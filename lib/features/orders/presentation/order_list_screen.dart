import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../orders/data/orders_repository.dart';
import '../../orders/domain/order.dart';

class OrderListScreen extends ConsumerStatefulWidget {
  const OrderListScreen({super.key});

  @override
  ConsumerState<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends ConsumerState<OrderListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(ordersStreamProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Orders',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: ordersAsync.when(
        data: (orders) {
          final activeOrders = orders
              .where((o) => o.status != OrderStatus.completed)
              .toList();
          final historyOrders = orders
              .where((o) => o.status == OrderStatus.completed)
              .toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _OrderListView(
                orders: activeOrders,
                isEmptyMessage: "No active orders",
              ),
              _OrderListView(
                orders: historyOrders,
                isEmptyMessage: "No order history",
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text("Error: $e")),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'orders_fab',
        onPressed: () {
          context.go('/orders/new-order');
        },
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text("New Order"),
      ),
    );
  }
}

class _OrderListView extends StatelessWidget {
  final List<OrderModel> orders;
  final String isEmptyMessage;

  const _OrderListView({required this.orders, required this.isEmptyMessage});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(isEmptyMessage, style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return _OrderCard(order: order);
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(order.status);
    final dateStr = DateFormat('MMM dd, hh:mm a').format(order.createdAt);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          context.go('/orders/detail', extra: order);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    order.customer.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      order.status.name.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "${order.items.length} Items • \$${order.totalAmount.toStringAsFixed(2)}",
                style: TextStyle(color: Colors.grey[700]),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      order.deliveryAddress,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    dateStr,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.prepping:
        return Colors.orange;
      case OrderStatus.delivering:
        return Colors.blue;
      case OrderStatus.completed:
        return Colors.green;
    }
  }
}
