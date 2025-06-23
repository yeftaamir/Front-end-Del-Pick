// lib/Services/store_service.dart
import 'dart:convert';
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
    double? latitude,
    double? longitude,
    double? radius,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (sortBy != null) 'sortBy': sortBy,
        if (sortOrder != null) 'sortOrder': sortOrder,
        if (latitude != null) 'latitude': latitude.toString(),
        if (longitude != null) 'longitude': longitude.toString(),
        if (radius != null) 'radius': radius.toString(),
      };

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: _baseEndpoint,
        queryParams: queryParams,
        requiresAuth: true,
      );

      // Process store images
      if (response['data'] != null && response['data'] is List) {
        for (var store in response['data']) {
          _processStoreImages(store);
        }
      }

      return response;
    } catch (e) {
      print('Get all stores error: $e');
      throw Exception('Failed to get stores: $e');
    }
  }

  /// Get store by ID
  static Future<Map<String, dynamic>> getStoreById(String storeId) async {
    try {
      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/$storeId',
        requiresAuth: true,
      );

      if (response['data'] != null) {
        _processStoreImages(response['data']);
      }

      return response['data'] ?? {};
    } catch (e) {
      print('Get store by ID error: $e');
      throw Exception('Failed to get store: $e');
    }
  }

  /// Update store status (for store owners)
  static Future<Map<String, dynamic>> updateStoreStatus({
    required String storeId,
    required String status, // active, inactive
  }) async {
    try {
      if (!['active', 'inactive'].contains(status)) {
        throw Exception('Invalid status. Must be: active or inactive');
      }

      final response = await BaseService.apiCall(
        method: 'PATCH',
        endpoint: '$_baseEndpoint/$storeId/status',
        body: {'status': status},
        requiresAuth: true,
      );

      return response['data'] ?? {};
    } catch (e) {
      print('Update store status error: $e');
      throw Exception('Failed to update store status: $e');
    }
  }

  /// Update store profile
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
        _processStoreImages(response['data']);
      }

      return response['data'] ?? {};
    } catch (e) {
      print('Update store profile error: $e');
      throw Exception('Failed to update store profile: $e');
    }
  }

  /// Get store orders
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

      return response;
    } catch (e) {
      print('Get store orders error: $e');
      throw Exception('Failed to get store orders: $e');
    }
  }

  /// Get nearby stores based on location
  static Future<List<Map<String, dynamic>>> getNearbyStores({
    required double latitude,
    required double longitude,
    double radius = 10.0, // km
    int limit = 20,
  }) async {
    try {
      final response = await getAllStores(
        latitude: latitude,
        longitude: longitude,
        radius: radius,
        limit: limit,
        sortBy: 'distance',
        sortOrder: 'asc',
      );

      return List<Map<String, dynamic>>.from(response['data'] ?? []);
    } catch (e) {
      print('Get nearby stores error: $e');
      throw Exception('Failed to get nearby stores: $e');
    }
  }

  /// Search stores by name or category
  static Future<List<Map<String, dynamic>>> searchStores({
    required String query,
    String? category,
    double? latitude,
    double? longitude,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final queryParams = {
        'search': query,
        'page': page.toString(),
        'limit': limit.toString(),
        if (category != null) 'category': category,
        if (latitude != null) 'latitude': latitude.toString(),
        if (longitude != null) 'longitude': longitude.toString(),
      };

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: _baseEndpoint,
        queryParams: queryParams,
        requiresAuth: true,
      );

      final stores = List<Map<String, dynamic>>.from(response['data'] ?? []);
      for (var store in stores) {
        _processStoreImages(store);
      }

      return stores;
    } catch (e) {
      print('Search stores error: $e');
      throw Exception('Failed to search stores: $e');
    }
  }

  /// Helper method to process store images
  static void _processStoreImages(Map<String, dynamic> store) {
    // Process store image
    if (store['image_url'] != null && store['image_url'].toString().isNotEmpty) {
      store['image_url'] = ImageService.getImageUrl(store['image_url']);
    }

    // Process owner avatar if present
    if (store['owner'] != null && store['owner']['avatar'] != null) {
      store['owner']['avatar'] = ImageService.getImageUrl(store['owner']['avatar']);
    }
  }
}