// lib/services/store_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'core/api_constants.dart';
import 'core/token_service.dart';
import 'image_service.dart';

class StoreService {
  /// Get all stores
  static Future<List<Map<String, dynamic>>> getAllStores({
    int page = 1,
    int limit = 10,
    String? search,
    double? latitude,
    double? longitude,
    double? radiusKm,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (search != null) queryParams['search'] = search;
      if (latitude != null) queryParams['latitude'] = latitude.toString();
      if (longitude != null) queryParams['longitude'] = longitude.toString();
      if (radiusKm != null) queryParams['radius'] = radiusKm.toString();

      final uri = Uri.parse('${ApiConstants.baseUrl}/stores')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = _parseResponseBody(response.body);

        List<Map<String, dynamic>> stores = [];
        if (jsonData['data'] != null && jsonData['data']['stores'] is List) {
          stores = List<Map<String, dynamic>>.from(jsonData['data']['stores']);

          // Process store images
          for (var store in stores) {
            _processStoreImage(store);
          }
        }

        return stores;
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error fetching stores: $e');
      throw Exception('Failed to get stores: $e');
    }
    return [];
  }

  /// Get store by ID
  static Future<Map<String, dynamic>> getStoreById(String storeId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/stores/$storeId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = _parseResponseBody(response.body);

        // Process store image
        if (jsonData['data'] != null) {
          _processStoreImage(jsonData['data']);
        }

        return jsonData['data'] ?? {};
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error fetching store: $e');
      throw Exception('Failed to get store: $e');
    }
    return {};
  }

  /// Create new store - NEW METHOD
  static Future<Map<String, dynamic>> createStore(Map<String, dynamic> storeData) async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/stores'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(storeData),
      );

      if (response.statusCode == 201) {
        final Map<String, dynamic> jsonData = _parseResponseBody(response.body);

        // Process store image
        if (jsonData['data'] != null) {
          _processStoreImage(jsonData['data']);
        }

        return jsonData['data'] ?? {};
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error creating store: $e');
      throw Exception('Failed to create store: $e');
    }
    return {};
  }

  /// Update store - NEW METHOD
  static Future<Map<String, dynamic>> updateStore(String storeId, Map<String, dynamic> storeData) async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/stores/$storeId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(storeData),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = _parseResponseBody(response.body);

        // Process store image
        if (jsonData['data'] != null) {
          _processStoreImage(jsonData['data']);
        }

        return jsonData['data'] ?? {};
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error updating store: $e');
      throw Exception('Failed to update store: $e');
    }
    return {};
  }

  /// Delete store - NEW METHOD
  static Future<bool> deleteStore(String storeId) async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.delete(
        Uri.parse('${ApiConstants.baseUrl}/stores/$storeId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error deleting store: $e');
      throw Exception('Failed to delete store: $e');
    }
    return false;
  }

  /// Update store status (for store owners)
  static Future<Map<String, dynamic>> updateStoreStatus(String storeId, String status) async {
    try {
      if (!['active', 'inactive'].contains(status)) {
        throw Exception('Status must be "active" or "inactive"');
      }

      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.patch(
        Uri.parse('${ApiConstants.baseUrl}/stores/$storeId/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'status': status}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = _parseResponseBody(response.body);

        // Process store image
        if (jsonData['data'] != null) {
          _processStoreImage(jsonData['data']);
        }

        return jsonData['data'] ?? {};
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error updating store status: $e');
      throw Exception('Failed to update store status: $e');
    }
    return {};
  }

  /// Get current store profile (for store owners) - NEW METHOD
  static Future<Map<String, dynamic>> getCurrentStoreProfile() async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/stores/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = _parseResponseBody(response.body);

        // Process store image
        if (jsonData['data'] != null) {
          _processStoreImage(jsonData['data']);
        }

        return jsonData['data'] ?? {};
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error fetching store profile: $e');
      throw Exception('Failed to get store profile: $e');
    }
    return {};
  }

  /// Update current store profile (for store owners) - NEW METHOD
  static Future<Map<String, dynamic>> updateCurrentStoreProfile(Map<String, dynamic> storeData) async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/stores/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(storeData),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = _parseResponseBody(response.body);

        // Process store image
        if (jsonData['data'] != null) {
          _processStoreImage(jsonData['data']);
        }

        return jsonData['data'] ?? {};
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error updating store profile: $e');
      throw Exception('Failed to update store profile: $e');
    }
    return {};
  }

  /// Get store statistics (for store owners) - NEW METHOD
  static Future<Map<String, dynamic>> getStoreStatistics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final queryParams = <String, String>{};
      if (startDate != null) queryParams['startDate'] = startDate.toIso8601String();
      if (endDate != null) queryParams['endDate'] = endDate.toIso8601String();

      final uri = Uri.parse('${ApiConstants.baseUrl}/stores/statistics')
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
        return jsonData['data'] ?? {};
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error fetching store statistics: $e');
      throw Exception('Failed to get store statistics: $e');
    }
    return {};
  }

  /// Get nearby stores (based on location) - NEW METHOD
  static Future<List<Map<String, dynamic>>> getNearbyStores({
    required double latitude,
    required double longitude,
    double radiusKm = 5.0,
    int limit = 20,
  }) async {
    try {
      final queryParams = {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'radius': radiusKm.toString(),
        'limit': limit.toString(),
      };

      final uri = Uri.parse('${ApiConstants.baseUrl}/stores/nearby')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = _parseResponseBody(response.body);

        List<Map<String, dynamic>> stores = [];
        if (jsonData['data'] != null && jsonData['data'] is List) {
          stores = List<Map<String, dynamic>>.from(jsonData['data']);

          // Process store images
          for (var store in stores) {
            _processStoreImage(store);
          }
        }

        return stores;
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error fetching nearby stores: $e');
      throw Exception('Failed to get nearby stores: $e');
    }
    return [];
  }

  /// Search stores by criteria - NEW METHOD
  static Future<List<Map<String, dynamic>>> searchStores({
    String? query,
    String? category,
    double? minRating,
    double? maxDistance,
    double? userLatitude,
    double? userLongitude,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (query != null) queryParams['q'] = query;
      if (category != null) queryParams['category'] = category;
      if (minRating != null) queryParams['minRating'] = minRating.toString();
      if (maxDistance != null) queryParams['maxDistance'] = maxDistance.toString();
      if (userLatitude != null) queryParams['lat'] = userLatitude.toString();
      if (userLongitude != null) queryParams['lng'] = userLongitude.toString();

      final uri = Uri.parse('${ApiConstants.baseUrl}/stores/search')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = _parseResponseBody(response.body);

        List<Map<String, dynamic>> stores = [];
        if (jsonData['data'] != null && jsonData['data']['stores'] is List) {
          stores = List<Map<String, dynamic>>.from(jsonData['data']['stores']);

          // Process store images
          for (var store in stores) {
            _processStoreImage(store);
          }
        }

        return stores;
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error searching stores: $e');
      throw Exception('Failed to search stores: $e');
    }
    return [];
  }

  // Helper methods
  static void _processStoreImage(Map<String, dynamic> store) {
    if (store['image'] != null && store['image'].toString().isNotEmpty) {
      store['image'] = ImageService.getImageUrl(store['image']);
    }
    if (store['imageUrl'] != null && store['imageUrl'].toString().isNotEmpty) {
      store['imageUrl'] = ImageService.getImageUrl(store['imageUrl']);
    }
    if (store['image_url'] != null && store['image_url'].toString().isNotEmpty) {
      store['image_url'] = ImageService.getImageUrl(store['image_url']);
    }
  }

  static Map<String, dynamic> _parseResponseBody(String body) {
    try {
      return json.decode(body);
    } catch (e) {
      throw Exception('Invalid response format: $body');
    }
  }

  static void _handleErrorResponse(http.Response response) {
    try {
      final errorData = _parseResponseBody(response.body);
      final message = errorData['message'] ?? 'Request failed';
      throw Exception(message);
    } catch (e) {
      throw Exception('Request failed with status ${response.statusCode}: ${response.body}');
    }
  }
}