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

  // Helper methods
  static void _processStoreImage(Map<String, dynamic> store) {
    if (store['image'] != null && store['image'].toString().isNotEmpty) {
      store['image'] = ImageService.getImageUrl(store['image']);
    }
    if (store['imageUrl'] != null && store['imageUrl'].toString().isNotEmpty) {
      store['imageUrl'] = ImageService.getImageUrl(store['imageUrl']);
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
