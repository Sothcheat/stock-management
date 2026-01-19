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
      // 1. Check stock for all items
      for (final item in order.items) {
        final productRef = _firestore
            .collection('products')
            .doc(item.productId);
        final productDoc = await transaction.get(productRef);

        if (!productDoc.exists) {
          throw Exception("Product ${item.name} not found");
        }

        final product = Product.fromFirestore(productDoc);

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

          // Update variant stock in local object to prepare for write
          // Note: arrays in Firestore are tricky to update partially inside nested objects without reading.
          // Since we read the doc, we modify the list and write the whole variants array back (or partial).
          // For simplicity/safety, we will write the Updated Product back.

          // Logic:
          // newVariants[i].stock -= qty
          // totalStock -= qty
        } else {
          // No variant, check total stock (assuming no variants logic, or main stock)
          // Based on schema, if variants exist, totalStock is sum.
          // If product has no variants, usage of variants list is empty.
          // But wait, the schema says totalStock is sum of variants.
          // If a product has NO variants, does it track totalStock directly?
          // Let's assume for this project: Products ALWAYS have at least one variant?
          // OR: If variants list is empty, we use totalStock directly.

          if (product.variants.isEmpty) {
            if (product.totalStock < item.quantity) {
              throw Exception("Insufficient stock for ${item.name}");
            }
          } else {
            // If variants exist, user MUST select a variant.
            // If item.variantId is null but variants exist, that's an error in UI logic potentially.
            if (item.variantId == null)
              throw Exception("Please select a variant for ${item.name}");
          }
        }
      }

      // 2. Deduct Stock (Second Pass or Combined)
      // Since we need to write multiple updates, we iterate again or do it in one pass if we kept the refs.
      // Refetch logic might be needed if we want to be super strict, but inside transaction we are safe from outside modifications on these docs.

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

      // 3. Create Order
      // We need to inject the ID into the model or let Firestore generate it and update model?
      // Model passed in already has an ID? Usually we prefer Firestore to generate ID.
      // Let's create a new ref with ID from passed model (if UUID) or generation.
      // Since OrderModel in UI probably generates a UUID or empty.
      // Cleanest: Let UI generate UUID for ID.

      transaction.set(
        _firestore.collection('orders').doc(order.id),
        order.toFirestore(),
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
