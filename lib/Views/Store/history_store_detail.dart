import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:lottie/lottie.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';

// Import Models
import 'package:del_pick/Models/order.dart';
import 'package:del_pick/Models/order_enum.dart';

// Import updated services
import 'package:del_pick/Services/order_service.dart';
import 'package:del_pick/Services/auth_service.dart';
import 'package:del_pick/Services/image_service.dart';

class HistoryStoreDetailPage extends StatefulWidget {
  static const String route = '/Store/HistoryStoreDetail';
  final String orderId;

  const HistoryStoreDetailPage({Key? key, required this.orderId})
      : super(key: key);

  @override
  _HistoryStoreDetailPageState createState() => _HistoryStoreDetailPageState();
}

class _HistoryStoreDetailPageState extends State<HistoryStoreDetailPage>
    with TickerProviderStateMixin {
  // Data state
  OrderModel? _orderDetail;
  Map<String, dynamic>? _storeData;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isUpdatingStatus = false;
  bool _isRefreshing = false;

  // Animation controllers
  late List<AnimationController> _cardControllers;
  late List<Animation<Offset>> _cardAnimations;
  late AnimationController _statusController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Status tracking
  Timer? _statusUpdateTimer;
  OrderStatus? _previousStatus;
  DeliveryStatus? _previousDeliveryStatus;
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Store-specific color theme for status card
  final Color _primaryColor = const Color(0xFF7B1FA2);
  final Color _secondaryColor = const Color(0xFF9C27B0);

  // Standardized status timeline (same as customer)
// ✅ PERBAIKAN: Status timeline yang benar sesuai backend
  final List<Map<String, dynamic>> _statusTimeline = [
    {
      'status': OrderStatus.pending,
      'label': 'Menunggu',
      'description': 'Pesanan baru masuk',
      'icon': Icons.notification_important,
      'color': Colors.orange,
      'animation': 'assets/animations/diambil.json'
    },
    {
      'status':
          OrderStatus.preparing, // ✅ LANGSUNG preparing (tidak ada confirmed)
      'label': 'Disiapkan',
      'description': 'Mempersiapkan pesanan',
      'icon': Icons.restaurant_menu,
      'color': Colors.purple,
      'animation': 'assets/animations/diproses.json'
    },
    {
      'status': OrderStatus.readyForPickup,
      'label': 'Siap Diambil',
      'description': 'Siap diambil driver',
      'icon': Icons.shopping_bag,
      'color': Colors.indigo,
      'animation': 'assets/animations/diproses.json'
    },
    {
      'status': OrderStatus.onDelivery,
      'label': 'Diantar',
      'description': 'Dalam perjalanan',
      'icon': Icons.local_shipping,
      'color': Colors.teal,
      'animation': 'assets/animations/diantar.json'
    },
    {
      'status': OrderStatus.delivered,
      'label': 'Selesai',
      'description': 'Pesanan terkirim',
      'icon': Icons.done_all,
      'color': Colors.green,
      'animation': 'assets/animations/pesanan_selesai.json'
    },
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _validateAndLoadData();
  }

  void _initializeAnimations() {
    // Initialize animation controllers for card sections
    _cardControllers = List.generate(
      5, // Status, Customer, Driver, Items, Actions cards
      (index) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 600 + (index * 150)),
      ),
    );

    // Status card animation controller
    _statusController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Initialize pulse animation for status card
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Create slide animations for each card
    _cardAnimations = _cardControllers.map((controller) {
      return Tween<Offset>(
        begin: const Offset(0, 0.3),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeOutCubic,
      ));
    }).toList();
  }

  @override
  void dispose() {
    for (var controller in _cardControllers) {
      controller.dispose();
    }
    _statusController.dispose();
    _pulseController.dispose();
    _audioPlayer.dispose();
    _statusUpdateTimer?.cancel();
    super.dispose();
  }

// ✅ PERBAIKAN: Enhanced safe map conversion
  static Map<String, dynamic> _safeMapConversion(dynamic data) {
    if (data == null) return {};

    if (data is Map<String, dynamic>) {
      return data;
    } else if (data is Map) {
      return Map<String, dynamic>.from(data.map((key, value) {
        // ✅ PERBAIKAN: Handle nested conversion dengan aman
        String safeKey = key.toString();
        dynamic safeValue = value;

        try {
          if (value is Map && value is! Map<String, dynamic>) {
            safeValue = _safeMapConversion(value);
          } else if (value is List) {
            // ✅ KHUSUS: Handle tracking_updates list
            if (safeKey == 'tracking_updates') {
              safeValue = _processTrackingList(value);
            } else {
              safeValue = _safeListConversion(value);
            }
          } else if (value is String && value.isNotEmpty) {
            // ✅ PERBAIKAN: Hanya coba parse JSON jika format valid
            if ((value.startsWith('[') && value.endsWith(']')) ||
                (value.startsWith('{') && value.endsWith('}'))) {
              try {
                final decoded = jsonDecode(value);
                if (decoded is Map) {
                  safeValue = _safeMapConversion(decoded);
                } else if (decoded is List) {
                  if (safeKey == 'tracking_updates') {
                    safeValue = _processTrackingList(decoded);
                  } else {
                    safeValue = _safeListConversion(decoded);
                  }
                }
              } catch (e) {
                // Tetap gunakan string original jika parsing gagal
                print(
                    '⚠️ JSON parse failed for key "$safeKey": ${e.toString()}');
                safeValue = value;
              }
            }
          }
        } catch (e) {
          print('❌ Error processing key "$safeKey": $e');
          safeValue = value; // Fallback ke nilai original
        }

        return MapEntry(safeKey, safeValue);
      }));
    }

    return {};
  }

  static List<dynamic> _safeListConversion(List<dynamic> list) {
    return list.map((item) {
      if (item is Map && item is! Map<String, dynamic>) {
        return _safeMapConversion(item);
      } else if (item is String) {
        // ✅ TAMBAHAN: Handle string JSON dalam list
        try {
          if (item.startsWith('{') || item.startsWith('[')) {
            final decoded = jsonDecode(item);
            if (decoded is Map) {
              return _safeMapConversion(decoded);
            } else if (decoded is List) {
              return _safeListConversion(decoded);
            }
          }
        } catch (e) {
          print(
              '⚠️ JSON parse failed in list: ${item.substring(0, item.length > 100 ? 100 : item.length)}...');
        }
      }
      return item;
    }).toList();
  }

