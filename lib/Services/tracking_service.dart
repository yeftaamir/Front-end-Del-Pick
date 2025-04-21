// lib/services/tracking_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'core/api_constants.dart';
import 'core/token_service.dart';
import 'image_service.dart';

class TrackingService {
  static Future<Map<String, dynamic>> getOrderTracking(String orderId) async {
    final String? token = await TokenService.getToken();
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/tracking/${orderId}'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = json.decode(response.body);

      // Process driver profile image if present
      if (jsonData['data'] != null && jsonData['data']['driver'] != null) {
        if (jsonData['data']['driver']['user'] != null && jsonData['data']['driver']['user']['avatar'] != null) {
          jsonData['data']['driver']['user']['avatar'] =
              ImageService.getImageUrl(jsonData['data']['driver']['user']['avatar']);
        }
      }

      return jsonData['data'];
    } else {
      throw Exception('Failed to fetch order tracking: ${response.body}');
    }
  }
}