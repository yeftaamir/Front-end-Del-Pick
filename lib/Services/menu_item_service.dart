// lib/services/menu_item_service.dart
import 'package:flutter/foundation.dart';
import 'core/base_service.dart';
import 'image_service.dart';

class MenuItemService extends BaseService {

  // Get all menu items with pagination and filtering
  static Future<Map<String, dynamic>> getAllMenuItems({
    int page = 1,
    int limit = 10,
    String? category,
    String? search,
    bool? isAvailable,
    double? minPrice,
    double? maxPrice,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (category != null) queryParams['category'] = category;
      if (search != null) queryParams['search'] = search;
      if (isAvailable != null) queryParams['isAvailable'] = isAvailable.toString();
      if (minPrice != null) queryParams['minPrice'] = minPrice.toString();
      if (maxPrice != null) queryParams['maxPrice'] = maxPrice.toString();

      final response = await BaseService.get('/menu', queryParams: queryParams);

      if (response['data'] != null) {
        _processMenuItemList(response['data']);
      }

      return response;
    } catch (e) {
      debugPrint('Get all menu items error: $e');
      rethrow;
    }
  }

  // Get menu items by store ID
  static Future<Map<String, dynamic>> getMenuItemsByStore(String storeId, {
    int page = 1,
    int limit = 10,
    String? category,
    bool? isAvailable,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (category != null) queryParams['category'] = category;
      if (isAvailable != null) queryParams['isAvailable'] = isAvailable.toString();

      final response = await BaseService.get('/menu/store/$storeId', queryParams: queryParams);

      if (response['data'] != null) {
        _processMenuItemList(response['data']);
      }

      return response;
    } catch (e) {
      debugPrint('Get menu items by store error: $e');
      rethrow;
    }
  }

  // Get menu item by ID
  static Future<Map<String, dynamic>> getMenuItemById(String menuItemId) async {
    try {
      final response = await BaseService.get('/menu/$menuItemId');

      if (response['data'] != null) {
        _processMenuItemImages(response['data']);
      }

      return response['data'] ?? {};
    } catch (e) {
      debugPrint('Get menu item by ID error: $e');
      rethrow;
    }
  }

  // Create new menu item
  static Future<Map<String, dynamic>> createMenuItem(Map<String, dynamic> menuItemData) async {
    try {
      final response = await BaseService.post('/menu', menuItemData);

      if (response['data'] != null) {
        _processMenuItemImages(response['data']);
      }

      return response['data'] ?? {};
    } catch (e) {
      debugPrint('Create menu item error: $e');
      rethrow;
    }
  }

  // Update menu item
  static Future<Map<String, dynamic>> updateMenuItem(String menuItemId, Map<String, dynamic> menuItemData) async {
    try {
      final response = await BaseService.put('/menu/$menuItemId', menuItemData);

      if (response['data'] != null) {
        _processMenuItemImages(response['data']);
      }

      return response['data'] ?? {};
    } catch (e) {
      debugPrint('Update menu item error: $e');
      rethrow;
    }
  }

  // Delete menu item
  static Future<bool> deleteMenuItem(String menuItemId) async {
    try {
      await BaseService.delete('/menu/$menuItemId');
      return true;
    } catch (e) {
      debugPrint('Delete menu item error: $e');
      rethrow;
    }
  }

  // Search menu items
  static Future<Map<String, dynamic>> searchMenuItems(String query, {
    int page = 1,
    int limit = 10,
    String? category,
    double? minPrice,
    double? maxPrice,
  }) async {
    try {
      final queryParams = {
        'search': query,
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (category != null) queryParams['category'] = category;
      if (minPrice != null) queryParams['minPrice'] = minPrice.toString();
      if (maxPrice != null) queryParams['maxPrice'] = maxPrice.toString();

      final response = await BaseService.get('/menu/search', queryParams: queryParams);

      if (response['data'] != null) {
        _processMenuItemList(response['data']);
      }

      return response;
    } catch (e) {
      debugPrint('Search menu items error: $e');
      rethrow;
    }
  }

  // Get menu categories
  static Future<List<String>> getMenuCategories() async {
    try {
      final response = await BaseService.get('/menu/categories');

      if (response['data'] != null && response['data'] is List) {
        return List<String>.from(response['data']);
      }

      return [];
    } catch (e) {
      debugPrint('Get menu categories error: $e');
      rethrow;
    }
  }

  // PRIVATE HELPER METHODS

  static void _processMenuItemList(dynamic data) {
    try {
      List<dynamic> menuItems = [];

      if (data is List) {
        menuItems = data;
      } else if (data is Map && data['items'] is List) {
        menuItems = data['items'];
      }

      for (var menuItem in menuItems) {
        _processMenuItemImages(menuItem);
      }
    } catch (e) {
      debugPrint('Process menu item list error: $e');
    }
  }

  static void _processMenuItemImages(Map<String, dynamic> menuItemData) {
    try {
      if (menuItemData['imageUrl'] != null) {
        menuItemData['imageUrl'] = ImageService.getImageUrl(menuItemData['imageUrl']);
      }

      if (menuItemData['image'] != null) {
        menuItemData['image'] = ImageService.getImageUrl(menuItemData['image']);
      }

      // Process store information if present
      if (menuItemData['store'] != null && menuItemData['store']['imageUrl'] != null) {
        menuItemData['store']['imageUrl'] = ImageService.getImageUrl(menuItemData['store']['imageUrl']);
      }
    } catch (e) {
      debugPrint('Process menu item images error: $e');
    }
  }
}