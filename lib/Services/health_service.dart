// lib/services/health_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'core/api_constants.dart';
import 'core/token_service.dart';

class HealthService {
  /// Check overall system health
  static Future<Map<String, dynamic>> checkHealth() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/health'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = _parseResponseBody(response.body);
        return jsonData['data'] ?? {};
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error checking health: $e');
      throw Exception('Failed to check health: $e');
    }
    return {};
  }

  /// Check database connection
  static Future<Map<String, dynamic>> checkDatabase() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/health/db'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = _parseResponseBody(response.body);
        return jsonData['data'] ?? {};
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error checking database: $e');
      throw Exception('Failed to check database: $e');
    }
    return {};
  }

  /// Check cache connection
  static Future<Map<String, dynamic>> checkCache() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/health/cache'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = _parseResponseBody(response.body);
        return jsonData['data'] ?? {};
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error checking cache: $e');
      throw Exception('Failed to check cache: $e');
    }
    return {};
  }

  /// Check storage connection
  static Future<Map<String, dynamic>> checkStorage() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/health/storage'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = _parseResponseBody(response.body);
        return jsonData['data'] ?? {};
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error checking storage: $e');
      throw Exception('Failed to check storage: $e');
    }
    return {};
  }

  // Helper methods
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