import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Views/Component/driver_bottom_navigation.dart';
import 'package:del_pick/Views/Driver/history_driver_detail.dart';
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
import 'package:del_pick/Services/tracking_service.dart';
import 'package:del_pick/Services/auth_service.dart';
import 'package:del_pick/Services/image_service.dart';
import 'package:del_pick/Models/driver.dart';
import 'package:del_pick/Models/order.dart';
import 'package:del_pick/Models/order_enum.dart';

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

  // Driver Profile
  DriverModel? _driverProfile;
  Map<String, dynamic>? _driverData;

  // Orders Data
  List<Map<String, dynamic>> _regularOrders = [];
  List<Map<String, dynamic>> _jasaTitipRequests = [];
  List<Map<String, dynamic>> _driverRequests = [];

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
    _loadInitialData();

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
      6, // Number of card sections
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

  Future<void> _loadInitialData() async {
    setState(() {
      _isInitialLoading = true;
      _errorMessage = null;
    });

    try {
      // Load driver profile
      await _loadDriverProfile();

      // Load orders and requests
      await Future.wait([
        _loadRegularOrders(),
        _loadJasaTitipRequests(),
        _loadDriverRequests(),
      ]);

    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal memuat data: $e';
      });
      print('Error loading initial data: $e');
    } finally {
      setState(() {
        _isInitialLoading = false;
      });
    }
  }

  // Load driver profile using AuthService
  Future<void> _loadDriverProfile() async {
    try {
      final userData = await AuthService.getRoleSpecificData();
      if (userData != null) {
        setState(() {
          _driverData = userData;
          if (userData['driver'] != null) {
            _driverProfile = DriverModel.fromJson(userData);
            _driverStatus = userData['driver']['status'] ?? 'inactive';
          }
        });
      }
    } catch (e) {
      print('Error loading driver profile: $e');
    }
  }

  // Load regular orders using DriverService.getDriverOrders()
  Future<void> _loadRegularOrders() async {
    if (!mounted) return;

    setState(() {
      _isLoadingOrders = true;
    });

    try {
      final response = await DriverService.getDriverOrders(
        page: 1,
        limit: 20,
        status: null, // Get all active orders
        sortBy: 'created_at',
        sortOrder: 'desc',
      );

      final ordersData = response['data'] ?? [];
      List<Map<String, dynamic>> activeOrders = [];

      // Filter only active orders (not completed/cancelled)
      for (var orderData in ordersData) {
        final String status = orderData['orderStatus'] ?? 'pending';
        if (['confirmed', 'preparing', 'ready_for_pickup', 'on_delivery'].contains(status)) {
          activeOrders.add(orderData);
        }
      }

      setState(() {
        _regularOrders = activeOrders;
        _isLoadingOrders = false;
      });

    } catch (e) {
      setState(() {
        _isLoadingOrders = false;
      });
      print('Error loading regular orders: $e');
    }
  }

  // Load jasa titip requests using DriverRequestService.getDriverRequests()
  Future<void> _loadJasaTitipRequests() async {
    if (!mounted) return;

    setState(() {
      _isLoadingRequests = true;
    });

    try {
      final response = await DriverRequestService.getDriverRequests(
        page: 1,
        limit: 20,
        status: 'pending', // Only pending requests
        sortBy: 'created_at',
        sortOrder: 'desc',
      );

      final requestsData = response['requests'] ?? [];

      setState(() {
        _jasaTitipRequests = List<Map<String, dynamic>>.from(requestsData);
        _isLoadingRequests = false;
      });

    } catch (e) {
      setState(() {
        _isLoadingRequests = false;
      });
      print('Error loading jasa titip requests: $e');
    }
  }

  // Load all driver requests for history
  Future<void> _loadDriverRequests() async {
    try {
      final response = await DriverRequestService.getDriverRequestHistory(
        page: 1,
        limit: 10,
        status: null,
      );

      final requestsData = response['requests'] ?? [];
      setState(() {
        _driverRequests = List<Map<String, dynamic>>.from(requestsData);
      });

    } catch (e) {
      print('Error loading driver requests: $e');
    }
  }

  // Start periodic polling for new orders and requests
  void _startPeriodicUpdates() {
    // Poll for new orders every 15 seconds when active
    _orderPollingTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (_driverStatus == 'active' && mounted) {
        _loadRegularOrders();
      }
    });

    // Poll for new requests every 10 seconds when active
    _requestPollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_driverStatus == 'active' && mounted) {
        _loadJasaTitipRequests();
      }
    });
  }

  // Toggle driver status using DriverService.updateDriverStatus()
  Future<void> _toggleDriverStatus() async {
    if (_isUpdatingStatus) return;

    if (_driverStatus == 'active') {
      _showDeactivateConfirmationDialog();
    } else {
      await _setDriverStatus('active');
    }
  }

  Future<void> _setDriverStatus(String newStatus) async {
    if (_driverProfile == null) return;

    setState(() {
      _isUpdatingStatus = true;
    });

    try {
      await DriverService.updateDriverStatus(
        driverId: _driverProfile!.driverId.toString(),
        status: newStatus,
      );

      setState(() {
        _driverStatus = newStatus;
        _isUpdatingStatus = false;
      });

      if (newStatus == 'active') {
        _showDriverActiveDialog();
      }

      // Refresh orders when status changes
      if (newStatus == 'active') {
        _loadRegularOrders();
        _loadJasaTitipRequests();
      }

    } catch (e) {
      setState(() {
        _isUpdatingStatus = false;
      });
      _showErrorDialog('Gagal mengubah status driver: $e');
    }
  }

  // Accept regular order
  Future<void> _acceptRegularOrder(Map<String, dynamic> orderData) async {
    try {
      final String orderId = orderData['id'].toString();

      // Update order status to accepted
      await OrderService.updateOrderStatus(
        orderId: orderId,
        status: 'confirmed',
        notes: 'Driver telah menerima pesanan',
      );

      // Show success and refresh
      _playSound('audio/kring.mp3');
      _showOrderAcceptedDialog(orderData);
      _loadRegularOrders();

    } catch (e) {
      _showErrorDialog('Gagal menerima pesanan: $e');
    }
  }

  // Accept jasa titip request using DriverRequestService.acceptDriverRequest()
  Future<void> _acceptJasaTitipRequest(Map<String, dynamic> requestData) async {
    try {
      final String requestId = requestData['id'].toString();

      await DriverRequestService.acceptDriverRequest(
        requestId: requestId,
        estimatedPickupTime: DateTime.now().add(Duration(minutes: 15)).toIso8601String(),
        estimatedDeliveryTime: DateTime.now().add(Duration(hours: 1)).toIso8601String(),
        notes: 'Driver akan segera menghubungi Anda',
      );

      _playSound('audio/kring.mp3');
      _showRequestAcceptedDialog(requestData);
      _loadJasaTitipRequests();

    } catch (e) {
      _showErrorDialog('Gagal menerima permintaan: $e');
    }
  }

  // Reject jasa titip request using DriverRequestService.rejectDriverRequest()
  Future<void> _rejectJasaTitipRequest(Map<String, dynamic> requestData) async {
    try {
      final String requestId = requestData['id'].toString();

      await DriverRequestService.rejectDriverRequest(
        requestId: requestId,
        reason: 'Driver tidak tersedia saat ini',
      );

      _playSound('audio/wrong.mp3');
      _loadJasaTitipRequests();

    } catch (e) {
      _showErrorDialog('Gagal menolak permintaan: $e');
    }
  }

  // Start delivery using TrackingService.startDelivery()
  Future<void> _startDelivery(String orderId) async {
    try {
      await TrackingService.startDelivery(orderId);

      // Update local status
      setState(() {
        _driverStatus = 'busy';
      });

      _showDeliveryStartedDialog();
      _loadRegularOrders();

    } catch (e) {
      _showErrorDialog('Gagal memulai pengiriman: $e');
    }
  }

  // Complete delivery using TrackingService.completeDelivery()
  Future<void> _completeDelivery(String orderId) async {
    try {
      await TrackingService.completeDelivery(orderId);

      // Update driver status back to active
      await _setDriverStatus('active');

      _showDeliveryCompletedDialog();
      _loadRegularOrders();

    } catch (e) {
      _showErrorDialog('Gagal menyelesaikan pengiriman: $e');
    }
  }

  // Handle notification tap
  void _handleNotificationTap(NotificationResponse details) {
    // Navigate to appropriate screen based on notification
    if (details.payload != null) {
      final data = details.payload!.split('|');
      if (data.length >= 2) {
        final type = data[0];
        final id = data[1];

        if (type == 'order') {
          _navigateToOrderDetail(id);
        } else if (type == 'request') {
          _navigateToRequestDetail(id);
        }
      }
    }
  }

  void _navigateToOrderDetail(String orderId) {
    // Navigate to order detail page
    Navigator.pushNamed(
      context,
      HistoryDriverDetailPage.route,
      arguments: orderId,
    );
  }

  void _navigateToRequestDetail(String requestId) {
    // Navigate to request detail page
    // Implementation depends on your request detail page
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
            'Anda yakin ingin menonaktifkan status? Anda tidak akan menerima pesanan baru.',
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

  void _showOrderAcceptedDialog(Map<String, dynamic> orderData) {
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
                  _navigateToOrderDetail(orderData['id'].toString());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlobalStyle.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  minimumSize: const Size(double.infinity, 45),
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
        );
      },
    );
  }

  void _showRequestAcceptedDialog(Map<String, dynamic> requestData) {
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
                'Permintaan Jasa Titip Diterima!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: GlobalStyle.fontFamily,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Silakan hubungi customer untuk detail lebih lanjut.',
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

  void _showDeliveryStartedDialog() {
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
                width: 150,
                height: 150,
              ),
              const SizedBox(height: 16),
              Text(
                'Pengiriman Dimulai!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: GlobalStyle.fontFamily,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Selamat mengantar. Hati-hati di jalan!',
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
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlobalStyle.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  minimumSize: const Size(double.infinity, 45),
                ),
                child: Text(
                  'OK',
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

  void _showDeliveryCompletedDialog() {
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
                'assets/animations/pesanan_selesai.json',
                width: 150,
                height: 150,
                repeat: false,
              ),
              const SizedBox(height: 16),
              Text(
                'Pengiriman Selesai!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: GlobalStyle.fontFamily,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Terima kasih atas pelayanan yang baik!',
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
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlobalStyle.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  minimumSize: const Size(double.infinity, 45),
                ),
                child: Text(
                  'OK',
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

  // Helper method to get status color
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

  // Helper method to get status label
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
    final String customerName = orderData['customer']?['name'] ?? 'Customer';
    final String storeName = orderData['store']?['name'] ?? 'Store';
    final double totalAmount = (orderData['total_amount'] ?? 0).toDouble();
    final String status = orderData['orderStatus'] ?? 'pending';
    final String orderId = orderData['id'].toString();

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
                        DateFormat('dd/MM, HH:mm').format(
                            DateTime.parse(orderData['created_at'] ?? DateTime.now().toIso8601String())
                        ),
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
                      onPressed: () => _navigateToOrderDetail(orderId),
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
                  if (status == 'confirmed' || status == 'preparing')
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
                  if (status == 'ready_for_pickup')
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _startDelivery(orderId),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Mulai Antar'),
                      ),
                    ),
                  if (status == 'on_delivery')
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _completeDelivery(orderId),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Selesai'),
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
    final String customerName = orderData['customer']?['name'] ?? 'Customer';
    final String notes = requestData['notes'] ?? 'Tidak ada catatan';
    final String location = requestData['location'] ?? 'Lokasi tidak tersedia';
    final double deliveryFee = (requestData['delivery_fee'] ?? 0).toDouble();
    final String requestId = requestData['id'].toString();

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

              // Customer Info
              Row(
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
                  const Spacer(),
                  Text(
                    GlobalStyle.formatRupiah(deliveryFee),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                      fontFamily: GlobalStyle.fontFamily,
                    ),
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
    switch (status) {
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
    switch (status) {
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
                onPressed: _loadInitialData,
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
                        ],
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(context, ProfileDriverPage.route);
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