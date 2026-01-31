import 'package:flutter/material.dart';
import '../../../inventory/domain/product.dart';
import '../order.dart';

/// Interface for Order Data Access.
/// Decouples Domain/UI from Firestore implementation.
abstract interface class IOrderRepository {
  /// Watches the stream of active orders.
  Stream<List<OrderModel>> getOrdersStream();

  /// Watches a specific order by ID.
  Stream<OrderModel?> getOrderStream(String orderId);

  /// Fetches paginated history of orders with filters.
  /// [startAfter] is an opaque cursor (e.g. DocumentSnapshot) managed by the repo.
  Future<List<OrderModel>> getOrdersHistory({
    int limit = 20,
    Object? startAfter,
    DateTimeRange? dateRange,
    String? statusFilter,
    OrderType? typeFilter,
    bool isArchived = false,
    bool filterVoided = false,
  });

  /// Creates a new order in the database.
  Future<void> createOrder(OrderModel order);

  /// Updates an existing order.
  Future<void> updateOrder(OrderModel order);

  /// Deletes an order (Standard delete, usually for non-finalized orders).
  Future<void> deleteOrder(OrderModel order);

  /// Updates the status of an order.
  Future<void> updateOrderStatus(String orderId, OrderStatus status);

  /// Creates a quick sale order for a single product.
  Future<void> createQuickSale(Product product, int quantity);

  /// Creates a quick sale order for a batch of items. Returns Order ID.
  Future<String> createBatchQuickSale(List<OrderItem> items);

  /// Reverts a quick sale, restoring stock and deleting the order.
  Future<void> revertQuickSaleOrder(String orderId);

  // --- Data Lifecycle Actions ---

  /// Archives or un-archives an order. Archived orders are hidden from main lists.
  Future<void> archiveOrder(String orderId, bool archive);

  /// Soft-deletes an order and restores its stock.
  /// Sets [isVoided] to true.
  Future<void> voidOrder(String orderId);

  /// Permanently deletes an order from the database (Hard Delete).
  /// This action is irreversible.
  Future<void> permanentPurgeOrder(String orderId);

  /// Bulk archives/un-archives multiple orders.
  Future<void> bulkArchive(List<String> ids, bool archive);

  /// Bulk permanently deletes multiple orders.
  Future<void> bulkPurge(List<String> ids);

  // --- Counts ---

  /// Watches the total count of voided orders.
  Stream<int> watchVoidedCount();

  /// Watches completed orders within a date range (for Reports).
  Stream<List<OrderModel>> watchCompletedOrders(DateTime start, DateTime end);

  /// Stream dealing with NEW or UPDATED orders that enter 'Reserved' status.
  /// Intended for Real-time alerts (Notifications).
  Stream<OrderModel> onReservedOrderAdded();
}
