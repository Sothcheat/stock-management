class ProductVariant {
  final String id;
  final String name; // e.g., "White", "XL"
  final int stock;
  final int soldCount; // Track how many sold for "Most Sold" feature

  const ProductVariant({
    required this.id,
    required this.name,
    required this.stock,
    this.soldCount = 0,
  });

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'stock': stock, 'soldCount': soldCount};
  }

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    return ProductVariant(
      id: json['id'] as String,
      name: json['name'] as String,
      stock: (json['stock'] as num).toInt(),
      soldCount: (json['soldCount'] as num?)?.toInt() ?? 0,
    );
  }

  ProductVariant copyWith({
    String? id,
    String? name,
    int? stock,
    int? soldCount,
  }) {
    return ProductVariant(
      id: id ?? this.id,
      name: name ?? this.name,
      stock: stock ?? this.stock,
      soldCount: soldCount ?? this.soldCount,
    );
  }
}
