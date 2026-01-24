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
  final String? note;

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

class OrderLogistics {
  final double deliveryFeeCharged; // Revenue
  final double? actualDeliveryCost; // Expense
  final String deliveryType; // e.g., 'Grab', 'Manual', 'Free'

  const OrderLogistics({
    this.deliveryFeeCharged = 0.0,
    this.actualDeliveryCost,
    this.deliveryType = 'Standard',
  });

  Map<String, dynamic> toMap() {
    return {
      'deliveryFeeCharged': deliveryFeeCharged,
      'actualDeliveryCost': actualDeliveryCost,
      'deliveryType': deliveryType,
    };
  }

  factory OrderLogistics.fromMap(Map<String, dynamic> map) {
    return OrderLogistics(
      deliveryFeeCharged: (map['deliveryFeeCharged'] ?? 0).toDouble(),
      actualDeliveryCost: map['actualDeliveryCost']?.toDouble(),
      deliveryType: map['deliveryType'] ?? 'Standard',
    );
  }
}

class OrderItem {
  final String productId;
  final String? variantId;
  final String variantName;
  final String name;
  final int quantity;

  // Financial Snapshots
  final double priceAtSale;
  final double discountAtSale;
  final double costPriceAtSale;
  final double shipmentCostAtSale;

  const OrderItem({
    required this.productId,
    this.variantId,
    required this.variantName,
    required this.name,
    required this.quantity,
    required this.priceAtSale,
    this.discountAtSale = 0.0,
    this.costPriceAtSale = 0.0,
    this.shipmentCostAtSale = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'variantId': variantId,
      'variantName': variantName,
      'name': name,
      'quantity': quantity,
      'priceAtSale': priceAtSale,
      'discountAtSale': discountAtSale,
      'costPriceAtSale': costPriceAtSale,
      'shipmentCostAtSale': shipmentCostAtSale,
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      productId: map['productId'] ?? '',
      variantId: map['variantId'],
      variantName: map['variantName'] ?? '',
      name: map['name'] ?? 'Product',
      quantity: (map['quantity'] ?? 0).toInt(),
      priceAtSale: (map['priceAtSale'] ?? 0).toDouble(),
      discountAtSale: (map['discountAtSale'] ?? 0).toDouble(),
      costPriceAtSale: (map['costPriceAtSale'] ?? 0).toDouble(),
      shipmentCostAtSale: (map['shipmentCostAtSale'] ?? 0).toDouble(),
    );
  }

  // Helper getters
  double get totalRevenue =>
      priceAtSale * quantity; // priceAtSale implies final price after discount?
  // User said "priceAtSale, discountAtSale".
  // Usually priceAtSale is the LIST price or the FINAL price?
  // Let's assume priceAtSale is the Unit Price (Pre-discount) or Post-discount?
  // "priceAtSale, discountAtSale". If both exist, likely Price is Base, Discount is subtraction.
  // Formula: (priceAtSale - discountAtSale) * quantity?
  // Or is priceAtSale the final price?
  // User Prompt: "copy... priceAtSale, discountAtSale".
  // Let's assume net unit price = priceAtSale. (If discount is stored just for record).
  // BUT logic says: `totalRevenue: (sum of item prices * qty) + deliveryFee`.
  // `totalExpense: (sum of (costPrice + shipmentCost) * qty) ... + discounts`.
  // Wait, "totalExpense... + discounts"?
  // If discount is considered an expense (Contra-revenue), then Revenue = List Price * Qty.
  // Net Profit = Revenue - Expense (which includes discount).
  // Correct.

  double get totalCost => (costPriceAtSale + shipmentCostAtSale) * quantity;
}

class OrderModel {
  final String id;
  final OrderCustomer customer;
  final String deliveryAddress;
  final List<OrderItem> items;
  final OrderLogistics logistics;
  final OrderStatus status;
  final String? note;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const OrderModel({
    required this.id,
    required this.customer,
    required this.deliveryAddress,
    required this.items,
    this.logistics = const OrderLogistics(),
    required this.totalAmount,
    this.status = OrderStatus.prepping,
    this.note,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  // --- Financial Getters ---

  double get totalRevenue {
    // Sum of item prices * qty + delivery fee
    final itemsRevenue = items.fold(
      0.0,
      (total, item) => total + (item.priceAtSale * item.quantity),
    );
    return itemsRevenue + logistics.deliveryFeeCharged;
  }

  double get totalExpense {
    // Sum of (cost + shipment) * qty + actualDeliveryCost + discounts
    final itemsCost = items.fold(0.0, (total, item) {
      final itemCost =
          (item.costPriceAtSale + item.shipmentCostAtSale) * item.quantity;
      final itemDiscount = item.discountAtSale * item.quantity;
      return total + itemCost + itemDiscount;
    });
    return itemsCost + (logistics.actualDeliveryCost ?? 0.0);
  }

  double get netProfit => totalRevenue - totalExpense;

  // Wait, if totalRevenue uses priceAtSale (List Price), then the actual "Amount To Pay" by customer is Revenue - Discounts.
  // Typically `totalAmount` in OrderModel represents what the customer pays.
  // If `priceAtSale` is the List Price, then `totalAmount` = (price - discount) * qty + delivery.

  // Let's verify `totalAmount` definition in original file.
  // original `totalAmount` field existed as a plain double.
  // I should probably keep `totalAmount` as a field or computed getter that represents the Final Value.
  // The user asked for `totalRevenue`, `totalExpense`, `netProfit`.
  // I will make `totalAmount` a computed getter or simple field for backward compatibility?
  // The original had `final double totalAmount;`.
  // I will keep it as a field for Firestore persistence if needed, but setters/getters are better for consistency.
  // However, `fromFirestore` reads keys.
  // I will calculate it in `toFirestore` or let it be stored.
  // Storing it is safer for history if get logic changes.
  // But for this refactor, I'll calculate it in the constructor or factory?
  // Let's keep it as a stored field to avoid breaking changes if logic drifts, BUT update it in copyWith/constructor.
  // Actually, I'll keep `totalAmount` as a stored field to match existing Firestore data structure, but commonly it should match the math.

  // Revised approach: I will keep `totalAmount` as a parameter to ensure we don't lose data, but the getters above are dynamic.

  final double totalAmount; // Stored total (Customer Paid)

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OrderModel(
      id: doc.id,
      customer: OrderCustomer.fromMap(data['customer'] ?? {}),
      deliveryAddress: data['deliveryAddress'] ?? '',
      items: (data['items'] as List<dynamic>? ?? [])
          .map((i) => OrderItem.fromMap(i))
          .toList(),
      logistics: OrderLogistics.fromMap(data['logistics'] ?? {}),
      totalAmount: (data['totalAmount'] ?? 0).toDouble(),
      status: OrderStatus.fromString(data['status'] ?? 'prepping'),
      note: data['note'],
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'customer': customer.toMap(),
      'deliveryAddress': deliveryAddress,
      'items': items.map((i) => i.toMap()).toList(),
      'logistics': logistics.toMap(),
      'totalAmount': totalAmount,
      'status': status.name,
      'note': note,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  OrderModel copyWith({
    String? id,
    OrderCustomer? customer,
    String? deliveryAddress,
    List<OrderItem>? items,
    OrderLogistics? logistics,
    double? totalAmount,
    OrderStatus? status,
    String? note,
    DateTime? updatedAt,
  }) {
    return OrderModel(
      id: id ?? this.id,
      customer: customer ?? this.customer,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      items: items ?? this.items,
      logistics: logistics ?? this.logistics,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      note: note ?? this.note,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
