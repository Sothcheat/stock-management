import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../../design_system.dart';
import '../../auth/data/providers/auth_providers.dart';
import '../../auth/domain/user_model.dart';
import '../../reports/domain/daily_summary.dart';
import '../../reports/domain/report_time_range.dart';
import 'providers/reports_provider.dart';
// import 'widgets/custom_line_chart.dart'; // REMOVED
import 'package:cached_network_image/cached_network_image.dart';
import '../../inventory/data/inventory_repository.dart';
import '../../inventory/domain/product.dart';

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
  bool _isDescending = true;

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Time Range Selector
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
          child: RepaintBoundary(
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
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                            color: const Color(0xFFD6943C),
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
                                  padding: EdgeInsets.symmetric(vertical: 8.0),
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
                                        (_focusedDate.year ==
                                                DateTime.now().year &&
                                            _focusedDate.month ==
                                                DateTime.now().month &&
                                            _focusedDate.day ==
                                                DateTime.now().day)
                                        ? SoftColors.brandPrimary
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color:
                                          (_focusedDate.year ==
                                                  DateTime.now().year &&
                                              _focusedDate.month ==
                                                  DateTime.now().month &&
                                              _focusedDate.day ==
                                                  DateTime.now().day)
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

                const SizedBox(height: 16),

                // 4. Content (List Based Only)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  switchInCurve: Curves.easeInOutCubic,
                  switchOutCurve: Curves.easeInOutCubic,

                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(
                                0.0,
                                0.02,
                              ), // Reduced slide dist (was 0.05)
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
                      : RepaintBoundary(
                          key: ValueKey(
                            // Semantic Key for Animation Trigger
                            'content-${_focusedDate.toString()}-${_selectedRange.toString()}',
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Sales Analysis",
                                    style: GoogleFonts.outfit(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: SoftColors.textMain,
                                    ),
                                  ),
                                  BounceButton(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      setState(() {
                                        _isDescending = !_isDescending;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: SoftColors.bgLight,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        _isDescending
                                            ? Icons.sort_rounded
                                            : Icons.calendar_today_rounded,
                                        color: SoftColors.textSecondary,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // The LIST is the hero now.
                              _SalesAnalysisList(
                                key: ValueKey("$_focusedDate-$_isDescending"),
                                data: summaries,
                                range: _selectedRange,
                                isDescending: _isDescending,
                              ),

                              const SizedBox(height: 32),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Top Selling Products",
                                    style: GoogleFonts.outfit(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: SoftColors.textMain,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _TopProductsList(summaries: summaries),
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
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
  final bool isDescending;

  const _SalesAnalysisList({
    super.key,
    required this.data,
    required this.range,
    required this.isDescending,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Sort Data
    final activeData = List<DailyData>.from(data);
    activeData.sort(
      (a, b) =>
          isDescending ? b.date.compareTo(a.date) : a.date.compareTo(b.date),
    );

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

    // Sort weeks based on preference
    final sortedWeeks = weeks.keys.toList();
    sortedWeeks.sort((a, b) => isDescending ? b.compareTo(a) : a.compareTo(b));

    return Column(
      children: sortedWeeks.map((weekNum) {
        final days = weeks[weekNum]!;
        // Sort days within week based on preference
        days.sort(
          (a, b) => isDescending
              ? b.date.compareTo(a.date)
              : a.date.compareTo(b.date),
        );

        final totalRevenue = days.fold<double>(0, (p, c) => p + c.revenue);
        // Be careful with min/max if sorted descending, first is max, last is min.
        // It's safer to recalculate explicitly or check sorting.
        DateTime minDate = days
            .map((e) => e.date)
            .reduce((a, b) => a.isBefore(b) ? a : b);
        DateTime maxDate = days
            .map((e) => e.date)
            .reduce((a, b) => a.isAfter(b) ? a : b);

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

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final itemDate = DateTime(item.date.year, item.date.month, item.date.day);
    final isToday = itemDate == today;

    if (range == ReportTimeRange.yearly || range == ReportTimeRange.allTime) {
      topLabel = DateFormat('y').format(item.date);
      mainLabel = DateFormat('MMM').format(item.date);
    } else {
      topLabel = DateFormat('MMM').format(item.date).toUpperCase();
      if (isToday) {
        mainLabel =
            "TODAY"; // All caps tiny label handled by font size? No, mainLabel needs to be "25" or similar?
        // Request says: Label: Add a small "TODAY" text label in tiny all-caps next to the date.
        // My previous implementation put "Today" as the MAIN label.
        // Let's stick to Date number for main label, and put TODAY in topLabel or separate?
        // Actually, the previous code had logic: if (isToday) mainLabel = "Today";
        // Let's adapt. The user said "Add a small 'TODAY' text label in tiny all-caps next to the date."
        // This suggests the date number should be visible? Or maybe "TODAY" replaces the date number?
        // "next to the date" implies: [JAN] [25 TODAY] ?
        // Let's try putting TODAY in the top label or replacing the top label?
        // Top label is "JAN". Main is "25".
        // Let's behave as requested: "Tiny all-caps next to the date".
        // If I make mainLabel = "25", I can add "TODAY" in the column.
        mainLabel = DateFormat('d').format(item.date);
      } else if (itemDate == today.subtract(const Duration(days: 1))) {
        mainLabel = "Yest.";
      } else {
        mainLabel = DateFormat('d').format(item.date);
      }
    }

    final textColor = isZeroRevenue
        ? SoftColors.textSecondary.withValues(alpha: 0.5)
        : SoftColors.textMain;

    // Highlight Colors
    final rowBgColor = isToday
        ? SoftColors.brandPrimary.withValues(alpha: 0.08)
        : Colors.transparent;

    final dateBoxColor = isZeroRevenue
        ? SoftColors.bgLight.withValues(alpha: 0.5)
        : SoftColors.bgLight;

    final borderColor = isToday
        ? SoftColors.brandPrimary.withValues(alpha: 0.2)
        : Colors.transparent;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: rowBgColor,
        borderRadius: BorderRadius.circular(12),
        border: isToday ? Border.all(color: borderColor) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: dateBoxColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  topLabel,
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isToday
                        ? SoftColors.brandPrimary
                        : SoftColors.textSecondary.withValues(
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
                      color: isToday ? SoftColors.brandPrimary : textColor,
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
                      : const Color(0xFFA6722E),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TopProductsList extends ConsumerWidget {
  final List<DailyData> summaries;

  const _TopProductsList({required this.summaries});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 0. Live Inventory Bridge
    final productsMapAsync = ref.watch(productsMapProvider);
    final productsMap = productsMapAsync.valueOrNull ?? {};

    // 1. Aggregate Data
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

    // 2. Sort Descending
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

    // 3. Logic: Top 5 + View All
    final displayedStats = sortedStats.take(5).toList();
    final maxQty = displayedStats.first.totalQty;
    final showViewAll = sortedStats.length > 5;

    return Column(
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: displayedStats.length,
          itemBuilder: (context, index) {
            return _ProductListItem(
              stat: displayedStats[index],
              maxQty: maxQty,
              rank: index + 1,
              product: productsMap[displayedStats[index].name],
            );
          },
        ),
        if (showViewAll) ...[
          const SizedBox(height: 16),
          TextButton(
            onPressed: () =>
                _showAllProductsSheet(context, sortedStats, productsMap),
            style: TextButton.styleFrom(
              foregroundColor: SoftColors.brandPrimary,
              textStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            child: Text("View All ${sortedStats.length} Products"),
          ),
        ],
      ],
    );
  }

  void _showAllProductsSheet(
    BuildContext context,
    List<_ProductStat> allStats,
    Map<String, Product> productsMap,
  ) {
    final maxQty = allStats.first.totalQty;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "All Products",
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: SoftColors.textMain,
                        ),
                      ),
                      Text(
                        "${allStats.length} Items",
                        style: GoogleFonts.outfit(
                          color: SoftColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.all(24),
                    itemCount: allStats.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 24),
                    itemBuilder: (context, index) {
                      return _ProductListItem(
                        stat: allStats[index],
                        maxQty: maxQty,
                        rank: index + 1,
                        product: productsMap[allStats[index].name],
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _ProductListItem extends ConsumerWidget {
  final _ProductStat stat;
  final int maxQty;
  final int rank;
  final Product? product; // Nullable if deleted

  const _ProductListItem({
    required this.stat,
    required this.maxQty,
    required this.rank,
    this.product,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = maxQty > 0 ? stat.totalQty / maxQty : 0.0;
    final isTop3 = rank <= 3;
    final isOutOfStock = product != null && product!.totalStock <= 0;
    final isLowStock =
        product != null && product!.totalStock <= 5 && !isOutOfStock;

    // Avg Profit Logic
    String? profitPerUnitLabel;
    if (product != null) {
      final margin = product!.finalPrice - product!.costPrice;
      profitPerUnitLabel = "Avg. Profit/Unit: \$${margin.toStringAsFixed(2)}";
    }

    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: product == null
              ? null
              : () {
                  context.push('/inventory/detail', extra: product);
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: Row(
              children: [
                // 4. Rank Badge & Thumbnail
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _ProductThumbnail(
                      product: product,
                      fallbackName: stat.name,
                    ),
                    if (isTop3)
                      Positioned(
                        top: -6,
                        left: -6,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: rank == 1
                                ? const Color(0xFFFFD700) // Gold
                                : rank == 2
                                ? const Color(0xFFC0C0C0) // Silver
                                : const Color(0xFFCD7F32), // Bronze
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              "$rank",
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              stat.name,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                color: SoftColors.textMain,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isOutOfStock) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: SoftColors.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: SoftColors.error.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                              ),
                              child: Text(
                                "Out of Stock",
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: SoftColors.error,
                                ),
                              ),
                            ),
                          ] else if (isLowStock) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: SoftColors.warning.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: SoftColors.warning.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                              ),
                              child: Text(
                                "Low Stock",
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: SoftColors.warning,
                                ),
                              ),
                            ),
                          ],
                        ],
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "${stat.totalQty} Sold",
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: SoftColors.textSecondary,
                            ),
                          ),
                          if (profitPerUnitLabel != null)
                            Text(
                              profitPerUnitLabel,
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: const Color(0xFFA6722E), // Profit Color
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 24,
                  color: SoftColors.textSecondary.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductThumbnail extends StatelessWidget {
  final Product? product;
  final String fallbackName;

  const _ProductThumbnail({this.product, required this.fallbackName});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: SoftColors.bgLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SoftColors.border.withValues(alpha: 0.5)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child:
            product != null &&
                product!.imagePath != null &&
                product!.imagePath!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: product!.imagePath!,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    ColoredBox(color: Colors.grey[200]!),
                errorWidget: (context, url, error) => _buildLetterFallback(),
              )
            : _buildLetterFallback(),
      ),
    );
  }

  Widget _buildLetterFallback() {
    return Center(
      child: Text(
        fallbackName.isNotEmpty ? fallbackName[0].toUpperCase() : "?",
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.bold,
          color: SoftColors.brandPrimary,
        ),
      ),
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
