import 'package:flutter_test/flutter_test.dart';
import 'package:pine_vault/data/services/totp_service.dart';
import 'package:pine_vault/domain/models/totp_config.dart';

void main() {
  const service = TotpService();

  test('generates RFC 6238 SHA1 test vectors', () {
    const config = TotpConfig(
      secret: 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ',
      digits: 8,
      period: 30,
    );
    const vectors = {
      59: '94287082',
      1111111109: '07081804',
      1111111111: '14050471',
      1234567890: '89005924',
      2000000000: '69279037',
      20000000000: '65353130',
    };

    for (final entry in vectors.entries) {
      expect(
        service.generate(
          config,
          time: DateTime.fromMillisecondsSinceEpoch(
            entry.key * 1000,
            isUtc: true,
          ),
        ),
        entry.value,
      );
    }
  });

  test('generates RFC 6238 SHA256 and SHA512 test vectors', () {
    const sha256 = TotpConfig(
      secret: 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZA',
      algorithm: TotpAlgorithm.sha256,
      digits: 8,
    );
    const sha512 = TotpConfig(
      secret:
          'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNA',
      algorithm: TotpAlgorithm.sha512,
      digits: 8,
    );
    final time = DateTime.fromMillisecondsSinceEpoch(59000, isUtc: true);

    expect(service.generate(sha256, time: time), '46119246');
    expect(service.generate(sha512, time: time), '90693936');
  });

  test('parses and exports otpauth URI parameters', () {
    final parsed = service.parse(
      'otpauth://totp/Example:user%40example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example&algorithm=SHA256&digits=8&period=60',
    );

    expect(parsed.secret, 'JBSWY3DPEHPK3PXP');
    expect(parsed.issuer, 'Example');
    expect(parsed.account, 'user@example.com');
    expect(parsed.algorithm, TotpAlgorithm.sha256);
    expect(parsed.digits, 8);
    expect(parsed.period, 60);

    final reparsed = service.parse(service.toUri(parsed).toString());
    expect(reparsed.toJson(), parsed.toJson());
  });

  test('normalizes a plain Base32 secret and rejects HOTP', () {
    expect(service.parse('jbsw y3dp-ehpk3pxp').secret, 'JBSWY3DPEHPK3PXP');
    expect(
      () => service.parse(
        'otpauth://hotp/Example?secret=JBSWY3DPEHPK3PXP&counter=1',
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
