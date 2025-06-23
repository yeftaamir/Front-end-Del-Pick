// lib/Services/driver_service.dart
import 'dart:convert';
import 'core/base_service.dart';
import 'image_service.dart';

class DriverService {
  static const String _baseEndpoint = '/drivers';

  /// Get all drivers
  static Future<Map<String, dynamic>> getAllDrivers({
    int page = 1,
    int limit = 10,
    String? sortBy,
    String? sortOrder,
    String? status,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (sortBy != null) 'sortBy': sortBy,
        if (sortOrder != null) 'sortOrder': sortOrder,
        if (status != null) 'status': status,
      };

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: _baseEndpoint,
        queryParams: queryParams,
        requiresAuth: true,
      );

      // Process driver images
      if (response['data'] != null && response['data'] is List) {
        for (var driver in response['data']) {
          _processDriverImages(driver);
        }
      }

      return response;
    } catch (e) {
      print('Get all drivers error: $e');
      throw Exception('Failed to get drivers: $e');
    }
  }

  /// Get driver by ID
  static Future<Map<String, dynamic>> getDriverById(String driverId) async {
    try {
      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/$driverId',
        requiresAuth: true,
      );

      if (response['data'] != null) {
        _processDriverImages(response['data']);
      }

      return response['data'] ?? {};
    } catch (e) {
      print('Get driver by ID error: $e');
      throw Exception('Failed to get driver: $e');
    }
  }

  /// Get driver location by ID
  static Future<Map<String, dynamic>> getDriverLocation(String driverId) async {
    try {
      final driver = await getDriverById(driverId);

      return {
        'latitude': driver['driver']?['latitude'],
        'longitude': driver['driver']?['longitude'],
        'status': driver['driver']?['status'],
        'last_updated': driver['driver']?['updated_at'],
      };
    } catch (e) {
      print('Get driver location error: $e');
      throw Exception('Failed to get driver location: $e');
    }
  }

  /// Update driver status (active, inactive, busy)
  static Future<Map<String, dynamic>> updateDriverStatus({
    required String driverId,
    required String status, // active, inactive, busy
  }) async {
    try {
      if (!['active', 'inactive', 'busy'].contains(status)) {
        throw Exception('Invalid status. Must be: active, inactive, or busy');
      }

      final response = await BaseService.apiCall(
        method: 'PATCH',
        endpoint: '$_baseEndpoint/$driverId/status',
        body: {'status': status},
        requiresAuth: true,
      );

      return response['data'] ?? {};
    } catch (e) {
      print('Update driver status error: $e');
      throw Exception('Failed to update driver status: $e');
    }
  }

  /// Update driver profile
  static Future<Map<String, dynamic>> updateProfileDriver({
    required String driverId,
    required Map<String, dynamic> updateData,
  }) async {
    try {
      final response = await BaseService.apiCall(
        method: 'PUT',
        endpoint: '$_baseEndpoint/$driverId',
        body: updateData,
        requiresAuth: true,
      );

      if (response['data'] != null) {
        _processDriverImages(response['data']);
      }

      return response['data'] ?? {};
    } catch (e) {
      print('Update driver profile error: $e');
      throw Exception('Failed to update driver profile: $e');
    }
  }

  /// Get driver orders
  static Future<Map<String, dynamic>> getDriverOrders({
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
        endpoint: '/orders/driver',
        queryParams: queryParams,
        requiresAuth: true,
      );

      return response;
    } catch (e) {
      print('Get driver orders error: $e');
      throw Exception('Failed to get driver orders: $e');
    }
  }

  /// Update driver location
  static Future<Map<String, dynamic>> updateDriverLocation({
    required String driverId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await BaseService.apiCall(
        method: 'PATCH',
        endpoint: '$_baseEndpoint/$driverId/location',
        body: {
          'latitude': latitude,
          'longitude': longitude,
        },
        requiresAuth: true,
      );

      return response['data'] ?? {};
    } catch (e) {
      print('Update driver location error: $e');
      throw Exception('Failed to update driver location: $e');
    }
  }

  /// Helper method to process driver images
  static void _processDriverImages(Map<String, dynamic> driver) {
    // Process user avatar
    if (driver['user'] != null && driver['user']['avatar'] != null) {
      driver['user']['avatar'] = ImageService.getImageUrl(driver['user']['avatar']);
    }

    // If driver data is nested differently
    if (driver['avatar'] != null && driver['avatar'].toString().isNotEmpty) {
      driver['avatar'] = ImageService.getImageUrl(driver['avatar']);
    }
  }
}
