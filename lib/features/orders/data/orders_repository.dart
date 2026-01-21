import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../inventory/domain/product.dart';
import '../domain/order.dart';

part 'orders_repository.g.dart';

@Riverpod(keepAlive: true)
OrdersRepository ordersRepository(Ref ref) {
  return OrdersRepository(FirebaseFirestore.instance);
}

@riverpod
Stream<List<OrderModel>> ordersStream(Ref ref) {
  return ref.watch(ordersRepositoryProvider).getOrdersStream();
}

class OrdersRepository {
  final FirebaseFirestore _firestore;

  OrdersRepository(this._firestore);

  Stream<List<OrderModel>> getOrdersStream() {
    return _firestore
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => OrderModel.fromFirestore(doc))
              .toList(),
        );
  }

  Future<void> createOrder(OrderModel order) async {
    // Run as transaction to ensure stock consistency
    await _firestore.runTransaction((transaction) async {
      List<OrderItem> itemsWithCost = [];

      // 1. Check stock for all items AND capture cost price
      for (final item in order.items) {
        final productRef = _firestore
            .collection('products')
            .doc(item.productId);
        final productDoc = await transaction.get(productRef);

        if (!productDoc.exists) {
          throw Exception("Product ${item.name} not found");
        }

        final product = Product.fromFirestore(productDoc);

        // Capture cost price from the product at this moment
        itemsWithCost.add(item.copyWith(costPriceAtSale: product.costPrice));

        // Variant Logic
        if (item.variantId != null) {
          final variantIndex = product.variants.indexWhere(
            (v) => v.id == item.variantId,
          );
          if (variantIndex == -1) {
            throw Exception(
              "Variant ${item.variantName} not found for ${item.name}",
            );
          }

          final variant = product.variants[variantIndex];
          if (variant.stockQuantity < item.quantity) {
            throw Exception(
              "Insufficient stock for ${item.name} (${item.variantName})",
            );
          }
        } else {
          if (product.variants.isEmpty) {
            if (product.totalStock < item.quantity) {
              throw Exception("Insufficient stock for ${item.name}");
            }
          } else {
            if (item.variantId == null) {
              throw Exception("Please select a variant for ${item.name}");
            }
          }
        }
      }

      // 2. Deduct Stock (Second Pass to ensure we don't start deducting if any check fails)
      for (final item in order.items) {
        final productRef = _firestore
            .collection('products')
            .doc(item.productId);
        final productDoc = await transaction.get(
          productRef,
        ); // Read again within transaction scope (cached)
        final product = Product.fromFirestore(productDoc);

        List<ProductVariant> newVariants = List.from(product.variants);
        int newTotalStock = product.totalStock;

        if (item.variantId != null) {
          final index = newVariants.indexWhere((v) => v.id == item.variantId);
          if (index != -1) {
            final oldVariant = newVariants[index];
            newVariants[index] = ProductVariant(
              id: oldVariant.id,
              name: oldVariant.name,
              stockQuantity: oldVariant.stockQuantity - item.quantity,
            );
          }
        }

        newTotalStock -= item.quantity;

        transaction.update(productRef, {
          'variants': newVariants.map((v) => v.toMap()).toList(),
          'totalStock': newTotalStock,
        });
      }

      // 3. Create Order with updated items (containing cost price)
      final orderToSave = OrderModel(
        id: order.id,
        customer: order.customer,
        deliveryAddress: order.deliveryAddress,
        items: itemsWithCost, // Use items with cost price
        totalAmount: order.totalAmount,
        status: order.status,
        createdBy: order.createdBy,
        createdAt: order.createdAt,
        updatedAt: order.updatedAt,
      );

      transaction.set(
        _firestore.collection('orders').doc(order.id),
        orderToSave.toFirestore(),
      );
    });
  }

  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    await _firestore.collection('orders').doc(orderId).update({
      'status': status.name,
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> deleteOrder(OrderModel order) async {
    // When deleting an order, we must RESTORE stock!
    await _firestore.runTransaction((transaction) async {
      // 1. Restore Stock
      for (final item in order.items) {
        final productRef = _firestore
            .collection('products')
            .doc(item.productId);
        final productDoc = await transaction.get(productRef);

        if (productDoc.exists) {
          final product = Product.fromFirestore(productDoc);

          List<ProductVariant> newVariants = List.from(product.variants);
          int newTotalStock = product.totalStock;

          if (item.variantId != null) {
            final index = newVariants.indexWhere((v) => v.id == item.variantId);
            if (index != -1) {
              final oldVariant = newVariants[index];
              newVariants[index] = ProductVariant(
                id: oldVariant.id,
                name: oldVariant.name,
                stockQuantity: oldVariant.stockQuantity + item.quantity,
              );
            }
          }
          newTotalStock += item.quantity;

          transaction.update(productRef, {
            'variants': newVariants.map((v) => v.toMap()).toList(),
            'totalStock': newTotalStock,
          });
        }
      }

      // 2. Delete Order
      transaction.delete(_firestore.collection('orders').doc(order.id));
    });
  }
}
