// lib/Views/Component/driver_notification_badge_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Services/driver_enhanced_notification_service.dart';

// ========================================
// 1. Driver Notification Service untuk Home Driver
// ========================================

class DriverNotificationService {
  static final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();
  static final AudioPlayer _audioPlayer = AudioPlayer();

  // Badge counter untuk driver
  static int _badgeCount = 0;
  static List<Map<String, dynamic>> _pendingNotifications = [];

  // Initialize notification service untuk driver
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
      'driver_requests_channel',
      'Permintaan Driver',
      description: 'Notifikasi untuk permintaan delivery baru',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: Colors.blue,
    );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // Enhanced permission request untuk driver
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
              const Text('Izin Notifikasi Driver',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  children: [
                    Icon(Icons.local_shipping, color: Colors.blue.shade700, size: 32),
                    const SizedBox(height: 8),
                    Text(
                      'Dapatkan notifikasi untuk:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700,
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
                            Text('• Permintaan delivery baru', style: TextStyle(fontSize: 14)),
                          ],
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green, size: 16),
                            SizedBox(width: 8),
                            Text('• Update status orderan', style: TextStyle(fontSize: 14)),
                          ],
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green, size: 16),
                            SizedBox(width: 8),
                            Text('• Informasi penting', style: TextStyle(fontSize: 14)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Driver memerlukan izin notifikasi untuk menerima permintaan delivery baru dan update status orderan.',
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

  // Show notification dengan badge untuk driver request
  static Future<void> showDriverRequestNotification({
    required Map<String, dynamic> requestData,
    required BuildContext context,
  }) async {
    try {
      // Play notification sound
      await _playNotificationSound();

      // Increment badge count
      _badgeCount++;
      _pendingNotifications.add(requestData);

      // Extract request information
      final requestId = requestData['id']?.toString() ?? '';
      final order = requestData['order'] ?? {};
      final customerName = order['customer']?['name'] ?? order['user']?['name'] ?? 'Customer';
      final storeName = order['store']?['name'] ?? 'Store';
      final totalAmount = _parseDouble(order['total_amount'] ?? order['totalAmount'] ?? order['total']) ?? 0.0;
      final deliveryFee = _parseDouble(order['delivery_fee'] ?? order['deliveryFee']) ?? 0.0;
      final orderId = order['id']?.toString() ?? '';

      // Create notification
      final androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'driver_requests_channel',
        'Permintaan Driver',
        channelDescription: 'Notifikasi untuk permintaan delivery baru',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        when: DateTime.now().millisecondsSinceEpoch,
        icon: '@mipmap/ic_launcher',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        color: Colors.blue,
        enableLights: true,
        enableVibration: true,
        playSound: false, // We handle sound separately
        number: _badgeCount, // Badge count
        ticker: 'Permintaan delivery baru!',
        styleInformation: BigTextStyleInformation(
          'Customer: $customerName\n'
              'Store: $storeName\n'
              'Total Order: ${GlobalStyle.formatRupiah(totalAmount)}\n'
              'Delivery Fee: ${GlobalStyle.formatRupiah(deliveryFee)}\n'
              'Ketuk untuk melihat detail',
          htmlFormatBigText: false,
          contentTitle: 'Permintaan Delivery Baru! 🚗',
          htmlFormatContentTitle: false,
          summaryText: 'Order #$orderId',
          htmlFormatSummaryText: false,
        ),
        actions: [
          AndroidNotificationAction(
            'view_request',
            'Lihat Detail',
            icon: DrawableResourceAndroidBitmap('@drawable/ic_visibility'),
          ),
          AndroidNotificationAction(
            'accept_request',
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
        subtitle: 'Permintaan Delivery',
        threadIdentifier: 'driver_requests',
      );

      final platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await _flutterLocalNotificationsPlugin.show(
        requestId.hashCode, // Unique ID based on request ID
        'Permintaan Delivery Baru! 🚗',
        'Customer: $customerName • Store: $storeName • ${GlobalStyle.formatRupiah(totalAmount)}',
        platformChannelSpecifics,
        payload: 'request_$requestId',
      );

      print('✅ Driver notification sent for request: $requestId');
    } catch (e) {
      print('❌ Error showing driver notification: $e');
    }
  }

  // Play notification sound
  static Future<void> _playNotificationSound() async {
    try {
      await _audioPlayer.play(AssetSource('audio/kring.mp3'));
      print('🔊 Driver notification sound played');
    } catch (e) {
      print('❌ Error playing driver notification sound: $e');
    }
  }

  // Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    print('🔔 Driver notification tapped: ${response.payload}');
    // Handle navigation or actions here
    if (response.payload?.startsWith('request_') == true) {
      final requestId = response.payload!.substring(8);
      // Navigate to request detail or refresh home
      // This can be handled through a global navigator or callback
    }
  }

  // Clear badge count
  static Future<void> clearBadgeCount() async {
    try {
      _badgeCount = 0;
      _pendingNotifications.clear();
      await _flutterLocalNotificationsPlugin.cancelAll();
      print('🧹 Driver badge count cleared');
    } catch (e) {
      print('❌ Error clearing driver badge count: $e');
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
      print('🗑️ DriverNotificationService disposed');
    } catch (e) {
      print('❌ Error disposing DriverNotificationService: $e');
    }
  }
}

