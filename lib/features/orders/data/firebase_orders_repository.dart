import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../auth/data/providers/auth_providers.dart';
import '../../auth/domain/user_model.dart';
import '../../inventory/data/inventory_repository.dart';
import '../../inventory/domain/product.dart';
import '../domain/order.dart';
import '../domain/repositories/order_repository.dart';

part 'firebase_orders_repository.g.dart';

@Riverpod(keepAlive: true)
OrderRepository ordersRepository(Ref ref) {
  // Injecting InventoryRepository as requested
  final inventoryRepo = ref.watch(inventoryRepositoryProvider);
  return FirebaseOrdersRepository(
    FirebaseFirestore.instance,
    ref,
    inventoryRepo,
  );
}

@riverpod
Stream<List<OrderModel>> ordersStream(Ref ref) {
  return ref.watch(ordersRepositoryProvider).getOrdersStream();
}

class FirebaseOrdersRepository implements OrderRepository {
  final FirebaseFirestore _firestore;
  final Ref _ref;
  // ignore: unused_field
  final InventoryRepository _inventoryRepository;

  FirebaseOrdersRepository(
    this._firestore,
    this._ref,
    this._inventoryRepository,
  );

  UserRole _getCurrentUserRole() {
    final user = _ref.read(currentUserProfileProvider).value;
    return user?.role ?? UserRole.employee;
  }

  void _ensureOwnerOrAdmin(String operation) {
    // Only owner can delete?
    // According to context: Owner/Admin. Employee can sell.
    final role = _getCurrentUserRole();
    if (role == UserRole.employee) {
      throw Exception('Access Denied: Employees cannot $operation');
    }
  }

  @override
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

  @override
  Future<void> createOrder(OrderModel order) async {
    await _firestore.runTransaction((transaction) async {
      // 1. READ PHASE: Fetch all required products first
      // Firestore transactions require all reads to happen before any writes.
      final productIds = order.items.map((e) => e.productId).toSet();
      final Map<String, Product> originalProductMap = {};

      for (final pid in productIds) {
        final productRef = _firestore.collection('products').doc(pid);
        final productDoc = await transaction.get(productRef);

        if (!productDoc.exists) {
          throw Exception("Product with ID $pid not found");
        }
        originalProductMap[pid] = Product.fromFirestore(productDoc);
      }

      // 2. LOGIC PHASE: Validate Stock & Calculate Snapshots
      // We use 'workingProducts' to track stock changes as we iterate (for multiple items of same product)
      final Map<String, Product> workingProducts = Map.from(originalProductMap);
      final List<OrderItem> itemsWithSnapshots = [];

      for (final item in order.items) {
        final currentProduct = workingProducts[item.productId]!;

        // --- A. Snapshot Creation (Pricing) ---
        // Calculate Discount Snapshot based on ORIGINAL product pricing
        // (Use original map for pricing to match DB state at start of transaction)
        final pricingProduct = originalProductMap[item.productId]!;

        double discountAmount = 0.0;
        if (pricingProduct.discountValue != null &&
            pricingProduct.discountValue! > 0) {
          if (pricingProduct.discountType == DiscountType.fixed) {
            discountAmount = pricingProduct.discountValue!;
          } else {
            discountAmount =
                pricingProduct.price * (pricingProduct.discountValue! / 100);
          }
        }

        itemsWithSnapshots.add(
          OrderItem(
            productId: item.productId,
            variantId: item.variantId,
            variantName: item.variantName,
            name: item.name,
            quantity: item.quantity,
            priceAtSale: pricingProduct.price,
            discountAtSale: discountAmount,
            costPriceAtSale: pricingProduct.costPrice,
            shipmentCostAtSale: pricingProduct.shipmentCost ?? 0.0,
          ),
        );

        // --- B. Stock Validation & Deduction ---
        // Check current stock in our working copy
        if (item.variantId != null) {
          // Variant Stock Logic
          final variantIndex = currentProduct.variants.indexWhere(
            (v) => v.id == item.variantId,
          );
          if (variantIndex == -1) {
            throw Exception(
              "Variant ${item.variantName} not found for ${item.name}",
            );
          }

          final variant = currentProduct.variants[variantIndex];
          if (variant.stockQuantity < item.quantity) {
            throw Exception(
              "Insufficient stock for ${item.name} (${item.variantName})",
            );
          }

          // Deduct from Variant
          final newVariants = List<ProductVariant>.from(
            currentProduct.variants,
          );
          newVariants[variantIndex] = ProductVariant(
            id: variant.id,
            name: variant.name,
            stockQuantity: variant.stockQuantity - item.quantity,
          );

          workingProducts[item.productId] = currentProduct.copyWith(
            variants: newVariants,
            // totalStock auto-calculated by getter in Product, but we might need explicitly for safety?
            // Product.totalStock is a getter, so copyWith variants is enough.
          );
        } else {
          // Manual Stock Logic
          if (currentProduct.variants.isEmpty) {
            final currentStock = currentProduct.manualStock ?? 0;
            if (currentProduct.totalStock < item.quantity) {
              // Check totalStock (getter)
              throw Exception("Insufficient stock for ${item.name}");
            }

            workingProducts[item.productId] = currentProduct.copyWith(
              manualStock: currentStock - item.quantity,
            );
          } else {
            if (item.variantId == null) {
              throw Exception("Please select a variant for ${item.name}");
            }
          }
        }
      }

      // 3. WRITE PHASE: Commit Updates

      // A. Update Products
      for (final entry in workingProducts.entries) {
        final pid = entry.key;
        final updatedProduct = entry.value;
        final originalProduct = originalProductMap[pid]!;

        // Check if stock actually changed to avoid unnecessary writes?
        // With transactions, safer to write if we calculated it.
        if (updatedProduct.totalStock != originalProduct.totalStock) {
          final productRef = _firestore.collection('products').doc(pid);

          final updates = <String, dynamic>{
            'totalStock': updatedProduct.totalStock,
            'lastSoldAt': FieldValue.serverTimestamp(),
          };

          if (updatedProduct.variants.isNotEmpty) {
            updates['variants'] = updatedProduct.variants
                .map((v) => v.toMap())
                .toList();
          } else {
            updates['manualStock'] = updatedProduct.manualStock;
          }

          transaction.update(productRef, updates);
        }
      }

      // B. Create Order
      final orderId = order.id.isEmpty
          ? _firestore.collection('orders').doc().id
          : order.id;

      final orderToSave = OrderModel(
        id: orderId,
        customer: order.customer,
        deliveryAddress: order.deliveryAddress,
        items: itemsWithSnapshots,
        logistics: order.logistics,
        totalAmount: order.totalAmount,
        status: order.status,
        note: order.note,
        createdBy: order.createdBy,
        createdAt: order.createdAt,
        updatedAt: order.updatedAt,
      );

      transaction.set(
        _firestore.collection('orders').doc(orderId),
        orderToSave.toFirestore(),
      );
    });
  }

