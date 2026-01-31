import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../domain/daily_summary.dart';
import '../domain/monthly_summary.dart';
import '../../orders/domain/order.dart';

part 'reports_repository.g.dart';

@Riverpod(keepAlive: true)
ReportsRepository reportsRepository(Ref ref) {
  return ReportsRepository(FirebaseFirestore.instance);
}

class ReportsRepository {
  final FirebaseFirestore _firestore;

  ReportsRepository(this._firestore);

  // Fetch last N days of summaries
  Future<List<DailySummary>> getSummaries({int limit = 7}) async {
    // Note: To get "last N days", we ideally query by date desc, then reverse.
    // Assuming document ID is YYYY-MM-DD, we can order by __name__ or if we stored a timestamp field.
    // Since we only store ID as date (string sortable), we can order by Key.

    // We want the *latest* dates.
    final query = await _firestore
        .collection('daily_summaries')
        .orderBy(FieldPath.documentId, descending: true)
        .limit(limit)
        .get();

    final summaries = query.docs.map((doc) {
      return DailySummary.fromMap(doc.data(), doc.id);
    }).toList();

    // Return in chronological order (Oldest -> Newest) for graphs
    return summaries.reversed.toList();
  }

  // Fetch last N months of summaries
  Future<List<MonthlySummary>> getMonthlySummaries({int limit = 12}) async {
    final query = await _firestore
        .collection('monthly_summaries')
        .orderBy(FieldPath.documentId, descending: true)
        .limit(limit)
        .get();

    final summaries = query.docs.map((doc) {
      return MonthlySummary.fromMap(doc.data(), doc.id);
    }).toList();

    return summaries.reversed.toList();
  }

  Stream<List<DailySummary>> watchSummaries({int limit = 7}) {
    return _firestore
        .collection('daily_summaries')
        .orderBy(FieldPath.documentId, descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => DailySummary.fromMap(doc.data(), doc.id))
              .toList();
          return list.reversed.toList();
        });
  }

  // Fetch daily summaries between distinct dates (inclusive)
  Future<List<DailySummary>> getDailySummariesRange(
    DateTime start,
    DateTime end,
  ) async {
    final startKey = start.toIso8601String().substring(0, 10);
    final endKey = end.toIso8601String().substring(0, 10);

    final query = await _firestore
        .collection('daily_summaries')
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: startKey)
        .where(FieldPath.documentId, isLessThanOrEqualTo: endKey)
        .get();

    final summaries = query.docs.map((doc) {
      return DailySummary.fromMap(doc.data(), doc.id);
    }).toList();

    // Return sorted by date descending (Newest First) per UI requirement
    // Firestore ordering with inequality filter on key works, but manual sort is safer if key sort isn't guaranteed by default (it usually is for doc ID).
    // Let's explicitly sort in Dart to be sure.
    summaries.sort((a, b) => b.date.compareTo(a.date));
    return summaries;
  }

  Stream<List<DailySummary>> getDailySummariesRangeStream(
    DateTime start,
    DateTime end,
  ) {
    final startKey = start.toIso8601String().substring(0, 10);
    final endKey = end.toIso8601String().substring(0, 10);

    return _firestore
        .collection('daily_summaries')
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: startKey)
        .where(FieldPath.documentId, isLessThanOrEqualTo: endKey)
        .snapshots()
        .map((snapshot) {
          final summaries = snapshot.docs.map((doc) {
            return DailySummary.fromMap(doc.data(), doc.id);
          }).toList();
          // Sort Descending locally
          summaries.sort((a, b) => b.date.compareTo(a.date));
          return summaries;
        });
  }

  // Centralized Calculation Logic
  ReportSummary calculateSummary(List<OrderModel> orders) {
    double revenue = 0;
    double profit = 0;
    final Map<String, int> ranking = {};

    for (final order in orders) {
      if (order.isVoided) continue;

      revenue += order.totalRevenue;
      profit += order.netProfit;

      for (final item in order.items) {
        final key = item.name;
        ranking[key] = (ranking[key] ?? 0) + item.quantity;
      }
    }

    // Safeguard calls - Ensures no negative values in UI
    if (revenue < 0) revenue = 0;
    if (profit < 0) profit = 0;

    return ReportSummary(revenue, profit, ranking);
  }
}

class ReportSummary {
  final double totalRevenue;
  final double totalProfit;
  final Map<String, int> productRanking;

  ReportSummary(this.totalRevenue, this.totalProfit, this.productRanking);
}
