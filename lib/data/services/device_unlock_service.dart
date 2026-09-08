import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';

typedef DirectoryProvider = Future<Directory> Function();

class DeviceUnlockException implements Exception {
  const DeviceUnlockException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DeviceUnlockService {
  DeviceUnlockService({
    FlutterSecureStorage? storage,
    LocalAuthentication? authentication,
    DirectoryProvider? directoryProvider,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _authentication = authentication ?? LocalAuthentication(),
       _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  static const _storageKey = 'pine_vault_device_unlock_key_v1';
  static const _markerFileName = 'device_unlock.json';

  static const _androidOptions = AndroidOptions.biometric(
    enforceBiometrics: true,
    biometricType: AndroidBiometricType.biometricOrDeviceCredential,
    storageNamespace: 'pine_vault_device_unlock',
    biometricPromptTitle: '验证身份以解锁松匣',
    biometricPromptSubtitle: '使用指纹、面容或设备锁屏密码',
    biometricPromptNegativeButton: '取消',
  );
  static const _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.passcode,
    accessControlFlags: [AccessControlFlag.userPresence],
    synchronizable: false,
    label: '松匣设备解锁',
  );
  static const _macOptions = MacOsOptions(
    accessibility: KeychainAccessibility.unlocked_this_device,
    accessControlFlags: [AccessControlFlag.userPresence],
    synchronizable: false,
    usesDataProtectionKeychain: false,
    label: '松匣设备解锁',
  );

  final FlutterSecureStorage _storage;
  final LocalAuthentication _authentication;
  final DirectoryProvider _directoryProvider;

  bool get platformSupported =>
      Platform.isAndroid ||
      Platform.isIOS ||
      Platform.isMacOS ||
      Platform.isWindows;

  Future<bool> isAvailable() async {
    if (!platformSupported) return false;
    try {
      return await _authentication.isDeviceSupported();
    } on Object {
      return false;
    }
  }

  Future<bool> isEnabledFor(String vaultId) async {
    final marker = await _readMarker();
    return marker?['version'] == 1 && marker?['vaultId'] == vaultId;
  }

  Future<void> enable({
    required String vaultId,
    required Uint8List vaultKey,
  }) async {
    if (!await isAvailable()) {
      throw const DeviceUnlockException('当前设备没有可用的系统验证方式');
    }
    if (!Platform.isAndroid && !await _authenticate('验证身份以开启设备验证解锁')) {
      throw const DeviceUnlockException('设备验证已取消');
    }

    final payload = jsonEncode({
      'version': 1,
      'vaultId': vaultId,
      'vaultKey': base64Encode(vaultKey),
    });
    try {
      await _storage.write(
        key: _storageKey,
        value: payload,
        aOptions: _androidOptions,
        iOptions: _iosOptions,
        mOptions: _macOptions,
      );
      await _writeMarker(vaultId);
    } catch (error) {
      await _deleteStoredKey();
      throw DeviceUnlockException(_readableStorageError(error));
    }
  }

  Future<Uint8List> readVaultKey(String vaultId) async {
    if (!await isEnabledFor(vaultId)) {
      throw const DeviceUnlockException('本机尚未开启设备验证解锁');
    }
    if (Platform.isWindows && !await _authenticate('验证身份以解锁松匣')) {
      throw const DeviceUnlockException('设备验证已取消');
    }

    try {
      final encoded = await _storage.read(
        key: _storageKey,
        aOptions: _androidOptions,
        iOptions: _iosOptions,
        mOptions: _macOptions,
      );
      if (encoded == null) {
        throw const DeviceUnlockException('设备解锁信息已失效，请使用主密码重新绑定');
      }
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, dynamic> ||
          decoded['version'] != 1 ||
          decoded['vaultId'] != vaultId ||
          decoded['vaultKey'] is! String) {
        throw const DeviceUnlockException('设备解锁信息与当前密码库不匹配');
      }
      return base64Decode(decoded['vaultKey'] as String);
    } on DeviceUnlockException {
      rethrow;
    } catch (error) {
      throw DeviceUnlockException(_readableStorageError(error));
    }
  }

  Future<void> disable() async {
    try {
      await _deleteStoredKey();
      final marker = await _markerFile();
      if (await marker.exists()) await marker.delete();
    } catch (error) {
      throw DeviceUnlockException(_readableStorageError(error));
    }
  }

  Future<bool> _authenticate(String reason) async {
    try {
      return await _authentication.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        sensitiveTransaction: true,
      );
    } on PlatformException catch (error) {
      throw DeviceUnlockException(
        error.message?.trim().isNotEmpty == true
            ? error.message!
            : '无法调用系统设备验证',
      );
    } on LocalAuthException catch (error) {
      throw DeviceUnlockException(
        error.description?.trim().isNotEmpty == true
            ? error.description!
            : '无法调用系统设备验证',
      );
    }
  }

  Future<void> _deleteStoredKey() => _storage.delete(
    key: _storageKey,
    aOptions: _androidOptions,
    iOptions: _iosOptions,
    mOptions: _macOptions,
  );

  Future<Map<String, dynamic>?> _readMarker() async {
    try {
      final file = await _markerFile();
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeMarker(String vaultId) async {
    final file = await _markerFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({'version': 1, 'vaultId': vaultId}),
      flush: true,
    );
  }

  Future<File> _markerFile() async {
    final support = await _directoryProvider();
    return File('${support.path}/PineVault/$_markerFileName');
  }

  String _readableStorageError(Object error) {
    if (error is PlatformException) {
      final message = error.message?.trim();
      if (error.code == '-34018' || message?.contains('-34018') == true) {
        return 'macOS 设备安全存储权限未生效，请重新启动应用后再试';
      }
      final normalized = message?.toLowerCase() ?? '';
      if (normalized.contains('cancel') || normalized.contains('canceled')) {
        return '设备验证已取消';
      }
    }
    return '设备安全存储不可用，请使用主密码解锁';
  }
}
