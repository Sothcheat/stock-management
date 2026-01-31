import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/firebase_orders_repository.dart';
import '../../domain/order.dart';
import '../../../../core/utils/logger.dart';

// Manual Provider
final orderHistoryProvider =
    AsyncNotifierProvider.family<OrderHistory, OrderHistoryState, bool>(() {
      return OrderHistory();
    });

final voidedOrdersCountProvider = StreamProvider<int>((ref) {
  return ref.watch(ordersRepositoryProvider).watchVoidedCount();
});

class OrderHistoryState {
  final List<OrderModel> orders;
  final bool isLoadingMore;
  final bool hasMore;
  final Object? lastDoc; // Opaque cursor
  final DateTimeRange? dateRange;
  final String? statusFilter;
  final OrderType? typeFilter;
  final bool isSelectionMode;
  final Set<String> selectedIds;
  final bool isArchived;
  final double totalRevenue;
  final int totalItems;

  // New Filters
  final bool filterVoided; // Default false (Show Active)
  final bool filterHasNotes; // Default false (Show All)

  OrderHistoryState({
    required this.orders,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.lastDoc,
    this.dateRange,
    this.statusFilter,
    this.typeFilter,
    this.isSelectionMode = false,
    this.selectedIds = const {},
    this.isArchived = false,
    this.totalRevenue = 0.0,
    this.totalItems = 0,
    this.filterVoided = false,
    this.filterHasNotes = false,
  });

  OrderHistoryState copyWith({
    List<OrderModel>? orders,
    bool? isLoadingMore,
    bool? hasMore,
    Object? lastDoc, // Opaque
    DateTimeRange? dateRange,
    bool clearDateRange = false,
    String? statusFilter,
    bool clearStatusFilter = false,
    OrderType? typeFilter,
    bool clearTypeFilter = false,
    bool? isSelectionMode,
    Set<String>? selectedIds,
    bool? isArchived,
    double? totalRevenue,
    int? totalItems,
    bool? filterVoided,
    bool? filterHasNotes,
  }) {
    return OrderHistoryState(
      orders: orders ?? this.orders,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      lastDoc: lastDoc ?? this.lastDoc,
      dateRange: clearDateRange ? null : (dateRange ?? this.dateRange),
      statusFilter: clearStatusFilter
          ? null
          : (statusFilter ?? this.statusFilter),
      typeFilter: clearTypeFilter ? null : (typeFilter ?? this.typeFilter),
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      selectedIds: selectedIds ?? this.selectedIds,
      isArchived: isArchived ?? this.isArchived,
      totalRevenue: totalRevenue ?? this.totalRevenue,
      totalItems: totalItems ?? this.totalItems,
      filterVoided: filterVoided ?? this.filterVoided,
      filterHasNotes: filterHasNotes ?? this.filterHasNotes,
    );
  }
}

