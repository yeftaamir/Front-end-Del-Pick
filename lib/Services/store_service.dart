// lib/services/store_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../Models/store.dart';
import 'core/api_constants.dart';
import 'core/token_service.dart';
import 'image_service.dart';

class StoreService {
  /// Fetch all stores
  static Future<List<dynamic>> getAllStores() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/stores'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        List<dynamic> storesJson = jsonData['data']['stores'];

        // Process each store, ensuring proper handling of images
        storesJson.forEach((json) {
          // Ensure image URLs are properly formatted
          if (json['image'] != null) {
            json['image'] = ImageService.getImageUrl(json['image']);
          }
        });

        return storesJson;
      } else {
        throw Exception('Failed to load stores: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching stores: $e');
      throw Exception('Failed to load stores: $e');
    }
  }

  /// Fetch store by ID
  static Future<Map<String, dynamic>> getStoreById(String storeId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/stores/$storeId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);

        // Format image URL if present
        if (jsonData['data']['image'] != null) {
          jsonData['data']['image'] = ImageService.getImageUrl(jsonData['data']['image']);
        }

        return jsonData['data'];
      } else {
        throw Exception('Failed to load store: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching store #$storeId: $e');
      throw Exception('Failed to load store: $e');
    }
  }

  /// Update store status (active/inactive)
  static Future<Map<String, dynamic>> updateStoreStatus(String storeId, String status) async {
    try {
      // Validate status input
      if (status != 'active' && status != 'inactive') {
        throw Exception('Status must be "active" or "inactive"');
      }

      // Get authentication token
      final String? token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      // Make API request
      final response = await http.patch(
        Uri.parse('${ApiConstants.baseUrl}/stores/$storeId/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'status': status}),
      );

      // Handle response
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        return jsonData['data'];
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to update store status');
      }
    } catch (e) {
      print('Error updating store status: $e');
      throw Exception('Failed to update store status: $e');
    }
  }
}