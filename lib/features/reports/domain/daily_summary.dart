class DailySummary {
  final String date; // YYYY-MM-DD
  final double totalRevenue;
  final double totalProfit;
  final int itemsSold;
  final Map<String, int> productRanking; // "product_name": quantity

  const DailySummary({
    required this.date,
    this.totalRevenue = 0.0,
    this.totalProfit = 0.0,
    this.itemsSold = 0,
    this.productRanking = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'totalRevenue': totalRevenue,
      'totalProfit': totalProfit,
      'itemsSold': itemsSold,
      'productRanking': productRanking,
    };
  }

  factory DailySummary.fromMap(Map<String, dynamic> map, String docId) {
    return DailySummary(
      date: docId,
      totalRevenue: (map['totalRevenue'] ?? 0).toDouble(),
      totalProfit: (map['totalProfit'] ?? 0).toDouble(),
      itemsSold: (map['itemsSold'] ?? 0).toInt(),
      productRanking: Map<String, int>.from(map['productRanking'] ?? {}),
    );
  }
}

class DailyData {
  final DateTime date;
  final double revenue;
  final double profit;
  final Map<String, int> productRanking;

  DailyData(
    this.date,
    this.revenue,
    this.profit, {
    this.productRanking = const {},
  });
}