// ✅ PERBAIKAN UTAMA: Enhanced tracking updates conversion
  static List<Map<String, dynamic>> _safeTrackingConversion(
      dynamic trackingData) {
    print('🔍 Processing tracking data: ${trackingData.runtimeType}');

    if (trackingData == null) return [];

    try {
      if (trackingData is String) {
        if (trackingData.isEmpty || trackingData == 'null') return [];

        print('📝 Parsing tracking string length: ${trackingData.length}');

        final decoded = jsonDecode(trackingData);
        if (decoded is List) {
          return _processTrackingList(decoded);
        } else if (decoded is Map) {
          final safeMap = _safeMapConversion(decoded);
          return [safeMap];
        }
      } else if (trackingData is List) {
        return _processTrackingList(trackingData);
      } else if (trackingData is Map) {
        final safeMap = _safeMapConversion(trackingData);
        return [safeMap];
      }
    } catch (e) {
      print('❌ Error parsing tracking updates: $e');
      print(
          '   Data preview: ${trackingData.toString().substring(0, trackingData.toString().length > 300 ? 300 : trackingData.toString().length)}...');
    }

    return [];
  }

// ✅ TAMBAHAN: Method khusus untuk memproses tracking list
  static List<Map<String, dynamic>> _processTrackingList(
      List<dynamic> trackingList) {
    List<Map<String, dynamic>> result = [];

    print('🔧 Processing tracking list with ${trackingList.length} items');

    for (int i = 0; i < trackingList.length; i++) {
      final item = trackingList[i];

      // ✅ FILTER: Hanya proses item yang merupakan Map atau string JSON valid
      if (item is Map) {
        try {
          final safeMap = _safeMapConversion(item);
          // ✅ VALIDASI: Pastikan item memiliki struktur tracking yang valid
          if (safeMap.containsKey('timestamp') ||
              safeMap.containsKey('status') ||
              safeMap.containsKey('message')) {
            result.add(safeMap);
            print(
                '✅ Added valid tracking item: ${safeMap['status'] ?? 'unknown'}');
          }
        } catch (e) {
          print('⚠️ Skipped invalid map item at index $i: $e');
        }
      } else if (item is String && item.length > 10) {
        // ✅ FILTER: Hanya coba parse string yang cukup panjang untuk menjadi JSON
        try {
          if (item.trim().startsWith('{') && item.trim().endsWith('}')) {
            final decoded = jsonDecode(item);
            if (decoded is Map) {
              final safeMap = _safeMapConversion(decoded);
              if (safeMap.containsKey('timestamp') ||
                  safeMap.containsKey('status') ||
                  safeMap.containsKey('message')) {
                result.add(safeMap);
                print(
                    '✅ Added valid tracking item from string: ${safeMap['status'] ?? 'unknown'}');
              }
            }
          }
        } catch (e) {
          // Ignore invalid JSON strings
          print('⚠️ Skipped invalid string item at index $i');
        }
      }
      // ✅ SKIP: Abaikan item lain seperti karakter tunggal
    }

    print(
        '✅ Processed tracking list: ${result.length} valid items from ${trackingList.length} total');
    return result;
  }

  // ✅ FIXED: Enhanced validation and data loading menggunakan getRoleSpecificData
