import 'package:sticky_headers/sticky_headers.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart'; // Corrected import path
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
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging || _tabController.animation != null) {
        if (!mounted) return;
        setState(() {}); // Rebuild for FAB visibility
      }
    });

    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_tabController.index == 1 && // Only for History tab
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
      final historyState = ref.read(orderHistoryProvider(false)).valueOrNull;
      if (historyState != null &&
          !historyState.isLoadingMore &&
          historyState.hasMore) {
        ref.read(orderHistoryProvider(false).notifier).loadMore();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(ordersStreamProvider);
    // Listen to tab changes to update FAB visibility
    // We need to rebuild when tab index changes
    // Using AnimatedBuilder on the controller or just setState since we have a mixin
    // But mixin doesn't auto-rebuild. Let's add listener in initState.
    // Actually, simpler: Wrap FAB in AnimatedBuilder listening to _tabController?
    // Or just setState in listener. Since we need to access _tabController in build.
    // Let's rely on standard setState in listener added in initState.

    // ... Existing build logic ...

    // Listen to tab changes to update FAB visibility
    // We need to rebuild when tab index changes (handled by setState in listener)
    final userProfileAsync = ref.watch(currentUserProfileProvider);

    final colors = context.softColors; // Access dynamic colors

    if (userProfileAsync.isLoading) {
      return Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: 80),
            child: const SoftShimmer.orderCard(itemCount: 4),
          ),
        ),
      );
    }

    final user = userProfileAsync.value;
    final isEmployee = user?.role == UserRole.employee;

    final historyAsync = ref.watch(orderHistoryProvider(false));
    final historyState = historyAsync.value;

    return PopScope(
      canPop: !(historyState?.isSelectionMode ?? false),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Exit Selection Mode manually if back is pressed
        if (historyState?.isSelectionMode ?? false) {
          ref.read(orderHistoryProvider(false).notifier).clearSelection();
          ref
              .read(orderHistoryProvider(false).notifier)
              .toggleSelectionMode(); // Actually turn it off
        }
      },
      child: RefreshIndicator(
        onRefresh: () async {
          // Standard refresh logic - usually driven by state change or explicit refresh
          // Active: Stream handles itself (but pull to refresh could force check? Firestore stream is live).
          // History: Needs explicit refresh.
          if (_tabController.index == 1) {
            await ref.read(orderHistoryProvider(false).notifier).refresh();
          }
        },
        child: SoftSliverScaffold(
          controller: _scrollController,
          title: 'Orders',
          floatingActionButton: AnimatedScale(
            scale:
                (isEmployee ||
                    _tabController.index == 1 ||
                    (historyState?.isSelectionMode ?? false))
                ? 0.0
                : 1.0,
            duration: const Duration(milliseconds: 200),
            child: FloatingActionButton.extended(
              heroTag: 'orders_fab',
              onPressed: () {
                context.go('/orders/new-order');
              },
              backgroundColor: colors.brandPrimary,
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
          ),
          slivers: [
            // 1. Tab Bar (SliverToBox)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: SoftColors.textMain.withValues(
                                alpha: 0.05,
                              ),
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
                            unselectedLabelColor: colors.textSecondary,
                            indicator: BoxDecoration(
                              color: colors.brandPrimary,
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
                            onTap: (index) {
                              setState(
                                () {},
                              ); // Trigger rebuild to switch slivers
                            },
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
                              color: SoftColors.textMain.withValues(
                                alpha: 0.05,
                              ),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.archive_outlined,
                            color: colors.textMain,
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
            ),

            // 2. Content Slivers (Conditional)
            if (_tabController.index == 0) ...[
              // ACTIVE ORDERS SLIVERS
              ordersAsync.when(
                data: (orders) {
                  final activeOrders = orders
                      .where((o) => o.status != OrderStatus.completed)
                      .toList();
                  final activeState = OrderHistoryState(
                    orders: activeOrders,
                    hasMore: false,
                  );
                  return SliverOrderList(
                    state: activeState,
                    isEmptyMessage: "No active orders",
                    isHistory: false,
                    isArchived: false,
                  );
                },
                loading: () =>
                    SliverToBoxAdapter(child: SoftShimmer.orderCard()),
                error: (e, s) => SliverToBoxAdapter(
                  child: ErrorView(
                    message: "Failed to load active orders.",
                    onRetry: () => ref.invalidate(ordersStreamProvider),
                    retryLabel: "Retry",
                  ),
                ),
              ),
            ] else ...[
              // HISTORY ORDERS SLIVERS
              historyAsync.when(
                loading: () =>
                    SliverToBoxAdapter(child: SoftShimmer.orderCard()),
                error: (e, s) => SliverToBoxAdapter(
                  child: ErrorView(
                    message: "Failed to load history.",
                    onRetry: () {
                      ref.read(orderHistoryProvider(false).notifier).refresh();
                    },
                    retryLabel: "Refresh",
                  ),
                ),
                data: (state) => SliverMainAxisGroup(
                  slivers: [
                    // Categories
                    SliverToBoxAdapter(
                      child: Container(
                        height: 48,
                        margin: const EdgeInsets.only(top: 12, bottom: 0),
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          children: [
                            _CategoryChip(
                              label: "All",
                              isSelected: state.typeFilter == null,
                              isDisabled: state.filterVoided,
                              onTap: () {
                                ref
                                    .read(orderHistoryProvider(false).notifier)
                                    .setTypeFilter(null);
                                HapticFeedback.selectionClick();
                              },
                            ),
                            const SizedBox(width: 8),
                            _CategoryChip(
                              label: "Reservations",
                              isSelected:
                                  state.typeFilter == OrderType.standard,
                              isDisabled: state.filterVoided,
                              onTap: () {
                                ref
                                    .read(orderHistoryProvider(false).notifier)
                                    .setTypeFilter(OrderType.standard);
                                HapticFeedback.selectionClick();
                              },
                            ),
                            const SizedBox(width: 8),
                            _CategoryChip(
                              label: "Quick Sales",
                              isSelected:
                                  state.typeFilter == OrderType.manualReduction,
                              isDisabled: state.filterVoided,
                              onTap: () {
                                ref
                                    .read(orderHistoryProvider(false).notifier)
                                    .setTypeFilter(OrderType.manualReduction);
                                HapticFeedback.selectionClick();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Date Range Bar (Pinned)
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _DateRangeHeaderDelegate(state: state),
                    ),

                    // Audit Bar
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _SlimAuditBar(state: state),
                      ),
                    ),

                    // List
                    SliverOrderList(
                      state: state,
                      isEmptyMessage: state.filterVoided
                          ? "No voided orders found."
                          : "No history found",
                      isHistory: true,
                      isArchived: false,
                    ),
                  ],
                ),
              ),
            ],
          ],
          bottomSheet: (historyState?.isSelectionMode ?? false) && !isEmployee
              ? const SelectionToolbar(isArchived: false)
              : null,
        ),
      ),
    );
  }
}

