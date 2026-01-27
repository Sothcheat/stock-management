import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/reports_repository.dart';
import '../../domain/daily_summary.dart';

part 'reports_provider.g.dart';

// Helpers removed (replaced by direct range calculation using targetDate)

@riverpod
Stream<List<DailyData>> weeklyReport(Ref ref, DateTime targetDate) {
  ref.cacheFor(const Duration(minutes: 5));
  final repo = ref.watch(reportsRepositoryProvider);

  final int offsetToSunday = targetDate.weekday % 7;
  final start = targetDate.subtract(Duration(days: offsetToSunday));
  final end = start.add(const Duration(days: 6));

  return repo.getDailySummariesRangeStream(start, end).map((fetchedSummaries) {
    final days = 7;
    final keys = List.generate(days, (index) {
      final date = end.subtract(Duration(days: index));
      return date.toIso8601String().substring(0, 10);
    });

    final summaryMap = {for (var s in fetchedSummaries) s.date: s};

    final result = keys.map((dateKey) {
      final s = summaryMap[dateKey];
      return DailyData(
        DateTime.parse(dateKey),
        s?.totalRevenue ?? 0.0,
        s?.totalProfit ?? 0.0,
        productRanking: s?.productRanking ?? {},
      );
    }).toList();

    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  });
}

@riverpod
Stream<List<DailyData>> monthlyReport(Ref ref, DateTime targetDate) {
  ref.cacheFor(const Duration(minutes: 5));
  final repo = ref.watch(reportsRepositoryProvider);

  final start = DateTime(targetDate.year, targetDate.month, 1);
  final nextMonth = DateTime(targetDate.year, targetDate.month + 1, 1);
  final end = nextMonth.subtract(const Duration(days: 1));

  return repo.getDailySummariesRangeStream(start, end).map((fetchedSummaries) {
    final daysInMonth = end.day;
    final keys = List.generate(daysInMonth, (index) {
      final date = end.subtract(Duration(days: index));
      return date.toIso8601String().substring(0, 10);
    });

    final summaryMap = {for (var s in fetchedSummaries) s.date: s};

    final result = keys.map((dateKey) {
      final s = summaryMap[dateKey];
      return DailyData(
        DateTime.parse(dateKey),
        s?.totalRevenue ?? 0.0,
        s?.totalProfit ?? 0.0,
        productRanking: s?.productRanking ?? {},
      );
    }).toList();

    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  });
}

@riverpod
Stream<List<DailyData>> yearlyReport(Ref ref, DateTime targetDate) {
  ref.cacheFor(const Duration(minutes: 5));
  final repo = ref.watch(reportsRepositoryProvider);

  final start = DateTime(targetDate.year, 1, 1);
  final end = DateTime(targetDate.year, 12, 31);

  return repo.getDailySummariesRangeStream(start, end).map((
    fetchedDailySummaries,
  ) {
    final Map<String, DailyData> monthlyAggregation = {};

    final keys = List.generate(12, (index) {
      final month = 12 - index;
      return "${targetDate.year}-${month.toString().padLeft(2, '0')}";
    });

    for (var key in keys) {
      monthlyAggregation[key] = DailyData(DateTime.parse("$key-01"), 0.0, 0.0);
    }

    for (var daily in fetchedDailySummaries) {
      if (daily.date.length >= 7) {
        final monthKey = daily.date.substring(0, 7);
        if (monthlyAggregation.containsKey(monthKey)) {
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
      }
    }

    return monthlyAggregation.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
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
    print('Caching provider ${this.runtimeType} for $duration'); // Debug intent
    final link = keepAlive();
    final timer = Future.delayed(duration, () {
      print('Disposing cached provider ${this.runtimeType}');
      link.close();
    });
    onDispose(() => timer.ignore()); // Prevent unawaited_futures if strict
  }
}
