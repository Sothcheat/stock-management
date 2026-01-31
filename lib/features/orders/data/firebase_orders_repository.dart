import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/providers/auth_providers.dart';
import '../../auth/domain/user_model.dart';
import '../../inventory/data/inventory_repository.dart';
import '../../inventory/domain/product.dart';
import '../domain/order.dart';
import '../domain/repositories/order_repository.dart';

// Manual Providers to enforce Interface usage
final ordersRepositoryProvider = Provider<IOrderRepository>((ref) {
  final inventoryRepo = ref.watch(inventoryRepositoryProvider);
  return FirebaseOrdersRepository(
    FirebaseFirestore.instance,
    ref,
    inventoryRepo,
  );
});

final ordersStreamProvider = StreamProvider<List<OrderModel>>((ref) {
  return ref.watch(ordersRepositoryProvider).getOrdersStream();
});

final orderStreamProvider = StreamProvider.family<OrderModel?, String>((
  ref,
  id,
) {
  return ref.watch(ordersRepositoryProvider).getOrderStream(id);
});

class FirebaseOrdersRepository implements IOrderRepository {
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
  Future<void> archiveOrder(String orderId, bool archive) async {
    _ensureOwnerOrAdmin('archive orders');
    await _firestore.collection('orders').doc(orderId).update({
      'isArchived': archive,
      'updatedAt': Timestamp.now(),
    });
  }