class _SlimAuditBar extends ConsumerWidget {
  final OrderHistoryState state;
  const _SlimAuditBar({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.softColors;
    // 1. Fetch Global Void Count
    final voidCountAsync = ref.watch(voidedOrdersCountProvider);
    final globalVoidCount = voidCountAsync.value ?? 0;
    final isDisabled = state.filterVoided;

    return SizedBox(
      height: 40, // Reduced height for sub-filters
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          // Date Shortcuts
          _AuditChip(
            label: "Today",
            isSelected: _isRangeToday(state.dateRange),
            isDisabled: isDisabled,
            onTap: () {
              final now = DateTime.now();
              final range = DateTimeRange(
                start: DateTime(now.year, now.month, now.day),
                end: now,
              );
              ref
                  .read(orderHistoryProvider(false).notifier)
                  .setDateRange(range);
              HapticFeedback.lightImpact();
            },
          ),
          const SizedBox(width: 8),
          _AuditChip(
            label: "Yesterday",
            isSelected: _isRangeYesterday(state.dateRange),
            isDisabled: isDisabled,
            onTap: () {
              final now = DateTime.now();
              final yesterday = now.subtract(const Duration(days: 1));
              final range = DateTimeRange(
                start: DateTime(yesterday.year, yesterday.month, yesterday.day),
                end: DateTime(
                  yesterday.year,
                  yesterday.month,
                  yesterday.day,
                  23,
                  59,
                  59,
                ),
              );
              ref
                  .read(orderHistoryProvider(false).notifier)
                  .setDateRange(range);
              HapticFeedback.lightImpact();
            },
          ),
          const SizedBox(width: 8),

          // Divider
          Container(
            width: 1,
            color: colors.border.withValues(alpha: 0.5),
            margin: const EdgeInsets.symmetric(vertical: 8),
          ),
          const SizedBox(width: 8),

          // Void Toggle
          _AuditChip(
            label: "Voided",
            count: globalVoidCount, // Show Always? Or if (globalVoidCount > 0)
            // User requested to know availablity. Showing 0 is fine if 0.
            isSelected: state.filterVoided,
            isErrorData: true,
            onTap: () {
              ref.read(orderHistoryProvider(false).notifier).toggleVoidFilter();
              HapticFeedback.mediumImpact();
            },
          ),
          const SizedBox(width: 8),

          // Notes Toggle
          _AuditChip(
            label: "Notes",
            count: state.filterHasNotes ? state.orders.length : null,
            isSelected: state.filterHasNotes,
            onTap: () {
              ref
                  .read(orderHistoryProvider(false).notifier)
                  .toggleNotesFilter();
              HapticFeedback.mediumImpact();
            },
          ),
        ],
      ),
    );
  }

  bool _isRangeToday(DateTimeRange? range) {
    if (range == null) return false;
    final now = DateTime.now();
    return range.start.year == now.year &&
        range.start.month == now.month &&
        range.start.day == now.day &&
        range.end.day == now.day;
  }

  bool _isRangeYesterday(DateTimeRange? range) {
    if (range == null) return false;
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    return range.start.year == yesterday.year &&
        range.start.day == yesterday.day;
  }
}

