import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../inventory/domain/product.dart';
import '../order.dart';

abstract class OrderRepository {
  Stream<List<OrderModel>> getOrdersStream();
  Stream<OrderModel?> getOrderStream(String orderId);
  Future<List<OrderModel>> getOrdersHistory({
    int limit = 20,
    DocumentSnapshot? startAfter,
    DateTimeRange? dateRange,
    String? statusFilter,
    OrderType? typeFilter,
  });
  Future<void> createOrder(OrderModel order);
  Future<void> updateOrder(OrderModel order);
  Future<void> deleteOrder(OrderModel order);
  Future<void> updateOrderStatus(String orderId, OrderStatus status);
  Future<void> createQuickSale(Product product, int quantity);
  Future<String> createBatchQuickSale(List<OrderItem> items);
  Future<void> revertQuickSaleOrder(String orderId);
}
