// ========================================
// Updated home_store.dart dengan Notification Badge System
// ========================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:del_pick/Views/Component/bottom_navigation.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Views/Store/history_store_detail.dart';
import 'package:del_pick/Views/Store/profil_store.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:lottie/lottie.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';

// Import updated services
import 'package:del_pick/Services/order_service.dart';
import 'package:del_pick/Services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../Component/notification_badge_card.dart';

// ✅ TAMBAH: Import notification service yang baru
// Pastikan file notification_service.dart sudah dibuat di folder yang sama

class HomeStore extends StatefulWidget {
  static const String route = '/Store/HomePage';

  const HomeStore({Key? key}) : super(key: key);

  @override
  State<HomeStore> createState() => _HomeStoreState();
}

class _HomeStoreState extends State<HomeStore> with TickerProviderStateMixin {
  late TabController _tabController;
  int _currentIndex = 0;

  // Separate data for tabs
  List<Map<String, dynamic>> _pendingOrders = [];
  List<Map<String, dynamic>> _activeOrders = [];

  // Loading states for each tab
  bool _isLoadingPending = true;
  bool _isLoadingActive = true;
  bool _hasErrorPending = false;
  bool _hasErrorActive = false;
  String _errorMessagePending = '';
  String _errorMessageActive = '';

  // Pagination for each tab
  int _pendingCurrentPage = 1;
  int _activeCurrentPage = 1;
  bool _isLoadingMorePending = false;
  bool _isLoadingMoreActive = false;
  bool _hasMorePendingData = true;
  bool _hasMoreActiveData = true;

  // Auto refresh timer (15 seconds for pending orders)
  Timer? _pendingOrdersTimer;

  // Animation controllers for both tabs
  late List<AnimationController> _pendingCardControllers = [];
  late List<Animation<Offset>> _pendingCardAnimations = [];
  late List<AnimationController> _activeCardControllers = [];
  late List<Animation<Offset>> _activeCardAnimations = [];

  // Scroll controllers for each tab
  final ScrollController _pendingScrollController = ScrollController();
  final ScrollController _activeScrollController = ScrollController();

  // Other existing controllers...
  late AnimationController _celebrationController;
  late AnimationController _pulseController;
  late AnimationController _rotationController;

  // ✅ HAPUS: FlutterLocalNotificationsPlugin yang lama (sudah ada di service)
  // final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();

  Map<String, dynamic>? _storeData;
  Map<String, dynamic>? _userData;

  // Processed orders tracking
  Set<String> _processedOrderIds = <String>{};
  static final Set<String> _globalProcessedOrderIds = <String>{};

  // New order celebration
  String? _newOrderId;
  bool _showCelebration = false;

  bool _needsRefresh = false;
  DateTime? _lastRefreshTime;

  // ✅ TAMBAH: Notification badge state
  int _notificationBadgeCount = 0;
  bool _notificationPermissionGranted = false;

  // ✅ PERBAIKAN: Logic filter yang lebih tepat untuk pending orders
  static bool _shouldShowInPendingTab(Map<String, dynamic> order) {
    final orderStatus = order['order_status']?.toString() ?? '';
    final deliveryStatus = order['delivery_status']?.toString() ?? '';

    print(
        '🔍 Checking order ${order['id']}: order_status=$orderStatus, delivery_status=$deliveryStatus');

    // ✅ ATURAN BISNIS YANG BENAR:
    // Tampilkan di pending tab HANYA jika order_status = 'pending'
    // Tidak peduli delivery_status apa (bisa pending atau picked_up)
    return orderStatus == 'pending';
  }

  // Logic filter yang lebih tepat untuk active orders
  static bool _shouldShowInActiveTab(Map<String, dynamic> order) {
    final orderStatus = order['order_status']?.toString() ?? '';

    print(
        '🔍 Checking order ${order['id']} for active tab: order_status=$orderStatus');

    // Tampilkan di active tab jika order_status adalah: preparing, ready_for_pickup, on_delivery, rejected
    return ['preparing', 'ready_for_pickup', 'on_delivery']
        .contains(orderStatus);
  }