  @override
  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    await _firestore.runTransaction((transaction) async {
      final orderRef = _firestore.collection('orders').doc(orderId);
      final doc = await transaction.get(orderRef);
      if (!doc.exists) throw Exception("Order not found");

      final order = OrderModel.fromFirestore(doc);
      final oldStatus = order.status;

      // Handle Aggregation logic if status changes to/from Completed
      if ((status == OrderStatus.completed &&
              oldStatus != OrderStatus.completed) ||
          (oldStatus == OrderStatus.completed &&
              status != OrderStatus.completed)) {
        final multiplier = (status == OrderStatus.completed) ? 1 : -1;
        await _performAggregationUpdates(transaction, order, multiplier);
      }

      transaction.update(orderRef, {
        'status': status.name,
        'updatedAt': Timestamp.now(),
      });
    });
  }

  // Unified Aggregation Update ensuring Read-Before-Write
  Future<void> _performAggregationUpdates(
    Transaction transaction,
    OrderModel order,
    int multiplier,
  ) async {
    // Use Order's timestamps if completed, or NOW converted to UTC+7 specific context.
    // User requested: "Order Completion Timestamp specifically, converted to the local 'Phnom Penh' timezone (UTC+7)"
    // We don't have 'completedAt' field handy on order (only createdAt/updatedAt).
    // Usually 'updatedAt' is sufficient when status changes to completed.
    final timestamp = order.updatedAt;
    final phnomPenhTime = timestamp.toUtc().add(const Duration(hours: 7));

    final dateKey = phnomPenhTime.toIso8601String().substring(0, 10);
    final monthKey = phnomPenhTime.toIso8601String().substring(0, 7);

    final dailyRef = _firestore.collection('daily_summaries').doc(dateKey);
    final monthlyRef = _firestore.collection('monthly_summaries').doc(monthKey);

    // 1. READ ALL FIRST
    final dailyDoc = await transaction.get(dailyRef);
    final monthlyDoc = await transaction.get(monthlyRef);

    // 2. PREPARE DATA
    final orderRevenue = order.totalRevenue;
    final orderProfit = order.netProfit;
    final orderItemsCount = order.items.fold<int>(0, (p, c) => p + c.quantity);

    // Helper to calculate new product ranking
    Map<String, int> updateRanking(Map<String, dynamic> currentData) {
      final currentRanking = Map<String, int>.from(
        currentData['productRanking'] ?? {},
      );
      for (final item in order.items) {
        final key = item.name;
        final currentQty = currentRanking[key] ?? 0;
        final newQty = currentQty + (item.quantity * multiplier);
        if (newQty <= 0) {
          currentRanking.remove(key);
        } else {
          currentRanking[key] = newQty;
        }
      }
      return currentRanking;
    }

    // Daily Data
    Map<String, int> dailyRanking = {};
    if (dailyDoc.exists) {
      dailyRanking = updateRanking(dailyDoc.data()!);
    } else {
      dailyRanking = updateRanking({});
    }

    // Monthly Data
    Map<String, int> monthlyRanking = {};
    if (monthlyDoc.exists) {
      monthlyRanking = updateRanking(monthlyDoc.data()!);
    } else {
      monthlyRanking = updateRanking({});
    }

    // 3. WRITE ALL
    transaction.set(dailyRef, {
      'totalRevenue': FieldValue.increment(orderRevenue * multiplier),
      'totalProfit': FieldValue.increment(orderProfit * multiplier),
      'itemsSold': FieldValue.increment(orderItemsCount * multiplier),
      'productRanking': dailyRanking,
      'date': dateKey,
    }, SetOptions(merge: true));

    transaction.set(monthlyRef, {
      'totalRevenue': FieldValue.increment(orderRevenue * multiplier),
      'totalProfit': FieldValue.increment(orderProfit * multiplier),
      'itemsSold': FieldValue.increment(orderItemsCount * multiplier),
      'productRanking': monthlyRanking,
      'month': monthKey,
    }, SetOptions(merge: true));
  }

  // Remove old separated helpers to avoid confusion/misuse
  // Future<void> _updateDailySummary(...) async {}
  // Future<void> _updateMonthlySummary(...) async {}

  @override
  Future<void> updateOrder(OrderModel order) async {
    await _firestore.runTransaction((transaction) async {
      final orderRef = _firestore.collection('orders').doc(order.id);
      final doc = await transaction.get(orderRef);
      if (!doc.exists) throw Exception("Order not found");

      final oldOrder = OrderModel.fromFirestore(doc);

      // Handle Aggregation
      if ((order.status == OrderStatus.completed &&
              oldOrder.status != OrderStatus.completed) ||
          (oldOrder.status == OrderStatus.completed &&
              order.status != OrderStatus.completed)) {
        final multiplier = (order.status == OrderStatus.completed) ? 1 : -1;
        await _performAggregationUpdates(transaction, order, multiplier);
      }

      transaction.update(orderRef, {
        ...order.toFirestore(),
        'updatedAt': Timestamp.now(),
      });
    });
  }

  @override
  Future<void> deleteOrder(OrderModel order) async {
    _ensureOwnerOrAdmin('delete orders');

    await _firestore.runTransaction((transaction) async {
      // 1. Restore Stock
      for (final item in order.items) {
        final productRef = _firestore
            .collection('products')
            .doc(item.productId);
        final productDoc = await transaction.get(productRef);

        if (productDoc.exists) {
          final product = Product.fromFirestore(productDoc);
          final Map<String, dynamic> updates = {};

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
              updates['variants'] = newVariants.map((v) => v.toMap()).toList();
            }
          } else {
            if (product.variants.isEmpty) {
              final currentManual = product.manualStock ?? 0;
              updates['manualStock'] = currentManual + item.quantity;
            }
          }

          newTotalStock += item.quantity;
          updates['totalStock'] = newTotalStock;

          transaction.update(productRef, updates);
        }
      }

      // 2. Delete Order
      transaction.delete(_firestore.collection('orders').doc(order.id));
    });
  }
}
