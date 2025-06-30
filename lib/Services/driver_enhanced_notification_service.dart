// lib/Services/driver_enhanced_notification_service.dart
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:del_pick/Common/global_style.dart';

class DriverEnhancedNotificationService {
  static final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();
  static final AudioPlayer _audioPlayer = AudioPlayer();

  // Badge counter untuk tracking notifikasi driver
  static int _driverBadgeCount = 0;

  // Callback untuk handling notification tap
  static Function(String)? onNotificationTap;

  /// Initialize notification service dengan badge support untuk driver
  static Future<void> initialize({
    Function(String)? onTap,
  }) async {
    onNotificationTap = onTap;

    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
      requestCriticalPermission: true,
    );

    const InitializationSettings initializationSettings =
    InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        if (details.payload != null && onNotificationTap != null) {
          onNotificationTap!(details.payload!);
        }
      },
    );

    // Request permissions
    await _requestPermissions();
  }

  /// Request semua permissions yang diperlukan
  static Future<void> _requestPermissions() async {
    await Permission.notification.request();

    // Android 13+ notification permission
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    // iOS badge permission
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
      critical: true,
    );
  }

  /// Show notification untuk driver request baru dengan badge dan sound kring.mp3
  static Future<void> showNewDriverRequestNotification({
    required Map<String, dynamic> requestData,
    bool playSound = true,
    bool updateBadge = true,
  }) async {
    try {
      // Parse request data
      final requestId = requestData['id']?.toString() ?? '';
      final order = requestData['order'] ?? {};
      final orderId = order['id']?.toString() ?? '';
      final customerName = order['customer']?['name'] ??
          order['user']?['name'] ?? 'Customer';
      final storeName = order['store']?['name'] ?? 'Store';
      final totalAmount = _parseDouble(order['total_amount'] ??
          order['totalAmount'] ??
          order['total']) ?? 0.0;
      final deliveryFee = _parseDouble(order['delivery_fee'] ??
          order['deliveryFee']) ?? 0.0;

      // Calculate potential earnings (delivery fee + 5% commission)
      final potentialEarnings = deliveryFee + (totalAmount * 0.05);

      // Update badge count
      if (updateBadge) {
        _driverBadgeCount++;
      }

      // Play kring.mp3 sound
      if (playSound) {
        await _playKringSound();
      }

      // Android notification details dengan badge
      final AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
        'driver_request_channel',
        'Permintaan Antar',
        channelDescription: 'Notifikasi untuk permintaan pengantaran baru',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'Permintaan Antar Baru',
        showWhen: true,
        autoCancel: true,
        enableVibration: true,
        enableLights: true,
        color: Colors.blue,
        colorized: true,
        number: _driverBadgeCount, // Badge count untuk Android
        icon: '@mipmap/ic_launcher',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: BigTextStyleInformation(
          'Customer: $customerName\n'
              'Store: $storeName\n'
              'Order Total: ${GlobalStyle.formatRupiah(totalAmount)}\n'
              'Est. Earning: ${GlobalStyle.formatRupiah(potentialEarnings)}',
          contentTitle: '🚗 Permintaan Antar Baru! 🔔',
          summaryText: 'Order #$orderId',
        ),
        actions: [
          AndroidNotificationAction(
            'view_request',
            'Lihat Permintaan',
            icon: DrawableResourceAndroidBitmap('@drawable/ic_visibility'),
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            'dismiss',
            'Tutup',
            icon: DrawableResourceAndroidBitmap('@drawable/ic_close'),
            cancelNotification: true,
          ),
        ],
      );

      // iOS notification details dengan badge
      final DarwinNotificationDetails iOSPlatformChannelSpecifics =
      DarwinNotificationDetails(
        badgeNumber: _driverBadgeCount, // Badge count untuk iOS
        subtitle: 'Order #$orderId',
        sound: 'kring.mp3', // Custom sound file
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
        categoryIdentifier: 'DRIVER_REQUEST_CATEGORY',
      );

      final NotificationDetails platformChannelSpecifics =
      NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      // Show notification
      await _flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        '🚗 Permintaan Antar Baru!',
        '$customerName → $storeName • Est. ${GlobalStyle.formatRupiah(potentialEarnings)}',
        platformChannelSpecifics,
        payload: requestId,
      );

      print('✅ Driver notification sent for request #$requestId');
      print('   - Badge count: $_driverBadgeCount');
      print('   - Customer: $customerName');
      print('   - Store: $storeName');
      print('   - Potential Earnings: ${GlobalStyle.formatRupiah(potentialEarnings)}');

    } catch (e) {
      print('❌ Error showing driver notification: $e');
    }
  }

  /// Play kring.mp3 sound
  static Future<void> _playKringSound() async {
    try {
      await _audioPlayer.play(AssetSource('audio/kring.mp3'));
      print('🔊 Kring.mp3 sound played successfully for driver');
    } catch (e) {
      print('❌ Error playing kring.mp3: $e');
      // Fallback ke sound system default
      try {
        await _audioPlayer.play(AssetSource('audio/notification.wav'));
      } catch (fallbackError) {
        print('❌ Fallback sound also failed: $fallbackError');
      }
    }
  }

  /// Show grouped notification untuk multiple driver requests
  static Future<void> showGroupedDriverRequestNotification({
    required List<Map<String, dynamic>> requests,
    bool playSound = true,
  }) async {
    try {
      if (requests.isEmpty) return;

      // Update badge count
      _driverBadgeCount += requests.length;

      // Play sound
      if (playSound) {
        await _playKringSound();
      }

      final String groupKey = 'driver_requests_group';
      final String groupChannelId = 'grouped_driver_requests_channel';

      // Create individual notifications untuk setiap request
      for (int i = 0; i < requests.length; i++) {
        final request = requests[i];
        final requestId = request['id']?.toString() ?? '';
        final order = request['order'] ?? {};
        final customerName = order['customer']?['name'] ?? 'Customer';
        final storeName = order['store']?['name'] ?? 'Store';
        final totalAmount = _parseDouble(order['total_amount']) ?? 0.0;
        final deliveryFee = _parseDouble(order['delivery_fee']) ?? 0.0;
        final potentialEarnings = deliveryFee + (totalAmount * 0.05);

        final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          groupChannelId,
          'Permintaan Antar Grup',
          channelDescription: 'Notifikasi grup untuk permintaan pengantaran',
          importance: Importance.max,
          priority: Priority.high,
          groupKey: groupKey,
          setAsGroupSummary: false,
          autoCancel: true,
          number: _driverBadgeCount,
          styleInformation: BigTextStyleInformation(
            '$customerName → $storeName\n'
                'Est. Earning: ${GlobalStyle.formatRupiah(potentialEarnings)}',
            contentTitle: 'Permintaan Antar #$requestId',
          ),
        );

        await _flutterLocalNotificationsPlugin.show(
          i + 2000, // Unique ID untuk setiap notification
          'Permintaan Antar #$requestId',
          '$customerName → $storeName • ${GlobalStyle.formatRupiah(potentialEarnings)}',
          NotificationDetails(android: androidDetails),
          payload: requestId,
        );
      }

      // Create summary notification
      final AndroidNotificationDetails summaryAndroidDetails =
      AndroidNotificationDetails(
        groupChannelId,
        'Permintaan Antar Grup',
        channelDescription: 'Notifikasi grup untuk permintaan pengantaran',
        importance: Importance.max,
        priority: Priority.high,
        groupKey: groupKey,
        setAsGroupSummary: true,
        number: _driverBadgeCount,
        styleInformation: InboxStyleInformation(
          requests.map((request) {
            final requestId = request['id']?.toString() ?? '';
            final order = request['order'] ?? {};
            final customerName = order['customer']?['name'] ?? 'Customer';
            final storeName = order['store']?['name'] ?? 'Store';
            final deliveryFee = _parseDouble(order['delivery_fee']) ?? 0.0;
            final totalAmount = _parseDouble(order['total_amount']) ?? 0.0;
            final potentialEarnings = deliveryFee + (totalAmount * 0.05);
            return '#$requestId - $customerName → $storeName (${GlobalStyle.formatRupiah(potentialEarnings)})';
          }).toList(),
          contentTitle: '${requests.length} Permintaan Antar Baru! 🚗',
          summaryText: 'Tap untuk melihat semua permintaan',
        ),
      );

      await _flutterLocalNotificationsPlugin.show(
        1000, // Summary notification ID untuk driver
        '${requests.length} Permintaan Antar! 🚗',
        'Tap untuk melihat semua permintaan pengantaran',
        NotificationDetails(android: summaryAndroidDetails),
        payload: 'group_driver_requests',
      );

      print('✅ Grouped driver notification sent for ${requests.length} requests');
      print('   - Total badge count: $_driverBadgeCount');

    } catch (e) {
      print('❌ Error showing grouped driver notification: $e');
    }
  }

  /// Clear specific notification
  static Future<void> clearNotification(int notificationId) async {
    try {
      await _flutterLocalNotificationsPlugin.cancel(notificationId);
      print('✅ Driver notification $notificationId cleared');
    } catch (e) {
      print('❌ Error clearing driver notification: $e');
    }
  }

  /// Clear all notifications
  static Future<void> clearAllNotifications() async {
    try {
      await _flutterLocalNotificationsPlugin.cancelAll();
      print('✅ All driver notifications cleared');
    } catch (e) {
      print('❌ Error clearing all driver notifications: $e');
    }
  }

  /// Reset badge count
  static Future<void> resetBadgeCount() async {
    try {
      _driverBadgeCount = 0;

      // Clear badge untuk iOS
      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(badge: true);

      print('✅ Driver badge count reset to 0');
    } catch (e) {
      print('❌ Error resetting driver badge count: $e');
    }
  }

  /// Set custom badge count
  static Future<void> setBadgeCount(int count) async {
    try {
      _driverBadgeCount = count;
      print('✅ Driver badge count set to $count');
    } catch (e) {
      print('❌ Error setting driver badge count: $e');
    }
  }

  /// Get current badge count
  static int getBadgeCount() {
    return _driverBadgeCount;
  }

  /// Show request processed notification
  static Future<void> showRequestProcessedNotification({
    required String requestId,
    required String action, // 'accepted' or 'rejected'
    bool playSound = false,
  }) async {
    try {
      final isAccepted = action.toLowerCase() == 'accepted';

      final AndroidNotificationDetails androidDetails =
      AndroidNotificationDetails(
        'driver_request_processed_channel',
        'Permintaan Diproses',
        channelDescription: 'Notifikasi untuk permintaan yang sudah diproses',
        importance: Importance.high,
        priority: Priority.high,
        color: isAccepted ? Colors.green : Colors.orange,
        icon: '@mipmap/ic_launcher',
      );

      final DarwinNotificationDetails iOSDetails =
      DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false, // Tidak update badge untuk processed notification
        presentSound: playSound,
      );

      await _flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        isAccepted ? '✅ Permintaan Diterima' : '❌ Permintaan Ditolak',
        'Request #$requestId telah ${isAccepted ? 'diterima' : 'ditolak'}',
        NotificationDetails(
          android: androidDetails,
          iOS: iOSDetails,
        ),
        payload: requestId,
      );

      print('✅ Driver request processed notification sent for #$requestId ($action)');

    } catch (e) {
      print('❌ Error showing driver request processed notification: $e');
    }
  }

  /// Parse double value safely
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// Create notification channel untuk Android
  static Future<void> createNotificationChannels() async {
    try {
      const AndroidNotificationChannel driverRequestChannel =
      AndroidNotificationChannel(
        'driver_request_channel',
        'Permintaan Antar',
        description: 'Notifikasi untuk permintaan pengantaran baru',
        importance: Importance.max,
        enableVibration: true,
        enableLights: true,
        showBadge: true,
      );

      const AndroidNotificationChannel groupedDriverRequestChannel =
      AndroidNotificationChannel(
        'grouped_driver_requests_channel',
        'Permintaan Antar Grup',
        description: 'Notifikasi grup untuk permintaan pengantaran',
        importance: Importance.max,
        enableVibration: true,
        enableLights: true,
        showBadge: true,
      );

      const AndroidNotificationChannel processedDriverRequestChannel =
      AndroidNotificationChannel(
        'driver_request_processed_channel',
        'Permintaan Diproses',
        description: 'Notifikasi untuk permintaan yang sudah diproses',
        importance: Importance.high,
        enableVibration: false,
        showBadge: false,
      );

      final plugin = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      await plugin?.createNotificationChannel(driverRequestChannel);
      await plugin?.createNotificationChannel(groupedDriverRequestChannel);
      await plugin?.createNotificationChannel(processedDriverRequestChannel);

      print('✅ Driver notification channels created successfully');

    } catch (e) {
      print('❌ Error creating driver notification channels: $e');
    }
  }

  /// Dispose resources
  static Future<void> dispose() async {
    try {
      await _audioPlayer.dispose();
      print('✅ Driver enhanced notification service disposed');
    } catch (e) {
      print('❌ Error disposing driver enhanced notification service: $e');
    }
  }
}