// lib/services/driver_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'core/api_constants.dart';
import 'core/token_service.dart';
import 'image_service.dart';

class DriverService {
  /// Update driver location
  static Future<Map<String, dynamic>> updateDriverLocation(Map<String, dynamic> locationData) async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
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
        final Map<String, dynamic> jsonData = json.decode(response.body);
        return jsonData['data'];
      } else {
        throw Exception('Location update failed: ${response.body}');
      }
    } catch (e) {
      print('Error updating driver location: $e');
      throw Exception('Failed to update location: $e');
    }
  }

  /// Update driver status (active/inactive)
  static Future<Map<String, dynamic>> updateDriverStatus(String status) async {
    try {
      if (status != 'active' && status != 'inactive') {
        throw Exception('Status must be "active" or "inactive"');
      }

      final String? token = await TokenService.getToken();
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
        final Map<String, dynamic> jsonData = json.decode(response.body);
        return jsonData['data'];
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to change driver status');
      }
    } catch (e) {
      print('Error changing driver status: $e');
      throw Exception('Failed to change driver status: $e');
    }
  }

  /// Get driver location by ID
  static Future<Map<String, dynamic>> getDriverLocation(String driverId) async {
    try {
      final String? token = await TokenService.getToken();
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
        final Map<String, dynamic> jsonData = json.decode(response.body);
        return jsonData['data'];
      } else if (response.statusCode == 404) {
        throw Exception('Driver location not available');
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to retrieve driver location');
      }
    } catch (e) {
      print('Error fetching driver location: $e');
      throw Exception('Failed to retrieve driver location: $e');
    }
  }

  /// Get all driver requests
  static Future<Map<String, dynamic>> getDriverRequests() async {
    try {
      final String? token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/driver-requests'),
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
        throw Exception(errorData['message'] ?? 'Failed to load driver requests');
      }
    } catch (e) {
      print('Error fetching driver requests: $e');
      throw Exception('Failed to load driver requests: $e');
    }
  }

  /// Get detailed driver request
  static Future<Map<String, dynamic>> getDriverRequestDetail(String requestId) async {
    try {
      final String? token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/driver-requests/$requestId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);

        // Process images in order data if needed
        if (jsonData['data'] != null && jsonData['data']['order'] != null) {
          // Process store image if present
          if (jsonData['data']['order']['store'] != null &&
              jsonData['data']['order']['store']['image'] != null) {
            jsonData['data']['order']['store']['image'] =
                ImageService.getImageUrl(jsonData['data']['order']['store']['image']);
          }

          // Process user profile image if present
          if (jsonData['data']['order']['user'] != null &&
              jsonData['data']['order']['user']['avatar'] != null) {
            jsonData['data']['order']['user']['avatar'] =
                ImageService.getImageUrl(jsonData['data']['order']['user']['avatar']);
          }

          // Process images in order items if present
          if (jsonData['data']['order']['orderItems'] != null &&
              jsonData['data']['order']['orderItems'] is List) {
            for (var item in jsonData['data']['order']['orderItems']) {
              if (item['imageUrl'] != null) {
                item['imageUrl'] = ImageService.getImageUrl(item['imageUrl']);
              }
            }
          }
        }

        return jsonData['data'];
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to load driver request detail');
      }
    } catch (e) {
      print('Error fetching driver request detail: $e');
      throw Exception('Failed to load driver request detail: $e');
    }
  }

  /// Respond to driver request (accept/reject)
  static Future<Map<String, dynamic>> respondToDriverRequest(String requestId, String action) async {
    try {
      if (action != 'accept' && action != 'reject') {
        throw Exception('Action must be "accept" or "reject"');
      }

      final String? token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/driver-requests/$requestId/respond'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'action': action}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        return jsonData['data'];
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to respond to driver request');
      }
    } catch (e) {
      print('Error responding to driver request: $e');
      throw Exception('Failed to respond to driver request: $e');
    }
  }
}