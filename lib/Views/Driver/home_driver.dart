import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Views/Component/driver_bottom_navigation.dart';
import 'package:del_pick/Views/Driver/history_driver_detail.dart';
import 'package:del_pick/Views/Driver/contact_user.dart';
import 'package:del_pick/Views/Driver/profil_driver.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:lottie/lottie.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';

// Import services
import 'package:del_pick/Services/driver_service.dart';
import 'package:del_pick/Services/driver_request_service.dart';
import 'package:del_pick/Services/order_service.dart';
import 'package:del_pick/Services/auth_service.dart';
import 'package:del_pick/Services/image_service.dart';

class HomeDriverPage extends StatefulWidget {
  static const String route = '/Driver/HomePage';
  const HomeDriverPage({Key? key}) : super(key: key);

  @override
  State<HomeDriverPage> createState() => _HomeDriverPageState();
}

class _HomeDriverPageState extends State<HomeDriverPage>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  // Tab Controller for Regular Orders vs Jasa Titip
  late TabController _tabController;

  // Navigation
  int _currentIndex = 0;

  // Driver Status
  String _driverStatus = 'inactive'; // active, inactive, busy
  bool _isUpdatingStatus = false;

  // Driver & User Data
  Map<String, dynamic>? _driverData;
  Map<String, dynamic>? _userData;
  String? _driverId;

  // Orders & Requests Data
  List<Map<String, dynamic>> _regularOrders = [];
  List<Map<String, dynamic>> _jasaTitipRequests = [];

  // Loading States
  bool _isLoadingOrders = false;
  bool _isLoadingRequests = false;
  bool _isInitialLoading = true;

  // Error States
  String? _errorMessage;

  // Animations
  late List<AnimationController> _cardControllers;
  late List<Animation<Offset>> _cardAnimations;
  late AnimationController _statusController;
  late Animation<double> _statusAnimation;

  // Notifications & Audio
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Polling Timers
  Timer? _orderPollingTimer;
  Timer? _requestPollingTimer;

  @override
  void initState() {
    super.initState();

    // Initialize Tab Controller
    _tabController = TabController(length: 2, vsync: this);

    // Initialize Animations
    _initializeAnimations();

    // Initialize Notifications
    _initializeNotifications();

    // Request Permissions
    _requestPermissions();

    // Load Initial Data
    _initializeAuthentication();

    // Start Periodic Updates
    _startPeriodicUpdates();
  }

  void _initializeAnimations() {
    _statusController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _statusAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _statusController, curve: Curves.elasticOut),
    );

    _cardControllers = List.generate(
      6,
          (index) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 600 + (index * 200)),
      ),
    );

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
    Future.delayed(const Duration(milliseconds: 300), () {
      _statusController.forward();
      for (var controller in _cardControllers) {
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
        _handleNotificationTap(details);
      },
    );
  }

  Future<void> _requestPermissions() async {
    await Permission.notification.request();
    await Permission.location.request();
  }

  // Initialize authentication and load driver data
  Future<void> _initializeAuthentication() async {
    setState(() {
      _isInitialLoading = true;
      _errorMessage = null;
    });

    try {
      print('🔍 HomeDriver: Initializing authentication...');

      // Check authentication status
      final isAuth = await AuthService.isAuthenticated();
      if (!isAuth) {
        throw Exception('User not authenticated');
      }

      // Get user data
      final userData = await AuthService.getUserData();
      if (userData == null) {
        throw Exception('No user data found');
      }

      // Get role-specific data
      final roleSpecificData = await AuthService.getRoleSpecificData();
      if (roleSpecificData == null) {
        throw Exception('No role-specific data found');
      }

      // Verify user role
      final userRole = await AuthService.getUserRole();
      if (userRole?.toLowerCase() != 'driver') {
        throw Exception('User is not a driver');
      }

      // Extract driver information
      _userData = userData;
      _driverData = roleSpecificData;

      // Get driver ID from various possible locations
      if (roleSpecificData['driver'] != null) {
        _driverId = roleSpecificData['driver']['id']?.toString();
        _driverStatus = roleSpecificData['driver']['status'] ?? 'inactive';
      } else if (roleSpecificData['user'] != null) {
        _driverId = roleSpecificData['user']['id']?.toString();
      } else if (userData['id'] != null) {
        _driverId = userData['id']?.toString();
      }

      if (_driverId == null || _driverId!.isEmpty) {
        throw Exception('Driver ID not found');
      }

      print('✅ HomeDriver: Authentication successful, Driver ID: $_driverId, Status: $_driverStatus');

      // Load initial data
      await _loadInitialData();

    } catch (e) {
      print('❌ HomeDriver: Authentication error: $e');
      setState(() {
        _isInitialLoading = false;
        _errorMessage = 'Authentication failed: $e';
      });
    }
  }

  // Load initial orders and requests data
  Future<void> _loadInitialData() async {
    try {
      await Future.wait([
        _loadRegularOrders(),
        _loadJasaTitipRequests(),
      ]);

      setState(() {
        _isInitialLoading = false;
      });

    } catch (e) {
      print('❌ HomeDriver: Error loading initial data: $e');
      setState(() {
        _isInitialLoading = false;
        _errorMessage = 'Failed to load data: $e';
      });
    }
  }

  // Load regular orders using DriverService.getDriverOrders()
  Future<void> _loadRegularOrders() async {
    if (!mounted || _driverId == null) return;

    setState(() {
      _isLoadingOrders = true;
    });

    try {
      print('🔄 HomeDriver: Loading regular orders...');

      final response = await DriverService.getDriverOrders(
        page: 1,
        limit: 20,
        status: null, // Get all active orders
        sortBy: 'created_at',
        sortOrder: 'desc',
      );

      print('📦 HomeDriver: Regular orders response received');

      final ordersData = response['orders'] ?? response['data'] ?? [];
      List<Map<String, dynamic>> activeOrders = [];

      // Filter only active orders (not completed/cancelled)
      for (var orderData in ordersData) {
        final String status = orderData['status'] ?? orderData['orderStatus'] ?? 'pending';
        if (['confirmed', 'preparing', 'ready_for_pickup', 'on_delivery'].contains(status.toLowerCase())) {
          activeOrders.add(orderData);
        }
      }

      setState(() {
        _regularOrders = activeOrders;
        _isLoadingOrders = false;
      });

      print('✅ HomeDriver: Loaded ${activeOrders.length} regular orders');

    } catch (e) {
      print('❌ HomeDriver: Error loading regular orders: $e');
      setState(() {
        _regularOrders = [];
        _isLoadingOrders = false;
      });
    }
  }

  // Load jasa titip requests using DriverRequestService.getDriverRequests()
  Future<void> _loadJasaTitipRequests() async {
    if (!mounted || _driverId == null) return;

    setState(() {
      _isLoadingRequests = true;
    });

    try {
      print('🔄 HomeDriver: Loading jasa titip requests...');

      final response = await DriverRequestService.getDriverRequests(
        page: 1,
        limit: 20,
        status: 'pending', // Only pending requests
        sortBy: 'created_at',
        sortOrder: 'desc',
      );

      print('📦 HomeDriver: Jasa titip requests response received');

      final requestsData = response['requests'] ?? response['data'] ?? [];

      setState(() {
        _jasaTitipRequests = List<Map<String, dynamic>>.from(requestsData);
        _isLoadingRequests = false;
      });

      print('✅ HomeDriver: Loaded ${requestsData.length} jasa titip requests');

    } catch (e) {
      print('❌ HomeDriver: Error loading jasa titip requests: $e');
      setState(() {
        _jasaTitipRequests = [];
        _isLoadingRequests = false;
      });
    }
  }

  // Start periodic polling for new orders and requests
  void _startPeriodicUpdates() {
    // Poll for new orders every 30 seconds when active
    _orderPollingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_driverStatus == 'active' && mounted && _driverId != null) {
        _loadRegularOrders();
      }
    });

    // Poll for new requests every 20 seconds when active
    _requestPollingTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      if (_driverStatus == 'active' && mounted && _driverId != null) {
        _loadJasaTitipRequests();
      }
    });
  }

  // Toggle driver status
  Future<void> _toggleDriverStatus() async {
    if (_isUpdatingStatus || _driverId == null) return;

    if (_driverStatus == 'active') {
      _showDeactivateConfirmationDialog();
    } else {
      await _setDriverStatus('active');
    }
  }

  // Set driver status using AuthService.updateProfile
  Future<void> _setDriverStatus(String newStatus) async {
    if (_driverId == null) {
      _showErrorDialog('Driver ID tidak ditemukan. Silakan login ulang.');
      return;
    }

    setState(() {
      _isUpdatingStatus = true;
    });

    try {
      print('🔄 HomeDriver: Updating driver status to: $newStatus');

      // Use AuthService to update profile
      final updateData = {
        'driver': {
          'status': newStatus,
        }
      };

      await AuthService.updateProfile(updateData: updateData);

      setState(() {
        _driverStatus = newStatus;
        _isUpdatingStatus = false;
      });

      print('✅ HomeDriver: Driver status updated to: $newStatus');

      // Show status dialog
      if (newStatus == 'active') {
        _showDriverActiveDialog();
      }

      // Refresh data when status changes to active
      if (newStatus == 'active') {
        _loadRegularOrders();
        _loadJasaTitipRequests();
      }

    } catch (e) {
      print('❌ HomeDriver: Error updating driver status: $e');
      setState(() {
        _isUpdatingStatus = false;
      });
      _showErrorDialog('Gagal mengubah status driver: $e');
    }
  }

  // Accept regular order - Navigate to HistoryDriverDetailPage
  Future<void> _acceptRegularOrder(Map<String, dynamic> orderData) async {
    try {
      final String orderId = orderData['id'].toString();

      print('🔄 HomeDriver: Accepting regular order: $orderId');

      // Update order status to confirmed
      await OrderService.updateOrderStatus(
        orderId: orderId,
        status: 'confirmed',
        notes: 'Driver telah menerima pesanan',
      );

      // Play success sound
      _playSound('audio/kring.mp3');

      // Show success dialog and navigate to detail
      _showOrderAcceptedDialog(orderData, () {
        Navigator.pushNamed(
          context,
          HistoryDriverDetailPage.route,
          arguments: orderId,
        );
      });

      // Refresh orders list
      _loadRegularOrders();

      print('✅ HomeDriver: Regular order accepted successfully');

    } catch (e) {
      print('❌ HomeDriver: Error accepting regular order: $e');
      _showErrorDialog('Gagal menerima pesanan: $e');
    }
  }

  // Accept jasa titip request using DriverRequestService.respondToDriverRequest() - Navigate to ContactUserPage
  Future<void> _acceptJasaTitipRequest(Map<String, dynamic> requestData) async {
    try {
      final String requestId = requestData['id'].toString();

      print('🔄 HomeDriver: Accepting jasa titip request: $requestId');

      // Use respondToDriverRequest with accept action
      await DriverRequestService.respondToDriverRequest(
        requestId: requestId,
        action: 'accept',
        estimatedPickupTime: DateTime.now().add(Duration(minutes: 15)).toIso8601String(),
        estimatedDeliveryTime: DateTime.now().add(Duration(hours: 1)).toIso8601String(),
        notes: 'Driver akan segera menghubungi Anda untuk detail pembelian',
      );

      // Play success sound
      _playSound('audio/kring.mp3');

      // Show success dialog and navigate to contact user
      _showRequestAcceptedDialog(requestData, () {
        // Extract order ID from request data
        final orderId = requestData['order']?['id']?.toString() ?? requestData['orderId']?.toString();

        if (orderId != null) {
          Navigator.pushNamed(
            context,
            ContactUserPage.route,
            arguments: {
              'orderId': orderId,
              'orderDetail': requestData,
            },
          );
        } else {
          _showErrorDialog('Order ID tidak ditemukan dalam request data');
        }
      });

      // Refresh requests list
      _loadJasaTitipRequests();

      print('✅ HomeDriver: Jasa titip request accepted successfully');

    } catch (e) {
      print('❌ HomeDriver: Error accepting jasa titip request: $e');
      _showErrorDialog('Gagal menerima permintaan: $e');
    }
  }

  // Reject jasa titip request using DriverRequestService.respondToDriverRequest()
  Future<void> _rejectJasaTitipRequest(Map<String, dynamic> requestData) async {
    try {
      final String requestId = requestData['id'].toString();

      print('🔄 HomeDriver: Rejecting jasa titip request: $requestId');

      // Use respondToDriverRequest with reject action
      await DriverRequestService.respondToDriverRequest(
        requestId: requestId,
        action: 'reject',
        notes: 'Driver tidak tersedia saat ini',
      );

      // Play rejection sound
      _playSound('audio/wrong.mp3');

      // Refresh requests list
      _loadJasaTitipRequests();

      print('✅ HomeDriver: Jasa titip request rejected successfully');

    } catch (e) {
      print('❌ HomeDriver: Error rejecting jasa titip request: $e');
      _showErrorDialog('Gagal menolak permintaan: $e');
    }
  }

  // Navigate to Profile
  void _navigateToProfile() async {
    try {
      print('🔄 HomeDriver: Navigating to ProfileDriverPage...');
      await Navigator.pushNamed(context, ProfileDriverPage.route);
    } catch (e) {
      print('❌ HomeDriver: Error navigating to profile: $e');
      _showErrorDialog('Gagal membuka halaman profil: $e');
    }
  }

  // Handle notification tap
  void _handleNotificationTap(NotificationResponse details) {
    if (details.payload != null) {
      final data = details.payload!.split('|');
      if (data.length >= 2) {
        final type = data[0];
        final id = data[1];

        if (type == 'order') {
          Navigator.pushNamed(context, HistoryDriverDetailPage.route, arguments: id);
        } else if (type == 'request') {
          Navigator.pushNamed(context, ContactUserPage.route, arguments: {'orderId': id});
        }
      }
    }
  }

  // Sound effects
  Future<void> _playSound(String assetPath) async {
    try {
      await _audioPlayer.play(AssetSource(assetPath));
    } catch (e) {
      print('Error playing sound: $e');
    }
  }

  // Dialog methods
  void _showDriverActiveDialog() async {
    await _playSound('audio/found.wav');

    if (mounted) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                  'Anda akan menerima pesanan dan permintaan jasa titip.',
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlobalStyle.primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
            'Anda yakin ingin menonaktifkan status? Anda tidak akan menerima pesanan atau permintaan baru.',
            style: TextStyle(
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
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
                _setDriverStatus('inactive');
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

  void _showOrderAcceptedDialog(Map<String, dynamic> orderData, VoidCallback onViewDetail) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset(
                'assets/animations/check_animation.json',
                width: 150,
                height: 150,
                repeat: false,
              ),
              const SizedBox(height: 16),
              Text(
                'Pesanan Diterima!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: GlobalStyle.fontFamily,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Order #${orderData['id']}',
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: GlobalStyle.fontFamily,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onViewDetail();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlobalStyle.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  minimumSize: const Size(double.infinity, 45),
                ),
                child: Text(
                  'Lihat Detail Pesanan',
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

  void _showRequestAcceptedDialog(Map<String, dynamic> requestData, VoidCallback onContactCustomer) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset(
                'assets/animations/check_animation.json',
                width: 150,
                height: 150,
                repeat: false,
              ),
              const SizedBox(height: 16),
              Text(
                'Jasa Titip Diterima!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: GlobalStyle.fontFamily,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Silakan hubungi customer untuk koordinasi lebih lanjut.',
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: GlobalStyle.fontFamily,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onContactCustomer();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlobalStyle.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  minimumSize: const Size(double.infinity, 45),
                ),
                child: Text(
                  'Hubungi Customer',
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

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Error',
            style: TextStyle(
              fontFamily: GlobalStyle.fontFamily,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            message,
            style: TextStyle(
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: GlobalStyle.primaryColor,
              ),
              child: Text(
                'OK',
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

  @override
  void dispose() {
    _tabController.dispose();
    _statusController.dispose();
    for (var controller in _cardControllers) {
      controller.dispose();
    }
    _audioPlayer.dispose();
    _orderPollingTimer?.cancel();
    _requestPollingTimer?.cancel();
    super.dispose();
  }

  // Helper methods for status
  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'busy':
        return Colors.orange;
      case 'inactive':
      default:
        return Colors.red;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'active':
        return 'Aktif';
      case 'busy':
        return 'Sibuk';
      case 'inactive':
      default:
        return 'Tidak Aktif';
    }
  }

  // Build regular order card
  Widget _buildRegularOrderCard(Map<String, dynamic> orderData, int index) {
    final String customerName = orderData['customer']?['name'] ?? orderData['user']?['name'] ?? 'Customer';
    final String storeName = orderData['store']?['name'] ?? 'Store';
    final double totalAmount = ((orderData['total_amount'] ?? orderData['totalAmount'] ?? orderData['total']) ?? 0).toDouble();
    final String status = orderData['status'] ?? orderData['orderStatus'] ?? 'pending';
    final String orderId = orderData['id'].toString();
    final createdAt = orderData['created_at'] ?? orderData['createdAt'] ?? DateTime.now().toIso8601String();

    return SlideTransition(
      position: _cardAnimations[index % _cardAnimations.length],
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: GlobalStyle.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.shopping_bag,
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
                          'Pesanan Regular',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                        Text(
                          'Order #$orderId',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getOrderStatusColor(status),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getOrderStatusLabel(status),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Customer & Store Info
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.person, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              'Customer:',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        Text(
                          customerName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.store, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              'Toko:',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        Text(
                          storeName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        GlobalStyle.formatRupiah(totalAmount),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: GlobalStyle.primaryColor,
                          fontFamily: GlobalStyle.fontFamily,
                        ),
                      ),
                      Text(
                        DateFormat('dd/MM, HH:mm').format(DateTime.parse(createdAt)),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          HistoryDriverDetailPage.route,
                          arguments: orderId,
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: GlobalStyle.primaryColor,
                        side: BorderSide(color: GlobalStyle.primaryColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Detail'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _acceptRegularOrder(orderData),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GlobalStyle.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Terima'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build jasa titip request card
  Widget _buildJasaTitipCard(Map<String, dynamic> requestData, int index) {
    final Map<String, dynamic> orderData = requestData['order'] ?? {};
    final String customerName = orderData['customer']?['name'] ?? orderData['user']?['name'] ?? 'Customer';
    final String notes = requestData['notes'] ?? orderData['notes'] ?? orderData['description'] ?? 'Tidak ada catatan';
    final String location = requestData['location'] ?? orderData['delivery_address'] ?? orderData['deliveryAddress'] ?? 'Lokasi tidak tersedia';
    final double deliveryFee = ((requestData['delivery_fee'] ?? requestData['deliveryFee'] ?? orderData['delivery_fee'] ?? orderData['deliveryFee']) ?? 0).toDouble();
    final String requestId = requestData['id'].toString();
    final createdAt = requestData['created_at'] ?? requestData['createdAt'] ?? DateTime.now().toIso8601String();

    return SlideTransition(
      position: _cardAnimations[index % _cardAnimations.length],
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.local_shipping,
                      color: Colors.orange,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Jasa Titip',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                        Text(
                          'Request #$requestId',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Pending',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Customer Info & Date
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.person, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          customerName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        GlobalStyle.formatRupiah(deliveryFee),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                          fontFamily: GlobalStyle.fontFamily,
                        ),
                      ),
                      Text(
                        DateFormat('dd/MM, HH:mm').format(DateTime.parse(createdAt)),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Location
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      location,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                        fontFamily: GlobalStyle.fontFamily,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Notes
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Catatan Permintaan:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notes,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[800],
                        fontFamily: GlobalStyle.fontFamily,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _rejectJasaTitipRequest(requestData),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Tolak'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _acceptJasaTitipRequest(requestData),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Terima'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper methods for order status
  Color _getOrderStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Colors.blue;
      case 'preparing':
        return Colors.purple;
      case 'ready_for_pickup':
        return Colors.orange;
      case 'on_delivery':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  String _getOrderStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return 'Dikonfirmasi';
      case 'preparing':
        return 'Disiapkan';
      case 'ready_for_pickup':
        return 'Siap Diambil';
      case 'on_delivery':
        return 'Diantar';
      default:
        return 'Pending';
    }
  }

  // Build empty state
  Widget _buildEmptyState(String type) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/animations/empty.json',
            width: 200,
            height: 200,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 16),
          Text(
            type == 'regular' ? 'Tidak ada pesanan regular' : 'Tidak ada permintaan jasa titip',
            style: TextStyle(
              color: GlobalStyle.fontColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _driverStatus == 'active'
                ? 'Anda akan melihat ${type == 'regular' ? 'pesanan' : 'permintaan'} baru di sini'
                : 'Aktifkan status untuk menerima ${type == 'regular' ? 'pesanan' : 'permintaan'}',
            style: TextStyle(
              color: GlobalStyle.fontColor.withOpacity(0.7),
              fontSize: 14,
              fontFamily: GlobalStyle.fontFamily,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isInitialLoading) {
      return Scaffold(
        backgroundColor: const Color(0xffD6E6F2),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset(
                'assets/animations/loading_animation.json',
                width: 150,
                height: 150,
              ),
              const SizedBox(height: 16),
              Text(
                "Memuat Data Driver...",
                style: TextStyle(
                  color: GlobalStyle.primaryColor,
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                  fontFamily: GlobalStyle.fontFamily,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xffD6E6F2),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 80,
                color: Colors.red[400],
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.red[700],
                    fontSize: 16,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _initializeAuthentication,
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlobalStyle.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xffD6E6F2),
      body: SafeArea(
        child: Column(
          children: [
            // Header Section
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
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
                            'Driver Dashboard',
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
                              fontSize: 14,
                              fontFamily: GlobalStyle.fontFamily,
                            ),
                          ),
                          if (_driverId != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'ID Driver: $_driverId',
                              style: TextStyle(
                                color: GlobalStyle.fontColor.withOpacity(0.7),
                                fontSize: 12,
                                fontFamily: GlobalStyle.fontFamily,
                              ),
                            ),
                          ],
                        ],
                      ),
                      GestureDetector(
                        onTap: _navigateToProfile,
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
                  const SizedBox(height: 20),

                  // Status Toggle with Animation
                  AnimatedBuilder(
                    animation: _statusAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: 0.9 + (_statusAnimation.value * 0.1),
                        child: Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: _getStatusColor(_driverStatus).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: _isUpdatingStatus ? null : _toggleDriverStatus,
                            icon: _isUpdatingStatus
                                ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                                : Icon(
                              _driverStatus == 'active' ? Icons.toggle_on : Icons.toggle_off,
                              color: Colors.white,
                              size: 28,
                            ),
                            label: Text(
                              _isUpdatingStatus
                                  ? 'Mengubah Status...'
                                  : 'Status: ${_getStatusLabel(_driverStatus)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _getStatusColor(_driverStatus),
                              disabledBackgroundColor: Colors.grey,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              minimumSize: const Size(double.infinity, 55),
                              elevation: 0,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Tab Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: GlobalStyle.primaryColor,
                indicatorWeight: 3,
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: GlobalStyle.primaryColor,
                unselectedLabelColor: Colors.grey[600],
                labelStyle: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  fontFamily: GlobalStyle.fontFamily,
                ),
                unselectedLabelStyle: TextStyle(
                  fontWeight: FontWeight.normal,
                  fontSize: 16,
                  fontFamily: GlobalStyle.fontFamily,
                ),
                tabs: [
                  Tab(
                    icon: Icon(Icons.delivery_dining, size: 20),
                    text: 'Pesanan Regular',
                  ),
                  Tab(
                    icon: Icon(Icons.local_shipping, size: 20),
                    text: 'Jasa Titip',
                  ),
                ],
              ),
            ),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Regular Orders Tab
                  RefreshIndicator(
                    onRefresh: _loadRegularOrders,
                    color: GlobalStyle.primaryColor,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      child: _isLoadingOrders
                          ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              color: GlobalStyle.primaryColor,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "Memuat pesanan...",
                              style: TextStyle(
                                color: GlobalStyle.primaryColor,
                                fontFamily: GlobalStyle.fontFamily,
                              ),
                            ),
                          ],
                        ),
                      )
                          : _regularOrders.isEmpty
                          ? _buildEmptyState('regular')
                          : ListView.builder(
                        itemCount: _regularOrders.length,
                        itemBuilder: (context, index) =>
                            _buildRegularOrderCard(_regularOrders[index], index),
                      ),
                    ),
                  ),

                  // Jasa Titip Tab
                  RefreshIndicator(
                    onRefresh: _loadJasaTitipRequests,
                    color: Colors.orange,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      child: _isLoadingRequests
                          ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              color: Colors.orange,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "Memuat permintaan...",
                              style: TextStyle(
                                color: Colors.orange,
                                fontFamily: GlobalStyle.fontFamily,
                              ),
                            ),
                          ],
                        ),
                      )
                          : _jasaTitipRequests.isEmpty
                          ? _buildEmptyState('jasa_titip')
                          : ListView.builder(
                        itemCount: _jasaTitipRequests.length,
                        itemBuilder: (context, index) =>
                            _buildJasaTitipCard(_jasaTitipRequests[index], index),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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