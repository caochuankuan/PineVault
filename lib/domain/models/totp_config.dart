enum TotpAlgorithm { sha1, sha256, sha512 }

class TotpConfig {
  const TotpConfig({
    required this.secret,
    this.algorithm = TotpAlgorithm.sha1,
    this.digits = 6,
    this.period = 30,
    this.issuer = '',
    this.account = '',
  });

  final String secret;
  final TotpAlgorithm algorithm;
  final int digits;
  final int period;
  final String issuer;
  final String account;

  factory TotpConfig.fromJson(Map<String, dynamic> json) {
    final algorithmName = json['algorithm'] as String? ?? 'sha1';
    final digits = json['digits'] as int? ?? 6;
    final period = json['period'] as int? ?? 30;
    if (digits != 6 && digits != 8) {
      throw const FormatException('TOTP 位数必须是 6 或 8');
    }
    if (period <= 0) throw const FormatException('TOTP 周期必须大于 0');
    return TotpConfig(
      secret: json['secret'] as String,
      algorithm: TotpAlgorithm.values.byName(algorithmName),
      digits: digits,
      period: period,
      issuer: json['issuer'] as String? ?? '',
      account: json['account'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'secret': secret,
    'algorithm': algorithm.name,
    'digits': digits,
    'period': period,
    if (issuer.isNotEmpty) 'issuer': issuer,
    if (account.isNotEmpty) 'account': account,
  };

  TotpConfig copyWith({
    String? secret,
    TotpAlgorithm? algorithm,
    int? digits,
    int? period,
    String? issuer,
    String? account,
  }) {
    return TotpConfig(
      secret: secret ?? this.secret,
      algorithm: algorithm ?? this.algorithm,
      digits: digits ?? this.digits,
      period: period ?? this.period,
      issuer: issuer ?? this.issuer,
      account: account ?? this.account,
    );
  }
}
