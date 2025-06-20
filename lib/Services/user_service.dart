// lib/services/user_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'core/api_constants.dart';
import 'core/token_service.dart';
import 'image_service.dart';

class UserService {
  /// Get user profile
  static Future<Map<String, dynamic>> getProfile() async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/users/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = _parseResponseBody(response.body);

        // Process user avatar
        if (jsonData['data'] != null && jsonData['data']['avatar'] != null) {
          jsonData['data']['avatar'] = ImageService.getImageUrl(jsonData['data']['avatar']);
        }

        return jsonData['data'] ?? {};
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error fetching profile: $e');
      throw Exception('Failed to get profile: $e');
    }
    return {};
  }

  /// Update user profile
  static Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> profileData) async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/users/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(profileData),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = _parseResponseBody(response.body);

        // Process user avatar
        if (jsonData['data'] != null && jsonData['data']['avatar'] != null) {
          jsonData['data']['avatar'] = ImageService.getImageUrl(jsonData['data']['avatar']);
        }

        return jsonData['data'] ?? {};
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error updating profile: $e');
      throw Exception('Failed to update profile: $e');
    }
    return {};
  }

  /// Delete user profile
  static Future<bool> deleteProfile() async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.delete(
        Uri.parse('${ApiConstants.baseUrl}/users/profile'),
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
      print('Error deleting profile: $e');
      throw Exception('Failed to delete profile: $e');
    }
    return false;
  }

  /// Get user notifications
  static Future<List<Map<String, dynamic>>> getNotifications({
    int page = 1,
    int limit = 10,
    bool? unreadOnly,
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

      if (unreadOnly != null) queryParams['unreadOnly'] = unreadOnly.toString();

      final uri = Uri.parse('${ApiConstants.baseUrl}/users/notifications')
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

        List<Map<String, dynamic>> notifications = [];
        if (jsonData['data'] != null && jsonData['data'] is List) {
          notifications = List<Map<String, dynamic>>.from(jsonData['data']);
        }

        return notifications;
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error fetching notifications: $e');
      throw Exception('Failed to get notifications: $e');
    }
    return [];
  }

  /// Mark notification as read
  static Future<bool> markNotificationAsRead(String notificationId) async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.patch(
        Uri.parse('${ApiConstants.baseUrl}/users/notifications/$notificationId/read'),
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
      print('Error marking notification as read: $e');
      throw Exception('Failed to mark notification as read: $e');
    }
    return false;
  }

  /// Mark all notifications as read - NEW METHOD
  static Future<bool> markAllNotificationsAsRead() async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.patch(
        Uri.parse('${ApiConstants.baseUrl}/users/notifications/read-all'),
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
      print('Error marking all notifications as read: $e');
      throw Exception('Failed to mark all notifications as read: $e');
    }
    return false;
  }

  /// Delete notification
  static Future<bool> deleteNotification(String notificationId) async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.delete(
        Uri.parse('${ApiConstants.baseUrl}/users/notifications/$notificationId'),
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
      print('Error deleting notification: $e');
      throw Exception('Failed to delete notification: $e');
    }
    return false;
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