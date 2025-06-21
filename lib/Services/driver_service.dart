// lib/services/driver_service.dart
import 'package:flutter/foundation.dart';
import 'core/base_service.dart';
import 'image_service.dart';

class DriverService extends BaseService {

  // Get all drivers with pagination
  static Future<Map<String, dynamic>> getAllDrivers({
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
      };

      if (sortBy != null) queryParams['sortBy'] = sortBy;
      if (sortOrder != null) queryParams['sortOrder'] = sortOrder;
      if (search != null) queryParams['search'] = search;
      if (status != null) queryParams['status'] = status;

      final response = await BaseService.get('/drivers', queryParams: queryParams);

      if (response['data'] != null && response['data'] is List) {
        for (var driver in response['data']) {
          _processDriverImages(driver);
        }
      }

      return response;
    } catch (e) {
      debugPrint('Get all drivers error: $e');
      rethrow;
    }
  }

  // Get driver by ID
  static Future<Map<String, dynamic>> getDriverById(String driverId) async {
    try {
      final response = await BaseService.get('/drivers/$driverId');

      if (response['data'] != null) {
        _processDriverImages(response['data']);
      }

      return response['data'] ?? {};
    } catch (e) {
      debugPrint('Get driver by ID error: $e');
      rethrow;
    }
  }

  // Create new driver
  static Future<Map<String, dynamic>> createDriver(Map<String, dynamic> driverData) async {
    try {
      final response = await BaseService.post('/drivers', driverData);

      if (response['data'] != null) {
        _processDriverImages(response['data']);
      }

      return response['data'] ?? {};
    } catch (e) {
      debugPrint('Create driver error: $e');
      rethrow;
    }
  }

  // Update driver
  static Future<Map<String, dynamic>> updateDriver(String driverId, Map<String, dynamic> driverData) async {
    try {
      final response = await BaseService.put('/drivers/$driverId', driverData);

      if (response['data'] != null) {
        _processDriverImages(response['data']);
      }

      return response['data'] ?? {};
    } catch (e) {
      debugPrint('Update driver error: $e');
      rethrow;
    }
  }

  // Delete driver
  static Future<bool> deleteDriver(String driverId) async {
    try {
      await BaseService.delete('/drivers/$driverId');
      return true;
    } catch (e) {
      debugPrint('Delete driver error: $e');
      rethrow;
    }
  }

  // Get current driver profile
  static Future<Map<String, dynamic>> getCurrentDriverProfile() async {
    try {
      final response = await BaseService.get('/drivers/profile');

      if (response['data'] != null) {
        _processDriverImages(response['data']);
      }

      return response['data'] ?? {};
    } catch (e) {
      debugPrint('Get current driver profile error: $e');
      rethrow;
    }
  }

  // Update current driver profile
  static Future<Map<String, dynamic>> updateCurrentDriverProfile(Map<String, dynamic> driverData) async {
    try {
      final response = await BaseService.put('/drivers/profile', driverData);

      if (response['data'] != null) {
        _processDriverImages(response['data']);
      }

      return response['data'] ?? {};
    } catch (e) {
      debugPrint('Update current driver profile error: $e');
      rethrow;
    }
  }

  // Update driver status
  static Future<Map<String, dynamic>> updateDriverStatus(String status) async {
    try {
      if (!['active', 'inactive', 'busy'].contains(status)) {
        throw ApiException('Status must be "active", "inactive", or "busy"');
      }

      final response = await BaseService.put('/drivers/status', {'status': status});
      return response['data'] ?? {};
    } catch (e) {
      debugPrint('Update driver status error: $e');
      rethrow;
    }
  }

  // Update driver location
  static Future<Map<String, dynamic>> updateDriverLocation(double latitude, double longitude) async {
    try {
      final response = await BaseService.put('/drivers/location', {
        'latitude': latitude,
        'longitude': longitude,
      });

      return response['data'] ?? {};
    } catch (e) {
      debugPrint('Update driver location error: $e');
      rethrow;
    }
  }

  // Get driver location
  static Future<Map<String, dynamic>> getDriverLocation(String driverId) async {
    try {
      final response = await BaseService.get('/drivers/$driverId/location');
      return response['data'] ?? {};
    } catch (e) {
      debugPrint('Get driver location error: $e');
      rethrow;
    }
  }

  // Get driver orders
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
      };

      if (status != null) queryParams['status'] = status;
      if (sortBy != null) queryParams['sortBy'] = sortBy;
      if (sortOrder != null) queryParams['sortOrder'] = sortOrder;

      final response = await BaseService.get('/drivers/orders', queryParams: queryParams);

      if (response['data'] != null) {
        _processOrdersList(response['data']);
      }

      return response;
    } catch (e) {
      debugPrint('Get user orders error: $e');
      rethrow;
    }
  }

  static void _processOrdersList(dynamic data) {
    try {
      List<dynamic> orders = [];

      if (data is List) {
        orders = data;
      } else if (data is Map) {
        if (data['orders'] is List) {
          orders = data['orders'];
        } else if (data['data'] is List) {
          orders = data['data'];
        }
      }

      for (var order in orders) {
        _processOrderData(order);
      }
    } catch (e) {
      debugPrint('Process orders list error: $e');
    }
  }

  static void _processOrderData(Map<String, dynamic> orderData) {
    try {
      // Process store images
      if (orderData['store'] != null) {
        if (orderData['store']['imageUrl'] != null) {
          orderData['store']['imageUrl'] = ImageService.getImageUrl(orderData['store']['imageUrl']);
        }
        if (orderData['store']['logoUrl'] != null) {
          orderData['store']['logoUrl'] = ImageService.getImageUrl(orderData['store']['logoUrl']);
        }
      }

      // Process menu item images
      if (orderData['items'] != null && orderData['items'] is List) {
        for (var item in orderData['items']) {
          if (item['menuItem'] != null && item['menuItem']['imageUrl'] != null) {
            item['menuItem']['imageUrl'] = ImageService.getImageUrl(item['menuItem']['imageUrl']);
          }
          if (item['menu_item'] != null && item['menu_item']['imageUrl'] != null) {
            item['menu_item']['imageUrl'] = ImageService.getImageUrl(item['menu_item']['imageUrl']);
          }
        }
      }

      // Process driver images
      if (orderData['driver'] != null) {
        if (orderData['driver']['user'] != null && orderData['driver']['user']['avatar'] != null) {
          orderData['driver']['user']['avatar'] = ImageService.getImageUrl(orderData['driver']['user']['avatar']);
        }
        if (orderData['driver']['profileImage'] != null) {
          orderData['driver']['profileImage'] = ImageService.getImageUrl(orderData['driver']['profileImage']);
        }
      }

      // Process customer avatar
      if (orderData['customer'] != null && orderData['customer']['avatar'] != null) {
        orderData['customer']['avatar'] = ImageService.getImageUrl(orderData['customer']['avatar']);
      }
    } catch (e) {
      debugPrint('Process order data error: $e');
    }
  }

  // Get nearby drivers
  static Future<List<Map<String, dynamic>>> getNearbyDrivers(
      double latitude,
      double longitude, {
        double radius = 5.0,
        int limit = 10,
      }) async {
    try {
      final queryParams = {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'radius': radius.toString(),
        'limit': limit.toString(),
      };

      final response = await BaseService.get('/drivers/nearby', queryParams: queryParams);

      if (response['data'] != null && response['data'] is List) {
        for (var driver in response['data']) {
          _processDriverImages(driver);
        }
        return List<Map<String, dynamic>>.from(response['data']);
      }

      return [];
    } catch (e) {
      debugPrint('Get nearby drivers error: $e');
      rethrow;
    }
  }

  // PRIVATE HELPER METHODS

  static void _processDriverImages(Map<String, dynamic> driverData) {
    try {
      // Process user avatar if present
      if (driverData['user'] != null && driverData['user']['avatar'] != null) {
        driverData['user']['avatar'] = ImageService.getImageUrl(driverData['user']['avatar']);
      }

      // Process driver profile images
      if (driverData['profileImage'] != null) {
        driverData['profileImage'] = ImageService.getImageUrl(driverData['profileImage']);
      }

      if (driverData['image'] != null) {
        driverData['image'] = ImageService.getImageUrl(driverData['image']);
      }
    } catch (e) {
      debugPrint('Process driver images error: $e');
    }
  }

  static void _processOrdersData(dynamic data) {
    try {
      List<dynamic> orders = [];

      if (data is List) {
        orders = data;
      } else if (data is Map<String, dynamic> && data['orders'] != null && data['orders'] is List) {
        orders = data['orders'];
      }

      for (var order in orders) {
        _processOrderImages(order);
      }
    } catch (e) {
      debugPrint('Process orders data error: $e');
    }
  }

  static void _processOrderImages(Map<String, dynamic> orderData) {
    try {
      // Process store image
      if (orderData['store'] != null && orderData['store']['imageUrl'] != null) {
        orderData['store']['imageUrl'] = ImageService.getImageUrl(orderData['store']['imageUrl']);
      }

      // Process menu item images
      if (orderData['items'] != null && orderData['items'] is List) {
        for (var item in orderData['items']) {
          if (item['menuItem'] != null && item['menuItem']['imageUrl'] != null) {
            item['menuItem']['imageUrl'] = ImageService.getImageUrl(item['menuItem']['imageUrl']);
          }
        }
      }
    } catch (e) {
      debugPrint('Process order images error: $e');
    }
  }
}