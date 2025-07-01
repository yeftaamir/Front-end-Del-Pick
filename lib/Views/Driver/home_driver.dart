// lib/Views/Driver/home_driver.dart - Updated dengan Sistem Notifikasi Badge
import 'package:del_pick/Views/Driver/driver_request_detail.dart';
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

// ✅ TAMBAHAN: Import notification components yang baru
import 'package:del_pick/Services/driver_enhanced_notification_service.dart';
import 'package:del_pick/Views/Component/driver_notification_badge_card.dart';

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

  // Tab Controller
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

  // Driver requests and stats
  List<Map<String, dynamic>> _driverRequests = [];
  Map<String, dynamic> _requestStats = {
    'total_requests': 0,
    'accepted_requests': 0,
    'pending_requests': 0,
    'acceptance_rate': 0.0,
    'total_earnings': 0.0,
  };

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
  Timer? _fastPollingTimer; // For active status

  // Debouncing untuk prevent multiple clicks
  final Map<String, bool> _processingRequests = {};

  // Network state tracking
  bool _isOnline = true;

  // ✅ TAMBAHAN: Notification Badge State
  int _notificationBadgeCount = 0;
  bool _notificationPermissionGranted = false;
  List<Map<String, dynamic>> _notificationQueue = [];
  bool _showNotificationBadge = false;
  Map<String, dynamic>? _currentNotificationRequest;
  Timer? _notificationTimer;

  // ✅ TAMBAHAN: Badge Animation Controller
  late AnimationController _badgeController;
  late Animation<double> _badgeAnimation;

  /// Parse double from various formats safely
  static double _parseDouble(dynamic value) {
    try {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        String cleanValue = value
            .replaceAll('Rp', '')
            .replaceAll(' ', '')
            .replaceAll(',', '')
            .trim();
        if (cleanValue.isEmpty) return 0.0;
        return double.tryParse(cleanValue) ?? 0.0;
      }
      return 0.0;
    } catch (e) {
      print('Error parsing double value "$value": $e');
      return 0.0;
    }
  }

  /// Parse int safely
  static int _parseInt(dynamic value) {
    try {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    } catch (e) {
      print('Error parsing int value "$value": $e');
      return 0;
    }
  }

  // initState dengan status sync dan notifikasi
  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 1, vsync: this);
    _initializeAnimations();

    // ✅ TAMBAHAN: Initialize enhanced notifications
    _initializeEnhancedNotifications();

    _initializeNotifications();
    _requestPermissions();
    _initializeAuthentication();

    // Start status sync immediately
    Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted && _driverId != null) {
        _syncDriverStatusWithBackend();
      }
    });
  }

  // ✅ TAMBAHAN: Initialize enhanced notification system
  Future<void> _initializeEnhancedNotifications() async {
    try {
      print('🔔 HomeDriver: Initializing enhanced notification system...');

      // Initialize enhanced notification service
      await DriverEnhancedNotificationService.initialize(
        onTap: (requestId) {
          print('🔔 Driver notification tapped for request: $requestId');

          // Reset badge saat notification di-tap
          DriverEnhancedNotificationService.resetBadgeCount();

          // Update local badge count
          setState(() {
            _notificationBadgeCount = DriverEnhancedNotificationService.getBadgeCount();
          });

          // Navigate ke request detail jika requestId valid
          if (requestId.isNotEmpty && requestId != 'group_driver_requests') {
            _viewRequestDetail(requestId);
          }

          // Clear notification badge
          setState(() {
            _showNotificationBadge = false;
            _currentNotificationRequest = null;
          });
        },
      );

      // Create notification channels
      await DriverEnhancedNotificationService.createNotificationChannels();

      // ✅ TAMBAHAN: Initialize DriverNotificationService
      await DriverNotificationService.initialize();

      // Request notification permissions
      _notificationPermissionGranted = await DriverNotificationService.requestNotificationPermissions(context);

      if (_notificationPermissionGranted) {
        print('✅ HomeDriver: Notification permissions granted');
      } else {
        print('⚠️ HomeDriver: Notification permissions denied');
      }

      // Update badge count from service
      setState(() {
        _notificationBadgeCount = DriverEnhancedNotificationService.getBadgeCount();
      });

      print('✅ HomeDriver: Enhanced notification system initialized successfully');
    } catch (e) {
      print('❌ HomeDriver: Error initializing enhanced notifications: $e');
    }
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

    // ✅ TAMBAHAN: Badge animation controller
    _badgeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _badgeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _badgeController,
      curve: Curves.elasticOut,
    ));

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

    const InitializationSettings initializationSettings =
    InitializationSettings(
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

  //Enhanced authentication with better error handling
  Future<void> _initializeAuthentication() async {
    setState(() {
      _isInitialLoading = true;
      _errorMessage = null;
    });

    try {
      print('🔍 HomeDriver: Initializing authentication...');

      // Check if user has driver role
      final hasDriverAccess = await AuthService.hasRole('driver');
      if (!hasDriverAccess) {
        throw Exception('Access denied: You are not authenticated as a driver');
      }

      // Get user and driver data
      final userData = await AuthService.getUserData();
      final roleSpecificData = await AuthService.getRoleSpecificData();

      if (userData == null) {
        throw Exception('Unable to retrieve user data. Please login again.');
      }

      _userData = userData;
      _driverData = roleSpecificData;

      // Extract driver information with fallbacks
      if (roleSpecificData != null && roleSpecificData['driver'] != null) {
        _driverId = roleSpecificData['driver']['id']?.toString();
        _driverStatus = roleSpecificData['driver']['status'] ?? 'inactive';
      } else if (roleSpecificData != null && roleSpecificData['user'] != null) {
        _driverId = roleSpecificData['user']['id']?.toString();
      } else if (userData['id'] != null) {
        _driverId = userData['id']?.toString();
      }

      if (_driverId == null || _driverId!.isEmpty) {
        throw Exception('Driver ID not found. Please contact support.');
      }

      print('✅ HomeDriver: Authentication successful');
      print('   - Driver ID: $_driverId');
      print('   - Status: $_driverStatus');

      // Load initial data
      await _loadInitialData();
    } catch (e) {
      print('❌ HomeDriver: Authentication error: $e');
      setState(() {
        _isInitialLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  //Load initial data with better error handling
  Future<void> _loadInitialData() async {
    try {
      // Load data in parallel with individual error handling
      final results = await Future.wait([
        _loadDriverRequests().catchError((e) {
          print('⚠️ Failed to load driver requests: $e');
          return null;
        }),
        _loadDriverStats().catchError((e) {
          print('⚠️ Failed to load driver stats: $e');
          return null;
        }),
      ]);

      setState(() {
        _isInitialLoading = false;
      });
    } catch (e) {
      print('❌ HomeDriver: Error loading initial data: $e');
      setState(() {
        _isInitialLoading = false;
        _errorMessage = 'Failed to load some data. You can still use the app.';
      });
    }
  }

  //method untuk validasi status request
  bool _isRequestStillValid(Map<String, dynamic> requestData) {
    final String status = requestData['status'] ?? 'pending';
    final String requestId = requestData['id'].toString();

    // Cek apakah status masih pending dan tidak sedang diproses
    return status == 'pending' && _processingRequests[requestId] != true;
  }

  // Load driver requests with improved error handling dan new request detection
  Future<void> _loadDriverRequests() async {
    if (!mounted || _driverId == null || _isLoadingRequests) {
      return;
    }

    setState(() {
      _isLoadingRequests = true;
    });

    try {
      print('🔄 Loading driver requests...');

      final response = await DriverRequestService.getDriverRequests(
        page: 1,
        limit: 50,
        // ✅ HAPUS filter status, ambil semua untuk filter di frontend
        sortBy: 'created_at',
        sortOrder: 'desc',
      );

      final requestsData = response['requests'] ?? [];
      List<Map<String, dynamic>> processedRequests = [];

      // ✅ UBAH: Filter berdasarkan kondisi order status dan delivery status
      for (var requestData in requestsData) {
        try {
          final String id = requestData['id'].toString();
          final String requestStatus = requestData['status'] ?? 'pending';
          final order = requestData['order'];

          if (order == null) continue;

          final String orderStatus = order['order_status'] ?? '';
          final String deliveryStatus = order['delivery_status'] ?? '';

          // ✅ TAMBAH: Logic filter sesuai requirement
          bool shouldShow = false;

          // Show jika request status pending dan kondisi order memenuhi syarat
          if (requestStatus == 'pending') {
            // Case 1: order_status pending dan delivery_status pending
            if (orderStatus == 'pending' && deliveryStatus == 'pending') {
              shouldShow = true;
            }
            // Case 2: order_status preparing dan delivery_status pending
            else if (orderStatus == 'preparing' &&
                deliveryStatus == 'pending') {
              shouldShow = true;
            }
          }

          // Skip jika tidak memenuhi kondisi atau sedang diproses
          if (!shouldShow || _processingRequests[id] == true) {
            continue;
          }

          // Process request data
          Map<String, dynamic> processedRequest =
          Map<String, dynamic>.from(requestData);
          processedRequest['urgency'] =
              DriverRequestService.getRequestUrgency(requestData);
          processedRequest['potential_earnings'] =
              _calculateSafePotentialEarnings(requestData);

          processedRequests.add(processedRequest);
        } catch (e) {
          print('⚠️ Error processing request ${requestData['id']}: $e');
        }
      }

      // ✅ TAMBAHAN: Detect new requests dan trigger notification
      final existingIds = _driverRequests
          .map((request) => request['id']?.toString() ?? '')
          .toSet();

      List<Map<String, dynamic>> newRequests = [];

      for (var request in processedRequests) {
        final requestId = request['id']?.toString();
        if (requestId != null && !existingIds.contains(requestId)) {
          print('🎉 HomeDriver: New driver request detected: $requestId');
          newRequests.add(request);
        }
      }

      // ✅ TAMBAHAN: Show enhanced notifications untuk new requests
      if (newRequests.isNotEmpty && _driverRequests.isNotEmpty) {
        await _handleNewRequestNotifications(newRequests);
      }

      if (mounted) {
        setState(() {
          _driverRequests = processedRequests;
          _isLoadingRequests = false;
        });
        print('✅ Loaded ${processedRequests.length} valid driver requests');
      }
    } catch (e) {
      print('❌ Error loading driver requests: $e');
      if (mounted) {
        setState(() {
          _isLoadingRequests = false;
        });
      }
    }
  }

  // ✅ TAMBAHAN: Handle new request notifications
  Future<void> _handleNewRequestNotifications(List<Map<String, dynamic>> newRequests) async {
    try {
      if (newRequests.isEmpty || !_notificationPermissionGranted) return;

      print('🔔 HomeDriver: Handling ${newRequests.length} new request notifications');

      // Show enhanced notifications
      if (newRequests.length == 1) {
        // Single request notification
        await DriverEnhancedNotificationService.showNewDriverRequestNotification(
          requestData: newRequests.first,
          playSound: true,
          updateBadge: true,
        );

        // ✅ TAMBAHAN: Show notification menggunakan DriverNotificationService
        await DriverNotificationService.showDriverRequestNotification(
          requestData: newRequests.first,
          context: context,
        );
      } else {
        // Multiple requests notification
        await DriverEnhancedNotificationService.showGroupedDriverRequestNotification(
          requests: newRequests,
          playSound: true,
        );

        // Show multiple notifications using DriverNotificationService
        for (var request in newRequests) {
          await DriverNotificationService.showDriverRequestNotification(
            requestData: request,
            context: context,
          );
        }
      }

      // Add to notification queue
      setState(() {
        _notificationQueue.addAll(newRequests);
        _notificationBadgeCount = DriverEnhancedNotificationService.getBadgeCount();
      });

      // Show in-app notification badge untuk first request
      if (newRequests.isNotEmpty && !_showNotificationBadge) {
        _showInAppNotificationBadge(newRequests.first);
      }

      print('✅ HomeDriver: New request notifications handled');
    } catch (e) {
      print('❌ HomeDriver: Error handling new request notifications: $e');
    }
  }

  // ✅ TAMBAHAN: Show in-app notification badge
  void _showInAppNotificationBadge(Map<String, dynamic> requestData) {
    setState(() {
      _currentNotificationRequest = requestData;
      _showNotificationBadge = true;
    });

    // Start badge animation
    _badgeController.forward();

    // Auto hide after 8 seconds if not manually dismissed
    _notificationTimer?.cancel();
    _notificationTimer = Timer(const Duration(seconds: 8), () {
      if (mounted && _showNotificationBadge) {
        _hideInAppNotificationBadge();
      }
    });

    print('🔔 HomeDriver: In-app notification badge shown for request ${requestData['id']}');
  }

  // ✅ TAMBAHAN: Hide in-app notification badge
  void _hideInAppNotificationBadge() {
    setState(() {
      _showNotificationBadge = false;
      _currentNotificationRequest = null;
    });

    _badgeController.reverse();
    _notificationTimer?.cancel();

    // Show next notification in queue if any
    if (_notificationQueue.isNotEmpty) {
      _notificationQueue.removeAt(0);
      if (_notificationQueue.isNotEmpty) {
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            _showInAppNotificationBadge(_notificationQueue.first);
          }
        });
      }
    }

    print('🔔 HomeDriver: In-app notification badge hidden');
  }

  // ✅ TAMBAHAN: View request detail method
  Future<void> _viewRequestDetail(String requestId) async {
    try {
      print('👁️ HomeDriver: Viewing request detail: $requestId');

      // Find request data
      final requestData = _driverRequests
          .firstWhere((request) => request['id']?.toString() == requestId);

      if (requestData != null) {
        await Navigator.pushNamed(
          context,
          DriverRequestDetailPage.route,
          arguments: {
            'requestId': requestId,
            'requestData': requestData,
          },
        ).then((_) {
          // Refresh status driver saat kembali
          _syncDriverStatusWithBackend();
        });

        print('✅ HomeDriver: Navigated to request detail');
      } else {
        throw Exception('Request data not found');
      }
    } catch (e) {
      print('❌ HomeDriver: Error viewing request detail: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat detail permintaan: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  // ✅ TAMBAHAN: Show notification history
  void _showNotificationHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DriverNotificationHistoryWidget(),
    );
  }

  // ✅ TAMBAHAN: Clear notifications
  void _clearNotifications() {
    setState(() {
      _notificationBadgeCount = 0;
    });
    DriverEnhancedNotificationService.clearAllNotifications();
    DriverNotificationService.clearBadgeCount();
  }

  /// ✅ Load driver stats menggunakan perhitungan frontend
  Future<void> _loadDriverStats() async {
    try {
      print(
          '📊 HomeDriver: Loading driver statistics (frontend calculation)...');

      // Gunakan method baru yang menghitung dari multiple endpoints
      final stats = await DriverService.getComprehensiveDriverStats();

      setState(() {
        _requestStats = {
          'total_requests': _parseInt(stats['total_requests']),
          'accepted_requests': _parseInt(stats['accepted_requests']),
          'cancelled_by_driver': _parseInt(stats['cancelled_by_driver']),
          'pending_requests': _parseInt(stats['pending_requests']),
          'acceptance_rate': _parseDouble(stats['acceptance_rate']),
          'total_earnings': _parseDouble(stats['total_earnings']),
          'today_earnings': _parseDouble(stats['today_earnings']),
          'completed_today': _parseInt(stats['completed_today']),
        };
      });

      print('✅ HomeDriver: Driver stats calculated successfully');
      print('   - Total Requests: ${_requestStats['total_requests']}');
      print('   - Delivered Orders: ${_requestStats['accepted_requests']}');
      print('   - Total Earnings: Rp ${_requestStats['total_earnings']}');
      print('   - Acceptance Rate: ${_requestStats['acceptance_rate']}%');

      // Debug info
      if (stats['raw_data'] != null) {
        final rawData = stats['raw_data'];
        print('📊 Raw data summary:');
        print('   - Total requests found: ${rawData['total_requests_found']}');
        print('   - Total orders found: ${rawData['total_orders_found']}');
        print(
            '   - Delivered orders found: ${rawData['delivered_orders_found']}');
      }
    } catch (e) {
      print('❌ HomeDriver: Error loading driver stats: $e');

      // ✅ Use default stats instead of failing
      setState(() {
        _requestStats = {
          'total_requests': 0,
          'accepted_requests': 0,
          'cancelled_by_driver': 0,
          'pending_requests': 0,
          'acceptance_rate': 0.0,
          'total_earnings': 0.0,
          'today_earnings': 0.0,
          'completed_today': 0,
        };
      });

      print('ℹ️ Using default stats due to calculation error');
    }
  }

  double _calculateSafePotentialEarnings(Map<String, dynamic> request) {
    try {
      final order = request['order'];
      if (order == null) return 0.0;

      final deliveryFee = _parseDouble(order['delivery_fee']);
      final totalAmount = _parseDouble(
          order['total_amount'] ?? order['totalAmount'] ?? order['total']);

      // Driver gets delivery fee + small percentage of order total
      final baseEarning = deliveryFee;
      final commissionRate = 0.05; // 5% dari total order
      final commission = totalAmount * commissionRate;

      return baseEarning + commission;
    } catch (e) {
      print('Error calculating potential earnings: $e');
      return 0.0;
    }
  }

  // Polling berdasarkan status driver
  void _startPeriodicUpdates() {
    _requestPollingTimer?.cancel(); // Cancel existing timer

    _requestPollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted && _driverId != null) {
        if (_driverStatus == 'active') {
          // Load requests hanya saat active
          _loadDriverRequests();
        }

        // ✅ TAMBAH: Selalu sync status dengan backend
        _syncDriverStatusWithBackend();
      }
    });
  }

  // Fast polling dengan status check
  void _startFastPolling() {
    _fastPollingTimer?.cancel(); // Cancel existing timer

    _fastPollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted && _driverId != null) {
        // ✅ TAMBAH: Sync status lebih sering untuk real-time update
        _syncDriverStatusWithBackend();

        // Load requests jika active dan ada processing requests
        if (_driverStatus == 'active' && _processingRequests.isNotEmpty) {
          _loadDriverRequests();
        }
      }
    });
  }

  /// Prevent toggle saat driver busy
  Future<void> _toggleDriverStatus() async {
    if (_isUpdatingStatus || _driverId == null) return;

    // ✅ TAMBAH: Prevent deactivate saat busy
    if (_driverStatus == 'busy') {
      _showErrorDialog(
          'Cannot change status while processing an order.\nPlease complete your current delivery first.');
      return;
    }

    if (_driverStatus == 'active') {
      _showDeactivateConfirmationDialog();
    } else {
      await _setDriverStatus('active');
    }
  }

  //Set driver status with better error handling
  Future<void> _setDriverStatus(String newStatus) async {
    if (_driverId == null) {
      _showErrorDialog('Driver ID not found. Please login again.');
      return;
    }

    setState(() {
      _isUpdatingStatus = true;
    });

    try {
      print('🔄 HomeDriver: Updating driver status to: $newStatus');

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
      _showErrorDialog('Failed to update driver status. Please try again.');
    }
  }

  ///Accept request dengan optimistic update + auto refresh dengan navigation ke detail & update status busy
  Future<void> _acceptDriverRequest(Map<String, dynamic> requestData) async {
    final String requestId = requestData['id'].toString();

    if (_processingRequests[requestId] == true) {
      print('⚠️ Request $requestId already being processed');
      return;
    }

    try {
      setState(() {
        _processingRequests[requestId] = true;
        _driverRequests.removeWhere((r) => r['id'].toString() == requestId);
      });

      print('🔄 Accepting driver request: $requestId');

      await DriverRequestService.respondToDriverRequest(
        requestId: requestId,
        action: 'accept',
        notes: 'Driver has accepted the request.',
      );

      // ✅ TAMBAH: Update driver status menjadi busy setelah accept
      setState(() {
        _driverStatus = 'busy';
      });

      _playSound('audio/kring.mp3');

      // ✅ TAMBAH: Stop polling karena driver sudah busy
      _requestPollingTimer?.cancel();
      _fastPollingTimer?.cancel();

      // ✅ TAMBAH: Sync status dengan backend untuk konfirmasi
      await _syncDriverStatusWithBackend();

      // ✅ TAMBAHAN: Show processed notification
      await DriverEnhancedNotificationService.showRequestProcessedNotification(
        requestId: requestId,
        action: 'accepted',
        playSound: false,
      );

      _showOrderAcceptedDialog(requestData, () {
        Navigator.pushNamed(
          context,
          DriverRequestDetailPage.route,
          arguments: {
            'requestId': requestId,
            'requestData': requestData,
          },
        ).then((_) {
          // ✅ TAMBAH: Refresh status driver saat kembali
          _syncDriverStatusWithBackend();
        });
      });

      print('✅ Driver request accepted successfully, status changed to busy');
    } catch (e) {
      print('❌ Error accepting driver request: $e');

      // ✅ TAMBAH: Revert status jika gagal
      setState(() {
        _driverStatus = 'active';
      });

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _loadDriverRequests();
        }
      });

      _showErrorDialog('Failed to accept request. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _processingRequests.remove(requestId);
        });
      }
    }
  }

  /// Reject request with improved error handling
  Future<void> _rejectDriverRequest(Map<String, dynamic> requestData) async {
    final String requestId = requestData['id'].toString();

    // ✅ Prevent double clicks
    if (_processingRequests[requestId] == true) {
      return;
    }

    try {
      setState(() {
        _processingRequests[requestId] = true;
        requestData['_isProcessing'] = true;
      });

      print('🔄 Rejecting driver request: $requestId');

      // ✅ OPTIMISTIC UPDATE: Remove from list immediately
      setState(() {
        _driverRequests.removeWhere((r) => r['id'].toString() == requestId);
      });

      await DriverRequestService.respondToDriverRequest(
        requestId: requestId,
        action: 'reject',
        notes: 'Driver is currently unavailable.',
      );

      _playSound('audio/wrong.mp3');

      // ✅ TAMBAHAN: Show processed notification
      await DriverEnhancedNotificationService.showRequestProcessedNotification(
        requestId: requestId,
        action: 'rejected',
        playSound: false,
      );

      // ✅ IMMEDIATE REFRESH: Refresh after 1 second
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          print('🔄 Post-reject refresh...');
          _loadDriverRequests();
        }
      });

      print('✅ Driver request rejected successfully');
    } catch (e) {
      print('❌ Error rejecting driver request: $e');

      // ✅ Auto refresh on error
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          _loadDriverRequests();
        }
      });

      _showErrorDialog('Failed to reject request. List refreshed.');
    } finally {
      if (mounted) {
        setState(() {
          _processingRequests.remove(requestId);
        });
      }
    }
  }

  // Method untuk sync status dengan backend
