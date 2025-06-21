// lib/services/store_service.dart
import 'package:flutter/foundation.dart';
import 'core/base_service.dart';
import 'image_service.dart';

class StoreService extends BaseService {

  // Get all stores with pagination and filtering
  static Future<Map<String, dynamic>> getAllStores({
    int page = 1,
    int limit = 10,
    String? search,
    String? category,
    bool? isOpen,
    double? latitude,
    double? longitude,
    double? radius,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (search != null) queryParams['search'] = search;
      if (category != null) queryParams['category'] = category;
      if (isOpen != null) queryParams['isOpen'] = isOpen.toString();
      if (latitude != null) queryParams['latitude'] = latitude.toString();
      if (longitude != null) queryParams['longitude'] = longitude.toString();
      if (radius != null) queryParams['radius'] = radius.toString();

      final response = await BaseService.get('/stores', queryParams: queryParams);

      if (response['data'] != null && response['data'] is List) {
        for (var store in response['data']) {
          _processStoreImages(store);
        }
      }

      return response;
    } catch (e) {
      debugPrint('Get all stores error: $e');
      rethrow;
    }
  }

  // Get store by ID
  static Future<Map<String, dynamic>> getStoreById(String storeId) async {
    try {
      final response = await BaseService.get('/stores/$storeId');

      if (response['data'] != null) {
        _processStoreImages(response['data']);
      }

      return response['data'] ?? {};
    } catch (e) {
      debugPrint('Get store by ID error: $e');
      rethrow;
    }
  }

  // Create new store
  static Future<Map<String, dynamic>> createStore(Map<String, dynamic> storeData) async {
    try {
      final response = await BaseService.post('/stores', storeData);

      if (response['data'] != null) {
        _processStoreImages(response['data']);
      }

      return response['data'] ?? {};
    } catch (e) {
      debugPrint('Create store error: $e');
      rethrow;
    }
  }

  // Update store
  static Future<Map<String, dynamic>> updateStore(String storeId, Map<String, dynamic> storeData) async {
    try {
      final response = await BaseService.put('/stores/$storeId', storeData);

      if (response['data'] != null) {
        _processStoreImages(response['data']);
      }

      return response['data'] ?? {};
    } catch (e) {
      debugPrint('Update store error: $e');
      rethrow;
    }
  }

  // Delete store
  static Future<bool> deleteStore(String storeId) async {
    try {
      await BaseService.delete('/stores/$storeId');
      return true;
    } catch (e) {
      debugPrint('Delete store error: $e');
      rethrow;
    }
  }

  // Get current store profile (for store owners)
  static Future<Map<String, dynamic>> getCurrentStoreProfile() async {
    try {
      final response = await BaseService.get('/stores/profile');

      if (response['data'] != null) {
        _processStoreImages(response['data']);
      }

      return response['data'] ?? {};
    } catch (e) {
      debugPrint('Get current store profile error: $e');
      rethrow;
    }
  }

  // Update current store profile (for store owners)
  static Future<Map<String, dynamic>> updateCurrentStoreProfile(Map<String, dynamic> storeData) async {
    try {
      final response = await BaseService.put('/stores/profile', storeData);

      if (response['data'] != null) {
        _processStoreImages(response['data']);
      }

      return response['data'] ?? {};
    } catch (e) {
      debugPrint('Update current store profile error: $e');
      rethrow;
    }
  }

  // Get store statistics (for store owners)
  static Future<Map<String, dynamic>> getStoreStatistics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (startDate != null) queryParams['startDate'] = startDate.toIso8601String();
      if (endDate != null) queryParams['endDate'] = endDate.toIso8601String();

      final response = await BaseService.get('/stores/statistics', queryParams: queryParams);
      return response['data'] ?? {};
    } catch (e) {
      debugPrint('Get store statistics error: $e');
      rethrow;
    }
  }

  // Get store menu items
  static Future<Map<String, dynamic>> getStoreMenuItems(String storeId, {
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

      final response = await BaseService.get('/stores/$storeId/menu', queryParams: queryParams);

      if (response['data'] != null && response['data'] is List) {
        for (var menuItem in response['data']) {
          _processMenuItemImages(menuItem);
        }
      }

      return response;
    } catch (e) {
      debugPrint('Get store menu items error: $e');
      rethrow;
    }
  }

  // Get nearby stores
  static Future<List<Map<String, dynamic>>> getNearbyStores(
      double latitude,
      double longitude, {
        double radius = 5.0,
        int limit = 20,
      }) async {
    try {
      final queryParams = {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'radius': radius.toString(),
        'limit': limit.toString(),
      };

      final response = await BaseService.get('/stores/nearby', queryParams: queryParams);

      if (response['data'] != null && response['data'] is List) {
        for (var store in response['data']) {
          _processStoreImages(store);
        }
        return List<Map<String, dynamic>>.from(response['data']);
      }

      return [];
    } catch (e) {
      debugPrint('Get nearby stores error: $e');
      rethrow;
    }
  }

  // PRIVATE HELPER METHODS

  static void _processStoreImages(Map<String, dynamic> storeData) {
    try {
      if (storeData['imageUrl'] != null) {
        storeData['imageUrl'] = ImageService.getImageUrl(storeData['imageUrl']);
      }

      if (storeData['bannerImage'] != null) {
        storeData['bannerImage'] = ImageService.getImageUrl(storeData['bannerImage']);
      }

      if (storeData['logoUrl'] != null) {
        storeData['logoUrl'] = ImageService.getImageUrl(storeData['logoUrl']);
      }
    } catch (e) {
      debugPrint('Process store images error: $e');
    }
  }

  static void _processMenuItemImages(Map<String, dynamic> menuItemData) {
    try {
      if (menuItemData['imageUrl'] != null) {
        menuItemData['imageUrl'] = ImageService.getImageUrl(menuItemData['imageUrl']);
      }
    } catch (e) {
      debugPrint('Process menu item images error: $e');
    }
  }
}