// lib/services/utils/cart_manager.dart
import 'package:del_pick/Services/Utils/storage_service.dart';

import '../../Models/Cart/cart.dart';
import '../../Models/Requests/order_requests.dart';
import '../../Models/Responses/order_responses.dart';

class CartManager {
  static const String _cartKey = 'shopping_cart';
  static Cart _currentCart = Cart();

  // Initialize cart manager
  static Future<void> init() async {
    await StorageService.init();
    await _loadCart();
  }

  // Load cart from storage
  static Future<void> _loadCart() async {
    final cartJson = StorageService.getObject(_cartKey);
    if (cartJson != null) {
      _currentCart = Cart.fromJson(cartJson);
    }
  }

  // Save cart to storage
  static Future<void> _saveCart() async {
    await StorageService.saveObject(_cartKey, _currentCart.toJson());
  }

  // Get current cart
  static Cart get currentCart => _currentCart;

  // Add item to cart
  static Future<bool> addItem(CartItem item) async {
    if (!_currentCart.canAddItem(item.menuItem)) {
      return false; // Cannot add item from different store
    }

    _currentCart = _currentCart.addItem(item);
    await _saveCart();
    return true;
  }

  // Remove item from cart
  static Future<void> removeItem(int menuItemId) async {
    _currentCart = _currentCart.removeItem(menuItemId);
    await _saveCart();
  }

  // Update item quantity
  static Future<void> updateItemQuantity(int menuItemId, int quantity) async {
    _currentCart = _currentCart.updateItemQuantity(menuItemId, quantity);
    await _saveCart();
  }

  // Clear cart
  static Future<void> clearCart() async {
    _currentCart = _currentCart.clear();
    await _saveCart();
  }

  // Get cart summary
  static Map<String, dynamic> getCartSummary(double? distance) {
    return {
      'itemCount': _currentCart.itemCount,
      'totalQuantity': _currentCart.totalQuantity,
      'subtotal': _currentCart.subtotal,
      'deliveryFee': _currentCart.getDeliveryFee(distance),
      'totalAmount': _currentCart.getTotalAmount(distance),
      'store': _currentCart.store?.toJson(),
    };
  }

  // Check if cart has items
  static bool get hasItems => _currentCart.isNotEmpty;

  // Get items count
  static int get itemsCount => _currentCart.itemCount;

  // Create order request from cart
  static CreateOrderRequest? createOrderRequest() {
    if (_currentCart.isEmpty || _currentCart.store == null) {
      return null;
    }

    final items = _currentCart.items.map((cartItem) =>
        OrderItemRequest(
          menuItemId: cartItem.menuItem.id,
          quantity: cartItem.quantity,
        )
    ).toList();

    return CreateOrderRequest(
      storeId: _currentCart.store!.id,
      items: items,
    );
  }
}