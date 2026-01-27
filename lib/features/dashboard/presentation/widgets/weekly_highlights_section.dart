import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

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
            final product = stat.product;

            // Determine stock status/color (Legacy badges style from Inventory)
            final isLowStock = product.totalStock <= product.lowStockThreshold;
            final isOutOfStock = product.totalStock == 0;
            final badgeColor = isOutOfStock
                ? SoftColors.error
                : (isLowStock ? SoftColors.warning : SoftColors.success);

            return BounceButton(
              onTap: () => context.push('/inventory/detail', extra: product),
              child: SoftCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Thumbnail
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 56,
                        height: 56,
                        color: SoftColors.bgSecondary,
                        child: product.imagePath != null
                            ? CachedNetworkImage(
                                imageUrl: product.imagePath!,
                                fit: BoxFit.cover,
                              )
                            : Icon(
                                Icons.image_not_supported,
                                color: SoftColors.textSecondary.withValues(
                                  alpha: 0.5,
                                ),
                                size: 24,
                              ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: SoftColors.textMain,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Price Row
                          Row(
                            children: [
                              Text(
                                "\$${product.finalPrice.toStringAsFixed(2)}",
                                style: GoogleFonts.outfit(
                                  color: SoftColors.textMain, // Changed to main
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (product.hasDiscount) ...[
                                const SizedBox(width: 8),
                                Text(
                                  "\$${product.price.toStringAsFixed(2)}",
                                  style: GoogleFonts.outfit(
                                    color: SoftColors.textSecondary.withValues(
                                      alpha: 0.8,
                                    ),
                                    fontSize: 12,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Trailing: Stock Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isOutOfStock
                            ? "Out of Stock"
                            : (isLowStock
                                  ? "Low Stock"
                                  : "${product.totalStock} in stock"),
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: badgeColor,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Icon(
                        Icons.chevron_right,
                        color: SoftColors.textSecondary.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
