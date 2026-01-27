import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../design_system.dart';
import '../../orders/data/firebase_orders_repository.dart';
import '../../orders/domain/order.dart';
import '../../auth/data/providers/auth_providers.dart';
import '../../auth/domain/user_model.dart';
import 'providers/order_history_controller.dart';

class OrderDetailScreen extends ConsumerWidget {
  final OrderModel order;
  const OrderDetailScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fix: Use specific order stream to avoid "Order not found" when order is not in Active Stream
    final orderAsync = ref.watch(orderStreamProvider(order.id));
    final userProfileAsync = ref.watch(currentUserProfileProvider);

    // Security: Wait for user profile to load to prevent showing Owner data to Employees
    if (userProfileAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final user = userProfileAsync.value;
    final isEmployee = user?.role == UserRole.employee;

    return orderAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, s) => Scaffold(body: Center(child: Text("Error: $e"))),
      data: (currentOrder) {
        if (currentOrder == null) {
          return const Scaffold(
            body: Center(child: Text("Order not found (Deleted)")),
          );
        }

        return SoftScaffold(
          title: "Order Details",
          showBack: true,
          actions: [
            if (!isEmployee) ...[
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

                    // Update Local History State immediately if it exists
                    ref
                        .read(orderHistoryProvider.notifier)
                        .removeOrderLocally(currentOrder.id);

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
          ],
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header (Status & ID)
                // Header (Status & ID) - Matching New Card Style
                SoftCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "#${currentOrder.id.substring(0, 5).toUpperCase()}",
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: SoftColors.brandPrimary,
                            ),
                          ),
                          _StatusBadge(status: currentOrder.status),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        currentOrder.customer.name,
                        style: GoogleFonts.outfit(
                          color: SoftColors.textMain,
                          fontSize: 24, // Large
                          fontWeight: FontWeight.w800, // Extra Bold
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 16,
                            color: SoftColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat(
                              'MMMM dd, yyyy • h:mm a',
                            ).format(currentOrder.createdAt),
                            style: GoogleFonts.outfit(
                              color: SoftColors.textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Customer Info (Reduced to Contact Details since Name is in Header now)
                _SectionHeader("Contact Details"),
                SoftCard(
                  child: Column(
                    children: [
                      // Map Name Row removed from here since it is in header
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
                      if (currentOrder.note != null &&
                          currentOrder.note!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 12),
                        _InfoRow(Icons.note_outlined, currentOrder.note!),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 32),
                // Items
                _SectionHeader("Digital Receipt"),

                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: currentOrder.items.length,
                  itemBuilder: (context, index) {
                    final item = currentOrder.items[index];
                    final totalItemPrice = item.priceAtSale * item.quantity;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SoftCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                    "${item.quantity}x",
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      color: SoftColors.brandPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                      if (item.discountAtSale > 0)
                                        Text(
                                          "Desc: -\$${(item.discountAtSale * item.quantity).toStringAsFixed(2)}",
                                          style: GoogleFonts.outfit(
                                            color: SoftColors.success,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      "\$${totalItemPrice.toStringAsFixed(2)}",
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: SoftColors.textMain,
                                      ),
                                    ),
                                    Text(
                                      "@ \$${item.priceAtSale.toStringAsFixed(2)}/ea",
                                      style: GoogleFonts.outfit(
                                        color: SoftColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: SoftColors.border),
                  ),
                  child: Column(
                    children: [
                      _SummaryRow(
                        "Subtotal",
                        "\$${currentOrder.items.fold(0.0, (p, c) => p + (c.priceAtSale * c.quantity)).toStringAsFixed(2)}",
                      ),
                      const SizedBox(height: 8),
                      _SummaryRow(
                        "Delivery Fee",
                        "\$${currentOrder.logistics.deliveryFeeCharged.toStringAsFixed(2)}",
                        isHighlight: true,
                        color: SoftColors.brandPrimary,
                      ),
                      const Divider(height: 24),
                      Row(
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
                    ],
                  ),
                ),

                // Profit Analysis (Owner Only)
                if (!isEmployee) ...[
                  const SizedBox(height: 24),
                  Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      title: Text(
                        "Profit Analysis (Private)",
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: SoftColors.textMain,
                        ),
                      ),
                      backgroundColor: SoftColors.background,
                      collapsedBackgroundColor: SoftColors.textMain.withOpacity(
                        0.05,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      collapsedShape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              _SummaryRow(
                                "Total Revenue",
                                "\$${currentOrder.totalRevenue.toStringAsFixed(2)}",
                                color: SoftColors.success,
                              ),
                              const SizedBox(height: 8),
                              _SummaryRow(
                                "COGS (Product Cost)",
                                "-\$${((currentOrder.totalExpense - (currentOrder.logistics.actualDeliveryCost ?? 0))).toStringAsFixed(2)}",
                                color: SoftColors.error,
                              ),
                              const SizedBox(height: 8),
                              _SummaryRow(
                                "Delivery Paid",
                                "-\$${(currentOrder.logistics.actualDeliveryCost ?? 0).toStringAsFixed(2)}",
                                color: SoftColors.error,
                              ),
                              const Divider(),
                              _SummaryRow(
                                "Net Profit",
                                "\$${currentOrder.netProfit.toStringAsFixed(2)}",
                                isHighlight: true,
                                color: currentOrder.netProfit >= 0
                                    ? SoftColors.success
                                    : SoftColors.error,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 48),

                // Actions (Change Status)
                if (currentOrder.status == OrderStatus.prepping)
                  SoftButton(
                    label: "Mark as Delivering",
                    icon: Icons.local_shipping_outlined,
                    backgroundColor: SoftColors.brandPrimary,
                    onTap: () async {
                      // 1. Show Dialog to record Expense
                      final actualCost = await showDialog<double>(
                        context: context,
                        builder: (context) {
                          final feeCharged =
                              currentOrder.logistics.deliveryFeeCharged;
                          final controller = TextEditingController();
                          return AlertDialog(
                            backgroundColor: SoftColors.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                SoftColors.cardRadius,
                              ),
                            ),
                            title: Text(
                              "Record Delivery Expense",
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: SoftColors.warning.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.info_outline,
                                        size: 16,
                                        color: SoftColors.warning,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          "Customer charged: \$${feeCharged.toStringAsFixed(2)}",
                                          style: GoogleFonts.outfit(
                                            color: SoftColors.textMain,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  "Actual Cost to Driver",
                                  style: GoogleFonts.outfit(
                                    color: SoftColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: controller,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: InputDecoration(
                                    hintText: "Enter amount paid",
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Quick Action: Match
                                InkWell(
                                  onTap: () {
                                    controller.text = feeCharged.toString();
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: SoftColors.brandPrimary,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        "Match Charged Amount (\$${feeCharged.toStringAsFixed(2)})",
                                        style: GoogleFonts.outfit(
                                          color: SoftColors.brandPrimary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text("Cancel"),
                              ),
                              TextButton(
                                onPressed: () {
                                  final val = double.tryParse(controller.text);
                                  if (val == null) {
                                    return; // forcing valid input
                                  }
                                  Navigator.pop(context, val);
                                },
                                child: Text(
                                  "Confirm & Deliver",
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    color: SoftColors.brandPrimary,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );

                      if (actualCost != null) {
                        // 2. Update Order
                        final updatedLogistics = OrderLogistics(
                          deliveryFeeCharged:
                              currentOrder.logistics.deliveryFeeCharged,
                          deliveryType: currentOrder.logistics.deliveryType,
                          actualDeliveryCost: actualCost,
                        );

                        final updatedOrder = currentOrder.copyWith(
                          status: OrderStatus.delivering,
                          logistics: updatedLogistics,
                          updatedAt: DateTime.now(),
                        );

                        await ref
                            .read(ordersRepositoryProvider)
                            .updateOrder(updatedOrder);

                        // Sync with History List
                        ref
                            .read(orderHistoryProvider.notifier)
                            .updateOrderLocally(updatedOrder);
                      }
                    },
                  ),

                if (currentOrder.status == OrderStatus.delivering &&
                    !isEmployee)
                  SoftButton(
                    label: "Mark as Completed",
                    icon: Icons.check_circle_outline_rounded,
                    backgroundColor: SoftColors.success,
                    textColor: Colors.white,
                    onTap: () async {
                      await ref
                          .read(ordersRepositoryProvider)
                          .updateOrderStatus(
                            currentOrder.id,
                            OrderStatus.completed,
                          );

                      // Sync with History List
                      // (We need to construct the updated order object locally or fetch it,
                      // but since updateOrderStatus relies on ID, let's create a local copy for the UI)
                      final updatedOrder = currentOrder.copyWith(
                        status: OrderStatus.completed,
                      );
                      ref
                          .read(orderHistoryProvider.notifier)
                          .updateOrderLocally(updatedOrder);
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
      case OrderStatus.cancelled:
        color = SoftColors.error;
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

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlight;
  final Color? color;

  const _SummaryRow(
    this.label,
    this.value, {
    this.isHighlight = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: isHighlight ? 16 : 14,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
            color: SoftColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: isHighlight ? 16 : 14,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
            color: color ?? SoftColors.textMain,
          ),
        ),
      ],
    );
  }
}
