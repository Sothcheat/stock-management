import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../design_system.dart';
import '../../orders/data/orders_repository.dart';
import '../../orders/domain/order.dart';

class OrderDetailScreen extends ConsumerWidget {
  final OrderModel order;
  const OrderDetailScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersStreamProvider);

    return ordersAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, s) => Scaffold(body: Center(child: Text("Error: $e"))),
      data: (orders) {
        // Find updated version of this order
        final currentOrder = orders.firstWhere(
          (o) => o.id == order.id,
          orElse: () => order, // Fallback (e.g. if deleted)
        );

        // If order was deleted (and we are still here), show a message or pop
        final exists = orders.any((o) => o.id == order.id);
        if (!exists) {
          return const Scaffold(
            body: Center(child: Text("Order not found (Deleted)")),
          );
        }

        return SoftScaffold(
          title: "Order Details",
          showBack: true,
          actions: [
            BounceButton(
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    backgroundColor: SoftColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        SoftColors.cardRadius,
                      ),
                    ),
                    title: Text(
                      "Delete Order?",
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                    ),
                    content: Text(
                      "This action cannot be undone. Stock will be restored.",
                      style: GoogleFonts.outfit(
                        color: SoftColors.textSecondary,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text("Cancel"),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: Text(
                          "Delete",
                          style: GoogleFonts.outfit(
                            color: SoftColors.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref
                      .read(ordersRepositoryProvider)
                      .deleteOrder(currentOrder);
                  if (context.mounted) context.pop();
                }
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: SoftColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: SoftColors.error,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 24),
          ],
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header (Status & ID)
                SoftCard(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Order ID",
                            style: GoogleFonts.outfit(
                              color: SoftColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            "#${currentOrder.id.substring(0, 5).toUpperCase()}",
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: SoftColors.textMain,
                            ),
                          ),
                        ],
                      ),
                      _StatusBadge(status: currentOrder.status),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Customer Info
                _SectionHeader("Customer Info"),
                SoftCard(
                  child: Column(
                    children: [
                      _InfoRow(
                        Icons.person_outline_rounded,
                        currentOrder.customer.name,
                      ),
                      const SizedBox(height: 12),
                      _InfoRow(
                        Icons.phone_outlined,
                        currentOrder.customer.primaryPhone,
                      ),
                      if (currentOrder.customer.secondaryPhone?.isNotEmpty ==
                          true) ...[
                        const SizedBox(height: 12),
                        _InfoRow(
                          Icons.phone_android_rounded,
                          currentOrder.customer.secondaryPhone!,
                        ),
                      ],
                      const SizedBox(height: 12),
                      _InfoRow(
                        Icons.location_on_outlined,
                        currentOrder.deliveryAddress,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
                // Items
                _SectionHeader("Order Items"),

                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: currentOrder.items.length,
                  itemBuilder: (context, index) {
                    final item = currentOrder.items[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SoftCard(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: SoftColors.brandPrimary.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "x${item.quantity}",
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  color: SoftColors.brandPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: SoftColors.textMain,
                                    ),
                                  ),
                                  Text(
                                    item.variantName,
                                    style: GoogleFonts.outfit(
                                      color: SoftColors.textSecondary,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              "\$${(item.priceAtSale * item.quantity).toStringAsFixed(2)}",
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: SoftColors.textMain,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: SoftColors.brandPrimary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: SoftColors.brandPrimary.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Total Amount",
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: SoftColors.textMain,
                        ),
                      ),
                      Text(
                        "\$${currentOrder.totalAmount.toStringAsFixed(2)}",
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: SoftColors.brandPrimary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                // Actions (Change Status)
                if (currentOrder.status == OrderStatus.prepping)
                  SoftButton(
                    label: "Mark as Delivering",
                    icon: Icons.local_shipping_outlined,
                    backgroundColor: SoftColors.brandPrimary,
                    onTap: () {
                      ref
                          .read(ordersRepositoryProvider)
                          .updateOrderStatus(
                            currentOrder.id,
                            OrderStatus.delivering,
                          );
                    },
                  ),

                if (currentOrder.status == OrderStatus.delivering)
                  SoftButton(
                    label: "Mark as Completed",
                    icon: Icons.check_circle_outline_rounded,
                    backgroundColor: SoftColors.success,
                    textColor: Colors.white,
                    onTap: () {
                      ref
                          .read(ordersRepositoryProvider)
                          .updateOrderStatus(
                            currentOrder.id,
                            OrderStatus.completed,
                          );
                    },
                  ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 4),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: SoftColors.textMain,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow(this.icon, this.text);
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: SoftColors.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.outfit(fontSize: 16, color: SoftColors.textMain),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final OrderStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case OrderStatus.prepping:
        color = SoftColors.warning;
        break;
      case OrderStatus.delivering:
        color = SoftColors.brandPrimary;
        break;
      case OrderStatus.completed:
        color = SoftColors.success;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: GoogleFonts.outfit(
          color: color,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          fontSize: 12,
        ),
      ),
    );
  }
}
