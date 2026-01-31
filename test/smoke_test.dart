// ignore_for_file: avoid_print

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_management_app/features/inventory/data/inventory_repository.dart';
import 'package:stock_management_app/features/orders/data/firebase_orders_repository.dart';
import 'package:stock_management_app/features/orders/domain/order.dart';

import 'package:firebase_storage/firebase_storage.dart';

// Mock Ref
class MockRef extends Ref {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeFirebaseStorage extends Fake implements FirebaseStorage {}

void main() {
  group('FirebaseOrdersRepository Smoke Test', () {
    late FakeFirebaseFirestore firestore;
    late FirebaseOrdersRepository ordersRepo;
    late InventoryRepository inventoryRepo;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      // auth was unused

      // Create mock Ref if needed, or null if we don't assume role checks for this test or mock them
      // For simplicity, we assume we can pass a dummy ref that returns a user with permission if needed.
      // But verify logic uses _ref.read(currentUserProfileProvider).
      // We'll bypass role check by pretending to be owner or just testing the transaction method directly if possible.
      // Actually, createOrder doesn't check role? deleteOrder does. createOrder just needs valid product.

      // We need to construct repos manually since we're not using full Riverpod container here for simplicity
      // unless we want to. Manual injection is faster for unit test.
      inventoryRepo = InventoryRepository(firestore, FakeFirebaseStorage());
      ordersRepo = FirebaseOrdersRepository(
        firestore,
        MockRef(),
        inventoryRepo,
      );
    });

    test(
      'Transaction correctly reduces stock and updates lastSoldAt',
      () async {
        print('--- Starting Smoke Test ---');

        // 1. Setup Product
        // productData was unused

        // Manually add to firestore
        final productRef = await firestore.collection('products').add({
          'name': 'Test Product',
          'price': 100,
          'costPrice': 50,
          'manualStock': 10,
          'variants': [],
          'createdAt': Timestamp.fromDate(DateTime.now()), // Fix: Use Timestamp
        });
        final productId = productRef.id;
        print('1. Created Product ($productId) with Stock: 10');

        // 2. Create Order
        final orderItem = OrderItem(
          productId: productId,
          name: 'Test Product',
          quantity: 2,
          priceAtSale: 100,
          costPriceAtSale:
              50, // Snapshot logic should fill this if missing, but passed here
          variantName: '',
        );

        final order = OrderModel(
          id: 'order_1',
          customer: const OrderCustomer(name: 'Tester', primaryPhone: '123'),
          items: [orderItem],
          totalAmount: 200,
          status: OrderStatus.completed,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          deliveryAddress: 'Test Address',
          createdBy: 'user_1',
        );

        print('2. Creating Order for 2 items...');
        await ordersRepo.createOrder(order);
        print('   Order Created Successfully.');

        // 3. Verify Product Stock
        final updatedProductSnap = await firestore
            .collection('products')
            .doc(productId)
            .get();
        final updatedData = updatedProductSnap.data()!;

        final newStock = updatedData['manualStock'];
        final newTotal = updatedData['totalStock'];
        final lastSoldAt = updatedData['lastSoldAt'];

        print('3. Verifying Stock Reduction:');
        print('   Original Stock: 10');
        print('   Expected Stock: 8');
        print('   Actual ManualStock: $newStock');
        print('   Actual TotalStock: $newTotal');
        print('   LastSoldAt: $lastSoldAt');

        expect(newStock, 8);
        expect(newTotal, 8);
        expect(lastSoldAt, isNotNull);

        print('--- Smoke Test PASSED ---');
      },
    );
  });
}
