import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../orders/data/orders_repository.dart';
import '../../orders/domain/order.dart';

class ReportScreen extends ConsumerWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Reports',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: ordersAsync.when(
        data: (orders) => _ReportContent(orders: orders),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text("Error: $e")),
      ),
    );
  }
}

class _ReportContent extends StatelessWidget {
  final List<OrderModel> orders;
  const _ReportContent({required this.orders});

  @override
  Widget build(BuildContext context) {
    // 1. Calculate Total Sales
    final totalSales = orders
        .where((o) => o.status == OrderStatus.completed)
        .fold(0.0, (sum, o) => sum + o.totalAmount);

    // 2. Prepare Data for Chart (Daily Sales for last 7 days)
    final now = DateTime.now();
    final List<double> weeklySales = List.filled(7, 0.0);
    final List<String> weekDays = [];

    for (int i = 0; i < 7; i++) {
      final day = now.subtract(Duration(days: 6 - i));
      weekDays.add(DateFormat('E').format(day)); // Mon, Tue...

      final dailyTotal = orders
          .where(
            (o) =>
                o.status == OrderStatus.completed &&
                o.createdAt.year == day.year &&
                o.createdAt.month == day.month &&
                o.createdAt.day == day.day,
          )
          .fold(0.0, (sum, o) => sum + o.totalAmount);

      weeklySales[i] = dailyTotal;
    }

    final maxSale = weeklySales.reduce(
      (curr, next) => curr > next ? curr : next,
    );
    final maxY = maxSale > 0 ? maxSale * 1.2 : 100.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primary, AppTheme.primary.withOpacity(0.8)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                const Text(
                  "Total Revenue (All Time)",
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  "\$${totalSales.toStringAsFixed(2)}",
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
          Text(
            "Weekly Sales",
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          Container(
            height: 300,
            padding: const EdgeInsets.only(right: 16, left: 8, bottom: 8),
            child: BarChart(
              BarChartData(
                maxY: maxY,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => Colors.blueGrey,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 &&
                            value.toInt() < weekDays.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              weekDays[value.toInt()],
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return DataEntry(value: value);
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                barGroups: weeklySales.asMap().entries.map((e) {
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value,
                        color: AppTheme.primary,
                        width: 16,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxY,
                          color: Colors.grey[100],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DataEntry extends StatelessWidget {
  final double value;
  const DataEntry({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    if (value == 0) return const SizedBox();
    return Text(
      NumberFormat.compactSimpleCurrency().format(value),
      style: const TextStyle(fontSize: 10, color: Colors.grey),
    );
  }
}
