// lib/Features/Pages/Customers/navigation/cart_navigation.dart
import 'package:flutter/material.dart';
import 'package:del_pick/Models/Entities/store.dart';
import 'package:del_pick/Models/Entities/order.dart';
import 'package:del_pick/Models/Responses/order_responses.dart';
import 'package:del_pick/Services/Utils/cart_manager.dart';

import '../../../Models/Entities/menu_item.dart';
import '../Customers/cart_screen.dart';
import '../Customers/location_access.dart';
import '../Customers/track_cust_order.dart';

class CartNavigation {
  // Navigate to cart from store detail
  static Future<void> navigateToCartFromStore(
      BuildContext context,
      Store store,
      ) async {
    // Get current cart items
    final cartItems = await _getCurrentCartItems();

    if (cartItems.isEmpty) {
      _showEmptyCartMessage(context);
      return;
    }

    // Validate that all items are from the same store
    final isValidCart = _validateCartStore(cartItems, store);
    if (!isValidCart) {
      _showDifferentStoreDialog(context, store, cartItems);
      return;
    }

    // Navigate to cart
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CartScreen(
          store: store,
          cartItems: cartItems,
        ),
      ),
    );
  }

  // Navigate to cart with specific order (for history)
  static Future<void> navigateToOrderHistory(
      BuildContext context,
      Order completedOrder,
      ) async {
    if (completedOrder.store == null) {
      _showErrorMessage(context, 'Data toko tidak tersedia');
      return;
    }

    // Convert order items back to cart items for display
    final cartItems = _convertOrderToCartItems(completedOrder);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CartScreen(
          store: completedOrder.store!,
          cartItems: cartItems,
          completedOrder: completedOrder,
        ),
      ),
    );
  }

  // Navigate to order tracking
  static Future<void> navigateToOrderTracking(
      BuildContext context,
      Order activeOrder,
      ) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TrackCustOrderScreen(
          order: activeOrder,
        ),
      ),
    );
  }

  // Navigate to location access
  static Future<Map<String, dynamic>?> navigateToLocationAccess(
      BuildContext context,
      ) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => const LocationAccessScreen(),
      ),
    );

    return result;
  }

  // Quick add to cart from menu item
  static Future<bool> quickAddToCart(
      BuildContext context,
      CartItem cartItem,
      Store store,
      ) async {
    try {
      // Check if cart is empty or from same store
      final currentCart = CartManager.currentCart;

      if (currentCart.store != null && currentCart.store!.id != store.id) {
        // Show replace cart dialog
        final shouldReplace = await _showReplaceCartDialog(context, currentCart.store!.name, store.name);
        if (!shouldReplace) return false;

        // Clear cart if user wants to replace
        await CartManager.clearCart();
      }

      // Add item to cart
      final success = await CartManager.addItem(cartItem);

      if (success) {
        _showAddToCartSuccess(context, cartItem);
        return true;
      } else {
        _showErrorMessage(context, 'Gagal menambahkan item ke keranjang');
        return false;
      }
    } catch (e) {
      _showErrorMessage(context, 'Terjadi kesalahan: $e');
      return false;
    }
  }

  // Helper methods
  static Future<List<CartItem>> _getCurrentCartItems() async {
    final cart = CartManager.currentCart;
    return cart.items;
  }

  static bool _validateCartStore(List<CartItem> cartItems, Store store) {
    for (var item in cartItems) {
      if (item.menuItem.storeId != store.id) {
        return false;
      }
    }
    return true;
  }

  static List<CartItem> _convertOrderToCartItems(Order order) {
    if (order.items == null) return [];

    return order.items!.map((orderItem) {
      // Create a simplified MenuItem for display
      final menuItem = MenuItem(
        id: orderItem.menuItemId,
        name: orderItem.name,
        price: orderItem.price,
        description: orderItem.description,
        imageUrl: orderItem.imageUrl,
        storeId: order.storeId,
        category: orderItem.category,
        isAvailable: true,
        createdAt: order.createdAt,
        updatedAt: order.updatedAt,
      );

      return CartItem(
        menuItem: menuItem,
        quantity: orderItem.quantity,
        notes: orderItem.notes,
      );
    }).toList();
  }

  // Dialog methods
  static Future<bool> _showReplaceCartDialog(
      BuildContext context,
      String currentStoreName,
      String newStoreName,
      ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Ganti Keranjang?'),
          content: Text(
              'Keranjang Anda berisi item dari $currentStoreName. '
                  'Menambahkan item dari $newStoreName akan menghapus item sebelumnya. '
                  'Lanjutkan?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Ganti'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  static void _showDifferentStoreDialog(
      BuildContext context,
      Store newStore,
      List<CartItem> currentItems,
      ) {
    final currentStoreName = currentItems.first.menuItem.store?.name ?? 'Toko lain';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Keranjang dari Toko Berbeda'),
          content: Text(
              'Keranjang Anda berisi item dari $currentStoreName. '
                  'Untuk memesan dari ${newStore.name}, silakan kosongkan keranjang terlebih dahulu.'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  static void _showEmptyCartMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Keranjang kosong. Tambahkan item terlebih dahulu.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static void _showAddToCartSuccess(BuildContext context, CartItem item) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.menuItem.name} ditambahkan ke keranjang'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Lihat Keranjang',
          onPressed: () {
            // Navigate to cart if store info is available
            if (item.menuItem.store != null) {
              navigateToCartFromStore(context, item.menuItem.store!);
            }
          },
        ),
      ),
    );
  }

  static void _showErrorMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// Route generation helper