  @override
  void dispose() {
    print('🗑️ HomeStore: Disposing widget...');

    _tabController.dispose();

    // ✅ PERBAIKAN: Cancel timer untuk pending orders
    _pendingOrdersTimer?.cancel();

    // ✅ PERBAIKAN: Dispose pending animation controllers
    for (var controller in _pendingCardControllers) {
      controller.dispose();
    }

    // ✅ PERBAIKAN: Dispose active animation controllers
    for (var controller in _activeCardControllers) {
      controller.dispose();
    }

    // ✅ TETAP: Dispose celebration controllers
    _celebrationController.dispose();
    _pulseController.dispose();
    _rotationController.dispose();

    // ✅ TETAP: Dispose audio player
    _audioPlayer.dispose();

    // ✅ PERBAIKAN: Dispose scroll controllers untuk kedua tab
    _pendingScrollController.dispose();
    _activeScrollController.dispose();

    // ✅ TAMBAH: Dispose notification service
    StoreNotificationService.dispose();

    print('✅ HomeStore: Widget disposed successfully');
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check if we need to refresh when returning from other pages
    if (_needsRefresh) {
      _needsRefresh = false;
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          // ✅ PERBAIKAN: Gunakan filtered refresh alih-alih force refresh
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeAnimations();

    // ✅ UBAH: Initialize notification service yang baru
    _initializeNotificationService();

    _validateAndInitializeData();
    _setupScrollListeners();

    //Start clear processed orders timer
    _clearOldProcessedOrders();
  }

  // ✅ TAMBAH: Initialize notification service yang baru
  Future<void> _initializeNotificationService() async {
    try {
      print('🔔 HomeStore: Initializing notification service...');

      // Initialize notification service
      await StoreNotificationService.initialize();

      // Request notification permissions
      _notificationPermissionGranted = await StoreNotificationService.requestNotificationPermissions(context);

      if (_notificationPermissionGranted) {
        print('✅ HomeStore: Notification permissions granted');
      } else {
        print('⚠️ HomeStore: Notification permissions denied');
      }

      // Update badge count from service
      setState(() {
        _notificationBadgeCount = StoreNotificationService.getBadgeCount();
      });

      print('✅ HomeStore: Notification service initialized successfully');
    } catch (e) {
      print('❌ HomeStore: Error initializing notification service: $e');
    }
  }

  /// Method untuk clear processed orders secara berkala
  void _clearOldProcessedOrders() {
    // ✅ PERBAIKAN: DISABLE processed orders clearing untuk auto refresh
    // Timer.periodic sudah tidak diperlukan karena auto refresh tidak filter processed orders
    print(
        '🧹 HomeStore: Processed orders clearing disabled for better auto refresh');
  }

  Future<void> _validateAndInitializeData() async {
    try {
      if (!mounted) return;

      setState(() {
        _isLoadingPending = true;
        _isLoadingActive = true;
        _hasErrorPending = false;
        _hasErrorActive = false;
      });

      print('🏪 HomeStore: Starting validation and initialization...');

      // Validate store access
      final hasStoreAccess = await AuthService.hasRole('store');
      if (!mounted) return;

      if (!hasStoreAccess) {
        throw Exception('Access denied: Store authentication required');
      }

      final hasValidSession = await AuthService.ensureValidUserData();
      if (!mounted) return;

      if (!hasValidSession) {
        throw Exception('Invalid user session. Please login again.');
      }

      print('✅ HomeStore: Store access validated');

      // Load store data
      await _loadStoreData();
      if (!mounted) return;

      // Load both pending and active orders
      await Future.wait([
        _loadPendingOrders(isRefresh: true),
        _loadActiveOrders(isRefresh: true),
      ]);

      if (!mounted) return;

      // Start auto refresh timer for pending orders (15 seconds)
      _startPendingOrdersMonitoring();

      if (mounted) {
        setState(() {
          _isLoadingPending = false;
          _isLoadingActive = false;
        });
      }

      print('✅ HomeStore: Initialization completed successfully');
    } catch (e) {
      print('❌ HomeStore: Initialization error: $e');

      if (mounted) {
        setState(() {
          _hasErrorPending = true;
          _hasErrorActive = true;
          _errorMessagePending = e.toString();
          _errorMessageActive = e.toString();
          _isLoadingPending = false;
          _isLoadingActive = false;
        });
      }
    }
  }

  void _startPendingOrdersMonitoring() {
    print('🔄 HomeStore: Starting pending orders monitoring (20s interval)...');

    // ✅ PERBAIKAN: Timer yang lebih konsisten
    _pendingOrdersTimer =
        Timer.periodic(const Duration(seconds: 20), (timer) async {
          if (!mounted) {
            timer.cancel();
            return;
          }

          try {
            print('📡 HomeStore: Auto-refreshing pending orders...');
            print('📊 Current pending orders count: ${_pendingOrders.length}');

            // ✅ PERBAIKAN: SELALU force refresh dari page 1
            await _loadPendingOrders(isRefresh: true, isAutoRefresh: true);

            print('✅ HomeStore: Auto refresh completed');
          } catch (e) {
            print('❌ HomeStore: Error auto-refreshing pending orders: $e');
            // ✅ JANGAN stop timer pada error, coba lagi di cycle berikutnya
          }
        });
  }

  void _initializeAnimations() {
    _celebrationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _pulseController.repeat(reverse: true);
    _rotationController.repeat();
  }

  void _initializePendingAnimations() {
    _pendingCardControllers = List.generate(
      _pendingOrders.length,
          (index) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 600 + (index * 100)),
      ),
    );

