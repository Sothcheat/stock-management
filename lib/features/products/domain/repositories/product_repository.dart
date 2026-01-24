import 'dart:io';
import '../../../inventory/domain/product.dart';

abstract class ProductRepository {
  Future<List<Product>> fetchProducts();
  Future<String?> uploadProductImage(File file);
  Future<void> updateProduct(Product product);
  Future<void> deleteProduct(String productId);
}
