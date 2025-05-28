// lib/services/tracking_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'core/api_constants.dart';
import 'core/token_service.dart';
import 'image_service.dart';

class TrackingService {
  /// Get order tracking data
  static Future<Map<String, dynamic>> getTrackingData(String orderId) async {
    try {
      final String? token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/tracking/$orderId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);

        // Process driver profile image if present
        if (jsonData['data'] != null && jsonData['data']['driver'] != null) {
          if (jsonData['data']['driver']['name'] != null) {
            // Process data directly
          } else if (jsonData['data']['driver']['user'] != null &&
              jsonData['data']['driver']['user']['avatar'] != null) {
            jsonData['data']['driver']['user']['avatar'] =
                ImageService.getImageUrl(jsonData['data']['driver']['user']['avatar']);
          }
        }

        return jsonData['data'];
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to fetch order tracking');
      }
    } catch (e) {
      print('Error fetching tracking data: $e');
      throw Exception('Failed to fetch order tracking: $e');
    }
  }

  /// Get order tracking information
  static Future<Map<String, dynamic>> getOrderTracking(String orderId) async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/orders/$orderId/tracking'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);

        // Process driver avatar if present
        if (jsonData['data'] != null &&
            jsonData['data']['driver'] != null &&
            jsonData['data']['driver']['avatar'] != null) {
          jsonData['data']['driver']['avatar'] =
              ImageService.getImageUrl(jsonData['data']['driver']['avatar']);
        }

        return jsonData['data'];
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to fetch order tracking status');
      }
    } catch (e) {
      print('Error fetching order tracking: $e');
      throw Exception('Failed to fetch order tracking status: $e');
    }
  }

  /// Get order detail with status information
  static Future<Map<String, dynamic>> getOrderDetail(String orderId) async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/orders/$orderId/detail'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);

        // Process images and additional data if present
        if (jsonData['data'] != null) {
          // Process store image if present
          if (jsonData['data']['store'] != null && jsonData['data']['store']['image'] != null) {
            jsonData['data']['store']['image'] =
                ImageService.getImageUrl(jsonData['data']['store']['image']);
          }

          // Process customer avatar if present
          if (jsonData['data']['customer'] != null && jsonData['data']['customer']['avatar'] != null) {
            jsonData['data']['customer']['avatar'] =
                ImageService.getImageUrl(jsonData['data']['customer']['avatar']);
          }

          // Process driver avatar if present
          if (jsonData['data']['driver'] != null && jsonData['data']['driver']['avatar'] != null) {
            jsonData['data']['driver']['avatar'] =
                ImageService.getImageUrl(jsonData['data']['driver']['avatar']);
          }

          // Process items images if present
          if (jsonData['data']['items'] != null && jsonData['data']['items'] is List) {
            for (var item in jsonData['data']['items']) {
              if (item['imageUrl'] != null) {
                item['imageUrl'] = ImageService.getImageUrl(item['imageUrl']);
              }
            }
          }

          // Process tracking information if present
          if (jsonData['data']['tracking'] != null) {
            // Additional tracking data processing if needed
          }
        }

        return jsonData['data'];
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to get order detail');
      }
    } catch (e) {
      print('Error fetching order detail: $e');
      throw Exception('Failed to get order detail: $e');
    }
  }

  /// Start delivery by driver
  static Future<Map<String, dynamic>> startDelivery(String orderId) async {
    try {
      final String? token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/tracking/$orderId/start'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        return jsonData['data'];
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to start delivery');
      }
    } catch (e) {
      print('Error starting delivery: $e');
      throw Exception('Failed to start delivery: $e');
    }
  }

  /// Complete delivery by driver
  static Future<Map<String, dynamic>> completeDelivery(String orderId) async {
    try {
      final String? token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/tracking/$orderId/complete'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        return jsonData['data'];
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to complete delivery');
      }
    } catch (e) {
      print('Error completing delivery: $e');
      throw Exception('Failed to complete delivery: $e');
    }
  }

  /// Update order status
  static Future<Map<String, dynamic>> updateOrderStatus(String orderId, String status) async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/orders/$orderId/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'status': status}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        return jsonData['data'];
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to update order status');
      }
    } catch (e) {
      print('Error updating order status: $e');
      throw Exception('Failed to update order status: $e');
    }
  }
}