    _pendingCardAnimations = _pendingCardControllers.map((controller) {
      return Tween<Offset>(
        begin: const Offset(0, 0.5),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeOutCubic,
      ));
    }).toList();
  }

  void _initializeActiveAnimations() {
    _activeCardControllers = List.generate(
      _activeOrders.length,
          (index) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 600 + (index * 100)),
      ),
    );

    _activeCardAnimations = _activeCardControllers.map((controller) {
      return Tween<Offset>(
        begin: const Offset(0, 0.5),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeOutCubic,
      ));
    }).toList();
  }

  void _addNewPendingAnimations(int count) {
    for (int i = 0; i < count; i++) {
      AnimationController newController = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 600 + (i * 100)),
      );

      Animation<Offset> newAnimation = Tween<Offset>(
        begin: const Offset(0, 0.5),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: newController,
        curve: Curves.easeOutCubic,
      ));

      _pendingCardControllers.add(newController);
      _pendingCardAnimations.add(newAnimation);
    }
  }

  void _addNewActiveAnimations(int count) {
    for (int i = 0; i < count; i++) {
      AnimationController newController = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 600 + (i * 100)),
      );

      Animation<Offset> newAnimation = Tween<Offset>(
        begin: const Offset(0, 0.5),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: newController,
        curve: Curves.easeOutCubic,
      ));

      _activeCardControllers.add(newController);
      _activeCardAnimations.add(newAnimation);
    }
  }

  void _startPendingAnimations() {
    Future.delayed(const Duration(milliseconds: 100), () {
      for (int i = 0; i < _pendingCardControllers.length; i++) {
        Future.delayed(Duration(milliseconds: i * 100), () {
          if (mounted) _pendingCardControllers[i].forward();
        });
      }
    });
  }

  void _startActiveAnimations() {
    Future.delayed(const Duration(milliseconds: 100), () {
      for (int i = 0; i < _activeCardControllers.length; i++) {
        Future.delayed(Duration(milliseconds: i * 100), () {
          if (mounted) _activeCardControllers[i].forward();
        });
      }
    });
  }

  void _startNewPendingAnimations() {
    int startIndex = _pendingCardControllers.length - _pendingOrders.length;
    if (startIndex < 0) startIndex = 0;

    for (int i = startIndex; i < _pendingCardControllers.length; i++) {
      if (mounted) _pendingCardControllers[i].forward();
    }
  }

  void _startNewActiveAnimations() {
    int startIndex = _activeCardControllers.length - _activeOrders.length;
    if (startIndex < 0) startIndex = 0;

    for (int i = startIndex; i < _activeCardControllers.length; i++) {
      if (mounted) _activeCardControllers[i].forward();
    }
  }

  // store data loading dengan AuthService yang benar
  Future<void> _loadStoreData() async {
    try {
      print('🔍 HomeStore: Loading store data...');

      // ✅ Check mounted sebelum operasi async
      if (!mounted) {
        print('⚠️ HomeStore: Widget not mounted, skipping store data load');
        return;
      }

      // ✅ FIXED: Get role-specific data menggunakan AuthService
      final roleData = await AuthService.getRoleSpecificData();

      // ✅ Check mounted setelah operasi async
      if (!mounted) {
        print('⚠️ HomeStore: Widget not mounted after getRoleSpecificData');
        return;
      }

      if (roleData != null && roleData['store'] != null) {
        // ✅ Only call setState if mounted
        if (mounted) {
          setState(() {
            _storeData = roleData['store'];
            _userData = roleData['user'];
          });
        }

        _processStoreData(_storeData!);
        print('✅ HomeStore: Store data loaded from cache');
        print('   - Store ID: ${_storeData!['id']}');
        print('   - Store Name: ${_storeData!['name']}');
      } else {
        // ✅ FIXED: Fallback to fresh profile data
        print('⚠️ HomeStore: No cached store data, fetching fresh data...');

        if (!mounted) return; // Check before another async call

        final profileData = await AuthService.refreshUserData();

        if (!mounted) return; // Check after async call

        if (profileData != null && profileData['store'] != null) {
          if (mounted) {
            setState(() {
              _storeData = profileData['store'];
              _userData = profileData;
            });
          }
          _processStoreData(_storeData!);
          print('✅ HomeStore: Fresh store data loaded');
        } else {
          throw Exception('Unable to load store data from profile');
        }
      }
    } catch (e) {
      print('❌ HomeStore: Error loading store data: $e');
      // ✅ Only throw if still mounted
      if (mounted) {
        throw Exception('Failed to load store data: $e');
      }
    }
  }

  Future<void> _loadPendingOrders(
      {bool isRefresh = false, bool isAutoRefresh = false}) async {
    try {
      if (!mounted) return;

      print(
          '📋 HomeStore: Loading pending orders (refresh: $isRefresh, auto: $isAutoRefresh)...');

      // ✅ PERBAIKAN: Untuk auto refresh, SELALU reset pagination
      if (isRefresh || isAutoRefresh) {
        setState(() {
          _pendingCurrentPage = 1;
          _hasMorePendingData = true;
          if (!isAutoRefresh) _isLoadingPending = true;
        });
      }

      // ✅ PERBAIKAN: Auto refresh dengan parameter yang benar
      final response = await OrderService.getOrdersByStore(
        page: 1, // ✅ SELALU page 1 untuk auto refresh
        limit: isAutoRefresh ? 50 : 20, // ✅ Auto refresh ambil lebih banyak
        sortBy: 'created_at',
        sortOrder: 'desc', // ✅ PASTIKAN desc untuk data terbaru
        timestamp:
        DateTime.now().millisecondsSinceEpoch, // ✅ SELALU fresh timestamp
      );

      if (!mounted) return;

      final allOrders =
      List<Map<String, dynamic>>.from(response['orders'] ?? []);

      // ✅ PERBAIKAN: Filter HANYA berdasarkan order_status = 'pending'
      final validPendingOrders = allOrders.where((order) {
        final orderStatus = order['order_status']?.toString() ?? '';

        // ✅ UTAMA: Hanya tampilkan order dengan status pending
        return orderStatus == 'pending';
      }).toList();

      print(
          '📋 HomeStore: Found ${validPendingOrders.length} pending orders (auto: $isAutoRefresh)');

      // ✅ PERBAIKAN: Detect new orders hanya untuk manual load & auto refresh
      if (!isRefresh || isAutoRefresh) {
        final existingIds = _pendingOrders
            .map((order) => order['id']?.toString() ?? '')
            .toSet();
        for (var order in validPendingOrders) {
          final orderId = order['id']?.toString();
          if (orderId != null && !existingIds.contains(orderId)) {
            print('🎉 HomeStore: New pending order detected: $orderId');
            _triggerNewOrderCelebration(orderId);

            // ✅ TAMBAH: Show enhanced notification dengan badge
            await _showEnhancedNotification(order);
          }
        }
      }

      if (mounted) {
        setState(() {
          if (isRefresh || isAutoRefresh) {
            // ✅ PERBAIKAN: Dispose old controllers untuk auto refresh
            for (var controller in _pendingCardControllers) {
              controller.dispose();
            }
            _pendingOrders = validPendingOrders;
            _initializePendingAnimations();
          } else {
            _pendingOrders.addAll(validPendingOrders);
            _addNewPendingAnimations(validPendingOrders.length);
          }

          final totalPages = response['totalPages'] ?? 1;
          _hasMorePendingData = _pendingCurrentPage < totalPages;

          // ✅ PERBAIKAN: Hanya increment page untuk manual load
          if (!isAutoRefresh && !isRefresh) _pendingCurrentPage++;

          _isLoadingPending = false;
          _hasErrorPending = false;
        });

        // Start animations
        if (isRefresh || isAutoRefresh) {
          _startPendingAnimations();
        } else {
          _startNewPendingAnimations();
        }
      }

      print('✅ HomeStore: Pending orders loaded successfully');
    } catch (e) {
      print('❌ HomeStore: Error loading pending orders: $e');
      if (mounted) {
        setState(() {
          _hasErrorPending = true;
          _errorMessagePending = e.toString();
          _isLoadingPending = false;
        });
      }
    }
  }

  Future<void> _loadActiveOrders({bool isRefresh = false}) async {
    try {
      if (!mounted) return;

      print('📋 HomeStore: Loading active orders (refresh: $isRefresh)...');

      if (isRefresh) {
        setState(() {
          _activeCurrentPage = 1;
          _hasMoreActiveData = true;
          _isLoadingActive = true;
        });
      }

      final response = await OrderService.getOrdersByStore(
        page: _activeCurrentPage,
        limit: 20,
        sortBy: 'created_at',
        sortOrder: 'desc',
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      if (!mounted) return;

      final allOrders =
      List<Map<String, dynamic>>.from(response['orders'] ?? []);

      // Filter for active tab
      final validActiveOrders = allOrders.where((order) {
        return _shouldShowInActiveTab(order);
      }).toList();

      final totalPages = response['totalPages'] ?? 1;

      print('📋 HomeStore: Found ${validActiveOrders.length} active orders');

      if (mounted) {
        setState(() {
          if (isRefresh) {
            // Dispose old controllers
            for (var controller in _activeCardControllers) {
              controller.dispose();
            }
            _activeOrders = validActiveOrders;
            _initializeActiveAnimations();
          } else {
            _activeOrders.addAll(validActiveOrders);
            _addNewActiveAnimations(validActiveOrders.length);
          }

          _hasMoreActiveData = _activeCurrentPage < totalPages;
          _activeCurrentPage++;
          _isLoadingActive = false;
          _hasErrorActive = false;
        });

        // Start animations
        if (isRefresh) {
          _startActiveAnimations();
        } else {
          _startNewActiveAnimations();
        }
      }

      print('✅ HomeStore: Active orders loaded successfully');
    } catch (e) {
      print('❌ HomeStore: Error loading active orders: $e');
      if (mounted) {
        setState(() {
          _hasErrorActive = true;
          _errorMessageActive = e.toString();
          _isLoadingActive = false;
        });
      }
    }
  }

  void _processStoreData(Map<String, dynamic> storeData) {
    // Ensure all required store fields with defaults
    storeData['rating'] = storeData['rating'] ?? 0.0;
    storeData['review_count'] = storeData['review_count'] ?? 0;
    storeData['total_products'] = storeData['total_products'] ?? 0;
    storeData['status'] = storeData['status'] ?? 'active';

    print('📊 HomeStore: Store data processed');
    print('   - Rating: ${storeData['rating']}');
    print('   - Review Count: ${storeData['review_count']}');
    print('   - Status: ${storeData['status']}');
  }

  // ✅ UBAH: Enhanced notification dengan badge system
  Future<void> _showEnhancedNotification(Map<String, dynamic> orderDetails) async {
    try {
      if (!_notificationPermissionGranted) {
        print('⚠️ HomeStore: Notification permission not granted, skipping notification');
        return;
      }

      print('🔔 HomeStore: Showing enhanced notification for order: ${orderDetails['id']}');

      // Show notification dengan badge melalui service
      await StoreNotificationService.showOrderNotification(
        orderData: orderDetails,
        context: context,
      );

      // Update badge count di UI
      setState(() {
        _notificationBadgeCount = StoreNotificationService.getBadgeCount();
      });

      print('✅ HomeStore: Enhanced notification shown successfully');
    } catch (e) {
      print('❌ HomeStore: Error showing enhanced notification: $e');
    }
  }

  // ✅ TAMBAH: Method untuk show notification history
  void _showNotificationHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const NotificationHistoryWidget(),
    );
  }

  // ✅ TAMBAH: Method untuk clear notifications
  void _clearNotifications() {
    setState(() {
      _notificationBadgeCount = 0;
    });
    StoreNotificationService.clearBadgeCount();
  }

  /// Contact customer method
  void _contactCustomer(
      String phoneNumber, String customerName, String orderId) {
    try {
      // Clean phone number (remove any non-digits except +)
      String cleanedPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

      // Add country code if not present
      if (!cleanedPhone.startsWith('+') && !cleanedPhone.startsWith('62')) {
        if (cleanedPhone.startsWith('0')) {
          cleanedPhone = '62${cleanedPhone.substring(1)}';
        } else {
          cleanedPhone = '62$cleanedPhone';
        }
      }

      // Prepare WhatsApp message
      final message = Uri.encodeComponent('Halo $customerName! 👋\n\n'
          'Pesanan Anda dengan Order ID #$orderId telah kami terima dan sedang diproses. '
          'Kami akan segera menyiapkan pesanan Anda.\n\n'
          'Terima kasih telah mempercayai toko kami! 🙏');

      final whatsappUrl = 'https://wa.me/$cleanedPhone?text=$message';

      print('🚀 HomeStore: Opening WhatsApp URL: $whatsappUrl');

      // Try to open WhatsApp
      _launchWhatsApp(whatsappUrl, phoneNumber);
    } catch (e) {
      print('❌ HomeStore: Error contacting customer: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuka WhatsApp: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  /// Launch WhatsApp method
  void _launchWhatsApp(String whatsappUrl, String fallbackPhone) async {
    try {
      final Uri url = Uri.parse(whatsappUrl);

      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );
      } else {
        // Fallback: show phone number
        _showPhoneNumberDialog(fallbackPhone);
      }
    } catch (e) {
      print('❌ HomeStore: Error launching WhatsApp: $e');
      _showPhoneNumberDialog(fallbackPhone);
    }
  }

  /// Show phone number dialog sebagai fallback
  void _showPhoneNumberDialog(String phoneNumber) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Nomor Customer',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: GlobalStyle.fontFamily,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Silakan hubungi customer melalui:',
              style: TextStyle(fontFamily: GlobalStyle.fontFamily),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.phone, color: GlobalStyle.primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      phoneNumber,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: GlobalStyle.fontFamily,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      // Copy to clipboard
                      Clipboard.setData(ClipboardData(text: phoneNumber));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Nomor disalin ke clipboard'),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    },
                    icon: Icon(Icons.copy, color: GlobalStyle.primaryColor),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Tutup',
              style: TextStyle(fontFamily: GlobalStyle.fontFamily),
            ),
          ),
        ],
      ),
    );
  }

  /// method _showContactCustomerPopup
  Future<void> _showContactCustomerPopup(
      String orderId, Map<String, dynamic> orderData) async {
    try {
      // Get fresh order details for contact info
      final orderDetail = await OrderService.getOrderById(orderId);

      final customerName = orderDetail['customer']?['name'] ?? 'Customer';
      final customerPhone = orderDetail['customer']?['phone'] ?? '';
      final totalAmount = _parseDouble(orderDetail['total_amount']) ?? 0.0;
      final itemCount = orderDetail['items']?.length ?? 0;

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => Dialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Colors.green.shade50],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Success icon with animation
                TweenAnimationBuilder(
                  duration: const Duration(milliseconds: 600),
                  tween: Tween<double>(begin: 0, end: 1),
                  builder: (context, double value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Icon(Icons.check, color: Colors.white, size: 32),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  'Pesanan Diterima!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
                const SizedBox(height: 8),

                Text(
                  'Pesanan telah berhasil diterima dan siap diproses',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Order summary card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person,
                              color: GlobalStyle.primaryColor, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              customerName,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                fontFamily: GlobalStyle.fontFamily,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.receipt,
                              color: Colors.grey.shade600, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            '$itemCount item • ${GlobalStyle.formatRupiah(totalAmount)}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                              fontFamily: GlobalStyle.fontFamily,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Action buttons
                Row(
                  children: [
                    // Contact customer button
                    if (customerPhone.isNotEmpty) ...[
                      Expanded(
                        child: _buildActionButton(
                          onTap: () {
                            Navigator.of(context).pop();
                            _contactCustomer(
                                customerPhone, customerName, orderId);
                          },
                          icon: Icons.phone,
                          label: 'Hubungi Customer',
                          gradient: [Colors.green, Colors.green.shade600],
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],

                    // View detail button - PERBAIKAN UNTUK NAVIGASI YANG BENAR
                    Expanded(
                      child: _buildActionButton(
                        onTap: () {
                          Navigator.of(context).pop();
                          // Navigasi ke halaman detail order store
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => HistoryStoreDetailPage(
                                orderId: orderId,
                              ),
                            ),
                          );
                        },
                        icon: Icons.visibility,
                        label: 'Lihat Detail',
                        gradient: [
                          GlobalStyle.primaryColor,
                          GlobalStyle.primaryColor.withOpacity(0.8)
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Close button
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Tutup',
                    style: TextStyle(
                      color: Colors.grey.shade600,
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
    } catch (e) {
      print('❌ HomeStore: Error showing contact popup: $e');

      // Fallback success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('Pesanan berhasil diterima'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  /// Enhanced order processing menggunakan OrderService.processOrderByStore
  Future<void> _processOrder(String orderId, String action) async {
    try {
      print('⚙️ HomeStore: Processing order $orderId with action: $action');

      final hasStoreAccess = await AuthService.hasRole('store');
      if (!hasStoreAccess) {
        throw Exception('Access denied: Store authentication required');
      }

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: GlobalStyle.primaryColor),
                const SizedBox(height: 16),
                Text(
                  action == 'approve'
                      ? 'Menyetujui pesanan...'
                      : 'Menolak pesanan...',
                  style: TextStyle(
                      fontSize: 16, fontFamily: GlobalStyle.fontFamily),
                ),
              ],
            ),
          ),
        ),
      );

      // Process order using OrderService
      final result = await OrderService.processOrderByStore(
        orderId: orderId,
        action: action,
      );

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // ✅ PERBAIKAN: Hapus dari pending orders dengan immediate update
      setState(() {
        _pendingOrders
            .removeWhere((order) => order['id']?.toString() == orderId);
      });

      // ✅ PERBAIKAN: Refresh data dengan delay untuk memastikan backend sudah update
      await Future.delayed(const Duration(milliseconds: 500));

      // Force refresh both tabs tanpa mengganggu pagination
      await Future.wait([
        _loadPendingOrders(isRefresh: true),
        _loadActiveOrders(isRefresh: true),
      ]);

      print(
          '✅ HomeStore: Order $orderId processed successfully and UI refreshed');

      // Show appropriate response
      if (action == 'approve') {
        await _showContactCustomerPopup(orderId, result);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Pesanan berhasil ditolak'),
                ],
              ),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }

      // ✅ TAMBAHAN: Trigger global refresh untuk history store jika sedang aktif
      // Ini bisa dilakukan dengan event bus atau shared preferences
      await _notifyHistoryStoreRefresh();
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) Navigator.of(context).pop();

      print('❌ HomeStore: Error processing order: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Gagal memproses pesanan: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Refresh on error
      await Future.wait([
        _loadPendingOrders(isRefresh: true),
        _loadActiveOrders(isRefresh: true),
      ]);
    }
  }

  Future<void> _notifyHistoryStoreRefresh() async {
    try {
      // Simpan timestamp terakhir update untuk history store
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'last_order_update', DateTime.now().toIso8601String());
      print('📡 HomeStore: Notified history store to refresh');
    } catch (e) {
      print('⚠️ HomeStore: Failed to notify history store: $e');
    }
  }

  /// Enhanced order detail viewing menggunakan OrderService.getOrderById
  Future<void> _viewOrderDetail(String orderId) async {
    try {
      print('👁️ HomeStore: Viewing order detail: $orderId');

      final hasStoreAccess = await AuthService.hasRole('store');
      if (!hasStoreAccess) {
        throw Exception('Access denied: Store authentication required');
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: GlobalStyle.primaryColor),
                const SizedBox(height: 16),
                Text(
                  'Memuat detail pesanan...',
                  style: TextStyle(
                    fontSize: 16,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final orderDetail = await OrderService.getOrderById(orderId);
      Navigator.of(context).pop(); // Close loading dialog

      if (orderDetail.isNotEmpty) {
        // ✅ PERBAIKAN: Navigate tanpa return handling yang tidak perlu
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HistoryStoreDetailPage(
              orderId: orderId,
            ),
          ),
        );

        // ✅ PERBAIKAN: Refresh both tabs setelah kembali dari detail
        await Future.wait([
          _loadPendingOrders(isRefresh: true),
          _loadActiveOrders(isRefresh: true),
        ]);

        print('✅ HomeStore: Navigated to order detail');
      } else {
        throw Exception('Order detail is empty');
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog

      print('❌ HomeStore: Error viewing order detail: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat detail pesanan: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _setupScrollListeners() {
    _pendingScrollController.addListener(() {
      if (_pendingScrollController.position.pixels >=
          _pendingScrollController.position.maxScrollExtent - 200) {
        if (!_isLoadingMorePending && _hasMorePendingData) {
          _loadMorePendingOrders();
        }
      }
    });

    _activeScrollController.addListener(() {
      if (_activeScrollController.position.pixels >=
          _activeScrollController.position.maxScrollExtent - 200) {
        if (!_isLoadingMoreActive && _hasMoreActiveData) {
          _loadMoreActiveOrders();
        }
      }
    });
  }

  Future<void> _loadMorePendingOrders() async {
    if (_isLoadingMorePending || !_hasMorePendingData) return;

    setState(() {
      _isLoadingMorePending = true;
    });

    try {
      await _loadPendingOrders();
    } catch (e) {
      print('❌ HomeStore: Error loading more pending orders: $e');
    } finally {
      setState(() {
        _isLoadingMorePending = false;
      });
    }
  }

  Future<void> _loadMoreActiveOrders() async {
    if (_isLoadingMoreActive || !_hasMoreActiveData) return;

    setState(() {
      _isLoadingMoreActive = true;
    });

    try {
      await _loadActiveOrders();
    } catch (e) {
      print('❌ HomeStore: Error loading more active orders: $e');
    } finally {
      setState(() {
        _isLoadingMoreActive = false;
      });
    }
  }

  void _triggerNewOrderCelebration(String orderId) {
    setState(() {
      _newOrderId = orderId;
      _showCelebration = true;
    });

    // Play celebration sound
    _audioPlayer.play(AssetSource('audio/celebration.wav'));

    // Start celebration animation
    _celebrationController.forward().then((_) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showCelebration = false;
            _newOrderId = null;
          });
          _celebrationController.reset();
        }
      });
    });
  }

  // ✅ HAPUS: initializeNotifications yang lama (sudah ada di service)

  // ✅ BARU: Helper method untuk safely parse double dari string
  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 100, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: GlobalStyle.fontColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
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

  Widget _buildErrorState(String errorMessage, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Terjadi Kesalahan',
            style: TextStyle(
              color: GlobalStyle.fontColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              errorMessage,
              style: TextStyle(
                color: GlobalStyle.fontColor.withOpacity(0.7),
                fontSize: 14,
                fontFamily: GlobalStyle.fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: GlobalStyle.primaryColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              'Coba Lagi',
              style: TextStyle(
                color: Colors.white,
                fontFamily: GlobalStyle.fontFamily,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'preparing':
        return Colors.purple;
      case 'ready_for_pickup':
        return Colors.green;
      case 'on_delivery':
        return Colors.teal;
      case 'delivered':
        return Colors.green[700]!;
      case 'cancelled':
        return Colors.red;
      case 'rejected':
        return Colors.red[800]!;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Menunggu';
      case 'confirmed':
        return 'Dikonfirmasi';
      case 'preparing':
        return 'Disiapkan';
      case 'ready_for_pickup':
        return 'Siap Diambil';
      case 'on_delivery':
        return 'Diantar';
      case 'delivered':
        return 'Selesai';
      case 'cancelled':
        return 'Dibatalkan';
      case 'rejected':
        return 'Ditolak';
      default:
        return 'Unknown';
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'preparing':
        return Icons.restaurant;
      case 'ready_for_pickup':
        return Icons.check_circle;
      case 'on_delivery':
        return Icons.local_shipping;
      default:
        return Icons.info;
    }
  }

  // ✅ UBAH: Enhanced header dengan notification badge
  Widget _buildEnhancedHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            GlobalStyle.lightColor.withOpacity(0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dashboard title
                Text(
                  'Dashboard Toko',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: GlobalStyle.fontFamily,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),

                // Store name dengan fallback dan loading state
                _buildStoreNameWidget(),

                const SizedBox(height: 4),

                // Store status dan info tambahan
                _buildStoreInfoWidget(),

                const SizedBox(height: 2),

                // Date dengan format Indonesia
                Text(
                  _getFormattedDate(),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
              ],
            ),
          ),

          // ✅ TAMBAH: Notification button dengan badge
          NotificationBadgeWidget(
            count: _notificationBadgeCount,
            badgeColor: Colors.red,
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: GestureDetector(
                onTap: _showNotificationHistory,
                child: Icon(
                  Icons.notifications,
                  color: Colors.orange,
                  size: 20,
                ),
              ),
            ),
          ),

          // Profile button dengan store avatar jika ada
          _buildProfileButton(),
        ],
      ),
    );
  }

