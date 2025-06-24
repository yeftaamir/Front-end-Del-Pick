// lib/Services/store_service.dart
import 'dart:convert';
import 'auth_service.dart';
import 'core/base_service.dart';
import 'image_service.dart';

class StoreService {
  static const String _baseEndpoint = '/stores';

  /// Get all stores (public endpoint)
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

      // Process store images from the correct data structure
      if (response['data'] != null && response['data'] is List) {
        for (var store in response['data']) {
          _processStoreImages(store);
        }
      }

      return {
        'stores': response['data'] ?? [],
        'totalItems': response['totalItems'] ?? 0,
        'totalPages': response['totalPages'] ?? 0,
        'currentPage': response['currentPage'] ?? 1,
      };
    } catch (e) {
      print('❌ Get all stores error: $e');
      throw Exception('Failed to get stores: $e');
    }
  }

  /// Get store by ID with enhanced error handling and customer access validation
  static Future<Map<String, dynamic>> getStoreById(String storeId) async {
    try {
      print('🏪 StoreService: Getting store details for ID: $storeId');

      // Validate customer access
      final userData = await AuthService.getRoleSpecificData();
      if (userData == null) {
        throw Exception('User not authenticated');
      }

      final userRole = await AuthService.getUserRole();
      if (userRole?.toLowerCase() != 'customer') {
        print('⚠️ StoreService: Non-customer access detected, allowing but logging');
      }

      print('✅ StoreService: User access validated');

      // Validate storeId
      final parsedStoreId = int.tryParse(storeId);
      if (parsedStoreId == null || parsedStoreId <= 0) {
        throw Exception('Invalid store ID: $storeId');
      }

      print('🏪 StoreService: Making API call for store $storeId');

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/$storeId',
        requiresAuth: true,
      );

      print('🏪 StoreService: Raw API response structure: ${response.keys.toList()}');

      if (response['data'] != null) {
        final storeData = Map<String, dynamic>.from(response['data']);

        print('🏪 StoreService: Store data fields: ${storeData.keys.toList()}');

        // Process store data to ensure proper formatting
        _validateAndProcessStoreData(storeData);

        // Process store images
        _processStoreImages(storeData);

        print('✅ StoreService: Successfully processed store data for: ${storeData['name']}');

        return {
          'success': true,
          'data': storeData,
          'message': 'Store details loaded successfully',
        };
      } else {
        print('❌ StoreService: No data in response');
        print('❌ Full response: $response');

        return {
          'success': false,
          'data': {},
          'error': 'Store not found or no data received from server',
        };
      }
    } catch (e) {
      print('❌ StoreService: Get store by ID error: $e');

      // Return structured error response
      return {
        'success': false,
        'data': {},
        'error': e.toString(),
      };
    }
  }

  /// Create new store (admin only)
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
      print('❌ Create store error: $e');
      throw Exception('Failed to create store: $e');
    }
  }

  /// Update store profile (admin only)
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
      print('❌ Update store profile error: $e');
      throw Exception('Failed to update store profile: $e');
    }
  }

  /// Delete store (admin only)
  static Future<bool> deleteStore(String storeId) async {
    try {
      await BaseService.apiCall(
        method: 'DELETE',
        endpoint: '$_baseEndpoint/$storeId',
        requiresAuth: true,
      );
      return true;
    } catch (e) {
      print('❌ Delete store error: $e');
      return false;
    }
  }

  /// Get store orders (for store owners)
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

      return response['data'] ?? {
        'orders': [],
        'totalItems': 0,
        'totalPages': 0,
        'currentPage': 1,
      };
    } catch (e) {
      print('❌ Get store orders error: $e');
      throw Exception('Failed to get store orders: $e');
    }
  }

  /// Search stores by name or category
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
      print('❌ Search stores error: $e');
      throw Exception('Failed to search stores: $e');
    }
  }

  /// Validate and process store data to ensure proper formatting
  static void _validateAndProcessStoreData(Map<String, dynamic> storeData) {
    try {
      print('🔍 StoreService: Validating store data...');

      // Handle nested store structure
      Map<String, dynamic> actualStoreData;
      if (storeData.containsKey('store')) {
        actualStoreData = storeData['store'];
        // Copy owner data to root level for easier access
        if (storeData.containsKey('owner')) {
          actualStoreData['owner'] = storeData['owner'];
        }
        // Replace root data with nested store data
        storeData.clear();
        storeData.addAll(actualStoreData);
      }

      // Ensure required fields have default values
      storeData['id'] = storeData['id'] ?? 0;
      storeData['name'] = storeData['name'] ?? 'Unknown Store';
      storeData['address'] = storeData['address'] ?? 'No address provided';
      storeData['description'] = storeData['description'] ?? '';
      storeData['phone'] = storeData['phone'] ?? '';
      storeData['open_time'] = storeData['open_time'] ?? '08:00';
      storeData['close_time'] = storeData['close_time'] ?? '22:00';

      // Ensure numeric fields are properly typed
      if (storeData['rating'] != null) {
        if (storeData['rating'] is String) {
          storeData['rating'] = double.tryParse(storeData['rating']) ?? 0.0;
        } else if (storeData['rating'] is int) {
          storeData['rating'] = storeData['rating'].toDouble();
        }
      } else {
        storeData['rating'] = 0.0;
      }

      if (storeData['latitude'] != null) {
        if (storeData['latitude'] is String) {
          storeData['latitude'] = double.tryParse(storeData['latitude']);
        } else if (storeData['latitude'] is int) {
          storeData['latitude'] = storeData['latitude'].toDouble();
        }
      }

      if (storeData['longitude'] != null) {
        if (storeData['longitude'] is String) {
          storeData['longitude'] = double.tryParse(storeData['longitude']);
        } else if (storeData['longitude'] is int) {
          storeData['longitude'] = storeData['longitude'].toDouble();
        }
      }

      // Ensure integer fields are properly typed
      storeData['review_count'] = storeData['review_count'] ?? 0;
      storeData['total_products'] = storeData['total_products'] ?? 0;

      // Ensure status is set
      storeData['status'] = storeData['status'] ?? 'active';

      print('✅ StoreService: Store data validated successfully');
      print('   - Store ID: ${storeData['id']}');
      print('   - Store Name: ${storeData['name']}');
      print('   - Rating: ${storeData['rating']}');
      print('   - Location: ${storeData['latitude']}, ${storeData['longitude']}');

    } catch (e) {
      print('❌ StoreService: Error validating store data: $e');
    }
  }

  /// Helper method to process store images
  static void _processStoreImages(Map<String, dynamic> store) {
    try {
      // Process store image_url
      if (store['image_url'] != null && store['image_url'].toString().isNotEmpty) {
        final originalUrl = store['image_url'].toString();
        final processedUrl = ImageService.getImageUrl(originalUrl);
        store['image_url'] = processedUrl;
        print('🖼️ Processed store image URL: $originalUrl -> $processedUrl');
      }

      // Process owner avatar if present
      if (store['owner'] != null && store['owner']['avatar'] != null && store['owner']['avatar'].toString().isNotEmpty) {
        final originalUrl = store['owner']['avatar'].toString();
        final processedUrl = ImageService.getImageUrl(originalUrl);
        store['owner']['avatar'] = processedUrl;
        print('👤 Processed owner avatar URL: $originalUrl -> $processedUrl');
      }
    } catch (e) {
      print('❌ Error processing store images: $e');
    }
  }

  /// Debug method to inspect store data structure
  static void debugStoreData(Map<String, dynamic> store) {
    print('🔍 ====== STORE DEBUG ======');
    print('🏪 Store ID: ${store['id']} (${store['id']?.runtimeType})');
    print('🏪 Store Name: ${store['name']} (${store['name']?.runtimeType})');
    print('📍 Address: ${store['address']} (${store['address']?.runtimeType})');
    print('⭐ Rating: ${store['rating']} (${store['rating']?.runtimeType})');
    print('📞 Phone: ${store['phone']} (${store['phone']?.runtimeType})');
    print('🕐 Open Time: ${store['open_time']} (${store['open_time']?.runtimeType})');
    print('🕐 Close Time: ${store['close_time']} (${store['close_time']?.runtimeType})');
    print('🌍 Latitude: ${store['latitude']} (${store['latitude']?.runtimeType})');
    print('🌍 Longitude: ${store['longitude']} (${store['longitude']?.runtimeType})');
    print('🖼️ Image URL: ${store['image_url']} (${store['image_url']?.runtimeType})');
    print('📝 Description: ${store['description']} (${store['description']?.runtimeType})');
    print('📊 Status: ${store['status']} (${store['status']?.runtimeType})');
    print('🔍 ====== END DEBUG ======');
  }

  /// Validate store data structure
  static bool validateStoreData(Map<String, dynamic> store) {
    final requiredFields = ['id', 'name', 'address'];

    for (String field in requiredFields) {
      if (store[field] == null || store[field].toString().isEmpty) {
        print('❌ Missing or empty required field: $field');
        return false;
      }
    }

    // Validate numeric fields
    if (store['rating'] != null && store['rating'] is! num && store['rating'] is! String) {
      print('❌ Invalid rating format: ${store['rating']}');
      return false;
    }

    if (store['latitude'] != null && store['latitude'] is! num && store['latitude'] is! String) {
      print('❌ Invalid latitude format: ${store['latitude']}');
      return false;
    }

    if (store['longitude'] != null && store['longitude'] is! num && store['longitude'] is! String) {
      print('❌ Invalid longitude format: ${store['longitude']}');
      return false;
    }

    return true;
  }

  /// Get store statistics (for store owners)
  static Future<Map<String, dynamic>> getStoreStatistics(String storeId) async {
    try {
      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/$storeId/statistics',
        requiresAuth: true,
      );

      return response['data'] ?? {};
    } catch (e) {
      print('❌ Get store statistics error: $e');
      throw Exception('Failed to get store statistics: $e');
    }
  }

  /// Update store status (active/inactive)
  static Future<Map<String, dynamic>> updateStoreStatus({
    required String storeId,
    required String status, // active, inactive
  }) async {
    try {
      if (!['active', 'inactive'].contains(status)) {
        throw Exception('Invalid status. Must be "active" or "inactive"');
      }

      print('🔄 StoreService: Updating store $storeId status to $status');

      final response = await BaseService.apiCall(
        method: 'PATCH',
        endpoint: '$_baseEndpoint/$storeId/status',
        body: {'status': status},
        requiresAuth: true,
      );

      print('✅ StoreService: Store status updated successfully');

      return response['data'] ?? {};
    } catch (e) {
      print('❌ StoreService: Update store status error: $e');
      throw Exception('Failed to update store status: $e');
    }
  }

  /// Get stores near user location
  static Future<List<Map<String, dynamic>>> getNearbyStores({
    required double latitude,
    required double longitude,
    double maxDistance = 10.0, // km
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
        _processStoreImages(store);
      }

      return stores;
    } catch (e) {
      print('❌ Get nearby stores error: $e');
      return [];
    }
  }
}