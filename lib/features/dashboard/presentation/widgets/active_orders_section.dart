import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../design_system.dart';
import '../../../auth/data/providers/auth_providers.dart';
import '../../../auth/domain/user_model.dart';
import '../../../orders/data/firebase_orders_repository.dart';
import '../../../orders/domain/order.dart';
import '../../data/dashboard_providers.dart';

class ActiveOrdersSection extends ConsumerWidget {
  const ActiveOrdersSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeOrders = ref.watch(activeOrdersProvider);
    final userRole = ref.watch(
      currentUserProfileProvider.select((v) => v.value?.role),
    );
    final isOwner = userRole == UserRole.owner || userRole == UserRole.admin;

    if (activeOrders.isEmpty) {
      return const SizedBox.shrink(); // Handled by main empty state if needed
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            "Active Orders",
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: SoftColors.textMain,
            ),
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: activeOrders.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final order = activeOrders[index];
            final isDelivering = order.status == OrderStatus.delivering;

            return BounceButton(
              onTap: () => context.go('/orders/detail', extra: order),
              child: SoftCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.customer.name,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: SoftColors.textMain,
                              ),
                            ),
                            Text(
                              "${order.items.length} Items • \$${order.totalAmount.toStringAsFixed(0)}",
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: SoftColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isDelivering
                                ? SoftColors.brandPrimary.withValues(alpha: 0.1)
                                : SoftColors.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            order.status.name.toUpperCase(),
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDelivering
                                  ? SoftColors.brandPrimary
                                  : SoftColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (isDelivering && isOwner) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            ref
                                .read(ordersRepositoryProvider)
                                .updateOrderStatus(
                                  order.id,
                                  OrderStatus.completed,
                                );
                          },
                          icon: const Icon(
                            Icons.check_circle_outline,
                            size: 16,
                          ),
                          label: const Text("Mark Completed"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: SoftColors.success,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            textStyle: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
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