// Widget untuk menampilkan nama toko
  Widget _buildStoreNameWidget() {
    if (_storeData == null) {
      // Loading state
      return Container(
        height: 20,
        width: 120,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(4),
        ),
      );
    }

    final storeName =
        _storeData?['name']?.toString() ?? 'Nama Toko Tidak Diketahui';

    return Text(
      storeName,
      style: TextStyle(
        color: GlobalStyle.primaryColor,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        fontFamily: GlobalStyle.fontFamily,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

// Widget untuk menampilkan info tambahan store
  Widget _buildStoreInfoWidget() {
    if (_storeData == null) return const SizedBox.shrink();

    final storeStatus = _storeData?['status']?.toString() ?? 'unknown';
    final rating = _parseDouble(_storeData?['rating']) ?? 0.0;
    final totalProducts = _storeData?['total_products'] ?? 0;

    return Row(
      children: [
        // Status indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _getStoreStatusColor(storeStatus),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _getStoreStatusLabel(storeStatus),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Rating jika ada
        if (rating > 0) ...[
          Icon(Icons.star, size: 12, color: Colors.amber),
          const SizedBox(width: 2),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
        ],

        // Total produk
        Text(
          '$totalProducts produk',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

// Profile button dengan avatar store jika ada
  Widget _buildProfileButton() {
    final storeImageUrl = _storeData?['image_url']?.toString();
    final userAvatar = _userData?['avatar']?.toString();

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, ProfileStorePage.route);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              GlobalStyle.primaryColor,
              GlobalStyle.primaryColor.withOpacity(0.8),
            ],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: GlobalStyle.primaryColor.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: _buildProfileIcon(storeImageUrl, userAvatar),
      ),
    );
  }

// Widget untuk profile icon
  Widget _buildProfileIcon(String? storeImageUrl, String? userAvatar) {
    // Prioritas: store image -> user avatar -> default icon
    if (storeImageUrl != null && storeImageUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          storeImageUrl,
          width: 20,
          height: 20,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildDefaultProfileIcon();
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _buildDefaultProfileIcon();
          },
        ),
      );
    }

    if (userAvatar != null && userAvatar.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          userAvatar,
          width: 20,
          height: 20,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildDefaultProfileIcon();
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _buildDefaultProfileIcon();
          },
        ),
      );
    }

    return _buildDefaultProfileIcon();
  }

  Widget _buildDefaultProfileIcon() {
    return FaIcon(
      FontAwesomeIcons.user,
      size: 20,
      color: Colors.white,
    );
  }

