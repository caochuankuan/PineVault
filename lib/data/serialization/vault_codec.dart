import 'dart:convert';

import '../../domain/models/vault.dart';
import '../models/vault_envelope.dart';

class VaultCodec {
  const VaultCodec();

  String encodeEnvelope(VaultEnvelope envelope) =>
      jsonEncode(envelope.toJson());

  VaultEnvelope decodeEnvelope(String source) {
    final value = jsonDecode(source);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Vault file is not a JSON object.');
    }
    return VaultEnvelope.fromJson(value);
  }

  List<int> encodeVault(Vault vault) => utf8.encode(jsonEncode(vault.toJson()));

  Vault decodeVault(List<int> bytes) {
    final value = jsonDecode(utf8.decode(bytes));
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Vault payload is not a JSON object.');
    }
    return Vault.fromJson(value);
  }
}
