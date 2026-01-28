import 'package:sticky_headers/sticky_headers.dart';
import 'dart:ui' as ui;
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
import 'package:flutter/services.dart';
import 'providers/order_history_controller.dart';

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

    final historyState = ref.watch(orderHistoryProvider(isArchived: false));

    return PopScope(
      canPop: !historyState.isSelectionMode,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (historyState.isSelectionMode) {
          // Exit Selection Mode on Back Press
          ref
              .read(orderHistoryProvider(isArchived: false).notifier)
              .clearSelection();
        }
      },
      child: SoftScaffold(
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
              child: Row(
                children: [
                  Expanded(
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
                          ),
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicatorPadding: const EdgeInsets.all(4),
                          labelStyle: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                          ),
                          tabs: const [
                            Tab(text: 'Active'),
                            Tab(text: 'History'),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (!isEmployee) ...[
                    const SizedBox(width: 12),
                    Container(
                      height: 48,
                      width: 48,
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
                      child: IconButton(
                        icon: const Icon(
                          Icons.archive_outlined,
                          color: SoftColors.textMain,
                        ),
                        tooltip: "Archived Orders",
                        onPressed: () {
                          context.push('/orders/archived');
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Active Orders Tab (Keep stream for active)
                  ordersAsync.when(
                    data: (orders) {
                      final activeOrders = orders
                          .where((o) => o.status != OrderStatus.completed)
                          .toList();

                      // Re-use _OrderListView but with mock state for active orders (Simpler to just make a wrapper or specialized widget really, but for speed...)
                      // Actually, _OrderListView now expects OrderHistoryState.
                      // Let's create a temporary state wrapper for active orders.
                      final activeState = OrderHistoryState(
                        orders: activeOrders,
                        isLoadingInitial: false,
                        hasMore: false,
                      );

                      return OrderListView(
                        state: activeState,
                        isEmptyMessage: "No active orders",
                        isHistory: false,
                        isArchived: false,
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, s) => Center(child: Text("Error: $e")),
                  ),

                  // History Tab (New Design)
                  Column(
                    children: [
                      // 1. Filter Chips (Horizontal Scroll) - Top Priority
                      Container(
                        height: 60, // Increased height for breathing room
                        margin: const EdgeInsets.only(
                          bottom: 0,
                        ), // Add spacing below list
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          children: [
                            _FilterChip(
                              label: "All",
                              isSelected: historyState.typeFilter == null,
                              onSelected: (selected) {
                                if (selected) {
                                  HapticFeedback.mediumImpact();
                                  ref
                                      .read(
                                        orderHistoryProvider(
                                          isArchived: false,
                                        ).notifier,
                                      )
                                      .setTypeFilter(null);
                                }
                              },
                            ),
                            const SizedBox(width: 12),
                            _FilterChip(
                              label: "Reservations",
                              isSelected:
                                  historyState.typeFilter == OrderType.standard,
                              onSelected: (selected) {
                                if (selected) {
                                  HapticFeedback.mediumImpact();
                                  ref
                                      .read(
                                        orderHistoryProvider(
                                          isArchived: false,
                                        ).notifier,
                                      )
                                      .setTypeFilter(OrderType.standard);
                                }
                              },
                            ),
                            const SizedBox(width: 12),
                            _FilterChip(
                              label: "Quick Sales",
                              isSelected:
                                  historyState.typeFilter ==
                                  OrderType.manualReduction,
                              onSelected: (selected) {
                                if (selected) {
                                  HapticFeedback.mediumImpact();
                                  ref
                                      .read(
                                        orderHistoryProvider(
                                          isArchived: false,
                                        ).notifier,
                                      )
                                      .setTypeFilter(OrderType.manualReduction);
                                }
                              },
                            ),
                          ],
                        ),
                      ),

                      // 2. Date Range Bar (Sub-Header)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical:
                              16, // Reduced top vertical padding as chips have margin now
                        ),
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.light(
                                      primary: SoftColors.brandPrimary,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              ref
                                  .read(
                                    orderHistoryProvider(
                                      isArchived: false,
                                    ).notifier,
                                  )
                                  .setDateRange(picked);
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: SoftColors.textSecondary.withValues(
                                  alpha: 0.1,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today_rounded,
                                  size: 18,
                                  color: SoftColors.textSecondary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    historyState.dateRange == null
                                        ? "Filter by Date Range"
                                        : "${DateFormat('MMM d').format(historyState.dateRange!.start)} - ${DateFormat('MMM d').format(historyState.dateRange!.end)}",
                                    style: GoogleFonts.outfit(
                                      color: historyState.dateRange == null
                                          ? SoftColors.textSecondary
                                          : SoftColors.textMain,
                                      fontWeight: historyState.dateRange == null
                                          ? FontWeight.normal
                                          : FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (historyState.dateRange != null)
                                  GestureDetector(
                                    onTap: () {
                                      HapticFeedback.lightImpact(); // Haptic feedback
                                      ref
                                          .read(
                                            orderHistoryProvider(
                                              isArchived: false,
                                            ).notifier,
                                          )
                                          .clearDateRange();
                                    },
                                    child: CircleAvatar(
                                      radius: 12, // Radius 12
                                      backgroundColor: SoftColors.error
                                          .withValues(alpha: 0.1),
                                      child: const Icon(
                                        Icons.close_rounded,
                                        size: 14,
                                        color: SoftColors.error,
                                      ),
                                    ),
                                  )
                                else
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    size: 20,
                                    color: SoftColors.textSecondary,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // 3. Pinned Summary (Mini-Dashboard)
                      if (historyState.orders.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 4,
                          ),
                          child: _HistorySummaryCard(state: historyState),
                        ),

                      const SizedBox(height: 8),

                      // 4. The List
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: () async {
                            await ref
                                .read(
                                  orderHistoryProvider(
                                    isArchived: false,
                                  ).notifier,
                                )
                                .refresh();
                          },
                          child: OrderListView(
                            state: historyState,
                            isEmptyMessage: "No history found",
                            isHistory: true, // Enables sticky headers
                            isArchived: false,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomSheet: historyState.isSelectionMode && !isEmployee
            ? Container(
                color: SoftColors.surface,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Text(
                        "${historyState.selectedIds.length} Selected",
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(
                          Icons.archive,
                          color: SoftColors.brandAccent,
                        ),
                        tooltip: "Archive Selected",
                        onPressed: () {
                          ref
                              .read(
                                orderHistoryProvider(
                                  isArchived: false,
                                ).notifier,
                              )
                              .executeBulkArchive(true);
                        },
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: SoftColors.error,
                        ),
                        tooltip: "Void (Restore Stock)",
                        onPressed: () {
                          // Show confirmation? Or just execute?
                          // Ideally confirmation. I'll execute for now as per "executeBulkDelete" existence.
                          // User plan implied guards were in repo ("Transaction Safety").
                          // But UI confirmation is nice. For speed, I'll add confirmation if easy.
                          // _showBulkVoidConfirmation?
                          // I'll call executeBulkDelete directly for now, or add a confirmation dialog helper.
                          // Given user instructions, I should probably prioritize functionality.
                          _showBulkVoidConfirmation(context, ref);
                        },
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_forever,
                          color: SoftColors.error,
                        ),
                        tooltip: "Purge Selected",
                        onPressed: () {
                          _showBulkPurgeConfirmation(context, ref);
                        },
                      ),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: () {
                          ref
                              .read(
                                orderHistoryProvider(
                                  isArchived: false,
                                ).notifier,
                              )
                              .toggleSelectionMode();
                          HapticFeedback.lightImpact(); // Haptic for visual feedback
                        },
                        child: const Text("Cancel"),
                      ),
                    ],
                  ),
                ),
              )
            : null,
      ),
    );
  }

  void _showBulkVoidConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Void Orders"),
        content: const Text(
          "Are you sure you want to void these orders? Stock will be restored.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref
                  .read(orderHistoryProvider(isArchived: false).notifier)
                  .executeBulkDelete();
            },
            child: const Text(
              "Void",
              style: TextStyle(color: SoftColors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _showBulkPurgeConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Permanent Purge"),
        content: const Text(
          "Are you sure you want to permanently delete these orders? This cannot be undone and no stock will be restored.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref
                  .read(orderHistoryProvider(isArchived: false).notifier)
                  .executeBulkPurge();
            },
            child: const Text("Purge", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _HistorySummaryCard extends StatelessWidget {
  final OrderHistoryState state;
  const _HistorySummaryCard({required this.state});

  @override
  Widget build(BuildContext context) {
    // Use pre-calculated totals from state (Controller logic)
    final totalRevenue = state.totalRevenue;
    final totalItems = state.totalItems;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SoftColors.brandPrimary,
        borderRadius: BorderRadius.circular(16), // 16px Radius
        boxShadow: [
          BoxShadow(
            color: SoftColors.brandPrimary.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Column(
            children: [
              Text(
                "Revenue",
                style: GoogleFonts.outfit(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
              ),
              Text(
                "\$${totalRevenue.toStringAsFixed(2)}",
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          Container(
            width: 1,
            height: 30,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          Column(
            children: [
              Text(
                "Items Sold",
                style: GoogleFonts.outfit(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
              ),
              Text(
                "$totalItems",
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class OrderListView extends ConsumerWidget {
  final OrderHistoryState state;
  final String isEmptyMessage;
  final bool isHistory;
  final bool isArchived;

  const OrderListView({
    required this.state,
    required this.isEmptyMessage,
    this.isHistory = false,
    this.isArchived = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Error State
    if (state.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 60, color: SoftColors.error),
              const SizedBox(height: 16),
              Text(
                "Something went wrong",
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: SoftColors.textMain,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                state.errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(color: SoftColors.textSecondary),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  ref
                      .read(
                        orderHistoryProvider(isArchived: isArchived).notifier,
                      )
                      .refresh();
                },
                icon: const Icon(Icons.refresh),
                label: const Text("Try Again"),
                style: FilledButton.styleFrom(
                  backgroundColor: SoftColors.brandPrimary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 2. Initial Loading
    if (state.isLoadingInitial) {
      return const Center(child: CircularProgressIndicator());
    }

    // 2. Empty State
    if (state.orders.isEmpty) {
      // If not loading and empty, show placeholder
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

    // Group By Date if History
    // We do grouping here for simplicity of logic passing,
    // though deeper optimization could move it to controller.
    // For < 1000 items, local grouping is instant.
    // We use a helper map for "Today", "Yesterday".

    // For pagination scroll listener:
    return NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) {
        if (isHistory &&
            !state.isLoadingMore &&
            state.hasMore &&
            scrollInfo.metrics.pixels >=
                scrollInfo.metrics.maxScrollExtent - 200) {
          ref
              .read(orderHistoryProvider(isArchived: isArchived).notifier)
              .loadMore();
          // Optional: HapticFeedback.lightImpact(); // Maybe too frequent if scrolling fast
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          24,
          0,
          24,
          80,
        ), // Bottom padding for FAB/Safe
        itemCount: isHistory
            ? _groupOrders(state.orders).length + (state.isLoadingMore ? 1 : 0)
            : state.orders.length,
        itemBuilder: (context, index) {
          // ... Logic for Sticky Headers or Normal List
          if (isHistory) {
            final groups = _groupOrders(state.orders);
            if (index >= groups.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            final entry = groups.entries.elementAt(index);
            return RepaintBoundary(
              child: StickyHeader(
                header: ClipRRect(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      height: 40,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ), // Match list padding
                      decoration: BoxDecoration(
                        color: SoftColors.background.withValues(
                          alpha: 0.8,
                        ), // Translucent
                        border: Border(
                          bottom: BorderSide(
                            color: SoftColors.textSecondary.withValues(
                              alpha: 0.1,
                            ),
                          ),
                        ),
                      ),
                      child: Text(
                        entry.key,
                        style: GoogleFonts.outfit(
                          color: SoftColors.textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                content: Column(
                  children: entry.value
                      .map(
                        (order) =>
                            OrderCard(order: order, isArchived: isArchived),
                      )
                      .toList(),
                ),
              ),
            );
          }

          return OrderCard(order: state.orders[index], isArchived: isArchived);
        },
      ),
    );
  }

  Map<String, List<OrderModel>> _groupOrders(List<OrderModel> orders) {
    final groups = <String, List<OrderModel>>{};
    for (final order in orders) {
      final dateKey = _getDateKey(order.createdAt);
      groups.putIfAbsent(dateKey, () => []).add(order);
    }
    return groups;
  }

  String _getDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateCheck = DateTime(date.year, date.month, date.day);

    if (dateCheck == today) return "Today";
    if (dateCheck == yesterday) return "Yesterday";

    // Is this week?
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    if (dateCheck.isAfter(weekStart.subtract(const Duration(seconds: 1)))) {
      return "This Week";
    }

    return DateFormat('MMMM dd, yyyy').format(date);
  }
}

class OrderCard extends ConsumerWidget {
  final OrderModel order;
  final bool isArchived;
  const OrderCard({required this.order, required this.isArchived});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyState = ref.watch(
      orderHistoryProvider(isArchived: isArchived),
    );
    final isSelected = historyState.selectedIds.contains(order.id);
    final user = ref.watch(currentUserProfileProvider).value;
    final isEmployee = user?.role == UserRole.employee;

    // Content Widget
    Widget cardContent;
    if (order.customer.name == 'Quick Sale') {
      cardContent = QuickSaleOrderCard(order: order, isArchived: isArchived);
    } else {
      cardContent = _ReservationOrderCard(order: order);
    }

    // 1. Selection Overlay Wrapper
    Widget contentWithOverlay = Stack(
      children: [
        cardContent,
        if (historyState.isSelectionMode)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? SoftColors.brandPrimary : Colors.white,
                border: Border.all(
                  color: isSelected
                      ? SoftColors.brandPrimary
                      : SoftColors.textSecondary.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.check,
                  size: 14,
                  color: isSelected ? Colors.white : Colors.transparent,
                ),
              ),
            ),
          ),
      ],
    );

    // 2. Gesture Wrapper (Tap/LongPress)
    // Note: Child cards have their own Tap logic (BounceButton).
    // In Selection Mode, we must override that.
    // Outside Selection Mode, Long Press triggers generic selection.

    if (historyState.isSelectionMode) {
      // Override child taps by wrapping in a GestureDetector that absorbs or handles taps first?
      // Actually, BounceButton consumes taps. We might need to wrap in AbsorbPointer?
      // Or pass a 'onTap' override to children? Children are existing widgets.
      // Wrapping with detailed GestureDetector behavior:
      contentWithOverlay = GestureDetector(
        onTap: () {
          ref
              .read(orderHistoryProvider(isArchived: isArchived).notifier)
              .toggleOrderSelection(order.id);
        },
        child: AbsorbPointer(
          absorbing: true, // Disable child buttons in selection mode
          child: contentWithOverlay,
        ),
      );
    } else {
      // Normal Mode: Allow child taps, but listen for Long Press
      if (!isEmployee) {
        contentWithOverlay = GestureDetector(
          onLongPress: () {
            HapticFeedback.mediumImpact(); // High-Fidelity UX: Medium Haptic on Long Press
            ref
                .read(orderHistoryProvider(isArchived: false).notifier)
                .toggleSelectionMode();
            ref
                .read(orderHistoryProvider(isArchived: isArchived).notifier)
                .toggleOrderSelection(order.id);
          },
          child: contentWithOverlay,
        );
      }
    }

    // 3. Dismissible Wrapper (Swipe Actions)
    // 3. Dismissible Wrapper (Swipe Actions)
    if (!historyState.isSelectionMode && !isEmployee) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(
              16,
            ), // Not strictly needed if Container has radius, but good for safety
            child: Dismissible(
              key: Key(order.id),
              direction: DismissDirection.horizontal,
              // UX FIX: Remove floating background gap by creating a tight container here or relying on Padding wrapping Dismissible
              // The Dismissible background must FILL the space behind the item.
              background: _buildSwipeAction(
                alignment: Alignment.centerLeft,
                color: SoftColors.success,
                icon: Icons.archive_outlined,
              ),
              secondaryBackground: _buildSwipeAction(
                alignment: Alignment.centerRight,
                color: SoftColors.error,
                icon: Icons.delete_forever_rounded,
              ),
              confirmDismiss: (direction) async {
                if (direction == DismissDirection.startToEnd) {
                  // Swipe Right (L->R) -> Archive
                  try {
                    await ref
                        .read(ordersRepositoryProvider)
                        .archiveOrder(order.id, true);

                    // Only update UI if remote succeeds
                    ref
                        .read(
                          orderHistoryProvider(isArchived: isArchived).notifier,
                        )
                        .removeOrderLocally(order.id);

                    if (context.mounted) {
                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      scaffoldMessenger.clearSnackBars();
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: const Text("Order archived"),
                          duration: const Duration(seconds: 4),
                          action: SnackBarAction(
                            label: "UNDO",
                            onPressed: () async {
                              try {
                                await ref
                                    .read(ordersRepositoryProvider)
                                    .archiveOrder(order.id, false);
                                ref
                                    .read(
                                      orderHistoryProvider(
                                        isArchived: isArchived,
                                      ).notifier,
                                    )
                                    .addOrderLocally(order);
                              } catch (e) {
                                // Handle undo error
                              }
                            },
                          ),
                        ),
                      );
                    }
                    return true;
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Failed to archive: $e"),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                    return false; // Prevent dismiss
                  }
                } else {
                  // Swipe Left (R->L) -> Purge
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text("Permanent Purge"),
                      content: const Text(
                        "Delete this order forever? This cannot be undone.",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text("Cancel"),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text(
                            "Purge",
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    ref
                        .read(ordersRepositoryProvider)
                        .permanentPurgeOrder(order.id);
                    return true;
                  }
                  return false;
                }
              },
              child: Container(color: Colors.white, child: contentWithOverlay),
            ),
          ),
        ),
      );
    }

    // When NOT in Dismissible (Selection Mode / Employee), we need successful Card styling (Shadow/Radius)
    // Wrap contentWithOverlay in same styling as above but without the dismissible logic.
    return Padding(
      // Keep consistent spacing even without Dismissible
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: contentWithOverlay,
      ),
    );
  }

  Widget _buildSwipeAction({
    required Alignment alignment,
    required Color color,
    required IconData icon,
  }) {
    // Ensure background matches the card's radius for high-fidelity feel
    return Container(
      alignment: alignment,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: alignment == Alignment.centerLeft
          ? const EdgeInsets.only(left: 20)
          : const EdgeInsets.only(right: 20),
      child: Icon(icon, color: Colors.white),
    );
  }
}

class _ReservationOrderCard extends StatelessWidget {
  final OrderModel order;
  const _ReservationOrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM dd, yyyy • h:mm a').format(order.createdAt);
    // Display Order ID logic - Shortening for POS display (5 chars is standard)
    final displayId = order.id.length > 5
        ? "#${order.id.substring(0, 5).toUpperCase()}"
        : "#${order.id.toUpperCase()}";

    return BounceButton(
      onTap: () {
        context.go('/orders/detail', extra: order);
      },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header Row (ID & Status)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  displayId,
                  style: GoogleFonts.outfit(
                    color: SoftColors.brandPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16, // Increased size
                  ),
                ),
                _StatusChip(status: order.status), // Extracted for reuse logic
              ],
            ),
            const SizedBox(height: 4), // Increased spacing
            // 2. Customer Section (Large Extra-Bold)
            Text(
              order.customer.name,
              style: GoogleFonts.outfit(
                color: SoftColors.textMain,
                fontSize: 20, // Large
                fontWeight: FontWeight.w800, // Extra Bold
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 14,
                  color: SoftColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  dateStr,
                  style: GoogleFonts.outfit(
                    color: SoftColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16), // More breathing room
            const Divider(height: 1, color: SoftColors.border),
            const SizedBox(height: 12),

            // 3. Footer Row (Items & Price)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "${order.items.length} items",
                  style: GoogleFonts.outfit(
                    color: SoftColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  "\$${order.totalAmount.toStringAsFixed(2)}",
                  style: GoogleFonts.outfit(
                    color: SoftColors.textMain,
                    fontSize: 22, // Large
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final OrderStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case OrderStatus.prepping:
        color = SoftColors.brandPrimary; // Active Blue (Pending)
        break;
      case OrderStatus.delivering:
        color = SoftColors.warning; // Or Orange? Stuck to Logic.
        // User spec said Blue for Pending.
        // Let's stick to what was requested or logical equivalent.
        // Prepping = Brand Primary (Blue)
        // Delivering = Warning (Orange)
        break;
      case OrderStatus.completed:
        color = SoftColors.success;
        break;
      case OrderStatus.cancelled:
        color = SoftColors.error;
        break;
    }

    // Override if needed logic
    if (status == OrderStatus.prepping) {
      color = SoftColors.brandPrimary;
    } else if (status == OrderStatus.delivering) {
      color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: GoogleFonts.outfit(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class QuickSaleOrderCard extends ConsumerWidget {
  final OrderModel order;
  final bool isArchived;
  const QuickSaleOrderCard({required this.order, required this.isArchived});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // final statusColor = SoftColors.success; // Quick sales are usually completed
    final dateStr = DateFormat('MMM dd, hh:mm a').format(order.createdAt);

    // Quick Sale Dynamic Items
    String itemsText = "";
    if (order.items.length <= 2) {
      itemsText = order.items.map((e) => "${e.quantity}x ${e.name}").join(", ");
    } else {
      final firstTwo = order.items.take(2).map((e) => e.name).join(", ");
      itemsText = "$firstTwo +${order.items.length - 2} more items";
    }

    return BounceButton(
      onTap: () {
        context.go('/orders/detail', extra: order);
      },
      child: Container(
        color: Colors.white, // SoftCard's default background
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Quick Sale Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: SoftColors.brandPrimary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_bag_outlined,
                color: SoftColors.brandPrimary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),

            // Main Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          "Quick Sale",
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: SoftColors.textMain,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Price aligned with Title
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
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          itemsText,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: const Color.fromARGB(
                              255,
                              120,
                              123,
                              138,
                            ).withValues(alpha: 0.7),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Text(
                          dateStr,
                          style: GoogleFonts.outfit(
                            fontSize: 11, // Smaller for metadata
                            color: SoftColors.textSecondary.withValues(
                              alpha: 0.7,
                            ),
                            fontWeight: FontWeight.w600, // Crisp but subtle
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Delete / Revert Action
            Container(
              margin: const EdgeInsets.only(left: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () {
                    HapticFeedback.mediumImpact();

                    // Show Safe Deletion Dialog
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(
                          "Delete Quick Sale?",
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        content: Text(
                          "This will restore ${order.items.fold<int>(0, (p, c) => p + c.quantity)} items to inventory.",
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("Cancel"),
                          ),
                          TextButton(
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              Navigator.pop(context);
                              try {
                                await ref
                                    .read(ordersRepositoryProvider)
                                    .deleteOrder(order);

                                // Update Local History State immediately
                                ref
                                    .read(
                                      orderHistoryProvider(
                                        isArchived: isArchived,
                                      ).notifier,
                                    )
                                    .removeOrderLocally(order.id);

                                // Success - show snackbar using captured messenger
                                HapticFeedback.vibrate();
                                messenger.hideCurrentSnackBar();
                                messenger.showSnackBar(
                                  SnackBar(
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: SoftColors.textMain,
                                    duration: const Duration(seconds: 5),
                                    content: Row(
                                      children: [
                                        const Icon(
                                          Icons.settings_backup_restore_rounded,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            "Quick Sale Deleted: Product stock has been restored and profit reversed.",
                                            style: GoogleFonts.outfit(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text("Error: $e"),
                                      backgroundColor: SoftColors.error,
                                    ),
                                  );
                                }
                              }
                            },
                            child: const Text(
                              "Delete & Restore",
                              style: TextStyle(color: SoftColors.error),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.only(
                      left: 8,
                    ), // 48x48 Target (24 icon + 12*2 padding)
                    child: Icon(
                      Icons.delete_outline,
                      color: SoftColors.textSecondary,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Function(bool) onSelected;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: onSelected,
      // padding: removed to match standard size
      backgroundColor: Colors.grey.withOpacity(
        0.08,
      ), // Light grey for unselected
      selectedColor: SoftColors.brandPrimary, // Brand color for selected
      checkmarkColor: Colors.white,
      labelStyle: GoogleFonts.outfit(
        color: isSelected ? Colors.white : SoftColors.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        fontSize: 14,
      ),
      shape: const StadiumBorder(side: BorderSide(color: Colors.transparent)),
      showCheckmark: false,
    );
  }
}
