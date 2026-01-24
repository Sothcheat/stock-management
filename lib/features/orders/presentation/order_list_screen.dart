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
    final userProfileAsync = ref.watch(currentUserProfileProvider);

    if (userProfileAsync.isLoading) {
      return const Scaffold(
        backgroundColor: SoftColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final user = userProfileAsync.value;
    final isEmployee = user?.role == UserRole.employee;

    return SoftScaffold(
      title: 'Orders',
      floatingActionButton: isEmployee
          ? null
          : FloatingActionButton.extended(
              heroTag: 'orders_fab',
              onPressed: () {
                context.go('/orders/new-order');
              },
              backgroundColor: SoftColors.brandPrimary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: Text(
                "New Order",
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
      body: Column(
        children: [
          // Custom Tab Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: SoftColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: SoftColors.textMain.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: TabBar(
                  controller: _tabController,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: SoftColors.textSecondary,
                  indicator: BoxDecoration(
                    color: SoftColors.brandPrimary,
                    borderRadius: BorderRadius.circular(12),
                    // Shadow removed from indicator to prevent double-shadow clipping artifacts
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorPadding: const EdgeInsets.all(4),
                  labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                  tabs: const [
                    Tab(text: 'Active'),
                    Tab(text: 'History'),
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            child: ordersAsync.when(
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
          ),
        ],
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
            Icon(
              Icons.assignment_outlined,
              size: 60,
              color: SoftColors.textSecondary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              isEmptyMessage,
              style: GoogleFonts.outfit(
                color: SoftColors.textSecondary,
                fontSize: 18,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: BounceButton(
        onTap: () {
          context.go('/orders/detail', extra: order);
        },
        child: SoftCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    order.customer.name,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: SoftColors.textMain,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      order.status.name.toUpperCase(),
                      style: GoogleFonts.outfit(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    size: 16,
                    color: SoftColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "${order.items.length} Items",
                    style: GoogleFonts.outfit(
                      color: SoftColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    "\$${order.totalAmount.toStringAsFixed(2)}",
                    style: GoogleFonts.outfit(
                      color: SoftColors.textMain,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: SoftColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.deliveryAddress,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: SoftColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    dateStr,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: SoftColors.textSecondary,
                    ),
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
        return SoftColors.warning;
      case OrderStatus.delivering:
        return SoftColors.brandPrimary;
      case OrderStatus.completed:
        return SoftColors.success;
    }
  }
}
