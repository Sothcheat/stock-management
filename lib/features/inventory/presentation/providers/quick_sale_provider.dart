import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../inventory/domain/product.dart';

part 'quick_sale_provider.g.dart';

@riverpod
class QuickSaleCart extends _$QuickSaleCart {
  @override
  Map<String, int> build() {
    return {};
  }

  void toggleItem(Product product) {
    if (state.containsKey(product.id)) {
      final newState = Map<String, int>.from(state);
      newState.remove(product.id);
      state = newState;
    } else {
      state = {...state, product.id: 1};
    }
  }

  void addToCart(Product product) {
    // Keep for backward compatibility or direct add if needed,
    // but User asked for Toggle on Tap.
    // I'll keep this but redirect to toggle logic if simple tap, or explicit add.
    // Actually, let's make it explicitly 'add or increment' vs 'toggle'.
    // User requirement: "If product is NOT in cart, add it. If IS in cart, remove it."
    // This is STRICT toggle.
    toggleItem(product);
  }

  void updateQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      final newState = Map<String, int>.from(state);
      newState.remove(productId);
      state = newState;
    } else {
      state = {...state, productId: quantity};
    }
  }

  void removeFromCart(Product product) {
    // Explicit remove
    final newState = Map<String, int>.from(state);
    newState.remove(product.id);
    state = newState;
  }

  void clearCart() {
    state = {};
  }

  bool get hasItems => state.isNotEmpty;

  int get conversionCount => state.length; // Unique items or total quantity?
  // User asked: "Process 3 Items". Usually means total count or line items?
  // "total number of items selected (e.g., Process 3 Items)"
  // Let's assume Unique Items (Product count) for now, or Total Quantity?
  // If I select 5 Cokes, is it "Process 5" or "Process 1 (type)"?
  // Typically for quick sale, total Quantity is more relevant if it's "Quick Sale 5 Cokes".
  // But if I have 2 Cokes + 1 Water, "Process 3 Items" sounds right.
  // Let's use total quantity sum.

  int get totalQuantity => state.values.fold(0, (sum, qty) => sum + qty);
}
