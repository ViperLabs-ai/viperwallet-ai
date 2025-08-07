class TokenInfo {
  final String address;
  final String name;
  final String symbol;
  final int decimals;
  final String? logoURI;
  final bool verified;

  TokenInfo({
    required this.address,
    required this.name,
    required this.symbol,
    required this.decimals,
    this.logoURI,
    this.verified = false,
  });

  factory TokenInfo.fromJson(Map<String, dynamic> json) {
    return TokenInfo(
      address: json['address'] ?? '',
      name: json['name'] ?? 'Unknown Token',
      symbol: json['symbol'] ?? 'UNKNOWN',
      decimals: json['decimals'] ?? 0,
      logoURI: json['logoURI'],
      verified: json['verified'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'address': address,
      'name': name,
      'symbol': symbol,
      'decimals': decimals,
      'logoURI': logoURI,
      'verified': verified,
    };
  }
}
