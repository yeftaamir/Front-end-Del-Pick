// lib/Services/driver_service.dart
import 'dart:convert';
import 'core/base_service.dart';
import 'image_service.dart';

class DriverService {
  static const String _baseEndpoint = '/drivers';

  /// Get all drivers (admin only)
  static Future<Map<String, dynamic>> getAllDrivers({
    int page = 1,
    int limit = 10,
    String? sortBy,
    String? sortOrder,
    String? status,
    String? search,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (sortBy != null) 'sortBy': sortBy,
        if (sortOrder != null) 'sortOrder': sortOrder,
        if (status != null) 'status': status,
        if (search != null) 'search': search,
      };

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: _baseEndpoint,
        queryParams: queryParams,
        requiresAuth: true,
      );

      // Process driver images from the correct data structure
      if (response['data'] != null && response['data'] is List) {
        for (var driver in response['data']) {
          _processDriverImages(driver);
        }
      }

      return {
        'drivers': response['data'] ?? [],
        'totalItems': response['totalItems'] ?? 0,
        'totalPages': response['totalPages'] ?? 0,
        'currentPage': response['currentPage'] ?? 1,
      };
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
        final driverData = response['data'];
        _processDriverImages(driverData);
        return driverData;
      }

      return {};
    } catch (e) {
      print('Get driver by ID error: $e');
      throw Exception('Failed to get driver: $e');
    }
  }

  /// Create new driver (admin only)
  static Future<Map<String, dynamic>> createDriver({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String licenseNumber,
    required String vehiclePlate,
    String? avatar,
    String status = 'active',
  }) async {
    try {
      final body = {
        'name': name,
        'email': email,
        'password': password,
        'phone': phone,
        'license_number': licenseNumber,
        'vehicle_plate': vehiclePlate,
        'status': status,
        if (avatar != null) 'avatar': avatar,
      };

      final response = await BaseService.apiCall(
        method: 'POST',
        endpoint: _baseEndpoint,
        body: body,
        requiresAuth: true,
      );

      if (response['data'] != null) {
        final createdData = response['data'];
        if (createdData['driver'] != null) {
          _processDriverImages(createdData['driver']);
        }
        return createdData;
      }

      return {};
    } catch (e) {
      print('Create driver error: $e');
      throw Exception('Failed to create driver: $e');
    }
  }

  /// Update driver profile (admin only)
  static Future<Map<String, dynamic>> updateDriverProfile({
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
        final updatedData = response['data'];
        if (updatedData['driver'] != null) {
          _processDriverImages(updatedData['driver']);
        }
        return updatedData;
      }

      return {};
    } catch (e) {
      print('Update driver profile error: $e');
      throw Exception('Failed to update driver profile: $e');
    }
  }

  /// Delete driver (admin only)
  static Future<bool> deleteDriver(String driverId) async {
    try {
      await BaseService.apiCall(
        method: 'DELETE',
        endpoint: '$_baseEndpoint/$driverId',
        requiresAuth: true,
      );
      return true;
    } catch (e) {
      print('Delete driver error: $e');
      return false;
    }
  }

  /// Update driver status (admin only) - FIXED LOGIC
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

  /// Update driver location (driver only)
  static Future<Map<String, dynamic>> updateDriverLocation({
    required String driverId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      // Validate coordinates
      if (latitude < -90 || latitude > 90) {
        throw Exception('Invalid latitude. Must be between -90 and 90');
      }
      if (longitude < -180 || longitude > 180) {
        throw Exception('Invalid longitude. Must be between -180 and 180');
      }

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

  /// Get driver location by ID
  static Future<Map<String, dynamic>> getDriverLocation(String driverId) async {
    try {
      final driver = await getDriverById(driverId);

      return {
        'latitude': driver['latitude'],
        'longitude': driver['longitude'],
        'status': driver['status'],
        'last_updated': driver['updated_at'],
      };
    } catch (e) {
      print('Get driver location error: $e');
      throw Exception('Failed to get driver location: $e');
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

      return response['data'] ?? {
        'orders': [],
        'totalItems': 0,
        'totalPages': 0,
        'currentPage': 1,
      };
    } catch (e) {
      print('Get driver orders error: $e');
      throw Exception('Failed to get driver orders: $e');
    }
  }

  /// Helper method to process driver images
  static void _processDriverImages(Map<String, dynamic> driver) {
    try {
      // Process user avatar if nested in user object
      if (driver['user'] != null && driver['user']['avatar'] != null && driver['user']['avatar'].toString().isNotEmpty) {
        driver['user']['avatar'] = ImageService.getImageUrl(driver['user']['avatar']);
      }

      // Process direct avatar if present
      if (driver['avatar'] != null && driver['avatar'].toString().isNotEmpty) {
        driver['avatar'] = ImageService.getImageUrl(driver['avatar']);
      }
    } catch (e) {
      print('Error processing driver images: $e');
    }
  }
}