  @override
  Future<void> voidOrder(String orderId) async {
    _ensureOwnerOrAdmin('void order');
    await _firestore.runTransaction((transaction) async {
      // 1. READ PHASE: Fetch ALL documents first
      final orderRef = _firestore.collection('orders').doc(orderId);
      final doc = await transaction.get(orderRef);
      if (!doc.exists) throw Exception("Order not found");

      final order = OrderModel.fromFirestore(doc);

      // Constraint: Check if already voided
      if (order.isVoided) {
        throw Exception("Order is already voided");
      }

      // Read Products
      final Map<String, DocumentSnapshot> productDocs = {};
      for (final item in order.items) {
        if (!productDocs.containsKey(item.productId)) {
          productDocs[item.productId] = await transaction.get(
            _firestore.collection('products').doc(item.productId),
          );
        }
      }

      // Read Aggregations (Daily & Monthly)
      // Only if the order was COMPLETED and contributed to stats
      DocumentSnapshot? dailyDoc;
      DocumentSnapshot? monthlyDoc;
      String? dateKey;
      String? monthKey;

      if (order.status == OrderStatus.completed) {
        final timestamp = order.updatedAt;
        final phnomPenhTime = timestamp.toUtc().add(const Duration(hours: 7));
        dateKey = phnomPenhTime.toIso8601String().substring(0, 10);
        monthKey = phnomPenhTime.toIso8601String().substring(0, 7);

        dailyDoc = await transaction.get(
          _firestore.collection('daily_summaries').doc(dateKey),
        );
        monthlyDoc = await transaction.get(
          _firestore.collection('monthly_summaries').doc(monthKey),
        );
      }

      // 2. LOGIC PHASE: Compute Updates
      final Map<DocumentReference, Map<String, dynamic>> batchUpdates = {};

      // A. Compute Stock Restorations
      for (final entry in productDocs.entries) {
        final productId = entry.key;
        final productDoc = entry.value;

        if (productDoc.exists) {
          final product = Product.fromFirestore(productDoc);
          List<ProductVariant> newVariants = List.from(product.variants);
          int restoredManualStock = product.manualStock ?? 0;
          int totalRestored = 0;

          final items = order.items.where((i) => i.productId == productId);

          for (final item in items) {
            totalRestored += item.quantity;
            if (item.variantId != null) {
              final index = newVariants.indexWhere(
                (v) => v.id == item.variantId,
              );
              if (index != -1) {
                final old = newVariants[index];
                newVariants[index] = ProductVariant(
                  id: old.id,
                  name: old.name,
                  stockQuantity: old.stockQuantity + item.quantity,
                );
              }
            } else {
              restoredManualStock += item.quantity;
            }
          }

          final updates = <String, dynamic>{
            'totalStock': product.totalStock + totalRestored,
            'lastUpdated': FieldValue.serverTimestamp(),
          };

          if (product.variants.isNotEmpty) {
            updates['variants'] = newVariants.map((v) => v.toMap()).toList();
          } else {
            updates['manualStock'] = restoredManualStock;
          }

          batchUpdates[productDoc.reference] = updates;
        }
      }

      // B. Compute Aggregation Reversals (if performed)
      // Logic copied from _performAggregationUpdates but handling inline writes later
      // We can use transaction.set with merge straight away in Write phase
      // Helper to calculate ranking updates
      Map<String, int> calculateRanking(
        Map<String, dynamic> currentData,
        int multiplier,
      ) {
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

      // 3. WRITE PHASE: Execute all writes

      // A. Write Product Updates
      for (final entry in batchUpdates.entries) {
        transaction.update(entry.key, entry.value);
      }

      // B. Write Aggregation Updates
      if (order.status == OrderStatus.completed &&
          dailyDoc != null &&
          monthlyDoc != null &&
          dateKey != null &&
          monthKey != null) {
        final multiplier = -1; // Reverse stats
        final orderRevenue = order.totalRevenue;
        final orderProfit = order.netProfit;
        final orderItemsCount = order.items.fold<int>(
          0,
          (p, c) => p + c.quantity,
        );

        final dailyRanking = dailyDoc.exists
            ? calculateRanking(
                dailyDoc.data() as Map<String, dynamic>,
                multiplier,
              )
            : calculateRanking({}, multiplier);
        final monthlyRanking = monthlyDoc.exists
            ? calculateRanking(
                monthlyDoc.data() as Map<String, dynamic>,
                multiplier,
              )
            : calculateRanking({}, multiplier);

        transaction.set(
          _firestore.collection('daily_summaries').doc(dateKey),
          {
            'totalRevenue': FieldValue.increment(orderRevenue * multiplier),
            'totalProfit': FieldValue.increment(orderProfit * multiplier),
            'itemsSold': FieldValue.increment(orderItemsCount * multiplier),
            'productRanking': dailyRanking,
            'date': dateKey,
          },
          SetOptions(merge: true),
        );

        transaction.set(
          _firestore.collection('monthly_summaries').doc(monthKey),
          {
            'totalRevenue': FieldValue.increment(orderRevenue * multiplier),
            'totalProfit': FieldValue.increment(orderProfit * multiplier),
            'itemsSold': FieldValue.increment(orderItemsCount * multiplier),
            'productRanking': monthlyRanking,
            'month': monthKey,
          },
          SetOptions(merge: true),
        );
      }

      // C. Update Order Status
      transaction.update(orderRef, {
        'isVoided': true,
        'status':
            'voided', // Or keep original status? User requirement says 'voided' status update.
        'updatedAt': Timestamp.now(),
      });
    });
  }

  @override
  Future<void> permanentPurgeOrder(String orderId) async {
    _ensureOwnerOrAdmin('purge orders');
    // Hard delete. Stock ALREADY handled by voidOrder.
    // Constraint: Purge should not touch stock.
    await _firestore.collection('orders').doc(orderId).delete();
  }

  @override
  Future<void> bulkArchive(List<String> ids, bool archive) async {
    _ensureOwnerOrAdmin('bulk archive');
    final batch = _firestore.batch();
    for (final id in ids) {
      final docRef = _firestore.collection('orders').doc(id);
      batch.update(docRef, {
        'isArchived': archive,
        'updatedAt': Timestamp.now(),
      });
    }
    await batch.commit();
  }

  @override
  Stream<List<OrderModel>> getOrdersStream() {
    return _firestore
        .collection('orders')
        .where('status', whereIn: ['prepping', 'delivering'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => OrderModel.fromFirestore(doc))
              .toList(),
        );
  }

  @override
  Stream<OrderModel?> getOrderStream(String orderId) {
    return _firestore.collection('orders').doc(orderId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return OrderModel.fromFirestore(doc);
    });
  }

