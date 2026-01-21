import 'package:cloud_firestore/cloud_firestore.dart';

class ProductVariant {
  final String id;
  final String name;
  final int stockQuantity;

  const ProductVariant({
    required this.id,
    required this.name,
    required this.stockQuantity,
  });

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'stockQuantity': stockQuantity};
  }

  factory ProductVariant.fromMap(Map<String, dynamic> map) {
    return ProductVariant(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      stockQuantity: map['stockQuantity']?.toInt() ?? 0,
    );
  }
}

class Product {
  final String id;
  final String name;
  final String description;
  final String categoryId;
  final double price;
  final double costPrice;
  final double? shipmentCost;
  final double? discountValue;
  final DiscountType discountType;
  final List<ProductVariant> variants;
  final int totalStock;
  final int lowStockThreshold;
  final String? imagePath;
  final DateTime createdAt;

  // Calculated Price
  double get finalPrice {
    if (discountValue == null || discountValue == 0) return price;
    if (discountType == DiscountType.fixed) {
      return (price - discountValue!).clamp(0, double.infinity);
    } else {
      return (price * (1 - discountValue! / 100)).clamp(0, double.infinity);
    }
  }

  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.categoryId,
    required this.price,
    required this.costPrice,
    this.shipmentCost,
    this.discountValue,
    this.discountType = DiscountType.fixed,
    required this.variants,
    required this.totalStock,
    this.lowStockThreshold = 10,
    this.imagePath,
    required this.createdAt,
  });

  // Create 'empty' for logic
  factory Product.empty() => Product(
    id: '',
    name: '',
    description: '',
    categoryId: '',
    price: 0,
    costPrice: 0,
    variants: [],
    totalStock: 0,
    createdAt: DateTime.now(),
  );

  factory Product.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Product(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      categoryId: data['categoryId'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      costPrice: (data['costPrice'] ?? 0).toDouble(),
      shipmentCost: (data['shipmentCost'] ?? 0).toDouble(),
      discountValue: (data['discountValue'] ?? 0).toDouble(),
      discountType: DiscountType.values.firstWhere(
        (e) => e.name == (data['discountType'] ?? 'fixed'),
        orElse: () => DiscountType.fixed,
      ),
      variants: (data['variants'] as List<dynamic>? ?? [])
          .map((v) => ProductVariant.fromMap(v))
          .toList(),
      totalStock: (data['totalStock'] ?? 0).toInt(),
      lowStockThreshold: (data['lowStockThreshold'] ?? 10).toInt(),
      imagePath: data['imagePath'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'categoryId': categoryId,
      'price': price,
      'costPrice': costPrice,
      'shipmentCost': shipmentCost,
      'discountValue': discountValue,
      'discountType': discountType.name,
      'variants': variants.map((v) => v.toMap()).toList(),
      'totalStock': totalStock,
      'lowStockThreshold': lowStockThreshold,
      'imagePath': imagePath,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Product copyWith({
    String? id,
    String? name,
    String? description,
    String? categoryId,
    double? price,
    double? costPrice,
    double? shipmentCost,
    double? discountValue,
    DiscountType? discountType,
    List<ProductVariant>? variants,
    int? totalStock,
    int? lowStockThreshold,
    String? imagePath,
    DateTime? createdAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      price: price ?? this.price,
      costPrice: costPrice ?? this.costPrice,
      shipmentCost: shipmentCost ?? this.shipmentCost,
      discountValue: discountValue ?? this.discountValue,
      discountType: discountType ?? this.discountType,
      variants: variants ?? this.variants,
      totalStock: totalStock ?? this.totalStock,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      imagePath: imagePath ?? this.imagePath,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

enum DiscountType { percentage, fixed }
