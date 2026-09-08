import 'dart:convert';
import 'dart:typed_data';

import 'package:sodium_libs/sodium_libs_sumo.dart';

import '../../domain/models/vault.dart';
import '../models/vault_envelope.dart';
import '../serialization/vault_codec.dart';

class CreatedVault {
  const CreatedVault({required this.envelope, required this.key});

  final VaultEnvelope envelope;
  final SecureKey key;
}

class UnlockedVault {
  const UnlockedVault({
    required this.envelope,
    required this.vault,
    required this.key,
  });

  final VaultEnvelope envelope;
  final Vault vault;
  final SecureKey key;
}

class VaultUnlockException implements Exception {
  const VaultUnlockException();

  @override
  String toString() => '主密码错误；如果其他设备修改过主密码，请输入最新主密码';
}

class SodiumCryptoService {
  SodiumCryptoService(this._sodium, {VaultCodec codec = const VaultCodec()})
    : _codec = codec;

  final SodiumSumo _sodium;
  final VaultCodec _codec;

  Aead get _aead => _sodium.crypto.aeadXChaCha20Poly1305IETF;
  Pwhash get _pwhash => _sodium.crypto.pwhash;

  CreatedVault createVault({
    required String masterPassword,
    required Vault vault,
  }) {
    final salt = _sodium.randombytes.buf(_pwhash.saltBytes);
    final parameters = KdfParameters(
      algorithm: 'argon2id13',
      salt: base64Encode(salt),
      operations: _pwhash.opsLimitInteractive,
      memory: _pwhash.memLimitInteractive,
    );
    final vaultKey = _aead.keygen();
    final wrappingKey = _deriveKey(masterPassword, parameters);

    try {
      final wrappingNonce = _sodium.randombytes.buf(_aead.nonceBytes);
      final rawVaultKey = vaultKey.extractBytes();
      late final Uint8List wrappedKey;
      try {
        wrappedKey = _aead.encrypt(
          message: rawVaultKey,
          nonce: wrappingNonce,
          key: wrappingKey,
          additionalData: _associatedData(vault.id, parameters),
        );
      } finally {
        rawVaultKey.fillRange(0, rawVaultKey.length, 0);
      }

      return CreatedVault(
        key: vaultKey,
        envelope: VaultEnvelope(
          magic: VaultEnvelope.expectedMagic,
          version: VaultEnvelope.currentVersion,
          vaultId: vault.id,
          kdf: parameters,
          wrappedKey: CipherPayload(
            nonce: base64Encode(wrappingNonce),
            ciphertext: base64Encode(wrappedKey),
          ),
          payload: _encryptPayload(vault, vaultKey),
        ),
      );
    } catch (_) {
      vaultKey.dispose();
      rethrow;
    } finally {
      wrappingKey.dispose();
    }
  }

  UnlockedVault unlock({
    required String masterPassword,
    required VaultEnvelope envelope,
  }) {
    final wrappingKey = _deriveKey(masterPassword, envelope.kdf);
    SecureKey? vaultKey;
    try {
      final rawVaultKey = _aead.decrypt(
        cipherText: base64Decode(envelope.wrappedKey.ciphertext),
        nonce: base64Decode(envelope.wrappedKey.nonce),
        key: wrappingKey,
        additionalData: _associatedData(envelope.vaultId, envelope.kdf),
      );
      try {
        vaultKey = _sodium.secureCopy(rawVaultKey);
      } finally {
        rawVaultKey.fillRange(0, rawVaultKey.length, 0);
      }
      final vault = _decryptPayload(
        envelope.vaultId,
        envelope.payload,
        vaultKey,
      );
      if (vault.id != envelope.vaultId) {
        throw const FormatException('Vault identifier mismatch.');
      }
      return UnlockedVault(envelope: envelope, vault: vault, key: vaultKey);
    } catch (_) {
      vaultKey?.dispose();
      throw const VaultUnlockException();
    } finally {
      wrappingKey.dispose();
    }
  }

  UnlockedVault unlockWithVaultKey({
    required Uint8List rawVaultKey,
    required VaultEnvelope envelope,
  }) {
    if (rawVaultKey.length != _aead.keyBytes) {
      throw const VaultUnlockException();
    }
    final vaultKey = _sodium.secureCopy(rawVaultKey);
    try {
      final vault = _decryptPayload(
        envelope.vaultId,
        envelope.payload,
        vaultKey,
      );
      if (vault.id != envelope.vaultId) {
        throw const FormatException('Vault identifier mismatch.');
      }
      return UnlockedVault(envelope: envelope, vault: vault, key: vaultKey);
    } catch (_) {
      vaultKey.dispose();
      throw const VaultUnlockException();
    }
  }

