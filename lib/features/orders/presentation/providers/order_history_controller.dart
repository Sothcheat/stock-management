import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  final bool isLoadingInitial;

  OrderHistoryState({
    required this.orders,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.lastDoc,
    this.dateRange,
    this.statusFilter,
    this.typeFilter,
    this.isLoadingInitial = false,
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
    );
  }
}

// KeepAlive to preserve state when switching tabs
@Riverpod(keepAlive: true)
class OrderHistory extends _$OrderHistory {
  @override
  OrderHistoryState build() {
    // Initial fetch - delayed to ensure provider is built
    Future.microtask(() => _fetchOrders(isRefresh: true));
    return OrderHistoryState(orders: [], isLoadingInitial: true, hasMore: true);
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
    debugPrint("DEBUG: setTypeFilter called with $type");
    // Use constructor directly to allow setting 'typeFilter' to null
    // (copyWith '??' logic would ignore null)
    state = OrderHistoryState(
      orders: [],
      isLoadingInitial: true,
      hasMore: true,
      lastDoc: null,
      typeFilter: type,
      dateRange: state.dateRange,
      statusFilter: state.statusFilter,
    );
    await _fetchOrders(isRefresh: true);
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

      state = state.copyWith(
        orders: updatedList,
        hasMore: hasMore,
        lastDoc: lastDoc ?? state.lastDoc,
      );
    } catch (e) {
      debugPrint("OrderHistory Error: $e");
    } finally {
      state = state.copyWith(isLoadingMore: false, isLoadingInitial: false);
    }
  }

  void removeOrderLocally(String orderId) {
    if (state.orders.isEmpty) return;
    final updatedList = state.orders.where((o) => o.id != orderId).toList();
    state = state.copyWith(orders: updatedList);
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
}
