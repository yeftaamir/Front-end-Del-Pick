// lib/services/customer/store_detail_service.dart
import 'package:geolocator/geolocator.dart';

import '../../Models/Base/api_response.dart';
import '../../Models/Entities/store.dart';
import '../../Models/Entities/menu_item.dart';
import '../../Models/Exceptions/api_exception.dart';
import '../../Services/Store/store_service.dart';
import '../../Services/Menu/menu_item_service.dart';
import '../../Services/Utils/location_service.dart';
import '../../Services/Utils/error_handler.dart';

class StoreDetailService {
  // Get store details by ID
  static Future<Store> getStoreById(int storeId) async {
    try {
      final response = await StoreService.getStoreById(storeId);

      if (response.isSuccess && response.data != null) {
        return response.data!;
      } else {
        throw ApiException(
          message: response.message,
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      ErrorHandler.logError(e, context: 'StoreDetailService.getStoreById');
      rethrow;
    }
  }

  // Get menu items by store ID
  static Future<List<MenuItem>> getMenuItemsByStore(int storeId) async {
    try {
      final response = await MenuItemService.getMenuItemsByStore(storeId);

      if (response.isSuccess && response.data != null) {
        return response.data!;
      } else {
        throw ApiException(
          message: response.message,
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      ErrorHandler.logError(e, context: 'StoreDetailService.getMenuItemsByStore');
      rethrow;
    }
  }

  // Calculate distance between user and store
  static double? calculateStoreDistance(
      Position? userPosition,
      Store store,
      ) {
    if (userPosition == null) return null;

    return LocationService.calculateDistance(
      userPosition.latitude,
      userPosition.longitude,
      store.latitude,
      store.longitude,
    );
  }

  // Format distance for display
  static String formatDistance(double? distanceKm) {
    if (distanceKm == null) return "-- km";

    if (distanceKm < 1) {
      return "${(distanceKm * 1000).toInt()} m";
    } else {
      return "${distanceKm.toStringAsFixed(1)} km";
    }
  }

  // Search menu items
  static List<MenuItem> searchMenuItems(List<MenuItem> menuItems, String query) {
    if (query.isEmpty) return menuItems;

    final lowercaseQuery = query.toLowerCase();
    return menuItems.where((item) {
      return item.name.toLowerCase().contains(lowercaseQuery) ||
          (item.description?.toLowerCase().contains(lowercaseQuery) ?? false);
    }).toList();
  }

  // Calculate remaining stock for an item
  static int calculateRemainingStock(MenuItem item, Map<int, int> originalStockMap) {
    final originalStock = originalStockMap[item.id] ?? 0;
    return originalStock; // Since we're not tracking cart quantities in this service
  }

  // Validate if item can be added to cart
  static bool canAddItemToCart(MenuItem item, int remainingStock) {
    return item.isAvailable && remainingStock > 0;
  }

  // Calculate cart totals
  static CartSummary calculateCartSummary(List<MenuItem> menuItems) {
    final cartItems = menuItems.where((item) => item.id > 0).toList(); // Items with quantity > 0

    int totalItems = 0;
    double totalPrice = 0.0;

    for (var item in cartItems) {
      // This would need to be updated based on how you track quantities
      // For now, assuming a quantity property exists or is tracked separately
      final quantity = 1; // Placeholder - replace with actual quantity tracking
      totalItems += quantity;
      totalPrice += item.price * quantity;
    }

    return CartSummary(
      totalItems: totalItems,
      totalPrice: totalPrice,
      hasItems: totalItems > 0,
    );
  }

  // Get menu categories
  static Future<List<String>> getMenuCategories(int storeId) async {
    try {
      final response = await MenuItemService.getMenuCategories(storeId);

      if (response.isSuccess && response.data != null) {
        return response.data!;
      } else {
        return [];
      }
    } catch (e) {
      ErrorHandler.logError(e, context: 'StoreDetailService.getMenuCategories');
      return [];
    }
  }

  // Filter menu items by category
  static List<MenuItem> filterByCategory(List<MenuItem> menuItems, String? category) {
    if (category == null || category.isEmpty) return menuItems;

    return menuItems.where((item) => item.category == category).toList();
  }

  // Check if store is currently open
  static bool isStoreOpen(Store store) {
    if (store.openTime == null || store.closeTime == null) {
      return true; // Assume open if no time specified
    }

    final now = DateTime.now();
    final currentTime = now.hour * 60 + now.minute;

    try {
      final openParts = store.openTime!.split(':');
      final closeParts = store.closeTime!.split(':');

      final openTime = int.parse(openParts[0]) * 60 + int.parse(openParts[1]);
      final closeTime = int.parse(closeParts[0]) * 60 + int.parse(closeParts[1]);

      if (openTime <= closeTime) {
        // Same day (e.g., 9:00 - 17:00)
        return currentTime >= openTime && currentTime <= closeTime;
      } else {
        // Crosses midnight (e.g., 22:00 - 06:00)
        return currentTime >= openTime || currentTime <= closeTime;
      }
    } catch (e) {
      return true; // Default to open if parsing fails
    }
  }

  // Get store operating hours display
  static String getOperatingHoursDisplay(Store store) {
    if (store.openTime == null || store.closeTime == null) {
      return "24 Jam";
    }
    return "${store.openTime} - ${store.closeTime}";
  }

  // Validate menu item availability
  static ItemValidationResult validateItemForCart(
      MenuItem item,
      int currentQuantity,
      int requestedQuantity,
      Map<int, int> originalStockMap,
      ) {
    if (!item.isAvailable) {
      return ItemValidationResult(
        isValid: false,
        errorType: ItemErrorType.unavailable,
        message: "Item ini sedang tidak tersedia",
      );
    }

    final originalStock = originalStockMap[item.id] ?? 0;
    final totalRequested = currentQuantity + requestedQuantity;

    if (totalRequested > originalStock) {
      return ItemValidationResult(
        isValid: false,
        errorType: ItemErrorType.outOfStock,
        message: "Stok tidak mencukupi. Stok tersedia: $originalStock",
      );
    }

    if (requestedQuantity <= 0) {
      return ItemValidationResult(
        isValid: false,
        errorType: ItemErrorType.zeroQuantity,
        message: "Jumlah harus lebih dari 0",
      );
    }

    return ItemValidationResult(
      isValid: true,
      errorType: ItemErrorType.none,
      message: "Valid",
    );
  }
}

// Helper classes
class CartSummary {
  final int totalItems;
  final double totalPrice;
  final bool hasItems;

  CartSummary({
    required this.totalItems,
    required this.totalPrice,
    required this.hasItems,
  });
}

class ItemValidationResult {
  final bool isValid;
  final ItemErrorType errorType;
  final String message;

  ItemValidationResult({
    required this.isValid,
    required this.errorType,
    required this.message,
  });
}

enum ItemErrorType {
  none,
  unavailable,
  outOfStock,
  zeroQuantity,
}