class CartRoutes {
  static const String cart = '/cart';
  static const String orderHistory = '/order-history';
  static const String orderTracking = '/order-tracking';
  static const String locationAccess = '/location-access';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case cart:
        final args = settings.arguments as Map<String, dynamic>?;
        if (args == null) {
          return _errorRoute('Missing cart arguments');
        }

        return MaterialPageRoute(
          builder: (context) => CartScreen(
            store: args['store'] as Store,
            cartItems: args['cartItems'] as List<CartItem>,
            completedOrder: args['completedOrder'] as Order?,
          ),
        );

      case orderTracking:
        final order = settings.arguments as Order?;
        if (order == null) {
          return _errorRoute('Missing order for tracking');
        }

        return MaterialPageRoute(
          builder: (context) => TrackCustOrderScreen(order: order),
        );

      case locationAccess:
        return MaterialPageRoute(
          builder: (context) => const LocationAccessScreen(),
        );

      default:
        return _errorRoute('Route not found: ${settings.name}');
    }
  }

  static Route<dynamic> _errorRoute(String message) {
    return MaterialPageRoute(
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Text(message),
        ),
      ),
    );
  }
}

// Cart state provider for global cart management
class CartStateProvider extends ChangeNotifier {
  static final CartStateProvider _instance = CartStateProvider._internal();
  factory CartStateProvider() => _instance;
  CartStateProvider._internal();

  bool _hasItemsInCart = false;
  int _totalItems = 0;
  Store? _currentStore;

  bool get hasItemsInCart => _hasItemsInCart;
  int get totalItems => _totalItems;
  Store? get currentStore => _currentStore;

  Future<void> updateCartState() async {
    final cart = CartManager.currentCart;
    _hasItemsInCart = cart.isNotEmpty;
    _totalItems = cart.totalQuantity;
    _currentStore = cart.store;
    notifyListeners();
  }

  Future<void> clearCart() async {
    await CartManager.clearCart();
    _hasItemsInCart = false;
    _totalItems = 0;
    _currentStore = null;
    notifyListeners();
  }

  Future<void> addItem(CartItem item) async {
    final success = await CartManager.addItem(item);
    if (success) {
      await updateCartState();
    }
  }

  Future<void> removeItem(int menuItemId) async {
    await CartManager.removeItem(menuItemId);
    await updateCartState();
  }

  Future<void> updateQuantity(int menuItemId, int quantity) async {
    await CartManager.updateItemQuantity(menuItemId, quantity);
    await updateCartState();
  }
}