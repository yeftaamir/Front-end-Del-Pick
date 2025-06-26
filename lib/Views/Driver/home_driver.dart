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

  // Tab Controller - ✅ PERBAIKAN: Simplified menjadi hanya satu tab untuk semua driver requests
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

  // ✅ PERBAIKAN: Unified driver requests (sekarang semua melalui driver request system)
  List<Map<String, dynamic>> _driverRequests = [];
  Map<String, dynamic> _requestStats = {};

  // Loading States
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
  Timer? _requestPollingTimer;

  @override
  void initState() {
    super.initState();

    // ✅ PERBAIKAN: Single tab controller untuk unified requests
    _tabController = TabController(length: 1, vsync: this);

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

  // ✅ PERBAIKAN: Enhanced authentication dengan driver validation
  Future<void> _initializeAuthentication() async {
    setState(() {
      _isInitialLoading = true;
      _errorMessage = null;
    });

    try {
      print('🔍 HomeDriver: Initializing authentication...');

      // ✅ PERBAIKAN: Use new driver validation method
      final hasDriverAccess = await AuthService.hasRole('driver');
      if (!hasDriverAccess) {
        throw Exception('User is not authenticated as driver');
      }

      // Get user and driver data
      final userData = await AuthService.getUserData();
      final roleSpecificData = await AuthService.getRoleSpecificData();

      if (userData == null || roleSpecificData == null) {
        throw Exception('Unable to retrieve user or driver data');
      }

      _userData = userData;
      _driverData = roleSpecificData;

      // Extract driver information
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

  // ✅ PERBAIKAN: Load all driver requests in one method
  Future<void> _loadInitialData() async {
    try {
      await Future.wait([
        _loadDriverRequests(),
        _loadDriverStats(),
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

  // ✅ PERBAIKAN: Unified method untuk load semua driver requests
  Future<void> _loadDriverRequests() async {
    if (!mounted || _driverId == null) return;

    setState(() {
      _isLoadingRequests = true;
    });

    try {
      print('🔄 HomeDriver: Loading driver requests...');

      // ✅ PERBAIKAN: Use DriverRequestService.getDriverRequests() untuk semua requests
      final response = await DriverRequestService.getDriverRequests(
        page: 1,
        limit: 50,
        status: 'pending', // Only pending requests
        sortBy: 'created_at',
        sortOrder: 'desc',
      );

      print('📦 HomeDriver: Driver requests response received');
      print('   - Response structure: ${response.keys}');

      // ✅ PERBAIKAN: Process response sesuai struktur backend yang baru
      final requestsData = response['requests'] ?? [];
      List<Map<String, dynamic>> processedRequests = [];

      for (var requestData in requestsData) {
        try {
          // Extract order information from nested structure
          final orderData = requestData['order'] ?? {};

          // Determine request type berdasarkan order data
          String requestType = _determineRequestType(orderData);

          // Add metadata untuk UI
          Map<String, dynamic> processedRequest = Map<String, dynamic>.from(requestData);
          processedRequest['request_type'] = requestType;
          processedRequest['urgency'] = DriverRequestService.getRequestUrgency(requestData);
          processedRequest['potential_earnings'] = DriverRequestService.calculatePotentialEarnings(requestData);

          processedRequests.add(processedRequest);

          print('   - Processed request ${requestData['id']}: $requestType');
        } catch (e) {
          print('⚠️ HomeDriver: Error processing request ${requestData['id']}: $e');
        }
      }

      setState(() {
        _driverRequests = processedRequests;
        _isLoadingRequests = false;
      });

      print('✅ HomeDriver: Loaded ${processedRequests.length} driver requests');

    } catch (e) {
      print('❌ HomeDriver: Error loading driver requests: $e');
      setState(() {
        _driverRequests = [];
        _isLoadingRequests = false;
      });
    }
  }

  // ✅ BARU: Load driver statistics
  Future<void> _loadDriverStats() async {
    try {
      print('📊 HomeDriver: Loading driver statistics...');

      final stats = await DriverRequestService.getDriverRequestStats();

      setState(() {
        _requestStats = stats;
      });

      print('✅ HomeDriver: Driver stats loaded: ${stats.keys}');
    } catch (e) {
      print('❌ HomeDriver: Error loading driver stats: $e');
      setState(() {
        _requestStats = {};
      });
    }
  }

  // ✅ BARU: Determine request type dari order data
  String _determineRequestType(Map<String, dynamic> orderData) {
    // Check if it's a jasa titip request based on order characteristics
    final items = orderData['items'] ?? orderData['order_items'] ?? [];
    final notes = orderData['notes'] ?? '';
    final description = orderData['description'] ?? '';

    // Simple heuristic: if no items or contains certain keywords, it's jasa titip
    if (items.isEmpty ||
        notes.toLowerCase().contains('titip') ||
        notes.toLowerCase().contains('belikan') ||
        description.toLowerCase().contains('titip') ||
        description.toLowerCase().contains('belikan')) {
      return 'jasa_titip';
    }

    return 'regular';
  }

  // ✅ PERBAIKAN: Unified periodic updates
  void _startPeriodicUpdates() {
    // Poll for new requests every 15 seconds when active
    _requestPollingTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (_driverStatus == 'active' && mounted && _driverId != null) {
        _loadDriverRequests();
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

  // ✅ PERBAIKAN: Use DriverService.updateDriverStatus()
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

      // ✅ PERBAIKAN: Use DriverService.updateDriverStatus()
      await DriverService.updateDriverStatus(
        driverId: _driverId!,
        status: newStatus,
      );

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
        _loadDriverRequests();
        _loadDriverStats();
      }

    } catch (e) {
      print('❌ HomeDriver: Error updating driver status: $e');
      setState(() {
        _isUpdatingStatus = false;
      });
      _showErrorDialog('Gagal mengubah status driver: $e');
    }
  }

  // ✅ PERBAIKAN: Accept request using DriverRequestService.acceptDriverRequest()
  Future<void> _acceptDriverRequest(Map<String, dynamic> requestData) async {
    try {
      final String requestId = requestData['id'].toString();
      final String requestType = requestData['request_type'] ?? 'regular';

      print('🔄 HomeDriver: Accepting driver request: $requestId (type: $requestType)');

      // ✅ PERBAIKAN: Use convenience method acceptDriverRequest
      await DriverRequestService.acceptDriverRequest(
        requestId: requestId,
        notes: 'Driver telah menerima permintaan dan akan segera memproses',
      );

      // Play success sound
      _playSound('audio/kring.mp3');

      // Show success dialog and navigate based on request type
      if (requestType == 'jasa_titip') {
        _showRequestAcceptedDialog(requestData, () {
          // Navigate to contact user for jasa titip
          final orderId = requestData['order']?['id']?.toString();
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
      } else {
        _showOrderAcceptedDialog(requestData, () {
          // Navigate to order detail for regular orders
          final orderId = requestData['order']?['id']?.toString();
          if (orderId != null) {
            Navigator.pushNamed(
              context,
              HistoryDriverDetailPage.route,
              arguments: orderId,
            );
          } else {
            _showErrorDialog('Order ID tidak ditemukan dalam request data');
          }
        });
      }

      // Refresh requests list
      _loadDriverRequests();

      print('✅ HomeDriver: Driver request accepted successfully');

    } catch (e) {
      print('❌ HomeDriver: Error accepting driver request: $e');
      _showErrorDialog('Gagal menerima permintaan: $e');
    }
  }

  // ✅ PERBAIKAN: Reject request using DriverRequestService.rejectDriverRequest()
  Future<void> _rejectDriverRequest(Map<String, dynamic> requestData) async {
    try {
      final String requestId = requestData['id'].toString();

      print('🔄 HomeDriver: Rejecting driver request: $requestId');

      // ✅ PERBAIKAN: Use convenience method rejectDriverRequest
      await DriverRequestService.rejectDriverRequest(
        requestId: requestId,
        reason: 'Driver tidak tersedia saat ini',
      );

      // Play rejection sound
      _playSound('audio/wrong.mp3');

      // Refresh requests list
      _loadDriverRequests();

      print('✅ HomeDriver: Driver request rejected successfully');

    } catch (e) {
      print('❌ HomeDriver: Error rejecting driver request: $e');
      _showErrorDialog('Gagal menolak permintaan: $e');
    }
  }

  // Navigate to Profile
  void _navigateToProfile() async {
    try {
      print('🔄 HomeDriver: Navigating to ProfileDriverPage...');
      await Navigator.pushNamed(context, ProfileDriverPage.route);

      // Refresh data when returning from profile
      _loadDriverRequests();
      _loadDriverStats();
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
                  'Sistem akan otomatis mengirimkan permintaan pesanan terdekat kepada Anda.',
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
            'Anda yakin ingin menonaktifkan status? Anda tidak akan menerima permintaan pesanan baru.',
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

  void _showOrderAcceptedDialog(Map<String, dynamic> requestData, VoidCallback onViewDetail) {
    final orderId = requestData['order']?['id']?.toString() ?? requestData['id'].toString();

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
                'Order #$orderId',
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

  // ✅ PERBAIKAN: Unified driver request card
  Widget _buildDriverRequestCard(Map<String, dynamic> requestData, int index) {
    final Map<String, dynamic> orderData = requestData['order'] ?? {};
    final String requestType = requestData['request_type'] ?? 'regular';
    final String urgency = requestData['urgency'] ?? 'normal';
    final double potentialEarnings = requestData['potential_earnings']?.toDouble() ?? 0.0;

    final String customerName = orderData['customer']?['name'] ?? orderData['user']?['name'] ?? 'Customer';
    final String storeName = orderData['store']?['name'] ?? 'Store';
    final double totalAmount = ((orderData['total_amount'] ?? orderData['totalAmount'] ?? orderData['total']) ?? 0).toDouble();
    final double deliveryFee = ((orderData['delivery_fee'] ?? orderData['deliveryFee']) ?? 0).toDouble();
    final String requestId = requestData['id'].toString();
    final String orderId = orderData['id']?.toString() ?? '';
    final createdAt = requestData['created_at'] ?? requestData['createdAt'] ?? DateTime.now().toIso8601String();

    // Request type specific data
    final String notes = requestData['notes'] ?? orderData['notes'] ?? orderData['description'] ?? '';
    final String location = requestData['location'] ?? orderData['delivery_address'] ?? orderData['deliveryAddress'] ?? '';

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
          // ✅ BARU: Border indicator untuk urgency
          border: urgency == 'urgent'
              ? Border.all(color: Colors.red, width: 2)
              : urgency == 'high'
              ? Border.all(color: Colors.orange, width: 1)
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with type and urgency
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: requestType == 'jasa_titip'
                          ? Colors.orange.withOpacity(0.1)
                          : GlobalStyle.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      requestType == 'jasa_titip' ? Icons.local_shipping : Icons.shopping_bag,
                      color: requestType == 'jasa_titip' ? Colors.orange : GlobalStyle.primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          requestType == 'jasa_titip' ? 'Jasa Titip' : 'Pesanan Regular',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                        Text(
                          requestType == 'jasa_titip' ? 'Request #$requestId' : 'Order #$orderId',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ✅ BARU: Urgency indicator
                  if (urgency != 'normal') ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: urgency == 'urgent' ? Colors.red : Colors.orange,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        urgency == 'urgent' ? 'URGENT' : 'HIGH',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      DriverRequestService.getRequestStatusText('pending'),
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

              // Customer & Store/Location Info
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

                        if (requestType == 'regular') ...[
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
                        ] else ...[
                          Row(
                            children: [
                              Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                'Lokasi:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          Text(
                            location.isNotEmpty ? location : 'Lokasi tidak tersedia',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                              fontFamily: GlobalStyle.fontFamily,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (requestType == 'regular') ...[
                        Text(
                          GlobalStyle.formatRupiah(totalAmount),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: GlobalStyle.primaryColor,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                      ] else ...[
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
                      Text(
                        DateFormat('dd/MM, HH:mm').format(DateTime.parse(createdAt)),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      // ✅ BARU: Potential earnings display
                      if (potentialEarnings > 0) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Est. ${GlobalStyle.formatRupiah(potentialEarnings)}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.green[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),

              // Notes for jasa titip
              if (requestType == 'jasa_titip' && notes.isNotEmpty) ...[
                const SizedBox(height: 12),
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
              ],

              const SizedBox(height: 16),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _rejectDriverRequest(requestData),
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
                      onPressed: () => _acceptDriverRequest(requestData),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: requestType == 'jasa_titip' ? Colors.orange : GlobalStyle.primaryColor,
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

  // Build empty state
  Widget _buildEmptyState() {
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
            'Tidak ada permintaan baru',
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
                ? 'Sistem akan otomatis mengirimkan permintaan terdekat'
                : 'Aktifkan status untuk menerima permintaan',
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

  // ✅ BARU: Build stats row
  Widget _buildStatsRow() {
    final int totalRequests = _requestStats['total_requests'] ?? 0;
    final int acceptedRequests = _requestStats['accepted_requests'] ?? 0;
    final double acceptanceRate = _requestStats['acceptance_rate']?.toDouble() ?? 0.0;
    final double totalEarnings = _requestStats['total_earnings']?.toDouble() ?? 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Text(
                  '$totalRequests',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: GlobalStyle.primaryColor,
                  ),
                ),
                Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  '$acceptedRequests',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                Text(
                  'Diterima',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  '${acceptanceRate.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                Text(
                  'Rate',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  totalEarnings > 0 ? GlobalStyle.formatRupiah(totalEarnings) : 'Rp 0',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                ),
                Text(
                  'Earnings',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
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

            // ✅ BARU: Stats Row
            _buildStatsRow(),

            // Request List
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadDriverRequests,
                color: GlobalStyle.primaryColor,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: _isLoadingRequests
                      ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: GlobalStyle.primaryColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Memuat permintaan...",
                          style: TextStyle(
                            color: GlobalStyle.primaryColor,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                      ],
                    ),
                  )
                      : _driverRequests.isEmpty
                      ? _buildEmptyState()
                      : Column(
                    children: [
                      // ✅ BARU: Header dengan jumlah requests
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text(
                          'Permintaan Baru (${_driverRequests.length})',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: GlobalStyle.fontColor,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _driverRequests.length,
                          itemBuilder: (context, index) =>
                              _buildDriverRequestCard(_driverRequests[index], index),
                        ),
                      ),
                    ],
                  ),
                ),
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