import 'dart:async';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:geolocator/geolocator.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Views/Component/driver_bottom_navigation.dart';
import 'package:del_pick/Views/Driver/history_driver_detail.dart';
import 'package:del_pick/Views/Driver/profil_driver.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:lottie/lottie.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:del_pick/Services/driver_service.dart';
import 'package:del_pick/Services/auth_service.dart';
import 'package:del_pick/Services/image_service.dart';
import 'package:del_pick/Services/location_service.dart';
import 'package:del_pick/Services/order_service.dart';
import 'package:badges/badges.dart' as badges;
import 'package:url_launcher/url_launcher.dart';

class HomeDriverPage extends StatefulWidget {
  static const String route = '/Driver/HomePage';
  const HomeDriverPage({Key? key}) : super(key: key);

  @override
  State<HomeDriverPage> createState() => _HomeDriverPageState();
}

class _HomeDriverPageState extends State<HomeDriverPage> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late List<AnimationController> _cardControllers = [];
  late List<Animation<Offset>> _cardAnimations = [];
  bool _isDriverActive = false;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Location service for tracking
  final LocationService _locationService = LocationService();
  bool _isLocationServiceInitialized = false;

  // Data storage - Simplified structure
  List<Map<String, dynamic>> _allOrders = []; // All orders including new requests and active orders
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isLocaleInitialized = false;
  bool _isTogglingStatus = false;

  // Store current driver data
  Map<String, dynamic>? _driverData;
  String? _driverId;

  // Track previous orders count for new order detection
  int _previousOrdersCount = 0;

  // Notification badge counter
  int _notificationCount = 0;

  // Timer for periodic updates
  Timer? _ordersUpdateTimer;

  // Track active dialogs to prevent multiple notifications
  bool _isShowingNewOrderDialog = false;

  @override
  void initState() {
    super.initState();

    // Initialize locale data for date formatting
    _initializeLocaleData();

    // Initialize with empty controllers and animations
    _cardControllers = [];
    _cardAnimations = [];

    // Initialize notifications
    _initializeNotifications();

    // Request necessary permissions
    _requestPermissions();

    // Check if driver is already active
    _fetchDriverInfo();

    // Load orders
    _loadDriverOrders();

    // Setup periodic updates
    _setupPeriodicUpdates();
  }

  // Initialize locale data for date formatting
  Future<void> _initializeLocaleData() async {
    try {
      await initializeDateFormatting('id_ID', null);
      setState(() {
        _isLocaleInitialized = true;
      });
    } catch (e) {
      print('Error initializing locale data: $e');
      // We'll still set the flag to true to avoid blocking UI
      setState(() {
        _isLocaleInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    // Clean up animation controllers
    for (var controller in _cardControllers) {
      controller.dispose();
    }

    // Dispose audio player
    _audioPlayer.dispose();

    // Stop location tracking
    _locationService.stopTracking();

    // Cancel all timers
    _ordersUpdateTimer?.cancel();

    super.dispose();
  }

  // Setup enhanced periodic updates
  void _setupPeriodicUpdates() {
    _ordersUpdateTimer?.cancel();

    // Fetch orders every 15 seconds if driver is active
    _ordersUpdateTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted && _isDriverActive) {
        _loadDriverOrders();
      } else if (!mounted) {
        timer.cancel();
      }
    });
  }

  Future<void> _fetchDriverInfo() async {
    try {
      // Get fresh profile data from server
      final userData = await AuthService.getProfile();

      if (userData != null && userData['driver'] != null) {
        setState(() {
          _driverData = userData['driver'];
          _driverId = _driverData!['id']?.toString();
          _isDriverActive = _driverData!['status'] == 'active';
        });

        if (_isDriverActive) {
          // Start location tracking if driver is active
          await _startLocationTracking();
        }
      } else {
        // Try to get from local storage as fallback
        final localUserData = await AuthService.getUserData();
        if (localUserData != null && localUserData['driver'] != null) {
          setState(() {
            _driverData = localUserData['driver'];
            _driverId = _driverData!['id']?.toString();
            _isDriverActive = _driverData!['status'] == 'active';
          });

          if (_isDriverActive) {
            // Start location tracking if driver is active
            await _startLocationTracking();
          }
        }
      }
    } catch (e) {
      print('Error fetching driver information: $e');
      setState(() {
        _hasError = true;
        _errorMessage = 'Failed to load driver information: $e';
      });
    }
  }

  // Enhanced: Load driver orders - both new requests and active orders
  Future<void> _loadDriverOrders() async {
    if (!mounted) return;

    setState(() {
      if (_allOrders.isEmpty) {
        _isLoading = true;
      }
      _hasError = false;
    });

    try {
      // Get driver orders from OrderService
      final response = await OrderService.getDriverOrders();

      List<Map<String, dynamic>> processedOrders = [];

      // Handle response structure
      if (response is Map<String, dynamic>) {
        // Check if response has 'orders' key
        if (response.containsKey('orders') && response['orders'] is List) {
          final List<dynamic> ordersList = response['orders'];
          for (var orderItem in ordersList) {
            if (orderItem is Map<String, dynamic>) {
              final processedOrder = _processDriverOrder(orderItem);
              if (processedOrder != null) {
                processedOrders.add(processedOrder);
              }
            }
          }
        }
      }

      // Check for new orders and show notifications
      if (processedOrders.length > _previousOrdersCount &&
          _isDriverActive &&
          _previousOrdersCount > 0) {

        // Find new orders (pending orders that weren't in the previous list)
        final newIncomingOrders = processedOrders
            .where((order) => order['status'] == 'pending')
            .toList();

        for (var newOrder in newIncomingOrders) {
          _notificationCount++;
          await _showNotification(newOrder);
          await _showNewOrderDialog(newOrder);
        }
      }

      setState(() {
        _allOrders = processedOrders;
        _previousOrdersCount = processedOrders.length;
        _isLoading = false;

        // Sort orders by priority
        _sortOrdersByPriority();
      });
    } catch (e) {
      print('Error loading driver orders: $e');
      setState(() {
        _isLoading = false;
        if (_allOrders.isEmpty) {
          _hasError = true;
          _errorMessage = 'Failed to load orders: $e';
        }
      });
    }
  }

  // Process driver order data
  Map<String, dynamic>? _processDriverOrder(Map<String, dynamic> orderData) {
    try {
      final customerData = orderData['user'] ?? orderData['customer'] ?? {};
      final storeData = orderData['store'] ?? {};
      final orderItems = orderData['orderItems'] ?? orderData['items'] ?? [];

      // Determine if this is a new incoming order (request) or an active order
      final bool isPendingRequest = (orderData['order_status'] == 'pending' ||
          orderData['status'] == 'pending') &&
          orderData['driver_status'] == null;

      // Get customer avatar
      String customerAvatar = '';
      if (customerData['avatar'] != null && customerData['avatar'].toString().isNotEmpty) {
        customerAvatar = ImageService.getImageUrl(customerData['avatar']);
      }

      return {
        'id': orderData['id']?.toString() ?? '',
        'code': orderData['code']?.toString() ?? '',
        'customerName': customerData['name'] ?? 'Unknown Customer',
        'customerAvatar': customerAvatar,
        'customerPhone': customerData['phone'] ?? customerData['phoneNumber'] ?? '',
        'orderTime': _parseDateTime(orderData['created_at'] ?? orderData['createdAt']),
        'totalPrice': _parseDouble(orderData['total'] ?? 0),
        'status': _mapOrderStatusToDeliveryStatus(
            orderData['order_status'] ?? orderData['status'],
            orderData['delivery_status'] ?? orderData['deliveryStatus']
        ),
        'isPendingRequest': isPendingRequest, // Flag to identify new incoming orders
        'items': orderItems,
        'deliveryFee': _parseDouble(orderData['service_charge'] ?? orderData['serviceCharge'] ?? 0),
        'amount': _parseDouble(orderData['total'] ?? 0),
        'storeAddress': storeData['address'] ?? 'No Address',
        'storeName': storeData['name'] ?? 'Unknown Store',
        'storePhone': storeData['phone'] ?? storeData['phoneNumber'] ?? '',
        'customerAddress': orderData['delivery_address'] ?? orderData['deliveryAddress'] ?? 'No Address',
        'orderDetail': orderData,
      };
    } catch (e) {
      print('Error processing driver order: $e');
      return null;
    }
  }

  // Sort orders by priority
  void _sortOrdersByPriority() {
    // Sort orders: pending requests -> picking_up -> delivering -> delivered
    _allOrders.sort((a, b) {
      final statusPriority = {
        'pending': 0,
        'assigned': 1,
        'picking_up': 2,
        'delivering': 3,
        'delivered': 4,
        'cancelled': 5,
      };

      final aStatus = a['status'];
      final bStatus = b['status'];

      // Prioritize pending requests
      if (a['isPendingRequest'] && !b['isPendingRequest']) return -1;
      if (!a['isPendingRequest'] && b['isPendingRequest']) return 1;

      return (statusPriority[aStatus] ?? 6).compareTo(statusPriority[bStatus] ?? 6);
    });

    // Initialize animations for each card
    _initializeAnimations();
  }

  // Respond to driver request (accept/reject)
  Future<void> _respondToDriverRequest(String orderId, String action) async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Use OrderService to respond to driver request
      await OrderService.respondToDriverRequest(orderId, action);

      // Reload orders after response
      await _loadDriverOrders();

      // Show success message
      if (mounted) {
        final message = action == 'accept'
            ? 'Pesanan berhasil diterima!'
            : 'Pesanan berhasil ditolak!';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message,
              style: TextStyle(fontFamily: GlobalStyle.fontFamily),
            ),
            backgroundColor: action == 'accept' ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );

        // Play sound
        await _playSound(action == 'accept' ? 'audio/success.mp3' : 'audio/info.mp3');
      }

    } catch (e) {
      print('Error responding to driver request: $e');

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal merespon pesanan: ${e.toString()}',
              style: TextStyle(fontFamily: GlobalStyle.fontFamily),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Helper methods for safe parsing
  DateTime _parseDateTime(dynamic dateTime) {
    if (dateTime == null) return DateTime.now();
    if (dateTime is DateTime) return dateTime;
    if (dateTime is String) {
      try {
        return DateTime.parse(dateTime);
      } catch (e) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return 0.0;
      }
    }
    return 0.0;
  }

  // Map backend status to UI status
  String _mapOrderStatusToDeliveryStatus(String? orderStatus, String? deliveryStatus) {
    // First check delivery status which takes precedence
    if (deliveryStatus != null) {
      if (deliveryStatus == 'picking_up' || deliveryStatus == 'driverHeadingToStore' || deliveryStatus == 'driverAtStore') {
        return 'picking_up';
      } else if (deliveryStatus == 'on_delivery' || deliveryStatus == 'driverHeadingToCustomer' || deliveryStatus == 'driverArrived') {
        return 'delivering';
      } else if (deliveryStatus == 'delivered' || deliveryStatus == 'completed') {
        return 'delivered';
      }
    }

    // Then check order status
    if (orderStatus == 'pending') {
      return 'pending';
    } else if (orderStatus == 'pending_driver' || orderStatus == 'approved') {
      return 'assigned';
    } else if (orderStatus == 'preparing') {
      return 'picking_up';
    } else if (orderStatus == 'on_delivery') {
      return 'delivering';
    } else if (orderStatus == 'delivered' || orderStatus == 'completed') {
      return 'delivered';
    } else if (orderStatus == 'cancelled') {
      return 'cancelled';
    }

    // Default fallback
    return 'pending';
  }

  void _initializeAnimations() {
    // Clear existing controllers first
    for (var controller in _cardControllers) {
      controller.dispose();
    }

    if (_allOrders.isEmpty) return;

    // Initialize new controllers for each card
    _cardControllers = List.generate(
      _allOrders.length,
          (index) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 600 + (index * 200)),
      ),
    );

    // Create slide animations for each card
    _cardAnimations = _cardControllers.map((controller) {
      return Tween<Offset>(
        begin: const Offset(0, 0.5),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeOutCubic,
      ));
    }).toList();

    // Start animations
    for (var controller in _cardControllers) {
      controller.forward();
    }
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        // Handle notification tap
        if (details.payload != null) {
          _loadDriverOrders(); // Refresh orders when notification is tapped
        }
      },
    );
  }

  Future<void> _requestPermissions() async {
    await Permission.notification.request();

    // Initialize location service
    _isLocationServiceInitialized = await _locationService.initialize();
  }

  // Enhanced: Start location tracking using LocationService
  Future<void> _startLocationTracking() async {
    if (!_isLocationServiceInitialized) {
      _isLocationServiceInitialized = await _locationService.initialize();

      if (!_isLocationServiceInitialized) {
        // Show dialog to inform user
        if (mounted) {
          _locationService.showLocationPermissionDialog(context);
        }
        return;
      }
    }

    // Start tracking with LocationService - this will handle periodic updates automatically
    final success = await _locationService.startTracking();

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal memulai pelacakan lokasi. Pastikan GPS aktif.',
            style: TextStyle(fontFamily: GlobalStyle.fontFamily),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _stopLocationTracking() async {
    _locationService.stopTracking();
  }

  Future<void> _showNotification(Map<String, dynamic> orderDetails) async {
    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
        'driver_channel_id',
        'Driver Notifications',
        channelDescription: 'Notifications for new driver orders',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        sound: RawResourceAndroidNotificationSound('notification_sound'),
      );

      const NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);

      await _flutterLocalNotificationsPlugin.show(
        orderDetails['id'].hashCode,
        'Pesanan Baru Masuk! 🚗',
        'Dari: ${orderDetails['storeName'] ?? 'Toko'} → ${orderDetails['customerName']} - ${GlobalStyle.formatRupiah(orderDetails['totalPrice'])}',
        platformChannelSpecifics,
        payload: orderDetails['id'],
      );
    } catch (e) {
      print('Error showing notification: $e');
    }
  }

  Future<void> _playSound(String assetPath) async {
    try {
      await _audioPlayer.play(AssetSource(assetPath));
    } catch (e) {
      print('Error playing sound: $e');
    }
  }

  // Enhanced: Show new order dialog with better UI
  Future<void> _showNewOrderDialog(Map<String, dynamic> orderDetails) async {
    if (_isShowingNewOrderDialog) return; // Prevent multiple dialogs

    _isShowingNewOrderDialog = true;
    await _playSound('audio/notification_sound.mp3');

    if (mounted) {
      final result = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animation
                  Lottie.asset(
                    'assets/animations/new_order.json',
                    width: 180,
                    height: 180,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Text(
                    'Pesanan Baru Masuk! 🚗',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: GlobalStyle.fontFamily,
                      color: GlobalStyle.primaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Order Details Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: GlobalStyle.lightColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildOrderDetailRow('Toko:', orderDetails['storeName'] ?? 'Unknown Store'),
                        const SizedBox(height: 8),
                        _buildOrderDetailRow('Pelanggan:', orderDetails['customerName']),
                        const SizedBox(height: 8),
                        _buildOrderDetailRow('Alamat:', orderDetails['customerAddress']),
                        const SizedBox(height: 8),
                        _buildOrderDetailRow('Total:', GlobalStyle.formatRupiah(orderDetails['totalPrice']),
                            isHighlight: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Timer countdown (optional)
                  Text(
                    'Waktu untuk merespon: 60 detik',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange,
                      fontFamily: GlobalStyle.fontFamily,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              Row(
                children: [
                  // Reject button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop('reject');
                      },
                      icon: const Icon(Icons.close, color: Colors.red, size: 18),
                      label: Text(
                        'Tolak',
                        style: TextStyle(
                          color: Colors.red,
                          fontFamily: GlobalStyle.fontFamily,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Accept button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop('accept');
                      },
                      icon: const Icon(Icons.check, color: Colors.white, size: 18),
                      label: Text(
                        'Terima',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: GlobalStyle.fontFamily,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GlobalStyle.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      );

      _isShowingNewOrderDialog = false;

      // Handle the response
      if (result != null && orderDetails['id'] != null) {
        await _respondToDriverRequest(orderDetails['id'], result);
      }
    }
  }

  // Helper method to build order detail row
  Widget _buildOrderDetailRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: GlobalStyle.fontColor.withOpacity(0.7),
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: isHighlight ? GlobalStyle.primaryColor : GlobalStyle.fontColor,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
        ),
      ],
    );
  }

  // Reset notification count
  void _resetNotificationCount() {
    setState(() {
      _notificationCount = 0;
    });
  }

  // Enhanced: Update order status
  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Use OrderService to update order status
      await OrderService.updateOrderStatus(orderId, newStatus);

      // Refresh orders
      await _loadDriverOrders();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Status pesanan berhasil diubah',
              style: TextStyle(fontFamily: GlobalStyle.fontFamily),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error updating order status: $e');
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal mengubah status: ${e.toString()}',
              style: TextStyle(fontFamily: GlobalStyle.fontFamily),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Enhanced: Toggle driver status using DriverService
  Future<void> _toggleDriverStatus() async {
    if (_driverId == null) {
      // Show error if driver ID is not available
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Tidak dapat mengubah status driver: ID driver tidak ditemukan',
            style: TextStyle(fontFamily: GlobalStyle.fontFamily),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Set loading state
    setState(() {
      _isTogglingStatus = true;
    });

    try {
      // Get new status (opposite of current status)
      final newStatus = _isDriverActive ? 'inactive' : 'active';

      // Call DriverService to update driver status
      await DriverService.updateDriverStatus(newStatus);

      // Update local state
      setState(() {
        _isDriverActive = !_isDriverActive;

        // Update status in driver data
        if (_driverData != null) {
          _driverData!['status'] = newStatus;
        }
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isDriverActive
                ? 'Status aktif: Siap menerima pesanan! 🚗'
                : 'Status nonaktif: Tidak menerima pesanan baru 🛑',
            style: TextStyle(fontFamily: GlobalStyle.fontFamily),
          ),
          backgroundColor: _isDriverActive ? Colors.green : Colors.red,
        ),
      );

      // Play status change sound
      await _playSound(_isDriverActive ? 'audio/success.mp3' : 'audio/info.mp3');

      // If driver is now active, start location tracking and update orders
      if (_isDriverActive) {
        await _startLocationTracking();
        await _loadDriverOrders();
      } else {
        await _stopLocationTracking();
      }

    } catch (e) {
      print('Error toggling driver status: $e');

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal mengubah status driver: ${e.toString()}',
            style: TextStyle(fontFamily: GlobalStyle.fontFamily),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      // Reset loading state
      setState(() {
        _isTogglingStatus = false;
      });
    }
  }

  // Show confirmation dialog before toggling driver status
  void _showStatusConfirmationDialog() {
    final newStatus = _isDriverActive ? 'nonaktif' : 'aktif';
    final statusIcon = _isDriverActive ? '🛑' : '🚗';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Text(statusIcon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Text(
                'Konfirmasi Status',
                style: TextStyle(
                  fontFamily: GlobalStyle.fontFamily,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Anda yakin ingin mengubah status driver menjadi $newStatus?',
                style: TextStyle(
                  fontFamily: GlobalStyle.fontFamily,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (_isDriverActive ? Colors.red : Colors.green).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _isDriverActive
                      ? 'Anda akan berhenti menerima pesanan baru'
                      : 'Anda akan mulai menerima pesanan baru',
                  style: TextStyle(
                    fontSize: 12,
                    color: _isDriverActive ? Colors.red : Colors.green,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Batal',
                style: TextStyle(
                  color: GlobalStyle.primaryColor,
                  fontFamily: GlobalStyle.fontFamily,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _toggleDriverStatus();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: GlobalStyle.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                'Ya, Ubah Status',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: GlobalStyle.fontFamily,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Make a phone call
  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);

    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        throw 'Could not launch $phoneUri';
      }
    } catch (e) {
      print('Error launching phone call: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Tidak dapat melakukan panggilan: ${e.toString()}',
              style: TextStyle(fontFamily: GlobalStyle.fontFamily),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'assigned':
        return Colors.blue;
      case 'picking_up':
        return Colors.purple;
      case 'delivering':
        return Colors.indigo;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Pesanan Masuk';
      case 'assigned':
        return 'Diterima';
      case 'picking_up':
        return 'Dijemput';
      case 'delivering':
        return 'Diantar';
      case 'delivered':
        return 'Selesai';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return 'Unknown';
    }
  }

  String _getNextStatusAction(String currentStatus) {
    switch (currentStatus) {
      case 'assigned':
        return 'Mulai Jemput';
      case 'picking_up':
        return 'Mulai Antar';
      case 'delivering':
        return 'Selesaikan';
      default:
        return '';
    }
  }

  String _getNextStatus(String currentStatus) {
    switch (currentStatus) {
      case 'assigned':
        return 'picking_up';
      case 'picking_up':
        return 'on_delivery';
      case 'delivering':
        return 'delivered';
      default:
        return '';
    }
  }

  // Safe date formatting with fallback
  String _safeFormatDate(DateTime date) {
    try {
      return DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(date);
    } catch (e) {
      print('Error formatting date: $e');
      // Fallback to simple date format without locale
      return DateFormat('dd/MM/yyyy').format(date);
    }
  }

  // Build profile button with enhanced badge
  Widget _buildProfileButton() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: const FaIcon(
        FontAwesomeIcons.user,
        size: 20,
        color: Colors.white,
      ),
    );
  }

  // Build summary item
  Widget _buildSummaryItem(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color ?? GlobalStyle.primaryColor,
            fontFamily: GlobalStyle.fontFamily,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: GlobalStyle.fontColor.withOpacity(0.7),
            fontFamily: GlobalStyle.fontFamily,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // Enhanced: Build delivery card with better handling for requests vs orders
  Widget _buildDeliveryCard(Map<String, dynamic> order, int index) {
    String status = order['status'] as String;
    bool isPendingRequest = order['isPendingRequest'] == true;
    final animationIndex = index < _cardAnimations.length ? index : 0;

    return SlideTransition(
      position: _cardAnimations[animationIndex],
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isPendingRequest
              ? Border.all(color: Colors.orange, width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Header row with customer info and status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // Customer avatar
                            if (order['customerAvatar'] != null &&
                                order['customerAvatar'].toString().isNotEmpty)
                              ImageService.displayImage(
                                imageSource: order['customerAvatar'],
                                width: 36,
                                height: 36,
                                borderRadius: BorderRadius.circular(18),
                              )
                            else
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: GlobalStyle.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Icon(
                                  Icons.person,
                                  color: GlobalStyle.primaryColor,
                                  size: 20,
                                ),
                              ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    order['customerName'] ?? 'Customer',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      fontFamily: GlobalStyle.fontFamily,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (order['storeName'] != null)
                                    Text(
                                      'dari ${order['storeName']}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: GlobalStyle.fontColor.withOpacity(0.7),
                                        fontFamily: GlobalStyle.fontFamily,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.access_time,
                                color: GlobalStyle.fontColor, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('dd MMM yyyy HH:mm')
                                  .format(order['orderTime']),
                              style: TextStyle(
                                color: GlobalStyle.fontColor,
                                fontFamily: GlobalStyle.fontFamily,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.payments,
                                color: GlobalStyle.primaryColor, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              GlobalStyle.formatRupiah(order['totalPrice']),
                              style: TextStyle(
                                color: GlobalStyle.primaryColor,
                                fontWeight: FontWeight.bold,
                                fontFamily: GlobalStyle.fontFamily,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _getStatusLabel(status),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (isPendingRequest)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'BARU!',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                fontFamily: GlobalStyle.fontFamily,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Location information
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: GlobalStyle.lightColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    // Store location (pickup)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.store, color: Colors.white, size: 14),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Jemput',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  fontFamily: GlobalStyle.fontFamily,
                                ),
                              ),
                              Text(
                                order['storeAddress'] ?? 'Alamat Toko',
                                style: TextStyle(
                                  color: GlobalStyle.fontColor,
                                  fontSize: 12,
                                  fontFamily: GlobalStyle.fontFamily,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Dotted line connector
                    Padding(
                      padding: const EdgeInsets.only(left: 7.5),
                      child: Row(
                        children: [
                          Container(
                            width: 1,
                            height: 20,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ),

                    // Customer location (delivery)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.location_on, color: Colors.white, size: 14),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Antar',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  fontFamily: GlobalStyle.fontFamily,
                                ),
                              ),
                              Text(
                                order['customerAddress'] ?? 'Alamat Pelanggan',
                                style: TextStyle(
                                  color: GlobalStyle.fontColor,
                                  fontSize: 12,
                                  fontFamily: GlobalStyle.fontFamily,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Action buttons
              if (isPendingRequest) ...[
                // For new requests - Accept/Reject buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await _respondToDriverRequest(order['id'], 'reject');
                        },
                        icon: const Icon(Icons.close, color: Colors.red, size: 18),
                        label: Text(
                          'Tolak',
                          style: TextStyle(
                            color: Colors.red,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await _respondToDriverRequest(order['id'], 'accept');
                        },
                        icon: const Icon(Icons.check, color: Colors.white, size: 18),
                        label: Text(
                          'Terima',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GlobalStyle.primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // For active orders - Phone and Detail buttons
                Row(
                  children: [
                    if (order['customerPhone'] != null &&
                        order['customerPhone'].toString().isNotEmpty)
                      Expanded(
                        flex: 1,
                        child: ElevatedButton(
                          onPressed: () async {
                            final phoneNumber = order['customerPhone'].toString();
                            await _makePhoneCall(phoneNumber);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: EdgeInsets.zero,
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Icon(Icons.phone, color: Colors.white),
                          ),
                        ),
                      ),
                    if (order['customerPhone'] != null &&
                        order['customerPhone'].toString().isNotEmpty)
                      const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => HistoryDriverDetailPage(
                                orderDetail: order,
                              ),
                            ),
                          ).then((_) {
                            // Refresh orders when returning from detail page
                            _loadDriverOrders();
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GlobalStyle.primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          minimumSize: const Size(double.infinity, 40),
                        ),
                        child: Text(
                          'Lihat Detail',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Status update button for active orders
                if (status != 'delivered' && status != 'cancelled' && status != 'pending')
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          String nextStatus = _getNextStatus(status);
                          if (nextStatus.isNotEmpty) {
                            _updateOrderStatus(order['id'], nextStatus);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _getStatusColor(status),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          minimumSize: const Size(double.infinity, 40),
                        ),
                        child: Text(
                          _getNextStatusAction(status),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/animations/empty.json',
            width: 250,
            height: 250,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 16),
          Text(
            'Tidak ada pengiriman',
            style: TextStyle(
              color: GlobalStyle.fontColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isDriverActive
                ? 'Pengiriman baru akan muncul di sini'
                : 'Aktifkan status untuk menerima pengiriman',
            style: TextStyle(
              color: GlobalStyle.fontColor.withOpacity(0.7),
              fontSize: 14,
              fontFamily: GlobalStyle.fontFamily,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: _isDriverActive
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: _isDriverActive ? Colors.green : Colors.red, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                    _isDriverActive ? Icons.check_circle : Icons.warning_amber,
                    color: _isDriverActive ? Colors.green : Colors.red,
                    size: 20),
                const SizedBox(width: 8),
                Text(
                  'Status: ${_isDriverActive ? "Aktif 🚗" : "Nonaktif 🛑"}',
                  style: TextStyle(
                    color: _isDriverActive ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: GlobalStyle.primaryColor),
          const SizedBox(height: 16),
          Text(
            'Memuat pengiriman...',
            style: TextStyle(
              color: GlobalStyle.fontColor,
              fontSize: 16,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/animations/error.json',
            width: 200,
            height: 200,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 16),
          Text(
            'Gagal memuat pengiriman',
            style: TextStyle(
              color: Colors.red,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage,
            style: TextStyle(
              color: GlobalStyle.fontColor.withOpacity(0.7),
              fontSize: 14,
              fontFamily: GlobalStyle.fontFamily,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              _fetchDriverInfo();
              _loadDriverOrders();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: GlobalStyle.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: Text(
              'Coba Lagi',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontFamily: GlobalStyle.fontFamily,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // If locale is not initialized yet, show loading
    if (!_isLocaleInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Calculate summary counts
    final int pendingOrdersCount = _allOrders.where((order) => order['isPendingRequest'] == true).length;
    final int activeOrdersCount = _allOrders.where((order) =>
    !order['isPendingRequest'] &&
        ['picking_up', 'delivering', 'assigned'].contains(order['status'])
    ).length;

    return Scaffold(
      backgroundColor: const Color(0xffF8F9FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Enhanced Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      GlobalStyle.primaryColor,
                      GlobalStyle.primaryColor.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: GlobalStyle.primaryColor.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pengiriman Driver',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                fontFamily: GlobalStyle.fontFamily,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _safeFormatDate(DateTime.now()),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 12,
                                fontFamily: GlobalStyle.fontFamily,
                              ),
                            ),
                            if (_driverData != null && _driverData!['name'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.person,
                                      color: Colors.white.withOpacity(0.8),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _driverData!['name'],
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        fontFamily: GlobalStyle.fontFamily,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        // Enhanced profile button with notification badge
                        GestureDetector(
                          onTap: () {
                            _resetNotificationCount();
                            Navigator.pushNamed(context, ProfileDriverPage.route).then((_) {
                              // Refresh driver status when returning from profile page
                              _fetchDriverInfo();
                            });
                          },
                          child: _notificationCount > 0
                              ? badges.Badge(
                            badgeContent: Text(
                              _notificationCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            badgeStyle: badges.BadgeStyle(
                              badgeColor: Colors.red,
                              padding: const EdgeInsets.all(5),
                            ),
                            position: badges.BadgePosition.topEnd(
                                top: -5, end: -5),
                            child: _buildProfileButton(),
                          )
                              : _buildProfileButton(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Enhanced driver status toggle button
                    ElevatedButton.icon(
                      onPressed: _isTogglingStatus ? null : _showStatusConfirmationDialog,
                      icon: Icon(
                        _isDriverActive ? Icons.radio_button_checked : Icons.radio_button_off,
                        color: _isDriverActive ? Colors.green : Colors.red,
                        size: 24,
                      ),
                      label: _isTogglingStatus
                          ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              color: GlobalStyle.primaryColor,
                              strokeWidth: 2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Mengubah Status...',
                            style: TextStyle(
                              color: GlobalStyle.primaryColor,
                              fontWeight: FontWeight.bold,
                              fontFamily: GlobalStyle.fontFamily,
                            ),
                          ),
                        ],
                      )
                          : Text(
                        _isDriverActive
                            ? 'Status: Aktif 🚗'
                            : 'Status: Nonaktif 🛑',
                        style: TextStyle(
                          color: _isDriverActive ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontFamily: GlobalStyle.fontFamily,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        minimumSize: const Size(double.infinity, 50),
                        disabledBackgroundColor: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Enhanced deliveries summary
              if (!_isLoading && !_hasError && _allOrders.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryItem(
                        'Total',
                        _allOrders.length.toString(),
                      ),
                      Container(
                        height: 40,
                        width: 1,
                        color: GlobalStyle.primaryColor.withOpacity(0.3),
                      ),
                      _buildSummaryItem(
                        'Baru',
                        pendingOrdersCount.toString(),
                        color: Colors.orange,
                      ),
                      Container(
                        height: 40,
                        width: 1,
                        color: GlobalStyle.primaryColor.withOpacity(0.3),
                      ),
                      _buildSummaryItem(
                        'Aktif',
                        activeOrdersCount.toString(),
                        color: Colors.purple,
                      ),
                    ],
                  ),
                ),
              if (!_isLoading && !_hasError && _allOrders.isNotEmpty)
                const SizedBox(height: 20),

              // Deliveries list
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : _hasError
                    ? _buildErrorState()
                    : _allOrders.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                  onRefresh: () async {
                    await _loadDriverOrders();
                  },
                  color: GlobalStyle.primaryColor,
                  child: ListView.builder(
                    itemCount: _allOrders.length,
                    itemBuilder: (context, index) =>
                        _buildDeliveryCard(_allOrders[index], index),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: DriverBottomNavigation(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
      ),
    );
  }
}