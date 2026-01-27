import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../design_system.dart';
import '../../data/dashboard_providers.dart';
import '../../../inventory/presentation/providers/inventory_filter_provider.dart';

class StockAlertSection extends ConsumerWidget {
  const StockAlertSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(stockAlertsProvider);

    if (alerts.isEmpty) {
      return const SizedBox.shrink();
    }

    // Limit to 3 items
    final displayAlerts = alerts.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
          child: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: SoftColors.warning,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                "Action Required",
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: SoftColors.textMain,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: SoftColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "${alerts.length}",
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: SoftColors.warning,
                  ),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  // Reset filters and ensure Default Sort
                  final notifier = ref.read(inventoryFilterProvider.notifier);
                  notifier.setSearchQuery('');
                  notifier.selectCategory(null);
                  notifier.setSortOption(InventorySortOption.defaultSort);
                  context.go('/inventory');
                },
                style: TextButton.styleFrom(
                  foregroundColor: SoftColors.brandPrimary,
                  textStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("See All"),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded, size: 16),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Vertical List
        ...displayAlerts.map((item) {
          final product = item.product;
          final variant = item.variant;
          final isOutOfStock = item.isOutOfStock;
          final color = isOutOfStock ? SoftColors.error : SoftColors.warning;

          String subtitle = isOutOfStock
              ? "Restock immediately"
              : "Low stock warning";
          if (variant != null) {
            // "Black • Low stock warning"
            subtitle = "${variant.name} • $subtitle";
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: BounceButton(
              onTap: () => context.push(
                '/inventory/detail',
                extra: product,
              ), // TODO: Navigate to specific variant?
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: SoftColors.textMain.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: color.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Thumbnail
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 56,
                        height: 56,
                        color: SoftColors.bgSecondary,
                        child: (variant?.imagePath ?? product.imagePath) != null
                            ? CachedNetworkImage(
                                imageUrl:
                                    (variant?.imagePath ?? product.imagePath)!,
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: SoftColors.textMain,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: variant != null
                                  ? SoftColors.textSecondary
                                  : (isOutOfStock
                                        ? SoftColors.error
                                        : SoftColors.warning),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            isOutOfStock ? "0" : "${item.currentStock}",
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            "Left",
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 24,
                        color: SoftColors.textSecondary.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