// GANTI method _validateAndLoadData() yang ada dengan ini:
  Future<void> _validateAndLoadData() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      print('🏪 HistoryStoreDetail: Starting validation and data loading...');

      // ✅ FIXED: First check if user is authenticated
      final isAuthenticated = await AuthService.isAuthenticated();
      if (!isAuthenticated) {
        throw Exception('User not authenticated. Please login again.');
      }

      // ✅ FIXED: Get user data and role-specific data
      final userData = await AuthService.getUserData();
      final roleData = await AuthService.getRoleSpecificData();

      if (userData == null) {
        throw Exception('Unable to retrieve user data. Please login again.');
      }

      if (roleData == null) {
        throw Exception('Unable to retrieve role data. Please login again.');
      }

      print('✅ HistoryStoreDetail: User data retrieved');
      print('   - User data keys: ${userData.keys.toList()}');
      print('   - Role data keys: ${roleData.keys.toList()}');

      // ✅ FIXED: Check if user has store role
      final userRole = await AuthService.getUserRole();
      print('🔍 HistoryStoreDetail: User role: $userRole');

      if (userRole?.toLowerCase() != 'store') {
        // ✅ BACKUP: Check from roleData if getUserRole fails
        final hasStoreData = roleData['store'] != null;
        if (!hasStoreData) {
          throw Exception('Access denied: Store authentication required');
        }
        print('✅ HistoryStoreDetail: Store access confirmed via roleData');
      } else {
        print('✅ HistoryStoreDetail: Store access confirmed via userRole');
      }

      // ✅ FIXED: Ensure valid user session
      final hasValidSession = await AuthService.ensureValidUserData();
      if (!hasValidSession) {
        throw Exception('Invalid user session. Please login again.');
      }

      // ✅ FIXED: Store user and store data
      setState(() {
        _userData = userData;
        _storeData = roleData['store'];
      });

      if (_storeData != null) {
        print(
            '✅ HistoryStoreDetail: Store data loaded - ID: ${_storeData!['id']}');
        print('   - Store Name: ${_storeData!['name']}');
      } else {
        print('⚠️ HistoryStoreDetail: No store data found, but proceeding...');
      }

      print('✅ HistoryStoreDetail: Authentication and validation completed');

      // ✅ SMART: Initial load pakai cache (false = tidak force refresh)
      await _loadOrderDataSmart(forceRefresh: false);

      // Start animations
      _startAnimations();

      setState(() {
        _isLoading = false;
      });

      print('✅ HistoryStoreDetail: Data loading completed successfully');
    } catch (e) {
      print('❌ HistoryStoreDetail: Validation/loading error: $e');
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  // GANTI method _loadOrderData() yang ada dengan ini:
  Future<void> _loadOrderDataSmart({bool forceRefresh = false}) async {
    try {
      print(
          '📋 HistoryStoreDetail: Loading order data ${forceRefresh ? 'WITH FORCE REFRESH' : 'from cache if available'}');

      final isAuthenticated = await AuthService.isAuthenticated();
      if (!isAuthenticated) {
        throw Exception('User not authenticated');
      }

      // ✅ SMART: Hanya force refresh jika diminta
      final rawOrderData = await OrderService.getOrderByIdSmart(widget.orderId,
          forceRefresh: forceRefresh);

      if (rawOrderData.isNotEmpty) {
        print('📊 Raw order data keys: ${rawOrderData.keys.toList()}');

        // ✅ PERBAIKAN: Handle tracking_updates dengan cara yang lebih aman
        Map<String, dynamic> processedOrderData =
            Map<String, dynamic>.from(rawOrderData);

        // ✅ Debug tracking data sebelum diproses
        if (processedOrderData.containsKey('tracking_updates')) {
          final trackingData = processedOrderData['tracking_updates'];
          print('📊 Original tracking data type: ${trackingData.runtimeType}');
          print(
              '📊 Original tracking data length: ${trackingData is List ? trackingData.length : 'not a list'}');

          // ✅ Process tracking updates secara khusus
          final processedTracking = _safeTrackingConversion(trackingData);
          processedOrderData['tracking_updates'] = processedTracking;

          print(
              '✅ Final processed tracking: ${processedTracking.length} valid items');
        }

        // ✅ Safe conversion untuk semua data
        final safeOrderData = _safeMapConversion(processedOrderData);

        print('✅ HistoryStoreDetail: Order data converted safely');

        // ✅ TAMBAHAN: Validasi dan sanitasi data sebelum membuat OrderModel
        try {
          // Validasi customer data
          if (safeOrderData['customer'] != null) {
            if (safeOrderData['customer'] is! Map<String, dynamic>) {
              print(
                  '⚠️ Converting customer data type: ${safeOrderData['customer'].runtimeType}');
              safeOrderData['customer'] =
                  _safeMapConversion(safeOrderData['customer']);
            }
          }

          // Validasi store data
          if (safeOrderData['store'] != null) {
            if (safeOrderData['store'] is! Map<String, dynamic>) {
              print(
                  '⚠️ Converting store data type: ${safeOrderData['store'].runtimeType}');
              safeOrderData['store'] =
                  _safeMapConversion(safeOrderData['store']);
            }
          }

          // Validasi driver data
          if (safeOrderData['driver'] != null) {
            if (safeOrderData['driver'] is! Map<String, dynamic>) {
              print(
                  '⚠️ Converting driver data type: ${safeOrderData['driver'].runtimeType}');
              safeOrderData['driver'] =
                  _safeMapConversion(safeOrderData['driver']);
            }
          }

          // Validasi items data
          if (safeOrderData['items'] != null) {
            if (safeOrderData['items'] is! List) {
              if (safeOrderData['items'] is String) {
                try {
                  safeOrderData['items'] = jsonDecode(safeOrderData['items']);
                } catch (e) {
                  print('⚠️ Failed to parse items JSON: $e');
                  safeOrderData['items'] = [];
                }
              } else {
                print(
                    '⚠️ Converting items to list from: ${safeOrderData['items'].runtimeType}');
                safeOrderData['items'] = [];
              }
            }
          }

          // ✅ Create OrderModel dengan data yang sudah aman
          _orderDetail = OrderModel.fromJson(safeOrderData);

          print(
              '✅ HistoryStoreDetail: Order data loaded ${forceRefresh ? 'with FORCE REFRESH' : 'efficiently'}');
          print('   - Order ID: ${_orderDetail!.id}');
          print('   - Order Status: ${_orderDetail!.orderStatus.name}');
          print('   - Delivery Status: ${_orderDetail!.deliveryStatus?.name}');
          print('   - Customer: ${_orderDetail!.customer?.name}');
          print('   - Driver ID: ${_orderDetail?.driverId}');
          print('   - Items count: ${_orderDetail!.items.length}');
          // ✅ PERBAIKAN: Gunakan null-safe operator
          print(
              '   - Tracking updates: ${_orderDetail!.trackingUpdates?.length ?? 0}');

          // ✅ Start status tracking if order is not completed
          if (!_orderDetail!.orderStatus.isCompleted) {
            _startStatusTracking();
          }

          _handleInitialStatus(_orderDetail!.orderStatus);
          _previousStatus = _orderDetail!.orderStatus;
          // ✅ TAMBAH: Set initial delivery status
          _previousDeliveryStatus = _orderDetail?.deliveryStatus;
        } catch (orderModelError) {
          print('❌ Error creating OrderModel: $orderModelError');
          print('   Safe order data keys: ${safeOrderData.keys.toList()}');

          // ✅ Debug setiap field yang bermasalah
          safeOrderData.forEach((key, value) {
            print(
                '   - $key: ${value.runtimeType} = ${value.toString().length > 100 ? '${value.toString().substring(0, 100)}...' : value.toString()}');
          });

          throw Exception('Failed to create OrderModel: $orderModelError');
        }
      } else {
        throw Exception('Order not found or empty response');
      }
    } catch (e) {
      print('❌ HistoryStoreDetail: Error loading order data: $e');
      print('   Stack trace: ${StackTrace.current}');
      throw Exception('Failed to load order: $e');
    }
  }

// ✅ PERBAIKAN: Enhanced status tracking dengan null-safe operators
  // GANTI method _startStatusTracking() yang ada dengan ini:
  void _startStatusTracking() {
    if (_orderDetail == null || _orderDetail!.orderStatus.isCompleted) {
      print(
          '⚠️ HistoryStoreDetail: Order is completed, skipping status tracking');
      return;
    }

    print(
        '🔄 HistoryStoreDetail: Starting SMART status tracking for order ${_orderDetail!.id}');

    _statusUpdateTimer =
        Timer.periodic(const Duration(seconds: 15), (timer) async {
      if (!mounted) {
        print('⚠️ HistoryStoreDetail: Widget unmounted, stopping timer');
        timer.cancel();
        return;
      }

      try {
        print('📡 HistoryStoreDetail: Checking order status update...');

        final isAuthenticated = await AuthService.isAuthenticated();
        if (!isAuthenticated) {
          print(
              '❌ HistoryStoreDetail: User not authenticated, stopping tracking');
          timer.cancel();
          return;
        }

        final hasValidSession = await AuthService.ensureValidUserData();
        if (!hasValidSession) {
          print('❌ HistoryStoreDetail: Invalid session, stopping tracking');
          timer.cancel();
          return;
        }

        // ✅ SMART: Hanya refresh saat tracking, bukan force refresh
        final rawUpdatedOrderData = await OrderService.getOrderByIdSmart(
            widget.orderId,
            forceRefresh: false);

        // ✅ Process tracking data before safe conversion
        Map<String, dynamic> processedData =
            Map<String, dynamic>.from(rawUpdatedOrderData);
        if (processedData.containsKey('tracking_updates')) {
          final trackingData = processedData['tracking_updates'];
          final processedTracking = _safeTrackingConversion(trackingData);
          processedData['tracking_updates'] = processedTracking;
        }

        final safeUpdatedOrderData = _safeMapConversion(processedData);
        final updatedOrder = OrderModel.fromJson(safeUpdatedOrderData);

        if (mounted) {
          final statusChanged = _previousStatus != updatedOrder.orderStatus;
          final deliveryChanged =
              _previousDeliveryStatus != updatedOrder.deliveryStatus;

          print('✅ HistoryStoreDetail: Smart tracking check');
          print('   - Previous Order Status: ${_previousStatus?.name}');
          print('   - Current Order Status: ${updatedOrder.orderStatus.name}');
          print(
              '   - Previous Delivery Status: ${_previousDeliveryStatus?.name}');
          print(
              '   - Current Delivery Status: ${updatedOrder.deliveryStatus?.name}');
          print('   - Status Changed: $statusChanged');
          print('   - Delivery Changed: $deliveryChanged');
          print(
              '   - Tracking updates: ${updatedOrder.trackingUpdates?.length ?? 0}');

          setState(() {
            _orderDetail = updatedOrder;
          });

          if (statusChanged) {
            _handleStatusChange(_previousStatus, updatedOrder.orderStatus);
            _previousStatus = updatedOrder.orderStatus;
          }

          if (deliveryChanged) {
            _previousDeliveryStatus = updatedOrder.deliveryStatus;
          }

          if (updatedOrder.orderStatus.isCompleted) {
            print('✅ HistoryStoreDetail: Order completed, stopping tracking');
            timer.cancel();
          }
        }
      } catch (e) {
        print('❌ HistoryStoreDetail: Error updating order status: $e');
        // Don't stop tracking on temporary errors, but log them
      }
    });
  }

  // ✅ NEW: Handle status change notifications and animations
  void _handleStatusChange(OrderStatus? previousStatus, OrderStatus newStatus) {
    String? notification;

    switch (newStatus) {
      case OrderStatus.confirmed:
        notification = 'Pesanan telah dikonfirmasi.';
        break;
      case OrderStatus.preparing:
        notification = 'Pesanan sedang dipersiapkan.';
        break;
      case OrderStatus.readyForPickup:
        notification = 'Pesanan siap untuk diambil driver.';
        break;
      case OrderStatus.onDelivery:
        notification = 'Pesanan sedang diantar.';
        break;
      case OrderStatus.delivered:
        notification = 'Pesanan telah selesai diantar.';
        break;
      case OrderStatus.cancelled:
        notification = 'Pesanan telah dibatalkan.';
        break;
      case OrderStatus.rejected:
        notification = 'Pesanan telah ditolak.';
        break;
      default:
        break;
    }

    // Handle pulse animation
    if ([OrderStatus.cancelled, OrderStatus.rejected].contains(newStatus)) {
      _playCancelSound();
      _pulseController.stop();
    } else {
      _playStatusChangeSound();
      if (newStatus == OrderStatus.pending) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
      }
    }

    if (notification != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(notification),
          backgroundColor: newStatus.isCompleted
              ? (newStatus == OrderStatus.delivered ? Colors.green : Colors.red)
              : GlobalStyle.primaryColor,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _handleInitialStatus(OrderStatus status) {
    if ([OrderStatus.cancelled, OrderStatus.rejected].contains(status)) {
      _playCancelSound();
    } else if (status == OrderStatus.pending) {
      _pulseController.repeat(reverse: true);
    }
    _previousDeliveryStatus = _orderDetail?.deliveryStatus;
  }

  void _playStatusChangeSound() async {
    try {
      await _audioPlayer.play(AssetSource('audio/kring.mp3'));
    } catch (e) {
      print('Error playing status change sound: $e');
    }
  }

  void _playCancelSound() async {
    try {
      await _audioPlayer.play(AssetSource('audio/wrong.mp3'));
    } catch (e) {
      print('Error playing cancel sound: $e');
    }
  }

// UPDATE _refreshOrderData:
  Future<void> _refreshOrderData() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      print('🔄 HistoryStoreDetail: MANUAL smart refresh triggered');
      // ✅ Manual refresh selalu force refresh
      await _loadOrderDataSmart(forceRefresh: true);
      print('✅ HistoryStoreDetail: Manual smart refresh completed');
    } catch (e) {
      // Error handling sama
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  void _startAnimations() {
    // Start status animation
    _statusController.forward();

    // Start card animations sequentially
    Future.delayed(const Duration(milliseconds: 200), () {
      for (int i = 0; i < _cardControllers.length; i++) {
        Future.delayed(Duration(milliseconds: i * 100), () {
          if (mounted) _cardControllers[i].forward();
        });
      }
    });
  }

  // Helper methods for UI components
  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Menunggu Konfirmasi';
      case OrderStatus.confirmed:
        return 'Dikonfirmasi';
      case OrderStatus.preparing:
        return 'Sedang Disiapkan';
      case OrderStatus.readyForPickup:
        return 'Siap Diambil';
      case OrderStatus.onDelivery:
        return 'Sedang Diantar';
      case OrderStatus.delivered:
        return 'Selesai';
      case OrderStatus.cancelled:
        return 'Dibatalkan';
      case OrderStatus.rejected:
        return 'Ditolak';
      default:
        return 'Status Tidak Diketahui';
    }
  }