// ✅ KODE YANG TEPAT - Versi Final
  Future<void> _syncDriverStatusWithBackend() async {
    if (_driverId == null) return;

    try {
      print('🔄 Syncing driver status with backend...');

      // Call backend endpoint untuk get driver data terbaru
      final driverData = await DriverService.getDriverById(_driverId!);

      // ✅ PERBAIKAN: Check driverData.isNotEmpty karena service return Map<String, dynamic>
      if (driverData.isNotEmpty && driverData['status'] != null) {
        final String backendStatus = driverData['status'];

        // Update local status jika berbeda
        if (_driverStatus != backendStatus) {
          setState(() {
            _driverStatus = backendStatus;
          });

          print('✅ Driver status synced: $_driverStatus → $backendStatus');

          // ✅ Handle perubahan status
          if (backendStatus == 'active') {
            // Driver kembali active, restart polling
            _startPeriodicUpdates();
            _startFastPolling();
            _loadDriverRequests();
            print('🔄 Driver active again, restarting polling...');
          } else if (backendStatus == 'busy') {
            // Driver busy, stop request polling
            _requestPollingTimer?.cancel();
            print('⏸️ Driver busy, stopping request polling...');
          }
        }
      }
    } catch (e) {
      print('❌ Error syncing driver status: $e');
    }
  }

  /// Navigate to Profile
  void _navigateToProfile() async {
    try {
      await Navigator.pushNamed(context, ProfileDriverPage.route);
      _loadDriverRequests();
      _loadDriverStats();
    } catch (e) {
      print('❌ HomeDriver: Error navigating to profile: $e');
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
          Navigator.pushNamed(context, HistoryDriverDetailPage.route,
              arguments: id);
        } else if (type == 'request') {
          Navigator.pushNamed(context, ContactUserPage.route,
              arguments: {'orderId': id});
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

  // Dialog methods (tidak diubah - tetap sama seperti sebelumnya)
  void _showDriverActiveDialog() async {
    await _playSound('audio/found.wav');

    if (mounted) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                  'You are now Active!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'System will automatically send you nearby order requests.',
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
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    minimumSize: const Size(double.infinity, 45),
                  ),
                  child: Text(
                    'Got it',
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
            'Confirmation',
            style: TextStyle(
              fontFamily: GlobalStyle.fontFamily,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to deactivate your status? You will not receive new order requests.',
            style: TextStyle(
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
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
                'Yes, Deactivate',
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

// Dialog dengan info order yang lebih detail
  void _showOrderAcceptedDialog(
      Map<String, dynamic> requestData, VoidCallback onContactCustomer) {
    final order = requestData['order'] ?? {};
    final orderId = order['id']?.toString() ?? requestData['id'].toString();
    final customerName = order['customer']?['name'] ?? 'Customer';
    final storeName = order['store']?['name'] ?? 'Store';
    final totalAmount = _parseDouble(order['total_amount']);
    final deliveryFee = _parseDouble(order['delivery_fee']);

    showDialog(
      context: context,
      barrierDismissible: false, // ✅ TAMBAH: Prevent dismiss tanpa action
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                'Request Accepted!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: GlobalStyle.fontFamily,
                ),
              ),
              const SizedBox(height: 16),

              // ✅ TAMBAH: Info order detail
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Order #$orderId',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                        Text(
                          GlobalStyle.formatRupiah(totalAmount),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: GlobalStyle.primaryColor,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.person, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          'Customer: $customerName',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.store, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          'Store: $storeName',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.local_shipping,
                            size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          'Delivery Fee: ${GlobalStyle.formatRupiah(deliveryFee)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
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
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onContactCustomer(); // ✅ UBAH: Navigate ke detail page
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlobalStyle.primaryColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  minimumSize: const Size(double.infinity, 45),
                ),
                child: Text(
                  'View Request Details', // ✅ UBAH: Text button
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

// ✅ FIXED: Method _calculateDriverStats dengan akses Map yang benar
  Map<String, dynamic> _calculateDriverStats() {
    try {
      // Filter completed orders dari _driverRequests
      final completedOrders = _driverRequests.where((request) {
        final orderData = request['order'];
        if (orderData == null) return false;

        final String orderStatus = orderData['order_status'] ?? '';
        final String deliveryStatus = orderData['delivery_status'] ?? '';

        return orderStatus == 'delivered' && deliveryStatus == 'delivered';
      }).toList();

      // Calculate total earnings dari delivery fee
      final totalEarnings = completedOrders.fold(0.0, (sum, request) {
        final orderData = request['order'];
        if (orderData == null) return sum;

        final double deliveryFee = _parseDouble(orderData['delivery_fee']);
        return sum + deliveryFee; // Driver mendapat 100% delivery fee
      });

      // Calculate total delivery fee
      final totalDeliveryFee = completedOrders.fold(0.0, (sum, request) {
        final orderData = request['order'];
        if (orderData == null) return sum;

        final double deliveryFee = _parseDouble(orderData['delivery_fee']);
        return sum + deliveryFee;
      });

      final totalOrders = _driverRequests.length;
      final completedCount = completedOrders.length;

      return {
        'total_orders': totalOrders,
        'completed_orders': completedCount,
        'total_earnings': totalEarnings,
        'total_delivery_fee': totalDeliveryFee,
        'completion_rate':
        totalOrders > 0 ? (completedCount / totalOrders) : 0.0,
        'average_earning_per_order':
        completedCount > 0 ? (totalEarnings / completedCount) : 0.0,
      };
    } catch (e) {
      print('❌ Error calculating driver stats: $e');

      // Return default stats on error
      return {
        'total_orders': 0,
        'completed_orders': 0,
        'total_earnings': 0.0,
        'total_delivery_fee': 0.0,
        'completion_rate': 0.0,
        'average_earning_per_order': 0.0,
      };
    }
  }

  @override
  void dispose() {
    print('🗑️ HomeDriver: Disposing widget...');

    _tabController.dispose();
    _statusController.dispose();
    for (var controller in _cardControllers) {
      controller.dispose();
    }

    // ✅ TAMBAHAN: Dispose badge controller
    _badgeController.dispose();

    _audioPlayer.dispose();
    _requestPollingTimer?.cancel();
    _fastPollingTimer?.cancel();

    // ✅ TAMBAHAN: Cancel notification timer
    _notificationTimer?.cancel();

    // ✅ TAMBAHAN: Dispose enhanced notification service
    DriverEnhancedNotificationService.dispose();

    // ✅ TAMBAHAN: Dispose driver notification service
    DriverNotificationService.dispose();

    print('✅ HomeDriver: Widget disposed successfully');
    super.dispose();
  }

  /// Helper methods for status
  //Status color untuk busy state
  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'busy':
        return Colors.orange; // ✅ TAMBAH: Orange untuk busy
      case 'inactive':
      default:
        return Colors.red;
    }
  }

  //Status label untuk busy state
  String _getStatusLabel(String status) {
    switch (status) {
      case 'active':
        return 'Active - Ready for Orders';
      case 'busy':
        return 'Busy - Processing Order'; // ✅ TAMBAH: Label untuk busy
      case 'inactive':
      default:
        return 'Inactive';
    }
  }

// ✅ FIXED: _buildDriverStatsCard menggunakan _requestStats yang sudah di-load
  Widget _buildDriverStatsCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            GlobalStyle.primaryColor,
            GlobalStyle.primaryColor.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: GlobalStyle.primaryColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Statistik Driver',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'Total Order',
                '${_parseInt(_requestStats['total_requests'])}',
                Icons.assignment,
              ),
              _buildStatItem(
                'Delivered',
                '${_parseInt(_requestStats['accepted_requests'])}',
                Icons.check_circle,
              ),
              _buildStatItem(
                'Penghasilan',
                GlobalStyle.formatRupiah(
                    _parseDouble(_requestStats['total_earnings'])),
                Icons.account_balance_wallet,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'Hari Ini',
                GlobalStyle.formatRupiah(
                    _parseDouble(_requestStats['today_earnings'])),
                Icons.today,
              ),
              _buildStatItem(
                'Rate',
                '${_parseDouble(_requestStats['acceptance_rate']).toStringAsFixed(1)}%',
                Icons.trending_up,
              ),
              _buildStatItem(
                'Selesai',
                '${_parseInt(_requestStats['completed_today'])}',
                Icons.done_all,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  /// ✅ Driver request card with safe parsing & dengan status indicators lengkap
  Widget _buildDriverRequestCard(Map<String, dynamic> requestData, int index) {
    final Map<String, dynamic> orderData = requestData['order'] ?? {};
    final String orderStatus = orderData['order_status'] ?? '';
    final String deliveryStatus = orderData['delivery_status'] ?? '';
    final String urgency = requestData['urgency'] ?? 'normal';
    final double potentialEarnings =
    _parseDouble(requestData['potential_earnings']);

    // ✅ TAMBAHAN: Check processing state
    final bool isProcessing = requestData['_isProcessing'] ?? false;
    final String requestId = requestData['id'].toString();

    final String customerName = orderData['customer']?['name'] ??
        orderData['user']?['name'] ??
        'Customer';
    final String storeName = orderData['store']?['name'] ?? 'Store';
    final double totalAmount = _parseDouble(orderData['total_amount'] ??
        orderData['totalAmount'] ??
        orderData['total']);
    final double deliveryFee =
    _parseDouble(orderData['delivery_fee'] ?? orderData['deliveryFee']);

    final String orderId = orderData['id']?.toString() ?? '';
    final createdAt = requestData['created_at'] ??
        requestData['createdAt'] ??
        DateTime.now().toIso8601String();

    final String notes = requestData['notes'] ??
        orderData['notes'] ??
        orderData['description'] ??
        '';

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
          // ✅ TAMBAH: Border berdasarkan status
          border: isProcessing
              ? Border.all(color: Colors.blue, width: 2)
              : orderStatus == 'preparing'
              ? Border.all(color: Colors.orange, width: 2)
              : urgency == 'urgent'
              ? Border.all(color: Colors.red, width: 2)
              : Border.all(color: Colors.blue, width: 1),
        ),
        child: Stack(
          children: [
            // ✅ TAMBAHAN: Processing overlay
            if (isProcessing)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 30,
                            height: 30,
                            child: CircularProgressIndicator(
                              color: Colors.blue,
                              strokeWidth: 3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Processing Request...',
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              fontFamily: GlobalStyle.fontFamily,
                            ),
                          ),
                          Text(
                            'Please wait',
                            style: TextStyle(
                              color: Colors.blue[600],
                              fontSize: 12,
                              fontFamily: GlobalStyle.fontFamily,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // ✅ TAMBAHAN: Dimmed content saat processing
            Opacity(
              opacity: isProcessing ? 0.5 : 1.0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ✅ TAMBAH: Status indicators
                    Row(
                      children: [
                        // Order Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: orderStatus == 'preparing'
                                ? Colors.orange
                                : Colors.blue,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            orderStatus == 'preparing'
                                ? 'Preparing'
                                : 'Pending',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Delivery Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey[600],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Delivery: ${deliveryStatus.toUpperCase()}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        const Spacer(),

                        // Urgency Badge
                        if (urgency != 'normal' && !isProcessing) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: urgency == 'urgent'
                                  ? Colors.red
                                  : Colors.orange,
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

                        // Processing/Pending Status
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isProcessing ? Colors.orange : Colors.green,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isProcessing ? 'Processing' : 'Available',
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

                    // Header with order info
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: GlobalStyle.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.delivery_dining,
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
                                'Delivery Request',
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
                              // Customer Info
                              Row(
                                children: [
                                  Icon(Icons.person,
                                      size: 16, color: Colors.grey[600]),
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

                              // Store Info
                              Row(
                                children: [
                                  Icon(Icons.store,
                                      size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Store:',
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

                        // Price & Time Info
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
                              DateFormat('dd/MM, HH:mm')
                                  .format(DateTime.parse(createdAt)),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            if (potentialEarnings > 0) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
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

                    // Notes section (jika ada)
                    if (notes.isNotEmpty) ...[
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
                              'Order Notes:',
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

                    // ✅ UBAH: Action Buttons dengan processing state
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isProcessing
                                ? null
                                : () => _rejectDriverRequest(requestData),
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                              isProcessing ? Colors.grey : Colors.red,
                              side: BorderSide(
                                color: isProcessing ? Colors.grey : Colors.red,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (isProcessing) ...[
                                  SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Text(
                                  isProcessing ? 'Processing...' : 'Reject',
                                  style: TextStyle(
                                    color:
                                    isProcessing ? Colors.grey : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isProcessing
                                ? null
                                : () => _acceptDriverRequest(requestData),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isProcessing
                                  ? Colors.grey
                                  : GlobalStyle.primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (isProcessing) ...[
                                  SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Text(
                                  isProcessing ? 'Processing...' : 'Accept',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build empty state
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
            'No new requests',
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
                ? 'System will automatically send you nearby requests'
                : 'Activate your status to receive requests',
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

  // ✅ Build stats row with safe parsing
  Widget _buildStatsRow() {
    final int totalRequests = _parseInt(_requestStats['total_requests']);
    final int acceptedRequests = _parseInt(_requestStats['accepted_requests']);
    final double acceptanceRate =
    _parseDouble(_requestStats['acceptance_rate']);
    final double totalEarnings = _parseDouble(_requestStats['total_earnings']);

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
                  'Accepted',
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
                  totalEarnings > 0
                      ? GlobalStyle.formatRupiah(totalEarnings)
                      : 'Rp 0',
                  style: TextStyle(
                    fontSize: 12,
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

  // ✅ TAMBAHAN: Enhanced header dengan notification badge
  Widget _buildEnhancedHeader() {
    return Container(
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
          // ✅ PERBAIKI: Header dengan status info dan notification badge
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
                    DateFormat('EEEE, dd MMMM yyyy')
                        .format(DateTime.now()),
                    style: TextStyle(
                      color: GlobalStyle.fontColor,
                      fontSize: 14,
                      fontFamily: GlobalStyle.fontFamily,
                    ),
                  ),
                  if (_driverId != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Driver ID: $_driverId',
                      style: TextStyle(
                        color: GlobalStyle.fontColor.withOpacity(0.7),
                        fontSize: 12,
                        fontFamily: GlobalStyle.fontFamily,
                      ),
                    ),
                  ],
                  // ✅ TAMBAH: Status info untuk busy
                  if (_driverStatus == 'busy') ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.work,
                            size: 14,
                            color: Colors.orange[800],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Currently processing an order',
                            style: TextStyle(
                              color: Colors.orange[800],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              fontFamily: GlobalStyle.fontFamily,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),

              // ✅ TAMBAHAN: Right side dengan notification badge dan profile
              Row(
                children: [
                  // Notification badge button
                  DriverNotificationBadgeWidget(
                    count: _notificationBadgeCount,
                    badgeColor: Colors.red,
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: GestureDetector(
                        onTap: _showNotificationHistory,
                        child: Icon(
                          Icons.notifications,
                          color: Colors.blue,
                          size: 20,
                        ),
                      ),
                    ),
                  ),

                  // Profile button
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
                        color: _getStatusColor(_driverStatus)
                            .withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _isUpdatingStatus ||
                        _driverStatus == 'busy'
                        ? null
                        : _toggleDriverStatus, // ✅ TAMBAH: Disable saat busy
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
                      _driverStatus == 'active'
                          ? Icons.toggle_on
                          : _driverStatus == 'busy'
                          ? Icons
                          .work // ✅ TAMBAH: Icon untuk busy
                          : Icons.toggle_off,
                      color: Colors.white,
                      size: 28,
                    ),
                    label: Text(
                      _isUpdatingStatus
                          ? 'Updating Status...'
                          : 'Status: ${_getStatusLabel(_driverStatus)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _getStatusColor(_driverStatus),
                      disabledBackgroundColor:
                      Colors.grey, // ✅ TAMBAH: Grey saat disabled
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
                "Loading Driver Data...",
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

    if (_errorMessage != null && _driverId == null) {
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
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xffD6E6F2),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // ✅ UBAH: Enhanced Header dengan notification badge
                _buildEnhancedHeader(),

                _buildDriverStatsCard(),
                // Request List
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      // ✅ BARU: Load requests + stats
                      print('🔄 Manual refresh triggered');
                      await _loadDriverRequests();
                      await _loadDriverStats();
                    },
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
                              "Loading requests...",
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
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Text(
                              'New Requests (${_driverRequests.length})',
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
                                  _buildDriverRequestCard(
                                      _driverRequests[index], index),
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

          // ✅ TAMBAHAN: Notification Badge Overlay
          if (_showNotificationBadge && _currentNotificationRequest != null)
            Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _badgeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _badgeAnimation.value,
                    child: DriverNotificationBadgeCard(
                      requestData: _currentNotificationRequest!,
                      isVisible: _showNotificationBadge,
                      onTap: () {
                        final requestId = _currentNotificationRequest!['id']?.toString() ?? '';
                        _hideInAppNotificationBadge();
                        if (requestId.isNotEmpty) {
                          _viewRequestDetail(requestId);
                        }
                      },
                      onDismiss: _hideInAppNotificationBadge,
                      autoHideDuration: const Duration(seconds: 8),
                    ),
                  );
                },
              ),
            ),
        ],
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

// ✅ TAMBAHAN: Driver Notification History Widget
class DriverNotificationHistoryWidget extends StatefulWidget {
  const DriverNotificationHistoryWidget({Key? key}) : super(key: key);

  @override
  State<DriverNotificationHistoryWidget> createState() => _DriverNotificationHistoryWidgetState();
}

class _DriverNotificationHistoryWidgetState extends State<DriverNotificationHistoryWidget> {
  @override
  Widget build(BuildContext context) {
    final notifications = DriverNotificationService.getPendingNotifications();

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
                    'Notifikasi Permintaan',
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
                        DriverNotificationService.clearBadgeCount();
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
                    'Notifikasi permintaan delivery akan muncul di sini',
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
                  return DriverNotificationCardWidget(
                    requestData: notification,
                    onTap: () {
                      Navigator.pop(context);
                      // Handle navigation to request detail
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