class Stock {
  final String symbol;
  final String name;
  final String exchange;

  Stock({
    required this.symbol,
    required this.name,
    required this.exchange,
  });

  factory Stock.fromJson(Map<String, dynamic> json) {
    return Stock(
      symbol: json['symbol'] ?? '',
      name: json['name'] ?? '',
      exchange: json['exchange'] ?? '',
    );
  }
} 