// ✅ PERBAIKAN 6: Update _getStatusColor() sesuai enum yang baru
  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.confirmed:
        return Colors.blue;
      case OrderStatus.preparing:
        return Colors.indigo;
      case OrderStatus.readyForPickup:
        return Colors.purple;
      case OrderStatus.onDelivery:
        return Colors.teal;
      case OrderStatus.delivered:
        return Colors.green;
      case OrderStatus.cancelled:
        return Colors.red;
      case OrderStatus.rejected:
        return Colors.red[800]!;
      default:
        return Colors.grey;
    }
  }

  Widget _buildCard({required Widget child, required int index}) {
    return SlideTransition(
      position: index < _cardAnimations.length
          ? _cardAnimations[index]
          : const AlwaysStoppedAnimation(Offset.zero),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: child,
      ),
    );
  }

  // ✅ INTEGRATED STORE ORDER STATUS CARD: Built directly into the page
  Widget _buildStoreOrderStatusCard() {
    if (_orderDetail == null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Center(
          child: Column(
            children: [
              Lottie.asset(
                'assets/animations/diambil.json',
                height: 100,
                width: 100,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.shopping_bag,
                    size: 100,
                    color: Colors.grey[400],
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Memuat status pesanan toko...',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontFamily: GlobalStyle.fontFamily,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final currentStatusInfo = _getCurrentStatusInfo();
    final currentStatus = _orderDetail!.orderStatus;
    final currentIndex = _getCurrentStatusIndex();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_primaryColor, _secondaryColor],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.store,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Status Pesanan Toko',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                        Text(
                          'Order #${_orderDetail!.id}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _orderDetail!.formatTotalAmount(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: GlobalStyle.fontFamily,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Animation
                  if (currentStatus == OrderStatus.pending)
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            height: 180,
                            child: Lottie.asset(
                              currentStatusInfo['animation'],
                              repeat: true,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  currentStatusInfo['icon'],
                                  size: 100,
                                  color: currentStatusInfo['color'],
                                );
                              },
                            ),
                          ),
                        );
                      },
                    )
                  else
                    Container(
                      height: 180,
                      child: Lottie.asset(
                        currentStatusInfo['animation'],
                        repeat: ![
                          OrderStatus.delivered,
                          OrderStatus.cancelled,
                          OrderStatus.rejected
                        ].contains(currentStatus),
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            currentStatusInfo['icon'],
                            size: 100,
                            color: currentStatusInfo['color'],
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 20),

                  // ✅ FIXED: Status Timeline with overflow handling (same fix as customer)
                  if (![OrderStatus.cancelled, OrderStatus.rejected]
                      .contains(currentStatus))
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5), // ✅ Reduced padding
                      child: Column(
                        children: [
                          // Icons and connectors row
                          Row(
                            children:
                                List.generate(_statusTimeline.length, (index) {
                              final isActive = index <= currentIndex;
                              final isCurrent = index == currentIndex;
                              final isLast =
                                  index == _statusTimeline.length - 1;
                              final statusItem = _statusTimeline[index];

                              return Expanded(
                                child: Row(
                                  children: [
                                    // ✅ FIXED: Centered icon without text
                                    Expanded(
                                      child: Center(
                                        child: AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 300),
                                          width: isCurrent
                                              ? 28
                                              : 20, // ✅ Slightly smaller
                                          height: isCurrent
                                              ? 28
                                              : 20, // ✅ Slightly smaller
                                          decoration: BoxDecoration(
                                            color: isActive
                                                ? statusItem['color']
                                                : Colors.grey[300],
                                            shape: BoxShape.circle,
                                            boxShadow: isCurrent
                                                ? [
                                                    BoxShadow(
                                                      color: statusItem['color']
                                                          .withOpacity(0.4),
                                                      blurRadius:
                                                          6, // ✅ Reduced shadow
                                                      spreadRadius:
                                                          1, // ✅ Reduced shadow
                                                    ),
                                                  ]
                                                : [],
                                          ),
                                          child: Icon(
                                            statusItem['icon'],
                                            color: Colors.white,
                                            size: isCurrent
                                                ? 14
                                                : 10, // ✅ Smaller icons
                                          ),
                                        ),
                                      ),
                                    ),
                                    // ✅ FIXED: Connector line
                                    if (!isLast)
                                      Container(
                                        width: 20, // ✅ Fixed width connector
                                        height: 2,
                                        decoration: BoxDecoration(
                                          color: index < currentIndex
                                              ? _statusTimeline[index]['color']
                                              : Colors.grey[300],
                                          borderRadius:
                                              BorderRadius.circular(1),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }),
                          ),

                          const SizedBox(
                              height: 8), // ✅ Space between icons and labels

                          // ✅ FIXED: Labels row with proper overflow handling
                          Row(
                            children:
                                List.generate(_statusTimeline.length, (index) {
                              final isActive = index <= currentIndex;
                              final isCurrent = index == currentIndex;
                              final statusItem = _statusTimeline[index];

                              return Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 2), // ✅ Minimal padding
                                  child: Text(
                                    statusItem['label'],
                                    style: TextStyle(
                                      fontSize: 9, // ✅ Smaller font
                                      color: isActive
                                          ? statusItem['color']
                                          : Colors.grey,
                                      fontWeight: isCurrent
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      fontFamily: GlobalStyle.fontFamily,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2, // ✅ Allow 2 lines
                                    overflow: TextOverflow
                                        .ellipsis, // ✅ Handle overflow
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),

                  // Status Message
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          currentStatusInfo['color'].withOpacity(0.1),
                          currentStatusInfo['color'].withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: currentStatusInfo['color'].withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          currentStatusInfo['label'],
                          style: TextStyle(
                            color: currentStatusInfo['color'],
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentStatusInfo['description'],
                          style: TextStyle(
                            color: currentStatusInfo['color'].withOpacity(0.8),
                            fontSize: 14,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  // Customer info (different from customer card - shows customer instead of store)
                  if (_orderDetail!.customer != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: ImageService.displayImage(
                                imageSource:
                                    _orderDetail!.customer!.avatar ?? '',
                                width: 32,
                                height: 32,
                                fit: BoxFit.cover,
                                placeholder: Container(
                                  width: 32,
                                  height: 32,
                                  color: Colors.grey[300],
                                  child: Icon(Icons.person,
                                      color: Colors.grey[600], size: 18),
                                ),
                                errorWidget: Container(
                                  width: 32,
                                  height: 32,
                                  color: Colors.grey[300],
                                  child: Icon(Icons.person,
                                      color: Colors.grey[600], size: 18),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _orderDetail!.customer!.name,
                                    style: TextStyle(
                                      color: Colors.grey[800],
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: GlobalStyle.fontFamily,
                                    ),
                                    maxLines: 1, // ✅ Limit text overflow
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    _orderDetail!.customer!.phone,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                      fontFamily: GlobalStyle.fontFamily,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.phone,
                                size: 16, color: Colors.grey[600]),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _getCurrentStatusInfo() {
    if (_orderDetail == null) {
      return _statusTimeline[0];
    }

    final currentStatus = _orderDetail!.orderStatus;
    final deliveryStatus = _orderDetail!.deliveryStatus;

    print('🔍 HistoryStoreDetail: Getting status info');
    print('   - Order Status: ${currentStatus.name}');
    print('   - Delivery Status: ${deliveryStatus?.name}');

    // ✅ Handle cancelled/rejected status
    if (currentStatus == OrderStatus.cancelled) {
      return {
        'status': OrderStatus.cancelled,
        'label': 'Dibatalkan',
        'description': 'Pesanan dibatalkan',
        'icon': Icons.cancel_outlined,
        'color': Colors.red,
        'animation': 'assets/animations/cancel.json'
      };
    }

    if (currentStatus == OrderStatus.rejected) {
      return {
        'status': OrderStatus.rejected,
        'label': 'Ditolak',
        'description': 'Pesanan ditolak',
        'icon': Icons.block,
        'color': Colors.red,
        'animation': 'assets/animations/cancel.json'
      };
    }

    switch (currentStatus) {
      case OrderStatus.pending:
        return _statusTimeline[0]; // Menunggu

      case OrderStatus.preparing:
        // ✅ TAMBAHAN: Cek delivery status untuk detail description
        if (deliveryStatus == DeliveryStatus.pickedUp) {
          return {
            ..._statusTimeline[1], // Disiapkan
            'description': 'Pesanan telah diambil driver, siap untuk diproses',
          };
        } else {
          return {
            ..._statusTimeline[1], // Disiapkan
            'description': 'Menunggu driver mengambil pesanan',
          };
        }

      case OrderStatus.readyForPickup:
        return _statusTimeline[2]; // Siap Diambil

      case OrderStatus.onDelivery:
        return _statusTimeline[3]; // Diantar

      case OrderStatus.delivered:
        return _statusTimeline[4]; // Selesai

      default:
        return _statusTimeline[0];
    }
  }

// Di file HistoryStoreDetailPage, GANTI method _getCurrentStatusIndex():
  int _getCurrentStatusIndex() {
    if (_orderDetail == null) return 0;

    final currentStatus = _orderDetail!.orderStatus;
    final deliveryStatus = _orderDetail!.deliveryStatus;

    print('🔍 HistoryStoreDetail: Getting status index');
    print('   - Order Status: ${currentStatus.name}');
    print('   - Delivery Status: ${deliveryStatus?.name}');

    // ✅ Handle cancelled/rejected (tidak masuk timeline)
    if ([OrderStatus.cancelled, OrderStatus.rejected].contains(currentStatus)) {
      return -1; // Tidak ada di timeline
    }

    // ✅ PERBAIKAN: Logic mapping status ke timeline index (tanpa confirmed)
    switch (currentStatus) {
      case OrderStatus.pending:
        return 0;
      case OrderStatus.preparing:
        return 1; // ✅ Index 1 (tidak ada confirmed)
      case OrderStatus.readyForPickup:
        return 2; // ✅ Index 2
      case OrderStatus.onDelivery:
        return 3; // ✅ Index 3
      case OrderStatus.delivered:
        return 4; // ✅ Index 4
      default:
        return 0;
    }
  }

  Widget _buildCustomerInfoCard() {
    final customer = _orderDetail!.customer;
    if (customer == null) return const SizedBox.shrink();

    return _buildCard(
      index: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        GlobalStyle.primaryColor,
                        GlobalStyle.primaryColor.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Informasi Customer',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: GlobalStyle.fontFamily,
                    color: GlobalStyle.fontColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        GlobalStyle.primaryColor.withOpacity(0.1),
                        GlobalStyle.primaryColor.withOpacity(0.05),
                      ],
                    ),
                    border: Border.all(
                      color: GlobalStyle.primaryColor.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: ImageService.displayImage(
                      imageSource: customer.avatar ?? '',
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      placeholder: Icon(
                        Icons.person,
                        size: 30,
                        color: GlobalStyle.primaryColor,
                      ),
                      errorWidget: Icon(
                        Icons.person,
                        size: 30,
                        color: GlobalStyle.primaryColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: GlobalStyle.fontColor,
                          fontFamily: GlobalStyle.fontFamily,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (customer.phone.isNotEmpty)
                        Row(
                          children: [
                            Icon(
                              Icons.phone,
                              color: Colors.grey[600],
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              customer.phone,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
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
            if (customer.phone.isNotEmpty) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
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
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _callCustomer(customer.phone),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.call, color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Hubungi',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: GlobalStyle.fontFamily,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF25D366).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _openWhatsApp(customer.phone),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.message,
                                  color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'WhatsApp',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: GlobalStyle.fontFamily,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDriverInfoCard() {
    final driver = _orderDetail!.driver;
    final orderStatus = _orderDetail!.orderStatus;

    // Only show driver info if driver is assigned and order is in delivery phase
    if (driver == null ||
        !['ready_for_pickup', 'on_delivery', 'delivered']
            .contains(orderStatus.name)) {
      return const SizedBox.shrink();
    }

    return _buildCard(
      index: 1,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue, Colors.blue.withOpacity(0.8)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.drive_eta,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Informasi Driver',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Colors.blue.withOpacity(0.1),
                        Colors.blue.withOpacity(0.05),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: ImageService.displayImage(
                      imageSource: driver.avatar ?? '',
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      placeholder: Icon(
                        Icons.person,
                        size: 30,
                        color: Colors.blue,
                      ),
                      errorWidget: Icon(
                        Icons.person,
                        size: 30,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driver.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: GlobalStyle.fontColor,
                          fontFamily: GlobalStyle.fontFamily,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (driver.vehiclePlate.isNotEmpty)
                        Row(
                          children: [
                            Icon(
                              Icons.directions_car,
                              color: Colors.grey[600],
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Plat: ${driver.vehiclePlate}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                                fontFamily: GlobalStyle.fontFamily,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                if (driver.phone.isNotEmpty)
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.chat,
                        color: const Color(0xFF25D366),
                      ),
                      onPressed: () => _openWhatsApp(driver.phone),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsCard() {
    final orderItems = _orderDetail!.items;
    final totalAmount = _orderDetail!.totalAmount;
    final deliveryFee = _orderDetail!.deliveryFee;
    final subtotal = totalAmount - deliveryFee;

    if (orderItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return _buildCard(
      index: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green, Colors.green.withOpacity(0.8)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.shopping_bag,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Detail Pesanan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...orderItems.map<Widget>((item) {
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: ImageService.displayImage(
                        imageSource: item.imageUrl ?? '',
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        placeholder: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.fastfood,
                            color: Colors.grey[600],
                          ),
                        ),
                        errorWidget: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.fastfood,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              fontFamily: GlobalStyle.fontFamily,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            GlobalStyle.formatRupiah(item.price),
                            style: TextStyle(
                              color: GlobalStyle.primaryColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: GlobalStyle.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'x${item.quantity}',
                            style: TextStyle(
                              color: GlobalStyle.primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.formatTotalPrice(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: GlobalStyle.fontColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 16),
              height: 1,
              color: Colors.grey.shade300,
            ),
            _buildPaymentRow('Subtotal', subtotal),
            const SizedBox(height: 12),
            _buildPaymentRow('Biaya Pengiriman', deliveryFee),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 16),
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    GlobalStyle.primaryColor,
                    GlobalStyle.primaryColor.withOpacity(0.3),
                  ],
                ),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            _buildPaymentRow('Total Pembayaran', totalAmount, isTotal: true),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentRow(String label, double amount, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            fontSize: isTotal ? 18 : 15,
            color: isTotal ? GlobalStyle.fontColor : Colors.grey.shade700,
            fontFamily: GlobalStyle.fontFamily,
          ),
        ),
        Text(
          GlobalStyle.formatRupiah(amount),
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
            fontSize: isTotal ? 18 : 15,
            color: isTotal ? GlobalStyle.primaryColor : GlobalStyle.fontColor,
            fontFamily: GlobalStyle.fontFamily,
          ),
        ),
      ],
    );
  }

// Di file HistoryStoreDetailPage, GANTI method _buildActionButtons():

// ✅ PERBAIKAN: Method _buildActionButtons() sesuai alur yang benar
  Widget _buildActionButtons() {
    final orderStatus = _orderDetail!.orderStatus;
    final deliveryStatus = _orderDetail!.deliveryStatus;

    print(
        '🔍 Action Buttons for status: ${orderStatus.name}, delivery: ${deliveryStatus?.name}');

    switch (orderStatus) {
      case OrderStatus.pending:
        // Tombol approve/reject untuk status pending (sama seperti sebelumnya)
        return _buildCard(
          index: 3,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.red, Color(0xFFF44336)],
                    ),
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
                      onTap: _isUpdatingStatus
                          ? null
                          : () => _processOrder('reject'),
                      child: Center(
                        child: Icon(Icons.close, color: Colors.white, size: 24),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.green, Color(0xFF4CAF50)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _isUpdatingStatus
                            ? null
                            : () => _processOrder('approve'),
                        child: Center(
                          child: _isUpdatingStatus
                              ? SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : Text(
                                  'Terima Pesanan',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    fontFamily: GlobalStyle.fontFamily,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

      case OrderStatus.preparing:
        // ✅ PERBAIKAN: Cek delivery status picked_up dulu
        final canMarkReady = deliveryStatus == DeliveryStatus.pickedUp;

        return _buildCard(
          index: 3,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: canMarkReady
                      ? [Colors.purple, Colors.purple.withOpacity(0.8)]
                      : [
                          Colors.grey[400]!,
                          Colors.grey[500]!
                        ], // Disabled state
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: canMarkReady
                    ? [
                        BoxShadow(
                          color: Colors.purple.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : [],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: (_isUpdatingStatus || !canMarkReady)
                      ? null
                      : () {
                          print(
                              '🔄 Button clicked: Updating to ready_for_pickup');
                          _updateOrderStatus(OrderStatus.readyForPickup);
                        },
                  child: Center(
                    child: _isUpdatingStatus
                        ? SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (!canMarkReady) ...[
                                Icon(Icons.access_time,
                                    color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                              ],
                              Text(
                                canMarkReady
                                    ? 'Siap Diambil'
                                    : 'Menunggu Driver Ambil',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  fontFamily: GlobalStyle.fontFamily,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        );

      case OrderStatus.readyForPickup:
        // Menunggu driver (tidak ada button action)
        return _buildCard(
          index: 3,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange, Colors.orange.withOpacity(0.8)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Menunggu Driver',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        fontFamily: GlobalStyle.fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

      case OrderStatus.onDelivery:
        // Sedang diantar (tidak ada button)
        return _buildCard(
          index: 3,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal, Colors.teal.withOpacity(0.8)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.local_shipping, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'Sedang Diantar',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        fontFamily: GlobalStyle.fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

      default:
        // Untuk delivered, cancelled, rejected - tidak ada tombol
        return const SizedBox.shrink();
    }
  }

  // ✅ FIXED: Enhanced order processing using OrderService.processOrderByStore
// GANTI method _processOrder() yang ada dengan ini:
  Future<void> _processOrder(String action) async {
    if (_isUpdatingStatus) return;

    setState(() {
      _isUpdatingStatus = true;
    });

    try {
      print('⚙️ HistoryStoreDetail: Processing order with action: $action');

      // ✅ FIXED: Enhanced authentication check
      final isAuthenticated = await AuthService.isAuthenticated();
      if (!isAuthenticated) {
        throw Exception('User not authenticated');
      }

      final userData = await AuthService.getUserData();
      final roleData = await AuthService.getRoleSpecificData();

      if (userData == null || roleData == null) {
        throw Exception('Unable to retrieve authentication data');
      }

      // ✅ FIXED: Process order using OrderService.processOrderByStore
      await OrderService.processOrderByStore(
        orderId: widget.orderId,
        action: action, // 'approve' atau 'reject'
        rejectionReason: action == 'reject'
            ? 'Toko tidak dapat memproses pesanan saat ini'
            : null,
      );

      // ✅ SMART REFRESH: Force refresh setelah process order
      await _loadOrderDataSmart(forceRefresh: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == 'approve'
                  ? 'Pesanan berhasil diterima dan sedang disiapkan' // ✅ PERBAIKI pesan
                  : 'Pesanan berhasil ditolak',
            ),
            backgroundColor: action == 'approve' ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }

      print('✅ HistoryStoreDetail: Order processed successfully');
    } catch (e) {
      print('❌ HistoryStoreDetail: Error processing order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memproses pesanan: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      setState(() {
        _isUpdatingStatus = false;
      });
    }
  }

  // ✅ FIXED: Enhanced status update using OrderService.updateOrderStatus
  Future<void> _updateOrderStatus(OrderStatus status) async {
    // ✅ TAMBAHKAN debug info di awal
    print('🔍 Debug Info:');
    print('   - Current Order Status: ${_orderDetail?.orderStatus.name}');
    print('   - Target Status: ${status.name} (${status.value})');
    print('   - Order ID: ${widget.orderId}');
    print('   - User Role: ${await AuthService.getUserRole()}');

    if (_isUpdatingStatus) return;

    setState(() {
      _isUpdatingStatus = true;
    });

    try {
      print('📝 HistoryStoreDetail: Updating order status to: ${status.name}');

      // Enhanced authentication check
      final isAuthenticated = await AuthService.isAuthenticated();
      if (!isAuthenticated) {
        throw Exception('User not authenticated');
      }

      // ✅ PERBAIKI: Call the correct API endpoint dengan value yang benar
      final response = await OrderService.updateOrderStatus(
        orderId: widget.orderId,
        orderStatus: status.value, // Gunakan .value instead of .name
        notes: 'Status diupdate oleh toko',
      );

      print('✅ Response from API: $response');

      // ✅ SMART REFRESH: Hanya refresh setelah berhasil update
      await _loadOrderDataSmart(forceRefresh: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Status pesanan berhasil diupdate ke ${_getStatusText(status)}'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }

      print('✅ HistoryStoreDetail: Order status updated successfully');
    } catch (e) {
      print('❌ HistoryStoreDetail: Error updating status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengupdate status: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingStatus = false;
        });
      }
    }
  }

  Future<void> _callCustomer(String phoneNumber) async {
    if (phoneNumber.isEmpty) return;

    String cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '+62${cleanPhone.substring(1)}';
    } else if (!cleanPhone.startsWith('+')) {
      cleanPhone = '+62$cleanPhone';
    }

    final url = 'tel:$cleanPhone';
    try {
      if (await canLaunch(url)) {
        await launch(url);
      } else {
        throw Exception('Cannot launch phone dialer');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tidak dapat melakukan panggilan: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _openWhatsApp(String phoneNumber) async {
    if (phoneNumber.isEmpty) return;

    String cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '62${cleanPhone.substring(1)}';
    } else if (cleanPhone.startsWith('+62')) {
      cleanPhone = cleanPhone.substring(1);
    } else if (!cleanPhone.startsWith('62')) {
      cleanPhone = '62$cleanPhone';
    }

    final storeName = _storeData?['name'] ?? 'Toko';
    final orderId = widget.orderId;
    final message =
        'Halo! Saya dari $storeName mengenai pesanan #$orderId Anda. Apakah ada yang bisa saya bantu?';
    final encodedMessage = Uri.encodeComponent(message);
    final url = 'https://wa.me/$cleanPhone?text=$encodedMessage';

    try {
      if (await canLaunch(url)) {
        await launch(url);
      } else {
        throw Exception('Cannot launch WhatsApp');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tidak dapat membuka WhatsApp: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xffF8FAFE),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          title: Text(
            'Detail Pesanan',
            style: TextStyle(
              color: GlobalStyle.fontColor,
              fontWeight: FontWeight.bold,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: GlobalStyle.primaryColor, width: 1.5),
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: GlobalStyle.primaryColor,
                size: 16,
              ),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: GlobalStyle.primaryColor),
              const SizedBox(height: 16),
              Text(
                'Memuat detail pesanan...',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 16,
                  fontFamily: GlobalStyle.fontFamily,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_hasError) {
      return Scaffold(
        backgroundColor: const Color(0xffF8FAFE),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          title: Text(
            'Detail Pesanan',
            style: TextStyle(
              color: GlobalStyle.fontColor,
              fontWeight: FontWeight.bold,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: GlobalStyle.primaryColor, width: 1.5),
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: GlobalStyle.primaryColor,
                size: 16,
              ),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 80,
                  color: Colors.red[300],
                ),
                const SizedBox(height: 24),
                Text(
                  'Terjadi Kesalahan',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: GlobalStyle.fontColor,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _validateAndLoadData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlobalStyle.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
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
          ),
        ),
      );
    }

    final isCompleted = _orderDetail!.orderStatus.isCompleted;

    return Scaffold(
      backgroundColor: const Color(0xffF8FAFE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text(
          'Detail Pesanan',
          style: TextStyle(
            color: GlobalStyle.fontColor,
            fontWeight: FontWeight.bold,
            fontFamily: GlobalStyle.fontFamily,
          ),
        ),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: GlobalStyle.primaryColor, width: 1.5),
            ),
            child: Icon(
              Icons.arrow_back_ios_new,
              color: GlobalStyle.primaryColor,
              size: 16,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isRefreshing
                  ? GlobalStyle.primaryColor.withOpacity(0.1)
                  : GlobalStyle.primaryColor.withOpacity(0.1),
            ),
            child: IconButton(
              icon: _isRefreshing
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: GlobalStyle.primaryColor,
                      ),
                    )
                  : Icon(
                      Icons.refresh,
                      color: GlobalStyle.primaryColor,
                    ),
              onPressed: _isRefreshing ? null : _refreshOrderData,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshOrderData,
        color: GlobalStyle.primaryColor,
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ INTEGRATED: Store Order Status Card directly built in
                  SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, -0.3),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: _statusController,
                      curve: Curves.easeOutCubic,
                    )),
                    child: FadeTransition(
                      opacity: _statusController,
                      child: _buildStoreOrderStatusCard(),
                    ),
                  ),

                  const SizedBox(height: 16),
                  _buildCustomerInfoCard(),
                  _buildDriverInfoCard(),
                  _buildItemsCard(),
                  if (!isCompleted) _buildActionButtons(),
                  const SizedBox(height: 100), // Bottom padding
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
