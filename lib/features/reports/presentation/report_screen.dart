import 'widgets/custom_line_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../design_system.dart';
import '../../orders/data/orders_repository.dart';
import '../../orders/domain/order.dart';

class ReportScreen extends ConsumerWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch relevant providers. In a real app, optimize this to avoid re-reads.
    final ordersAsync = ref.watch(ordersStreamProvider);

    return SoftScaffold(
      title: 'Reports',
      showBack: false, // Requirement: Remove back button
      body: ordersAsync.when(
        data: (orders) => _ReportContent(orders: orders),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text("Error: $e")),
      ),
    );
  }
}

enum ReportTimeRange { weekly, monthly, yearly, allTime }

class _ReportContent extends StatefulWidget {
  final List<OrderModel> orders;
  const _ReportContent({required this.orders});

  @override
  State<_ReportContent> createState() => _ReportContentState();
}

class _ReportContentState extends State<_ReportContent> {
  ReportTimeRange _selectedRange = ReportTimeRange.weekly;

  List<OrderModel> _filterOrders(List<OrderModel> orders) {
    final now = DateTime.now();
    return orders.where((o) {
      if (o.status != OrderStatus.completed) return false;
      switch (_selectedRange) {
        case ReportTimeRange.weekly:
          return o.createdAt.isAfter(now.subtract(const Duration(days: 7)));
        case ReportTimeRange.monthly:
          return o.createdAt.month == now.month && o.createdAt.year == now.year;
        case ReportTimeRange.yearly:
          return o.createdAt.year == now.year;
        case ReportTimeRange.allTime:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredOrders = _filterOrders(widget.orders);

    // 1. Calculate Dashboard Metrics
    double totalRevenue = 0;
    double totalCost = 0;

    for (var o in filteredOrders) {
      totalRevenue += o.totalAmount;
      for (var item in o.items) {
        totalCost += (item.costPriceAtSale * item.quantity);
      }
    }

    final netProfit = totalRevenue - totalCost;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time Range Selector
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ReportTimeRange.values.map((range) {
                final isSelected = range == _selectedRange;
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: BounceButton(
                    onTap: () => setState(() => _selectedRange = range),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? SoftColors.brandPrimary
                            : SoftColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: isSelected
                            ? null
                            : Border.all(
                                color: SoftColors.textSecondary.withValues(
                                  alpha: 0.2,
                                ),
                              ),
                      ),
                      child: Text(
                        _getRangeName(range),
                        style: GoogleFonts.outfit(
                          color: isSelected
                              ? Colors.white
                              : SoftColors.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),

          // Dashboards
          Row(
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
              Expanded(
                child: _DashboardCard(
                  title: "Net Profit",
                  amount: netProfit,
                  icon: Icons.trending_up_rounded,
                  color: SoftColors.accentPurple,
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),
          Text(
            "Sales Analysis",
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: SoftColors.textMain,
            ),
          ),
          const SizedBox(height: 16),

          // Line Chart
          SizedBox(
            height: 300,
            child: SoftCard(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
              child: _SalesLineChart(
                orders: filteredOrders,
                range: _selectedRange,
              ),
            ),
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

          _TopProductsList(orders: filteredOrders),
          const SizedBox(height: 40),
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

class _SalesLineChart extends StatelessWidget {
  final List<OrderModel> orders;
  final ReportTimeRange range;

  const _SalesLineChart({required this.orders, required this.range});

  @override
  Widget build(BuildContext context) {
    List<double> dataPoints = [];
    List<String> xLabels = [];

    // Logic to bucket orders based on range
    if (range == ReportTimeRange.weekly) {
      final now = DateTime.now();
      // Find the start of the current week (Sunday)
      // weekday: Mon=1, Sun=7.
      // If today is Sun(7), subtract 0 days. If Mon(1), subtract 1 day.
      final daysSinceSunday = now.weekday == 7 ? 0 : now.weekday;
      final startOfWeek = now.subtract(Duration(days: daysSinceSunday));
      // Normalize start of week to 00:00:00
      final startOfWeekMidnight = DateTime(
        startOfWeek.year,
        startOfWeek.month,
        startOfWeek.day,
      );

      final dailyTimer = List.filled(7, 0.0);

      for (var o in orders) {
        if (o.createdAt.isAfter(startOfWeekMidnight)) {
          final diff = o.createdAt.difference(startOfWeekMidnight).inDays;
          if (diff >= 0 && diff < 7) {
            dailyTimer[diff] += o.totalAmount;
          }
        }
      }

      dataPoints = dailyTimer;

      // Generate Sun-Sat Labels
      for (int i = 0; i < 7; i++) {
        final day = startOfWeekMidnight.add(Duration(days: i));
        xLabels.add(DateFormat('E').format(day));
      }
    } else if (range == ReportTimeRange.monthly) {
      final now = DateTime.now();
      final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
      final monthSales = List.filled(daysInMonth + 1, 0.0);

      for (var o in orders) {
        if (o.createdAt.month == now.month && o.createdAt.year == now.year) {
          monthSales[o.createdAt.day] += o.totalAmount;
        }
      }

      // Remove index 0 (unused)
      dataPoints = monthSales.sublist(1);

      // Generate labels (every 5 days)
      for (int i = 1; i <= daysInMonth; i++) {
        if (i == 1 || i % 5 == 0) {
          xLabels.add(i.toString());
        } else {
          xLabels.add('');
        }
      }
    } else if (range == ReportTimeRange.yearly) {
      // Yearly: Month 1..12 of current year
      final now = DateTime.now();
      final monthSales = List.filled(12, 0.0);
      for (var o in orders) {
        if (o.createdAt.year == now.year) {
          monthSales[o.createdAt.month - 1] += o.totalAmount;
        }
      }
      dataPoints = monthSales;
      xLabels = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
    } else {
      // All Time: Group by Year
      // 1. Find min and max year
      if (orders.isEmpty) {
        dataPoints = [];
        xLabels = [];
      } else {
        // Sort orders by date just in case
        orders.sort((a, b) => a.createdAt.compareTo(b.createdAt));

        // Find range of years
        final minYear = orders.first.createdAt.year;
        final maxYear = orders.last.createdAt.year;
        // Ensure we show at least current year if data is empty or singular
        final todayYear = DateTime.now().year;
        final startYear = minYear;
        final endYear = maxYear > todayYear ? maxYear : todayYear;

        final yearCount = endYear - startYear + 1;
        final yearlySales = List.filled(yearCount, 0.0);

        for (var o in orders) {
          final yearIndex = o.createdAt.year - startYear;
          if (yearIndex >= 0 && yearIndex < yearCount) {
            yearlySales[yearIndex] += o.totalAmount;
          }
        }

        dataPoints = yearlySales;

        // Generate Year Labels
        for (int i = 0; i < yearCount; i++) {
          xLabels.add((startYear + i).toString());
        }
      }
    }

    return CustomLineChart(
      dataPoints: dataPoints,
      xLabels: xLabels,
      height: 250,
      color: SoftColors.brandPrimary,
    );
  }
}

class _TopProductsList extends StatelessWidget {
  final List<OrderModel> orders;

  const _TopProductsList({required this.orders});

  @override
  Widget build(BuildContext context) {
    // 1. Aggregate Products
    final productStats = <String, _ProductStat>{};

    for (var o in orders) {
      for (var item in o.items) {
        if (!productStats.containsKey(item.productId)) {
          productStats[item.productId] = _ProductStat(
            name: item.name,
            totalQty: 0,
            totalRevenue: 0,
          );
        }
        final stat = productStats[item.productId]!;
        stat.totalQty += item.quantity;
        stat.totalRevenue += (item.priceAtSale * item.quantity);
      }
    }

    final sortedStats = productStats.values.toList()
      ..sort(
        (a, b) => b.totalRevenue.compareTo(a.totalRevenue),
      ); // Sort by Revenue

    if (sortedStats.isEmpty) {
      return Center(
        child: Text(
          "No items sold in this period.",
          style: GoogleFonts.outfit(color: SoftColors.textSecondary),
        ),
      );
    }

    // Max revenue for progress bar
    final maxRev = sortedStats.first.totalRevenue;

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedStats.length > 5 ? 5 : sortedStats.length, // Top 5
      itemBuilder: (context, index) {
        final stat = sortedStats[index];
        final progress = maxRev > 0 ? stat.totalRevenue / maxRev : 0.0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              // Thumbnail (Placeholder or could load real if we had image path stored in OrderItem)
              // OrderItem currently doesn't store image path. We'll use an Icon/Initial.
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: SoftColors.bgLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    stat.name[0].toUpperCase(),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          stat.name,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            color: SoftColors.textMain,
                          ),
                        ),
                        Text(
                          "\$${stat.totalRevenue.toStringAsFixed(2)}",
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            color: SoftColors.textMain,
                          ),
                        ),
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
