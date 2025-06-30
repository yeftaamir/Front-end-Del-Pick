// lib/Services/enhanced_notification_service.dart
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:del_pick/Common/global_style.dart';

class EnhancedNotificationService {
  static final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();
  static final AudioPlayer _audioPlayer = AudioPlayer();

  // Badge counter untuk tracking notifikasi
  static int _badgeCount = 0;

  // Callback untuk handling notification tap
  static Function(String)? onNotificationTap;

  /// Initialize notification service dengan badge support
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

  /// Show notification dengan badge dan sound kring.mp3
  static Future<void> showNewOrderNotification({
    required Map<String, dynamic> orderData,
    bool playSound = true,
    bool updateBadge = true,
  }) async {
    try {
      // Parse order data
      final orderId = orderData['id']?.toString() ?? '';
      final customerName = orderData['customer']?['name'] ?? 'Customer';
      final totalAmount = _parseDouble(orderData['total_amount']) ?? 0.0;
      final itemCount = orderData['items']?.length ?? 0;

      // Update badge count
      if (updateBadge) {
        _badgeCount++;
      }

      // Play kring.mp3 sound
      if (playSound) {
        await _playKringSound();
      }

      // Android notification details dengan badge
      final AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
        'new_order_channel',
        'Pesanan Baru',
        channelDescription: 'Notifikasi untuk pesanan baru yang masuk',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'Pesanan Baru Masuk',
        showWhen: true,
        autoCancel: true,
        enableVibration: true,
        enableLights: true,
        color: GlobalStyle.primaryColor,
        colorized: true,
        number: _badgeCount, // Badge count untuk Android
        icon: '@mipmap/ic_launcher',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: BigTextStyleInformation(
          'Pelanggan: $customerName\n'
              'Total: ${GlobalStyle.formatRupiah(totalAmount)}\n'
              'Jumlah item: $itemCount',
          contentTitle: 'Pesanan Baru Masuk! 🔔',
          summaryText: 'Order #$orderId',
        ),
        actions: [
          AndroidNotificationAction(
            'view_order',
            'Lihat Pesanan',
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
        badgeNumber: _badgeCount, // Badge count untuk iOS
        subtitle: 'Order #$orderId',
        sound: 'kring.mp3', // Custom sound file
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
        categoryIdentifier: 'NEW_ORDER_CATEGORY',
      );

      final NotificationDetails platformChannelSpecifics =
      NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      // Show notification
      await _flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        '🔔 Pesanan Baru Masuk!',
        'Pelanggan: $customerName • ${GlobalStyle.formatRupiah(totalAmount)}',
        platformChannelSpecifics,
        payload: orderId,
      );

      print('✅ Enhanced notification sent for order #$orderId');
      print('   - Badge count: $_badgeCount');
      print('   - Customer: $customerName');
      print('   - Amount: ${GlobalStyle.formatRupiah(totalAmount)}');

    } catch (e) {
      print('❌ Error showing enhanced notification: $e');
    }
  }

