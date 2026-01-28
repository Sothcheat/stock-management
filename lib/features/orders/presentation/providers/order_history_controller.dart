import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/firebase_orders_repository.dart';
import '../../domain/order.dart';

part 'order_history_controller.g.dart';

class OrderHistoryState {
  final List<OrderModel> orders;
  final bool isLoadingMore;
  final bool hasMore;
  final DocumentSnapshot? lastDoc;
  final DateTimeRange? dateRange;
  final String? statusFilter;
  final OrderType? typeFilter;
  final bool isLoadingInitial; // Restored
  final bool isSelectionMode;
  final Set<String> selectedIds;
  final bool isArchived;
  final String? errorMessage;
  final double totalRevenue;
  final int totalItems;

  OrderHistoryState({
    required this.orders,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.lastDoc,
    this.dateRange,
    this.statusFilter,
    this.typeFilter,
    this.isLoadingInitial = false,
    this.isSelectionMode = false,
    this.selectedIds = const {},
    this.isArchived = false,
    this.errorMessage,
    this.totalRevenue = 0.0,
    this.totalItems = 0,
  });

  OrderHistoryState copyWith({
    List<OrderModel>? orders,
    bool? isLoadingMore,
    bool? hasMore,
    DocumentSnapshot? lastDoc,
    DateTimeRange? dateRange,
    String? statusFilter,
    OrderType? typeFilter,
    bool? isLoadingInitial,
    bool? isSelectionMode,
    Set<String>? selectedIds,
    bool? isArchived,
    String? errorMessage,
    double? totalRevenue,
    int? totalItems,
  }) {
    return OrderHistoryState(
      orders: orders ?? this.orders,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      lastDoc: lastDoc ?? this.lastDoc,
      dateRange: dateRange ?? this.dateRange,
      statusFilter: statusFilter ?? this.statusFilter,
      typeFilter: typeFilter ?? this.typeFilter,
      isLoadingInitial: isLoadingInitial ?? this.isLoadingInitial,
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      selectedIds: selectedIds ?? this.selectedIds,
      isArchived: isArchived ?? this.isArchived,
      errorMessage: errorMessage ?? this.errorMessage,
      totalRevenue: totalRevenue ?? this.totalRevenue,
      totalItems: totalItems ?? this.totalItems,
    );
  }
}

// KeepAlive to preserve state when switching tabs
@Riverpod(keepAlive: true)
class OrderHistory extends _$OrderHistory {
  @override
  OrderHistoryState build({bool isArchived = false}) {
    // Initial fetch - delayed to ensure provider is built
    Future.microtask(() => _fetchOrders(isRefresh: true));
    return OrderHistoryState(
      orders: [],
      isLoadingInitial: true,
      hasMore: true,
      isArchived: isArchived,
    );
  }

  Future<void> refresh() async {
    await _fetchOrders(isRefresh: true);
  }

