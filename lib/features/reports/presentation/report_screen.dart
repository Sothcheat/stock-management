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
import '../../../../core/utils/date_utils.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../inventory/data/inventory_repository.dart';
import '../../inventory/domain/product.dart';

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  ReportTimeRange _selectedRange = ReportTimeRange.weekly;
  DateTime _focusedDate = DateTime.now();
  bool _isDescending = true;
  int _lastNavigationDirection = 1; // 1 = forward, -1 = backward

  void _navigate(int direction) {
    if (direction == 0) return;
    HapticFeedback.lightImpact();
    setState(() {
      _lastNavigationDirection = direction;
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
        final start = DateUtilsHelper.getStartOfWeek(_focusedDate);
        final end = DateUtilsHelper.getEndOfWeek(_focusedDate);
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
    // 1. Fetch Data
    final isMonthly = _selectedRange == ReportTimeRange.monthly;
    AsyncValue<List<WeeklyGroup>>? monthlyAsync;
    AsyncValue<List<DailyData>>? dailyAsync;

    if (isMonthly) {
      monthlyAsync = ref.watch(monthlyReportProvider(_focusedDate));
    } else {
      dailyAsync = ref.watch(
        _selectedRange == ReportTimeRange.weekly
            ? weeklyReportProvider(_focusedDate)
            : _selectedRange == ReportTimeRange.yearly
            ? yearlyReportProvider(_focusedDate)
            : allTimeReportProvider(_focusedDate),
      );
    }

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

    // Extract Data
    List<DailyData> flatDailyData = [];
    List<WeeklyGroup> monthlyGroups = [];
    bool isLoading = false;
    bool hasError = false;

    if (isMonthly) {
      isLoading = monthlyAsync?.isLoading ?? false;
      hasError = monthlyAsync?.hasError ?? false;
      monthlyGroups = monthlyAsync?.valueOrNull ?? [];
      for (var group in monthlyGroups) {
        flatDailyData.addAll(group.days);
      }
      flatDailyData.sort((a, b) => b.date.compareTo(a.date));
    } else {
      isLoading = dailyAsync?.isLoading ?? false;
      hasError = dailyAsync?.hasError ?? false;
      flatDailyData = dailyAsync?.valueOrNull ?? [];
    }

    // Totals
    double totalRevenue = 0;
    double totalProfit = 0;
    for (var s in flatDailyData) {
      totalRevenue += s.revenue.clamp(0.0, double.infinity);
      totalProfit += s.profit.clamp(0.0, double.infinity);
    }

    final isInitialLoading =
        isLoading && flatDailyData.isEmpty && monthlyGroups.isEmpty;
    final isEmpty =
        !isLoading &&
        !hasError &&
        flatDailyData.isEmpty &&
        monthlyGroups.isEmpty;

    return SoftSliverScaffold(
      title: 'Reports',
      showBack: false,
      slivers: [
        // 1. Time Range Selector (Box)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
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
                                    color: SoftColors.brandPrimary.withValues(
                                      alpha: 0.3,
                                    ),
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
        ),

        // 2. Dashboards (Box)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
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
        ),

        const SliverPadding(padding: EdgeInsets.only(bottom: 24)),

        // 3. Navigation Header (Pinned)
        if (showNavigation)
          SliverPersistentHeader(
            pinned: true,
            delegate: _ReportNavigationDelegate(
              label: _getDateLabel(),
              canGoForward: canGoForward,
              navigationDirection: _lastNavigationDirection,
              onNavigate: _navigate,
              onReset: _resetToToday,
              onSelectDate: _selectDate,
              isToday:
                  _focusedDate.year == now.year &&
                  _focusedDate.month == now.month &&
                  _focusedDate.day == now.day,
            ),
          ),

        // 4. Content States
        if (isInitialLoading)
          SliverToBoxAdapter(
            child: SoftListSwitcher(
              direction: _lastNavigationDirection,
              childKey: const ValueKey('loading'),
              child: Padding(
                padding: const EdgeInsets.only(top: 24),
                child: const SoftShimmer.dailyRow(itemCount: 6),
              ),
            ),
          )
        else if (hasError)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text("Error loading data")),
          )
        else if (isEmpty)
          SliverToBoxAdapter(
            child: SoftListSwitcher(
              direction: _lastNavigationDirection,
              childKey: const ValueKey('empty'),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 300),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(SoftColors.cardRadius),
                    border: Border.all(color: SoftColors.border),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bar_chart_rounded,
                        size: 48,
                        color: SoftColors.textSecondary.withValues(alpha: 0.3),
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
                ),
              ),
            ),
          )
        else ...[
          // Header: Sales Analysis
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
            ),
          ),

          // LIST: Monthly vs Daily
          if (isMonthly)
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SoftFadeInSlide(
                    index: index,
                    child: _buildMonthlyItem(context, monthlyGroups[index]),
                  ),
                );
              }, childCount: monthlyGroups.length),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                // Sort Logic Inline or Pre-calc?
                // Better to pre-calc.
                final activeData = List<DailyData>.from(flatDailyData);
                activeData.sort(
                  (a, b) => _isDescending
                      ? b.date.compareTo(a.date)
                      : a.date.compareTo(b.date),
                );
                if (index >= activeData.length) return null;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SoftFadeInSlide(
                    index: index,
                    child: Column(
                      children: [
                        _DailyReportItem(
                          item: activeData[index],
                          isYearlyMode:
                              _selectedRange == ReportTimeRange.yearly ||
                              _selectedRange == ReportTimeRange.allTime,
                        ),
                        Divider(
                          color: SoftColors.textSecondary.withValues(
                            alpha: 0.1,
                          ),
                          height: 1,
                        ),
                      ],
                    ),
                  ),
                );
              }, childCount: flatDailyData.length),
            ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),

          // Header: Top Products
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                "Top Selling Products",
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: SoftColors.textMain,
                ),
              ),
            ),
          ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 16)),

          // Top Products List
          _buildSliverTopProductsList(flatDailyData),
        ],
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

  // Helper for Monthly Item (Ported from _buildMonthlyView logic)
  Widget _buildMonthlyItem(BuildContext context, WeeklyGroup weekGroup) {
    // ... (Implementation same as existing but returning single widget) ...
    // Actually, standard ExpantionTile in SliverList is fine.
    final start = weekGroup.weekStart;

    int displayWeekNumber = DateUtilsHelper.getWeekOfYear(start);
    if (displayWeekNumber > 52 && start.month == 1) {
      displayWeekNumber = 1;
    }

    final isEmpty = weekGroup.totalRevenue == 0;
    final contentOpacity = isEmpty ? 0.6 : 1.0;
    final textColor = isEmpty ? SoftColors.textSecondary : SoftColors.textMain;
    final secondaryTextColor = SoftColors.textSecondary;

    final thumbnailColor = isEmpty
        ? SoftColors.bgLight.withValues(alpha: 0.5)
        : SoftColors.bgLight;

    return Column(
      children: [
        Opacity(
          opacity: contentOpacity,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                enabled: !isEmpty,
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                childrenPadding: const EdgeInsets.only(bottom: 12),
                collapsedShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                trailing: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: SoftColors.textSecondary.withValues(alpha: 0.5),
                ),
                title: Row(
                  children: [
                    Container(
                      width: 60,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: thumbnailColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            "WEEK",
                            style: GoogleFonts.outfit(
                              color: secondaryTextColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              "$displayWeekNumber",
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                color: textColor,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Revenue",
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: secondaryTextColor.withValues(
                                    alpha: 0.7,
                                  ),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isEmpty
                                    ? "No Sales"
                                    : "\$${weekGroup.totalRevenue.clamp(0.0, double.infinity).toStringAsFixed(2)}",
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: isEmpty
                                      ? SoftColors.textSecondary
                                      : SoftColors.textMain,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                "Profit",
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: secondaryTextColor.withValues(
                                    alpha: 0.7,
                                  ),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isEmpty
                                    ? "-"
                                    : "${weekGroup.totalProfit >= 0 ? '+' : ''}\$${weekGroup.totalProfit.clamp(0.0, double.infinity).toStringAsFixed(2)}",
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: isEmpty
                                      ? SoftColors.textSecondary
                                      : const Color(0xFFB8860B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                children: weekGroup.days.asMap().entries.map((entry) {
                  return SoftFadeInSlide(
                    index: entry.key,
                    child: _DailyReportItem(
                      item: entry.value,
                      isYearlyMode: false,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        Divider(
          color: SoftColors.textSecondary.withValues(alpha: 0.1),
          height: 1,
        ),
      ],
    );
  }

  Widget _buildSliverTopProductsList(List<DailyData> summaries) {
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
      return SliverToBoxAdapter(
        child: SoftAnimatedEmpty(
          icon: Icons.shopping_cart_outlined,
          message: 'No items sold in this period.',
        ),
      );
    }

    // 3. Logic: Top 5 + View All
    final displayedStats = sortedStats.take(5).toList();
    final maxQty = displayedStats.first.totalQty;
    final showViewAll = sortedStats.length > 5;

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == displayedStats.length) {
            // View All Button
            if (showViewAll) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                child: TextButton(
                  onPressed: () =>
                      _showAllProductsSheet(context, sortedStats, productsMap),
                  style: TextButton.styleFrom(
                    foregroundColor: SoftColors.brandPrimary,
                    textStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                  ),
                  child: Text("View All ${sortedStats.length} Products"),
                ),
              );
            }
            return const SizedBox(height: 40);
          }
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SoftFadeInSlide(
              index: index,
              child: _ProductListItem(
                stat: displayedStats[index],
                maxQty: maxQty,
                rank: index + 1,
                product: productsMap[displayedStats[index].name],
              ),
            ),
          );
        },
        childCount: displayedStats.length + 1, // +1 for Footer
      ),
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

class _ReportNavigationDelegate extends SliverPersistentHeaderDelegate {
  final String label;
  final bool canGoForward;
  final bool isToday;
  final int navigationDirection; // 1 = forward, -1 = backward
  final Function(int) onNavigate;
  final VoidCallback onReset;
  final VoidCallback onSelectDate;

  _ReportNavigationDelegate({
    required this.label,
    required this.canGoForward,
    required this.isToday,
    required this.navigationDirection,
    required this.onNavigate,
    required this.onReset,
    required this.onSelectDate,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      height: maxExtent,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      color: SoftColors
          .background, // Match scaffold background (or white if needed for contrast)
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: SoftColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Navigation Group
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                BounceButton(
                  onTap: () => onNavigate(-1),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: 8.0,
                      horizontal: 12,
                    ),
                    child: Icon(
                      Icons.chevron_left_rounded,
                      size: 28,
                      color: SoftColors.textMain,
                    ),
                  ),
                ),
                // Warp Date Label with AnimatedSwitcher
                Container(
                  constraints: const BoxConstraints(minWidth: 120),
                  alignment: Alignment.center,
                  child: RepaintBoundary(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      switchInCurve: Curves.easeInOutQuart,
                      switchOutCurve: Curves.easeInOutQuart,
                      transitionBuilder: (child, animation) {
                        // Directional slide: forward=slides LEFT, backward=slides RIGHT
                        final slideOffset = navigationDirection > 0
                            ? Tween<Offset>(
                                begin: const Offset(0.4, 0), // Enter from right
                                end: Offset.zero,
                              )
                            : Tween<Offset>(
                                begin: const Offset(-0.4, 0), // Enter from left
                                end: Offset.zero,
                              );

                        return SlideTransition(
                          position: slideOffset.animate(animation),
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        );
                      },
                      child: Text(
                        label,
                        key: ValueKey<String>(label),
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: SoftColors.textMain,
                        ),
                      ),
                    ),
                  ),
                ),
                BounceButton(
                  onTap: () {
                    if (canGoForward) onNavigate(1);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8.0,
                      horizontal: 12,
                    ),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 28,
                      color: canGoForward
                          ? SoftColors.textMain
                          : SoftColors.textSecondary.withValues(alpha: 0.2),
                    ),
                  ),
                ),
              ],
            ),

            // Actions Group
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BounceButton(
                    onTap: onReset,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isToday
                            ? SoftColors.brandPrimary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isToday
                              ? Colors.transparent
                              : SoftColors.brandPrimary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.today_rounded,
                            size: 14,
                            color: isToday
                                ? Colors.white
                                : SoftColors.brandPrimary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "Today",
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isToday
                                  ? Colors.white
                                  : SoftColors.brandPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  BounceButton(
                    onTap: onSelectDate,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
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
            ),
          ],
        ),
      ),
    );
  }

  @override
  double get maxExtent => 72;

  @override
  double get minExtent => 72;

  @override
  bool shouldRebuild(covariant _ReportNavigationDelegate oldDelegate) {
    return oldDelegate.label != label ||
        oldDelegate.canGoForward != canGoForward ||
        oldDelegate.isToday != isToday;
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

// Extracted Daily Item Widget
class _DailyReportItem extends StatelessWidget {
  final DailyData item;
  final bool isYearlyMode;

  const _DailyReportItem({required this.item, required this.isYearlyMode});

  @override
  Widget build(BuildContext context) {
    final isZeroRevenue = item.revenue == 0;
    String topLabel = "";
    String mainLabel = "";

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final itemDate = DateTime(item.date.year, item.date.month, item.date.day);
    final isToday = itemDate == today;

    if (isYearlyMode) {
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
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
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
                      : "\$${item.revenue.clamp(0.0, double.infinity).toStringAsFixed(2)}",
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
                isZeroRevenue
                    ? "-"
                    : "+\$${item.profit.clamp(0.0, double.infinity).toStringAsFixed(2)}",
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
