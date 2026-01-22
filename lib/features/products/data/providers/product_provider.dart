import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../inventory/domain/product.dart';
import '../../domain/repositories/product_repository.dart';
import '../repositories/fake_product_repository.dart';

part 'product_provider.g.dart';

@Riverpod(keepAlive: true)
ProductRepository productRepository(Ref ref) {
  return FakeProductRepository();
}

@riverpod
class Products extends _$Products {
  @override
  Future<List<Product>> build() {
    return ref.watch(productRepositoryProvider).fetchProducts();
  }

  Future<void> updateProduct(Product updatedProduct) async {
    final previousState = state;
    // Optimistic update
    if (previousState.hasValue) {
      state = AsyncData(
        previousState.value!
            .map((p) => p.id == updatedProduct.id ? updatedProduct : p)
            .toList(),
      );
    }

    try {
      await ref.read(productRepositoryProvider).updateProduct(updatedProduct);
    } catch (e) {
      // Revert on failure
      state = previousState;
      rethrow;
    }
  }
}
