// lib/Services/user_service.dart
import 'dart:convert';
import 'Core/token_service.dart';
import 'core/base_service.dart';

class UserService {
  static const String _baseEndpoint = '/users';

  /// Get current user profile (same as AuthService.getProfile but here for completeness)
  static Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/profile',
        requiresAuth: true,
      );

      return response['data'] ?? {};
    } catch (e) {
      print('Get profile error: $e');
      throw Exception('Failed to get profile: $e');
    }
  }

  /// Update FCM token for push notifications
  static Future<bool> updateFcmToken(String fcmToken) async {
    try {
      await BaseService.apiCall(
        method: 'PUT',
        endpoint: '$_baseEndpoint/fcm-token',
        body: {'fcm_token': fcmToken},
        requiresAuth: true,
      );

      // Save FCM token locally
      await TokenService.saveFcmToken(fcmToken);
      return true;
    } catch (e) {
      print('Update FCM token error: $e');
      return false;
    }
  }

  /// Get user notifications
  static Future<Map<String, dynamic>> getUserNotifications({
    int page = 1,
    int limit = 20,
    bool? isRead,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (isRead != null) 'isRead': isRead.toString(),
      };

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/notifications',
        queryParams: queryParams,
        requiresAuth: true,
      );

      return response;
    } catch (e) {
      print('Get user notifications error: $e');
      throw Exception('Failed to get notifications: $e');
    }
  }

  /// Mark notification as read
  static Future<bool> markNotificationAsRead(String notificationId) async {
    try {
      await BaseService.apiCall(
        method: 'PATCH',
        endpoint: '$_baseEndpoint/notifications/$notificationId/read',
        requiresAuth: true,
      );
      return true;
    } catch (e) {
      print('Mark notification as read error: $e');
      return false;
    }
  }

  /// Mark all notifications as read
  static Future<bool> markAllNotificationsAsRead() async {
    try {
      await BaseService.apiCall(
        method: 'PATCH',
        endpoint: '$_baseEndpoint/notifications/read-all',
        requiresAuth: true,
      );
      return true;
    } catch (e) {
      print('Mark all notifications as read error: $e');
      return false;
    }
  }

  /// Delete notification
  static Future<bool> deleteNotification(String notificationId) async {
    try {
      await BaseService.apiCall(
        method: 'DELETE',
        endpoint: '$_baseEndpoint/notifications/$notificationId',
        requiresAuth: true,
      );
      return true;
    } catch (e) {
      print('Delete notification error: $e');
      return false;
    }
  }

  /// Delete all notifications
  static Future<bool> deleteAllNotifications() async {
    try {
      await BaseService.apiCall(
        method: 'DELETE',
        endpoint: '$_baseEndpoint/notifications/all',
        requiresAuth: true,
      );
      return true;
    } catch (e) {
      print('Delete all notifications error: $e');
      return false;
    }
  }

  /// Get unread notifications count
  static Future<int> getUnreadNotificationsCount() async {
    try {
      final response = await getUserNotifications(
        limit: 1,
        isRead: false,
      );

      return response['totalItems'] ?? 0;
    } catch (e) {
      print('Get unread notifications count error: $e');
      return 0;
    }
  }

  /// Update user profile
  static Future<Map<String, dynamic>> updateProfile({
    required Map<String, dynamic> updateData,
  }) async {
    try {
      final response = await BaseService.apiCall(
        method: 'PUT',
        endpoint: '$_baseEndpoint/profile',
        body: updateData,
        requiresAuth: true,
      );

      return response['data'] ?? {};
    } catch (e) {
      print('Update profile error: $e');
      throw Exception('Failed to update profile: $e');
    }
  }

  /// Delete user account
  static Future<bool> deleteProfile() async {
    try {
      await BaseService.apiCall(
        method: 'DELETE',
        endpoint: '$_baseEndpoint/profile',
        requiresAuth: true,
      );

      // Clear all local data after account deletion
      await TokenService.clearAll();
      return true;
    } catch (e) {
      print('Delete profile error: $e');
      return false;
    }
  }

  /// Get user preferences
  static Future<Map<String, dynamic>> getUserPreferences() async {
    try {
      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/preferences',
        requiresAuth: true,
      );

      return response['data'] ?? {};
    } catch (e) {
      print('Get user preferences error: $e');
      return {};
    }
  }

  /// Update user preferences
  static Future<bool> updateUserPreferences({
    required Map<String, dynamic> preferences,
  }) async {
    try {
      await BaseService.apiCall(
        method: 'PUT',
        endpoint: '$_baseEndpoint/preferences',
        body: preferences,
        requiresAuth: true,
      );
      return true;
    } catch (e) {
      print('Update user preferences error: $e');
      return false;
    }
  }
}