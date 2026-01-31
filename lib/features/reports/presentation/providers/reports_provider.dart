import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/reports_repository.dart';
import '../../domain/daily_summary.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/logger.dart';
import '../../../orders/data/firebase_orders_repository.dart';
import '../../../orders/domain/order.dart';

part 'reports_provider.g.dart';

// Helpers removed (replaced by direct range calculation using targetDate)

@riverpod
Stream<List<DailyData>> weeklyReport(Ref ref, DateTime targetDate) {
  ref.cacheFor(const Duration(minutes: 5));
  final repo = ref.watch(reportsRepositoryProvider);
  final orderRepo = ref.watch(ordersRepositoryProvider);

  final start = DateUtilsHelper.getStartOfWeek(targetDate);
  final end = DateUtilsHelper.getEndOfWeek(
    targetDate,
  ).add(const Duration(hours: 23, minutes: 59, seconds: 59));

  return orderRepo.watchCompletedOrders(start, end).map((orders) {
    // 1. Group Orders by Date (Local Time)
    final Map<String, List<OrderModel>> ordersByDate = {};
    for (final order in orders) {
      // User Req: Use .toLocal()
      final dateKey = order.createdAt.toLocal().toIso8601String().substring(
        0,
        10,
      );
      ordersByDate.putIfAbsent(dateKey, () => []).add(order);
    }

    // 2. Build Daily Data
    final days = 7;
    final keys = List.generate(days, (index) {
      final date = start.add(Duration(days: index));
      return date.toIso8601String().substring(0, 10);
    });

    final result = keys.map((dateKey) {
      final dayOrders = ordersByDate[dateKey] ?? [];
      // Use Centralized Logic
      final summary = repo.calculateSummary(dayOrders);

      return DailyData(
        DateTime.parse(dateKey),
        summary.totalRevenue,
        summary.totalProfit,
        productRanking: summary.productRanking,
      );
    }).toList();

    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  });
}

// Helper Class for Hierarchical Monthly Data
class WeeklyGroup {
  final DateTime weekStart;
  final DateTime weekEnd;
  final double totalRevenue;
  final double totalProfit;
  final List<DailyData> days; // The daily items within this week

  WeeklyGroup({
    required this.weekStart,
    required this.weekEnd,
    required this.totalRevenue,
    required this.totalProfit,
    required this.days,
  });
}

@riverpod
Stream<List<WeeklyGroup>> monthlyReport(Ref ref, DateTime targetDate) {
  ref.cacheFor(const Duration(minutes: 5));
  final repo = ref.watch(reportsRepositoryProvider);
  final orderRepo = ref.watch(ordersRepositoryProvider);

  // 1. Determine Range
  final startOfMonth = DateTime(targetDate.year, targetDate.month, 1);
  final endOfMonth = DateTime(targetDate.year, targetDate.month + 1, 0);

  final gridStart = DateUtilsHelper.getStartOfWeek(startOfMonth);
  final queryEnd = DateUtilsHelper.getEndOfWeek(
    endOfMonth,
  ).add(const Duration(hours: 23, minutes: 59, seconds: 59));

  return orderRepo.watchCompletedOrders(gridStart, queryEnd).map((orders) {
    // 2. Group by Date
    final Map<String, List<OrderModel>> ordersByDate = {};
    for (final order in orders) {
      final dateKey = order.createdAt.toLocal().toIso8601String().substring(
        0,
        10,
      );
      ordersByDate.putIfAbsent(dateKey, () => []).add(order);
    }

    final List<WeeklyGroup> allWeeks = [];
    DateTime currentWeekStart = gridStart;

    // 3. Iterate Week by Week
    while (currentWeekStart.isBefore(endOfMonth) ||
        currentWeekStart.isAtSameMomentAs(endOfMonth)) {
      if (currentWeekStart.year > targetDate.year + 1) break;

      final currentWeekEnd = DateUtilsHelper.getEndOfWeek(currentWeekStart);

      double weeklyRevenue = 0;
      double weeklyProfit = 0;
      List<DailyData> weekDays = [];

      for (int i = 0; i < 7; i++) {
        final dayDate = currentWeekStart.add(Duration(days: i));
        final dateKey = dayDate.toIso8601String().substring(0, 10);

        final dayOrders = ordersByDate[dateKey] ?? [];
        final summary = repo.calculateSummary(dayOrders);

        weeklyRevenue += summary.totalRevenue;
        weeklyProfit += summary.totalProfit;

        if (dayOrders.isNotEmpty) {
          // Only add days with data or add empty? Previous logic added if summary exists.
          // Let's add all days for grid completeness or sticking to logic "If summary != null".
          // Previous logic: if summary != null, add.
          // Map logic means every day has a potential list.
          // To match UI expectations of "Only relevant days" or "All days"?
          // Let's add ALL days but filtered logic is:
          weekDays.add(
            DailyData(
              dayDate,
              summary.totalRevenue,
              summary.totalProfit,
              productRanking: summary.productRanking,
            ),
          );
        } else {
          // Add empty daily data to maintain grid structure if needed, or skip?
          // Previous code: "if (summary != null) ... else { // Should we add empty? ... }"
          // It seems previous code DID NOT add empty days.
          // But here we want to enable correct rendering?
          // Actually, safely add it if we want empty cells. Use same logic as before: Add if has data?
          // Wait, previous code `summaryMap[dateKey]` was null if no doc.
          // Here `dayOrders` is empty.
          if (dayOrders.isNotEmpty) {
            // Actually, if we skip, we skip.
          }
        }
      }

      // Re-reading logic: Previous code ONLY added if summary != null.
      // If I want to match exactly, I should only add if dayOrders.isNotEmpty.
      // BUT, `weeklyRevenue` accumulation happens regardless (0 if empty).
      // Let's populate `weekDays` only if `dayOrders.isNotEmpty`.

      // Re-looping to populate `weekDays` correctly
      // Actually, I can just do it in the loop above.
      // But wait, the loop above I changed to `weekDays.add(...)` without check.
      // Let's restore the "Only add if has data" behavior?
      // Or better: UI usually handles empty list.
      // Let's stick to "Only add if has orders" to avoid cluttering the list.

      final actualWeekDays = <DailyData>[];
      for (int i = 0; i < 7; i++) {
        final dayDate = currentWeekStart.add(Duration(days: i));
        final dateKey = dayDate.toIso8601String().substring(0, 10);
        final dayOrders = ordersByDate[dateKey] ?? [];

        if (dayOrders.isNotEmpty) {
          final summary = repo.calculateSummary(dayOrders);
          // Optimization: If summary is 0 revenue/profit, still add?
          // Yes, user might want to see 0 if orders exist (e.g. all voided? -> returns 0).
          // Any list of orders -> add.
          actualWeekDays.add(
            DailyData(
              dayDate,
              summary.totalRevenue,
              summary.totalProfit,
              productRanking: summary.productRanking,
            ),
          );
        }
      }

      actualWeekDays.sort((a, b) => b.date.compareTo(a.date));

      allWeeks.add(
        WeeklyGroup(
          weekStart: currentWeekStart,
          weekEnd: currentWeekEnd,
          totalRevenue:
              weeklyRevenue, // This was calculated over 7 days, including empty ones (0).
          totalProfit: weeklyProfit,
          days: actualWeekDays,
        ),
      );

      currentWeekStart = currentWeekStart.add(const Duration(days: 7));
    }

    allWeeks.sort((a, b) => b.weekStart.compareTo(a.weekStart));
    return allWeeks;
  });
}