class _AuditChip extends StatelessWidget {
  final String label;
  final int? count;
  final bool isSelected;
  final bool isDisabled;
  final bool isErrorData;
  final VoidCallback onTap;

  const _AuditChip({
    required this.label,
    this.count,
    required this.isSelected,
    this.isDisabled = false,
    required this.onTap,
    this.isErrorData = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.softColors;
    final color = isErrorData ? colors.error : colors.brandPrimary;

    return IgnorePointer(
      ignoring: isDisabled,
      child: Opacity(
        opacity: isDisabled ? 0.4 : 1.0,
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? color.withValues(alpha: 0.1) : colors.surface,
              border: Border.all(
                color: isSelected
                    ? color
                    : colors.border.withValues(alpha: 0.5),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    color: isSelected ? color : colors.textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "$count",
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// OrderCard Update for Void Logic
class OrderCard extends ConsumerWidget {
  final OrderModel order;
  final bool isArchived;
  const OrderCard({super.key, required this.order, required this.isArchived});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(orderHistoryProvider(isArchived));
    final historyState = historyAsync.valueOrNull;
    final isSelected = historyState?.selectedIds.contains(order.id) ?? false;
    final user = ref.watch(currentUserProfileProvider).value;
    final isEmployee = user?.role == UserRole.employee;
    final colors = context.softColors; // Access colors

    final isVoided = order.isVoided; // New field check

    // Content Widget
    Widget cardContent;
    if (order.customer.name == 'Quick Sale') {
      cardContent = QuickSaleOrderCard(order: order, isArchived: isArchived);
    } else {
      cardContent = _ReservationOrderCard(order: order);
    }

    // Voided Styling Wrapper (Opacity)
    if (isVoided) {
      cardContent = Opacity(opacity: 0.6, child: cardContent);
    }

    // ... Gesture Logic (Keep existing, update Dismissible) ...

    Widget contentWithOverlay = cardContent;
    if (historyState?.isSelectionMode ?? false) {
      contentWithOverlay = GestureDetector(
        onTap: () {
          ref
              .read(orderHistoryProvider(isArchived).notifier)
              .toggleOrderSelection(order.id);
        },
        child: AbsorbPointer(absorbing: true, child: contentWithOverlay),
      );
    } else {
      if (!isEmployee) {
        contentWithOverlay = GestureDetector(
          onLongPress: () {
            ref
                .read(orderHistoryProvider(isArchived).notifier)
                .enterSelectionModeWithId(order.id);
          },
          child: contentWithOverlay,
        );
      }
    }

    if (!(historyState?.isSelectionMode ?? false) && !isEmployee) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
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
            borderRadius: BorderRadius.circular(16),
            child: Dismissible(
              key: Key(order.id),
              direction: DismissDirection.horizontal,
              // Right: Archive / Restore
              background: _buildSwipeAction(
                alignment: Alignment.centerLeft,
                color: isArchived ? SoftColors.success : Colors.orangeAccent,
                icon: isArchived
                    ? Icons.unarchive_rounded
                    : Icons.archive_outlined,
                label: isArchived ? "Restore" : "Archive",
              ),
              // Left: Void (Active) or Purge (Voided)
              secondaryBackground: _buildSwipeAction(
                alignment: Alignment.centerRight,
                color: SoftColors.error,
                // Change Icon/Label based on Void status
                icon: isVoided ? Icons.delete_forever : Icons.delete_outline,
                label: isVoided ? "Purge" : "Void",
              ),
              confirmDismiss: (direction) async {
                if (direction == DismissDirection.startToEnd) {
                  // Archive Logic (Keep existing)
                  final newArchiveStatus = !isArchived;
                  try {
                    await ref
                        .read(ordersRepositoryProvider)
                        .archiveOrder(order.id, newArchiveStatus);
                    ref
                        .read(orderHistoryProvider(isArchived).notifier)
                        .removeOrderLocally(order.id);

                    // Refresh the opposite list so the order appears there immediately
                    ref
                        .read(orderHistoryProvider(!isArchived).notifier)
                        .refresh();

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            newArchiveStatus ? "Archived" : "Restored",
                          ),
                        ),
                      );
                    }
                    return true;
                  } catch (e) {
                    return false;
                  }
                } else {
                  // Swipe Left -> Void or Purge
                  if (isVoided) {
                    // PURGE (Hard Delete)
                    final confirm = await showSoftDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        backgroundColor: colors.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            SoftColors.cardRadius,
                          ),
                        ),
                        title: Text(
                          "Permanent Purge",
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        content: Text(
                          "Delete forever? Cannot undo.",
                          style: GoogleFonts.outfit(
                            color: colors.textSecondary,
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
                              "Purge",
                              style: GoogleFonts.outfit(
                                color: colors.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      ref
                          .read(orderHistoryProvider(isArchived).notifier)
                          .executePurgeOrder(order.id);
                      return true;
                    }
                    return false;
                  } else {
                    // VOID (Soft Delete + Restore Stock)
                    // Show confirmation or undo? "Undo Support (Snackbar)".
                    // Usually Void is destructive, so a dialog is safer, but Snackbar Undo is nice for speed.
                    // Let's do instant Void with Undo Snackbar.

                    try {
                      await ref
                          .read(orderHistoryProvider(isArchived).notifier)
                          .executeVoidOrder(order.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              "Order Voided & Stock Restored",
                            ),
                            // action: SnackBarAction(
                            //   label: "UNDO",
                            //   onPressed: () {
                            //     // Undo not supported yet
                            //   },
                            // ),
                          ),
                        );
                      }
                      return true;
                    } catch (e) {
                      return false;
                    }
                  }
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? colors.brandPrimary.withValues(alpha: 0.05)
                      : colors.surface,
                  border: Border.all(
                    color: isSelected
                        ? colors.brandPrimary
                        : Colors.transparent,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: contentWithOverlay,
              ),
            ),
          ),
        ),
      );
    }

    // Non-Dismissible Fallback
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? colors.brandPrimary.withValues(alpha: 0.05)
              : colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? colors.brandPrimary : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
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
    String? label,
  }) {
    return Container(
      alignment: alignment,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 28),
          if (label != null)
            Text(
              label,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }
}