  @override
  Future<List<OrderModel>> getOrdersHistory({
    int limit = 20,
    Object? startAfter,
    DateTimeRange? dateRange,
    String? statusFilter,
    OrderType? typeFilter,
    bool isArchived = false,
    bool filterVoided = false,
  }) async {
    Query query = _firestore.collection('orders');

    // VOIDED FILTER OVERRIDE (Global Search)
    if (filterVoided) {
      query = query.where('isVoided', isEqualTo: true);

      // Still respect Archive context if desired, or skip it?
      // User said "show me all mistakes". Usually implies ignoring "Archive" state too?
      // But typically "Archived Screen" vs "Active Screen" are separate.
      // I will respect isArchived solely to keep screens distinct.
      // If user wants ALL voided ever, they might need to go to Archive?
      // Let's assume standard behavior: context-sensitive.
      if (isArchived) {
        query = query.where('isArchived', isEqualTo: true);
      }

      // We explicitly output sort by createdAt for consistency
      query = query.orderBy('createdAt', descending: true);

      // Pagination
      if (startAfter != null && startAfter is DocumentSnapshot) {
        query = query.startAfterDocument(startAfter);
      }
      query = query.limit(limit);

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => OrderModel.fromFirestore(doc))
          .where((order) => order.isVoided) // Double check
          .toList();
    }

    // --- STANDARD FILTER LOGIC (Non-Voided) ---

    // 1. Lifecycle Filter
    // HYBRID STRATEGY:
    // - If isArchived == true: We can strictly query server-side (Archived items MUST have the flag).
    // - If isArchived == false: We skip server-side filter to include "Legacy" orders (missing flag).
    //   We will filter the results in Dart (client-side) to remove any that ARE archived.
    if (isArchived) {
      query = query.where('isArchived', isEqualTo: true);
    }

    // 2. Type/Name Filter & Indexing Rules
    // Rule: If using != (isNotEqualTo), that field MUST be the first orderBy.
    if (typeFilter != null) {
      if (typeFilter == OrderType.manualReduction) {
        query = query.where('customer.name', isEqualTo: 'Quick Sale');
        // Equality filter: can order by createdAt directly or customer.name first, but for consistent index strategy we can keep createdAt unless we need specific sort.
      } else if (typeFilter == OrderType.standard) {
        // Inequality Filter
        query = query.where('customer.name', isNotEqualTo: 'Quick Sale');
        // Critical: Must order by the inequality field FIRST
        query = query.orderBy('customer.name');
      }
    }
    // If typeFilter is null ('All'), we do NOT filter by name at all.
    // AND we do NOT order by customer.name, avoiding the index requirement for inequality.

