import 'package:flutter/material.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lottie/lottie.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';

// Import Models
import 'package:del_pick/Models/order.dart';
import 'package:del_pick/Models/driver.dart';
import 'package:del_pick/Models/store.dart';
import 'package:del_pick/Models/menu_item.dart';
import 'package:del_pick/Models/order_enum.dart';
import 'package:del_pick/Models/order_item.dart';

// Import Services - Updated
import 'package:del_pick/Services/order_service.dart';
import 'package:del_pick/Services/image_service.dart';
import 'package:del_pick/Services/auth_service.dart';

// Import Components
import '../../Utils/timezone_helper.dart';
import 'rating_cust.dart';
import 'home_cust.dart';

class HistoryDetailPage extends StatefulWidget {
  static const String route = "/Customers/HistoryDetailPage";

  final OrderModel order;

  const HistoryDetailPage({
    Key? key,
    required this.order,
  }) : super(key: key);

  @override
  State<HistoryDetailPage> createState() => _HistoryDetailPageState();
}

class _HistoryDetailPageState extends State<HistoryDetailPage>
    with TickerProviderStateMixin {
  // Animation controllers
  late List<AnimationController> _cardControllers;
  late List<Animation<Offset>> _cardAnimations;
  late AnimationController _driverCardController;
  late AnimationController _reviewCardController;
  late Animation<Offset> _driverCardAnimation;
  late Animation<Offset> _reviewCardAnimation;

  // Order Status Card Animation Controllers
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final AudioPlayer _audioPlayer = AudioPlayer();

  // State variables
  bool _isLoading = false;
  bool _isLoadingOrderDetail = false;
  bool _isCancelling = false;
  bool _isSubmittingRating = false;
  String? _errorMessage;

  // Data objects - Updated structure
  OrderModel? _orderDetail;
  Map<String, dynamic>? _customerData;
  Map<String, dynamic>? _roleSpecificData;

  // Review tracking
  Map<String, dynamic>? _orderReviews;
  Map<String, dynamic>? _driverReviews;
  bool _hasGivenRating = false;

  // Status tracking
  Timer? _statusUpdateTimer;
  OrderStatus? _previousOrderStatus;
  DeliveryStatus? _previousDeliveryStatus;
  bool _canCancelOrder() {
    if (_orderDetail == null) return false;

    final orderStatus = _orderDetail!.orderStatus;
    final deliveryStatus = _orderDetail!.deliveryStatus;

    print('🔍 Checking if order can be cancelled:');
    print('   - Order Status: ${orderStatus.name}');
    print('   - Delivery Status: ${deliveryStatus.name}');

    // ✅ Hanya bisa cancel jika kedua status masih pending
    final canCancel = orderStatus == OrderStatus.pending &&
        deliveryStatus == DeliveryStatus.pending;

    print('   - Can Cancel: $canCancel');
    return canCancel;
  }

  // Customer-specific color theme for status card
  final Color _primaryColor = const Color(0xFF4A90E2);
  final Color _secondaryColor = const Color(0xFF7BB3F0);

  // ✅ PERBAIKAN: Updated status timeline sesuai alur yang benar
  final List<Map<String, dynamic>> _statusTimeline = [
    {
      'status': 'waiting', // pending + pending
      'label': 'Menunggu',
      'description': 'Menunggu konfirmasi toko dan driver',
      'icon': Icons.hourglass_empty,
      'color': Colors.orange,
      'animation': 'assets/animations/diambil.json'
    },
    {
      'status': 'processing', // preparing + pending ATAU pending + picked_up
      'label': 'Diproses',
      'description': 'Sedang diproses',
      'icon': Icons.sync,
      'color': Colors.blue,
      'animation': 'assets/animations/diproses.json'
    },
    {
      'status': 'preparing', // preparing + picked_up
      'label': 'Disiapkan',
      'description': 'Pesanan sedang disiapkan',
      'icon': Icons.restaurant,
      'color': Colors.purple,
      'animation': 'assets/animations/diproses.json'
    },
    {
      'status': 'ready', // ready_for_pickup + picked_up
      'label': 'Siap Diambil',
      'description': 'Pesanan siap untuk diambil',
      'icon': Icons.shopping_bag,
      'color': Colors.indigo,
      'animation': 'assets/animations/diproses.json'
    },
    {
      'status': 'delivering', // on_delivery + on_way
      'label': 'Diantar',
      'description': 'Pesanan sedang diantar',
      'icon': Icons.delivery_dining,
      'color': Colors.teal,
      'animation': 'assets/animations/diantar.json'
    },
    {
      'status': 'completed', // delivered + delivered
      'label': 'Selesai',
      'description': 'Pesanan telah selesai',
      'icon': Icons.celebration,
      'color': Colors.green,
      'animation': 'assets/animations/pesanan_selesai.json'
    },
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _validateAndLoadData();
    _validateAndLoadDataWithRefresh();
  }

  void _initializeAnimations() {
    // Initialize animation controllers for each card section
    _cardControllers = List.generate(
      6, // Number of card sections
      (index) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 600 + (index * 200)),
      ),
    );

    // Create slide animations for each card
    _cardAnimations = _cardControllers.map((controller) {
      return Tween<Offset>(
        begin: const Offset(0, -0.5),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeOutCubic,
      ));
    }).toList();

    // Initialize specific card animations
    _driverCardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _reviewCardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _driverCardAnimation = Tween<Offset>(
      begin: const Offset(0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _driverCardController,
      curve: Curves.easeOutCubic,
    ));

    _reviewCardAnimation = Tween<Offset>(
      begin: const Offset(0, 1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _reviewCardController,
      curve: Curves.easeOutCubic,
    ));

    // Initialize pulse animation for status card
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Start animations sequentially
    Future.delayed(const Duration(milliseconds: 100), () {
      for (var controller in _cardControllers) {
        controller.forward();
      }
    });
  }

  bool _shouldStartStatusTracking() {
    if (_orderDetail == null) return false;

    final orderStatus = _orderDetail!.orderStatus;
    final deliveryStatus = _orderDetail!.deliveryStatus;

    // ✅ PERBAIKAN: Track semua order yang belum benar-benar selesai
    // Jangan hanya andalkan isCompleted, cek kombinasi status
    final isFinallyCompleted = (orderStatus == OrderStatus.delivered &&
            deliveryStatus == DeliveryStatus.delivered) ||
        orderStatus == OrderStatus.cancelled ||
        orderStatus == OrderStatus.rejected;

    print('🔍 Should start tracking check:');
    print('   - Order Status: ${orderStatus.name}');
    print('   - Delivery Status: ${deliveryStatus.name}');
    print('   - Is Finally Completed: $isFinallyCompleted');
    print('   - Should Track: ${!isFinallyCompleted}');

    return !isFinallyCompleted;
  }

  // Helper methods untuk format waktu WIB
  String _formatOrderDateWIB(DateTime dateTime) {
    try {
      // Convert DateTime ke TZDateTime WIB
      final wibDateTime = TimezoneHelper.utcToWIB(dateTime.toUtc());
      return TimezoneHelper.formatWIBFull(wibDateTime);
    } catch (e) {
      print('Error formatting order date to WIB: $e');
      // Fallback ke format biasa jika error
      return DateFormat('dd MMM yyyy, HH:mm').format(dateTime);
    }
  }

  String _formatTimeWIB(DateTime dateTime) {
    try {
      // Convert DateTime ke TZDateTime WIB
      final wibDateTime = TimezoneHelper.utcToWIB(dateTime.toUtc());
      return TimezoneHelper.formatOrderTime(wibDateTime);
    } catch (e) {
      print('Error formatting time to WIB: $e');
      // Fallback ke format biasa jika error
      return DateFormat('dd MMM yyyy, HH:mm').format(dateTime);
    }
  }

  String _formatTimeShortWIB(DateTime dateTime) {
    try {
      // Convert DateTime ke TZDateTime WIB
      final wibDateTime = TimezoneHelper.utcToWIB(dateTime.toUtc());

      if (TimezoneHelper.isToday(wibDateTime)) {
        return 'Hari ini, ${TimezoneHelper.formatTimeOnly(wibDateTime)} WIB';
      } else if (TimezoneHelper.isYesterday(wibDateTime)) {
        return 'Kemarin, ${TimezoneHelper.formatTimeOnly(wibDateTime)} WIB';
      } else {
        return TimezoneHelper.formatWIB(wibDateTime, pattern: 'dd MMM, HH:mm') +
            ' WIB';
      }
    } catch (e) {
      print('Error formatting short time to WIB: $e');
      return DateFormat('dd MMM, HH:mm').format(dateTime);
    }
  }

  String _getRelativeTimeWIB(DateTime dateTime) {
    try {
      // Convert DateTime ke TZDateTime WIB
      final wibDateTime = TimezoneHelper.utcToWIB(dateTime.toUtc());
      return TimezoneHelper.formatRelativeTime(wibDateTime);
    } catch (e) {
      print('Error formatting relative time to WIB: $e');
      return 'Beberapa waktu lalu';
    }
  }

  @override
  void dispose() {
    for (var controller in _cardControllers) {
      controller.dispose();
    }
    _driverCardController.dispose();
    _reviewCardController.dispose();
    _pulseController.dispose();
    _audioPlayer.dispose();
    _statusUpdateTimer?.cancel();
    super.dispose();
  }

  /// ✅ Safe type conversion for nested maps
  static Map<String, dynamic> _safeMapConversion(dynamic data) {
    if (data == null) return {};

    if (data is Map<String, dynamic>) {
      return data;
    } else if (data is Map) {
      // Convert Map<dynamic, dynamic> to Map<String, dynamic>
      return Map<String, dynamic>.from(data.map((key, value) {
        // Recursively convert nested maps
        if (value is Map && value is! Map<String, dynamic>) {
          value = _safeMapConversion(value);
        } else if (value is List) {
          value = _safeListConversion(value);
        }
        return MapEntry(key.toString(), value);
      }));
    }

    return {};
  }

  /// ✅ Safe type conversion for lists containing maps
  static List<dynamic> _safeListConversion(List<dynamic> list) {
    return list.map((item) {
      if (item is Map && item is! Map<String, dynamic>) {
        return _safeMapConversion(item);
      }
      return item;
    }).toList();
  }

  // ✅ UPDATED: Enhanced authentication and data validation
  Future<void> _validateAndLoadData() async {
    // Fallback ke method yang sudah ada jika force refresh gagal
    try {
      await _validateAndLoadDataWithRefresh();
    } catch (e) {
      print('❌ Force refresh failed, trying regular load: $e');

      // Fallback ke regular validation
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final hasAccess = await AuthService.validateCustomerAccess();
        if (!hasAccess) {
          throw Exception('Access denied: Customer authentication required');
        }

        final userData = await AuthService.getUserData();
        if (userData == null) {
          throw Exception('Unable to retrieve user data');
        }

        _roleSpecificData = await AuthService.getRoleSpecificData();
        if (_roleSpecificData == null) {
          throw Exception('Unable to retrieve role-specific data');
        }

        _customerData = await AuthService.getCustomerData();
        if (_customerData == null) {
          throw Exception('Unable to retrieve customer data');
        }

        print('✅ Fallback: Authentication validated successfully');

        // Try regular load without force refresh
        await _loadOrderDetail();

        setState(() {
          _isLoading = false;
        });
      } catch (fallbackError) {
        print('❌ Fallback also failed: $fallbackError');
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load order details: $fallbackError';
        });
      }
    }
  }

  // ✅ PERBAIKAN 9: Method baru untuk initial load dengan force refresh
  Future<void> _validateAndLoadDataWithRefresh() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print(
          '🔍 HistoryDetailPage: Starting authentication validation with force refresh...');

      // ✅ Step 1: Validate customer access
      final hasAccess = await AuthService.validateCustomerAccess();
      if (!hasAccess) {
        throw Exception('Access denied: Customer authentication required');
      }

      // ✅ Step 2: Get customer data
      final userData = await AuthService.getUserData();
      if (userData == null) {
        throw Exception('Unable to retrieve user data');
      }

      // ✅ Step 3: Get role-specific data
      _roleSpecificData = await AuthService.getRoleSpecificData();
      if (_roleSpecificData == null) {
        throw Exception('Unable to retrieve role-specific data');
      }

      // ✅ Step 4: Get customer-specific data
      _customerData = await AuthService.getCustomerData();
      if (_customerData == null) {
        throw Exception('Unable to retrieve customer data');
      }

      print('✅ HistoryDetailPage: Authentication validated successfully');
      print('   - Customer ID: ${_customerData!['id']}');
      print('   - Customer Name: ${_customerData!['name']}');

      // ✅ Step 5: Force refresh order detail
      await _loadOrderDetailWithForceRefresh();

      setState(() {
        _isLoading = false;
      });

      // Start animations for loaded content
      if (_orderDetail?.driverId != null) {
        _driverCardController.forward();
      }
      if (_orderReviews != null || _driverReviews != null) {
        _reviewCardController.forward();
      }

      // Handle initial status for pulse animation
      if (_orderDetail != null) {
        _handleInitialStatus(_orderDetail!.orderStatus);
      }
    } catch (e) {
      print('❌ HistoryDetailPage: Validation/Load error: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load order details: $e';
      });
    }
  }

  Future<void> _manualRefreshOrder() async {
    try {
      print('🔄 Manual refresh triggered by user');

      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 2,
                ),
              ),
              const SizedBox(width: 12),
              const Text('Memperbarui data pesanan...'),
            ],
          ),
          backgroundColor: GlobalStyle.primaryColor,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );

      await _loadOrderDetailWithForceRefresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                const Text('Data pesanan berhasil diperbarui'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ Manual refresh error: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                const Text('Gagal memperbarui data pesanan'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

// Method khusus untuk force refresh initial load
  Future<void> _loadOrderDetailWithForceRefresh() async {
    setState(() {
      _isLoadingOrderDetail = true;
    });

    try {
      print(
          '🔄 HistoryDetailPage: Force refreshing order detail: ${widget.order.id}');

      // ✅ Clear cache dulu
      OrderService.clearOrderCache(widget.order.id.toString());

      // ✅ Force refresh dengan timestamp untuk bypass cache
      final rawOrderData = await OrderService.getOrderByIdForceRefresh(
        widget.order.id.toString(),
        forceRefresh: true,
      );

      final safeOrderData = _safeMapConversion(rawOrderData);

      print('✅ HistoryDetailPage: Fresh order data loaded');
      print('   - Order Status: ${safeOrderData['order_status']}');
      print('   - Delivery Status: ${safeOrderData['delivery_status']}');
      print('   - Updated At: ${safeOrderData['updated_at']}');

      _orderDetail = OrderModel.fromJson(safeOrderData);

      print('✅ HistoryDetailPage: Order detail refreshed successfully');
      print('   - Order Status: ${_orderDetail!.orderStatus.name}');
      print('   - Delivery Status: ${_orderDetail!.deliveryStatus.name}');

      // ✅ Load reviews
      await _loadOrderReviews(safeOrderData);

      // ✅ Start tracking if needed
      if (_shouldStartStatusTracking()) {
        _startStatusTracking();
      }

      // ✅ Store status for change detection
      _previousOrderStatus = _orderDetail!.orderStatus;
      _previousDeliveryStatus = _orderDetail!.deliveryStatus;
    } catch (e) {
      print('❌ HistoryDetailPage: Error force refreshing order detail: $e');
      throw Exception('Failed to refresh order details: $e');
    } finally {
      setState(() {
        _isLoadingOrderDetail = false;
      });
    }
  }

  // Load order detail with proper type conversion
  Future<void> _loadOrderDetail() async {
    setState(() {
      _isLoadingOrderDetail = true;
    });

    try {
      print('🔍 HistoryDetailPage: Loading order detail: ${widget.order.id}');

      // ✅ PERBAIKAN 1: Selalu gunakan force refresh untuk memastikan data terbaru
      final rawOrderData = await OrderService.getOrderByIdForceRefresh(
        widget.order.id.toString(),
        forceRefresh: true, // ✅ Force refresh setiap kali load
      );

      // ✅ PERBAIKAN 2: Clear cache sebelum load ulang
      OrderService.clearOrderCache(widget.order.id.toString());

      // ✅ Convert all nested maps safely before creating OrderModel
      final safeOrderData = _safeMapConversion(rawOrderData);

      print('✅ HistoryDetailPage: Order data converted safely');
      print('   - Order Status: ${safeOrderData['order_status']}');
      print('   - Delivery Status: ${safeOrderData['delivery_status']}');
      print('   - Updated At: ${safeOrderData['updated_at']}');

      // ✅ Process the order data with enhanced structure and safe conversion
      _orderDetail = OrderModel.fromJson(safeOrderData);

      print('✅ HistoryDetailPage: Order detail loaded successfully');
      print('   - Order Status: ${_orderDetail!.orderStatus.name}');
      print('   - Delivery Status: ${_orderDetail!.deliveryStatus.name}');
      print('   - Driver ID: ${_orderDetail?.driverId}');
      print('   - Items count: ${_orderDetail!.items.length}');

      // ✅ Load reviews data from the order response with safe conversion
      await _loadOrderReviews(safeOrderData);

      // ✅ PERBAIKAN 3: Start status tracking untuk SEMUA order yang bukan final status
      if (_shouldStartStatusTracking()) {
        _startStatusTracking();
      }

      // ✅ Store previous status for change detection
      _previousOrderStatus = _orderDetail!.orderStatus;
      _previousDeliveryStatus = _orderDetail!.deliveryStatus;
    } catch (e) {
      print('❌ HistoryDetailPage: Error loading order detail: $e');
      throw Exception('Failed to load order details: $e');
    } finally {
      setState(() {
        _isLoadingOrderDetail = false;
      });
    }
  }

  // ✅ Enhanced review loading with better structure handling
  Future<void> _loadOrderReviews(Map<String, dynamic> orderData) async {
    try {
      print('🔍 HistoryDetailPage: Loading order reviews...');

      // ✅ Reset review states
      _orderReviews = null;
      _driverReviews = null;
      _hasGivenRating = false;

      // ✅ Check for reviews in order data - multiple possible structures
      if (orderData['orderReviews'] != null) {
        final reviews = orderData['orderReviews'];
        if (reviews is List && reviews.isNotEmpty) {
          _orderReviews = _safeMapConversion(reviews.first);
          print('✅ HistoryDetailPage: Order review found (List structure)');
        } else if (reviews is Map) {
          _orderReviews = _safeMapConversion(reviews);
          print('✅ HistoryDetailPage: Order review found (Map structure)');
        }
      }

      if (orderData['driverReviews'] != null) {
        final reviews = orderData['driverReviews'];
        if (reviews is List && reviews.isNotEmpty) {
          _driverReviews = _safeMapConversion(reviews.first);
          print('✅ HistoryDetailPage: Driver review found (List structure)');
        } else if (reviews is Map) {
          _driverReviews = _safeMapConversion(reviews);
          print('✅ HistoryDetailPage: Driver review found (Map structure)');
        }
      }

      // ✅ Alternative review structure check with safe conversion
      if (orderData['reviews'] != null) {
        final reviews = _safeListConversion(orderData['reviews'] as List);
        for (var reviewData in reviews) {
          final review = _safeMapConversion(reviewData);
          if (review['type'] == 'store' || review['target_type'] == 'store') {
            _orderReviews = review;
          } else if (review['type'] == 'driver' ||
              review['target_type'] == 'driver') {
            _driverReviews = review;
          }
        }
      }

      // ✅ Check nested review structures
      if (orderData['order_reviews'] != null) {
        _orderReviews = _safeMapConversion(orderData['order_reviews']);
        print('✅ HistoryDetailPage: Order review found (order_reviews key)');
      }

      if (orderData['driver_reviews'] != null) {
        _driverReviews = _safeMapConversion(orderData['driver_reviews']);
        print('✅ HistoryDetailPage: Driver review found (driver_reviews key)');
      }

      // ✅ Update rating status
      _hasGivenRating = _orderReviews != null || _driverReviews != null;

      print('📊 HistoryDetailPage: Review status:');
      print('   - Has Order Review: ${_orderReviews != null}');
      print('   - Has Driver Review: ${_driverReviews != null}');
      print('   - Has Given Rating: $_hasGivenRating');
    } catch (e) {
      print('❌ HistoryDetailPage: Error loading reviews: $e');
    }
  }

  //  Enhanced status tracking dengan logika yang benar
  void _startStatusTracking() {
    if (_orderDetail == null) {
      print('⚠️ HistoryDetailPage: No order detail for status tracking');
      return;
    }

    if (!_shouldStartStatusTracking()) {
      print('⚠️ HistoryDetailPage: Order completed, skipping status tracking');
      return;
    }

    print(
        '🔄 HistoryDetailPage: Starting status tracking for order ${_orderDetail!.id}');

    // ✅ PERBAIKAN: Interval lebih sering untuk update yang lebih responsif
    _statusUpdateTimer =
        Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (!mounted) {
        print('⚠️ HistoryDetailPage: Widget unmounted, stopping timer');
        timer.cancel();
        return;
      }

      try {
        print('📡 HistoryDetailPage: Checking order status update...');

        // ✅ PERBAIKAN: Enhanced session validation
        final sessionChecks = await Future.wait([
          AuthService.isAuthenticated(),
          AuthService.isSessionValid(),
          AuthService.ensureValidUserData(),
        ]);

        final isAuthenticated = sessionChecks[0] as bool;
        final sessionValid = sessionChecks[1] as bool;
        final hasValidSession = sessionChecks[2] as bool;

        if (!isAuthenticated || !sessionValid || !hasValidSession) {
          print('❌ HistoryDetailPage: Invalid session, stopping tracking');
          timer.cancel();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.white),
                    const SizedBox(width: 12),
                    const Text('Sesi berakhir. Update status dihentikan.'),
                  ],
                ),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }

        // ✅ PERBAIKAN 6: Selalu gunakan force refresh untuk real-time data
        final rawUpdatedOrderData = await OrderService.getOrderByIdForceRefresh(
          widget.order.id.toString(),
          forceRefresh: true,
        );

        final safeUpdatedOrderData = _safeMapConversion(rawUpdatedOrderData);
        final updatedOrder = OrderModel.fromJson(safeUpdatedOrderData);

        if (mounted) {
          final orderStatusChanged =
              _previousOrderStatus != updatedOrder.orderStatus;
          final deliveryStatusChanged =
              _previousDeliveryStatus != updatedOrder.deliveryStatus;

          print('✅ HistoryDetailPage: Order status checked');
          print('   - Previous Order Status: ${_previousOrderStatus?.name}');
          print('   - Current Order Status: ${updatedOrder.orderStatus.name}');
          print(
              '   - Previous Delivery Status: ${_previousDeliveryStatus?.name}');
          print(
              '   - Current Delivery Status: ${updatedOrder.deliveryStatus.name}');
          print('   - Order Status Changed: $orderStatusChanged');
          print('   - Delivery Status Changed: $deliveryStatusChanged');

          setState(() {
            _orderDetail = updatedOrder;
          });

          // ✅ Handle status change notifications
          if (orderStatusChanged || deliveryStatusChanged) {
            _handleStatusChange(
              _previousOrderStatus,
              updatedOrder.orderStatus,
              _previousDeliveryStatus,
              updatedOrder.deliveryStatus,
            );
            _previousOrderStatus = updatedOrder.orderStatus;
            _previousDeliveryStatus = updatedOrder.deliveryStatus;
          }

          // ✅ PERBAIKAN 7: Stop tracking hanya jika benar-benar final
          final isFinallyCompleted = (updatedOrder.orderStatus ==
                      OrderStatus.delivered &&
                  updatedOrder.deliveryStatus == DeliveryStatus.delivered) ||
              updatedOrder.orderStatus == OrderStatus.cancelled ||
              updatedOrder.orderStatus == OrderStatus.rejected;

          if (isFinallyCompleted) {
            print(
                '✅ HistoryDetailPage: Order finally completed, stopping tracking');
            timer.cancel();

            // ✅ Reload reviews for completed orders
            await _loadOrderReviews(safeUpdatedOrderData);
            if (_orderReviews != null || _driverReviews != null) {
              _reviewCardController.forward();
            }
          }
        }
      } catch (e) {
        print('❌ HistoryDetailPage: Error updating order status: $e');

        // ✅ Stop tracking hanya untuk authentication errors
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('unauthorized') ||
            errorStr.contains('session expired') ||
            errorStr.contains('authentication required')) {
          print(
              '🛑 HistoryDetailPage: Authentication error, stopping tracking');
          timer.cancel();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.white),
                    const SizedBox(width: 12),
                    const Text('Sesi berakhir. Update status dihentikan.'),
                  ],
                ),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
        // Untuk error lain, lanjutkan tracking
      }
    });
  }

  // Handle status change dengan logika kombinasi yang benar
  void _handleStatusChange(
      OrderStatus? previousOrderStatus,
      OrderStatus newOrderStatus,
      DeliveryStatus? previousDeliveryStatus,
      DeliveryStatus newDeliveryStatus) {
    // ✅ TAMBAHAN: Log perubahan dengan waktu WIB
    final now = TimezoneHelper.nowWIB();
    print('🔄 Status changed at ${TimezoneHelper.formatWIBFull(now)}:');
    print('   - Order: ${previousOrderStatus?.name} -> ${newOrderStatus.name}');
    print(
        '   - Delivery: ${previousDeliveryStatus?.name} -> ${newDeliveryStatus.name}');

    String? notification;

    // Prioritas notifikasi berdasarkan kombinasi status
    if (newOrderStatus == OrderStatus.delivered &&
        newDeliveryStatus == DeliveryStatus.delivered) {
      notification = 'Pesanan selesai! Pesanan Anda telah berhasil diterima.';
      _playSuccessSound();
    } else if (newOrderStatus == OrderStatus.onDelivery &&
        newDeliveryStatus == DeliveryStatus.onWay) {
      notification =
          'Pesanan sedang diantar! Driver sedang menuju lokasi Anda.';
      _playStatusChangeSound();
    } else if (newOrderStatus == OrderStatus.readyForPickup &&
        newDeliveryStatus == DeliveryStatus.pickedUp) {
      notification =
          'Pesanan siap diambil! Driver akan segera mengambil pesanan.';
      _playStatusChangeSound();
    } else if (newOrderStatus == OrderStatus.preparing &&
        newDeliveryStatus == DeliveryStatus.pickedUp) {
      notification =
          'Pesanan sedang disiapkan! Toko dan driver sudah menerima pesanan.';
      _playStatusChangeSound();
    } else if (newOrderStatus == OrderStatus.preparing &&
        newDeliveryStatus == DeliveryStatus.pending) {
      notification = 'Toko sedang memproses pesanan, menunggu driver menerima.';
      _playStatusChangeSound();
    } else if (newOrderStatus == OrderStatus.pending &&
        newDeliveryStatus == DeliveryStatus.pickedUp) {
      notification = 'Driver sudah menerima pesanan, menunggu toko memproses.';
      _playStatusChangeSound();
    } else if (newOrderStatus == OrderStatus.cancelled) {
      notification = 'Pesanan Anda telah dibatalkan.';
      _playCancelSound();
    } else if (newOrderStatus == OrderStatus.rejected) {
      notification = 'Pesanan Anda ditolak oleh toko.';
      _playCancelSound();
    } else if (newOrderStatus == OrderStatus.confirmed) {
      notification =
          'Pesanan dikonfirmasi! Toko akan segera memproses pesanan Anda.';
      _playStatusChangeSound();
    }

    // ✅ TAMBAHAN: Handle perubahan status individual untuk notifikasi tambahan
    if (previousOrderStatus != newOrderStatus) {
      print(
          '📝 Order status change detected: ${previousOrderStatus?.name} -> ${newOrderStatus.name}');

      // Notifikasi khusus untuk perubahan order status
      switch (newOrderStatus) {
        case OrderStatus.confirmed:
          if (notification == null) {
            notification = 'Pesanan dikonfirmasi oleh toko.';
            _playStatusChangeSound();
          }
          break;
        case OrderStatus.preparing:
          if (notification == null) {
            notification = 'Toko mulai menyiapkan pesanan Anda.';
            _playStatusChangeSound();
          }
          break;
        case OrderStatus.readyForPickup:
          if (notification == null) {
            notification = 'Pesanan siap untuk diambil driver.';
            _playStatusChangeSound();
          }
          break;
        case OrderStatus.onDelivery:
          if (notification == null) {
            notification = 'Pesanan dalam perjalanan menuju Anda.';
            _playStatusChangeSound();
          }
          break;
        default:
          break;
      }
    }

    if (previousDeliveryStatus != newDeliveryStatus) {
      print(
          '🚚 Delivery status change detected: ${previousDeliveryStatus?.name} -> ${newDeliveryStatus.name}');

      // Notifikasi khusus untuk perubahan delivery status
      switch (newDeliveryStatus) {
        case DeliveryStatus.pickedUp:
          if (notification == null) {
            notification = 'Driver telah menerima pesanan Anda.';
            _playStatusChangeSound();
          }
          break;
        case DeliveryStatus.onWay:
          if (notification == null) {
            notification = 'Driver sedang dalam perjalanan mengantar pesanan.';
            _playStatusChangeSound();
          }
          break;
        case DeliveryStatus.delivered:
          if (notification == null) {
            notification = 'Pesanan telah sampai di tujuan.';
            _playSuccessSound();
          }
          break;
        default:
          break;
      }
    }

    // Handle pulse animation berdasarkan status
    if ([OrderStatus.cancelled, OrderStatus.rejected]
        .contains(newOrderStatus)) {
      _pulseController.stop();
      print('🛑 Stopping pulse animation for cancelled/rejected order');
    } else if (newOrderStatus == OrderStatus.pending &&
        newDeliveryStatus == DeliveryStatus.pending) {
      _pulseController.repeat(reverse: true);
      print('🔄 Starting pulse animation for pending order');
    } else if (newOrderStatus == OrderStatus.delivered &&
        newDeliveryStatus == DeliveryStatus.delivered) {
      _pulseController.stop();
      print('✅ Stopping pulse animation for completed order');
    } else {
      // Stop pulse for other statuses but don't log
      _pulseController.stop();
    }

    // ✅ TAMBAHAN: Show notification dengan timestamp WIB
    if (notification != null && mounted) {
      final notificationColor = _getNotificationColor(newOrderStatus);
      final timeText = TimezoneHelper.formatTimeOnly(now);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                notification,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Diperbarui pada $timeText WIB',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.8),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          backgroundColor: notificationColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Tutup',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );

      // ✅ TAMBAHAN: Log notifikasi yang ditampilkan
      print(
          '📢 Showing notification at ${TimezoneHelper.formatWIBFull(now)}: $notification');
    }

    // ✅ TAMBAHAN: Update waktu perubahan status terakhir untuk tracking
    if (mounted) {
      setState(() {
        // Bisa digunakan untuk menyimpan waktu perubahan terakhir jika diperlukan
        // _lastStatusChangeTime = now;
      });
    }
  }

  // ✅ BARU: Helper method untuk cek apakah ada informasi waktu
  bool _hasTimeInformation() {
    if (_orderDetail == null) return false;

    return _orderDetail!.estimatedPickupTime != null ||
        _orderDetail!.actualPickupTime != null ||
        _orderDetail!.estimatedDeliveryTime != null ||
        _orderDetail!.actualDeliveryTime != null;
  }