// ... (Existing OrderCard and other classes)

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isDisabled;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    this.isDisabled = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.softColors;
    return IgnorePointer(
      ignoring: isDisabled,
      child: Opacity(
        opacity: isDisabled ? 0.4 : 1.0,
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? colors.brandPrimary : colors.surface,
              borderRadius: BorderRadius.circular(14), // Modern soft round
              border: Border.all(
                color: isSelected
                    ? Colors.transparent
                    : colors.border.withValues(alpha: 0.5),
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: colors.brandPrimary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              style: GoogleFonts.outfit(
                color: isSelected ? Colors.white : colors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DateRangeBar extends ConsumerStatefulWidget {
  final OrderHistoryState state;
  const _DateRangeBar({required this.state});

  @override
  ConsumerState<_DateRangeBar> createState() => _DateRangeBarState();
}

class _DateRangeBarState extends ConsumerState<_DateRangeBar> {
  bool _slideFromRight = true;

  @override
  void didUpdateWidget(covariant _DateRangeBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Determine slide direction based on date comparison
    final oldRange = oldWidget.state.dateRange;
    final newRange = widget.state.dateRange;

    if (oldRange != newRange) {
      // Trigger haptic on date change
      HapticFeedback.mediumImpact();

      if (newRange == null || oldRange == null) {
        _slideFromRight = newRange != null;
      } else {
        // Compare start dates for direction
        _slideFromRight = newRange.start.isAfter(oldRange.start);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasRange = widget.state.dateRange != null;
    final isDisabled = widget.state.filterVoided;
    final formatter = DateFormat('MMM dd');
    String label = "Filter by Date Range";
    if (hasRange) {
      final start = formatter.format(widget.state.dateRange!.start);
      final end = formatter.format(widget.state.dateRange!.end);
      if (start == end) {
        label = start;
      } else {
        label = "$start - $end";
      }
    }

    return Row(
      children: [
        Expanded(
          child: IgnorePointer(
            ignoring: isDisabled,
            child: Opacity(
              opacity: isDisabled ? 0.4 : 1.0,
              child: GestureDetector(
                onTap: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    initialDateRange: widget.state.dateRange,
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.light(
                            primary: SoftColors.brandPrimary,
                            onPrimary: Colors.white,
                            surface: Colors.white,
                            onSurface: SoftColors.textMain,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    ref
                        .read(orderHistoryProvider(false).notifier)
                        .setDateRange(picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: SoftColors.border.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 18,
                        color: hasRange
                            ? SoftColors.brandPrimary
                            : SoftColors.textSecondary,
                      ),
                      const SizedBox(width: 12),
                      // Animated date label with directional slide
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) {
                            // Directional slide: right if newer, left if older
                            final slideOffset = _slideFromRight
                                ? Tween<Offset>(
                                    begin: const Offset(0.3, 0),
                                    end: Offset.zero,
                                  )
                                : Tween<Offset>(
                                    begin: const Offset(-0.3, 0),
                                    end: Offset.zero,
                                  );

                            return SlideTransition(
                              position: slideOffset.animate(animation),
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            );
                          },
                          child: Text(
                            label,
                            key: ValueKey<String>(label),
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              color: hasRange
                                  ? SoftColors.brandPrimary
                                  : SoftColors.textSecondary,
                              fontWeight: hasRange
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (hasRange) ...[
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close, color: SoftColors.textSecondary),
            onPressed: () {
              ref.read(orderHistoryProvider(false).notifier).clearDateRange();
              HapticFeedback.lightImpact();
            },
            style: IconButton.styleFrom(
              backgroundColor: SoftColors.surface,
              padding: const EdgeInsets.all(8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class SelectionToolbar extends ConsumerWidget {
  final bool isArchived;

  const SelectionToolbar({super.key, required this.isArchived});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.softColors;
    final stateAsync = ref.watch(orderHistoryProvider(isArchived));
    final state =
        stateAsync.valueOrNull ??
        OrderHistoryState(
          orders: [],
          isArchived: isArchived,
        ); // Fallback if loading

    return Container(
      color: colors.surface,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: SafeArea(
        top: false, // Bottom sheet doesn't need top safe area
        bottom: true, // Critical for iPhone/Android Gesture Bar
        child: Row(
          children: [
            // using colors
            Text(
              "${state.selectedIds.length} Selected",
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(
                    isArchived ? Icons.unarchive : Icons.archive,
                    color: colors.brandPrimary,
                  ),
                  tooltip: isArchived
                      ? "Unarchive Selected"
                      : "Archive Selected",
                  onPressed: () {
                    // If archived, unarchive (pass false). If not, archive (pass true).
                    ref
                        .read(orderHistoryProvider(isArchived).notifier)
                        .executeBulkArchive(!isArchived);
                  },
                ),
                const SizedBox(width: 8),
                // Only show Void (Restore Stock) if NOT in archive? Or both?
                // Usually "Void" is an active order action. In archive, maybe just purge?
                // But let's allow it for flexibility.
                IconButton(
                  icon: Icon(Icons.delete_outline, color: colors.error),
                  tooltip: "Void (Restore Stock)",
                  onPressed: () {
                    _showBulkVoidConfirmation(context, ref);
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.delete_forever, color: colors.error),
                  tooltip: "Purge Selected",
                  onPressed: () {
                    _showBulkPurgeConfirmation(context, ref);
                  },
                ),
              ],
            ),
            const SizedBox(width: 16),
            // Divider
            Container(width: 1, height: 24, color: colors.border),
            const SizedBox(width: 16),
            TextButton(
              onPressed: () {
                ref
                    .read(orderHistoryProvider(isArchived).notifier)
                    .toggleSelectionMode(); // Toggle off to exit
                HapticFeedback.lightImpact();
              },
              child: Text(
                "Cancel",
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
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
                  .read(orderHistoryProvider(isArchived).notifier)
                  .executeBulkVoid();
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
                  .read(orderHistoryProvider(isArchived).notifier)
                  .executeBulkPurge();
            },
            child: const Text("Purge", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class SliverOrderList extends StatelessWidget {
  final OrderHistoryState state;
  final String isEmptyMessage;
  final bool isHistory;
  final bool isArchived;

  const SliverOrderList({
    super.key,
    required this.state,
    required this.isEmptyMessage,
    this.isHistory = false,
    required this.isArchived,
  });

  @override
  Widget build(BuildContext context) {
    if (!state.isLoadingMore && state.orders.isEmpty) {
      return SliverToBoxAdapter(
        child: SoftAnimatedEmpty(
          icon: Icons.inbox_outlined,
          message: isEmptyMessage,
        ),
      );
    }

    final itemCount = isHistory
        ? _groupOrders(state.orders).length + (state.isLoadingMore ? 1 : 0)
        : state.orders.length;

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        // History Grouping Logic
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
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    decoration: BoxDecoration(
                      color: SoftColors.background.withValues(alpha: 0.8),
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
                    .asMap()
                    .entries
                    .map(
                      (e) => SoftFadeInSlide(
                        index: e.key,
                        child: OrderCard(
                          order: e.value,
                          isArchived: isArchived,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          );
        }

        // Active Orders (Linear)
        return SoftFadeInSlide(
          index: index,
          child: OrderCard(order: state.orders[index], isArchived: isArchived),
        );
      }, childCount: itemCount),
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

    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    if (dateCheck.isAfter(weekStart.subtract(const Duration(seconds: 1)))) {
      return "This Week";
    }

    return DateFormat('MMMM dd, yyyy').format(date);
  }
}

class _ReservationOrderCard extends StatelessWidget {
  final OrderModel order;
  const _ReservationOrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final colors = context.softColors;
    final dateStr = DateFormat('MMM dd, yyyy • h:mm a').format(order.createdAt);
    // Display Order ID logic - Shortening for POS display (5 chars is standard)
    final displayId = order.id.length > 5
        ? "#${order.id.substring(0, 5).toUpperCase()}"
        : "#${order.id.toUpperCase()}";

    return BounceButton(
      onTap: () {
        context.go('/orders/detail/${order.id}', extra: order);
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
                    color: colors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  "\$${order.totalAmount.toStringAsFixed(2)}",
                  style: GoogleFonts.outfit(
                    color: colors.textMain,
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
      case OrderStatus.reserved:
        color = const Color(0xFF9333EA); // Purple
        break;
      case OrderStatus.prepping:
        color = SoftColors.brandPrimary; // Active Blue (Pending)
        break;
      case OrderStatus.delivering:
        color = SoftColors.warning; // Orange
        break;
      case OrderStatus.completed:
        color = SoftColors.success;
        break;
      case OrderStatus.cancelled:
        color = SoftColors.error;
        break;
      case OrderStatus.voided:
        color = SoftColors.textSecondary;
        break;
    }

    if (status == OrderStatus.prepping) {
      color = SoftColors.brandPrimary;
    } else if (status == OrderStatus.delivering) {
      color = Colors.orange;
    } else if (status == OrderStatus.reserved) {
      color = const Color(0xFF9333EA);
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
  const QuickSaleOrderCard({
    super.key,
    required this.order,
    required this.isArchived,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.softColors;
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
        context.go('/orders/detail/${order.id}', extra: order);
      },
      child: Container(
        color: colors.surface, // Dynamic surface
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Quick Sale Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.brandPrimary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shopping_bag_outlined,
                color: colors.brandPrimary,
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
                            color: colors.textMain,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Price aligned with Title
                      Text(
                        "\$${order.totalAmount.toStringAsFixed(2)}",
                        style: GoogleFonts.outfit(
                          color: colors.textMain,
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
                                      orderHistoryProvider(isArchived).notifier,
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

class _DateRangeHeaderDelegate extends SliverPersistentHeaderDelegate {
  final OrderHistoryState state;
  const _DateRangeHeaderDelegate({required this.state});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: SoftColors.background, // Match scaffold bg
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      alignment: Alignment.center,
      child: _DateRangeBar(state: state),
    );
  }

  @override
  double get maxExtent => 72; // Appx height of bar + padding

  @override
  double get minExtent => 72;

  @override
  bool shouldRebuild(covariant _DateRangeHeaderDelegate oldDelegate) {
    return oldDelegate.state != state;
  }
}
