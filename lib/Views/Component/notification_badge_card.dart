// ========================================
// 1. Enhanced Notification Service untuk Home Store
// ========================================

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:del_pick/Common/global_style.dart';

class StoreNotificationService {
  static final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();
  static final AudioPlayer _audioPlayer = AudioPlayer();

  // Badge counter
  static int _badgeCount = 0;
  static List<Map<String, dynamic>> _pendingNotifications = [];

  // Initialize notification service
  static Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    const InitializationSettings initializationSettings =
    InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    await _createNotificationChannel();
  }

  static Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'store_orders_channel',
      'Pesanan Toko',
      description: 'Notifikasi untuk pesanan masuk ke toko',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: Colors.orange,
    );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // Enhanced permission request
  static Future<bool> requestNotificationPermissions(BuildContext context) async {
    try {
      // Check current permission status
      PermissionStatus status = await Permission.notification.status;

      if (status.isGranted) {
        return true;
      }

      if (status.isDenied) {
        // Show permission dialog
        bool shouldRequest = await _showPermissionDialog(context);
        if (!shouldRequest) return false;

        // Request permission
        status = await Permission.notification.request();
      }

      if (status.isPermanentlyDenied) {
        // Show settings dialog
        await _showSettingsDialog(context);
        return false;
      }

      return status.isGranted;
    } catch (e) {
      print('❌ Error requesting notification permissions: $e');
      return false;
    }
  }

  static Future<bool> _showPermissionDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.notifications_active,
                  color: GlobalStyle.primaryColor, size: 28),
              const SizedBox(width: 12),
              const Text('Izin Notifikasi',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  children: [
                    Icon(Icons.store, color: Colors.orange.shade700, size: 32),
                    const SizedBox(height: 8),
                    Text(
                      'Dapatkan notifikasi untuk:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green, size: 16),
                            SizedBox(width: 8),
                            Text('• Pesanan baru masuk', style: TextStyle(fontSize: 14)),
                          ],
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green, size: 16),
                            SizedBox(width: 8),
                            Text('• Update status pesanan', style: TextStyle(fontSize: 14)),
                          ],
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green, size: 16),
                            SizedBox(width: 8),
                            Text('• Pesan penting dari sistem', style: TextStyle(fontSize: 14)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Aplikasi memerlukan izin notifikasi untuk memberitahu Anda tentang pesanan baru yang masuk ke toko.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Nanti Saja',
                  style: TextStyle(color: Colors.grey.shade600)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: GlobalStyle.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Izinkan', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    ) ?? false;
  }

  static Future<void> _showSettingsDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Izin Notifikasi Diperlukan'),
          content: const Text(
            'Notifikasi telah dinonaktifkan. Silakan aktifkan melalui Pengaturan > Aplikasi > Del Pick > Notifikasi.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tutup'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: GlobalStyle.primaryColor,
              ),
              child: const Text('Buka Pengaturan', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // Show notification with badge
  static Future<void> showOrderNotification({
    required Map<String, dynamic> orderData,
    required BuildContext context,
  }) async {
    try {
      // Play notification sound
      await _playNotificationSound();

      // Increment badge count
      _badgeCount++;
      _pendingNotifications.add(orderData);

      // Extract order information
      final orderId = orderData['id']?.toString() ?? '';
      final customerName = orderData['customer']?['name'] ?? 'Customer';
      final totalAmount = _parseDouble(orderData['total_amount']) ?? 0.0;
      final itemCount = orderData['items']?.length ?? 0;

      // Create notification
      final androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'store_orders_channel',
        'Pesanan Toko',
        channelDescription: 'Notifikasi untuk pesanan masuk ke toko',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        when: DateTime.now().millisecondsSinceEpoch,
        icon: '@mipmap/ic_launcher',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        color: Colors.orange,
        enableLights: true,
        enableVibration: true,
        playSound: false, // We handle sound separately
        number: _badgeCount, // Badge count
        ticker: 'Pesanan baru masuk!',
        styleInformation: BigTextStyleInformation(
          'Pelanggan: $customerName\n'
              'Total: ${GlobalStyle.formatRupiah(totalAmount)}\n'
              '$itemCount item pesanan\n'
              'Ketuk untuk melihat detail',
          htmlFormatBigText: false,
          contentTitle: 'Pesanan Baru Masuk! 🛍️',
          htmlFormatContentTitle: false,
          summaryText: 'Order #$orderId',
          htmlFormatSummaryText: false,
        ),
        actions: [
          AndroidNotificationAction(
            'view_order',
            'Lihat Pesanan',
            icon: DrawableResourceAndroidBitmap('@drawable/ic_visibility'),
          ),
          AndroidNotificationAction(
            'accept_order',
            'Terima',
            icon: DrawableResourceAndroidBitmap('@drawable/ic_check'),
          ),
        ],
      );

      const iOSPlatformChannelSpecifics = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: false,
        badgeNumber: null, // Will be set automatically
        subtitle: 'Pesanan Baru',
        threadIdentifier: 'store_orders',
      );

      final platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await _flutterLocalNotificationsPlugin.show(
        orderId.hashCode, // Unique ID based on order ID
        'Pesanan Baru Masuk! 🛍️',
        'Pelanggan: $customerName • ${GlobalStyle.formatRupiah(totalAmount)}',
        platformChannelSpecifics,
        payload: 'order_$orderId',
      );

      print('✅ Notification sent for order: $orderId');
    } catch (e) {
      print('❌ Error showing notification: $e');
    }
  }

  // Play notification sound
  static Future<void> _playNotificationSound() async {
    try {
      await _audioPlayer.play(AssetSource('audio/kring.mp3'));
      print('🔊 Notification sound played');
    } catch (e) {
      print('❌ Error playing notification sound: $e');
    }
  }

  // Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    print('🔔 Notification tapped: ${response.payload}');
    // Handle navigation or actions here
    if (response.payload?.startsWith('order_') == true) {
      final orderId = response.payload!.substring(6);
      // Navigate to order detail or refresh home
      // This can be handled through a global navigator or callback
    }
  }

  // Clear badge count
  static Future<void> clearBadgeCount() async {
    try {
      _badgeCount = 0;
      _pendingNotifications.clear();
      await _flutterLocalNotificationsPlugin.cancelAll();
      print('🧹 Badge count cleared');
    } catch (e) {
      print('❌ Error clearing badge count: $e');
    }
  }

  // Get current badge count
  static int getBadgeCount() => _badgeCount;

  // Get pending notifications
  static List<Map<String, dynamic>> getPendingNotifications() =>
      List.from(_pendingNotifications);

  // Helper method to parse double
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  // Dispose resources
  static Future<void> dispose() async {
    try {
      await _audioPlayer.dispose();
      print('🗑️ StoreNotificationService disposed');
    } catch (e) {
      print('❌ Error disposing StoreNotificationService: $e');
    }
  }
}