    // 3. Date Range Filter
    if (dateRange != null) {
      // Ensure start is at beginning of day, and end is at END of day
      final start = DateTime(
        dateRange.start.year,
        dateRange.start.month,
        dateRange.start.day,
      );
      final endInput = dateRange.end;
      final end = DateTime(
        endInput.year,
        endInput.month,
        endInput.day,
        23,
        59,
        59,
      );

      query = query
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end));
    }

    // 4. Final Sort (Date)
    // If we have an inequality filter (Standard), this will be the SECOND sort key.
    // If 'All' or 'Quick Sale' (Equality), this is the FIRST sort key.
    // Firestore handles merging these orderBy calls.
    query = query.orderBy('createdAt', descending: true);

    if (statusFilter != null && statusFilter.isNotEmpty) {
      query = query.where('status', isEqualTo: statusFilter);
    }

    // Pagination
    if (startAfter != null && startAfter is DocumentSnapshot) {
      query = query.startAfterDocument(startAfter);
    }

    query = query.limit(limit);

    final snapshot = await query.get();

    // Client-Side Filter
    return snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).where((
      order,
    ) {
      // 0. ARCHIVE FILTER (Crucial for Hybrid Strategy)
      if (order.isArchived != isArchived) return false;

      // 1. If strict status filter is requested, obey it.
      if (statusFilter != null && statusFilter.isNotEmpty) {
        return order.status.name == statusFilter;
      }

      // 2. Default History View: Show Completed, Cancelled.
      // Explicitly HIDE voided orders in standard view to avoid clutter?
      // Or show them?
      // If user wants to see them, they use the filter.
      // So HIDE them here.
      if (order.isVoided) return false;

      return order.status == OrderStatus.completed ||
          order.status == OrderStatus.cancelled;
    }).toList();
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

      // 1B. READ PHASE: Aggregation Summaries (If needed)
      // Must happen before ANY writes.
      DocumentSnapshot? dailyDoc;
      DocumentSnapshot? monthlyDoc;
      String? dateKey;
      String? monthKey;

      if (order.status == OrderStatus.completed) {
        // Use Order's timestamps if completed, or NOW converted to UTC+7 specific context.
        final timestamp = order.updatedAt;
        final phnomPenhTime = timestamp.toUtc().add(const Duration(hours: 7));

        dateKey = phnomPenhTime.toIso8601String().substring(0, 10);
        monthKey = phnomPenhTime.toIso8601String().substring(0, 7);

        final dailyRef = _firestore.collection('daily_summaries').doc(dateKey);
        final monthlyRef = _firestore
            .collection('monthly_summaries')
            .doc(monthKey);

        dailyDoc = await transaction.get(dailyRef);
        monthlyDoc = await transaction.get(monthlyRef);
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

      // PREPARE ORDER WITH SNAPSHOTS
      final orderId = order.id.isEmpty
          ? _firestore.collection('orders').doc().id
          : order.id;

      final orderToSave = OrderModel(
        id: orderId,
        customer: order.customer,
        deliveryAddress: order.deliveryAddress,
        items: itemsWithSnapshots,
        logistics: order.logistics,
        totalAmount: order
            .totalAmount, // This is expected to be correct or computed before
        status: order.status,
        type: order.type,
        note: order.note,
        createdBy: order.createdBy,
        createdAt: order.createdAt,
        updatedAt: order.updatedAt,
      );

      // 2B. PREPARE AGGREGATION UPDATES (Logic Only)
      // Since we already did reads, we can compute writes now.
      if (order.status == OrderStatus.completed &&
          dailyDoc != null &&
          monthlyDoc != null) {
        final orderRevenue = orderToSave.totalRevenue;
        final orderProfit = orderToSave.netProfit;
        final orderItemsCount = orderToSave.items.fold<int>(
          0,
          (p, c) => p + c.quantity,
        );
        final multiplier = 1;

        Map<String, int> updateRanking(Map<String, dynamic> currentData) {
          final currentRanking = Map<String, int>.from(
            currentData['productRanking'] ?? {},
          );
          for (final item in orderToSave.items) {
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
        final dailyRanking = dailyDoc.exists
            ? updateRanking(dailyDoc.data()! as Map<String, dynamic>)
            : updateRanking({});

        // Monthly Data
        final monthlyRanking = monthlyDoc.exists
            ? updateRanking(monthlyDoc.data()! as Map<String, dynamic>)
            : updateRanking({});

        // 3. WRITE PHASE: Commit Everything

        // A. Update Aggregations
        transaction.set(
          _firestore.collection('daily_summaries').doc(dateKey),
          {
            'totalRevenue': FieldValue.increment(orderRevenue * multiplier),
            'totalProfit': FieldValue.increment(orderProfit * multiplier),
            'itemsSold': FieldValue.increment(orderItemsCount * multiplier),
            'productRanking': dailyRanking,
            'date': dateKey,
          },
          SetOptions(merge: true),
        );

        transaction.set(
          _firestore.collection('monthly_summaries').doc(monthKey),
          {
            'totalRevenue': FieldValue.increment(orderRevenue * multiplier),
            'totalProfit': FieldValue.increment(orderProfit * multiplier),
            'itemsSold': FieldValue.increment(orderItemsCount * multiplier),
            'productRanking': monthlyRanking,
            'month': monthKey,
          },
          SetOptions(merge: true),
        );
      }

      // B. Update Products
      for (final entry in workingProducts.entries) {
        final pid = entry.key;
        final updatedProduct = entry.value;
        final originalProduct = originalProductMap[pid]!;

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

      // C. Save Order
      transaction.set(
        _firestore.collection('orders').doc(orderId),
        orderToSave.toFirestore(),
      );
    });
  }

  @override
  Future<String> createBatchQuickSale(List<OrderItem> items) async {
    final user = _ref.read(currentUserProfileProvider).value;
    final createdBy = user?.uid ?? 'system';

    // Calculate total amount
    final totalAmount = items.fold(
      0.0,
      (sumTotal, item) => sumTotal + (item.priceAtSale * item.quantity),
    );

    final orderId = _firestore.collection('orders').doc().id; // Pre-generate ID

    final order = OrderModel(
      id: orderId,
      customer: const OrderCustomer(name: 'Quick Sale', primaryPhone: ''),
      deliveryAddress: '',
      items: items,
      totalAmount: totalAmount,
      status: OrderStatus.completed,
      type: OrderType.manualReduction,
      createdBy: createdBy,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      logistics: const OrderLogistics(deliveryType: 'Manual Reading'),
    );

    // createOrder uses runTransaction internally, ensuring atomicity
    // for all items, summaries, and stock updates.
    await createOrder(order);

    return orderId;
  }

  // Future<String> createQuickSale -> needs to match interface?
  // Interface `createQuickSale` was `Future<void>`.
  // I should probably update the interface too if I were to be strict,
  // but `createBatchQuickSale` is what I am focused on.
  // The existing `createQuickSale` calls `createBatchQuickSale`.

  @override
  Future<void> createQuickSale(Product product, int quantity) async {
    final item = OrderItem(
      productId: product.id,
      name: product.name,
      quantity: quantity,
      priceAtSale: product.finalPrice,
      variantName: 'Standard', // Used for Manual Stock
      variantId: null,
    );
    await createBatchQuickSale([item]);
  }

  @override
  Future<void> revertQuickSaleOrder(String orderId) async {
    await _firestore.runTransaction((transaction) async {
      // 1. Transaction Read Phase: Do ALL key reads first.

      // A. Read Order
      final orderRef = _firestore.collection('orders').doc(orderId);
      final doc = await transaction.get(orderRef);
      if (!doc.exists) throw Exception("Order not found or already reverted");
      final order = OrderModel.fromFirestore(doc);

      // B. Read Aggregation Summaries
      final timestamp = order.updatedAt;
      final phnomPenhTime = timestamp.toUtc().add(const Duration(hours: 7));
      final dateKey = phnomPenhTime.toIso8601String().substring(0, 10);
      final monthKey = phnomPenhTime.toIso8601String().substring(0, 7);

      final dailyRef = _firestore.collection('daily_summaries').doc(dateKey);
      final monthlyRef = _firestore
          .collection('monthly_summaries')
          .doc(monthKey);

      final dailyDoc = await transaction.get(dailyRef);
      final monthlyDoc = await transaction.get(monthlyRef);

      // C. Read Products
      final Map<String, DocumentSnapshot> productDocs = {};
      for (final item in order.items) {
        final productRef = _firestore
            .collection('products')
            .doc(item.productId);
        // Only read if we haven't read before (to avoid dup reads, though firestore handles it, good practice)
        if (!productDocs.containsKey(item.productId)) {
          productDocs[item.productId] = await transaction.get(productRef);
        }
      }

      // --- END OF READ PHASE ---

      // 2. Logic Phase: Prepare Revert Updates

      // A. Aggregation Reverse Logic (Multiplier -1)
      final multiplier = -1;
      final orderRevenue = order.totalRevenue;
      final orderProfit = order.netProfit;
      final orderItemsCount = order.items.fold<int>(
        0,
        (p, c) => p + c.quantity,
      );

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

      final dailyRanking = dailyDoc.exists
          ? updateRanking(dailyDoc.data()!)
          : updateRanking({});
      final monthlyRanking = monthlyDoc.exists
          ? updateRanking(monthlyDoc.data()!)
          : updateRanking({});

      // B. Stock Restoration Logic
      final Map<DocumentReference, Map<String, dynamic>> productUpdates = {};

      // Group items by Product ID to handle multiple items/variants for same product atomic update
      final itemsByProduct = <String, List<OrderItem>>{};
      for (final item in order.items) {
        itemsByProduct.putIfAbsent(item.productId, () => []).add(item);
      }

      for (final entry in itemsByProduct.entries) {
        final productId = entry.key;
        final items = entry.value;
        final productDoc = productDocs[productId]!;

        if (productDoc.exists) {
          final product = Product.fromFirestore(
            productDoc,
          ); // Base state from DB

          // Apply all restorations for this product
          List<ProductVariant> newVariants = List.from(product.variants);
          int restoredManualStock = product.manualStock ?? 0;
          int totalRestored = 0;

          for (final item in items) {
            totalRestored += item.quantity;
            if (item.variantId != null) {
              final index = newVariants.indexWhere(
                (v) => v.id == item.variantId,
              );
              if (index != -1) {
                final oldVariant = newVariants[index];
                newVariants[index] = ProductVariant(
                  id: oldVariant.id,
                  name: oldVariant.name,
                  stockQuantity: oldVariant.stockQuantity + item.quantity,
                );
              }
            } else {
              restoredManualStock += item.quantity;
            }
          }

          final updates = <String, dynamic>{
            'totalStock': product.totalStock + totalRestored,
          };

          if (product.variants.isNotEmpty) {
            updates['variants'] = newVariants.map((v) => v.toMap()).toList();
          } else {
            updates['manualStock'] = restoredManualStock;
          }

          productUpdates[productDoc.reference] = updates;
        }
      }

      // 3. Write Phase: Execute all writes

      // A. Write Aggregations
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

      // B. Write Product Updates
      for (final entry in productUpdates.entries) {
        transaction.update(entry.key, entry.value);
      }

      // C. Delete Order
      transaction.delete(orderRef);
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
  Future<void> bulkPurge(List<String> ids) async {
    _ensureOwnerOrAdmin('delete orders');
    if (ids.isEmpty) return;

    // Process in chunks of 10 for Firestore 'whereIn' limit (10 or 30 depending on SDK, 10 is safe)
    // Actually, 'whereIn' supports up to 30. But simpler to just loop gets or batch.
    // Given mobile selection is small, looping gets is acceptable, or fetch all.
    // Or just define a helper.

    // Efficient Approach: Chunk IDs, query orders, then execute delete.
    const int chunkSize = 10;
    for (var i = 0; i < ids.length; i += chunkSize) {
      final end = (i + chunkSize < ids.length) ? i + chunkSize : ids.length;
      final chunk = ids.sublist(i, end);

      final snapshot = await _firestore
          .collection('orders')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      for (final doc in snapshot.docs) {
        final order = OrderModel.fromFirestore(doc);
        // Execute delete safely (handles stock restore & transactions)
        await deleteOrder(order);
      }
    }
  }

  @override
  Future<void> deleteOrder(OrderModel order) async {
    _ensureOwnerOrAdmin('delete orders');

    // Unified Safety Logic:
    // If this is a Quick Sale (Manual Reduction), we MUST use the full revert logic
    // to ensure aggregations (Revenue, Profit, Daily/Monthly stats) are corrected.
    if (order.type == OrderType.manualReduction) {
      await revertQuickSaleOrder(order.id);
      return;
    }

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

  @override
  Stream<int> watchVoidedCount() {
    return _firestore
        .collection('orders')
        .where('isVoided', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  @override
  Stream<List<OrderModel>> watchCompletedOrders(DateTime start, DateTime end) {
    return _firestore
        .collection('orders')
        .where('status', isEqualTo: 'completed')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => OrderModel.fromFirestore(doc))
              .toList(),
        );
  }

  @override
  Stream<OrderModel> onReservedOrderAdded() {
    final startTime = DateTime.now();
    return _firestore
        .collection('orders')
        .where('status', isEqualTo: OrderStatus.reserved.name)
        .snapshots()
        .expand((snapshot) => snapshot.docChanges)
        .where((change) => change.type == DocumentChangeType.added)
        .map((change) => OrderModel.fromFirestore(change.doc))
        .where((order) => order.updatedAt.isAfter(startTime));
  }
}
