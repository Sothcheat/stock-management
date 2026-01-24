import '../order.dart';

abstract class OrderRepository {
  Stream<List<OrderModel>> getOrdersStream();
  Future<void> createOrder(OrderModel order);
  Future<void> updateOrderStatus(String orderId, OrderStatus status);
  Future<void> updateOrder(OrderModel order);
  Future<void> deleteOrder(OrderModel order);
}
