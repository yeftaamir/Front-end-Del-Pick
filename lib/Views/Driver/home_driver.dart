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
import 'package:del_pick/Services/driver_request.dart'; // Updated import
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

  // Separate data storage for requests and orders
  List<Map<String, dynamic>> _pendingRequests = []; // New incoming driver requests
  List<Map<String, dynamic>> _activeOrders = []; // Accepted orders in progress
  List<Map<String, dynamic>> _allItems = []; // Combined list for display

  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isLocaleInitialized = false;
  bool _isTogglingStatus = false;

  // Store current driver data
  Map<String, dynamic>? _driverData;
  String? _driverId;

  // Track previous counts for new request detection
  int _previousRequestsCount = 0;
  int _previousOrdersCount = 0;

  // Notification badge counter
  int _notificationCount = 0;

  // Timer for periodic updates
  Timer? _updateTimer;

  // Track active dialogs to prevent multiple notifications
  bool _isShowingNewRequestDialog = false;

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

    // Load driver requests and orders
    _loadDriverData();

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
    _updateTimer?.cancel();

    super.dispose();
  }

  // Setup enhanced periodic updates
  void _setupPeriodicUpdates() {
    _updateTimer?.cancel();

    // Fetch data every 15 seconds if driver is active
    _updateTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted && _isDriverActive) {
        _loadDriverData();
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

  // Enhanced: Load both driver requests and active orders separately
  Future<void> _loadDriverData() async {
    if (!mounted) return;

    setState(() {
      if (_allItems.isEmpty) {
        _isLoading = true;
      }
      _hasError = false;
    });

    try {
      // Load pending driver requests using DriverRequestService
      await _loadPendingRequests();

      // Load active orders using DriverService
      await _loadActiveOrders();

      // Combine and sort all items
      _combineAndSortItems();

    } catch (e) {
      print('Error loading driver data: $e');
      setState(() {
        _isLoading = false;
        if (_allItems.isEmpty) {
          _hasError = true;
          _errorMessage = 'Failed to load data: $e';
        }
      });
    }
  }

  // Load pending driver requests
  Future<void> _loadPendingRequests() async {
    try {
      final response = await DriverRequestService.getDriverRequests(
        status: 'pending',
      );

      List<Map<String, dynamic>> processedRequests = [];

      if (response is Map<String, dynamic> && response['requests'] is List) {
        final List<dynamic> requestsList = response['requests'];

        for (var requestItem in requestsList) {
          if (requestItem is Map<String, dynamic>) {
            final processedRequest = _processDriverRequest(requestItem);
            if (processedRequest != null) {
              processedRequests.add(processedRequest);
            }
          }
        }
      }

      // Check for new requests and show notifications
      if (processedRequests.length > _previousRequestsCount &&
          _isDriverActive &&
          _previousRequestsCount > 0) {

        final newRequests = processedRequests.skip(_previousRequestsCount).toList();

        for (var newRequest in newRequests) {
          _notificationCount++;
          await _showNotification(newRequest);
          await _showNewRequestDialog(newRequest);
        }
      }

      setState(() {
        _pendingRequests = processedRequests;
        _previousRequestsCount = processedRequests.length;
      });

    } catch (e) {
      print('Error loading pending requests: $e');
      throw e;
    }
  }

  // Load active orders
  Future<void> _loadActiveOrders() async {
    try {
      final response = await DriverService.getDriverOrders();

      List<Map<String, dynamic>> processedOrders = [];

      if (response is Map<String, dynamic>) {
        List<dynamic> ordersList = [];

        if (response.containsKey('orders') && response['orders'] is List) {
          ordersList = response['orders'];
        }

        for (var orderItem in ordersList) {
          if (orderItem is Map<String, dynamic>) {
            final processedOrder = _processActiveOrder(orderItem);
            if (processedOrder != null) {
              processedOrders.add(processedOrder);
            }
          }
        }
      }

      setState(() {
        _activeOrders = processedOrders;
      });

    } catch (e) {
      print('Error loading active orders: $e');
      throw e;
    }
  }

  // Process driver request data (from DriverRequestService)
  Map<String, dynamic>? _processDriverRequest(Map<String, dynamic> requestData) {
    try {
      final orderData = requestData['order'] ?? {};
      final customerData = orderData['customer'] ?? {};
      final storeData = orderData['store'] ?? {};

      // Get customer avatar
      String customerAvatar = '';
      if (customerData['avatar'] != null && customerData['avatar'].toString().isNotEmpty) {
        customerAvatar = ImageService.getImageUrl(customerData['avatar']);
      }

      return {
        'id': requestData['id']?.toString() ?? '',
        'orderId': orderData['id']?.toString() ?? '',
        'customerName': customerData['name'] ?? 'Unknown Customer',
        'customerAvatar': customerAvatar,
        'customerPhone': customerData['phone'] ?? '',
        'customerAddress': orderData['delivery_address'] ?? orderData['deliveryAddress'] ?? 'No Address',
        'requestTime': _parseDateTime(requestData['created_at'] ?? requestData['createdAt']),
        'totalPrice': _parseDouble(orderData['total_amount'] ?? orderData['total'] ?? 0),
        'status': 'pending_request',
        'isPendingRequest': true,
        'storeName': storeData['name'] ?? 'Unknown Store',
        'storeAddress': storeData['address'] ?? 'No Address',
        'storePhone': storeData['phone'] ?? '',
        'deliveryFee': _parseDouble(orderData['delivery_fee'] ?? 0),
        'requestDetail': requestData,
        'orderDetail': orderData,
        'estimatedPickupTime': requestData['estimated_pickup_time'],
        'estimatedDeliveryTime': requestData['estimated_delivery_time'],
      };
    } catch (e) {
      print('Error processing driver request: $e');
      return null;
    }
  }

  // Process active order data (from DriverService)
  Map<String, dynamic>? _processActiveOrder(Map<String, dynamic> orderData) {
    try {
      final customerData = orderData['customer'] ?? {};
      final storeData = orderData['store'] ?? {};
      final orderItems = orderData['items'] ?? [];

      // Only process orders that are not completed or cancelled
      final orderStatus = orderData['order_status'] ?? orderData['status'];
      if (['delivered', 'cancelled'].contains(orderStatus)) {
        return null; // Skip completed orders
      }

      // Get customer avatar
      String customerAvatar = '';
      if (customerData['avatar'] != null && customerData['avatar'].toString().isNotEmpty) {
        customerAvatar = ImageService.getImageUrl(customerData['avatar']);
      }

      return {
        'id': orderData['id']?.toString() ?? '',
        'orderId': orderData['id']?.toString() ?? '',
        'customerName': customerData['name'] ?? 'Unknown Customer',
        'customerAvatar': customerAvatar,
        'customerPhone': customerData['phone'] ?? '',
        'customerAddress': orderData['delivery_address'] ?? orderData['deliveryAddress'] ?? 'No Address',
        'orderTime': _parseDateTime(orderData['created_at'] ?? orderData['createdAt']),
        'totalPrice': _parseDouble(orderData['total_amount'] ?? orderData['total'] ?? 0),
        'status': _mapOrderStatusToDeliveryStatus(
            orderData['order_status'] ?? orderData['status'],
            orderData['delivery_status'] ?? orderData['deliveryStatus']
        ),
        'isPendingRequest': false,
        'items': orderItems,
        'deliveryFee': _parseDouble(orderData['delivery_fee'] ?? 0),
        'storeName': storeData['name'] ?? 'Unknown Store',
        'storeAddress': storeData['address'] ?? 'No Address',
        'storePhone': storeData['phone'] ?? '',
        'orderDetail': orderData,
        'estimatedPickupTime': orderData['estimated_pickup_time'],
        'estimatedDeliveryTime': orderData['estimated_delivery_time'],
        'actualPickupTime': orderData['actual_pickup_time'],
        'actualDeliveryTime': orderData['actual_delivery_time'],
      };
    } catch (e) {
      print('Error processing active order: $e');
      return null;
    }
  }

  // Combine requests and orders, then sort by priority
  void _combineAndSortItems() {
    _allItems = [..._pendingRequests, ..._activeOrders];

    // Sort items by priority: pending requests -> picking up -> delivering -> other statuses
    _allItems.sort((a, b) {
      final statusPriority = {
        'pending_request': 0,
        'confirmed': 1,
        'preparing': 2,
        'ready_for_pickup': 3,
        'picking_up': 4,
        'on_delivery': 5,
        'delivered': 6,
        'cancelled': 7,
      };

      // Prioritize pending requests
      if (a['isPendingRequest'] && !b['isPendingRequest']) return -1;
      if (!a['isPendingRequest'] && b['isPendingRequest']) return 1;

      final aStatus = a['status'];
      final bStatus = b['status'];
      return (statusPriority[aStatus] ?? 8).compareTo(statusPriority[bStatus] ?? 8);
    });

    setState(() {
      _isLoading = false;
    });

    // Initialize animations for each card
    _initializeAnimations();
  }

  // Accept driver request using DriverRequestService
  Future<void> _acceptDriverRequest(String requestId) async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Use DriverRequestService to accept request
      await DriverRequestService.respondToDriverRequest(
        requestId,
        'accept',
        estimatedPickupTime: DateTime.now().add(const Duration(minutes: 15)),
        estimatedDeliveryTime: DateTime.now().add(const Duration(minutes: 30)),
      );

      // Reload data after response
      await _loadDriverData();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Pesanan berhasil diterima!',
              style: TextStyle(fontFamily: GlobalStyle.fontFamily),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        // Play success sound
        await _playSound('audio/success.mp3');
      }

    } catch (e) {
      print('Error accepting driver request: $e');

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal menerima pesanan: ${e.toString()}',
              style: TextStyle(fontFamily: GlobalStyle.fontFamily),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Reject driver request using DriverRequestService
  Future<void> _rejectDriverRequest(String requestId) async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Use DriverRequestService to reject request
      await DriverRequestService.respondToDriverRequest(requestId, 'reject');

      // Reload data after response
      await _loadDriverData();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Pesanan berhasil ditolak!',
              style: TextStyle(fontFamily: GlobalStyle.fontFamily),
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );

        // Play info sound
        await _playSound('audio/info.mp3');
      }

    } catch (e) {
      print('Error rejecting driver request: $e');

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal menolak pesanan: ${e.toString()}',
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
      switch (deliveryStatus.toLowerCase()) {
        case 'picking_up':
        case 'picked_up':
          return 'picking_up';
        case 'on_way':
        case 'on_delivery':
          return 'on_delivery';
        case 'delivered':
          return 'delivered';
      }
    }

    // Then check order status
    if (orderStatus != null) {
      switch (orderStatus.toLowerCase()) {
        case 'pending':
          return 'pending';
        case 'confirmed':
        case 'approved':
          return 'confirmed';
        case 'preparing':
          return 'preparing';
        case 'ready_for_pickup':
          return 'ready_for_pickup';
        case 'on_delivery':
          return 'on_delivery';
        case 'delivered':
        case 'completed':
          return 'delivered';
        case 'cancelled':
          return 'cancelled';
      }
    }

    // Default fallback
    return 'pending';
  }

  void _initializeAnimations() {
    // Clear existing controllers first
    for (var controller in _cardControllers) {
      controller.dispose();
    }

    if (_allItems.isEmpty) return;

    // Initialize new controllers for each card
    _cardControllers = List.generate(
      _allItems.length,
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
          _loadDriverData(); // Refresh data when notification is tapped
        }
      },
    );
  }

  Future<void> _requestPermissions() async {
    await Permission.notification.request();

    // Initialize location service
    _isLocationServiceInitialized = await _locationService.initialize();
  }

  // Enhanced: Start location tracking using LocationService and DriverService
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

    // Start tracking with LocationService
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

  Future<void> _showNotification(Map<String, dynamic> itemDetails) async {
    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
        'driver_channel_id',
        'Driver Notifications',
        channelDescription: 'Notifications for new driver requests',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        sound: RawResourceAndroidNotificationSound('notification_sound'),
      );

      const NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);

      await _flutterLocalNotificationsPlugin.show(
        itemDetails['id'].hashCode,
        'Permintaan Driver Baru! 🚗',
        'Dari: ${itemDetails['storeName'] ?? 'Toko'} → ${itemDetails['customerName']} - ${GlobalStyle.formatRupiah(itemDetails['totalPrice'])}',
        platformChannelSpecifics,
        payload: itemDetails['id'],
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

  // Enhanced: Show new request dialog
  Future<void> _showNewRequestDialog(Map<String, dynamic> requestDetails) async {
    if (_isShowingNewRequestDialog) return; // Prevent multiple dialogs

    _isShowingNewRequestDialog = true;
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
                    'Permintaan Driver Baru! 🚗',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: GlobalStyle.fontFamily,
                      color: GlobalStyle.primaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Request Details Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: GlobalStyle.lightColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildDetailRow('Toko:', requestDetails['storeName'] ?? 'Unknown Store'),
                        const SizedBox(height: 8),
                        _buildDetailRow('Pelanggan:', requestDetails['customerName']),
                        const SizedBox(height: 8),
                        _buildDetailRow('Alamat:', requestDetails['customerAddress']),
                        const SizedBox(height: 8),
                        _buildDetailRow('Total:', GlobalStyle.formatRupiah(requestDetails['totalPrice']),
                            isHighlight: true),
                        if (requestDetails['estimatedDeliveryTime'] != null) ...[
                          const SizedBox(height: 8),
                          _buildDetailRow('Perkiraan Selesai:',
                              DateFormat('HH:mm dd/MM').format(DateTime.parse(requestDetails['estimatedDeliveryTime']))),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Timer countdown
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

      _isShowingNewRequestDialog = false;

      // Handle the response
      if (result != null && requestDetails['id'] != null) {
        if (result == 'accept') {
          await _acceptDriverRequest(requestDetails['id']);
        } else if (result == 'reject') {
          await _rejectDriverRequest(requestDetails['id']);
        }
      }
    }
  }

  // Helper method to build detail row
  Widget _buildDetailRow(String label, String value, {bool isHighlight = false}) {
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

  // Enhanced: Update order status using OrderService
  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Use OrderService to update order status
      await OrderService.updateOrderStatus(orderId, {'status': newStatus});

      // Refresh data
      await _loadDriverData();

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

      // If driver is now active, start location tracking and update data
      if (_isDriverActive) {
        await _startLocationTracking();
        await _loadDriverData();
      } else {
        await _stopLocationTracking();
      }

    } catch (e) {
      print('Error toggling driver status: $e');

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
                      ? 'Anda akan berhenti menerima permintaan baru'
                      : 'Anda akan mulai menerima permintaan baru',
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
      case 'pending_request':
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'preparing':
        return Colors.purple;
      case 'ready_for_pickup':
        return Colors.cyan;
      case 'picking_up':
        return Colors.indigo;
      case 'on_delivery':
        return Colors.teal;
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
      case 'pending_request':
        return 'Permintaan Baru';
      case 'pending':
        return 'Menunggu';
      case 'confirmed':
        return 'Dikonfirmasi';
      case 'preparing':
        return 'Dipersiapkan';
      case 'ready_for_pickup':
        return 'Siap Dijemput';
      case 'picking_up':
        return 'Dijemput';
      case 'on_delivery':
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
      case 'confirmed':
      case 'preparing':
      case 'ready_for_pickup':
        return 'Mulai Jemput';
      case 'picking_up':
        return 'Mulai Antar';
      case 'on_delivery':
        return 'Selesaikan';
      default:
        return '';
    }
  }

  String _getNextStatus(String currentStatus) {
    switch (currentStatus) {
      case 'confirmed':
      case 'preparing':
      case 'ready_for_pickup':
        return 'picking_up';
      case 'picking_up':
        return 'on_delivery';
      case 'on_delivery':
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

  // Enhanced: Build item card with better handling for requests vs orders
  Widget _buildItemCard(Map<String, dynamic> item, int index) {
    String status = item['status'] as String;
    bool isPendingRequest = item['isPendingRequest'] == true;
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
                            if (item['customerAvatar'] != null &&
                                item['customerAvatar'].toString().isNotEmpty)
                              ImageService.displayImage(
                                imageSource: item['customerAvatar'],
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
                                    item['customerName'] ?? 'Customer',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      fontFamily: GlobalStyle.fontFamily,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (item['storeName'] != null)
                                    Text(
                                      'dari ${item['storeName']}',
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
                                  .format(item['orderTime'] ?? item['requestTime']),
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
                              GlobalStyle.formatRupiah(item['totalPrice']),
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
                                item['storeAddress'] ?? 'Alamat Toko',
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
                                item['customerAddress'] ?? 'Alamat Pelanggan',
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
                          await _rejectDriverRequest(item['id']);
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
                          await _acceptDriverRequest(item['id']);
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
                    if (item['customerPhone'] != null &&
                        item['customerPhone'].toString().isNotEmpty)
                      Expanded(
                        flex: 1,
                        child: ElevatedButton(
                          onPressed: () async {
                            final phoneNumber = item['customerPhone'].toString();
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
                    if (item['customerPhone'] != null &&
                        item['customerPhone'].toString().isNotEmpty)
                      const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => HistoryDriverDetailPage(
                                orderDetail: item,
                              ),
                            ),
                          ).then((_) {
                            // Refresh data when returning from detail page
                            _loadDriverData();
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
                if (status != 'delivered' && status != 'cancelled' && status != 'pending_request')
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          String nextStatus = _getNextStatus(status);
                          if (nextStatus.isNotEmpty) {
                            _updateOrderStatus(item['orderId'], nextStatus);
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
            'Tidak ada permintaan atau pesanan',
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
                ? 'Permintaan baru akan muncul di sini'
                : 'Aktifkan status untuk menerima permintaan',
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
            'Memuat data...',
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
            'Gagal memuat data',
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
              _loadDriverData();
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
    final int pendingRequestsCount = _pendingRequests.length;
    final int activeOrdersCount = _activeOrders.length;

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
                              'Driver Dashboard',
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
                            if (_driverData != null && _driverData!['user'] != null && _driverData!['user']['name'] != null)
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
                                      _driverData!['user']['name'],
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

              // Enhanced summary
              if (!_isLoading && !_hasError && _allItems.isNotEmpty)
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
                        _allItems.length.toString(),
                      ),
                      Container(
                        height: 40,
                        width: 1,
                        color: GlobalStyle.primaryColor.withOpacity(0.3),
                      ),
                      _buildSummaryItem(
                        'Permintaan',
                        pendingRequestsCount.toString(),
                        color: Colors.orange,
                      ),
                      Container(
                        height: 40,
                        width: 1,
                        color: GlobalStyle.primaryColor.withOpacity(0.3),
                      ),
                      _buildSummaryItem(
                        'Pesanan Aktif',
                        activeOrdersCount.toString(),
                        color: Colors.purple,
                      ),
                    ],
                  ),
                ),
              if (!_isLoading && !_hasError && _allItems.isNotEmpty)
                const SizedBox(height: 20),

              // Items list
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : _hasError
                    ? _buildErrorState()
                    : _allItems.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                  onRefresh: () async {
                    await _loadDriverData();
                  },
                  color: GlobalStyle.primaryColor,
                  child: ListView.builder(
                    itemCount: _allItems.length,
                    itemBuilder: (context, index) =>
                        _buildItemCard(_allItems[index], index),
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