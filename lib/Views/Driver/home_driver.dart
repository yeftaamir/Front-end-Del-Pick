import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart'; // Import for Indonesian locale
import 'package:geolocator/geolocator.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Views/Component/driver_bottom_navigation.dart';
import 'package:del_pick/Views/Driver/history_driver_detail.dart';
import 'package:del_pick/Views/Driver/profil_driver.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:lottie/lottie.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:del_pick/Services/Core/token_service.dart';
import 'package:del_pick/Services/driver_service.dart';
import 'package:del_pick/Services/auth_service.dart';
import 'package:del_pick/Models/driver.dart';
import 'package:del_pick/Models/order_enum.dart';
import 'package:del_pick/Services/Core/api_constants.dart';

class HomeDriverPage extends StatefulWidget {
  static const String route = '/Driver/HomePage';
  const HomeDriverPage({Key? key}) : super(key: key);

  @override
  State<HomeDriverPage> createState() => _HomeDriverPageState();
}

class _HomeDriverPageState extends State<HomeDriverPage>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  late List<AnimationController> _cardControllers = [];
  late List<Animation<Offset>> _cardAnimations = [];
  bool _isDriverActive = false;
  bool _isLoading = true;
  bool _isChangingStatus = false;
  bool _hasError = false;
  String _errorMessage = '';
  List<Map<String, dynamic>> _activeOrders = [];
  Driver? _driverData;
  String? _driverId;
  Timer? _locationUpdateTimer;
  Position? _currentPosition;
  bool _isLocationPermissionGranted = false;

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();

    // Initialize date formatting for Indonesian locale
    initializeDateFormatting('id_ID', null);

    // Initialize notifications and permissions
    _initializeNotifications();
    _requestPermissions();

    // Initialize driver data and active orders
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = '';
      });

      // Get driver data and status from local storage (saved during login)
      await Future.wait([
        _getDriverData(),
        _getDriverStatus(),
      ]);

      // Get active orders if driver is active
      if (_isDriverActive) {
        await _fetchDriverOrders();
        // Initialize location tracking if driver is active
        _initializeLocationTracking();
      }

      // Initialize animations after fetching data
      _initializeAnimations();
    } catch (e) {
      print('Error initializing data: $e');
      setState(() {
        _hasError = true;
        _errorMessage = 'Gagal memuat data: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _initializeAnimations() {
    // Clear previous controllers if any
    for (var controller in _cardControllers) {
      controller.dispose();
    }

    // Initialize animation controllers for each delivery card
    _cardControllers = List.generate(
      _activeOrders.length,
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
    Future.delayed(const Duration(milliseconds: 100), () {
      for (var controller in _cardControllers) {
        controller.forward();
      }
    });
  }

  Future<void> _getDriverStatus() async {
    try {
      // Get user data from local storage (saved during login)
      final userData = await AuthService.getUserData();

      if (userData != null) {
        // Check if the user is a driver
        if (userData['role'] == 'driver') {
          // Get the driver ID
          final driverId = userData['id'];
          if (driverId != null) {
            // Save driver ID for later use
            _driverId = driverId.toString();

            // Update status based on stored user data
            setState(() {
              _isDriverActive = (userData['status'] ?? 'inactive').toLowerCase() == 'active';
            });

            print('Driver status: ${_isDriverActive ? 'Active' : 'Inactive'}');
            print('Driver ID: $_driverId');
          } else {
            print('Error: Driver ID is null in user data');
          }
        } else {
          print('Error: User role is not driver. Role: ${userData['role']}');
        }
      } else {
        print('Error: User data is null');

        // Try to get the user data from the server as fallback
        try {
          final profileData = await AuthService.getProfile();
          if (profileData != null && profileData['role'] == 'driver') {
            _driverId = profileData['id']?.toString();
            setState(() {
              _isDriverActive = (profileData['status'] ?? 'inactive').toLowerCase() == 'active';
            });
            print('Driver status (from profile): ${_isDriverActive ? 'Active' : 'Inactive'}');
          }
        } catch (e) {
          print('Error fetching profile data: $e');
        }
      }
    } catch (e) {
      print('Error getting driver status: $e');
      // Default to inactive if there's an error
      setState(() {
        _isDriverActive = false;
        _hasError = true;
        _errorMessage = 'Gagal mendapatkan status driver: $e';
      });
    }
  }

  Future<void> _getDriverData() async {
    try {
      // Get user data directly from AuthService (stored during login)
      final userData = await AuthService.getUserData();

      if (userData != null) {
        // Check if the user is a driver
        if (userData['role'] == 'driver') {
          final driverId = userData['id'];
          if (driverId != null) {
            // Save driver ID for later use
            _driverId = driverId.toString();

            // Create Driver object directly from user data
            setState(() {
              _driverData = Driver.fromStoredData(userData);
            });

            print('Driver data loaded successfully');
          } else {
            print('Error: Driver ID is null in user data');
          }
        } else {
          print('Error: User role is not driver. Role: ${userData['role']}');
        }
      } else {
        print('Error: User data is null');

        // Try to get the profile from server as fallback
        try {
          final profileData = await AuthService.getProfile();
          if (profileData != null) {
            setState(() {
              _driverData = Driver.fromStoredData(profileData);
              _driverId = profileData['id']?.toString();
            });
            print('Driver data loaded from profile');
          }
        } catch (e) {
          print('Error fetching profile data: $e');
        }
      }
    } catch (e) {
      print('Error getting driver data: $e');
      setState(() {
        _hasError = true;
        _errorMessage = 'Gagal memuat data driver: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat data driver: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _fetchDriverOrders() async {
    try {
      print('Fetching driver orders...');

      // Check if token exists
      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Token not found. Please login again.');
      }

      print('Using token: ${token.substring(0, min(10, token.length))}...');

      // First get all driver requests
      final driverRequests = await DriverService.getDriverRequests();
      print('Driver requests response received');

      List<Map<String, dynamic>> activeOrdersList = [];

      if (driverRequests != null && driverRequests.containsKey('requests')) {
        // For each request, get the details
        for (var request in driverRequests['requests']) {
          String requestId = request['id'].toString();
          try {
            // Get details for each driver request
            final requestDetail = await DriverService.getDriverRequestDetail(requestId);

            if (requestDetail != null && requestDetail.containsKey('order')) {
              var order = requestDetail['order'];

              // Check if order status is active (assigned, picking_up, delivering)
              String deliveryStatus = order['delivery_status'] ?? '';
              if (['assigned', 'picking_up', 'on_delivery'].contains(deliveryStatus.toLowerCase())) {
                // Format the order data for UI
                Map<String, dynamic> formattedOrder = {
                  'orderId': order['id'].toString(),
                  'customerName': order['user']?['name'] ?? 'Customer',
                  'orderTime': order['created_at'] != null
                      ? DateTime.parse(order['created_at'])
                      : DateTime.now(),
                  'totalPrice': double.tryParse(order['total'].toString()) ?? 0.0,
                  'status': deliveryStatus.toLowerCase(),
                  'items': order['items'] ?? [],
                  'deliveryFee': double.tryParse(order['service_charge'].toString()) ?? 0.0,
                  'amount': double.tryParse(order['total'].toString()) ?? 0.0,
                  'storeAddress': order['store']?['address'] ?? 'Address not available',
                  'customerAddress': order['delivery_address'] ?? 'Address not available',
                  'storePhone': order['store']?['phone'] ?? '',
                  'customerPhone': order['user']?['phone'] ?? '',
                  'code': order['code'] ?? '',
                  // Include the full order for the detail page
                  'orderDetail': order,
                  // Include the request for reference
                  'requestId': requestId,
                };

                activeOrdersList.add(formattedOrder);
              }
            }
          } catch (e) {
            print('Error fetching details for request $requestId: $e');
            // Continue with other requests even if one fails
          }
        }
      }

      print('Found ${activeOrdersList.length} active orders');

      setState(() {
        _activeOrders = activeOrdersList;
        _hasError = false;
        _errorMessage = '';
      });

      // Show notification for new orders if there are any
      if (activeOrdersList.isNotEmpty && _isDriverActive) {
        // Only show notification for the newest order
        _showNotification(activeOrdersList[0]);
      }
    } catch (e) {
      print('Error fetching driver orders: $e');
      setState(() {
        _hasError = true;
        _errorMessage = 'Gagal memuat pesanan: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat pesanan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Location handling methods
  Future<void> _requestLocationPermission() async {
    final status = await Permission.location.request();

    setState(() {
      _isLocationPermissionGranted = status.isGranted;
    });

    if (!status.isGranted) {
      // Show a message that location permission is required
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Izin lokasi diperlukan untuk menjadi driver aktif'),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'Pengaturan',
              onPressed: () async {
                await openAppSettings();
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    if (!_isLocationPermissionGranted) {
      await _requestLocationPermission();
      if (!_isLocationPermissionGranted) return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
      });

      // Update the location to the server
      await _updateDriverLocation();
    } catch (e) {
      print('Error getting current location: $e');
    }
  }

  Future<void> _updateDriverLocation() async {
    if (_currentPosition != null && _isDriverActive) {
      try {
        await DriverService.updateDriverLocation({
          'latitude': _currentPosition!.latitude,
          'longitude': _currentPosition!.longitude,
        });

        // Update local driver data if it exists
        if (_driverData != null) {
          setState(() {
            _driverData = _driverData!.copyWith(
              latitude: _currentPosition!.latitude,
              longitude: _currentPosition!.longitude,
            );
          });
        }

        print('Driver location updated successfully');
      } catch (e) {
        print('Error updating driver location: $e');
      }
    }
  }

  void _initializeLocationTracking() async {
    // Check and request location permission
    await _requestLocationPermission();

    if (_isLocationPermissionGranted) {
      // Get initial location
      await _getCurrentLocation();

      // Set up periodic location updates if not already set up
      _locationUpdateTimer?.cancel();
      _locationUpdateTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
        if (_isDriverActive) {
          await _getCurrentLocation();
        } else {
          timer.cancel();
          _locationUpdateTimer = null;
        }
      });
    }
  }

  void _stopLocationTracking() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@drawable/launch_background');

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
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        // Handle notification tap
        if (_activeOrders.isNotEmpty) {
          _showNewOrderDialog(_activeOrders[0]);
        }
      },
    );
  }

  Future<void> _requestPermissions() async {
    await Permission.notification.request();
    // Request location permission if the driver is active
    if (_isDriverActive) {
      await _requestLocationPermission();
    }
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
      icon: '@mipmap/delpick', // Updated to use custom icon
    );

    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.show(
      0,
      'Pesanan Baru!',
      'Pelanggan: ${orderDetails['customerName']} - ${GlobalStyle.formatRupiah(orderDetails['totalPrice'] ?? 0)}',
      platformChannelSpecifics,
    );
  }

  Future<void> _playSound(String assetPath) async {
    await _audioPlayer.play(AssetSource(assetPath));
  }

  Future<void> _showNewOrderDialog(Map<String, dynamic> order) async {
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
                  'Pelanggan: ${order['customerName']}',
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
                Text(
                  'Total: ${GlobalStyle.formatRupiah(order['totalPrice'] ?? 0)}',
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
                          orderDetail: order,
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
                    _fetchDriverOrders(); // Refresh orders when becoming active
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
              onPressed: () {
                Navigator.of(context).pop();
                _toggleDriverStatus();
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

  Future<void> _toggleDriverStatus() async {
    try {
      setState(() {
        _isChangingStatus = true;
      });

      String newStatus = _isDriverActive ? 'inactive' : 'active';

      // Call the DriverService to update the status in the database
      final response = await DriverService.changeDriverStatus(newStatus);

      if (response != null) {
        // Update local state with new status
        setState(() {
          _isDriverActive = newStatus == 'active';
        });

        // Update driver data
        if (_driverData != null) {
          setState(() {
            _driverData = _driverData!.copyWith(status: newStatus);
          });
        }

        // Start or stop location tracking based on status
        if (_isDriverActive) {
          // Initialize location tracking when activated
          _initializeLocationTracking();

          // Update orders
          await _fetchDriverOrders();
          _showDriverActiveDialog();
        } else {
          // Stop location tracking when deactivated
          _stopLocationTracking();

          setState(() {
            _activeOrders = [];
          });
          // Reinitialize animations after clearing orders
          _initializeAnimations();

          // Show success message for deactivation
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Status driver dinonaktifkan'),
              backgroundColor: Colors.orange,
            ),
          );
        }

        // Also update status in user data stored locally
        final userData = await AuthService.getUserData();
        if (userData != null) {
          userData['status'] = newStatus;
          // Store updated user data
          await ApiConstants.storage.write(
            key: 'user_profile',
            value: jsonEncode(userData),
          );
        }
      }
    } catch (e) {
      print('Error toggling driver status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengubah status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isChangingStatus = false;
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _cardControllers) {
      controller.dispose();
    }
    _locationUpdateTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'assigned':
        return Colors.blue;
      case 'picking_up':
        return Colors.orange;
      case 'on_delivery':
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
      case 'on_delivery':
        return 'Diantar';
      default:
        return status.toUpperCase(); // Return capitalized status if not known
    }
  }

  Widget _buildDeliveryCard(Map<String, dynamic> delivery, int index) {
    String status = delivery['status'] as String;

    return SlideTransition(
      position: _cardAnimations.length > index ? _cardAnimations[index] : const AlwaysStoppedAnimation(Offset.zero),
      child: Container(
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
                                delivery['customerName'] ?? 'Customer',
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
                            Icon(Icons.access_time,
                                color: GlobalStyle.fontColor, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              // Indonesian date format
                              DateFormat('dd MMMM yyyy HH:mm', 'id_ID')
                                  .format(delivery['orderTime'] ?? DateTime.now()),
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
                            Icon(Icons.payments,
                                color: GlobalStyle.primaryColor, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              GlobalStyle.formatRupiah(delivery['totalPrice'] ?? 0),
                              style: TextStyle(
                                color: GlobalStyle.primaryColor,
                                fontWeight: FontWeight.bold,
                                fontFamily: GlobalStyle.fontFamily,
                              ),
                            ),
                          ],
                        ),
                        if (delivery['code'] != null && delivery['code'].toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              children: [
                                Icon(Icons.qr_code,
                                    color: GlobalStyle.fontColor, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  'Kode: ${delivery['code']}',
                                  style: TextStyle(
                                    color: GlobalStyle.fontColor,
                                    fontFamily: GlobalStyle.fontFamily,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: GlobalStyle.lightColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on, color: GlobalStyle.primaryColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Jemput: ${delivery['storeAddress'] ?? 'Alamat toko tidak tersedia'}',
                            style: TextStyle(
                              color: GlobalStyle.fontColor,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Antar: ${delivery['customerAddress'] ?? 'Alamat pelanggan tidak tersedia'}',
                            style: TextStyle(
                              color: GlobalStyle.fontColor,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HistoryDriverDetailPage(
                        orderDetail: delivery,
                      ),
                    ),
                  ).then((_) {
                    // Refresh data when returning from detail page
                    _fetchDriverOrders();
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
            _isDriverActive
                ? 'Silakan tunggu pesanan baru'
                : 'Aktifkan status untuk menerima pesanan',
            style: TextStyle(
              color: GlobalStyle.fontColor.withOpacity(0.7),
              fontSize: 14,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Memuat data...'),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 64),
          const SizedBox(height: 16),
          Text(
            'Gagal memuat pesanan',
            style: TextStyle(
              color: GlobalStyle.fontColor,
              fontSize: 16,
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
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _initializeData,
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
                              // Indonesian date format
                              DateFormat('EEEE, dd MMMM yyyy', 'id_ID')
                                  .format(DateTime.now()),
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
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ProfileDriverPage(),
                              ),
                            ).then((_) {
                              // Refresh data when returning from profile page
                              _initializeData();
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: GlobalStyle.lightColor.withOpacity(0.3),
                              shape: BoxShape.circle,
                            ),
                            child: FaIcon(
                              FontAwesomeIcons.user,
                              size: 20,
                              color: GlobalStyle.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Status toggle button
                    ElevatedButton.icon(
                      onPressed: (_isLoading || _isChangingStatus) ? null : () {
                        if (_isDriverActive) {
                          _showDeactivateConfirmationDialog();
                        } else {
                          _toggleDriverStatus();
                        }
                      },
                      icon: _isChangingStatus
                          ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                          : Icon(
                        _isDriverActive ? Icons.toggle_on : Icons.toggle_off,
                        color: Colors.white,
                        size: 24,
                      ),
                      label: Text(
                        _isChangingStatus
                            ? 'Mengubah status...'
                            : (_isDriverActive
                            ? 'Status: Aktif'
                            : 'Status: Tidak Aktif'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                        _isDriverActive ? Colors.green : Colors.red,
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
                    ? _buildLoadingIndicator()
                    : _hasError
                    ? _buildErrorState()
                    : _activeOrders.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                  onRefresh: _fetchDriverOrders,
                  child: ListView.builder(
                    itemCount: _activeOrders.length,
                    itemBuilder: (context, index) =>
                        _buildDeliveryCard(_activeOrders[index], index),
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

// Helper function to find minimum of two values
int min(int a, int b) {
  return a < b ? a : b;
}