  Future<void> loadMore() async {
    // Gatekeeper: Prevent multiple calls or calls when no more data
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);
    await _fetchOrders(isRefresh: false);
  }

  Future<void> setDateRange(DateTimeRange? range) async {
    // Reset and Fetch using constructor to be safe
    state = OrderHistoryState(
      orders: [],
      isLoadingInitial: true,
      hasMore: true,
      lastDoc: null,
      dateRange: range,
      typeFilter: state.typeFilter,
      statusFilter: state.statusFilter,
      isArchived: state.isArchived,
    );
    await _fetchOrders(isRefresh: true);
  }

  Future<void> setStatusFilter(String? status) async {
    state = state.copyWith(
      statusFilter: status,
      orders: [],
      lastDoc: null,
      hasMore: true,
      isLoadingInitial: true,
    );
    await _fetchOrders(isRefresh: true);
  }

  Future<void> setTypeFilter(OrderType? type) async {
    debugPrint('DEBUG: Setting state to $type and resetting list');
    // Force reset with loading state using constructor to correctly clear nullables
    state = OrderHistoryState(
      orders: [],
      isLoadingInitial: true,
      hasMore: true,
      lastDoc: null,
      typeFilter: type, // Explicitly passed (null or value)
      statusFilter: state.statusFilter, // Preserve
      dateRange: state.dateRange, // Preserve
      isArchived: state.isArchived, // Preserve
    );

    try {
      await _fetchOrders(isRefresh: true);
    } catch (e) {
      debugPrint('DEBUG ERROR in setTypeFilter: $e');
      state = state.copyWith(
        isLoadingInitial: false,
        errorMessage: 'Failed to load orders: ${e.toString()}',
      );
    }
  }

  Future<void> clearDateRange() async {
    debugPrint("DEBUG: clearDateRange called");
    state = OrderHistoryState(
      orders: [],
      isLoadingInitial: true,
      hasMore: true,
      lastDoc: null,
      dateRange: null, // Explicitly null
      typeFilter: state.typeFilter,
      statusFilter: state.statusFilter,
      isArchived: state.isArchived,
    );
    await _fetchOrders(isRefresh: true);
  }

  Future<void> _fetchOrders({required bool isRefresh}) async {
    try {
      final repo = ref.read(ordersRepositoryProvider);

      final currentOrders = isRefresh ? <OrderModel>[] : state.orders;
      final startAfter = isRefresh ? null : state.lastDoc;
      final limit = 20;

      final newOrders = await repo.getOrdersHistory(
        limit: limit,
        startAfter: startAfter,
        dateRange: state.dateRange,
        statusFilter: state.statusFilter,
        typeFilter: state.typeFilter,
        isArchived: state.isArchived,
      );

      if (newOrders.isEmpty) {
        state = state.copyWith(
          hasMore: false,
          // If refresh and empty, orders is empty list
          orders: isRefresh ? [] : state.orders,
        );
        return;
      }

      final hasMore = newOrders.length == limit;
      final updatedList = [...currentOrders, ...newOrders];
      final lastDoc = newOrders.last.snapshot;

      // Calculate totals
      double newRevenue = 0;
      int newItems = 0;
      for (final order in updatedList) {
        newRevenue += order.totalRevenue;
        for (final item in order.items) {
          newItems += item.quantity;
        }
      }

      state = state.copyWith(
        orders: updatedList,
        hasMore: hasMore,
        lastDoc: lastDoc ?? state.lastDoc,
        totalRevenue: newRevenue,
        totalItems: newItems,
      );
    } catch (e) {
      debugPrint("OrderHistory Error: $e");
      state = state.copyWith(
        errorMessage: 'Error loading orders: ${e.toString()}',
      );
    } finally {
      state = state.copyWith(isLoadingMore: false, isLoadingInitial: false);
    }
  }

  void removeOrderLocally(String orderId) {
    if (state.orders.isEmpty) return;
    final updatedList = state.orders.where((o) => o.id != orderId).toList();

    // Recalculate totals
    double newRevenue = 0;
    int newItems = 0;
    for (final order in updatedList) {
      newRevenue += order.totalRevenue;
      for (final item in order.items) {
        newItems += item.quantity;
      }
    }

    state = state.copyWith(
      orders: updatedList,
      totalRevenue: newRevenue,
      totalItems: newItems,
    );
  }

  void updateOrderLocally(OrderModel updatedOrder) {
    if (state.orders.isEmpty) return;
    final index = state.orders.indexWhere((o) => o.id == updatedOrder.id);
    if (index != -1) {
      final updatedList = List<OrderModel>.from(state.orders);
      updatedList[index] = updatedOrder;
      state = state.copyWith(orders: updatedList);
    }
  }

  void addOrderLocally(OrderModel order) {
    final updatedList = [order, ...state.orders];
    state = state.copyWith(orders: updatedList);
  }

  // --- Selection Mode & Data Lifecycle ---

  void toggleSelectionMode() {
    final newMode = !state.isSelectionMode;
    state = state.copyWith(
      isSelectionMode: newMode,
      selectedIds: newMode ? {} : {}, // Clear on exit
    );
    if (newMode) {
      HapticFeedback.mediumImpact(); // Ignition Logic
    }
  }

  void toggleOrderSelection(String orderId) {
    if (!state.isSelectionMode) return;
    final currentIds = Set<String>.from(state.selectedIds);
    if (currentIds.contains(orderId)) {
      currentIds.remove(orderId);
    } else {
      currentIds.add(orderId);
    }
    state = state.copyWith(selectedIds: currentIds);
    HapticFeedback.selectionClick();
  }

  void selectAll() {
    if (state.orders.isEmpty) return;
    final allIds = state.orders.map((e) => e.id).toSet();
    state = state.copyWith(selectedIds: allIds);
    HapticFeedback.mediumImpact();
  }

  void clearSelection() {
    state = state.copyWith(selectedIds: {});
  }

  // Bulk Actions
  Future<void> executeBulkArchive(bool archive) async {
    final ids = state.selectedIds.toList();
    if (ids.isEmpty) return;

    try {
      await ref.read(ordersRepositoryProvider).bulkArchive(ids, archive);

      // Update Local State immediately
      // Assuming we are in Main History (isArchived=false), archiving removes them.
      // If we are in Archive (isArchived=true) and un-archive (archive=false), removes them.
      // So in both cases, we remove from current list filter.

      final updatedList = state.orders
          .where((o) => !ids.contains(o.id))
          .toList();
      state = state.copyWith(
        orders: updatedList,
        isSelectionMode: false,
        selectedIds: {},
      );
    } catch (e) {
      debugPrint("Bulk Archive Failed: $e");
    }
  }

  Future<void> executeBulkPurge() async {
    final ids = state.selectedIds.toList();
    if (ids.isEmpty) return;

    try {
      await ref.read(ordersRepositoryProvider).bulkPurge(ids);
      final updatedList = state.orders
          .where((o) => !ids.contains(o.id))
          .toList();
      state = state.copyWith(
        orders: updatedList,
        isSelectionMode: false,
        selectedIds: {},
      );
    } catch (e) {
      debugPrint("Bulk Purge Failed: $e");
    }
  }

  Future<void> executeBulkDelete() async {
    final ids = state.selectedIds.toList();
    if (ids.isEmpty) return;

    try {
      await ref.read(ordersRepositoryProvider).bulkDelete(ids);
      final updatedList = state.orders
          .where((o) => !ids.contains(o.id))
          .toList();
      state = state.copyWith(
        orders: updatedList,
        isSelectionMode: false,
        selectedIds: {},
      );
    } catch (e) {
      debugPrint("Bulk Delete Failed: $e");
    }
  }
}