@riverpod
Stream<List<DailyData>> yearlyReport(Ref ref, DateTime targetDate) {
  ref.cacheFor(const Duration(minutes: 5));
  final repo = ref.watch(reportsRepositoryProvider);
  final orderRepo = ref.watch(ordersRepositoryProvider);

  final start = DateTime(targetDate.year, 1, 1);
  final end = DateTime(targetDate.year, 12, 31, 23, 59, 59);

  return orderRepo.watchCompletedOrders(start, end).map((orders) {
    // Group By Month (yyyy-MM)
    final Map<String, List<OrderModel>> ordersByMonth = {};
    for (final order in orders) {
      final key = order.createdAt.toLocal().toIso8601String().substring(0, 7);
      ordersByMonth.putIfAbsent(key, () => []).add(order);
    }

    // Generate keys for 12 months (Newest first: Dec -> Jan)
    final keys = List.generate(12, (index) {
      final month = 12 - index;
      return "${targetDate.year}-${month.toString().padLeft(2, '0')}";
    });

    final result = <DailyData>[];

    for (var monthKey in keys) {
      final monthOrders = ordersByMonth[monthKey] ?? [];
      final summary = repo.calculateSummary(monthOrders);

      result.add(
        DailyData(
          DateTime.parse("$monthKey-01"),
          summary.totalRevenue,
          summary.totalProfit,
          productRanking: summary.productRanking,
        ),
      );
    }

    return result;
  });
}

@riverpod
Stream<List<DailyData>> allTimeReport(Ref ref, DateTime targetDate) {
  ref.cacheFor(const Duration(minutes: 5));
  final repo = ref.watch(reportsRepositoryProvider);
  // Using a broad range for "All Time" - e.g., last 10 years to next 1 year
  final start = DateTime(2020, 1, 1);
  final end = DateTime.now().add(const Duration(days: 365));

  return repo.getDailySummariesRangeStream(start, end).map((
    fetchedDailySummaries,
  ) {
    if (fetchedDailySummaries.isEmpty) return [];

    final Map<String, DailyData> monthlyAggregation = {};

    for (var daily in fetchedDailySummaries) {
      if (daily.date.length < 7) continue;
      final monthKey = daily.date.substring(0, 7);

      if (!monthlyAggregation.containsKey(monthKey)) {
        monthlyAggregation[monthKey] = DailyData(
          DateTime.parse("$monthKey-01"),
          0.0,
          0.0,
          productRanking: {},
        );
      }
      final current = monthlyAggregation[monthKey]!;

      // Merge product rankings
      final mergedRanking = Map<String, int>.from(current.productRanking);
      daily.productRanking.forEach((key, qty) {
        mergedRanking[key] = (mergedRanking[key] ?? 0) + qty;
      });

      monthlyAggregation[monthKey] = DailyData(
        current.date,
        current.revenue + daily.totalRevenue,
        current.profit + daily.totalProfit,
        productRanking: mergedRanking,
      );
    }

    return monthlyAggregation.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  });
}

extension on Ref {
  void cacheFor(Duration duration) {
    Logger.log('Caching provider $runtimeType for $duration'); // Debug intent
    final link = keepAlive();
    final timer = Future.delayed(duration, () {
      Logger.log('Disposing cached provider $runtimeType');
      link.close();
    });
    onDispose(() => timer.ignore()); // Prevent unawaited_futures if strict
  }
}