  /// Play kring.mp3 sound
  static Future<void> _playKringSound() async {
    try {
      await _audioPlayer.play(AssetSource('audio/kring.mp3'));
      print('🔊 Kring.mp3 sound played successfully');
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

  /// Show grouped notification untuk multiple orders
  static Future<void> showGroupedOrderNotification({
    required List<Map<String, dynamic>> orders,
    bool playSound = true,
  }) async {
    try {
      if (orders.isEmpty) return;

      // Update badge count
      _badgeCount += orders.length;

      // Play sound
      if (playSound) {
        await _playKringSound();
      }

      final String groupKey = 'new_orders_group';
      final String groupChannelId = 'grouped_orders_channel';

      // Create individual notifications untuk setiap order
      for (int i = 0; i < orders.length; i++) {
        final order = orders[i];
        final orderId = order['id']?.toString() ?? '';
        final customerName = order['customer']?['name'] ?? 'Customer';
        final totalAmount = _parseDouble(order['total_amount']) ?? 0.0;

        final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          groupChannelId,
          'Pesanan Baru Grup',
          channelDescription: 'Notifikasi grup untuk pesanan baru',
          importance: Importance.max,
          priority: Priority.high,
          groupKey: groupKey,
          setAsGroupSummary: false,
          autoCancel: true,
          number: _badgeCount,
          styleInformation: BigTextStyleInformation(
            'Pelanggan: $customerName\n'
                'Total: ${GlobalStyle.formatRupiah(totalAmount)}',
            contentTitle: 'Pesanan Baru #$orderId',
          ),
        );

        await _flutterLocalNotificationsPlugin.show(
          i + 1000, // Unique ID untuk setiap notification
          'Pesanan Baru #$orderId',
          '$customerName • ${GlobalStyle.formatRupiah(totalAmount)}',
          NotificationDetails(android: androidDetails),
          payload: orderId,
        );
      }

      // Create summary notification
      final AndroidNotificationDetails summaryAndroidDetails =
      AndroidNotificationDetails(
        groupChannelId,
        'Pesanan Baru Grup',
        channelDescription: 'Notifikasi grup untuk pesanan baru',
        importance: Importance.max,
        priority: Priority.high,
        groupKey: groupKey,
        setAsGroupSummary: true,
        number: _badgeCount,
        styleInformation: InboxStyleInformation(
          orders.map((order) {
            final orderId = order['id']?.toString() ?? '';
            final customerName = order['customer']?['name'] ?? 'Customer';
            final totalAmount = _parseDouble(order['total_amount']) ?? 0.0;
            return '#$orderId - $customerName (${GlobalStyle.formatRupiah(totalAmount)})';
          }).toList(),
          contentTitle: '${orders.length} Pesanan Baru Masuk! 🔔',
          summaryText: 'Tap untuk melihat semua pesanan',
        ),
      );

      await _flutterLocalNotificationsPlugin.show(
        0, // Summary notification ID
        '${orders.length} Pesanan Baru! 🔔',
        'Tap untuk melihat semua pesanan baru',
        NotificationDetails(android: summaryAndroidDetails),
        payload: 'group_orders',
      );

      print('✅ Grouped notification sent for ${orders.length} orders');
      print('   - Total badge count: $_badgeCount');

    } catch (e) {
      print('❌ Error showing grouped notification: $e');
    }
  }

  /// Clear specific notification
  static Future<void> clearNotification(int notificationId) async {
    try {
      await _flutterLocalNotificationsPlugin.cancel(notificationId);
      print('✅ Notification $notificationId cleared');
    } catch (e) {
      print('❌ Error clearing notification: $e');
    }
  }

  /// Clear all notifications
  static Future<void> clearAllNotifications() async {
    try {
      await _flutterLocalNotificationsPlugin.cancelAll();
      print('✅ All notifications cleared');
    } catch (e) {
      print('❌ Error clearing all notifications: $e');
    }
  }

  /// Reset badge count
  static Future<void> resetBadgeCount() async {
    try {
      _badgeCount = 0;

      // Clear badge untuk iOS
      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(badge: true);

      print('✅ Badge count reset to 0');
    } catch (e) {
      print('❌ Error resetting badge count: $e');
    }
  }

  /// Set custom badge count
  static Future<void> setBadgeCount(int count) async {
    try {
      _badgeCount = count;
      print('✅ Badge count set to $count');
    } catch (e) {
      print('❌ Error setting badge count: $e');
    }
  }

  /// Get current badge count
  static int getBadgeCount() {
    return _badgeCount;
  }

  /// Show order processed notification
  static Future<void> showOrderProcessedNotification({
    required String orderId,
    required String action, // 'approved' or 'rejected'
    bool playSound = false,
  }) async {
    try {
      final isApproved = action.toLowerCase() == 'approved';

      final AndroidNotificationDetails androidDetails =
      AndroidNotificationDetails(
        'order_processed_channel',
        'Pesanan Diproses',
        channelDescription: 'Notifikasi untuk pesanan yang sudah diproses',
        importance: Importance.high,
        priority: Priority.high,
        color: isApproved ? GlobalStyle.primaryColor : Colors.orange,
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
        isApproved ? '✅ Pesanan Diterima' : '❌ Pesanan Ditolak',
        'Order #$orderId telah ${isApproved ? 'diterima' : 'ditolak'}',
        NotificationDetails(
          android: androidDetails,
          iOS: iOSDetails,
        ),
        payload: orderId,
      );

      print('✅ Order processed notification sent for #$orderId ($action)');

    } catch (e) {
      print('❌ Error showing order processed notification: $e');
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
      const AndroidNotificationChannel newOrderChannel =
      AndroidNotificationChannel(
        'new_order_channel',
        'Pesanan Baru',
        description: 'Notifikasi untuk pesanan baru yang masuk',
        importance: Importance.max,
        enableVibration: true,
        enableLights: true,
        showBadge: true,
      );

      const AndroidNotificationChannel groupedOrderChannel =
      AndroidNotificationChannel(
        'grouped_orders_channel',
        'Pesanan Baru Grup',
        description: 'Notifikasi grup untuk pesanan baru',
        importance: Importance.max,
        enableVibration: true,
        enableLights: true,
        showBadge: true,
      );

      const AndroidNotificationChannel processedOrderChannel =
      AndroidNotificationChannel(
        'order_processed_channel',
        'Pesanan Diproses',
        description: 'Notifikasi untuk pesanan yang sudah diproses',
        importance: Importance.high,
        enableVibration: false,
        showBadge: false,
      );

      final plugin = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      await plugin?.createNotificationChannel(newOrderChannel);
      await plugin?.createNotificationChannel(groupedOrderChannel);
      await plugin?.createNotificationChannel(processedOrderChannel);

      print('✅ Notification channels created successfully');

    } catch (e) {
      print('❌ Error creating notification channels: $e');
    }
  }

  /// Dispose resources
  static Future<void> dispose() async {
    try {
      await _audioPlayer.dispose();
      print('✅ Enhanced notification service disposed');
    } catch (e) {
      print('❌ Error disposing enhanced notification service: $e');
    }
  }
}