  VaultEnvelope encryptVault({
    required VaultEnvelope envelope,
    required SecureKey key,
    required Vault vault,
  }) {
    return envelope.copyWithPayload(_encryptPayload(vault, key));
  }

  Vault decryptVault({
    required VaultEnvelope envelope,
    required SecureKey key,
  }) {
    final vault = _decryptPayload(envelope.vaultId, envelope.payload, key);
    if (vault.id != envelope.vaultId) {
      throw const FormatException('Vault identifier mismatch.');
    }
    return vault;
  }

  VaultEnvelope changeMasterPassword({
    required String currentPassword,
    required String newPassword,
    required VaultEnvelope envelope,
    required SecureKey vaultKey,
  }) {
    final verified = unlock(
      masterPassword: currentPassword,
      envelope: envelope,
    );
    verified.key.dispose();

    final salt = _sodium.randombytes.buf(_pwhash.saltBytes);
    final parameters = KdfParameters(
      algorithm: 'argon2id13',
      salt: base64Encode(salt),
      operations: _pwhash.opsLimitInteractive,
      memory: _pwhash.memLimitInteractive,
    );
    final wrappingKey = _deriveKey(newPassword, parameters);
    final nonce = _sodium.randombytes.buf(_aead.nonceBytes);
    final rawVaultKey = vaultKey.extractBytes();
    try {
      final wrappedKey = _aead.encrypt(
        message: rawVaultKey,
        nonce: nonce,
        key: wrappingKey,
        additionalData: _associatedData(envelope.vaultId, parameters),
      );
      return envelope.copyWithWrapping(
        newKdf: parameters,
        newWrappedKey: CipherPayload(
          nonce: base64Encode(nonce),
          ciphertext: base64Encode(wrappedKey),
        ),
      );
    } finally {
      rawVaultKey.fillRange(0, rawVaultKey.length, 0);
      wrappingKey.dispose();
    }
  }

  CipherPayload _encryptPayload(Vault vault, SecureKey key) {
    final nonce = _sodium.randombytes.buf(_aead.nonceBytes);
    final message = Uint8List.fromList(_codec.encodeVault(vault));
    try {
      final cipherText = _aead.encrypt(
        message: message,
        nonce: nonce,
        key: key,
        additionalData: _payloadAssociatedData(vault.id),
      );
      return CipherPayload(
        nonce: base64Encode(nonce),
        ciphertext: base64Encode(cipherText),
      );
    } finally {
      message.fillRange(0, message.length, 0);
    }
  }

  Vault _decryptPayload(String vaultId, CipherPayload payload, SecureKey key) {
    final plainText = _aead.decrypt(
      cipherText: base64Decode(payload.ciphertext),
      nonce: base64Decode(payload.nonce),
      key: key,
      additionalData: _payloadAssociatedData(vaultId),
    );
    try {
      return _codec.decodeVault(plainText);
    } finally {
      plainText.fillRange(0, plainText.length, 0);
    }
  }

  SecureKey _deriveKey(String password, KdfParameters parameters) {
    final passwordBytes = Uint8List.fromList(utf8.encode(password));
    try {
      return _pwhash(
        outLen: _aead.keyBytes,
        password: passwordBytes.buffer.asInt8List(),
        salt: base64Decode(parameters.salt),
        opsLimit: parameters.operations,
        memLimit: parameters.memory,
        alg: CryptoPwhashAlgorithm.argon2id13,
      );
    } finally {
      passwordBytes.fillRange(0, passwordBytes.length, 0);
    }
  }

  Uint8List _associatedData(String vaultId, KdfParameters parameters) {
    return Uint8List.fromList(
      utf8.encode(
        '${VaultEnvelope.expectedMagic}|${VaultEnvelope.currentVersion}|'
        '$vaultId|${parameters.algorithm}|${parameters.salt}|'
        '${parameters.operations}|${parameters.memory}',
      ),
    );
  }

  Uint8List _payloadAssociatedData(String vaultId) =>
      Uint8List.fromList(utf8.encode('PINEVAULT-PAYLOAD|$vaultId|1'));
}
