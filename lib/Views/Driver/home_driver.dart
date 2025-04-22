import 'dart:async';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
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
import 'package:del_pick/Models/order.dart';
import 'package:del_pick/Models/driver.dart';
import 'package:del_pick/Services/location_service.dart';

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
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _locationUpdateTimer;
  Position? _currentPosition;
  // For location tracking
  final LocationService _locationService = LocationService();
  bool _isLocationServiceInitialized = false;

  // To store driver orders from backend
  List<Map<String, dynamic>> _deliveries = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Store current driver data
  Driver? _currentDriver;

  @override
  void initState() {
    super.initState();

    // Initialize notifications
    _initializeNotifications();

    // Request necessary permissions
    _requestPermissions();

    // Check if driver is already active
    _checkDriverStatus();

    // Load active deliveries
    _loadDeliveries();

    // Start a timer to periodically fetch the latest deliveries every 30 seconds
    Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && _isDriverActive) {
        _loadDeliveries();
      } else if (!mounted) {
        timer.cancel();
      }
    });
  }

  Future<void> _checkDriverStatus() async {
    try {
      final userData = await AuthService.getUserData();
      if (userData != null && userData['driver'] != null) {
        // Create driver object from stored data
        _currentDriver = Driver.fromStoredData(userData['driver']);

        setState(() {
          _isDriverActive = _currentDriver?.status == 'active';
        });

        if (_isDriverActive) {
          // Start location tracking if driver is active
          _startLocationTracking();
        }
      }
    } catch (e) {
      print('Error checking driver status: $e');
    }
  }

  Future<void> _loadDeliveries() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get driver requests from API
      final response = await DriverService.getDriverRequests();

      // Debug: print response structure
      print('Driver requests response: $response');

      // Process the response structure correctly
      List<Map<String, dynamic>> newDeliveries = [];

      // The API response returns data with this structure, based on the backend code
      final requestsList = response['requests'] ?? [];

      // Convert orders to the format expected by the UI
      for (var request in requestsList) {
        // Extract order details from the request structure
        final orderData = request['order'] ?? {};
        final customerData = orderData['user'] ?? {};
        final storeData = orderData['store'] ?? {};

        Map<String, dynamic> delivery = {
          'id': orderData['id']?.toString() ?? '',
          'code': orderData['code']?.toString() ?? '',
          'customerName': customerData['name'] ?? 'Unknown Customer',
          'orderTime': orderData['created_at'] != null
              ? DateTime.parse(orderData['created_at'])
              : (orderData['createdAt'] != null
              ? DateTime.parse(orderData['createdAt'])
              : DateTime.now()),
          'totalPrice': (orderData['total'] as num?)?.toDouble() ?? 0.0,
          'status': _mapOrderStatusToDeliveryStatus(
              orderData['order_status'] ?? orderData['status'],
              orderData['delivery_status']
          ),
          'items': orderData['orderItems'] ?? [],
          'deliveryFee': (orderData['service_charge'] ?? orderData['serviceCharge'] ?? 0.0) as num,
          'amount': (orderData['total'] as num?)?.toDouble() ?? 0.0,
          'storeAddress': storeData['address'] ?? 'No Address',
          'customerAddress': orderData['delivery_address'] ?? orderData['deliveryAddress'] ?? 'No Address',
          'storePhone': storeData['phone'] ?? storeData['phoneNumber'] ?? '',
          'customerPhone': customerData['phone'] ?? customerData['phoneNumber'] ?? '',
          'orderDetail': orderData, // Store full order details for later use
        };

        newDeliveries.add(delivery);
      }

      setState(() {
        _deliveries = newDeliveries;
        _isLoading = false;

        // Initialize animations for each card
        _initializeAnimations();
      });

      // Add debug logging
      print('Processed deliveries count: ${newDeliveries.length}');

      // If we have new orders and driver is active, show notification
      if (_isDriverActive && newDeliveries.isNotEmpty) {
        // Find orders that are newly assigned
        final newOrder = newDeliveries.firstWhere(
              (delivery) => delivery['status'] == 'assigned',
          orElse: () => <String, dynamic>{},
        );

        if (newOrder.isNotEmpty) {
          _showNotification(newOrder);
        }
      }
    } catch (e) {
      print('Error loading deliveries: $e');
      setState(() {
        _errorMessage = 'Gagal memuat pesanan, silakan coba lagi.';
        _isLoading = false;
      });
    }
  }

  // Map backend status to UI status
  String _mapOrderStatusToDeliveryStatus(String? orderStatus, String? deliveryStatus) {
    if (deliveryStatus == 'picking_up') {
      return 'picking_up';
    } else if (deliveryStatus == 'on_delivery') {
      return 'delivering';
    } else if (orderStatus == 'pending' || orderStatus == 'approved') {
      return 'assigned';
    } else {
      return 'assigned'; // Default fallback
    }
  }

  void _initializeAnimations() {
    // Clear existing controllers first
    for (var controller in _cardControllers) {
      controller.dispose();
    }

    // Initialize new controllers for each delivery card
    _cardControllers = List.generate(
      _deliveries.length,
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

    // Start animations sequentially
    Future.delayed(const Duration(milliseconds: 100), () {
      for (var controller in _cardControllers) {
        if (controller.isCompleted) continue;
        controller.forward();
      }
    });
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
        _showNewOrderDialog();
      },
    );
  }

  Future<void> _requestPermissions() async {
    try {
      // Initialize location service (which will handle all location permissions)
      _isLocationServiceInitialized = await _locationService.initialize();

      // Request notification permission separately
      var notificationStatus = await Permission.notification.request();
      print('Notification permission: $notificationStatus');
    } catch (e) {
      print('Error requesting permissions: $e');
    }
  }

  Future<void> _startLocationTracking() async {
    // Cancel any existing timer
    _locationUpdateTimer?.cancel();

    // Request location permission first
    final permissionStatus = await Permission.location.request();
    if (permissionStatus != PermissionStatus.granted) {
      print('Location permission denied');

      // Show dialog to inform user
      if (mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Izin Lokasi Dibutuhkan',
                  style: TextStyle(fontFamily: GlobalStyle.fontFamily)),
              content: Text(
                  'Untuk mengaktifkan status driver, aplikasi membutuhkan izin lokasi. Silakan berikan izin lokasi di pengaturan.',
                  style: TextStyle(fontFamily: GlobalStyle.fontFamily)
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Deactivate driver since we can't track location
                    _toggleDriverStatus(false);
                  },
                  child: Text('Tutup',
                      style: TextStyle(color: GlobalStyle.primaryColor, fontFamily: GlobalStyle.fontFamily)),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    openAppSettings(); // Open app settings so user can enable location
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: GlobalStyle.primaryColor),
                  child: Text('Buka Pengaturan',
                      style: TextStyle(color: Colors.white, fontFamily: GlobalStyle.fontFamily)),
                ),
              ],
            );
          },
        );
      }
      return;
    }

    // First get current position
    try {
      _currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high
      );

      // Send initial location
      _updateDriverLocation();

      // Setup periodic updates every 10 seconds as per requirements
      _locationUpdateTimer = Timer.periodic(
          const Duration(seconds: 10),
              (timer) => _updateDriverLocation()
      );
    } catch (e) {
      print('Error getting location: $e');
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal mendapatkan lokasi. Pastikan GPS aktif.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            )
        );
      }
    }
  }

  Future<void> _updateDriverLocation() async {
    try {
      if (!_isDriverActive) return; // Skip if driver is not active

      // Get current position
      Position position;
      try {
        position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high
        );
        _currentPosition = position; // Update the stored position
      } catch (e) {
        // If we can't get a new position, use the last known position
        if (_currentPosition == null) {
          print('Failed to get location and no previous location available');
          return;
        }
        position = _currentPosition!;
      }

      // Send location to server
      await DriverService.updateDriverLocation({
        'latitude': position.latitude,
        'longitude': position.longitude,
      });

      print('Location updated: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      print('Error updating driver location: $e');
    }
  }

  Future<void> _stopLocationTracking() async {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
  }

  Future<void> _showNotification(Map<String, dynamic> orderDetails) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'delivery_channel_id',
      'Delivery Notifications',
      channelDescription: 'Notifications for new delivery orders',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/delpick',
    );

    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.show(
      0,
      'Pesanan Baru!',
      'Pelanggan: ${orderDetails['customerName']} - ${GlobalStyle.formatRupiah(orderDetails['totalPrice'].toDouble())}',
      platformChannelSpecifics,
    );
  }

  Future<void> _playSound(String assetPath) async {
    await _audioPlayer.play(AssetSource(assetPath));
  }

  Future<void> _showNewOrderDialog() async {
    // Don't show if there are no deliveries
    if (_deliveries.isEmpty) return;

    await _playSound('audio/kring.mp3');

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Colors.white,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/animations/pilih_pesanan.json',
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 16),
                Text(
                  'Pesanan Baru Masuk!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Pelanggan: ${_deliveries[0]['customerName']}',
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
                Text(
                  'Total: ${GlobalStyle.formatRupiah(_deliveries[0]['totalPrice'].toDouble())}',
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: GlobalStyle.fontFamily,
                    color: GlobalStyle.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            actions: [
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HistoryDriverDetailPage(
                          orderDetail: _deliveries[0],
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlobalStyle.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    minimumSize: const Size(double.infinity, 45),
                  ),
                  child: Text(
                    'Lihat Pesanan',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: GlobalStyle.fontFamily,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    }
  }

  void _showDriverActiveDialog() async {
    await _playSound('audio/found.wav');

    if (mounted) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Colors.white,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/animations/diantar.json',
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 16),
                Text(
                  'Anda Sekarang Aktif!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Anda akan menerima pesanan baru.',
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
              ],
            ),
            actions: [
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlobalStyle.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    minimumSize: const Size(double.infinity, 45),
                  ),
                  child: Text(
                    'Mengerti',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: GlobalStyle.fontFamily,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    }
  }

  void _showDeactivateConfirmationDialog() async {
    // Play wrong sound for deactivation confirmation
    await _playSound('audio/wrong.mp3');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Konfirmasi',
            style: TextStyle(
              fontFamily: GlobalStyle.fontFamily,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Anda yakin ingin menonaktifkan status? Anda tidak akan menerima pesanan baru.',
            style: TextStyle(
              fontFamily: GlobalStyle.fontFamily,
            ),
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
              onPressed: () async {
                Navigator.of(context).pop();
                await _toggleDriverStatus(false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: GlobalStyle.primaryColor,
              ),
              child: Text(
                'Ya, Nonaktifkan',
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

  Future<void> _toggleDriverStatus(bool isActivating) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // If activating and location service not initialized, try to initialize
      if (isActivating && !_isLocationServiceInitialized) {
        _isLocationServiceInitialized = await _locationService.initialize();

        if (!_isLocationServiceInitialized) {
          // If can't initialize location, show dialog and return
          _locationService.showLocationPermissionDialog(context);
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      // Call API to change driver status
      final newStatus = isActivating ? 'active' : 'inactive';
      final response = await DriverService.changeDriverStatus(newStatus);

      // Update local state and driver object
      if (_currentDriver != null) {
        _currentDriver = _currentDriver!.copyWith(status: newStatus);
      }

      setState(() {
        _isDriverActive = isActivating;
        _isLoading = false;
      });

      // Start or stop location tracking based on new status
      if (isActivating) {
        await _startLocationTracking();
        _showDriverActiveDialog();

        // Reload deliveries when activating
        _loadDeliveries();
      } else {
        _stopLocationTracking();
      }

      // Update stored user data with new status
      final userData = await AuthService.getUserData();
      if (userData != null && userData['driver'] != null) {
        userData['driver']['status'] = newStatus;
        // We would ideally save this back to storage, but let's rely on the backend
        // and just fetch fresh data next time
      }
    } catch (e) {
      print('Error toggling driver status: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal mengubah status, silakan coba lagi.';
      });

      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Gagal mengubah status: ${e.toString()}',
                style: TextStyle(fontFamily: GlobalStyle.fontFamily),
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            )
        );
      }
    }
  }

  void _onToggleButtonPressed() {
    if (_isDriverActive) {
      _showDeactivateConfirmationDialog();
    } else {
      _toggleDriverStatus(true);
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

    super.dispose();
  }

  List<Map<String, dynamic>> get activeDeliveries {
    return _deliveries.where((delivery) =>
        ['assigned', 'picking_up', 'delivering'].contains(delivery['status'])
    ).toList();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'assigned':
        return Colors.blue;
      case 'picking_up':
        return Colors.orange;
      case 'delivering':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'assigned':
        return 'Pesanan Masuk';
      case 'picking_up':
        return 'Dijemput';
      case 'delivering':
        return 'Diantar';
      default:
        return 'Unknown';
    }
  }

  Widget _buildDeliveryCard(Map<String, dynamic> delivery, int index) {
    String status = delivery['status'] as String;

    // Safe animation access
    Animation<Offset>? animation;
    if (index < _cardAnimations.length) {
      animation = _cardAnimations[index];
    }

    // Get order code or ID for display
    final orderCode = delivery['code'] != null && delivery['code'].toString().isNotEmpty
        ? delivery['code'].toString()
        : '#' + delivery['id'].toString();

    Widget card = Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Order Code/ID
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey.shade200,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order $orderCode',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      fontFamily: GlobalStyle.fontFamily,
                      color: GlobalStyle.primaryColor,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Customer and Price Info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person, color: GlobalStyle.primaryColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              delivery['customerName'],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                fontFamily: GlobalStyle.fontFamily,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.access_time, color: GlobalStyle.fontColor, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('dd MMM yyyy HH:mm').format(delivery['orderTime']),
                            style: TextStyle(
                              color: GlobalStyle.fontColor,
                              fontFamily: GlobalStyle.fontFamily,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.payments, color: GlobalStyle.primaryColor, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            GlobalStyle.formatRupiah(delivery['totalPrice'].toDouble()),
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
              ],
            ),
            const SizedBox(height: 16),
            // Location info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: GlobalStyle.lightColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  // Pickup location
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.store, color: Colors.white, size: 14),
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
                              delivery['storeAddress'],
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

                  // Delivery location
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.location_on, color: Colors.white, size: 14),
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
                              delivery['customerAddress'],
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
            Row(
              children: [
                if (delivery['customerPhone'] != null && delivery['customerPhone'].toString().isNotEmpty)
                  Expanded(
                    flex: 1,
                    child: ElevatedButton(
                      onPressed: () async {
                        final phoneNumber = delivery['customerPhone'].toString();
                        final url = 'tel:$phoneNumber';
                        // Open dialer
                        // In a real app, you'd use url_launcher package to launch the URL
                        // For example: await launch(url);
                        print('Calling customer: $phoneNumber');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Icon(Icons.phone, color: Colors.white),
                      ),
                    ),
                  ),
                if (delivery['customerPhone'] != null && delivery['customerPhone'].toString().isNotEmpty)
                  const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HistoryDriverDetailPage(
                            orderDetail: delivery,
                          ),
                        ),
                      );
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
          ],
        ),
      ),
    );

    // Apply animation if available
    return animation != null
        ? SlideTransition(position: animation, child: card)
        : card;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Adding Lottie animation when there are no orders
          Lottie.asset(
            'assets/animations/empty.json',
            width: 250,
            height: 250,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 16),
          Text(
            'Tidak ada pengiriman aktif',
            style: TextStyle(
              color: GlobalStyle.fontColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Anda akan melihat pengiriman aktif di sini',
            style: TextStyle(
              color: GlobalStyle.fontColor.withOpacity(0.7),
              fontSize: 14,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _isDriverActive
                ? 'Status: Aktif - Siap Menerima Pesanan'
                : 'Status: Tidak Aktif - Aktifkan untuk menerima pesanan',
            style: TextStyle(
              color: _isDriverActive ? Colors.green : Colors.red,
              fontSize: 14,
              fontWeight: FontWeight.bold,
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
          const Icon(
            Icons.error_outline,
            size: 80,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            'Terjadi Kesalahan',
            style: TextStyle(
              color: GlobalStyle.fontColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Gagal memuat data, silakan coba lagi.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: GlobalStyle.fontColor.withOpacity(0.7),
              fontSize: 14,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              _loadDeliveries();
              _checkDriverStatus();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: GlobalStyle.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              'Coba Lagi',
              style: TextStyle(
                color: Colors.white,
                fontFamily: GlobalStyle.fontFamily,
              ),
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
          CircularProgressIndicator(
            color: GlobalStyle.primaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Memuat Data...',
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

  @override
  Widget build(BuildContext context) {
    final deliveries = activeDeliveries;

    return Scaffold(
      backgroundColor: const Color(0xffD6E6F2),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
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
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pengantaran',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                fontFamily: GlobalStyle.fontFamily,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('EEEE, dd MMMM yyyy').format(DateTime.now()),
                              style: TextStyle(
                                color: GlobalStyle.fontColor,
                                fontSize: 12,
                                fontFamily: GlobalStyle.fontFamily,
                              ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushNamed(context, ProfileDriverPage.route);
                          },
                          child: Stack(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: GlobalStyle.lightColor.withOpacity(0.3),
                                  shape: BoxShape.circle,
                                ),
                                child: _currentDriver?.profileImageUrl != null &&
                                    _currentDriver!.profileImageUrl!.isNotEmpty
                                    ? ClipRRect(
                                  borderRadius: BorderRadius.circular(50),
                                  child: Image.network(
                                    _currentDriver!.profileImageUrl!,
                                    width: 30,
                                    height: 30,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => FaIcon(
                                      FontAwesomeIcons.user,
                                      size: 20,
                                      color: GlobalStyle.primaryColor,
                                    ),
                                  ),
                                )
                                    : FaIcon(
                                  FontAwesomeIcons.user,
                                  size: 20,
                                  color: GlobalStyle.primaryColor,
                                ),
                              ),
                              // Status indicator
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _isDriverActive ? Colors.green : Colors.red,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Status toggle button
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _onToggleButtonPressed,
                      icon: Icon(
                        _isDriverActive ? Icons.toggle_on : Icons.toggle_off,
                        color: Colors.white,
                        size: 24,
                      ),
                      label: Text(
                        _isDriverActive ? 'Status: Aktif' : 'Status: Tidak Aktif',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isDriverActive ? Colors.green : Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        minimumSize: const Size(double.infinity, 45),
                        disabledBackgroundColor: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Delivery List
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : _errorMessage != null
                    ? _buildErrorState()
                    : deliveries.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                  onRefresh: _loadDeliveries,
                  color: GlobalStyle.primaryColor,
                  child: ListView.builder(
                    itemCount: deliveries.length,
                    itemBuilder: (context, index) => _buildDeliveryCard(
                        deliveries[index],
                        index
                    ),
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
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}