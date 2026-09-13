import 'package:flutter_test/flutter_test.dart';
import 'package:pine_vault/domain/models/vault_item.dart';
import 'package:pine_vault/domain/services/autofill_matcher.dart';

void main() {
  VaultItem item(String url) => VaultItem(
    id: url,
    type: VaultItemType.login,
    title: url,
    username: 'user',
    password: 'password',
    urls: [url],
    notes: '',
    favorite: false,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    revision: 1,
  );

  test('matches exact domains and subdomains without suffix confusion', () {
    final exact = item('https://github.com/login');
    final subdomain = item('gist.github.com');
    final suffixTrap = item('notgithub.com');
    expect(
      matchingAutofillItems(
        items: [exact, subdomain, suffixTrap],
        domains: const ['github.com'],
        packageNames: const [],
      ),
      [exact, subdomain],
    );
  });

  test('matches an explicitly stored Android package', () {
    final matching = item('com.example.app');
    final other = item('com.example.other');
    expect(
      matchingAutofillItems(
        items: [matching, other],
        domains: const [],
        packageNames: const ['com.example.app'],
      ),
      [matching],
    );
  });
}
