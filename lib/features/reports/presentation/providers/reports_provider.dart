import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/reports_repository.dart';
import '../../domain/daily_summary.dart';
import '../../../../core/utils/date_utils.dart';

part 'reports_provider.g.dart';

// Helpers removed (replaced by direct range calculation using targetDate)

@riverpod
Stream<List<DailyData>> weeklyReport(Ref ref, DateTime targetDate) {
  ref.cacheFor(const Duration(minutes: 5));
  final repo = ref.watch(reportsRepositoryProvider);

  final start = DateUtilsHelper.getStartOfWeek(targetDate);
  final end = DateUtilsHelper.getEndOfWeek(targetDate);

  return repo.getDailySummariesRangeStream(start, end).map((fetchedSummaries) {
    final days = 7;
    // Generate keys sorted from Sunday (start) to Saturday (end)
    final keys = List.generate(days, (index) {
      final date = start.add(Duration(days: index));
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

  // 1. Determine the full range of weeks to display
  final startOfMonth = DateTime(targetDate.year, targetDate.month, 1);
  final endOfMonth = DateTime(targetDate.year, targetDate.month + 1, 0);

  // Start of the first week (Sunday)
  // If month starts on Sunday, this is the 1st. If Monday (2nd), this is 1st - 1 day, etc.
  final gridStart = DateUtilsHelper.getStartOfWeek(startOfMonth);

  // End of the last week (Saturday)
  // We keep adding weeks until we are past endOfMonth
  // Actually, simpler: iterate week by week from gridStart until weekStart > endOfMonth

  // Range for Query: We need data from gridStart to... let's say safely endOfMonth + 7 days
  final queryEnd = DateUtilsHelper.getEndOfWeek(endOfMonth);

  return repo.getDailySummariesRangeStream(gridStart, queryEnd).map((
    fetchedSummaries,
  ) {
    // 2. Map fetched data for easy lookup
    final Map<String, DailySummary> summaryMap = {};
    for (var s in fetchedSummaries) {
      summaryMap[s.date] = s; // Key is YYYY-MM-DD
    }

    final List<WeeklyGroup> allWeeks = [];

    // 3. Iterate Week by Week
    DateTime currentWeekStart = gridStart;

    // We iterate as long as the week *starts* before or on the end of the month
    // OR as long as the week *overlaps* the month.
    // Standard calendar view: row contains days from this month.
    // If a week starts on Jan 31st (Saturday), it is the week of Jan 25-31.
    // Loop condition: currentWeekStart is before or equal to endOfMonth (Wait, if end is Jan 31, and we act on Sunday Jan 25, that's fine. Next loop Feb 1 is > Jan 31).
    while (currentWeekStart.isBefore(endOfMonth) ||
        currentWeekStart.isAtSameMomentAs(endOfMonth)) {
      // Loop safety: ensure we don't go infinite
      if (currentWeekStart.year > targetDate.year + 1) break; // Safety break

      final currentWeekEnd = DateUtilsHelper.getEndOfWeek(currentWeekStart);

      // Build Daily Data for this week
      double weeklyRevenue = 0;
      double weeklyProfit = 0;
      List<DailyData> weekDays = [];

      // Iterate 7 days of this week
      for (int i = 0; i < 7; i++) {
        final dayDate = currentWeekStart.add(Duration(days: i));
        final dateKey = dayDate.toIso8601String().substring(0, 10);
        final summary = summaryMap[dateKey];

        if (summary != null) {
          weeklyRevenue += summary.totalRevenue;
          weeklyProfit += summary.totalProfit;
          weekDays.add(
            DailyData(
              dayDate,
              summary.totalRevenue,
              summary.totalProfit,
              productRanking: summary.productRanking,
            ),
          );
        } else {
          // Should we add empty days? The UI likely iterates 'days'.
          // If we want empty days to show inside the expansion, we can add them.
          // But 'Empty Week' usually means the expansion is disabled, so internal days don't matter much.
          // Let's NOT populate empty days to keep object light, UNLESS the week has some data.
          // Actually, if the week has data, we usually want to see the days impacting it.
          // If week has NO data, 'weekDays' will be empty.
        }
      }

      // Sort days new->old
      weekDays.sort((a, b) => b.date.compareTo(a.date));

      allWeeks.add(
        WeeklyGroup(
          weekStart: currentWeekStart,
          weekEnd: currentWeekEnd,
          totalRevenue: weeklyRevenue,
          totalProfit: weeklyProfit,
          days: weekDays,
        ),
      );

      // Advance to next week
      currentWeekStart = currentWeekStart.add(const Duration(days: 7));
    }

    // 4. Sort Weeks Descending (Newest Week First)
    allWeeks.sort((a, b) => b.weekStart.compareTo(a.weekStart));

    return allWeeks;
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
