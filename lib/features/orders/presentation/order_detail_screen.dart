import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../orders/data/orders_repository.dart';
import '../../orders/domain/order.dart';

class OrderDetailScreen extends ConsumerWidget {
  final OrderModel order;
  const OrderDetailScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch for updates (optional, or just use passed object and optimistic updates in repo)
    // Actually, passing the object from list might be stale if we just updated it.
    // Better to have a stream for single order, but for now we rely on the list stream updating the list,
    // and if we pop back it's fine. Inside here, we might want to watch the specific order from the list provider?
    // KEEP IT SIMPLE: Use the passed order for display. If actions happen, we pop or update locally?
    // Best: `ref.watch(ordersStreamProvider).when(...)` and find the order.

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
        // We can check if it exists in list.
        final exists = orders.any((o) => o.id == order.id);
        if (!exists) {
          return const Scaffold(
            body: Center(child: Text("Order not found (Deleted)")),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text("Order Details"),
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text("Delete Order?"),
                      content: const Text("Stock will be restored."),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: const Text("Cancel"),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text(
                            "Delete",
                            style: TextStyle(color: Colors.red),
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
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header (Status & ID)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Order #${currentOrder.id.substring(0, 5).toUpperCase()}",
                      style: const TextStyle(color: Colors.grey),
                    ),
                    _StatusBadge(status: currentOrder.status),
                  ],
                ),
                const SizedBox(height: 24),

                // Customer Info
                _SectionHeader("Customer"),
                _InfoRow(Icons.person, currentOrder.customer.name),
                _InfoRow(Icons.phone, currentOrder.customer.primaryPhone),
                if (currentOrder.customer.secondaryPhone?.isNotEmpty == true)
                  _InfoRow(
                    Icons.phone_android,
                    currentOrder.customer.secondaryPhone!,
                  ),
                _InfoRow(Icons.location_on, currentOrder.deliveryAddress),

                const SizedBox(height: 24),
                // Items
                _SectionHeader("Items"),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: currentOrder.items.length,
                  itemBuilder: (context, index) {
                    final item = currentOrder.items[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "x${item.quantity}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(item.name),
                      subtitle: Text(item.variantName),
                      trailing: Text(
                        "\$${(item.priceAtSale * item.quantity).toStringAsFixed(2)}",
                      ),
                    );
                  },
                ),
                const Divider(),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    "Total: \$${currentOrder.totalAmount.toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Actions (Change Status)
                if (currentOrder.status == OrderStatus.prepping)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: () {
                        ref
                            .read(ordersRepositoryProvider)
                            .updateOrderStatus(
                              currentOrder.id,
                              OrderStatus.delivering,
                            );
                      },
                      icon: const Icon(Icons.local_shipping),
                      label: const Text("Mark as Delivering"),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.blue,
                      ),
                    ),
                  ),

                if (currentOrder.status == OrderStatus.delivering)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: () {
                        ref
                            .read(ordersRepositoryProvider)
                            .updateOrderStatus(
                              currentOrder.id,
                              OrderStatus.completed,
                            );
                      },
                      icon: const Icon(Icons.check_circle),
                      label: const Text("Mark as Completed"),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                    ),
                  ),
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
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 16)),
        ],
      ),
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
        color = Colors.orange;
        break;
      case OrderStatus.delivering:
        color = Colors.blue;
        break;
      case OrderStatus.completed:
        color = Colors.green;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}