// ========================================
// 2. Notification Badge Widget
// ========================================

class NotificationBadgeWidget extends StatefulWidget {
  final Widget child;
  final int count;
  final Color? badgeColor;
  final Color? textColor;
  final double? fontSize;
  final EdgeInsets? padding;

  const NotificationBadgeWidget({
    Key? key,
    required this.child,
    required this.count,
    this.badgeColor,
    this.textColor,
    this.fontSize = 10,
    this.padding = const EdgeInsets.all(4),
  }) : super(key: key);

  @override
  State<NotificationBadgeWidget> createState() => _NotificationBadgeWidgetState();
}

class _NotificationBadgeWidgetState extends State<NotificationBadgeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    if (widget.count > 0) {
      _animationController.forward();
    }
  }

  @override
  void didUpdateWidget(NotificationBadgeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.count > oldWidget.count && widget.count > 0) {
      _animationController.reset();
      _animationController.forward();
    } else if (widget.count == 0) {
      _animationController.reverse();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        if (widget.count > 0)
          Positioned(
            right: -8,
            top: -8,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                padding: widget.padding,
                decoration: BoxDecoration(
                  color: widget.badgeColor ?? Colors.red,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: (widget.badgeColor ?? Colors.red).withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                constraints: const BoxConstraints(
                  minWidth: 18,
                  minHeight: 18,
                ),
                child: Text(
                  widget.count > 99 ? '99+' : widget.count.toString(),
                  style: TextStyle(
                    color: widget.textColor ?? Colors.white,
                    fontSize: widget.fontSize,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ========================================
// 3. Notification Card Widget
// ========================================

class NotificationCardWidget extends StatelessWidget {
  final Map<String, dynamic> notificationData;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  const NotificationCardWidget({
    Key? key,
    required this.notificationData,
    this.onTap,
    this.onDismiss,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final orderId = notificationData['id']?.toString() ?? '';
    final customerName = notificationData['customer']?['name'] ?? 'Customer';
    final totalAmount = _parseDouble(notificationData['total_amount']) ?? 0.0;
    final itemCount = notificationData['items']?.length ?? 0;
    final createdAt = notificationData['created_at'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.orange.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with notification icon and close button
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.orange, Color(0xFFFF8A65)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.notifications_active,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pesanan Baru Masuk!',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.orange.shade700,
                              fontFamily: GlobalStyle.fontFamily,
                            ),
                          ),
                          Text(
                            'Order #$orderId',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                              fontFamily: GlobalStyle.fontFamily,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (onDismiss != null)
                      IconButton(
                        onPressed: onDismiss,
                        icon: Icon(Icons.close, color: Colors.grey.shade400, size: 20),
                        constraints: const BoxConstraints(minHeight: 32, minWidth: 32),
                        padding: EdgeInsets.zero,
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // Customer and order info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person, color: GlobalStyle.primaryColor, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              customerName,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                fontFamily: GlobalStyle.fontFamily,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  GlobalStyle.primaryColor,
                                  GlobalStyle.primaryColor.withOpacity(0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              GlobalStyle.formatRupiah(totalAmount),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.shopping_cart, color: Colors.grey.shade600, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            '$itemCount item pesanan',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                              fontFamily: GlobalStyle.fontFamily,
                            ),
                          ),
                          const Spacer(),
                          if (createdAt != null)
                            Text(
                              _formatTime(createdAt),
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 11,
                                fontFamily: GlobalStyle.fontFamily,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Action button
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.visibility, size: 18, color: Colors.white),
                    label: Text(
                      'Lihat Pesanan',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontFamily: GlobalStyle.fontFamily,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GlobalStyle.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  String _formatTime(String timeStr) {
    try {
      final time = DateTime.parse(timeStr);
      final now = DateTime.now();
      final difference = now.difference(time);

      if (difference.inMinutes < 1) {
        return 'Baru saja';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m yang lalu';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}j yang lalu';
      } else {
        return '${difference.inDays}h yang lalu';
      }
    } catch (e) {
      return 'Baru saja';
    }
  }
}

// ========================================
// 4. Notification History Widget
// ========================================

class NotificationHistoryWidget extends StatefulWidget {
  const NotificationHistoryWidget({Key? key}) : super(key: key);

  @override
  State<NotificationHistoryWidget> createState() => _NotificationHistoryWidgetState();
}

class _NotificationHistoryWidgetState extends State<NotificationHistoryWidget> {
  @override
  Widget build(BuildContext context) {
    final notifications = StoreNotificationService.getPendingNotifications();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.notifications, color: GlobalStyle.primaryColor),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Notifikasi Pesanan',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (notifications.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        StoreNotificationService.clearBadgeCount();
                      });
                    },
                    child: const Text('Hapus Semua'),
                  ),
              ],
            ),
          ),

          // Notifications list
          if (notifications.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada notifikasi',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Notifikasi pesanan baru akan muncul di sini',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  return NotificationCardWidget(
                    notificationData: notification,
                    onTap: () {
                      Navigator.pop(context);
                      // Handle navigation to order detail
                    },
                    onDismiss: () {
                      setState(() {
                        notifications.removeAt(index);
                      });
                    },
                  );
                },
              ),
            ),

          // Bottom padding
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}