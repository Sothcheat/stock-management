import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../design_system.dart';
import '../../auth/data/providers/auth_providers.dart';
import '../../auth/domain/user_model.dart';
import '../../reports/domain/daily_summary.dart';
import '../../reports/domain/report_time_range.dart';
import 'providers/reports_provider.dart';
// import 'widgets/custom_line_chart.dart'; // REMOVED

class ReportScreen extends ConsumerWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SoftScaffold(
      title: 'Reports',
      showBack: false,
      body: _ReportContent(),
    );
  }
}

class _ReportContent extends ConsumerStatefulWidget {
  const _ReportContent();

  @override
  ConsumerState<_ReportContent> createState() => _ReportContentState();
}

class _ReportContentState extends ConsumerState<_ReportContent> {
  ReportTimeRange _selectedRange = ReportTimeRange.weekly;
  DateTime _focusedDate = DateTime.now();

  void _navigate(int direction) {
    if (direction == 0) return;
    HapticFeedback.lightImpact();
    setState(() {
      switch (_selectedRange) {
        case ReportTimeRange.weekly:
          _focusedDate = _focusedDate.add(Duration(days: 7 * direction));
          break;
        case ReportTimeRange.monthly:
          _focusedDate = DateTime(
            _focusedDate.year,
            _focusedDate.month + direction,
            _focusedDate.day,
          );
          break;
        case ReportTimeRange.yearly:
          _focusedDate = DateTime(
            _focusedDate.year + direction,
            _focusedDate.month,
            _focusedDate.day,
          );
          break;
        case ReportTimeRange.allTime:
          break;
      }
    });
  }

  void _resetToToday() {
    HapticFeedback.lightImpact();
    setState(() {
      _focusedDate = DateTime.now();
    });
  }

