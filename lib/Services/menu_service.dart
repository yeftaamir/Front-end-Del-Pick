// lib/Services/menu_service.dart
import 'dart:convert';
import 'core/base_service.dart';
import 'image_service.dart';
import 'auth_service.dart';

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
      // Ensure user is authenticated as customer
      final userData = await AuthService.getRoleSpecificData();
      if (userData == null) {
        throw Exception('User not authenticated');
      }

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
      print('❌ Get all menu items error: $e');
      throw Exception('Failed to get menu items: $e');
    }
  }

  /// Get menu items by store ID with enhanced error handling and customer access validation
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
      print('🔍 MenuItemService: Starting to fetch menu items for store $storeId');

      // Validate customer access
      final userData = await AuthService.getRoleSpecificData();
      if (userData == null) {
        throw Exception('User not authenticated');
      }

      final userRole = await AuthService.getUserRole();
      if (userRole?.toLowerCase() != 'customer') {
        throw Exception('Access denied: Only customers can view store menus');
      }

      print('✅ MenuItemService: Customer access validated');

      // Validate storeId
      final parsedStoreId = int.tryParse(storeId);
      if (parsedStoreId == null || parsedStoreId <= 0) {
        throw Exception('Invalid store ID: $storeId');
      }

      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (category != null) 'category': category,
        if (isAvailable != null) 'isAvailable': isAvailable.toString(),
        if (sortBy != null) 'sortBy': sortBy,
        if (sortOrder != null) 'sortOrder': sortOrder,
      };

      print('🔍 MenuItemService: Making API call with params: $queryParams');

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/store/$storeId',
        queryParams: queryParams,
        requiresAuth: true,
      );

      print('🔍 MenuItemService: Raw API response structure: ${response.keys.toList()}');

      // Enhanced response processing with better error handling
      if (response['data'] != null) {
        if (response['data'] is List) {
          final menuItemsList = response['data'] as List;
          print('📋 MenuItemService: Found ${menuItemsList.length} raw menu items');

          if (menuItemsList.isEmpty) {
            print('⚠️ MenuItemService: No menu items found for store $storeId');
            return {
              'success': true,
              'data': [],
              'total': 0,
              'page': page,
              'limit': limit,
              'message': 'No menu items found for this store',
            };
          }

          // Process each menu item with individual error handling
          final processedItems = <Map<String, dynamic>>[];
          for (int i = 0; i < menuItemsList.length; i++) {
            try {
              final item = Map<String, dynamic>.from(menuItemsList[i]);

              // Debug logging for price field
              print('🔍 Processing item $i: ${item['name']}');
              print('   - Price: ${item['price']} (${item['price'].runtimeType})');
              print('   - Available: ${item['is_available']}');
              print('   - Store ID: ${item['store_id']}');

              // Ensure price is properly formatted as double
              if (item['price'] != null) {
                if (item['price'] is String) {
                  item['price'] = double.tryParse(item['price']) ?? 0.0;
                } else if (item['price'] is int) {
                  item['price'] = item['price'].toDouble();
                }
              } else {
                item['price'] = 0.0;
              }

              // Ensure boolean fields are properly typed
              if (item['is_available'] != null) {
                if (item['is_available'] is String) {
                  item['is_available'] = item['is_available'].toLowerCase() == 'true';
                }
              } else {
                item['is_available'] = true;
              }

              // Process images
              _processMenuItemImages(item);

              // Validate required fields
              if (item['id'] != null && item['name'] != null && item['price'] != null) {
                processedItems.add(item);
                print('✅ Successfully processed item: ${item['name']}');
              } else {
                print('⚠️ Skipping item $i due to missing required fields');
              }

            } catch (e) {
              print('❌ Error processing menu item $i: $e');
              print('❌ Item data: ${menuItemsList[i]}');
              // Continue processing other items instead of failing completely
            }
          }

          print('✅ MenuItemService: Successfully processed ${processedItems.length}/${menuItemsList.length} menu items');

          return {
            'success': true,
            'data': processedItems,
            'total': processedItems.length,
            'page': page,
            'limit': limit,
            'message': 'Menu items loaded successfully',
          };

        } else {
          print('⚠️ MenuItemService: Unexpected response format - data is not a list');
          print('⚠️ Response data type: ${response['data'].runtimeType}');
          print('⚠️ Response data: ${response['data']}');

          return {
            'success': false,
            'data': [],
            'total': 0,
            'page': page,
            'limit': limit,
            'error': 'Unexpected response format from server',
          };
        }
      } else {
        print('⚠️ MenuItemService: No data in response');
        print('⚠️ Full response: $response');

        return {
          'success': false,
          'data': [],
          'total': 0,
          'page': page,
          'limit': limit,
          'error': 'No data received from server',
        };
      }

    } catch (e) {
      print('❌ MenuItemService: Get menu items by store error: $e');

      // Return structured error response
      return {
        'success': false,
        'data': [],
        'total': 0,
        'page': page,
        'limit': limit,
        'error': e.toString(),
      };
    }
  }

  /// Get menu item by ID with customer access validation
  static Future<Map<String, dynamic>> getMenuItemById(String menuItemId) async {
    try {
      print('🔍 MenuItemService: Getting menu item by ID: $menuItemId');

      // Validate customer access
      final userData = await AuthService.getRoleSpecificData();
      if (userData == null) {
        throw Exception('User not authenticated');
      }

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/$menuItemId',
        requiresAuth: true,
      );

      if (response['data'] != null) {
        final item = Map<String, dynamic>.from(response['data']);

        // Process price field
        if (item['price'] != null) {
          if (item['price'] is String) {
            item['price'] = double.tryParse(item['price']) ?? 0.0;
          } else if (item['price'] is int) {
            item['price'] = item['price'].toDouble();
          }
        }

        // Process availability field
        if (item['is_available'] != null) {
          if (item['is_available'] is String) {
            item['is_available'] = item['is_available'].toLowerCase() == 'true';
          }
        }

        _processMenuItemImages(item);

        print('✅ MenuItemService: Successfully retrieved menu item: ${item['name']}');
        return {
          'success': true,
          'data': item,
        };
      }

      return {
        'success': false,
        'data': {},
        'error': 'Menu item not found',
      };
    } catch (e) {
      print('❌ MenuItemService: Get menu item by ID error: $e');
      return {
        'success': false,
        'data': {},
        'error': e.toString(),
      };
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
      print('🔨 MenuItemService: Creating menu item for store $storeId');

      // Validate store owner access
      final userData = await AuthService.getRoleSpecificData();
      if (userData == null) {
        throw Exception('User not authenticated');
      }

      final userRole = await AuthService.getUserRole();
      if (userRole?.toLowerCase() != 'store') {
        throw Exception('Access denied: Only store owners can create menu items');
      }

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

      print('🔨 MenuItemService: Request body: ${body.keys.toList()}');

      final response = await BaseService.apiCall(
        method: 'POST',
        endpoint: _baseEndpoint,
        body: body,
        requiresAuth: true,
      );

      print('✅ MenuItemService: Menu item created successfully');

      if (response['data'] != null) {
        _processMenuItemImages(response['data']);
      }

      return response['data'] ?? {};
    } catch (e) {
      print('❌ MenuItemService: Create menu item error: $e');
      throw Exception('Failed to create menu item: $e');
    }
  }

  /// Update menu item (for store owners)
  static Future<Map<String, dynamic>> updateMenuItem({
    required String menuItemId,
    required Map<String, dynamic> updateData,
  }) async {
    try {
      print('🔧 MenuItemService: Updating menu item $menuItemId');

      // Validate store owner access
      final userData = await AuthService.getRoleSpecificData();
      if (userData == null) {
        throw Exception('User not authenticated');
      }

      final userRole = await AuthService.getUserRole();
      if (userRole?.toLowerCase() != 'store') {
        throw Exception('Access denied: Only store owners can update menu items');
      }

      print('🔧 MenuItemService: Update data keys: ${updateData.keys.toList()}');

      final response = await BaseService.apiCall(
        method: 'PUT',
        endpoint: '$_baseEndpoint/$menuItemId',
        body: updateData,
        requiresAuth: true,
      );

      print('✅ MenuItemService: Menu item updated successfully');

      if (response['data'] != null) {
        _processMenuItemImages(response['data']);
      }

      return response['data'] ?? {};
    } catch (e) {
      print('❌ MenuItemService: Update menu item error: $e');
      throw Exception('Failed to update menu item: $e');
    }
  }

  /// Delete menu item (for store owners)
  static Future<bool> deleteMenuItem(String menuItemId) async {
    try {
      print('🗑️ MenuItemService: Deleting menu item $menuItemId');

      // Validate store owner access
      final userData = await AuthService.getRoleSpecificData();
      if (userData == null) {
        throw Exception('User not authenticated');
      }

      final userRole = await AuthService.getUserRole();
      if (userRole?.toLowerCase() != 'store') {
        throw Exception('Access denied: Only store owners can delete menu items');
      }

      await BaseService.apiCall(
        method: 'DELETE',
        endpoint: '$_baseEndpoint/$menuItemId',
        requiresAuth: true,
      );

      print('✅ MenuItemService: Menu item deleted successfully');
      return true;
    } catch (e) {
      print('❌ MenuItemService: Delete menu item error: $e');
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

      print('🔄 MenuItemService: Updating item $menuItemId status to $status');

      // Validate store owner access
      final userData = await AuthService.getRoleSpecificData();
      if (userData == null) {
        throw Exception('User not authenticated');
      }

      final userRole = await AuthService.getUserRole();
      if (userRole?.toLowerCase() != 'store') {
        throw Exception('Access denied: Only store owners can update menu item status');
      }

      final response = await BaseService.apiCall(
        method: 'PATCH',
        endpoint: '$_baseEndpoint/$menuItemId/status',
        body: {'status': status},
        requiresAuth: true,
      );

      print('✅ MenuItemService: Item status updated successfully');

      return response['data'] ?? {};
    } catch (e) {
      print('❌ MenuItemService: Update menu item status error: $e');
      throw Exception('Failed to update menu item status: $e');
    }
  }

  /// Search menu items across stores (customer access)
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
      // Validate customer access
      final userData = await AuthService.getRoleSpecificData();
      if (userData == null) {
        throw Exception('User not authenticated');
      }

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
      print('❌ MenuItemService: Search menu items error: $e');
      throw Exception('Failed to search menu items: $e');
    }
  }

  /// Get menu categories (public access)
  static Future<List<String>> getMenuCategories() async {
    try {
      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/categories',
        requiresAuth: true,
      );

      return List<String>.from(response['data'] ?? []);
    } catch (e) {
      print('❌ MenuItemService: Get menu categories error: $e');
      return []; // Return empty list on error
    }
  }

  /// Get popular menu items (customer access)
  static Future<List<Map<String, dynamic>>> getPopularMenuItems({
    int limit = 10,
    String? category,
  }) async {
    try {
      // Validate customer access
      final userData = await AuthService.getRoleSpecificData();
      if (userData == null) {
        throw Exception('User not authenticated');
      }

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
      print('❌ MenuItemService: Get popular menu items error: $e');
      return [];
    }
  }

  // PRIVATE HELPER METHODS

  /// Process menu item images with enhanced error handling
  static void _processMenuItemImages(Map<String, dynamic> menuItem) {
    try {
      // Process menu item image
      if (menuItem['image_url'] != null && menuItem['image_url'].toString().isNotEmpty) {
        final originalUrl = menuItem['image_url'].toString();
        final processedUrl = ImageService.getImageUrl(originalUrl);
        menuItem['image_url'] = processedUrl;
        print('🖼️ Processed image URL: $originalUrl -> $processedUrl');
      }

      // Process store image if included
      if (menuItem['store'] != null && menuItem['store']['image_url'] != null) {
        final originalUrl = menuItem['store']['image_url'].toString();
        final processedUrl = ImageService.getImageUrl(originalUrl);
        menuItem['store']['image_url'] = processedUrl;
        print('🏪 Processed store image URL: $originalUrl -> $processedUrl');
      }
    } catch (e) {
      print('❌ Error processing menu item images: $e');
    }
  }

  /// Debug method to inspect menu item data structure
  static void debugMenuItemData(Map<String, dynamic> item) {
    print('🔍 ====== MENU ITEM DEBUG ======');
    print('📋 Item ID: ${item['id']} (${item['id']?.runtimeType})');
    print('📋 Item Name: ${item['name']} (${item['name']?.runtimeType})');
    print('💰 Item Price: ${item['price']} (${item['price']?.runtimeType})');
    print('🏪 Store ID: ${item['store_id']} (${item['store_id']?.runtimeType})');
    print('📂 Category: ${item['category']} (${item['category']?.runtimeType})');
    print('✅ Available: ${item['is_available']} (${item['is_available']?.runtimeType})');
    print('🖼️ Image URL: ${item['image_url']} (${item['image_url']?.runtimeType})');
    print('📝 Description: ${item['description']} (${item['description']?.runtimeType})');
    print('🔍 ====== END DEBUG ======');
  }

  /// Validate menu item data structure
  static bool validateMenuItemData(Map<String, dynamic> item) {
    final requiredFields = ['id', 'name', 'price', 'store_id'];

    for (String field in requiredFields) {
      if (item[field] == null) {
        print('❌ Missing required field: $field');
        return false;
      }
    }

    // Validate price is numeric
    if (item['price'] is! num && item['price'] is! String) {
      print('❌ Invalid price format: ${item['price']}');
      return false;
    }

    return true;
  }
}