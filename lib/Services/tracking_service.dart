// lib/services/tracking_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'core/api_constants.dart';
import 'core/token_service.dart';
import 'image_service.dart';

class TrackingService {
  /// Get tracking data for an order
  static Future<Map<String, dynamic>> getTrackingData(String orderId) async {
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
        final Map<String, dynamic> jsonData = _parseResponseBody(response.body);

        // Process driver image if present
        if (jsonData['data'] != null && jsonData['data']['driver'] != null) {
          _processDriverImage(jsonData['data']['driver']);
        }

        return jsonData['data'] ?? {};
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error fetching tracking data: $e');
      throw Exception('Failed to get tracking data: $e');
    }
    return {};
  }

  /// Start delivery (by driver)
  static Future<Map<String, dynamic>> startDelivery(String orderId) async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/orders/$orderId/tracking/start'),
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
      print('Error starting delivery: $e');
      throw Exception('Failed to start delivery: $e');
    }
    return {};
  }

  /// Complete delivery (by driver)
  static Future<Map<String, dynamic>> completeDelivery(String orderId) async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/orders/$orderId/tracking/complete'),
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
      print('Error completing delivery: $e');
      throw Exception('Failed to complete delivery: $e');
    }
    return {};
  }

  /// Update driver location during delivery
  static Future<Map<String, dynamic>> updateDriverLocation(String orderId, Map<String, dynamic> locationData) async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/orders/$orderId/tracking/location'),
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

  /// Get tracking history for an order
  static Future<Map<String, dynamic>> getTrackingHistory(String orderId) async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/orders/$orderId/tracking/history'),
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
      print('Error fetching tracking history: $e');
      throw Exception('Failed to get tracking history: $e');
    }
    return {};
  }

  // Helper methods
  static void _processDriverImage(Map<String, dynamic> driver) {
    if (driver['avatar'] != null && driver['avatar'].toString().isNotEmpty) {
      driver['avatar'] = ImageService.getImageUrl(driver['avatar']);
    }
    if (driver['user'] != null && driver['user']['avatar'] != null) {
      driver['user']['avatar'] = ImageService.getImageUrl(driver['user']['avatar']);
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