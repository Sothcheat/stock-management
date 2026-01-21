import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../design_system.dart';

class StatsCard extends StatelessWidget {
  final String title;
  final String value;
  final bool isPositive;
  final IconData icon;

  const StatsCard({
    super.key,
    required this.title,
    required this.value,
    this.isPositive = true,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: SoftColors.brandPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: SoftColors.brandPrimary, size: 20),
              ),
              if (isPositive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: SoftColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.trending_up,
                        size: 14,
                        color: SoftColors.success,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "12%",
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: SoftColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: SoftColors.textMain,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: SoftColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
