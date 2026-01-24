import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../domain/product.dart';
import '../domain/category.dart';
import '../domain/repositories/category_repository.dart';

part 'inventory_repository.g.dart';

@Riverpod(keepAlive: true)
InventoryRepository inventoryRepository(Ref ref) {
  return InventoryRepository(
    FirebaseFirestore.instance,
    FirebaseStorage.instance,
  );
}

@riverpod
Stream<List<Product>> productsStream(Ref ref) {
  return ref.watch(inventoryRepositoryProvider).processProductsStream();
}

class InventoryRepository implements CategoryRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  InventoryRepository(this._firestore, this._storage);

  CollectionReference get _productsRef => _firestore.collection('products');

  Stream<List<Product>> processProductsStream() {
    return _productsRef.orderBy('createdAt', descending: true).snapshots().map((
      snapshot,
    ) {
      return snapshot.docs.map((doc) => Product.fromFirestore(doc)).toList();
    });
  }

  /// **Pre-Upload Optimization Pipeline**
  /// 1. Resizes to max width 1080px.
  /// 2. Compresses to 80% quality.
  /// 3. Returns a temporary file to upload.
  Future<File?> _compressImage(File file) async {
    final dir = await getTemporaryDirectory();
    final targetPath =
        "${dir.absolute.path}/temp_${DateTime.now().millisecondsSinceEpoch}.jpg";

    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      minWidth: 1080,
      quality: 80,
    );

    return result != null ? File(result.path) : null;
  }

  Future<void> addProduct(Product product, File? imageFile) async {
    // 1. Generate ID first to use for Image Naming
    final docRef = _productsRef.doc();
    final productId = docRef.id;
    String? imageUrl;

    // 2. Image Optimization & Upload
    if (imageFile != null) {
      final compressedFile = await _compressImage(imageFile);
      if (compressedFile != null) {
        // Naming: products/{productId}.jpg
        final ref = _storage.ref().child('products/$productId.jpg');
        await ref.putFile(compressedFile);
        imageUrl = await ref.getDownloadURL();
      }
    }

    // 3. Prepare Hybrid Stock Data
    // Logic: totalStock = variants.sum ?? manualStock
    // We already have a getter in Product, but let's ensure it's saved explicitly if needed.
    // Product.toFirestore() already handles saving 'totalStock' using the getter.

    final newProduct = product.copyWith(
      id: productId, // Assign the generated ID
      imagePath: imageUrl,
      createdAt: DateTime.now(),
    );

    // 4. Save to Firestore
    await docRef.set(newProduct.toFirestore());
  }

  Future<void> updateProduct(Product product, File? newImageFile) async {
    String? imageUrl = product.imagePath;

    // 1. Handle New Image
    if (newImageFile != null) {
      final compressedFile = await _compressImage(newImageFile);
      if (compressedFile != null) {
        // Overwrite existing or create new with consistent ID name
        final ref = _storage.ref().child('products/${product.id}.jpg');
        await ref.putFile(compressedFile);
        imageUrl = await ref.getDownloadURL();
      }
    }

    // 2. Update Firestore
    // Note: product.totalStock getter will ensure the correct value is used in toFirestore()
    await _productsRef
        .doc(product.id)
        .update(product.copyWith(imagePath: imageUrl).toFirestore());
  }

  Future<void> deleteProduct(String productId) async {
    await _productsRef.doc(productId).delete();
    // Optional: Delete image from storage if it exists to clean up
    try {
      await _storage.ref().child('products/$productId.jpg').delete();
    } catch (_) {
      // Ignore if image not found
    }
  }

  // Categories
  CollectionReference get _categoriesRef => _firestore.collection('categories');

  @override
  Stream<List<Category>> watchCategories() {
    return _categoriesRef.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Category.fromFirestore(doc)).toList();
    });
  }

  @override
  Future<String> addCategory(Category category) async {
    await _categoriesRef.doc(category.id).set(category.toMap());
    return category.id;
  }

  @override
  Future<void> deleteCategory(String id) async {
    await _categoriesRef.doc(id).delete();
  }
}
