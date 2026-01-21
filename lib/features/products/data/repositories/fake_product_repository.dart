import 'dart:io';
import 'dart:math';
import '../../../inventory/domain/product.dart';
import '../../domain/repositories/product_repository.dart';

class FakeProductRepository implements ProductRepository {
  @override
  Future<List<Product>> fetchProducts() async {
    // Simulate network lag
    await Future.delayed(const Duration(seconds: 1));

    return List.generate(100, (index) {
      final id = 'product_$index';
      final price = (Random().nextDouble() * 100) + 10; // 10.0 to 110.0
      final costPrice = price * 0.7;
      final stock = Random().nextInt(50);

      // Use picsum for random images, using ID as seed for consistency
      // Use specific placeholder service for reliability
      // ID used to seed color or style if supported, but simple placeholder is safer for now.
      final imageUrl =
          'https://placehold.co/300x300/2A2D3E/FFFFFF/png?text=Product+$index';

      return Product(
        id: id,
        name: 'Product $index',
        description:
            'Description for Product $index. This is a mock product generated for testing.',
        categoryId: 'cat_${index % 5}', // 5 fake categories
        price: double.parse(price.toStringAsFixed(2)),
        costPrice: double.parse(costPrice.toStringAsFixed(2)),
        variants: [], // Empty for basic mock
        totalStock: stock,
        createdAt: DateTime.now().subtract(Duration(days: index)),
        imagePath: imageUrl,
      );
    });
  }

  @override
  Future<String?> uploadProductImage(File file) async {
    await Future.delayed(const Duration(seconds: 1));
    // Verify file exists
    if (await file.exists()) {
      return 'https://picsum.photos/seed/${file.path.hashCode}/300/300'; // Mock URL
    }
    return null;
  }
}
