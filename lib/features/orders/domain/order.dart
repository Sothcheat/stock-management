import 'package:cloud_firestore/cloud_firestore.dart';

enum OrderStatus {
  prepping,
  delivering,
  completed;

  static OrderStatus fromString(String status) {
    return OrderStatus.values.firstWhere(
      (e) => e.name == status,
      orElse: () => OrderStatus.prepping,
    );
  }
}

class OrderCustomer {
  final String name;
  final String primaryPhone;
  final String? secondaryPhone;
  final String? telegramHandle;
  final String? note; // Added note field

  const OrderCustomer({
    required this.name,
    required this.primaryPhone,
    this.secondaryPhone,
    this.telegramHandle,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'primaryPhone': primaryPhone,
      'secondaryPhone': secondaryPhone,
      'telegramHandle': telegramHandle,
      'note': note,
    };
  }

  factory OrderCustomer.fromMap(Map<String, dynamic> map) {
    return OrderCustomer(
      name: map['name'] ?? '',
      primaryPhone: map['primaryPhone'] ?? '',
      secondaryPhone: map['secondaryPhone'],
      telegramHandle: map['telegramHandle'],
      note: map['note'],
    );
  }
}

class OrderItem {
  final String productId;
  final String? variantId;
  final String variantName;
  final double priceAtSale;
  final double costPriceAtSale; // Added for profit calculation
  final int quantity;
  final String name;

  const OrderItem({
    required this.productId,
    this.variantId,
    required this.variantName,
    required this.priceAtSale,
    this.costPriceAtSale = 0.0,
    required this.quantity,
    required this.name,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'variantId': variantId,
      'variantName': variantName,
      'priceAtSale': priceAtSale,
      'costPriceAtSale': costPriceAtSale,
      'quantity': quantity,
      'name': name,
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      productId: map['productId'] ?? '',
      variantId: map['variantId'],
      variantName: map['variantName'] ?? '',
      priceAtSale: (map['priceAtSale'] ?? 0).toDouble(),
      costPriceAtSale: (map['costPriceAtSale'] ?? 0).toDouble(),
      quantity: (map['quantity'] ?? 0).toInt(),
      name: map['name'] ?? 'Product',
    );
  }

  // Helper to create copy with cost price
  OrderItem copyWith({double? costPriceAtSale}) {
    return OrderItem(
      productId: productId,
      variantId: variantId,
      variantName: variantName,
      priceAtSale: priceAtSale,
      costPriceAtSale: costPriceAtSale ?? this.costPriceAtSale,
      quantity: quantity,
      name: name,
    );
  }
}

class OrderModel {
  final String id;
  final OrderCustomer customer;
  final String deliveryAddress;
  final List<OrderItem> items;
  final double totalAmount;
  final OrderStatus status;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const OrderModel({
    required this.id,
    required this.customer,
    required this.deliveryAddress,
    required this.items,
    required this.totalAmount,
    this.status = OrderStatus.prepping,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OrderModel(
      id: doc.id,
      customer: OrderCustomer.fromMap(data['customer'] ?? {}),
      deliveryAddress: data['deliveryAddress'] ?? '',
      items: (data['items'] as List<dynamic>? ?? [])
          .map((i) => OrderItem.fromMap(i))
          .toList(),
      totalAmount: (data['totalAmount'] ?? 0).toDouble(),
      status: OrderStatus.fromString(data['status'] ?? 'prepping'),
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'customer': customer.toMap(),
      'deliveryAddress': deliveryAddress,
      'items': items.map((i) => i.toMap()).toList(),
      'totalAmount': totalAmount,
      'status': status.name,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  OrderModel copyWith({OrderStatus? status, DateTime? updatedAt}) {
    return OrderModel(
      id: id,
      customer: customer,
      deliveryAddress: deliveryAddress,
      items: items,
      totalAmount: totalAmount,
      status: status ?? this.status,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
