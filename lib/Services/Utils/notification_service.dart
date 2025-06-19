// lib/services/utils/notification_service.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../User/user_service.dart';
import 'auth_manager.dart';

class NotificationService {
  static FirebaseMessaging? _firebaseMessaging;
  static FlutterLocalNotificationsPlugin? _localNotifications;

  // Initialize notification service
  static Future<void> init() async {
    _firebaseMessaging = FirebaseMessaging.instance;
    _localNotifications = FlutterLocalNotificationsPlugin();

    // Request permission
    await _requestPermission();

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Setup message handlers
    _setupMessageHandlers();
  }

  // Request notification permission
  static Future<void> _requestPermission() async {
    if (_firebaseMessaging == null) return;

    NotificationSettings settings = await _firebaseMessaging!.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    print('User granted permission: ${settings.authorizationStatus}');
  }

  // Initialize local notifications
  static Future<void> _initializeLocalNotifications() async {
    if (_localNotifications == null) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings();

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications!.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onSelectNotification,
    );
  }

  // Setup message handlers
  static void _setupMessageHandlers() {
    if (_firebaseMessaging == null) return;

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification tapped when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
  }

  // Handle foreground messages
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('Received foreground message: ${message.messageId}');

    // Show local notification when app is in foreground
    await _showLocalNotification(
      title: message.notification?.title ?? 'New Notification',
      body: message.notification?.body ?? 'You have a new notification',
      payload: message.data.toString(),
    );
  }

  // Handle message opened app
  static Future<void> _handleMessageOpenedApp(RemoteMessage message) async {
    print('Message opened app: ${message.messageId}');
    // Handle navigation based on message data
    _handleNotificationTap(message.data);
  }

  // Background message handler
  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    print('Handling background message: ${message.messageId}');
  }

  // Show local notification
  static Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (_localNotifications == null) return;

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'del_pick_channel',
      'Del-Pick Notifications',
      channelDescription: 'Notifications for Del-Pick app',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
    DarwinNotificationDetails();

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _localNotifications!.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  // Handle notification selection
  static void _onSelectNotification(NotificationResponse response) {
    final String? payload = response.payload;
    if (payload != null) {
      print('Notification payload: $payload');
      // Handle notification tap
      _handleNotificationTap(null);
    }
  }

  // Handle notification tap
  static void _handleNotificationTap(Map<String, dynamic>? data) {
    // Implement navigation logic based on notification data
    // Example: Navigate to order details, driver tracking, etc.
    print('Handling notification tap with data: $data');
  }

  // Get FCM token
  static Future<String?> getFCMToken() async {
    if (_firebaseMessaging == null) return null;
    return await _firebaseMessaging!.getToken();
  }

  // Subscribe to topic
  static Future<void> subscribeToTopic(String topic) async {
    if (_firebaseMessaging == null) return;
    await _firebaseMessaging!.subscribeToTopic(topic);
  }

  // Unsubscribe from topic
  static Future<void> unsubscribeFromTopic(String topic) async {
    if (_firebaseMessaging == null) return;
    await _firebaseMessaging!.unsubscribeFromTopic(topic);
  }

  // Update FCM token on server
  static Future<void> updateFCMTokenOnServer() async {
    final token = await getFCMToken();
    if (token != null && AuthManager.isLoggedIn) {
      try {
        // Update user profile with FCM token
        await UserService.updateProfile({'fcm_token': token});
      } catch (e) {
        print('Failed to update FCM token on server: $e');
      }
    }
  }
}