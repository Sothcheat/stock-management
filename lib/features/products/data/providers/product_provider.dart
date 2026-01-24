import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../inventory/data/inventory_repository.dart';
import '../../../inventory/domain/product.dart';

part 'product_provider.g.dart';

@riverpod
class Products extends _$Products {
  @override
  Stream<List<Product>> build() {
    return ref.watch(inventoryRepositoryProvider).processProductsStream();
  }

  Future<void> updateProduct(Product product) async {
    // Determine image file if necessary, but for stock updates (main use case here),
    // we assume no image change unless handled separately.
    await ref.read(inventoryRepositoryProvider).updateProduct(product, null);
  }
}
