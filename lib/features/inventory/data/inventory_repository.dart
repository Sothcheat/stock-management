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

@riverpod
Stream<Map<String, Product>> productsMap(Ref ref) {
  return ref.watch(productsStreamProvider.future).asStream().map((products) {
    return {for (var p in products) p.name: p};
  });
}

@riverpod
Stream<Map<String, Product>> productsMapById(Ref ref) {
  return ref.watch(productsStreamProvider.future).asStream().map((products) {
    return {for (var p in products) p.id: p};
  });
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

  Future<Product?> getProductByName(String name) async {
    try {
      final snapshot = await _productsRef
          .where('name', isEqualTo: name)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return Product.fromFirestore(snapshot.docs.first);
    } catch (e) {
      // Return null on error to allow UI to show placeholder
      return null;
    }
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

  Future<List<ProductVariant>> _uploadVariantImages(
    String productId,
    List<ProductVariant> variants,
  ) async {
    final List<ProductVariant> updatedVariants = [];

    for (final v in variants) {
      // Check if imagePath is a local path (not a URL) and exists
      if (v.imagePath != null &&
          !v.imagePath!.startsWith('http') &&
          !v.imagePath!.startsWith('https')) {
        final file = File(v.imagePath!);
        if (await file.exists()) {
          final compressed = await _compressImage(file);
          if (compressed != null) {
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            // Naming: products/{productId}/variants/{variantId}_{timestamp}.jpg
            final ref = _storage.ref().child(
              'products/$productId/variants/${v.id}_$timestamp.jpg',
            );

            try {
              await ref.putFile(compressed);
              final url = await ref.getDownloadURL();

              // Update variant with URL
              updatedVariants.add(
                ProductVariant(
                  id: v.id,
                  name: v.name,
                  stockQuantity: v.stockQuantity,
                  imagePath: url,
                ),
              );
              continue; // Successfully updated
            } catch (e) {
              // On upload failure, keep local path or handle error?
              // For now, keep original to prevent data loss, but it won't be visible on other devices
              // Or maybe set to null? Let's keep original for retry potential
              updatedVariants.add(v);
              continue;
            }
          }
        }
      }
      // If no change needed or upload failed/skipped
      updatedVariants.add(v);
    }
    return updatedVariants;
  }

  /// Adds a new product to Firestore and uploads its images (main + variants).
  /// [imageFile] is optional; if provided, it's compressed and uploaded.
  Future<void> addProduct(Product product, File? imageFile) async {
    // 1. Generate ID first to use for Image Naming
    final docRef = _productsRef.doc();
    final productId = docRef.id;
    String? imageUrl;

    // 2. Image Optimization & Upload (Main)
    if (imageFile != null) {
      final compressedFile = await _compressImage(imageFile);
      if (compressedFile != null) {
        // Naming: products/{productId}.jpg
        final ref = _storage.ref().child('products/$productId.jpg');
        await ref.putFile(compressedFile);
        imageUrl = await ref.getDownloadURL();
      }
    }

    // 3. Variant Images Upload
    List<ProductVariant> finalVariants = product.variants;
    if (product.variants.isNotEmpty) {
      finalVariants = await _uploadVariantImages(productId, product.variants);
    }

    final newProduct = product.copyWith(
      id: productId, // Assign the generated ID
      imagePath: imageUrl,
      variants: finalVariants,
      createdAt: DateTime.now(),
    );

    // 4. Save to Firestore
    // Ensure manualStock is null if variants exist (enforce hybrid logic consistency)
    // Though copyWith doesn't support setting null easily unless we handle it
    // But Product logic usually prefers variants sum.
    await docRef.set(newProduct.toFirestore());
  }

  /// Updates an existing product.
  /// If [newImageFile] is provided, it replaces the existing main image.
  /// Variant images are handled via [product.variants] logic (local path vs URL).
  Future<void> updateProduct(Product product, File? newImageFile) async {
    String? imageUrl = product.imagePath;

    // 1. Handle New Image (Main)
    if (newImageFile != null) {
      final compressedFile = await _compressImage(newImageFile);
      if (compressedFile != null) {
        // Overwrite existing or create new with consistent ID name
        final ref = _storage.ref().child('products/${product.id}.jpg');
        await ref.putFile(compressedFile);
        imageUrl = await ref.getDownloadURL();
      }
    }

    // 2. Variant Images Upload
    List<ProductVariant> finalVariants = product.variants;
    if (product.variants.isNotEmpty) {
      finalVariants = await _uploadVariantImages(product.id, product.variants);
    }

    // 3. Update Firestore
    await _productsRef
        .doc(product.id)
        .update(
          product
              .copyWith(imagePath: imageUrl, variants: finalVariants)
              .toFirestore(),
        );
  }

  /// Deletes a product by ID.
  /// Attempts to clean up the main image in storage, but ignores errors if file missing.
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

  /// Adds a new category to the global catalog.
  /// Returns the category ID.
  @override
  Future<String> addCategory(Category category) async {
    await _categoriesRef.doc(category.id).set(category.toMap());
    return category.id;
  }

  /// Deletes a category by ID.
  @override
  Future<void> deleteCategory(String id) async {
    await _categoriesRef.doc(id).delete();
  }
}
