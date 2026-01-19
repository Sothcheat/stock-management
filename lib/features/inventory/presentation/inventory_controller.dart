import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/product.dart';
import '../data/inventory_repository.dart';

final inventoryControllerProvider =
    StreamNotifierProvider<InventoryController, List<Product>>(() {
      return InventoryController();
    });

class InventoryController extends StreamNotifier<List<Product>> {
  @override
  Stream<List<Product>> build() {
    return ref.watch(inventoryRepositoryProvider).processProductsStream();
  }

  Future<void> addProduct(Product product, File? imageFile) async {
    final repository = ref.read(inventoryRepositoryProvider);
    // State loading is handled by the stream mostly, but for actions we can rely on optimistic UI or just wait.
    // However, StreamNotifier build() provides the stream. Updates are separate.
    await repository.addProduct(product, imageFile);
  }

  Future<void> updateProduct(Product product, [File? imageFile]) async {
    final repository = ref.read(inventoryRepositoryProvider);
    await repository.updateProduct(product, imageFile);
  }

  Future<void> deleteProduct(String productId) async {
    final repository = ref.read(inventoryRepositoryProvider);
    await repository.deleteProduct(productId);
  }
}
