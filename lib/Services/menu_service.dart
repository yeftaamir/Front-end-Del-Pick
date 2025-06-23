// lib/Services/menu_item_service.dart
import 'dart:convert';
import 'core/base_service.dart';
import 'image_service.dart';

class MenuItemService {
  static const String _baseEndpoint = '/menu';

  /// Get all menu items (with pagination and filtering)
  static Future<Map<String, dynamic>> getAllMenuItems({
    int page = 1,
    int limit = 20,
    String? category,
    String? search,
    String? sortBy,
    String? sortOrder,
    bool? isAvailable,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (category != null) 'category': category,
        if (search != null) 'search': search,
        if (sortBy != null) 'sortBy': sortBy,
        if (sortOrder != null) 'sortOrder': sortOrder,
        if (isAvailable != null) 'isAvailable': isAvailable.toString(),
      };

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: _baseEndpoint,
        queryParams: queryParams,
        requiresAuth: true,
      );

      // Process menu item images
      if (response['data'] != null && response['data'] is List) {
        for (var menuItem in response['data']) {
          _processMenuItemImages(menuItem);
        }
      }

      return response;
    } catch (e) {
      print('Get all menu items error: $e');
      throw Exception('Failed to get menu items: $e');
    }
  }

  /// Get menu items by store ID
  static Future<Map<String, dynamic>> getMenuItemsByStore({
    required String storeId,
    int page = 1,
    int limit = 50,
    String? category,
    bool? isAvailable,
    String? sortBy,
    String? sortOrder,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (category != null) 'category': category,
        if (isAvailable != null) 'isAvailable': isAvailable.toString(),
        if (sortBy != null) 'sortBy': sortBy,
        if (sortOrder != null) 'sortOrder': sortOrder,
      };

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/store/$storeId',
        queryParams: queryParams,
        requiresAuth: true,
      );

      // Process menu item images
      if (response['data'] != null && response['data'] is List) {
        for (var menuItem in response['data']) {
          _processMenuItemImages(menuItem);
        }
      }

      return response;
    } catch (e) {
      print('Get menu items by store error: $e');
      throw Exception('Failed to get store menu items: $e');
    }
  }

  /// Get menu item by ID
  static Future<Map<String, dynamic>> getMenuItemById(String menuItemId) async {
    try {
      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/$menuItemId',
        requiresAuth: true,
      );

      if (response['data'] != null) {
        _processMenuItemImages(response['data']);
      }

      return response['data'] ?? {};
    } catch (e) {
      print('Get menu item by ID error: $e');
      throw Exception('Failed to get menu item: $e');
    }
  }

  /// Create new menu item (for store owners)
  static Future<Map<String, dynamic>> createMenuItem({
    required String name,
    required double price,
    required String storeId,
    required String category,
    String? description,
    String? imageBase64,
    int quantity = 1,
    bool isAvailable = true,
  }) async {
    try {
      final body = {
        'name': name,
        'price': price,
        'storeId': int.parse(storeId),
        'category': category,
        'quantity': quantity,
        'isAvailable': isAvailable,
        if (description != null) 'description': description,
        if (imageBase64 != null) 'image': imageBase64,
      };

      final response = await BaseService.apiCall(
        method: 'POST',
        endpoint: _baseEndpoint,
        body: body,
        requiresAuth: true,
      );

      if (response['data'] != null) {
        _processMenuItemImages(response['data']);
      }

      return response['data'] ?? {};
    } catch (e) {
      print('Create menu item error: $e');
      throw Exception('Failed to create menu item: $e');
    }
  }

  /// Update menu item (for store owners)
  static Future<Map<String, dynamic>> updateMenuItem({
    required String menuItemId,
    required Map<String, dynamic> updateData,
  }) async {
    try {
      final response = await BaseService.apiCall(
        method: 'PUT',
        endpoint: '$_baseEndpoint/$menuItemId',
        body: updateData,
        requiresAuth: true,
      );

      if (response['data'] != null) {
        _processMenuItemImages(response['data']);
      }

      return response['data'] ?? {};
    } catch (e) {
      print('Update menu item error: $e');
      throw Exception('Failed to update menu item: $e');
    }
  }

  /// Delete menu item (for store owners)
  static Future<bool> deleteMenuItem(String menuItemId) async {
    try {
      await BaseService.apiCall(
        method: 'DELETE',
        endpoint: '$_baseEndpoint/$menuItemId',
        requiresAuth: true,
      );
      return true;
    } catch (e) {
      print('Delete menu item error: $e');
      throw Exception('Failed to delete menu item: $e');
    }
  }

  /// Update menu item status (available/unavailable)
  static Future<Map<String, dynamic>> updateMenuItemStatus({
    required String menuItemId,
    required String status, // available, unavailable
  }) async {
    try {
      if (!['available', 'unavailable'].contains(status)) {
        throw Exception('Invalid status. Must be "available" or "unavailable"');
      }

      final response = await BaseService.apiCall(
        method: 'PATCH',
        endpoint: '$_baseEndpoint/$menuItemId/status',
        body: {'status': status},
        requiresAuth: true,
      );

      return response['data'] ?? {};
    } catch (e) {
      print('Update menu item status error: $e');
      throw Exception('Failed to update menu item status: $e');
    }
  }

  /// Search menu items across stores
  static Future<List<Map<String, dynamic>>> searchMenuItems({
    required String query,
    String? category,
    double? minPrice,
    double? maxPrice,
    double? userLatitude,
    double? userLongitude,
    double? maxDistance,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final queryParams = {
        'search': query,
        'page': page.toString(),
        'limit': limit.toString(),
        if (category != null) 'category': category,
        if (minPrice != null) 'minPrice': minPrice.toString(),
        if (maxPrice != null) 'maxPrice': maxPrice.toString(),
        if (userLatitude != null) 'latitude': userLatitude.toString(),
        if (userLongitude != null) 'longitude': userLongitude.toString(),
        if (maxDistance != null) 'maxDistance': maxDistance.toString(),
      };

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: _baseEndpoint,
        queryParams: queryParams,
        requiresAuth: true,
      );

      final menuItems = List<Map<String, dynamic>>.from(response['data'] ?? []);
      for (var menuItem in menuItems) {
        _processMenuItemImages(menuItem);
      }

      return menuItems;
    } catch (e) {
      print('Search menu items error: $e');
      throw Exception('Failed to search menu items: $e');
    }
  }

  /// Get menu categories
  static Future<List<String>> getMenuCategories() async {
    try {
      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/categories',
        requiresAuth: true,
      );

      return List<String>.from(response['data'] ?? []);
    } catch (e) {
      print('Get menu categories error: $e');
      return []; // Return empty list on error
    }
  }

  /// Get popular menu items
  static Future<List<Map<String, dynamic>>> getPopularMenuItems({
    int limit = 10,
    String? category,
  }) async {
    try {
      final queryParams = {
        'limit': limit.toString(),
        'sortBy': 'popularity',
        'sortOrder': 'desc',
        if (category != null) 'category': category,
      };

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: _baseEndpoint,
        queryParams: queryParams,
        requiresAuth: true,
      );

      final menuItems = List<Map<String, dynamic>>.from(response['data'] ?? []);
      for (var menuItem in menuItems) {
        _processMenuItemImages(menuItem);
      }

      return menuItems;
    } catch (e) {
      print('Get popular menu items error: $e');
      return [];
    }
  }

  // PRIVATE HELPER METHODS

  /// Process menu item images
  static void _processMenuItemImages(Map<String, dynamic> menuItem) {
    try {
      // Process menu item image
      if (menuItem['image_url'] != null && menuItem['image_url'].toString().isNotEmpty) {
        menuItem['image_url'] = ImageService.getImageUrl(menuItem['image_url']);
      }

      // Process store image if included
      if (menuItem['store'] != null && menuItem['store']['image_url'] != null) {
        menuItem['store']['image_url'] = ImageService.getImageUrl(menuItem['store']['image_url']);
      }
    } catch (e) {
      print('Error processing menu item images: $e');
    }
  }
}