class OrderHistory extends FamilyAsyncNotifier<OrderHistoryState, bool> {
  @override
  FutureOr<OrderHistoryState> build(bool isArchived) async {
    // Keep provider alive
    ref.keepAlive();

    // Initial fetch
    return _fetchOrdersInternal(
      baseState: OrderHistoryState(
        orders: [],
        hasMore: true,
        isArchived: isArchived,
      ),
      isRefresh: true,
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return _fetchOrdersInternal(
        baseState: state.requireValue.copyWith(
          orders: [],
          lastDoc: null,
          hasMore: true,
          isLoadingMore: false,
        ),
        isRefresh: true,
      );
    });
  }

  Future<void> loadMore() async {
    final currentState = state.value;
    if (currentState == null ||
        currentState.isLoadingMore ||
        !currentState.hasMore) {
      return;
    }

    // Set loading more flag without triggering full AsyncLoading
    state = AsyncValue.data(currentState.copyWith(isLoadingMore: true));

    try {
      final newState = await _fetchOrdersInternal(
        baseState: currentState,
        isRefresh: false,
      );
      state = AsyncValue.data(newState.copyWith(isLoadingMore: false));
    } catch (e) {
      // Keep old data but maybe show snackbar?
      // Or set error? For load more, we usually usually just stop loading
      state = AsyncValue.data(currentState.copyWith(isLoadingMore: false));
      // Ideally expose error via a side effect or transient field,
      // but strictly 'AsyncValue' handles error for the *whole* state.
      Logger.error("Load more error: $e");
    }
  }

  // --- Filter Methods ---

  Future<void> toggleVoidFilter() async {
    final currentState = state.requireValue;
    final newValue = !currentState.filterVoided;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return _fetchOrdersInternal(
        baseState: currentState.copyWith(
          filterVoided: newValue,
          orders: [],
          hasMore: true,
          lastDoc: null,
          selectedIds: {},
        ),
        isRefresh: true,
      );
    });
  }

  Future<void> toggleNotesFilter() async {
    final currentState = state.requireValue;
    final newValue = !currentState.filterHasNotes;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return _fetchOrdersInternal(
        baseState: currentState.copyWith(
          filterHasNotes: newValue,
          orders: [],
          hasMore: true,
          lastDoc: null,
          selectedIds: {},
        ),
        isRefresh: true,
      );
    });
  }

  Future<void> setDateRange(DateTimeRange? range) async {
    final currentState = state.requireValue;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return _fetchOrdersInternal(
        baseState: currentState.copyWith(
          orders: [],
          hasMore: true,
          lastDoc: null,
          dateRange: range,
        ),
        isRefresh: true,
      );
    });
  }

  Future<void> setTypeFilter(OrderType? type) async {
    final currentState = state.requireValue;
    final newType = (currentState.typeFilter == type) ? null : type;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return _fetchOrdersInternal(
        baseState: currentState.copyWith(
          orders: [],
          hasMore: true,
          lastDoc: null,
          typeFilter: newType,
          clearTypeFilter: newType == null,
        ),
        isRefresh: true,
      );
    });
  }

  Future<void> clearDateRange() async {
    final currentState = state.requireValue;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return _fetchOrdersInternal(
        baseState: currentState.copyWith(
          orders: [],
          hasMore: true,
          lastDoc: null,
          clearDateRange: true,
        ),
        isRefresh: true,
      );
    });
  }

  Future<OrderHistoryState> _fetchOrdersInternal({
    required OrderHistoryState baseState,
    required bool isRefresh,
  }) async {
    final repo = ref.read(ordersRepositoryProvider);

    final currentOrders = isRefresh ? <OrderModel>[] : baseState.orders;
    final startAfter = isRefresh ? null : baseState.lastDoc;
    final limit = 20;

    final effectiveDateRange = baseState.filterVoided
        ? null
        : baseState.dateRange;
    final effectiveStatusFilter = baseState.filterVoided
        ? null
        : baseState.statusFilter;
    final effectiveTypeFilter = baseState.filterVoided
        ? null
        : baseState.typeFilter;

    final rawOrders = await repo.getOrdersHistory(
      limit: limit + 10,
      startAfter: startAfter,
      dateRange: effectiveDateRange,
      statusFilter: effectiveStatusFilter,
      typeFilter: effectiveTypeFilter,
      isArchived: baseState.isArchived,
      filterVoided: baseState.filterVoided,
    );

    final filteredOrders = rawOrders.where((order) {
      if (baseState.filterVoided) {
        if (!order.isVoided) return false;
      } else {
        if (order.isVoided) return false;
      }
      if (baseState.filterHasNotes) {
        if (order.note == null || order.note!.isEmpty) return false;
      }
      return true;
    }).toList();

    final hasMore = rawOrders.length >= limit;
    final updatedList = [...currentOrders, ...filteredOrders];
    final lastDoc = rawOrders.isNotEmpty ? rawOrders.last.snapshot : null;

    final totals = _calculateTotals(updatedList);

    return baseState.copyWith(
      orders: updatedList,
      hasMore: hasMore,
      lastDoc: lastDoc ?? baseState.lastDoc,
      totalRevenue: totals.revenue,
      totalItems: totals.items,
    );
  }

  // Helper
  ({double revenue, int items}) _calculateTotals(List<OrderModel> list) {
    double newRevenue = 0;
    int newItems = 0;
    for (final order in list) {
      if (order.isVoided) continue;
      newRevenue += order.totalRevenue;
      for (final item in order.items) {
        newItems += item.quantity;
      }
    }
    return (revenue: newRevenue, items: newItems);
  }

  // --- Selection & Local Actions ---

  void toggleSelectionMode() {
    final current = state.requireValue;
    final newMode = !current.isSelectionMode;
    state = AsyncValue.data(
      current.copyWith(isSelectionMode: newMode, selectedIds: {}),
    );
    if (newMode) HapticFeedback.mediumImpact();
  }

  void enterSelectionModeWithId(String id) {
    if (state.requireValue.isSelectionMode) return;
    state = AsyncValue.data(
      state.requireValue.copyWith(isSelectionMode: true, selectedIds: {id}),
    );
    HapticFeedback.mediumImpact();
  }

  void toggleOrderSelection(String orderId) {
    final current = state.requireValue;
    if (!current.isSelectionMode) return;
    final currentIds = Set<String>.from(current.selectedIds);
    if (currentIds.contains(orderId)) {
      currentIds.remove(orderId);
    } else {
      currentIds.add(orderId);
    }
    state = AsyncValue.data(current.copyWith(selectedIds: currentIds));
    HapticFeedback.selectionClick();
  }

  void selectAll() {
    final current = state.requireValue;
    if (current.orders.isEmpty) return;
    final allIds = current.orders.map((e) => e.id).toSet();
    state = AsyncValue.data(current.copyWith(selectedIds: allIds));
    HapticFeedback.mediumImpact();
  }

  void clearSelection() {
    state = AsyncValue.data(state.requireValue.copyWith(selectedIds: {}));
  }

  // --- ACTIONS ---

  Future<void> executeVoidOrder(String orderId) async {
    try {
      await ref.read(ordersRepositoryProvider).voidOrder(orderId);
      final current = state.value;
      if (current != null) {
        final idx = current.orders.indexWhere((o) => o.id == orderId);
        if (idx != -1) {
          final updated = current.orders[idx].copyWith(
            isVoided: true,
            status: OrderStatus.cancelled,
          );
          updateOrderLocally(updated);
        }
      }
    } catch (e) {
      Logger.error("Void Order Failed: $e");
      // Could set transient error here if we had a mechanism
    }
  }

  Future<void> executePurgeOrder(String orderId) async {
    try {
      await ref.read(ordersRepositoryProvider).permanentPurgeOrder(orderId);
      removeOrderLocally(orderId);
    } catch (e) {
      Logger.error("Purge Order Failed: $e");
    }
  }

  Future<void> executeBulkArchive(bool archive) async {
    final current = state.requireValue;
    final ids = current.selectedIds.toList();
    if (ids.isEmpty) return;

    try {
      await ref.read(ordersRepositoryProvider).bulkArchive(ids, archive);
      final updatedList = current.orders
          .where((o) => !ids.contains(o.id))
          .toList();
      final totals = _calculateTotals(updatedList);

      state = AsyncValue.data(
        current.copyWith(
          orders: updatedList,
          isSelectionMode: false,
          selectedIds: {},
          totalRevenue: totals.revenue,
          totalItems: totals.items,
        ),
      );
    } catch (e) {
      Logger.error("Bulk Archive Failed: $e");
    }
  }

  Future<void> executeBulkVoid() async {
    final current = state.requireValue;
    final ids = current.selectedIds.toList();
    if (ids.isEmpty) return;

    try {
      for (final id in ids) {
        await ref.read(ordersRepositoryProvider).voidOrder(id);
      }
      await refresh(); // Refresh to get correct voided state
      toggleSelectionMode();
    } catch (e) {
      Logger.error("Bulk Void Failed");
    }
  }

  Future<void> executeBulkPurge() async {
    final current = state.requireValue;
    final ids = current.selectedIds.toList();
    if (ids.isEmpty) return;
    try {
      await ref.read(ordersRepositoryProvider).bulkPurge(ids);
      final updatedList = current.orders
          .where((o) => !ids.contains(o.id))
          .toList();
      final totals = _calculateTotals(updatedList);
      state = AsyncValue.data(
        current.copyWith(
          orders: updatedList,
          isSelectionMode: false,
          selectedIds: {},
          totalRevenue: totals.revenue,
          totalItems: totals.items,
        ),
      );
    } catch (e) {
      Logger.error("Bulk Purge Failed");
    }
  }

  void removeOrderLocally(String orderId) {
    final current = state.value;
    if (current == null) return;
    final updatedList = current.orders.where((o) => o.id != orderId).toList();
    final totals = _calculateTotals(updatedList);
    state = AsyncValue.data(
      current.copyWith(
        orders: updatedList,
        totalRevenue: totals.revenue,
        totalItems: totals.items,
      ),
    );
  }

  void updateOrderLocally(OrderModel updatedOrder) {
    final current = state.value;
    if (current == null) return;
    final index = current.orders.indexWhere((o) => o.id == updatedOrder.id);
    if (index != -1) {
      final updatedList = List<OrderModel>.from(current.orders);
      if (!current.filterVoided && updatedOrder.isVoided) {
        updatedList.removeAt(index);
      } else {
        updatedList[index] = updatedOrder;
      }
      final totals = _calculateTotals(updatedList);
      state = AsyncValue.data(
        current.copyWith(
          orders: updatedList,
          totalRevenue: totals.revenue,
          totalItems: totals.items,
        ),
      );
    }
  }

  void addOrderLocally(OrderModel order) {
    final current = state.value;
    if (current == null) return;
    if (order.isVoided && !current.filterVoided) return;
    final updatedList = [order, ...current.orders];
    final totals = _calculateTotals(updatedList);
    state = AsyncValue.data(
      current.copyWith(
        orders: updatedList,
        totalRevenue: totals.revenue,
        totalItems: totals.items,
      ),
    );
  }
}
