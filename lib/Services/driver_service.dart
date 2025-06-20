// lib/services/driver_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'core/api_constants.dart';
import 'core/token_service.dart';
import 'image_service.dart';

class DriverService {
  /// Get all drivers (with pagination support)
  static Future<Map<String, dynamic>> getAllDrivers({
    int page = 1,
    int limit = 10,
    String? sortBy,
    String? sortOrder,
    String? search,
  }) async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (sortBy != null) queryParams['sortBy'] = sortBy;
      if (sortOrder != null) queryParams['sortOrder'] = sortOrder;
      if (search != null) queryParams['search'] = search;

      final uri = Uri.parse('${ApiConstants.baseUrl}/drivers')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = _parseResponseBody(response.body);

        // Process driver images if present
        if (jsonData['data'] != null && jsonData['data'] is List) {
          for (var driver in jsonData['data']) {
            _processDriverImages(driver);
          }
        }

        return jsonData;
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error fetching drivers: $e');
      throw Exception('Failed to get drivers: $e');
    }
    return {};
  }

  /// Get driver by ID
  static Future<Map<String, dynamic>> getDriverById(String driverId) async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/drivers/$driverId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = _parseResponseBody(response.body);

        // Process driver images
        if (jsonData['data'] != null) {
          _processDriverImages(jsonData['data']);
        }

        return jsonData['data'] ?? {};
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error fetching driver by ID: $e');
      throw Exception('Failed to get driver: $e');
    }
    return {};
  }

  /// Get driver location by ID
  static Future<Map<String, dynamic>> getDriverLocation(String driverId) async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/drivers/$driverId/location'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = _parseResponseBody(response.body);
        return jsonData['data'] ?? {};
      } else if (response.statusCode == 404) {
        throw Exception('Driver location not available');
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error fetching driver location: $e');
      throw Exception('Failed to get driver location: $e');
    }
    return {};
  }

  /// Update driver status (active/inactive/busy)
  static Future<Map<String, dynamic>> updateDriverStatus(String status) async {
    try {
      if (!['active', 'inactive', 'busy'].contains(status)) {
        throw Exception('Status must be "active", "inactive", or "busy"');
      }

      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/drivers/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'status': status}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = _parseResponseBody(response.body);
        return jsonData['data'] ?? {};
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error updating driver status: $e');
      throw Exception('Failed to update driver status: $e');
    }
    return {};
  }

  /// Update driver profile
  static Future<Map<String, dynamic>> updateProfileDriver(Map<String, dynamic> profileData) async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/drivers/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(profileData),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = _parseResponseBody(response.body);

        // Process driver images
        if (jsonData['data'] != null) {
          _processDriverImages(jsonData['data']);
        }

        return jsonData['data'] ?? {};
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error updating driver profile: $e');
      throw Exception('Failed to update driver profile: $e');
    }
    return {};
  }

  /// Get driver orders
  static Future<Map<String, dynamic>> getDriverOrders({
    int page = 1,
    int limit = 10,
    String? status,
  }) async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (status != null) queryParams['status'] = status;

      final uri = Uri.parse('${ApiConstants.baseUrl}/drivers/orders')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = _parseResponseBody(response.body);

        // Process order images if present
        if (jsonData['data'] != null) {
          final data = jsonData['data'];
          List<dynamic> orders = [];

          if (data is List) {
            orders = data;
          } else if (data['orders'] != null && data['orders'] is List) {
            orders = data['orders'];
          }

          for (var order in orders) {
            _processOrderImages(order);
          }
        }

        return jsonData['data'] ?? {};
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error fetching driver orders: $e');
      throw Exception('Failed to get driver orders: $e');
    }
    return {};
  }

  /// Update driver location
  static Future<Map<String, dynamic>> updateDriverLocation(Map<String, dynamic> locationData) async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      // Validate required fields
      if (!locationData.containsKey('latitude') || !locationData.containsKey('longitude')) {
        throw Exception('Latitude and longitude are required');
      }

      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/drivers/location'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(locationData),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = _parseResponseBody(response.body);
        return jsonData['data'] ?? {};
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error updating driver location: $e');
      throw Exception('Failed to update driver location: $e');
    }
    return {};
  }

  /// Get driver statistics
  static Future<Map<String, dynamic>> getDriverStatistics() async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/drivers/statistics'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = _parseResponseBody(response.body);
        return jsonData['data'] ?? {};
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error fetching driver statistics: $e');
      throw Exception('Failed to get driver statistics: $e');
    }
    return {};
  }

  /// Get nearby drivers (for customer/store use)
  static Future<List<Map<String, dynamic>>> getNearbyDrivers({
    required double latitude,
    required double longitude,
    double radiusKm = 5.0,
  }) async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final queryParams = {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'radius': radiusKm.toString(),
      };

      final uri = Uri.parse('${ApiConstants.baseUrl}/drivers/nearby')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = _parseResponseBody(response.body);

        List<Map<String, dynamic>> drivers = [];
        if (jsonData['data'] != null && jsonData['data'] is List) {
          drivers = List<Map<String, dynamic>>.from(jsonData['data']);

          // Process driver images
          for (var driver in drivers) {
            _processDriverImages(driver);
          }
        }

        return drivers;
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error fetching nearby drivers: $e');
      throw Exception('Failed to get nearby drivers: $e');
    }
    return [];
  }

  // PRIVATE HELPER METHODS

  /// Process driver images in data
  static void _processDriverImages(Map<String, dynamic> driver) {
    try {
      // Process user avatar if present
      if (driver['user'] != null && driver['user']['avatar'] != null) {
        driver['user']['avatar'] = ImageService.getImageUrl(driver['user']['avatar']);
      }

      // Process direct driver profile image fields
      if (driver['profileImage'] != null && driver['profileImage'].toString().isNotEmpty) {
        driver['profileImage'] = ImageService.getImageUrl(driver['profileImage']);
      }

      if (driver['image'] != null && driver['image'].toString().isNotEmpty) {
        driver['image'] = ImageService.getImageUrl(driver['image']);
        // Set profileImage for consistency if not present
        if (driver['profileImage'] == null) {
          driver['profileImage'] = driver['image'];
        }
      }
    } catch (e) {
      print('Error processing driver images: $e');
    }
  }

  /// Process order images in driver order data
  static void _processOrderImages(Map<String, dynamic> order) {
    try {
      // Process store image if present
      if (order['store'] != null) {
        if (order['store']['imageUrl'] != null) {
          order['store']['imageUrl'] = ImageService.getImageUrl(order['store']['imageUrl']);
        }
        if (order['store']['image'] != null) {
          order['store']['image'] = ImageService.getImageUrl(order['store']['image']);
        }
      }

      // Process customer avatar if present
      if (order['customer'] != null && order['customer']['avatar'] != null) {
        order['customer']['avatar'] = ImageService.getImageUrl(order['customer']['avatar']);
      }

      // Process order items if present
      if (order['items'] != null && order['items'] is List) {
        for (var item in order['items']) {
          if (item['imageUrl'] != null) {
            item['imageUrl'] = ImageService.getImageUrl(item['imageUrl']);
          }
        }
      }
    } catch (e) {
      print('Error processing order images: $e');
    }
  }

  /// Parse response body with better error handling
  static Map<String, dynamic> _parseResponseBody(String body) {
    try {
      return json.decode(body);
    } catch (e) {
      print('Error parsing response body: $e');
      String cleanedBody = body.trim();
      if (cleanedBody.startsWith('\uFEFF')) {
        cleanedBody = cleanedBody.substring(1);
      }
      try {
        return json.decode(cleanedBody);
      } catch (e) {
        throw Exception('Invalid response format: $body');
      }
    }
  }

  /// Handle error responses consistently
  static void _handleErrorResponse(http.Response response) {
    try {
      final errorData = _parseResponseBody(response.body);
      final message = errorData['message'] ?? 'Request failed';
      throw Exception(message);
    } catch (e) {
      if (e is Exception && e.toString().contains('Request failed')) {
        rethrow;
      }
      throw Exception('Request failed with status ${response.statusCode}: ${response.body}');
    }
  }
}