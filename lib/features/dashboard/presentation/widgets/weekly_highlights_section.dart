import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../design_system.dart';
import '../../data/dashboard_providers.dart';

class WeeklyHighlightsSection extends ConsumerWidget {
  const WeeklyHighlightsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final highlights = ref.watch(weeklyHighlightsProvider);

    if (highlights.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Icon(
                Icons.bar_chart_rounded,
                size: 48,
                color: SoftColors.textSecondary.withValues(alpha: 0.2),
              ),
              const SizedBox(height: 8),
              Text(
                "No sales data yet this week.",
                style: GoogleFonts.outfit(
                  color: SoftColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            "Weekly Highlights",
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: SoftColors.textMain,
            ),
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: highlights.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final stat = highlights[index];
            final number = index + 1;
            final isTop3 = index < 3;

            return SoftCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isTop3
                          ? SoftColors.brandAccent
                          : SoftColors.bgSecondary,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      "#$number",
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        color: isTop3 ? Colors.white : SoftColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stat.productName,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: SoftColors.textMain,
                          ),
                        ),
                        Text(
                          "${stat.quantitySold} units sold",
                          style: GoogleFonts.outfit(
                            color: SoftColors.success,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    NumberFormat.simpleCurrency().format(stat.totalRevenue),
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: SoftColors.textMain,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