// ✅ BARU: Helper method untuk cek apakah perlu menampilkan section waktu/progress
  bool _shouldShowTimeInfoOrProgress() {
    return _hasTimeInformation() || _shouldShowProgressIndicator();
  }

// Method yang sudah ada sebelumnya
  bool _shouldShowProgressIndicator() {
    if (_orderDetail == null) return false;

    final orderStatus = _orderDetail!.orderStatus;
    final deliveryStatus = _orderDetail!.deliveryStatus;

    // Tampilkan progress untuk status yang sedang berlangsung
    return ![OrderStatus.cancelled, OrderStatus.rejected, OrderStatus.delivered]
            .contains(orderStatus) ||
        (orderStatus == OrderStatus.delivered &&
            deliveryStatus != DeliveryStatus.delivered);
  }

  // ✅ BARU: Helper untuk warna notifikasi
  Color _getNotificationColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.delivered:
        return Colors.green;
      case OrderStatus.cancelled:
      case OrderStatus.rejected:
        return Colors.red;
      case OrderStatus.onDelivery:
        return Colors.blue;
      default:
        return GlobalStyle.primaryColor;
    }
  }

  void _handleInitialStatus(OrderStatus status) {
    if ([OrderStatus.cancelled, OrderStatus.rejected].contains(status)) {
      _playCancelSound();
    } else if (status == OrderStatus.pending) {
      _pulseController.repeat(reverse: true);
    }
  }

  void _playStatusChangeSound() async {
    try {
      await _audioPlayer.play(AssetSource('audio/kring.mp3'));
    } catch (e) {
      print('Error playing status change sound: $e');
    }
  }

  void _playSuccessSound() async {
    try {
      await _audioPlayer.play(AssetSource('audio/success.mp3'));
    } catch (e) {
      print('Error playing success sound: $e');
      // Fallback to kring sound
      _playStatusChangeSound();
    }
  }

  void _playCancelSound() async {
    try {
      await _audioPlayer.play(AssetSource('audio/wrong.mp3'));
    } catch (e) {
      print('Error playing cancel sound: $e');
    }
  }

  // ✅ FIXED: Enhanced rating submission
  Future<void> _handleRatingSubmission() async {
    if (_orderDetail == null || _isSubmittingRating) return;

    setState(() {
      _isSubmittingRating = true;
    });

    try {
      print(
          '⭐ HistoryDetailPage: Starting rating submission for order: ${_orderDetail!.id}');

      // ✅ Comprehensive authentication validation
      final userData = await AuthService.getUserData();
      final roleData = await AuthService.getRoleSpecificData();

      if (userData == null) {
        throw Exception('Authentication required: Please login');
      }

      if (roleData == null) {
        throw Exception('Role data not found: Please login as customer');
      }

      // ✅ Validate customer role
      final userRole = await AuthService.getUserRole();
      if (userRole?.toLowerCase() != 'customer') {
        throw Exception('Access denied: Only customers can rate orders');
      }

      final hasAccess = await AuthService.validateCustomerAccess();
      if (!hasAccess) {
        throw Exception('Access denied: Customer authentication required');
      }

      print(
          '✅ HistoryDetailPage: Authentication validated for rating submission');

      // ✅ Validate order status
      if (_orderDetail!.orderStatus != OrderStatus.delivered) {
        throw Exception('Rating can only be given for delivered orders');
      }

      if (_hasGivenRating) {
        throw Exception('Rating has already been submitted for this order');
      }

      // ✅ Show loading state
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 2,
                  ),
                ),
                const SizedBox(width: 12),
                const Text('Membuka halaman rating...'),
              ],
            ),
            backgroundColor: GlobalStyle.primaryColor,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // ✅ Navigate to rating page
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RatingCustomerPage(
            order: _orderDetail!,
          ),
        ),
      );

      print('📝 HistoryDetailPage: Rating page returned result: $result');

      // ✅ Process rating result
      if (result != null && result is Map<String, dynamic>) {
        // Validate rating data before submission
        final storeRating = result['storeRating'];
        final driverRating = result['driverRating'];
        final storeComment = result['storeComment']?.toString().trim() ?? '';
        final driverComment = result['driverComment']?.toString().trim() ?? '';

        print('📋 HistoryDetailPage: Processing rating data:');
        print('   - Store Rating: $storeRating');
        print('   - Driver Rating: $driverRating');

        // ✅ Validate that at least one rating is provided
        if ((storeRating == null || storeRating <= 0) &&
            (driverRating == null || driverRating <= 0)) {
          throw Exception(
              'At least one rating (store or driver) must be provided');
        }

        // ✅ Prepare clean review data
        final Map<String, dynamic> orderReview = {};
        final Map<String, dynamic> driverReview = {};

        // Only include store review if rating is valid
        if (storeRating != null && storeRating > 0 && storeRating <= 5) {
          orderReview['rating'] = storeRating;
          if (storeComment.isNotEmpty) {
            orderReview['comment'] = storeComment;
          }
        }

        // Only include driver review if rating is valid
        if (driverRating != null && driverRating > 0 && driverRating <= 5) {
          driverReview['rating'] = driverRating;
          if (driverComment.isNotEmpty) {
            driverReview['comment'] = driverComment;
          }
        }

        // ✅ Ensure at least one valid review exists
        if (orderReview.isEmpty && driverReview.isEmpty) {
          throw Exception('No valid ratings to submit');
        }

        print('📤 HistoryDetailPage: Submitting review to OrderService:');
        print('   - Order Review: $orderReview');
        print('   - Driver Review: $driverReview');

        // ✅ Submit review using OrderService.createReview()
        final reviewResult = await OrderService.createReview(
          orderId: _orderDetail!.id.toString(),
          orderReview: orderReview,
          driverReview: driverReview,
        );

        print('✅ HistoryDetailPage: Review submitted successfully');

        // ✅ Reload order data to get updated reviews
        try {
          await _loadOrderDetail();

          if (_orderReviews != null || _driverReviews != null) {
            _reviewCardController.forward();
          }
        } catch (reloadError) {
          print(
              '⚠️ HistoryDetailPage: Error reloading order detail after review: $reloadError');
          // Continue anyway since review was submitted successfully
        }

        // ✅ Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Rating berhasil dikirim. Terima kasih!'),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        print(
            'ℹ️ HistoryDetailPage: Rating page cancelled or no data returned');
      }
    } catch (e) {
      print('❌ HistoryDetailPage: Error handling rating submission: $e');

      // ✅ Enhanced error handling with specific messages
      String errorMessage = 'Gagal mengirim rating';

      if (e.toString().contains('Authentication required') ||
          e.toString().contains('Access denied')) {
        errorMessage =
            'Autentikasi diperlukan. Silakan login sebagai customer.';
      } else if (e.toString().contains('Rating can only be given')) {
        errorMessage =
            'Rating hanya dapat diberikan untuk pesanan yang telah selesai.';
      } else if (e.toString().contains('already been submitted')) {
        errorMessage = 'Rating sudah pernah diberikan untuk pesanan ini.';
      } else if (e.toString().contains('At least one rating')) {
        errorMessage = 'Minimal berikan satu rating (toko atau driver).';
      } else if (e.toString().contains('Invalid review data') ||
          e.toString().contains('Bad request')) {
        errorMessage =
            'Data rating tidak valid. Silakan periksa rating Anda dan coba lagi.';
      } else if (e.toString().contains('network') ||
          e.toString().contains('connection')) {
        errorMessage = 'Masalah koneksi. Silakan periksa internet Anda.';
      } else {
        errorMessage = 'Terjadi kesalahan: ${e.toString()}';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(errorMessage)),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      setState(() {
        _isSubmittingRating = false;
      });
    }
  }

  Future<void> _cancelOrder() async {
    // Show confirmation dialog
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Batalkan Pesanan'),
        content: const Text('Apakah Anda yakin ingin membatalkan pesanan ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Tidak'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Ya, Batalkan',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldCancel != true) return;

    setState(() {
      _isCancelling = true;
    });

    try {
      print('🚫 HistoryDetailPage: Cancelling order: ${_orderDetail!.id}');

      // ✅ PERBAIKAN 1: Comprehensive authentication validation dengan detail logging
      final authResults = await Future.wait([
        AuthService.isAuthenticated(),
        AuthService.ensureValidUserData(),
        AuthService.getUserRole(),
        AuthService.getUserData(),
        AuthService.isSessionValid(),
        AuthService
            .getCustomerData(), // ✅ TAMBAHAN: Get customer data specifically
      ]);

      final isAuthenticated = authResults[0] as bool;
      final hasValidSession = authResults[1] as bool;
      final userRole = authResults[2] as String?;
      final userData = authResults[3] as Map<String, dynamic>?;
      final sessionValid = authResults[4] as bool;
      final customerData = authResults[5] as Map<String, dynamic>?;

      print('🔍 Authentication check results:');
      print('   - isAuthenticated: $isAuthenticated');
      print('   - hasValidSession: $hasValidSession');
      print('   - userRole: $userRole');
      print('   - userData keys: ${userData?.keys.toList()}');
      print('   - sessionValid: $sessionValid');
      print('   - customerData keys: ${customerData?.keys.toList()}');

      // ✅ PERBAIKAN 2: Better validation logic
      if (!isAuthenticated || !sessionValid) {
        throw Exception('Session expired: Please login again');
      }

      if (!hasValidSession || userData == null || customerData == null) {
        throw Exception('Invalid user session: Please login again');
      }

      if (userRole?.toLowerCase() != 'customer') {
        throw Exception('Access denied: Only customers can cancel orders');
      }

      // ✅ PERBAIKAN 3: Validate customer access specifically
      final hasCustomerAccess = await AuthService.validateCustomerAccess();
      if (!hasCustomerAccess) {
        throw Exception('Customer access validation failed');
      }

      print('✅ HistoryDetailPage: Authentication validated for cancellation');
      print('   - Customer ID: ${customerData['id']}');
      print('   - Customer Name: ${customerData['name']}');
      print('   - User Role: $userRole');
      print('   - Session Valid: $sessionValid');

      // ✅ PERBAIKAN 4: Validate order can be cancelled
      if (!_canCancelOrder()) {
        throw Exception('Order cannot be cancelled in its current state');
      }

      print(
          '✅ Order can be cancelled: ${_orderDetail!.orderStatus.name} + ${_orderDetail!.deliveryStatus.name}');

      // ✅ PERBAIKAN 5: Use proper cancel method dengan error handling yang lebih baik
      Map<String, dynamic> result;

      try {
        // Try using the dedicated cancel method first
        result = await OrderService.cancelOrderByCustomer(
          orderId: _orderDetail!.id.toString(),
          cancellationReason: 'Cancelled by customer from mobile app',
        );
        print('✅ Cancel method succeeded');
      } catch (cancelError) {
        print('⚠️ Cancel method failed, trying status update: $cancelError');

        // ✅ FALLBACK: Direct status update if cancel method fails
        result = await OrderService.updateOrderStatus(
          orderId: _orderDetail!.id.toString(),
          orderStatus: 'cancelled',
          notes: 'Cancelled by customer from mobile app',
        );
        print('✅ Status update method succeeded');
      }

      print('✅ HistoryDetailPage: Order cancelled successfully');
      print('   - Result: ${result.keys.toList()}');

      // ✅ PERBAIKAN 6: Refresh order detail to reflect changes
      await _loadOrderDetail();

      if (mounted) {
        // ✅ Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                const Text('Pesanan berhasil dibatalkan'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ),
        );

        // ✅ PERBAIKAN 7: Better navigation handling dengan delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            try {
              // Try to go back to previous screen first
              Navigator.pop(context);
            } catch (e) {
              print('Error popping: $e');
              // If that fails, try to go to home
              try {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  HomePage.route,
                  (route) => false,
                );
              } catch (homeError) {
                print('Error navigating to home: $homeError');
                // Ultimate fallback - just stay on current page
              }
            }
          }
        });
      }
    } catch (e) {
      print('❌ HistoryDetailPage: Error cancelling order: $e');

      // ✅ PERBAIKAN 8: Enhanced error message handling
      String errorMessage = 'Gagal membatalkan pesanan';
      bool shouldForceLogout = false;

      final errorStr = e.toString().toLowerCase();

      if (errorStr.contains('session expired') ||
          errorStr.contains('authentication required') ||
          errorStr.contains('please login again') ||
          errorStr.contains('unauthorized') ||
          errorStr.contains('invalid user session') ||
          errorStr.contains('customer access validation failed')) {
        errorMessage = 'Sesi telah berakhir. Silakan login kembali.';
        shouldForceLogout = true;
      } else if (errorStr.contains('access denied')) {
        errorMessage =
            'Akses ditolak. Hanya customer yang dapat membatalkan pesanan.';
      } else if (errorStr.contains('order not found')) {
        errorMessage = 'Pesanan tidak ditemukan.';
      } else if (errorStr.contains('cannot be cancelled') ||
          errorStr.contains('current state')) {
        errorMessage = 'Pesanan tidak dapat dibatalkan pada status saat ini.';
      } else if (errorStr.contains('network') ||
          errorStr.contains('connection')) {
        errorMessage = 'Masalah koneksi. Silakan periksa internet Anda.';
      } else {
        errorMessage = 'Terjadi kesalahan: ${e.toString()}';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(errorMessage)),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 4),
          ),
        );

        // ✅ PERBAIKAN 9: Handle forced logout dengan route yang benar
        if (shouldForceLogout) {
          try {
            await AuthService.logout();

            // ✅ PERBAIKAN 10: Better route handling
            if (mounted) {
              // Try multiple navigation approaches
              try {
                // First try: Use known route
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login', // ✅ Ganti dengan route yang benar sesuai routing Anda
                  (route) => false,
                );
              } catch (routeError1) {
                print('Login route failed: $routeError1');
                try {
                  // Second try: Go to root and let splash handle it
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/',
                    (route) => false,
                  );
                } catch (routeError2) {
                  print('Root route failed: $routeError2');
                  try {
                    // Third try: Use replacement to splash/login screen
                    Navigator.pushReplacementNamed(context, '/splash');
                  } catch (routeError3) {
                    print('Splash route failed: $routeError3');
                    // Ultimate fallback: just stay on current page
                    print(
                        'All navigation attempts failed, staying on current page');
                  }
                }
              }
            }
          } catch (logoutError) {
            print('Error during forced logout: $logoutError');
          }
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCancelling = false;
        });
      }
    }
  }

  // ✅ PERBAIKAN: Helper methods dengan logika kombinasi status yang benar
  Color getStatusColor(
      OrderStatus orderStatus, DeliveryStatus? deliveryStatus) {
    // ✅ Prioritas berdasarkan kombinasi status
    if (orderStatus == OrderStatus.delivered &&
        deliveryStatus == DeliveryStatus.delivered) {
      return Colors.green;
    } else if (orderStatus == OrderStatus.onDelivery &&
        deliveryStatus == DeliveryStatus.onWay) {
      return Colors.blue;
    } else if (orderStatus == OrderStatus.readyForPickup) {
      return Colors.indigo;
    } else if (orderStatus == OrderStatus.preparing) {
      return Colors.purple;
    } else if (orderStatus == OrderStatus.confirmed) {
      return Colors.blue;
    } else if (orderStatus == OrderStatus.cancelled ||
        orderStatus == OrderStatus.rejected) {
      return Colors.red;
    } else {
      return Colors.orange; // pending
    }
  }

  String _getStatusText(
      OrderStatus orderStatus, DeliveryStatus? deliveryStatus) {
    // Handle cancelled/rejected first
    if (orderStatus == OrderStatus.cancelled) return 'Dibatalkan';
    if (orderStatus == OrderStatus.rejected) return 'Ditolak';

    // Logic kombinasi sesuai alur bisnis
    if (orderStatus == OrderStatus.pending &&
        deliveryStatus == DeliveryStatus.pending) {
      return 'Menunggu';
    } else if (orderStatus == OrderStatus.preparing &&
        deliveryStatus == DeliveryStatus.pending) {
      return 'Diproses oleh Toko, Menunggu Driver';
    } else if (orderStatus == OrderStatus.pending &&
        deliveryStatus == DeliveryStatus.pickedUp) {
      return 'Diproses oleh Driver, Menunggu Toko';
    } else if (orderStatus == OrderStatus.preparing &&
        deliveryStatus == DeliveryStatus.pickedUp) {
      return 'Disiapkan';
    } else if (orderStatus == OrderStatus.readyForPickup &&
        deliveryStatus == DeliveryStatus.pickedUp) {
      return 'Siap Diambil';
    } else if (orderStatus == OrderStatus.onDelivery &&
        deliveryStatus == DeliveryStatus.onWay) {
      return 'Diantar';
    } else if (orderStatus == OrderStatus.delivered &&
        deliveryStatus == DeliveryStatus.delivered) {
      return 'Selesai';
    } else {
      // Fallback untuk status lain
      return orderStatus.displayName;
    }
  }

  String _getStatusDescription(
      OrderStatus orderStatus, DeliveryStatus? deliveryStatus) {
    // Handle cancelled/rejected first
    if (orderStatus == OrderStatus.cancelled) return 'Pesanan dibatalkan';
    if (orderStatus == OrderStatus.rejected) return 'Pesanan ditolak toko';

    // Logic kombinasi sesuai alur bisnis
    if (orderStatus == OrderStatus.pending &&
        deliveryStatus == DeliveryStatus.pending) {
      return 'Menunggu konfirmasi dari toko dan driver';
    } else if (orderStatus == OrderStatus.preparing &&
        deliveryStatus == DeliveryStatus.pending) {
      return 'Toko sedang memproses pesanan, menunggu driver menerima';
    } else if (orderStatus == OrderStatus.pending &&
        deliveryStatus == DeliveryStatus.pickedUp) {
      return 'Driver sudah menerima pesanan, menunggu toko memproses';
    } else if (orderStatus == OrderStatus.preparing &&
        deliveryStatus == DeliveryStatus.pickedUp) {
      return 'Toko sedang menyiapkan pesanan Anda';
    } else if (orderStatus == OrderStatus.readyForPickup &&
        deliveryStatus == DeliveryStatus.pickedUp) {
      return 'Pesanan siap untuk diambil driver';
    } else if (orderStatus == OrderStatus.onDelivery &&
        deliveryStatus == DeliveryStatus.onWay) {
      return 'Driver sedang mengantarkan pesanan ke lokasi Anda';
    } else if (orderStatus == OrderStatus.delivered &&
        deliveryStatus == DeliveryStatus.delivered) {
      return 'Pesanan telah berhasil diterima';
    } else {
      return 'Status pesanan: ${orderStatus.displayName}';
    }
  }

  // ✅ FIXED: Payment method text
  String _getPaymentMethodText() {
    return 'Tunai (COD)';
  }

  // ✅ PERBAIKAN: Order Status Card dengan logika kombinasi yang benar
  Widget _buildOrderStatusCard() {
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
              ),
              const SizedBox(height: 16),
              Text(
                'Memuat status pesanan...',
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

    final currentOrderStatus = _orderDetail!.orderStatus;
    final currentDeliveryStatus = _orderDetail!.deliveryStatus;
    final currentStatusInfo = _getCurrentStatusInfo();
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
                      Icons.track_changes,
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
                          'Status Pesanan',
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
                      color: Colors.white.withOpacity(0.2),
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
                  // ✅ PERBAIKAN: Animation dengan logika yang benar
                  if (currentOrderStatus == OrderStatus.pending)
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
                        repeat: _shouldRepeatAnimation(currentOrderStatus),
                      ),
                    ),

                  const SizedBox(height: 20),

                  // ✅ Status Timeline - hanya untuk order yang tidak cancelled/rejected
                  if (![OrderStatus.cancelled, OrderStatus.rejected]
                      .contains(currentOrderStatus))
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children:
                            List.generate(_statusTimeline.length, (index) {
                          final isActive = index <= currentIndex;
                          final isCurrent = index == currentIndex;
                          final isLast = index == _statusTimeline.length - 1;
                          final statusItem = _statusTimeline[index];

                          return Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Center(
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      width: isCurrent ? 32 : 24,
                                      height: isCurrent ? 32 : 24,
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
                                                  blurRadius: 8,
                                                  spreadRadius: 2,
                                                ),
                                              ]
                                            : [],
                                      ),
                                      child: Icon(
                                        statusItem['icon'],
                                        color: Colors.white,
                                        size: isCurrent ? 16 : 12,
                                      ),
                                    ),
                                  ),
                                ),
                                // Connector line
                                if (!isLast)
                                  Container(
                                    width: 24,
                                    height: 2,
                                    decoration: BoxDecoration(
                                      color: index < currentIndex
                                          ? _statusTimeline[index]['color']
                                          : Colors.grey[300],
                                      borderRadius: BorderRadius.circular(1),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),

                  const SizedBox(height: 20),

                  // ✅ Status Message dengan kombinasi yang benar
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
                          _getStatusText(
                              currentOrderStatus, currentDeliveryStatus),
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
                          _getStatusDescription(
                              currentOrderStatus, currentDeliveryStatus),
                          style: TextStyle(
                            color: currentStatusInfo['color'].withOpacity(0.8),
                            fontSize: 14,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        // ✅ BARU: Tampilkan informasi delivery status jika berbeda dari order status
                        if (_shouldShowDeliveryStatusInfo(
                            currentOrderStatus, currentDeliveryStatus))
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Status Pengiriman: ${_getDeliveryStatusText(currentDeliveryStatus)}',
                              style: TextStyle(
                                color:
                                    currentStatusInfo['color'].withOpacity(0.7),
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                fontFamily: GlobalStyle.fontFamily,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Store info
                  if (_orderDetail!.store != null)
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
                              borderRadius: BorderRadius.circular(8),
                              child: ImageService.displayImage(
                                imageSource:
                                    _orderDetail!.store!.imageUrl ?? '',
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                placeholder: Container(
                                  width: 40,
                                  height: 40,
                                  color: Colors.grey[300],
                                  child: Icon(Icons.store,
                                      color: Colors.grey[600], size: 20),
                                ),
                                errorWidget: Container(
                                  width: 40,
                                  height: 40,
                                  color: Colors.grey[300],
                                  child: Icon(Icons.store,
                                      color: Colors.grey[600], size: 20),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _orderDetail!.store!.name,
                                    style: TextStyle(
                                      color: Colors.grey[800],
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: GlobalStyle.fontFamily,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${_orderDetail!.totalItems} item',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                      fontFamily: GlobalStyle.fontFamily,
                                    ),
                                  ),
                                ],
                              ),
                            ),
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

  // ✅ BARU: Helper methods untuk status logic
  bool _shouldRepeatAnimation(OrderStatus orderStatus) {
    return ![OrderStatus.delivered, OrderStatus.cancelled, OrderStatus.rejected]
        .contains(orderStatus);
  }

  bool _shouldShowDeliveryStatusInfo(
      OrderStatus orderStatus, DeliveryStatus? deliveryStatus) {
    // Tampilkan info delivery status hanya untuk status yang sedang dalam proses pengiriman
    return orderStatus == OrderStatus.onDelivery &&
        deliveryStatus != null &&
        deliveryStatus != DeliveryStatus.pending;
  }

  String _getDeliveryStatusText(DeliveryStatus? deliveryStatus) {
    if (deliveryStatus == null) return 'Tidak Diketahui';

    switch (deliveryStatus) {
      case DeliveryStatus.pending:
        return 'Menunggu Penjemputan';
      case DeliveryStatus.pickedUp:
        return 'Sudah Diambil';
      case DeliveryStatus.onWay:
        return 'Dalam Perjalanan';
      case DeliveryStatus.delivered:
        return 'Terkirim';
      case DeliveryStatus.rejected:
        return 'Ditolak';
    }
  }

  Map<String, dynamic> _getCurrentStatusInfo() {
    if (_orderDetail == null) {
      return _statusTimeline[0];
    }

    final currentOrderStatus = _orderDetail!.orderStatus;
    final currentDeliveryStatus = _orderDetail!.deliveryStatus;

    // Handle cancelled and rejected status
    if (currentOrderStatus == OrderStatus.cancelled) {
      return {
        'status': 'cancelled',
        'label': 'Dibatalkan',
        'description': 'Pesanan dibatalkan',
        'icon': Icons.cancel_outlined,
        'color': Colors.red,
        'animation': 'assets/animations/cancel.json'
      };
    }

    if (currentOrderStatus == OrderStatus.rejected) {
      return {
        'status': 'rejected',
        'label': 'Ditolak',
        'description': 'Pesanan ditolak toko',
        'icon': Icons.block,
        'color': Colors.red,
        'animation': 'assets/animations/cancel.json'
      };
    }

    // Logic kombinasi status sesuai alur bisnis
    if (currentOrderStatus == OrderStatus.pending &&
        currentDeliveryStatus == DeliveryStatus.pending) {
      return _statusTimeline[0]; // waiting
    } else if ((currentOrderStatus == OrderStatus.preparing &&
            currentDeliveryStatus == DeliveryStatus.pending) ||
        (currentOrderStatus == OrderStatus.pending &&
            currentDeliveryStatus == DeliveryStatus.pickedUp)) {
      return _statusTimeline[1]; // processing
    } else if (currentOrderStatus == OrderStatus.preparing &&
        currentDeliveryStatus == DeliveryStatus.pickedUp) {
      return _statusTimeline[2]; // preparing
    } else if (currentOrderStatus == OrderStatus.readyForPickup &&
        currentDeliveryStatus == DeliveryStatus.pickedUp) {
      return _statusTimeline[3]; // ready
    } else if (currentOrderStatus == OrderStatus.onDelivery &&
        currentDeliveryStatus == DeliveryStatus.onWay) {
      return _statusTimeline[4]; // delivering
    } else if (currentOrderStatus == OrderStatus.delivered &&
        currentDeliveryStatus == DeliveryStatus.delivered) {
      return _statusTimeline[5]; // completed
    } else {
      // Fallback untuk kombinasi lain
      return _statusTimeline[0];
    }
  }

  int _getCurrentStatusIndex() {
    if (_orderDetail == null) return 0;

    final currentOrderStatus = _orderDetail!.orderStatus;
    final currentDeliveryStatus = _orderDetail!.deliveryStatus;

    // Special handling untuk status yang tidak ada di timeline
    if ([OrderStatus.cancelled, OrderStatus.rejected]
        .contains(currentOrderStatus)) {
      return -1; // Tidak tampilkan di timeline
    }

    // Return index berdasarkan kombinasi status
    if (currentOrderStatus == OrderStatus.pending &&
        currentDeliveryStatus == DeliveryStatus.pending) {
      return 0; // waiting
    } else if ((currentOrderStatus == OrderStatus.preparing &&
            currentDeliveryStatus == DeliveryStatus.pending) ||
        (currentOrderStatus == OrderStatus.pending &&
            currentDeliveryStatus == DeliveryStatus.pickedUp)) {
      return 1; // processing
    } else if (currentOrderStatus == OrderStatus.preparing &&
        currentDeliveryStatus == DeliveryStatus.pickedUp) {
      return 2; // preparing
    } else if (currentOrderStatus == OrderStatus.readyForPickup &&
        currentDeliveryStatus == DeliveryStatus.pickedUp) {
      return 3; // ready
    } else if (currentOrderStatus == OrderStatus.onDelivery &&
        currentDeliveryStatus == DeliveryStatus.onWay) {
      return 4; // delivering
    } else if (currentOrderStatus == OrderStatus.delivered &&
        currentDeliveryStatus == DeliveryStatus.delivered) {
      return 5; // completed
    } else {
      return 0; // default
    }
  }

  Widget _buildOrderInfoCard() {
    return _buildCard(
      index: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: GlobalStyle.primaryColor),
              const SizedBox(width: 8),
              Text(
                'Informasi Pesanan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: GlobalStyle.fontColor,
                  fontFamily: GlobalStyle.fontFamily,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ✅ PERBAIKAN: Tanggal Pesanan dalam WIB
          _buildInfoRow(
              'Tanggal Pesanan', _formatOrderDateWIB(_orderDetail!.createdAt)),
          const SizedBox(height: 8),

          // Status Utama (kombinasi)
          _buildInfoRow(
              'Status Utama',
              _getStatusText(
                  _orderDetail!.orderStatus, _orderDetail!.deliveryStatus)),
          const SizedBox(height: 8),

          // Detail Status - hanya tampilkan jika bukan status final
          if (![OrderStatus.cancelled, OrderStatus.rejected]
              .contains(_orderDetail!.orderStatus)) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.grey.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Detail Status:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                      fontFamily: GlobalStyle.fontFamily,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.store, size: 16, color: Colors.blue),
                      const SizedBox(width: 6),
                      Text(
                        'Toko: ${_orderDetail!.orderStatus.displayName}',
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
                      Icon(Icons.delivery_dining,
                          size: 16, color: Colors.orange),
                      const SizedBox(width: 6),
                      Text(
                        'Driver: ${_orderDetail!.deliveryStatus.displayName}',
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
            const SizedBox(height: 8),
          ],

          // Total Pembayaran
          _buildInfoRow('Total Pembayaran', _orderDetail!.formatTotalAmount()),

          // Metode Pembayaran
          const SizedBox(height: 8),
          _buildInfoRow('Metode Pembayaran', _getPaymentMethodText()),

          // ✅ GABUNGAN: Informasi waktu dan progress indicator
          if (_shouldShowTimeInfoOrProgress()) ...[
            const SizedBox(height: 16),

            // ✅ Informasi waktu dalam WIB (jika ada data waktu)
            if (_hasTimeInformation())
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 16, color: Colors.blue),
                        const SizedBox(width: 6),
                        Text(
                          'Informasi Waktu:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Estimasi Pickup
                    if (_orderDetail!.estimatedPickupTime != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(Icons.schedule_outlined,
                                size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 6),
                            Text(
                              'Est. Pickup: ${_formatTimeWIB(_orderDetail!.estimatedPickupTime!)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                                fontFamily: GlobalStyle.fontFamily,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Actual Pickup
                    if (_orderDetail!.actualPickupTime != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outlined,
                                size: 14, color: Colors.green),
                            const SizedBox(width: 6),
                            Text(
                              'Pickup: ${_formatTimeWIB(_orderDetail!.actualPickupTime!)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green[700],
                                fontFamily: GlobalStyle.fontFamily,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Estimasi Delivery
                    if (_orderDetail!.estimatedDeliveryTime != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(Icons.schedule_outlined,
                                size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 6),
                            Text(
                              'Est. Delivery: ${_formatTimeWIB(_orderDetail!.estimatedDeliveryTime!)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                                fontFamily: GlobalStyle.fontFamily,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Actual Delivery
                    if (_orderDetail!.actualDeliveryTime != null)
                      Row(
                        children: [
                          Icon(Icons.check_circle,
                              size: 14, color: Colors.green),
                          const SizedBox(width: 6),
                          Text(
                            'Delivered: ${_formatTimeWIB(_orderDetail!.actualDeliveryTime!)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green[700],
                              fontWeight: FontWeight.bold,
                              fontFamily: GlobalStyle.fontFamily,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

            // ✅ Status Progress Indicator (jika perlu)
            if (_shouldShowProgressIndicator())
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _getCurrentStatusInfo()['color'].withOpacity(0.1),
                      _getCurrentStatusInfo()['color'].withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getCurrentStatusInfo()['color'].withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          _getCurrentStatusInfo()['icon'],
                          color: _getCurrentStatusInfo()['color'],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _getStatusDescription(_orderDetail!.orderStatus,
                                _orderDetail!.deliveryStatus),
                            style: TextStyle(
                              color: _getCurrentStatusInfo()['color'],
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              fontFamily: GlobalStyle.fontFamily,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Progress indicator untuk status pending
                    if (_orderDetail!.orderStatus == OrderStatus.pending &&
                        _orderDetail!.deliveryStatus ==
                            DeliveryStatus.pending) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getCurrentStatusInfo()['color'],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xffF0F7FF),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          title: const Text('Detail Pesanan',
              style: TextStyle(color: Colors.black)),
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(7.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: GlobalStyle.primaryColor, width: 1.0),
              ),
              child: Icon(Icons.arrow_back_ios_new,
                  color: GlobalStyle.primaryColor, size: 18),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset(
                'assets/animations/loading_animation.json',
                width: 150,
                height: 150,
                errorBuilder: (context, error, stackTrace) {
                  return CircularProgressIndicator(
                    color: GlobalStyle.primaryColor,
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(
                "Memuat Detail Pesanan...",
                style: TextStyle(
                  color: GlobalStyle.primaryColor,
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xffF0F7FF),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          title: const Text('Detail Pesanan',
              style: TextStyle(color: Colors.black)),
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(7.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: GlobalStyle.primaryColor, width: 1.0),
              ),
              child: Icon(Icons.arrow_back_ios_new,
                  color: GlobalStyle.primaryColor, size: 18),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset(
                'assets/animations/caution.json',
                width: 150,
                height: 150,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.warning_amber_rounded,
                    size: 100,
                    color: Colors.orange,
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(
                "Gagal Memuat Data",
                style: TextStyle(
                  color: Colors.red[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _validateAndLoadData,
                icon: const Icon(Icons.refresh),
                label: const Text("Coba Lagi"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlobalStyle.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xffF0F7FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text(
          'Detail Pesanan',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
            fontFamily: GlobalStyle.fontFamily,
          ),
        ),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(7.0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: GlobalStyle.primaryColor, width: 1.0),
            ),
            child: Icon(Icons.arrow_back_ios_new,
                color: GlobalStyle.primaryColor, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // ✅ TAMBAH: Refresh button
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: GlobalStyle.primaryColor,
              size: 24,
            ),
            onPressed: _isLoading || _isLoadingOrderDetail
                ? null
                : _manualRefreshOrder,
            tooltip: 'Perbarui Status',
          ),
          if (_orderDetail?.id != null)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Text(
                  '#${_orderDetail!.id}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: GlobalStyle.primaryColor,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ✅ Order Status Card dengan logika yang diperbaiki
          SlideTransition(
            position: _cardAnimations[0],
            child: _buildOrderStatusCard(),
          ),

          // Order Date and Status Section
          _buildOrderInfoCard(),

          // Store and Items Section
          if (_orderDetail != null) _buildStoreAndItemsCard(),

          // Payment Details Section
          if (_orderDetail != null) _buildPaymentDetailsCard(),

          // Driver Information Section
          if (_orderDetail?.driver != null) _buildDriverCard(),

          // Reviews Section (shown after rating is given)
          if (_orderReviews != null || _driverReviews != null)
            _buildReviewsCard(),

          // Action Buttons Section
          if (_orderDetail != null) _buildActionButtonsCard(),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ✅ Enhanced card builder with better animation handling
  Widget _buildCard({required int index, required Widget child}) {
    return SlideTransition(
      position: _cardAnimations[index < _cardAnimations.length ? index : 0],
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }

  // ✅ Enhanced info row builder
  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
        ),
        const Text(': '),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: GlobalStyle.fontColor,
              fontFamily: GlobalStyle.fontFamily,
            ),
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
        ),
      ],
    );
  }

  // ✅ Enhanced store and items card with better data handling
  Widget _buildStoreAndItemsCard() {
    return _buildCard(
      index: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.store, color: GlobalStyle.primaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _orderDetail!.store?.name ?? 'Store',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: GlobalStyle.fontColor,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (_orderDetail!.store?.address != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _orderDetail!.store!.address,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _orderDetail!.items.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = _orderDetail!.items[index];
              return _buildOrderItemRow(item);
            },
          ),
        ],
      ),
    );
  }

  // ✅ Enhanced order item row with better image handling
  Widget _buildOrderItemRow(OrderItemModel item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: GlobalStyle.borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ImageService.displayImage(
              imageSource: item.imageUrl ?? '',
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              placeholder: Container(
                width: 60,
                height: 60,
                color: Colors.grey[200],
                child: const Icon(Icons.restaurant_menu, color: Colors.grey),
              ),
              errorWidget: Container(
                width: 60,
                height: 60,
                color: Colors.grey[300],
                child:
                    const Icon(Icons.image_not_supported, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: GlobalStyle.fontColor,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: GlobalStyle.lightColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'x${item.quantity}',
                    style: TextStyle(
                      color: GlobalStyle.primaryColor,
                      fontFamily: GlobalStyle.fontFamily,
                    ),
                  ),
                ),
                if (item.notes != null && item.notes!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Catatan: ${item.notes}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            item.formatTotalPrice(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: GlobalStyle.fontColor,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Enhanced payment details card with fixed calculations
  Widget _buildPaymentDetailsCard() {
    return _buildCard(
      index: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payment, color: GlobalStyle.primaryColor),
              const SizedBox(width: 8),
              Text(
                'Rincian Pembayaran',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: GlobalStyle.fontColor,
                  fontFamily: GlobalStyle.fontFamily,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                _buildPaymentRow('Subtotal', _orderDetail!.subtotal),
                const SizedBox(height: 12),
                _buildPaymentRow('Biaya Pengiriman', _orderDetail!.deliveryFee),
                const Divider(thickness: 1, height: 24),
                _buildPaymentRow(
                    'Total', _orderDetail!.subtotal + _orderDetail!.deliveryFee,
                    isTotal: true),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: Colors.blue[700],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pembayaran: ${_getPaymentMethodText()}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[700],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ],
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
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? GlobalStyle.fontColor : Colors.grey[700],
            fontFamily: GlobalStyle.fontFamily,
          ),
        ),
        Text(
          GlobalStyle.formatRupiah(amount),
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? GlobalStyle.primaryColor : GlobalStyle.fontColor,
            fontFamily: GlobalStyle.fontFamily,
          ),
        ),
      ],
    );
  }

  // ✅ Enhanced driver card with better data handling
  Widget _buildDriverCard() {
    return SlideTransition(
      position: _driverCardAnimation,
      child: Container(
        padding: const EdgeInsets.all(20),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.orange.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: Colors.orange.withOpacity(0.1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.delivery_dining,
                    color: Colors.orange,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Informasi Driver',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                // Driver Avatar
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.orange.withOpacity(0.3),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: _orderDetail!.driver!.avatar != null &&
                          _orderDetail!.driver!.avatar!.isNotEmpty
                      ? ClipOval(
                          child: ImageService.displayImage(
                            imageSource: _orderDetail!.driver!.avatar!,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            placeholder: const Center(
                              child: Icon(
                                Icons.person,
                                size: 30,
                                color: Colors.orange,
                              ),
                            ),
                            errorWidget: const Center(
                              child: Icon(
                                Icons.person,
                                size: 30,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                        )
                      : ClipOval(
                          child: Container(
                            color: Colors.orange.withOpacity(0.1),
                            child: const Icon(
                              Icons.person,
                              size: 40,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _orderDetail!.driver!.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.star,
                                    color: Colors.amber, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  _orderDetail!.driver!.rating
                                      .toStringAsFixed(1),
                                  style: TextStyle(
                                    color: Colors.amber[800],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.motorcycle,
                                color: Colors.grey[700], size: 16),
                            const SizedBox(width: 4),
                            Text(
                              _orderDetail!.driver!.vehiclePlate,
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_orderDetail!.driver!.reviewsCount} reviews',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ✅ PERBAIKAN: Contact buttons hanya untuk order yang aktif dan sedang dalam proses pengiriman
            if (_shouldShowContactButtons())
              Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.call,
                            color: Colors.white, size: 18),
                        label: const Text(
                          'Hubungi',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 2,
                        ),
                        onPressed: () =>
                            _callDriver(_orderDetail!.driver!.phone),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.message,
                            color: Colors.white, size: 18),
                        label: const Text(
                          'Pesan',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[700],
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 2,
                        ),
                        onPressed: () =>
                            _messageDriver(_orderDetail!.driver!.phone),
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

  // ✅ BARU: Helper untuk menentukan kapan menampilkan contact buttons
  bool _shouldShowContactButtons() {
    if (_orderDetail == null || _orderDetail!.driver == null) return false;

    final orderStatus = _orderDetail!.orderStatus;
    final deliveryStatus = _orderDetail!.deliveryStatus;

    // Tampilkan contact buttons untuk:
    // 1. Order status readyForPickup (siap diantar)
    // 2. Order status onDelivery dengan delivery status onWay (sedang diantarkan)
    return (orderStatus == OrderStatus.readyForPickup) ||
        (orderStatus == OrderStatus.onDelivery &&
            deliveryStatus == DeliveryStatus.onWay);
  }

  // ✅ Enhanced reviews card with better structure
  Widget _buildReviewsCard() {
    return SlideTransition(
      position: _reviewCardAnimation,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: Colors.green.withOpacity(0.2),
          ),
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
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.rate_review,
                      color: Colors.green,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Review Anda',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Store Review
              if (_orderReviews != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.store, color: Colors.blue, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Review Toko',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const Spacer(),
                          Row(
                            children: List.generate(5, (index) {
                              return Icon(
                                index < (_orderReviews!['rating'] ?? 0)
                                    ? Icons.star
                                    : Icons.star_border,
                                color: Colors.amber,
                                size: 16,
                              );
                            }),
                          ),
                        ],
                      ),
                      if (_orderReviews!['comment'] != null &&
                          _orderReviews!['comment'].toString().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          _orderReviews!['comment'],
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Driver Review
              if (_driverReviews != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.delivery_dining,
                              color: Colors.orange, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Review Driver',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                          const Spacer(),
                          Row(
                            children: List.generate(5, (index) {
                              return Icon(
                                index < (_driverReviews!['rating'] ?? 0)
                                    ? Icons.star
                                    : Icons.star_border,
                                color: Colors.amber,
                                size: 16,
                              );
                            }),
                          ),
                        ],
                      ),
                      if (_driverReviews!['comment'] != null &&
                          _driverReviews!['comment'].toString().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          _driverReviews!['comment'],
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle,
                        color: Colors.green[700], size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Terima kasih atas review Anda!',
                        style: TextStyle(
                          color: Colors.green[800],
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtonsCard() {
    final orderStatus = _orderDetail!.orderStatus;
    final deliveryStatus = _orderDetail!.deliveryStatus;

    // Cancel button - hanya untuk pending + pending
    final bool canCancel = _canCancelOrder();

    // Rate button - hanya untuk delivered + delivered dan belum ada rating
    final bool canRate = (orderStatus == OrderStatus.delivered &&
            deliveryStatus == DeliveryStatus.delivered) &&
        !_hasGivenRating;

    // Buy again button - untuk semua status yang completed
    final bool canBuyAgain = orderStatus.isCompleted;

    return _buildCard(
      index: 4,
      child: Column(
        children: [
          // Cancel Order Button (only for pending + pending)
          if (canCancel)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: _isCancelling
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cancel_outlined),
                  label: Text(
                      _isCancelling ? 'Membatalkan...' : 'Batalkan Pesanan'),
                  onPressed: _isCancelling ? null : _cancelOrder,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    disabledForegroundColor: Colors.grey,
                  ),
                ),
              ),
            ),

          // Rate Order Button (only for delivered + delivered)
          if (canRate)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: _isSubmittingRating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.star),
                  label: Text(_isSubmittingRating
                      ? 'Membuka Rating...'
                      : 'Beri Rating'),
                  onPressed:
                      _isSubmittingRating ? null : _handleRatingSubmission,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlobalStyle.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 2,
                    disabledBackgroundColor: Colors.grey,
                  ),
                ),
              ),
            ),

          // Buy Again Button (for completed orders)
          if (canBuyAgain)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.shopping_bag),
                label: const Text('Beli Lagi'),
                onPressed: () => _handleBuyAgain(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlobalStyle.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 2,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleBuyAgain() async {
    try {
      // Show loading feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 2,
                ),
              ),
              const SizedBox(width: 12),
              const Text('Mengarahkan ke halaman belanja...'),
            ],
          ),
          backgroundColor: GlobalStyle.primaryColor,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );

      // Small delay for user feedback
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        // ✅ PERBAIKAN: Navigation ke home customer yang lebih robust
        Navigator.pushNamedAndRemoveUntil(
          context,
          HomePage.route,
          (route) => false,
        );
      }
    } catch (e) {
      print('❌ HistoryDetailPage: Error navigating to home: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                const Text('Gagal mengarahkan ke halaman belanja'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Fallback: try to pop to previous screen
        try {
          Navigator.pop(context);
        } catch (popError) {
          print('Error popping: $popError');
        }
      }
    }
  }

  // Helper methods for phone actions
  Future<void> _callDriver(String phone) async {
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nomor telepon driver tidak tersedia'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final Uri uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak dapat memulai panggilan'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _messageDriver(String phone) async {
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nomor telepon driver tidak tersedia'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final Uri uri = Uri.parse('sms:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak dapat memulai pesan'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
