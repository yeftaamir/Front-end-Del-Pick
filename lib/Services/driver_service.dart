// lib/services/driver_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'core/api_constants.dart';
import 'core/token_service.dart';
import 'image_service.dart';

class DriverService {
  static Future<void> updateDriverLocation(Map<String, dynamic> locationData) async {
    final token = await TokenService.getToken();
    final response = await http.put(
      Uri.parse('${ApiConstants.baseUrl}/drivers/location'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(locationData),
    );

    if (response.statusCode != 200) {
      throw Exception('Location update failed: ${response.body}');
    }
  }

  static Future<String> changeDriverStatus(String status) async {
    final String? token = await TokenService.getToken();
    final response = await http.put(
      Uri.parse('${ApiConstants.baseUrl}/drivers/status'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'status': status}),
    );

    if (response.statusCode == 200) {
      return response.body.toString();
    } else {
      throw Exception('Failed to change driver status: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> getDriverById(String driverId) async {
    final String? token = await TokenService.getToken();
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/drivers/$driverId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = json.decode(response.body);

      // Process driver profile image if present
      if (jsonData['data'] != null) {
        if (jsonData['data']['user'] != null && jsonData['data']['user']['avatar'] != null) {
          jsonData['data']['user']['avatar'] = ImageService.getImageUrl(jsonData['data']['user']['avatar']);
        }

        // For backward compatibility
        if (jsonData['data']['user'] != null) {
          jsonData['data']['profileImage'] = jsonData['data']['user']['avatar'];
        }
      }

      return jsonData['data'];
    } else {
      throw Exception('Failed to load driver information');
    }
  }

  static Future<Map<String, dynamic>> getDriverLocation(String driverId) async {
    final String? token = await TokenService.getToken();
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
      throw Exception('Failed to retrieve driver location: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> getDriverRequests() async {
    final String? token = await TokenService.getToken();
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/driver-requests'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = json.decode(response.body);

      // Debug the response structure
      print('API Response for driver requests: ${jsonData['data']}');

      // Return the data object directly, which contains 'requests'
      return jsonData['data'];
    } else {
      throw Exception('Failed to load driver requests');
    }
  }

  static Future<Map<String, dynamic>> getDriverRequestDetail(String requestId) async {
    final String? token = await TokenService.getToken();
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/driver-requests/$requestId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = json.decode(response.body);

      // Process images in order data if any
      if (jsonData['data'] != null && jsonData['data']['order'] != null) {
        // Process store image if present
        if (jsonData['data']['order']['store'] != null && jsonData['data']['order']['store']['image'] != null) {
          jsonData['data']['order']['store']['image'] = ImageService.getImageUrl(jsonData['data']['order']['store']['image']);
        }

        // Process user profile image if present
        if (jsonData['data']['order']['user'] != null && jsonData['data']['order']['user']['avatar'] != null) {
          jsonData['data']['order']['user']['avatar'] = ImageService.getImageUrl(jsonData['data']['order']['user']['avatar']);
        }

        // Process images in order items if present
        if (jsonData['data']['order']['orderItems'] != null && jsonData['data']['order']['orderItems'] is List) {
          for (var item in jsonData['data']['order']['orderItems']) {
            if (item['imageUrl'] != null) {
              item['imageUrl'] = ImageService.getImageUrl(item['imageUrl']);
            }
          }
        }
      }

      return jsonData['data'];
    } else {
      throw Exception('Failed to load driver request detail');
    }
  }

  static Future<Map<String, dynamic>> respondToDriverRequest(String requestId, String action) async {
    final String? token = await TokenService.getToken();
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
      throw Exception('Failed to respond to driver request: ${response.body}');
    }
  }

  static Future<bool> updateDriverProfileImage(String driverId, String base64Image) async {
    return ImageService.uploadUserProfileImage(driverId, base64Image);
  }
}