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
Future<List<Product>> products(Ref ref) {
  return ref.watch(productRepositoryProvider).fetchProducts();
}
