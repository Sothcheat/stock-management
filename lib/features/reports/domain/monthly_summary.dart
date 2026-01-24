class MonthlySummary {
  final String month; // YYYY-MM
  final double totalRevenue;
  final double totalProfit;
  final int itemsSold;
  final Map<String, int> productRanking; // "product_name": quantity

  const MonthlySummary({
    required this.month,
    this.totalRevenue = 0.0,
    this.totalProfit = 0.0,
    this.itemsSold = 0,
    this.productRanking = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'month': month,
      'totalRevenue': totalRevenue,
      'totalProfit': totalProfit,
      'itemsSold': itemsSold,
      'productRanking': productRanking,
    };
  }

  factory MonthlySummary.fromMap(Map<String, dynamic> map, String docId) {
    return MonthlySummary(
      month: docId,
      totalRevenue: (map['totalRevenue'] ?? 0).toDouble(),
      totalProfit: (map['totalProfit'] ?? 0).toDouble(),
      itemsSold: (map['itemsSold'] ?? 0).toInt(),
      productRanking: Map<String, int>.from(map['productRanking'] ?? {}),
    );
  }
}