// ========================================
// 2. Driver Notification Badge Widget
// ========================================

class DriverNotificationBadgeWidget extends StatefulWidget {
  final Widget child;
  final int count;
  final Color? badgeColor;
  final Color? textColor;
  final double? fontSize;
  final EdgeInsets? padding;

  const DriverNotificationBadgeWidget({
    Key? key,
    required this.child,
    required this.count,
    this.badgeColor,
    this.textColor,
    this.fontSize = 10,
    this.padding = const EdgeInsets.all(4),
  }) : super(key: key);

  @override
  State<DriverNotificationBadgeWidget> createState() => _DriverNotificationBadgeWidgetState();
}

class _DriverNotificationBadgeWidgetState extends State<DriverNotificationBadgeWidget>
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
  void didUpdateWidget(DriverNotificationBadgeWidget oldWidget) {
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
// 3. Driver Notification Card Widget
// ========================================

class DriverNotificationCardWidget extends StatelessWidget {
  final Map<String, dynamic> requestData;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  const DriverNotificationCardWidget({
    Key? key,
    required this.requestData,
    this.onTap,
    this.onDismiss,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final requestId = requestData['id']?.toString() ?? '';
    final order = requestData['order'] ?? {};
    final customerName = order['customer']?['name'] ?? order['user']?['name'] ?? 'Customer';
    final storeName = order['store']?['name'] ?? 'Store';
    final totalAmount = _parseDouble(order['total_amount'] ?? order['totalAmount'] ?? order['total']) ?? 0.0;
    final deliveryFee = _parseDouble(order['delivery_fee'] ?? order['deliveryFee']) ?? 0.0;
    final orderId = order['id']?.toString() ?? '';
    final createdAt = requestData['created_at'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.blue.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
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
                          colors: [Colors.blue, Color(0xFF2196F3)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.local_shipping,
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
                            'Permintaan Delivery Baru!',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.blue.shade700,
                              fontFamily: GlobalStyle.fontFamily,
                            ),
                          ),
                          Text(
                            'Request #$requestId',
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
                          Icon(Icons.store, color: Colors.grey.shade600, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              storeName,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                                fontFamily: GlobalStyle.fontFamily,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Fee: ${GlobalStyle.formatRupiah(deliveryFee)}',
                              style: TextStyle(
                                color: Colors.green[700],
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.assignment, color: Colors.grey.shade600, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Order #$orderId',
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
                      'Lihat Detail Permintaan',
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
// 4. Driver Notification Badge Card (In-app overlay)
// ========================================

class DriverNotificationBadgeCard extends StatefulWidget {
  final Map<String, dynamic> requestData;
  final bool isVisible;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;
  final Duration autoHideDuration;

  const DriverNotificationBadgeCard({
    Key? key,
    required this.requestData,
    required this.isVisible,
    this.onTap,
    this.onDismiss,
    this.autoHideDuration = const Duration(seconds: 5),
  }) : super(key: key);

  @override
  State<DriverNotificationBadgeCard> createState() => _DriverNotificationBadgeCardState();
}

class _DriverNotificationBadgeCardState extends State<DriverNotificationBadgeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    if (widget.isVisible) {
      _animationController.forward();
    }
  }

  @override
  void didUpdateWidget(DriverNotificationBadgeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible && !oldWidget.isVisible) {
      _animationController.forward();
    } else if (!widget.isVisible && oldWidget.isVisible) {
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
    final order = widget.requestData['order'] ?? {};
    final customerName = order['customer']?['name'] ?? order['user']?['name'] ?? 'Customer';
    final storeName = order['store']?['name'] ?? 'Store';
    final totalAmount = _parseDouble(order['total_amount'] ?? order['totalAmount'] ?? order['total']) ?? 0.0;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.blue.shade50,
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade300, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Icon
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.local_shipping,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Permintaan Delivery Baru!',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$customerName → $storeName',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            GlobalStyle.formatRupiah(totalAmount),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: GlobalStyle.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Actions
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.onDismiss != null)
                          GestureDetector(
                            onTap: widget.onDismiss,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Ketuk',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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
}