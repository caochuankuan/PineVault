import Cocoa
import CryptoKit
import FlutterMacOS
import LocalAuthentication
import Security

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    MacDeviceUnlock.register(with: flutterViewController)

    super.awakeFromNib()
  }
}

private enum MacDeviceUnlockError: LocalizedError {
  case deviceUnavailable
  case invalidArguments
  case invalidBinding

  var errorDescription: String? {
    switch self {
    case .deviceUnavailable:
      return "此 Mac 没有可用的 Secure Enclave"
    case .invalidArguments:
      return "设备解锁参数无效"
    case .invalidBinding:
      return "设备解锁信息已失效"
    }
  }
}

private struct MacDeviceUnlockEnvelope: Codable {
  let version: Int
  let vaultId: String
  let privateKey: Data
  let peerPublicKey: Data
  let salt: Data
  let sealedVaultKey: Data
}

private final class MacDeviceUnlock {
  private static let channelName = "app.pinevault.client/device_unlock_macos"
  private static let sharedInfo = Data("PineVault macOS device unlock v1".utf8)

  static func register(with controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: controller.engine.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "isAvailable":
        result(SecureEnclave.isAvailable)
      case "enable":
        guard
          let arguments = call.arguments as? [String: Any],
          let vaultId = arguments["vaultId"] as? String,
          let typedKey = arguments["vaultKey"] as? FlutterStandardTypedData
        else {
          result(flutterError(for: MacDeviceUnlockError.invalidArguments))
          return
        }
        perform(result: result) {
          try enable(vaultId: vaultId, vaultKey: typedKey.data)
          return nil
        }
      case "read":
        guard
          let arguments = call.arguments as? [String: Any],
          let vaultId = arguments["vaultId"] as? String
        else {
          result(flutterError(for: MacDeviceUnlockError.invalidArguments))
          return
        }
        perform(result: result) {
          FlutterStandardTypedData(bytes: try read(vaultId: vaultId))
        }
      case "disable":
        perform(result: result) {
          try disable()
          return nil
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func enable(vaultId: String, vaultKey: Data) throws {
    guard SecureEnclave.isAvailable else {
      throw MacDeviceUnlockError.deviceUnavailable
    }

    let context = authenticationContext(reason: "验证身份以开启松匣设备解锁")
    var accessError: Unmanaged<CFError>?
    guard let accessControl = SecAccessControlCreateWithFlags(
      nil,
      kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
      [.privateKeyUsage, .userPresence],
      &accessError
    ) else {
      if let error = accessError?.takeRetainedValue() {
        throw error
      }
      throw MacDeviceUnlockError.invalidBinding
    }

    let privateKey = try SecureEnclave.P256.KeyAgreement.PrivateKey(
      accessControl: accessControl,
      authenticationContext: context
    )
    let peerPrivateKey = P256.KeyAgreement.PrivateKey()
    let salt = try randomData(count: 32)
    let sharedSecret = try privateKey.sharedSecretFromKeyAgreement(
      with: peerPrivateKey.publicKey
    )
    let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
      using: SHA256.self,
      salt: salt,
      sharedInfo: sharedInfo,
      outputByteCount: 32
    )
    let sealed = try AES.GCM.seal(vaultKey, using: symmetricKey)
    guard let combined = sealed.combined else {
      throw MacDeviceUnlockError.invalidBinding
    }

    let envelope = MacDeviceUnlockEnvelope(
      version: 1,
      vaultId: vaultId,
      privateKey: privateKey.dataRepresentation,
      peerPublicKey: peerPrivateKey.publicKey.x963Representation,
      salt: salt,
      sealedVaultKey: combined
    )
    let encoded = try JSONEncoder().encode(envelope)
    let file = try bindingFile()
    try FileManager.default.createDirectory(
      at: file.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try encoded.write(to: file, options: .atomic)
  }

  private static func read(vaultId: String) throws -> Data {
    guard SecureEnclave.isAvailable else {
      throw MacDeviceUnlockError.deviceUnavailable
    }
    let envelope = try JSONDecoder().decode(
      MacDeviceUnlockEnvelope.self,
      from: Data(contentsOf: try bindingFile())
    )
    guard envelope.version == 1, envelope.vaultId == vaultId else {
      throw MacDeviceUnlockError.invalidBinding
    }

    let context = authenticationContext(reason: "验证身份以解锁松匣")
    let privateKey = try SecureEnclave.P256.KeyAgreement.PrivateKey(
      dataRepresentation: envelope.privateKey,
      authenticationContext: context
    )
    let peerPublicKey = try P256.KeyAgreement.PublicKey(
      x963Representation: envelope.peerPublicKey
    )
    let sharedSecret = try privateKey.sharedSecretFromKeyAgreement(
      with: peerPublicKey
    )
    let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
      using: SHA256.self,
      salt: envelope.salt,
      sharedInfo: sharedInfo,
      outputByteCount: 32
    )
    let sealed = try AES.GCM.SealedBox(combined: envelope.sealedVaultKey)
    return try AES.GCM.open(sealed, using: symmetricKey)
  }

  private static func disable() throws {
    let file = try bindingFile()
    if FileManager.default.fileExists(atPath: file.path) {
      try FileManager.default.removeItem(at: file)
    }
  }

  private static func authenticationContext(reason: String) -> LAContext {
    let context = LAContext()
    context.localizedReason = reason
    context.localizedFallbackTitle = "使用系统密码"
    return context
  }

  private static func randomData(count: Int) throws -> Data {
    var data = Data(count: count)
    let status = data.withUnsafeMutableBytes { bytes in
      SecRandomCopyBytes(kSecRandomDefault, count, bytes.baseAddress!)
    }
    guard status == errSecSuccess else {
      throw MacDeviceUnlockError.invalidBinding
    }
    return data
  }

  private static func bindingFile() throws -> URL {
    guard let support = FileManager.default.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    ).first else {
      throw MacDeviceUnlockError.invalidBinding
    }
    guard let bundleId = Bundle.main.bundleIdentifier else {
      throw MacDeviceUnlockError.invalidBinding
    }
    return support
      .appendingPathComponent(bundleId, isDirectory: true)
      .appendingPathComponent("PineVault", isDirectory: true)
      .appendingPathComponent("device_unlock_macos.json", isDirectory: false)
  }

  private static func perform(
    result: @escaping FlutterResult,
    operation: @escaping () throws -> Any?
  ) {
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        let value = try operation()
        DispatchQueue.main.async { result(value) }
      } catch {
        let flutterError = flutterError(for: error)
        DispatchQueue.main.async { result(flutterError) }
      }
    }
  }

  private static func flutterError(for error: Error) -> FlutterError {
    let nsError = error as NSError
    let code: String
    if error is MacDeviceUnlockError {
      switch error as! MacDeviceUnlockError {
      case .deviceUnavailable:
        code = "device_unavailable"
      case .invalidArguments:
        code = "invalid_arguments"
      case .invalidBinding:
        code = "binding_invalid"
      }
    } else if nsError.domain == LAError.errorDomain {
      code = "authentication_failed"
    } else {
      code = "device_unlock_failed"
    }
    return FlutterError(
      code: code,
      message: error.localizedDescription,
      details: nil
    )
  }
}
