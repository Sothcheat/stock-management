// ignore_for_file: avoid_print
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../orders/domain/order.dart';

/// One-time script to fix Daily Aggregation for the last 48 hours.
/// Call this function ONCE (e.g., from a button or main.dart).
Future<void> runMigrationFix(FirebaseFirestore firestore) async {
  print("STARTING MIGRATION FIX...");

  // 1. Define Range (Last 48 Hours)
  final now = DateTime.now();
  final startPoint = now.subtract(const Duration(hours: 48));

  // 2. Fetch Completed Orders in range
  final querySnapshot = await firestore
      .collection('orders')
      .where('status', isEqualTo: 'completed')
      .where(
        'updatedAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startPoint),
      )
      .get();

  final orders = querySnapshot.docs
      .map((d) => OrderModel.fromFirestore(d))
      .toList();
  print("Found ${orders.length} orders to process.");

  // 3. Re-Calculate Summaries
  // Map Key: "YYYY-MM-DD" -> Data
  final Map<String, Map<String, dynamic>> dailyData = {};

  for (final order in orders) {
    // Correct Timezone Logic (UTC+7)
    // Correct Timezone Logic (UTC+7)
    final DateTime dt = order.updatedAt;

    final phnomPenhTime = dt.toUtc().add(const Duration(hours: 7));
    final dateKey = phnomPenhTime.toIso8601String().substring(0, 10);

    if (!dailyData.containsKey(dateKey)) {
      dailyData[dateKey] = {
        'totalRevenue': 0.0,
        'totalProfit': 0.0,
        'itemsSold': 0,
        // Must use <String, int> to match ranking type
        'productRanking': <String, int>{},
      };
    }

    final data = dailyData[dateKey]!;

    // Explicit casting to double/int for safety
    final currentRevenue = (data['totalRevenue'] as num).toDouble();
    final currentProfit = (data['totalProfit'] as num).toDouble();
    final currentItems = (data['itemsSold'] as num).toInt();

    data['totalRevenue'] = currentRevenue + order.totalRevenue;
    data['totalProfit'] = currentProfit + order.netProfit;
    data['itemsSold'] =
        currentItems + order.items.fold<int>(0, (p, c) => p + c.quantity);

    // Ranking
    final ranking = data['productRanking'] as Map<String, int>;
    for (final item in order.items) {
      ranking[item.name] = (ranking[item.name] ?? 0) + item.quantity;
    }
  }

  // 4. Overwrite Firestore Documents
  final batch = firestore.batch();

  for (final entry in dailyData.entries) {
    final dateKey = entry.key;
    final data = entry.value;

    final docRef = firestore.collection('daily_summaries').doc(dateKey);

    batch.set(docRef, {
      ...data,
      'date': dateKey,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    print("Queued update for $dateKey: Revenue \$${data['totalRevenue']}");
  }

  await batch.commit();
  print("MIGRATION COMPLETE.");
}
