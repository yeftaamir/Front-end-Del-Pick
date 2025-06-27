// lib/Services/menu_service.dart
import 'dart:convert';
import 'core/base_service.dart';
import 'image_service.dart';
import 'auth_service.dart';

class MenuItemService {
  static const String _baseEndpoint = '/menu';
  static const bool _debugMode = false; // Toggle for development debugging

  static void _log(String message) {
    if (_debugMode) print(message);
  }

  /// Get all menu items - Optimized version
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
      // Ensure user is authenticated
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

      // Batch process menu item images
      if (response['data'] != null && response['data'] is List) {
        final menuItems = response['data'] as List;
        for (var menuItem in menuItems) {
          _processMenuItemData(menuItem);
        }
      }

      return {
        'success': true,
        'data': response['data'] ?? [],
        'total': response['total'] ?? 0,
        'page': page,
        'limit': limit,
      };
    } catch (e) {
      _log('Get all menu items error: $e');
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

  /// Get menu items by store - Optimized version
  static Future<Map<String, dynamic>> getMenuItemsByStore({
    required String storeId,
    int page = 1,
    int limit = 50,
    String? category,
    bool? isAvailable,
    String? sortBy,
    String? sortOrder,
    bool bustCache = false,
  }) async {
    try {
      _log('Fetching menu items for store $storeId (bustCache: $bustCache)');

      // Batch authentication validation
      final validationResults = await Future.wait([
        AuthService.getRoleSpecificData(),
        AuthService.getUserRole(),
      ]);

      final userData = validationResults[0] as Map<String, dynamic>?;
      final userRole = validationResults[1] as String?;

      if (userData == null) {
        throw Exception('User not authenticated');
      }

      if (userRole == null) {
        throw Exception('Unable to determine user role');
      }

      _log('User authenticated with role: $userRole');

      // Validate storeId format
      final parsedStoreId = int.tryParse(storeId);
      if (parsedStoreId == null || parsedStoreId <= 0) {
        throw Exception('Invalid store ID format: $storeId');
      }

      // Build query parameters efficiently
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
        if (category != null) 'category': category,
        if (isAvailable != null) 'isAvailable': isAvailable.toString(),
        if (sortBy != null) 'sortBy': sortBy,
        if (sortOrder != null) 'sortOrder': sortOrder,
      };

      // Add cache-busting parameters if requested
      if (bustCache) {
        queryParams.addAll({
          '_t': DateTime.now().millisecondsSinceEpoch.toString(),
          '_fresh': 'true',
        });
        _log('Added cache-busting parameters');
      }

      _log('API call params: $queryParams');

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/store/$storeId',
        queryParams: queryParams,
        requiresAuth: true,
      );

      _log('Response keys: ${response.keys.toList()}');

      // Efficiently extract menu items from various response structures
      final menuItemsList = _extractMenuItemsList(response);

      _log('Found ${menuItemsList.length} raw menu items');

      if (menuItemsList.isEmpty) {
        _log('No menu items found for store $storeId');
        return _createEmptyMenuResponse(page, limit, 'No menu items found for this store');
      }

      // Batch process menu items
      final processedItems = _batchProcessMenuItems(menuItemsList);

      _log('Successfully processed ${processedItems.length}/${menuItemsList.length} menu items');

      return {
        'success': true,
        'data': processedItems,
        'total': response['total'] ?? processedItems.length,
        'page': page,
        'limit': limit,
        'message': 'Menu items loaded successfully',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

    } catch (e) {
      _log('Get menu items by store error: $e');

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

  /// Get menu item by ID - Optimized
  static Future<Map<String, dynamic>> getMenuItemById(String menuItemId) async {
    try {
      _log('Getting menu item by ID: $menuItemId');

      // Validate authentication
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

        // Process data efficiently
        _processMenuItemData(item);

        _log('Successfully retrieved menu item: ${item['name']}');
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
      _log('Get menu item by ID error: $e');
      return {
        'success': false,
        'data': {},
        'error': e.toString(),
      };
    }
  }

  /// Create new menu item - Optimized
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
      _log('Creating menu item for store $storeId');

      // Batch validate store owner access
      final validationResults = await Future.wait([
        AuthService.getRoleSpecificData(),
        AuthService.getUserRole(),
      ]);

      final userData = validationResults[0] as Map<String, dynamic>?;
      final userRole = validationResults[1] as String?;

      if (userData == null) {
        throw Exception('User not authenticated');
      }

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

      _log('Request body keys: ${body.keys.toList()}');

      final response = await BaseService.apiCall(
        method: 'POST',
        endpoint: _baseEndpoint,
        body: body,
        requiresAuth: true,
      );

      _log('Menu item created successfully');

      if (response['data'] != null) {
        _processMenuItemData(response['data']);
      }

      return {
        'success': true,
        'data': response['data'] ?? {},
      };
    } catch (e) {
      _log('Create menu item error: $e');
      return {
        'success': false,
        'data': {},
        'error': e.toString(),
      };
    }
  }

  /// Update menu item - Optimized
  static Future<Map<String, dynamic>> updateMenuItem({
    required String menuItemId,
    required Map<String, dynamic> updateData,
  }) async {
    try {
      _log('Updating menu item $menuItemId');

      // Batch validate store owner access
      final validationResults = await Future.wait([
        AuthService.getRoleSpecificData(),
        AuthService.getUserRole(),
      ]);

      final userData = validationResults[0] as Map<String, dynamic>?;
      final userRole = validationResults[1] as String?;

      if (userData == null) {
        throw Exception('User not authenticated');
      }

      if (userRole?.toLowerCase() != 'store') {
        throw Exception('Access denied: Only store owners can update menu items');
      }

      _log('Update data keys: ${updateData.keys.toList()}');

      final response = await BaseService.apiCall(
        method: 'PUT',
        endpoint: '$_baseEndpoint/$menuItemId',
        body: updateData,
        requiresAuth: true,
      );

      _log('Menu item updated successfully');

      if (response['data'] != null) {
        _processMenuItemData(response['data']);
      }

      return {
        'success': true,
        'data': response['data'] ?? {},
      };
    } catch (e) {
      _log('Update menu item error: $e');
      return {
        'success': false,
        'data': {},
        'error': e.toString(),
      };
    }
  }

  /// Delete menu item - Optimized
  static Future<bool> deleteMenuItem(String menuItemId) async {
    try {
      _log('Deleting menu item $menuItemId');

      // Batch validate store owner access
      final validationResults = await Future.wait([
        AuthService.getRoleSpecificData(),
        AuthService.getUserRole(),
      ]);

      final userData = validationResults[0] as Map<String, dynamic>?;
      final userRole = validationResults[1] as String?;

      if (userData == null) {
        throw Exception('User not authenticated');
      }

      if (userRole?.toLowerCase() != 'store') {
        throw Exception('Access denied: Only store owners can delete menu items');
      }

      await BaseService.apiCall(
        method: 'DELETE',
        endpoint: '$_baseEndpoint/$menuItemId',
        requiresAuth: true,
      );

      _log('Menu item deleted successfully');
      return true;
    } catch (e) {
      _log('Delete menu item error: $e');
      throw Exception('Failed to delete menu item: $e');
    }
  }

  /// Update menu item status - Optimized
  static Future<Map<String, dynamic>> updateMenuItemStatus({
    required String menuItemId,
    required String status,
  }) async {
    try {
      if (!['available', 'unavailable'].contains(status)) {
        throw Exception('Invalid status. Must be "available" or "unavailable"');
      }

      _log('Updating item $menuItemId status to $status');

      // Batch validate store owner access
      final validationResults = await Future.wait([
        AuthService.getRoleSpecificData(),
        AuthService.getUserRole(),
      ]);

      final userData = validationResults[0] as Map<String, dynamic>?;
      final userRole = validationResults[1] as String?;

      if (userData == null) {
        throw Exception('User not authenticated');
      }

      if (userRole?.toLowerCase() != 'store') {
        throw Exception('Access denied: Only store owners can update menu item status');
      }

      final response = await BaseService.apiCall(
        method: 'PATCH',
        endpoint: '$_baseEndpoint/$menuItemId/status',
        body: {'status': status},
        requiresAuth: true,
      );

      _log('Item status updated successfully');

      return {
        'success': true,
        'data': response['data'] ?? {},
      };
    } catch (e) {
      _log('Update menu item status error: $e');
      return {
        'success': false,
        'data': {},
        'error': e.toString(),
      };
    }
  }

  /// Search menu items - Optimized
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
      // Validate authentication
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
        _processMenuItemData(menuItem);
      }

      return menuItems;
    } catch (e) {
      _log('Search menu items error: $e');
      return [];
    }
  }

  /// Get menu categories - Optimized
  static Future<List<String>> getMenuCategories() async {
    try {
      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/categories',
        requiresAuth: true,
      );

      return List<String>.from(response['data'] ?? []);
    } catch (e) {
      _log('Get menu categories error: $e');
      return [];
    }
  }

  /// Get popular menu items - Optimized
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
        _processMenuItemData(menuItem);
      }

      return menuItems;
    } catch (e) {
      _log('Get popular menu items error: $e');
      return [];
    }
  }

  // PRIVATE HELPER METHODS - OPTIMIZED

  /// Extract menu items list from various response structures - Optimized
  static List<dynamic> _extractMenuItemsList(Map<String, dynamic> response) {
    if (response['data'] != null) {
      if (response['data'] is List) {
        return response['data'];
      } else if (response['data'] is Map) {
        final data = response['data'] as Map<String, dynamic>;
        return data['items'] ?? data['menuItems'] ?? [];
      }
    }
    return response['menuItems'] ?? response['items'] ?? [];
  }

  /// Create empty menu response - Optimized
  static Map<String, dynamic> _createEmptyMenuResponse(int page, int limit, String message) {
    return {
      'success': true,
      'data': [],
      'total': 0,
      'page': page,
      'limit': limit,
      'message': message,
    };
  }

  /// Batch process menu items - Optimized
  static List<Map<String, dynamic>> _batchProcessMenuItems(List<dynamic> menuItemsList) {
    final processedItems = <Map<String, dynamic>>[];

    for (int i = 0; i < menuItemsList.length; i++) {
      try {
        final rawItem = menuItemsList[i];
        if (rawItem == null || rawItem is! Map) {
          _log('Skipping invalid item at index $i: $rawItem');
          continue;
        }

        final item = Map<String, dynamic>.from(rawItem);

        // Process and validate in one go
        if (_processAndValidateMenuItem(item)) {
          processedItems.add(item);
          _log('Processed item: ${item['name']} - ${item['price']}');
        } else {
          _log('Skipping item $i: missing required fields');
        }

      } catch (e) {
        _log('Error processing menu item $i: $e');
        // Continue processing other items
      }
    }

    return processedItems;
  }

  /// Process and validate menu item in one step - Optimized
  static bool _processAndValidateMenuItem(Map<String, dynamic> item) {
    try {
      // Normalize and validate in one pass
      _normalizeMenuItemData(item);

      if (!_validateMenuItemData(item)) {
        return false;
      }

      // Process images
      _processMenuItemImages(item);

      return true;
    } catch (e) {
      _log('Error processing/validating menu item: $e');
      return false;
    }
  }

  /// Unified menu item data processing - Optimized
  static void _processMenuItemData(Map<String, dynamic> item) {
    _normalizeMenuItemData(item);
    _processMenuItemImages(item);
  }

  /// Normalize menu item data structure - Optimized
  static void _normalizeMenuItemData(Map<String, dynamic> item) {
    try {
      // Batch normalize numeric fields
      _normalizePrice(item);
      _normalizeBoolean(item);
      _normalizeStringFields(item);
      _normalizeImageUrl(item);

    } catch (e) {
      _log('Error normalizing menu item data: $e');
    }
  }

  /// Normalize price field - Optimized
  static void _normalizePrice(Map<String, dynamic> item) {
    final price = item['price'];
    if (price == null) {
      item['price'] = 0.0;
    } else if (price is String) {
      item['price'] = double.tryParse(price) ?? 0.0;
    } else if (price is int) {
      item['price'] = price.toDouble();
    }
  }

  /// Normalize boolean field - Optimized
  static void _normalizeBoolean(Map<String, dynamic> item) {
    final isAvailable = item['is_available'];
    if (isAvailable == null) {
      item['is_available'] = true;
    } else if (isAvailable is String) {
      item['is_available'] = isAvailable.toLowerCase() == 'true';
    } else if (isAvailable is int) {
      item['is_available'] = isAvailable == 1;
    }
  }

  /// Normalize string fields - Optimized
  static void _normalizeStringFields(Map<String, dynamic> item) {
    const stringFields = ['id', 'name', 'description', 'category', 'store_id'];

    for (final field in stringFields) {
      item[field] = item[field]?.toString() ?? '';
    }
  }

  /// Normalize image URL - Optimized
  static void _normalizeImageUrl(Map<String, dynamic> item) {
    final imageUrl = item['image_url'];
    if (imageUrl == null || imageUrl.toString().isEmpty) {
      item['image_url'] = null;
    }
  }

  /// Process menu item images - Optimized
  static void _processMenuItemImages(Map<String, dynamic> menuItem) {
    try {
      // Process menu item image
      final imageUrl = menuItem['image_url'];
      if (imageUrl != null && imageUrl.toString().isNotEmpty) {
        final originalUrl = imageUrl.toString();
        final processedUrl = ImageService.getImageUrl(originalUrl);
        menuItem['image_url'] = processedUrl;
        _log('Processed image URL: $originalUrl -> $processedUrl');
      }

      // Process store image if included
      final store = menuItem['store'];
      if (store is Map<String, dynamic>) {
        final storeImageUrl = store['image_url'];
        if (storeImageUrl != null) {
          final originalUrl = storeImageUrl.toString();
          final processedUrl = ImageService.getImageUrl(originalUrl);
          store['image_url'] = processedUrl;
          _log('Processed store image URL: $originalUrl -> $processedUrl');
        }
      }
    } catch (e) {
      _log('Error processing menu item images: $e');
    }
  }

  /// Validate menu item data - Optimized with const array
  static bool _validateMenuItemData(Map<String, dynamic> item) {
    const requiredFields = ['id', 'name', 'price', 'store_id'];

    for (final field in requiredFields) {
      final value = item[field];
      if (value == null || value.toString().isEmpty) {
        _log('Missing or empty required field: $field');
        return false;
      }
    }

    // Validate price is numeric
    if (item['price'] is! num) {
      _log('Invalid price format: ${item['price']}');
      return false;
    }

    return true;
  }

  /// Debug method - Only active when debug mode is on
  static void debugMenuItemData(Map<String, dynamic> item) {
    if (!_debugMode) return;

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
}