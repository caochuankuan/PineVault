import '../models/vault_item.dart';

List<VaultItem> matchingAutofillItems({
  required List<VaultItem> items,
  required Iterable<String> domains,
  required Iterable<String> packageNames,
}) {
  final normalizedDomains = domains
      .map((value) => _host(value))
      .where((value) => value.isNotEmpty)
      .toSet();
  final normalizedPackages = packageNames
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .toSet();
  return [
    for (final item in items)
      if (item.urls.any((url) {
        final normalized = url.trim().toLowerCase();
        final host = _host(normalized);
        return normalizedDomains.any(
              (domain) => host == domain || host.endsWith('.$domain'),
            ) ||
            normalizedPackages.contains(normalized) ||
            normalizedPackages.contains(host);
      }))
        item,
  ];
}

String _host(String value) {
  if (value.trim().isEmpty) return '';
  final normalized = value.trim().toLowerCase();
  final uri = Uri.tryParse(
    normalized.contains('://') ? normalized : '//$normalized',
  );
  return (uri?.host ?? '').replaceFirst(RegExp(r'^www\.'), '');
}
