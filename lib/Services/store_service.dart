// lib/Services/store_service.dart
import 'dart:convert';
import 'auth_service.dart';
import 'core/base_service.dart';
import 'image_service.dart';

class StoreService {
  static const String _baseEndpoint = '/stores';
  static const bool _debugMode = false; // Toggle for development debugging

  static void _log(String message) {
    if (_debugMode) print(message);
  }

  /// Get all stores - Optimized version
  static Future<Map<String, dynamic>> getAllStores({
    int page = 1,
    int limit = 10,
    String? sortBy,
    String? sortOrder,
    String? search,
    String? status,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (sortBy != null) 'sortBy': sortBy,
        if (sortOrder != null) 'sortOrder': sortOrder,
        if (search != null) 'search': search,
        if (status != null) 'status': status,
      };

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: _baseEndpoint,
        queryParams: queryParams,
        requiresAuth: true,
      );

      // Batch process store images
      if (response['data'] != null && response['data'] is List) {
        final stores = response['data'] as List;
        for (var store in stores) {
          _processStoreData(store);
        }
      }

      return {
        'stores': response['data'] ?? [],
        'totalItems': response['totalItems'] ?? 0,
        'totalPages': response['totalPages'] ?? 0,
        'currentPage': response['currentPage'] ?? 1,
      };
    } catch (e) {
      _log('Get all stores error: $e');
      throw Exception('Failed to get stores: $e');
    }
  }

  /// Get store by ID - Optimized version
  static Future<Map<String, dynamic>> getStoreById(String storeId) async {
    try {
      _log('Getting store details for ID: $storeId');

      // Batch validate user access
      final validationResults = await Future.wait([
        AuthService.getRoleSpecificData(),
        AuthService.getUserRole(),
      ]);

      final userData = validationResults[0] as Map<String, dynamic>?;
      final userRole = validationResults[1] as String?;

      if (userData == null) {
        throw Exception('User not authenticated');
      }

      if (userRole?.toLowerCase() != 'customer') {
        _log('Non-customer access detected, allowing but logging');
      }

      _log('User access validated');

      // Validate storeId
      final parsedStoreId = int.tryParse(storeId);
      if (parsedStoreId == null || parsedStoreId <= 0) {
        throw Exception('Invalid store ID: $storeId');
      }

      _log('Making API call for store $storeId');

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/$storeId',
        requiresAuth: true,
      );

      _log('Raw API response structure: ${response.keys.toList()}');

      if (response['data'] != null) {
        final storeData = Map<String, dynamic>.from(response['data']);

        _log('Store data fields: ${storeData.keys.toList()}');

        // Process store data efficiently
        _processStoreData(storeData);

        _log('Successfully processed store data for: ${storeData['name']}');

        return {
          'success': true,
          'data': storeData,
          'message': 'Store details loaded successfully',
        };
      } else {
        _log('No data in response');
        _log('Full response: $response');

        return {
          'success': false,
          'data': {},
          'error': 'Store not found or no data received from server',
        };
      }
    } catch (e) {
      _log('Get store by ID error: $e');

      return {
        'success': false,
        'data': {},
        'error': e.toString(),
      };
    }
  }

  /// Create new store - Optimized
  static Future<Map<String, dynamic>> createStore({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String address,
    required String openTime,
    required String closeTime,
    required double latitude,
    required double longitude,
    String? description,
    String? image,
    String status = 'active',
  }) async {
    try {
      final body = {
        'name': name,
        'email': email,
        'password': password,
        'phone': phone,
        'address': address,
        'open_time': openTime,
        'close_time': closeTime,
        'latitude': latitude,
        'longitude': longitude,
        'status': status,
        if (description != null) 'description': description,
        if (image != null) 'image': image,
      };

      final response = await BaseService.apiCall(
        method: 'POST',
        endpoint: _baseEndpoint,
        body: body,
        requiresAuth: true,
      );

      if (response['data'] != null) {
        final createdData = response['data'];
        if (createdData['store'] != null) {
          _processStoreImages(createdData['store']);
        }
        return createdData;
      }

      return {};
    } catch (e) {
      _log('Create store error: $e');
      throw Exception('Failed to create store: $e');
    }
  }

  /// Update store profile - Optimized
  static Future<Map<String, dynamic>> updateStoreProfile({
    required String storeId,
    required Map<String, dynamic> updateData,
  }) async {
    try {
      final response = await BaseService.apiCall(
        method: 'PUT',
        endpoint: '$_baseEndpoint/$storeId',
        body: updateData,
        requiresAuth: true,
      );

      if (response['data'] != null) {
        final updatedData = response['data'];
        if (updatedData['store'] != null) {
          _processStoreImages(updatedData['store']);
        }
        return updatedData;
      }

      return {};
    } catch (e) {
      _log('Update store profile error: $e');
      throw Exception('Failed to update store profile: $e');
    }
  }

  /// Delete store - Optimized
  static Future<bool> deleteStore(String storeId) async {
    try {
      await BaseService.apiCall(
        method: 'DELETE',
        endpoint: '$_baseEndpoint/$storeId',
        requiresAuth: true,
      );
      return true;
    } catch (e) {
      _log('Delete store error: $e');
      return false;
    }
  }

  /// Get store orders - Optimized
  static Future<Map<String, dynamic>> getStoreOrders({
    int page = 1,
    int limit = 10,
    String? status,
    String? sortBy,
    String? sortOrder,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (status != null) 'status': status,
        if (sortBy != null) 'sortBy': sortBy,
        if (sortOrder != null) 'sortOrder': sortOrder,
      };

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '/orders/store',
        queryParams: queryParams,
        requiresAuth: true,
      );

      return response['data'] ??
          {
            'orders': [],
            'totalItems': 0,
            'totalPages': 0,
            'currentPage': 1,
          };
    } catch (e) {
      _log('Get store orders error: $e');
      throw Exception('Failed to get store orders: $e');
    }
  }

  /// Search stores - Optimized
  static Future<List<Map<String, dynamic>>> searchStores({
    required String query,
    String? category,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await getAllStores(
        search: query,
        page: page,
        limit: limit,
      );

      return List<Map<String, dynamic>>.from(response['stores'] ?? []);
    } catch (e) {
      _log('Search stores error: $e');
      throw Exception('Failed to search stores: $e');
    }
  }

  /// Get store statistics - Optimized
  static Future<Map<String, dynamic>> getStoreStatistics(String storeId) async {
    try {
      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/$storeId/statistics',
        requiresAuth: true,
      );

      return response['data'] ?? {};
    } catch (e) {
      _log('Get store statistics error: $e');
      throw Exception('Failed to get store statistics: $e');
    }
  }

  /// Update store status - Optimized
  static Future<Map<String, dynamic>> updateStoreStatus({
    required String storeId,
    required String status,
  }) async {
    try {
      if (!['active', 'inactive'].contains(status)) {
        throw Exception('Invalid status. Must be "active" or "inactive"');
      }

      _log('Updating store $storeId status to $status');

      final response = await BaseService.apiCall(
        method: 'PATCH',
        endpoint: '$_baseEndpoint/$storeId/status',
        body: {'status': status},
        requiresAuth: true,
      );

      _log('Store status updated successfully');

      return response['data'] ?? {};
    } catch (e) {
      _log('Update store status error: $e');
      throw Exception('Failed to update store status: $e');
    }
  }

  /// Get nearby stores - Optimized
  static Future<List<Map<String, dynamic>>> getNearbyStores({
    required double latitude,
    required double longitude,
    double maxDistance = 10.0,
    int limit = 20,
  }) async {
    try {
      final queryParams = {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'maxDistance': maxDistance.toString(),
        'limit': limit.toString(),
      };

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/nearby',
        queryParams: queryParams,
        requiresAuth: true,
      );

      final stores = List<Map<String, dynamic>>.from(response['data'] ?? []);
      for (var store in stores) {
        _processStoreData(store);
      }

      return stores;
    } catch (e) {
      _log('Get nearby stores error: $e');
      return [];
    }
  }

  // PRIVATE HELPER METHODS - OPTIMIZED

  /// Unified store data processing - Optimized
  static void _processStoreData(Map<String, dynamic> storeData) {
    _validateAndProcessStoreData(storeData);
    _processStoreImages(storeData);
  }

  /// Validate and process store data - Optimized
  static void _validateAndProcessStoreData(Map<String, dynamic> storeData) {
    try {
      _log('Validating store data...');

      // Handle nested store structure efficiently
      _handleNestedStoreStructure(storeData);

      // Batch set required fields with defaults
      _setStoreDefaults(storeData);

      // Process numeric fields efficiently
      _processNumericFields(storeData);

      // Process other fields
      _processOtherFields(storeData);

      _log('Store data validated successfully');
      _log(
          'Store ID: ${storeData['id']}, Name: ${storeData['name']}, Rating: ${storeData['rating']}');
    } catch (e) {
      _log('Error validating store data: $e');
    }
  }

  /// Handle nested store structure - Optimized
  static void _handleNestedStoreStructure(Map<String, dynamic> storeData) {
    if (storeData.containsKey('store')) {
      final actualStoreData = storeData['store'];

      // Copy owner data if present
      if (storeData.containsKey('owner')) {
        actualStoreData['owner'] = storeData['owner'];
      }

      // Replace root data with nested store data
      storeData.clear();
      storeData.addAll(actualStoreData);
    }
  }

  /// Set store default values - Optimized
  static void _setStoreDefaults(Map<String, dynamic> storeData) {
    const stringDefaults = {
      'name': 'Unknown Store',
      'address': 'No address provided',
      'description': '',
      'phone': '',
      'open_time': '08:00',
      'close_time': '22:00',
      'status': 'active',
    };

    const numericDefaults = {
      'id': 0,
      'rating': 0.0,
      'review_count': 0,
      'total_products': 0,
    };

    // Batch set string defaults
    for (final entry in stringDefaults.entries) {
      storeData[entry.key] ??= entry.value;
    }

    // Batch set numeric defaults
    for (final entry in numericDefaults.entries) {
      storeData[entry.key] ??= entry.value;
    }
  }

  /// Process numeric fields - Optimized
  static void _processNumericFields(Map<String, dynamic> storeData) {
    // Process rating
    _processNumericField(storeData, 'rating', 0.0);

    // Process coordinates
    _processNumericField(storeData, 'latitude', null);
    _processNumericField(storeData, 'longitude', null);
  }

  /// Process individual numeric field - Optimized
  static void _processNumericField(
      Map<String, dynamic> data, String field, double? defaultValue) {
    final value = data[field];
    if (value != null) {
      if (value is String) {
        data[field] = double.tryParse(value) ?? defaultValue;
      } else if (value is int) {
        data[field] = value.toDouble();
      }
    } else if (defaultValue != null) {
      data[field] = defaultValue;
    }
  }

  /// Process other fields - Optimized
  static void _processOtherFields(Map<String, dynamic> storeData) {
    // Ensure integer fields are properly typed
    const intFields = ['review_count', 'total_products'];

    for (final field in intFields) {
      final value = storeData[field];
      if (value is String) {
        storeData[field] = int.tryParse(value) ?? 0;
      } else if (value is double) {
        storeData[field] = value.toInt();
      }
    }
  }

  /// Process store images - Optimized
  static void _processStoreImages(Map<String, dynamic> store) {
    try {
      // Process store image_url
      final imageUrl = store['image_url'];
      if (imageUrl != null && imageUrl.toString().isNotEmpty) {
        final originalUrl = imageUrl.toString();
        final processedUrl = ImageService.getImageUrl(originalUrl);
        store['image_url'] = processedUrl;
        _log('Processed store image URL: $originalUrl -> $processedUrl');
      }

      // Process owner avatar if present
      final owner = store['owner'];
      if (owner is Map<String, dynamic>) {
        final avatar = owner['avatar'];
        if (avatar != null && avatar.toString().isNotEmpty) {
          final originalUrl = avatar.toString();
          final processedUrl = ImageService.getImageUrl(originalUrl);
          owner['avatar'] = processedUrl;
          _log('Processed owner avatar URL: $originalUrl -> $processedUrl');
        }
      }
    } catch (e) {
      _log('Error processing store images: $e');
    }
  }

  /// Validate store data structure - Optimized
  static bool validateStoreData(Map<String, dynamic> store) {
    const requiredFields = ['id', 'name', 'address'];

    for (final field in requiredFields) {
      final value = store[field];
      if (value == null || value.toString().isEmpty) {
        _log('Missing or empty required field: $field');
        return false;
      }
    }

    // Validate numeric fields efficiently
    final numericValidations = [
      ('rating', store['rating']),
      ('latitude', store['latitude']),
      ('longitude', store['longitude']),
    ];

    for (final validation in numericValidations) {
      final field = validation.$1;
      final value = validation.$2;

      if (value != null && value is! num && value is! String) {
        _log('Invalid $field format: $value');
        return false;
      }
    }

    return true;
  }

  /// Debug method - Only active when debug mode is on
  static void debugStoreData(Map<String, dynamic> store) {
    if (!_debugMode) return;

    print('🔍 ====== STORE DEBUG ======');
    print('🏪 Store ID: ${store['id']} (${store['id']?.runtimeType})');
    print('🏪 Store Name: ${store['name']} (${store['name']?.runtimeType})');
    print('📍 Address: ${store['address']} (${store['address']?.runtimeType})');
    print('⭐ Rating: ${store['rating']} (${store['rating']?.runtimeType})');
    print('📞 Phone: ${store['phone']} (${store['phone']?.runtimeType})');
    print(
        '🕐 Open Time: ${store['open_time']} (${store['open_time']?.runtimeType})');
    print(
        '🕐 Close Time: ${store['close_time']} (${store['close_time']?.runtimeType})');
    print(
        '🌍 Latitude: ${store['latitude']} (${store['latitude']?.runtimeType})');
    print(
        '🌍 Longitude: ${store['longitude']} (${store['longitude']?.runtimeType})');
    print(
        '🖼️ Image URL: ${store['image_url']} (${store['image_url']?.runtimeType})');
    print(
        '📝 Description: ${store['description']} (${store['description']?.runtimeType})');
    print('📊 Status: ${store['status']} (${store['status']?.runtimeType})');
    print('🔍 ====== END DEBUG ======');
  }
}
