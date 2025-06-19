// lib/models/cart/cart.dart
import '../Entities/menu_item.dart';
import '../Entities/store.dart';
import '../Responses/order_responses.dart';
import '../Utils/model_utils.dart';

class Cart {
  final List<CartItem> items;
  final Store? store;

  Cart({
    this.items = const [],
    this.store,
  });

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;
  int get itemCount => items.length;
  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);

  double get subtotal => items.fold(0.0, (sum, item) => sum + item.totalPrice);

  double getDeliveryFee(double? distance) {
    // Calculate delivery fee based on distance
    // This is a sample calculation, adjust according to your business logic
    if (distance == null || distance <= 0) return 5000; // Base fee

    const double baseFee = 5000;
    const double perKmFee = 1000;

    return baseFee + (distance * perKmFee);
  }

  double getTotalAmount(double? distance) {
    return subtotal + getDeliveryFee(distance);
  }

  Cart addItem(CartItem item) {
    final existingIndex = items.indexWhere(
          (cartItem) => cartItem.menuItem.id == item.menuItem.id,
    );

    List<CartItem> newItems;
    if (existingIndex >= 0) {
      newItems = List.from(items);
      newItems[existingIndex] = items[existingIndex].copyWith(
        quantity: items[existingIndex].quantity + item.quantity,
      );
    } else {
      newItems = [...items, item];
    }

    return Cart(items: newItems, store: store ?? item.menuItem.store);
  }

  Cart removeItem(int menuItemId) {
    final newItems = items.where(
          (item) => item.menuItem.id != menuItemId,
    ).toList();

    return Cart(
      items: newItems,
      store: newItems.isEmpty ? null : store,
    );
  }

  Cart updateItemQuantity(int menuItemId, int quantity) {
    if (quantity <= 0) {
      return removeItem(menuItemId);
    }

    final newItems = items.map((item) {
      if (item.menuItem.id == menuItemId) {
        return item.copyWith(quantity: quantity);
      }
      return item;
    }).toList();

    return Cart(items: newItems, store: store);
  }

  Cart clear() {
    return Cart(items: const [], store: null);
  }

  bool canAddItem(MenuItem menuItem) {
    // Check if item can be added (same store policy)
    if (store == null) return true;
    return store!.id == menuItem.storeId;
  }

  Map<String, dynamic> toJson() {
    return {
      'items': items.map((item) => item.toJson()).toList(),
      'store': store?.toJson(),
    };
  }

  factory Cart.fromJson(Map<String, dynamic> json) {
    return Cart(
      items: ModelUtils.parseList(
        json['items'],
            (itemJson) => CartItem.fromJson(itemJson),
      ),
      store: json['store'] != null
          ? Store.fromJson(json['store'] as Map<String, dynamic>)
          : null,
    );
  }
}