  Future<void> _selectDate() async {
    HapticFeedback.lightImpact();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _focusedDate,
      firstDate: DateTime(2023),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: SoftColors.brandPrimary,
              onPrimary: Colors.white,
              onSurface: SoftColors.textMain,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: SoftColors.brandPrimary,
                textStyle: GoogleFonts.outfit(),
              ),
            ),
            textTheme: GoogleFonts.outfitTextTheme(),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _focusedDate = picked;
      });
    }
  }

  String _getDateLabel() {
    switch (_selectedRange) {
      case ReportTimeRange.weekly:
        final int offsetToSunday = _focusedDate.weekday % 7;
        final start = _focusedDate.subtract(Duration(days: offsetToSunday));
        final end = start.add(const Duration(days: 6));
        final startFormat = DateFormat('MMM d').format(start);
        final endFormat = DateFormat('MMM d, yyyy').format(end);
        return "$startFormat - $endFormat";
      case ReportTimeRange.monthly:
        return DateFormat('MMMM yyyy').format(_focusedDate);
      case ReportTimeRange.yearly:
        return DateFormat('yyyy').format(_focusedDate);
      case ReportTimeRange.allTime:
        return "All History";
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Determine Provider
    AsyncValue<List<DailyData>> summariesAsync;
    switch (_selectedRange) {
      case ReportTimeRange.weekly:
        summariesAsync = ref.watch(weeklyReportProvider(_focusedDate));
        break;
      case ReportTimeRange.monthly:
        summariesAsync = ref.watch(monthlyReportProvider(_focusedDate));
        break;
      case ReportTimeRange.yearly:
        summariesAsync = ref.watch(yearlyReportProvider(_focusedDate));
        break;
      case ReportTimeRange.allTime:
        summariesAsync = ref.watch(allTimeReportProvider(_focusedDate));
        break;
    }

    // 2. Side Effect: Haptics
    ref.listen(
      _selectedRange == ReportTimeRange.weekly
          ? weeklyReportProvider(_focusedDate)
          : _selectedRange == ReportTimeRange.monthly
          ? monthlyReportProvider(_focusedDate)
          : _selectedRange == ReportTimeRange.yearly
          ? yearlyReportProvider(_focusedDate)
          : allTimeReportProvider(_focusedDate),
      (previous, next) {
        if (next.hasValue &&
            !next.isLoading &&
            previous?.value != null &&
            previous!.value != next.value) {
          HapticFeedback.lightImpact();
        }
      },
    );

    final userRole = ref.watch(currentUserProfileProvider).value?.role;
    final isEmployee = userRole == UserRole.employee;

    // Navigation Constraints
    final now = DateTime.now();
    bool canGoForward = false;
    if (_selectedRange == ReportTimeRange.weekly) {
      final int offsetToSunday = _focusedDate.weekday % 7;
      final start = _focusedDate.subtract(Duration(days: offsetToSunday));
      final end = start.add(const Duration(days: 6));
      final today = DateTime(now.year, now.month, now.day);
      canGoForward = end.isBefore(today);
    } else if (_selectedRange == ReportTimeRange.monthly) {
      canGoForward =
          (_focusedDate.year < now.year) ||
          (_focusedDate.year == now.year && _focusedDate.month < now.month);
    } else if (_selectedRange == ReportTimeRange.yearly) {
      canGoForward = _focusedDate.year < now.year;
    }

    final showNavigation = _selectedRange != ReportTimeRange.allTime;

    // 3. Extract Data safely
    final summaries = summariesAsync.valueOrNull ?? [];

    // Check loading/error
    final isInitialLoading =
        summariesAsync.isLoading && !summariesAsync.hasValue;
    final hasError = summariesAsync.hasError && !summariesAsync.hasValue;

    // Calculate Totals
    double totalRevenue = 0;
    double totalProfit = 0;
    for (var s in summaries) {
      totalRevenue += s.revenue;
      totalProfit += s.profit;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Time Range Selector
          RepaintBoundary(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ReportTimeRange.values.map((range) {
                        final isSelected = _selectedRange == range;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: BounceButton(
                            onTap: () {
                              if (!isSelected) {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _selectedRange = range;
                                });
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? SoftColors.brandPrimary
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.transparent
                                      : SoftColors.border,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: SoftColors.brandPrimary
                                              .withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : [],
                              ),
                              child: Text(
                                _getRangeName(range),
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Colors.white
                                      : SoftColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                // Live Indicator (Hidden per request)
                /*
              if (!isInitialLoading && !hasError)
                Container(...)
              */
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 2. Dashboards (Persistent)
          RepaintBoundary(
            child: Row(
              children: [
                Expanded(
                  child: _DashboardCard(
                    title: "Total Revenue",
                    amount: totalRevenue,
                    icon: Icons.attach_money_rounded,
                    color: SoftColors.brandPrimary,
                  ),
                ),
                const SizedBox(width: 16),
                if (!isEmployee)
                  Expanded(
                    child: _DashboardCard(
                      title: "Net Profit",
                      amount: totalProfit,
                      icon: Icons.trending_up_rounded,
                      color: const Color(0xFF8E24AA),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 3. Navigation Header (Moved BETWEEN Dashboard and List)
          if (showNavigation)
            RepaintBoundary(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Navigation Group
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        BounceButton(
                          onTap: () => _navigate(-1),
                          child: const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Icon(
                              Icons.chevron_left_rounded,
                              size: 28,
                              color: SoftColors.textMain,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getDateLabel(),
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: SoftColors.textMain,
                          ),
                        ),
                        const SizedBox(width: 4),
                        BounceButton(
                          onTap: () {
                            if (canGoForward) _navigate(1);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Icon(
                              Icons.chevron_right_rounded,
                              size: 28,
                              color: canGoForward
                                  ? SoftColors.textMain
                                  : SoftColors.textSecondary.withValues(
                                      alpha: 0.2,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Actions Group
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        BounceButton(
                          onTap: _resetToToday,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  (_focusedDate.year == DateTime.now().year &&
                                      _focusedDate.month ==
                                          DateTime.now().month &&
                                      _focusedDate.day == DateTime.now().day)
                                  ? SoftColors.brandPrimary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color:
                                    (_focusedDate.year == DateTime.now().year &&
                                        _focusedDate.month ==
                                            DateTime.now().month &&
                                        _focusedDate.day == DateTime.now().day)
                                    ? Colors.transparent
                                    : SoftColors.brandPrimary.withValues(
                                        alpha: 0.3,
                                      ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.today_rounded,
                                  size: 14,
                                  color:
                                      (_focusedDate.year ==
                                              DateTime.now().year &&
                                          _focusedDate.month ==
                                              DateTime.now().month &&
                                          _focusedDate.day ==
                                              DateTime.now().day)
                                      ? Colors.white
                                      : SoftColors.brandPrimary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "Today",
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        (_focusedDate.year ==
                                                DateTime.now().year &&
                                            _focusedDate.month ==
                                                DateTime.now().month &&
                                            _focusedDate.day ==
                                                DateTime.now().day)
                                        ? Colors.white
                                        : SoftColors.brandPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        BounceButton(
                          onTap: () => _selectDate(),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: SoftColors.bgLight,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.calendar_month_rounded,
                              size: 18,
                              color: SoftColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 24),

          // 4. Content (List Based Only)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            switchInCurve: Curves.easeInOutCubic,
            switchOutCurve: Curves.easeInOutCubic,

            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, 0.05), // Subtle slide from bottom
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: isInitialLoading
                ? Container(
                    key: const ValueKey('loading'),
                    constraints: const BoxConstraints(minHeight: 400),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: SoftColors.brandPrimary,
                      ),
                    ),
                  )
                : hasError
                ? Container(
                    key: const ValueKey('error'),
                    constraints: const BoxConstraints(minHeight: 400),
                    child: Center(
                      child: Text(
                        "Error loading data: ${summariesAsync.error}",
                      ),
                    ),
                  )
                : summaries.isEmpty
                ? Container(
                    key: const ValueKey('empty'),
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 400),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(
                        SoftColors.cardRadius,
                      ),
                      border: Border.all(color: SoftColors.border),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bar_chart_rounded,
                          size: 48,
                          color: SoftColors.textSecondary.withValues(
                            alpha: 0.3,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "No data for this period",
                          style: GoogleFonts.outfit(
                            color: SoftColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    key: ValueKey(
                      // Semantic Key for Animation Trigger
                      'content-${_focusedDate.toString()}-${_selectedRange.toString()}',
                    ),
                    children: [
                      // Header: Sales Analysis
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Sales Analysis",
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: SoftColors.textMain,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // The LIST is the hero now.
                      _SalesAnalysisList(
                        data: summaries,
                        range: _selectedRange,
                      ),

                      const SizedBox(height: 32),
                      Text(
                        "Top Selling Products",
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: SoftColors.textMain,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _TopProductsList(summaries: summaries),
                      const SizedBox(height: 40),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  String _getRangeName(ReportTimeRange range) {
    switch (range) {
      case ReportTimeRange.weekly:
        return 'Weekly';
      case ReportTimeRange.monthly:
        return 'Monthly';
      case ReportTimeRange.yearly:
        return 'Yearly';
      case ReportTimeRange.allTime:
        return 'All Time';
    }
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final double amount;
  final IconData icon;
  final Color color;

  const _DashboardCard({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(SoftColors.cardRadius),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.outfit(
              color: SoftColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              "\$${amount.toStringAsFixed(2)}",
              style: GoogleFonts.outfit(
                color: SoftColors.textMain,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Renamed from _SalesList to _SalesAnalysisList
class _SalesAnalysisList extends StatelessWidget {
  final List<DailyData> data;
  final ReportTimeRange range;

  const _SalesAnalysisList({required this.data, required this.range});

  @override
  Widget build(BuildContext context) {
    // 1. Filter / Prepare Data
    final activeData = data;

    if (activeData.isEmpty) {
      return const SizedBox.shrink();
    }

    // Ensure min height to prevent jumps
    return Container(
      constraints: const BoxConstraints(minHeight: 400),
      child: range == ReportTimeRange.monthly
          ? _buildMonthlyView(context, activeData)
          : ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              addRepaintBoundaries: true, // GPU Optimization
              itemCount: activeData.length,
              separatorBuilder: (context, index) => Divider(
                color: SoftColors.textSecondary.withValues(alpha: 0.1),
                height: 1,
              ),
              itemBuilder: (context, index) =>
                  _buildDailyItem(activeData[index]),
            ),
    );
  }

  Widget _buildMonthlyView(BuildContext context, List<DailyData> data) {
    final Map<int, List<DailyData>> weeks = {};
    for (var item in data) {
      final weekNum = ((item.date.day - 1) ~/ 7) + 1;
      weeks.putIfAbsent(weekNum, () => []).add(item);
    }
    final sortedWeeks = weeks.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      children: sortedWeeks.map((weekNum) {
        final days = weeks[weekNum]!;
        days.sort((a, b) => b.date.compareTo(a.date));

        final totalRevenue = days.fold<double>(0, (p, c) => p + c.revenue);
        DateTime minDate = days.last.date;
        DateTime maxDate = days.first.date;
        final rangeLabel =
            "${DateFormat('MMM d').format(minDate)} - ${DateFormat('MMM d').format(maxDate)}";

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          color: SoftColors.bgLight.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              title: Row(
                children: [
                  Text(
                    "Week $weekNum",
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      color: SoftColors.textMain,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    rangeLabel,
                    style: GoogleFonts.outfit(
                      color: SoftColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              subtitle: Text(
                "\$${totalRevenue.toStringAsFixed(2)} Revenue",
                style: GoogleFonts.outfit(
                  color: SoftColors.brandPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              children: days.map((day) => _buildDailyItem(day)).toList(),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDailyItem(DailyData item) {
    final isZeroRevenue = item.revenue == 0;
    String topLabel = "";
    String mainLabel = "";

    if (range == ReportTimeRange.yearly || range == ReportTimeRange.allTime) {
      topLabel = DateFormat('y').format(item.date);
      mainLabel = DateFormat('MMM').format(item.date);
    } else {
      topLabel = DateFormat('MMM').format(item.date).toUpperCase();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final itemDate = DateTime(item.date.year, item.date.month, item.date.day);
      if (itemDate == today.subtract(const Duration(days: 1))) {
        mainLabel = "Yest.";
      } else {
        mainLabel = DateFormat('d').format(item.date);
      }
    }

    final textColor = isZeroRevenue
        ? SoftColors.textSecondary.withValues(alpha: 0.5)
        : SoftColors.textMain;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 60,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isZeroRevenue
                  ? SoftColors.bgLight.withValues(alpha: 0.5)
                  : SoftColors.bgLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  topLabel,
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: SoftColors.textSecondary.withValues(
                      alpha: isZeroRevenue ? 0.5 : 1.0,
                    ),
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    mainLabel,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Revenue",
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: SoftColors.textSecondary.withValues(
                      alpha: isZeroRevenue ? 0.5 : 1.0,
                    ),
                  ),
                ),
                Text(
                  isZeroRevenue
                      ? "No Sales"
                      : "\$${item.revenue.toStringAsFixed(2)}",
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "Profit",
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: SoftColors.textSecondary.withValues(
                    alpha: isZeroRevenue ? 0.5 : 1.0,
                  ),
                ),
              ),
              // VIBRANCY FIX: Solid accentPurple for profit
              Text(
                isZeroRevenue ? "-" : "+\$${item.profit.toStringAsFixed(2)}",
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  // SOLID COLOR, NO OPACITY FOR VALUES
                  color: isZeroRevenue
                      ? SoftColors.textSecondary.withValues(alpha: 0.5)
                      : const Color(0xFF8E24AA),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TopProductsList extends StatelessWidget {
  final List<DailyData> summaries;

  const _TopProductsList({required this.summaries});

  @override
  Widget build(BuildContext context) {
    final productStats = <String, _ProductStat>{};
    for (var s in summaries) {
      s.productRanking.forEach((key, qty) {
        if (!productStats.containsKey(key)) {
          productStats[key] = _ProductStat(
            name: key,
            totalQty: 0,
            totalRevenue: 0,
          );
        }
        productStats[key]!.totalQty += qty;
      });
    }

    final sortedStats = productStats.values.toList()
      ..sort((a, b) => b.totalQty.compareTo(a.totalQty));

    if (sortedStats.isEmpty) {
      return Center(
        child: Text(
          "No items sold in this period.",
          style: GoogleFonts.outfit(color: SoftColors.textSecondary),
        ),
      );
    }

    final maxQty = sortedStats.first.totalQty;

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedStats.length > 5 ? 5 : sortedStats.length,
      itemBuilder: (context, index) {
        final stat = sortedStats[index];
        final progress = maxQty > 0 ? stat.totalQty / maxQty : 0.0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: SoftColors.bgLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    stat.name.isNotEmpty ? stat.name[0].toUpperCase() : '?',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      color: SoftColors.brandPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stat.name,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        color: SoftColors.textMain,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: SoftColors.bgLight,
                        valueColor: const AlwaysStoppedAnimation(
                          SoftColors.brandPrimary,
                        ),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${stat.totalQty} Sold",
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: SoftColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProductStat {
  String name;
  int totalQty;
  double totalRevenue;
  _ProductStat({
    required this.name,
    required this.totalQty,
    required this.totalRevenue,
  });
}