// Helper methods
  String _getFormattedDate() {
    final now = DateTime.now();
    final dayNames = [
      'Minggu',
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu'
    ];
    final monthNames = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember'
    ];

    final dayName = dayNames[now.weekday % 7];
    final monthName = monthNames[now.month - 1];

    return '$dayName, ${now.day} $monthName ${now.year}';
  }

  Color _getStoreStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'inactive':
        return Colors.orange;
      case 'closed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStoreStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return 'AKTIF';
      case 'inactive':
        return 'NONAKTIF';
      case 'closed':
        return 'TUTUP';
      default:
        return 'UNKNOWN';
    }
  }

  Widget _buildPendingOrdersTab() {
    if (_isLoadingPending && _pendingOrders.isEmpty) {
      return _buildLoadingState();
    }

    if (_hasErrorPending && _pendingOrders.isEmpty) {
      return _buildErrorState(
          _errorMessagePending, () => _loadPendingOrders(isRefresh: true));
    }

    if (_pendingOrders.isEmpty) {
      return _buildEmptyState(
        'Tidak ada pesanan masuk',
        'Pesanan baru akan muncul di sini',
        Icons.inbox_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadPendingOrders(isRefresh: true),
      color: GlobalStyle.primaryColor,
      child: ListView.builder(
        controller: _pendingScrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16)
            .copyWith(bottom: 80, top: 8),
        itemCount: _pendingOrders.length + (_isLoadingMorePending ? 1 : 0),
        itemBuilder: (context, index) {
          if (index < _pendingOrders.length) {
            return _buildPendingOrderCard(_pendingOrders[index], index);
          } else {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Center(
                child:
                CircularProgressIndicator(color: GlobalStyle.primaryColor),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildPendingOrderCard(Map<String, dynamic> order, int index) {
    String orderId = order['id']?.toString() ?? '';
    bool isNewOrder = _newOrderId == orderId;

    final totalAmount = _parseDouble(order['total_amount']) ?? 0.0;
    final deliveryFee = _parseDouble(order['delivery_fee']) ?? 0.0;
    final itemCount = order['items']?.length ?? 0;

    Widget cardContent = Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.orange.shade50],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Header with NEW badge if applicable
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.orange, Colors.orange.shade600],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.pending_actions,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Order #$orderId',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.black87,
                              ),
                            ),
                            if (isNewOrder && _showCelebration) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'BARU!',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.access_time,
                                size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              order['created_at'] != null
                                  ? DateFormat('dd MMM yyyy HH:mm').format(
                                  DateTime.parse(order['created_at']))
                                  : 'Unknown Time',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'MENUNGGU',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Order summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.shopping_cart,
                            color: GlobalStyle.primaryColor, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '$itemCount item pesanan',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                GlobalStyle.primaryColor,
                                GlobalStyle.primaryColor.withOpacity(0.8)
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            GlobalStyle.formatRupiah(totalAmount),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.delivery_dining,
                            color: Colors.grey.shade600, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Ongkir: ${GlobalStyle.formatRupiah(deliveryFee)}',
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Action buttons for pending orders
              Row(
                children: [
                  // View Detail Button
                  Expanded(
                    child: _buildActionButton(
                      onTap: () => _viewOrderDetail(orderId),
                      icon: Icons.visibility,
                      label: 'Detail',
                      gradient: [
                        GlobalStyle.primaryColor,
                        GlobalStyle.primaryColor.withOpacity(0.8)
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Accept Button
                  Expanded(
                    flex: 2,
                    child: _buildActionButton(
                      onTap: () => _processOrder(orderId, 'approve'),
                      icon: Icons.check_circle,
                      label: 'Terima Pesanan',
                      gradient: [Colors.green, Colors.green.shade600],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Reject Button
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Colors.red, Color(0xFFF44336)]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _processOrder(orderId, 'reject'),
                        child: const Center(
                          child:
                          Icon(Icons.close, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    // Add celebration animation for new orders
    if (isNewOrder && _showCelebration) {
      return AnimatedBuilder(
        animation: _celebrationController,
        builder: (context, child) {
          return Transform.scale(
            scale: 1.0 +
                (0.1 *
                    Curves.elasticOut.transform(_celebrationController.value)),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.yellow
                        .withOpacity(0.6 * _celebrationController.value),
                    blurRadius: 20 * _celebrationController.value,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: cardContent,
            ),
          );
        },
      );
    }

    // Regular slide animation
    return SlideTransition(
      position: index < _pendingCardAnimations.length
          ? _pendingCardAnimations[index]
          : const AlwaysStoppedAnimation(Offset.zero),
      child: cardContent,
    );
  }

  Widget _buildActiveOrdersTab() {
    if (_isLoadingActive && _activeOrders.isEmpty) {
      return _buildLoadingState();
    }

    if (_hasErrorActive && _activeOrders.isEmpty) {
      return _buildErrorState(
          _errorMessageActive, () => _loadActiveOrders(isRefresh: true));
    }

    if (_activeOrders.isEmpty) {
      return _buildEmptyState(
        'Tidak ada pesanan aktif',
        'Pesanan yang sedang diproses akan muncul di sini',
        Icons.local_shipping_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadActiveOrders(isRefresh: true),
      color: GlobalStyle.primaryColor,
      child: ListView.builder(
        controller: _activeScrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16)
            .copyWith(bottom: 80, top: 8),
        itemCount: _activeOrders.length + (_isLoadingMoreActive ? 1 : 0),
        itemBuilder: (context, index) {
          if (index < _activeOrders.length) {
            return _buildActiveOrderCard(_activeOrders[index], index);
          } else {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Center(
                child:
                CircularProgressIndicator(color: GlobalStyle.primaryColor),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildActiveOrderCard(Map<String, dynamic> order, int index) {
    String status = order['order_status'] as String? ?? 'preparing';
    String orderId = order['id']?.toString() ?? '';

    final totalAmount = _parseDouble(order['total_amount']) ?? 0.0;
    final deliveryFee = _parseDouble(order['delivery_fee']) ?? 0.0;
    final itemCount = order['items']?.length ?? 0;

    Widget cardContent = Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, _getStatusColor(status).withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _getStatusColor(status),
                          _getStatusColor(status).withOpacity(0.8)
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_getStatusIcon(status),
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order #$orderId',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.access_time,
                                size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              order['created_at'] != null
                                  ? DateFormat('dd MMM yyyy HH:mm').format(
                                  DateTime.parse(order['created_at']))
                                  : 'Unknown Time',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                          ],
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
                      boxShadow: [
                        BoxShadow(
                          color: _getStatusColor(status).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
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

              // Order summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.shopping_cart,
                            color: GlobalStyle.primaryColor, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '$itemCount item pesanan',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                GlobalStyle.primaryColor,
                                GlobalStyle.primaryColor.withOpacity(0.8)
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            GlobalStyle.formatRupiah(totalAmount),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.delivery_dining,
                            color: Colors.grey.shade600, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Ongkir: ${GlobalStyle.formatRupiah(deliveryFee)}',
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // View Detail Button only for active orders
              SizedBox(
                width: double.infinity,
                child: _buildActionButton(
                  onTap: () => _viewOrderDetail(orderId),
                  icon: Icons.visibility,
                  label: 'Lihat Detail Pesanan',
                  gradient: [
                    GlobalStyle.primaryColor,
                    GlobalStyle.primaryColor.withOpacity(0.8)
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return SlideTransition(
      position: index < _activeCardAnimations.length
          ? _activeCardAnimations[index]
          : const AlwaysStoppedAnimation(Offset.zero),
      child: cardContent,
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
            'Memuat data pesanan...',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback onTap,
    required IconData icon,
    required String label,
    required List<Color> gradient,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: GlobalStyle.fontFamily,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFE),
      body: SafeArea(
        child: Column(
          children: [
            // Enhanced Header dengan notification badge
            _buildEnhancedHeader(),

            // Tab Bar (sisanya tetap sama)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: GlobalStyle.primaryColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey.shade600,
                labelStyle: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: GlobalStyle.fontFamily,
                ),
                unselectedLabelStyle: TextStyle(
                  fontWeight: FontWeight.normal,
                  fontFamily: GlobalStyle.fontFamily,
                ),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.pending_actions, size: 18),
                        const SizedBox(width: 8),
                        Text('Pesanan Masuk'),
                        if (_pendingOrders.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_pendingOrders.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.local_shipping, size: 18),
                        const SizedBox(width: 8),
                        Text('Pesanan Aktif'),
                        if (_activeOrders.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_activeOrders.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Tab Views (sisanya tetap sama)
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(top: 16),
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPendingOrdersTab(),
                    _buildActiveOrdersTab(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationComponent(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
      ),
    );
  }
}