class KdfParameters {
  const KdfParameters({
    required this.algorithm,
    required this.salt,
    required this.operations,
    required this.memory,
  });

  final String algorithm;
  final String salt;
  final int operations;
  final int memory;

  factory KdfParameters.fromJson(Map<String, dynamic> json) {
    return switch (json) {
      {
        'algorithm': final String algorithm,
        'salt': final String salt,
        'operations': final int operations,
        'memory': final int memory,
      } =>
        KdfParameters(
          algorithm: algorithm,
          salt: salt,
          operations: operations,
          memory: memory,
        ),
      _ => throw const FormatException('Invalid KDF parameters.'),
    };
  }

  Map<String, dynamic> toJson() => {
    'algorithm': algorithm,
    'salt': salt,
    'operations': operations,
    'memory': memory,
  };
}

class CipherPayload {
  const CipherPayload({required this.nonce, required this.ciphertext});

  final String nonce;
  final String ciphertext;

  factory CipherPayload.fromJson(Map<String, dynamic> json) {
    return switch (json) {
      {'nonce': final String nonce, 'ciphertext': final String ciphertext} =>
        CipherPayload(nonce: nonce, ciphertext: ciphertext),
      _ => throw const FormatException('Invalid cipher payload.'),
    };
  }

  Map<String, dynamic> toJson() => {'nonce': nonce, 'ciphertext': ciphertext};
}

class VaultEnvelope {
  const VaultEnvelope({
    required this.magic,
    required this.version,
    required this.vaultId,
    required this.kdf,
    required this.wrappedKey,
    required this.payload,
  });

  static const expectedMagic = 'PINEVAULT';
  static const currentVersion = 1;

  final String magic;
  final int version;
  final String vaultId;
  final KdfParameters kdf;
  final CipherPayload wrappedKey;
  final CipherPayload payload;

  factory VaultEnvelope.fromJson(Map<String, dynamic> json) {
    final envelope = switch (json) {
      {
        'magic': final String magic,
        'version': final int version,
        'vaultId': final String vaultId,
        'kdf': final Map<String, dynamic> kdf,
        'wrappedKey': final Map<String, dynamic> wrappedKey,
        'payload': final Map<String, dynamic> payload,
      } =>
        VaultEnvelope(
          magic: magic,
          version: version,
          vaultId: vaultId,
          kdf: KdfParameters.fromJson(kdf),
          wrappedKey: CipherPayload.fromJson(wrappedKey),
          payload: CipherPayload.fromJson(payload),
        ),
      _ => throw const FormatException('Invalid PineVault envelope.'),
    };
    if (envelope.magic != expectedMagic ||
        envelope.version != currentVersion ||
        envelope.kdf.algorithm != 'argon2id13') {
      throw const FormatException('Unsupported PineVault format.');
    }
    return envelope;
  }

  Map<String, dynamic> toJson() => {
    'magic': magic,
    'version': version,
    'vaultId': vaultId,
    'kdf': kdf.toJson(),
    'wrappedKey': wrappedKey.toJson(),
    'payload': payload.toJson(),
  };

  VaultEnvelope copyWithPayload(CipherPayload newPayload) => VaultEnvelope(
    magic: magic,
    version: version,
    vaultId: vaultId,
    kdf: kdf,
    wrappedKey: wrappedKey,
    payload: newPayload,
  );
}
