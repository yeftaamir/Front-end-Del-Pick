// lib/services/notification_service.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'core/base_service.dart';

class NotificationService extends BaseService {
  static FlutterLocalNotificationsPlugin? _localNotifications;

  // Initialize notification service
  static Future<void> initialize() async {
    try {
      _localNotifications = FlutterLocalNotificationsPlugin();

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications!.initialize(settings);
      debugPrint('Notification service initialized');
    } catch (e) {
      debugPrint('Notification service initialization error: $e');
    }
  }

  // Show local notification
  static Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      if (_localNotifications == null) {
        await initialize();
      }

      const androidDetails = AndroidNotificationDetails(
        'default_channel',
        'Default Channel',
        channelDescription: 'Default notification channel',
        importance: Importance.high,
        priority: Priority.high,
      );

      const iosDetails = DarwinNotificationDetails();

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications!.show(id, title, body, details, payload: payload);
    } catch (e) {
      debugPrint('Show local notification error: $e');
    }
  }

  // Register device for push notifications
  static Future<Map<String, dynamic>> registerDevice(String fcmToken) async {
    try {
      final response = await BaseService.post('/notifications/register', {
        'fcm_token': fcmToken,
        'platform': defaultTargetPlatform.name,
      });

      return response['data'] ?? {};
    } catch (e) {
      debugPrint('Register device error: $e');
      rethrow;
    }
  }

  // Unregister device from push notifications
  static Future<bool> unregisterDevice() async {
    try {
      await BaseService.delete('/notifications/register');
      return true;
    } catch (e) {
      debugPrint('Unregister device error: $e');
      return false;
    }
  }

  // Get notification settings
  static Future<Map<String, dynamic>> getNotificationSettings() async {
    try {
      final response = await BaseService.get('/notifications/settings');
      return response['data'] ?? {};
    } catch (e) {
      debugPrint('Get notification settings error: $e');
      rethrow;
    }
  }

  // Update notification settings
  static Future<Map<String, dynamic>> updateNotificationSettings(Map<String, bool> settings) async {
    try {
      final response = await BaseService.put('/notifications/settings', settings);
      return response['data'] ?? {};
    } catch (e) {
      debugPrint('Update notification settings error: $e');
      rethrow;
    }
  }

  // Mark notification as read
  static Future<bool> markNotificationAsRead(String notificationId) async {
    try {
      await BaseService.put('/notifications/$notificationId/read', {});
      return true;
    } catch (e) {
      debugPrint('Mark notification as read error: $e');
      return false;
    }
  }

  // Get notification history
  static Future<Map<String, dynamic>> getNotificationHistory({
    int page = 1,
    int limit = 20,
    bool? isRead,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (isRead != null) queryParams['isRead'] = isRead.toString();

      final response = await BaseService.get('/notifications', queryParams: queryParams);
      return response;
    } catch (e) {
      debugPrint('Get notification history error: $e');
      rethrow;
    }
  }
}