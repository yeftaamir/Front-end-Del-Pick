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
  OrderStatus? _previousStatus;

  // Customer-specific color theme for status card
  final Color _primaryColor = const Color(0xFF4A90E2);
  final Color _secondaryColor = const Color(0xFF7BB3F0);

  // Standardized status timeline
  final List<Map<String, dynamic>> _statusTimeline = [
    {
      'status': OrderStatus.pending,
      'label': 'Menunggu',
      'description': 'Menunggu konfirmasi toko',
      'icon': Icons.hourglass_empty,
      'color': Colors.orange,
      'animation': 'assets/animations/diambil.json'
    },
    {
      'status': OrderStatus.confirmed,
      'label': 'Dikonfirmasi',
      'description': 'Pesanan dikonfirmasi toko',
      'icon': Icons.check_circle_outline,
      'color': Colors.blue,
      'animation': 'assets/animations/diambil.json'
    },
    {
      'status': OrderStatus.preparing,
      'label': 'Disiapkan',
      'description': 'Pesanan sedang disiapkan',
      'icon': Icons.restaurant,
      'color': Colors.purple,
      'animation': 'assets/animations/diproses.json'
    },
    {
      'status': OrderStatus.readyForPickup,
      'label': 'Siap Diambil',
      'description': 'Pesanan siap diambil driver',
      'icon': Icons.shopping_bag,
      'color': Colors.indigo,
      'animation': 'assets/animations/diproses.json'
    },
    {
      'status': OrderStatus.onDelivery,
      'label': 'Diantar',
      'description': 'Pesanan dalam perjalanan',
      'icon': Icons.delivery_dining,
      'color': Colors.teal,
      'animation': 'assets/animations/diantar.json'
    },
    {
      'status': OrderStatus.delivered,
      'label': 'Selesai',
      'description': 'Pesanan telah diterima',
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

  // ✅ UPDATED: Enhanced authentication and data validation using getRoleSpecificData() & getUserData()
  Future<void> _validateAndLoadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('🔍 HistoryDetailPage: Starting authentication validation...');

      // ✅ Step 1: Validate customer access using updated AuthService
      final hasAccess = await AuthService.validateCustomerAccess();
      if (!hasAccess) {
        throw Exception('Access denied: Customer authentication required');
      }

      // ✅ Step 2: Get customer data using getUserData()
      final userData = await AuthService.getUserData();
      if (userData == null) {
        throw Exception('Unable to retrieve user data');
      }

      // ✅ Step 3: Get role-specific data using getRoleSpecificData()
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
      print('   - Role: ${_roleSpecificData!['role'] ?? 'customer'}');
      print('   - User Data Keys: ${userData.keys.toList()}');

      // ✅ Step 5: Load order detail using updated OrderService
      await _loadOrderDetail();

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

  // ✅ UPDATED: Load order detail with proper type conversion
  Future<void> _loadOrderDetail() async {
    setState(() {
      _isLoadingOrderDetail = true;
    });

    try {
      print('🔍 HistoryDetailPage: Loading order detail: ${widget.order.id}');

      // ✅ Use updated OrderService.getOrderById()
      final rawOrderData =
      await OrderService.getOrderById(widget.order.id.toString());

      // ✅ IMPORTANT: Convert all nested maps safely before creating OrderModel
      final safeOrderData = _safeMapConversion(rawOrderData);

      print('✅ HistoryDetailPage: Order data converted safely');
      print('   - Raw data type: ${rawOrderData.runtimeType}');
      print('   - Safe data type: ${safeOrderData.runtimeType}');
      print('   - Safe data keys: ${safeOrderData.keys.toList()}');

      // ✅ Process the order data with enhanced structure and safe conversion
      _orderDetail = OrderModel.fromJson(safeOrderData);

      print('✅ HistoryDetailPage: Order detail loaded successfully');
      print('   - Order Status: ${_orderDetail!.orderStatus.name}');
      print('   - Driver ID: ${_orderDetail?.driverId}');
      print('   - Store ID: ${_orderDetail?.storeId}');
      print('   - Items count: ${_orderDetail!.items.length}');

      // ✅ Load reviews data from the order response with safe conversion
      await _loadOrderReviews(safeOrderData);

      // ✅ Start status tracking if order is not completed
      if (!_orderDetail!.orderStatus.isCompleted) {
        _startStatusTracking();
      }

      // ✅ Store previous status for change detection
      _previousStatus = _orderDetail!.orderStatus;
    } catch (e) {
      print('❌ HistoryDetailPage: Error loading order detail: $e');
      throw Exception('Failed to load order details: $e');
    } finally {
      setState(() {
        _isLoadingOrderDetail = false;
      });
    }
  }

  // ✅ UPDATED: Enhanced review loading with better structure handling and safe conversion
  Future<void> _loadOrderReviews(Map<String, dynamic> orderData) async {
    try {
      print('🔍 HistoryDetailPage: Loading order reviews...');

      // ✅ Reset review states
      _orderReviews = null;
      _driverReviews = null;
      _hasGivenRating = false;

      // ✅ Check for reviews in order data - multiple possible structures with safe conversion
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

      // ✅ Check nested review structures - common in API responses
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

  // ✅ UPDATED: Enhanced status tracking with better session management
  void _startStatusTracking() {
    if (_orderDetail == null || _orderDetail!.orderStatus.isCompleted) {
      print(
          '⚠️ HistoryDetailPage: Order is completed, skipping status tracking');
      return;
    }

    print(
        '🔄 HistoryDetailPage: Starting status tracking for order ${_orderDetail!.id}');

    _statusUpdateTimer =
        Timer.periodic(const Duration(seconds: 15), (timer) async {
          if (!mounted) {
            print('⚠️ HistoryDetailPage: Widget unmounted, stopping timer');
            timer.cancel();
            return;
          }

          try {
            print('📡 HistoryDetailPage: Checking order status update...');

            // ✅ Ensure valid session before API call using updated method
            final hasValidSession = await AuthService.ensureValidUserData();
            if (!hasValidSession) {
              print('❌ HistoryDetailPage: Invalid session, stopping tracking');
              timer.cancel();
              return;
            }

            // ✅ Get updated order data with safe conversion
            final rawUpdatedOrderData =
            await OrderService.getOrderById(widget.order.id.toString());
            final safeUpdatedOrderData = _safeMapConversion(rawUpdatedOrderData);
            final updatedOrder = OrderModel.fromJson(safeUpdatedOrderData);

            if (mounted) {
              final statusChanged = _previousStatus != updatedOrder.orderStatus;

              print('✅ HistoryDetailPage: Order status checked');
              print('   - Previous: ${_previousStatus?.name}');
              print('   - Current: ${updatedOrder.orderStatus.name}');
              print('   - Changed: $statusChanged');

              setState(() {
                _orderDetail = updatedOrder;
              });

              // ✅ Handle status change notifications
              if (statusChanged) {
                _handleStatusChange(_previousStatus, updatedOrder.orderStatus);
                _previousStatus = updatedOrder.orderStatus;
              }

              // ✅ Stop tracking if order is completed
              if (updatedOrder.orderStatus.isCompleted) {
                print('✅ HistoryDetailPage: Order completed, stopping tracking');
                timer.cancel();

                // ✅ Reload reviews for completed orders with safe conversion
                await _loadOrderReviews(safeUpdatedOrderData);
                if (_orderReviews != null || _driverReviews != null) {
                  _reviewCardController.forward();
                }
              }
            }
          } catch (e) {
            print('❌ HistoryDetailPage: Error updating order status: $e');
            // Don't stop tracking on temporary errors
          }
        });
  }

  // ✅ Handle status change notifications and animations
  void _handleStatusChange(OrderStatus? previousStatus, OrderStatus newStatus) {
    String? notification;

    switch (newStatus) {
      case OrderStatus.confirmed:
        notification = 'Pesanan Anda telah dikonfirmasi oleh toko.';
        break;
      case OrderStatus.preparing:
        notification = 'Pesanan Anda sedang diproses oleh toko.';
        break;
      case OrderStatus.readyForPickup:
        notification = 'Pesanan Anda siap untuk diambil oleh driver.';
        break;
      case OrderStatus.delivered:
        notification = 'Pesanan Anda telah selesai diantar.';
        break;
      case OrderStatus.cancelled:
        notification = 'Pesanan Anda telah dibatalkan.';
        break;
      case OrderStatus.rejected:
        notification = 'Pesanan Anda ditolak oleh toko.';
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

  // ✅ UPDATED: Enhanced rating submission using updated OrderService
  Future<void> _handleRatingSubmission() async {
    if (_orderDetail == null) return;

    try {
      print(
          '⭐ HistoryDetailPage: Opening rating page for order: ${_orderDetail!.id}');

      // ✅ Validate customer access before rating using updated method
      final hasAccess = await AuthService.validateCustomerAccess();
      if (!hasAccess) {
        throw Exception(
            'Access denied: Customer authentication required for rating');
      }

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RatingCustomerPage(
            order: _orderDetail!,
          ),
        ),
      );

      if (result != null && result is Map<String, dynamic>) {
        print('📝 HistoryDetailPage: Rating received, submitting review...');

        // ✅ Submit review using updated OrderService.createReview()
        await OrderService.createReview(
          orderId: _orderDetail!.id.toString(),
          orderReview: {
            'rating': result['storeRating'] ?? 5,
            'comment': result['storeComment'] ?? '',
          },
          driverReview: {
            'rating': result['driverRating'] ?? 5,
            'comment': result['driverComment'] ?? '',
          },
        );

        print('✅ HistoryDetailPage: Review submitted successfully');

        // ✅ Reload order data to get updated reviews
        await _loadOrderDetail();

        if (_orderReviews != null || _driverReviews != null) {
          _reviewCardController.forward();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Rating berhasil dikirim. Terima kasih!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ HistoryDetailPage: Error handling rating submission: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengirim rating: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  // ✅ FIXED: Cancel order using updated validation and new cancelOrderByCustomer method
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

      // ✅ Validate customer access before cancelling using updated method
      final hasAccess = await AuthService.validateCustomerAccess();
      if (!hasAccess) {
        throw Exception('Access denied: Customer authentication required');
      }

      // ✅ Validate using getRoleSpecificData and getUserData
      final userData = await AuthService.getUserData();
      final roleData = await AuthService.getRoleSpecificData();

      if (userData == null || roleData == null) {
        throw Exception('Authentication required: Please login');
      }

      print('✅ HistoryDetailPage: Authentication validated for cancellation');
      print('   - User Data Keys: ${userData.keys.toList()}');
      print('   - Role Data Keys: ${roleData.keys.toList()}');

      // ✅ Use new cancelOrderByCustomer method first, fallback to updateOrderStatus
      try {
        await OrderService.cancelOrderByCustomer(
          orderId: _orderDetail!.id.toString(),
          cancellationReason: 'Cancelled by customer from mobile app',
        );
        print('✅ HistoryDetailPage: Order cancelled using cancelOrderByCustomer');
      } catch (cancelError) {
        print('⚠️ HistoryDetailPage: cancelOrderByCustomer failed, trying updateOrderStatus: $cancelError');

        // Fallback to updateOrderStatus
        await OrderService.updateOrderStatus(
          orderId: _orderDetail!.id.toString(),
          orderStatus: 'cancelled',
          notes: 'Cancelled by customer from mobile app',
        );
        print('✅ HistoryDetailPage: Order cancelled using updateOrderStatus fallback');
      }

      // ✅ Refresh order detail
      await _loadOrderDetail();

      print('✅ HistoryDetailPage: Order cancelled successfully');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Pesanan berhasil dibatalkan'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      print('❌ HistoryDetailPage: Error cancelling order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membatalkan pesanan: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      setState(() {
        _isCancelling = false;
      });
    }
  }

  // Helper methods for UI components
  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.delivered:
        return Colors.green;
      case OrderStatus.cancelled:
      case OrderStatus.rejected:
        return Colors.red;
      case OrderStatus.onDelivery:
        return Colors.blue;
      case OrderStatus.preparing:
        return Colors.orange;
      default:
        return GlobalStyle.primaryColor;
    }
  }

  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Menunggu';
      case OrderStatus.confirmed:
        return 'Dikonfirmasi';
      case OrderStatus.preparing:
        return 'Diproses';
      case OrderStatus.readyForPickup:
        return 'Siap Diambil';
      case OrderStatus.onDelivery:
        return 'Diantar';
      case OrderStatus.delivered:
        return 'Selesai';
      case OrderStatus.cancelled:
        return 'Dibatalkan';
      case OrderStatus.rejected:
        return 'Ditolak';
      default:
        return 'Unknown';
    }
  }

  // ✅ FIXED: Payment method text - removed closure issue
  String _getPaymentMethodText() {
    // Default payment method since backend doesn't store this field
    return 'Tunai (COD)';
  }

  // ✅ INTEGRATED ORDER STATUS CARD: Built directly into the page
  // ✅ FIXED: Order Status Card with improved layout and no label text below icons
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
                      ),
                    ),

                  const SizedBox(height: 20),

                  // ✅ FIXED: Status Timeline without label text - cleaner layout
                  if (![OrderStatus.cancelled, OrderStatus.rejected]
                      .contains(currentStatus))
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: List.generate(_statusTimeline.length, (index) {
                          final isActive = index <= currentIndex;
                          final isCurrent = index == currentIndex;
                          final isLast = index == _statusTimeline.length - 1;
                          final statusItem = _statusTimeline[index];

                          return Expanded(
                            child: Row(
                              children: [
                                // ✅ FIXED: Only icon without text below
                                Expanded(
                                  child: Center(
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 300),
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
                                // ✅ FIXED: Connector line
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

  Map<String, dynamic> _getCurrentStatusInfo() {
    if (_orderDetail == null) {
      return _statusTimeline[0];
    }

    final currentStatus = _orderDetail!.orderStatus;

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
        'description': 'Pesanan ditolak toko',
        'icon': Icons.block,
        'color': Colors.red,
        'animation': 'assets/animations/cancel.json'
      };
    }

    return _statusTimeline.firstWhere(
          (item) => item['status'] == currentStatus,
      orElse: () => _statusTimeline[0],
    );
  }

  int _getCurrentStatusIndex() {
    if (_orderDetail == null) return 0;
    final currentStatus = _orderDetail!.orderStatus;
    return _statusTimeline
        .indexWhere((item) => item['status'] == currentStatus);
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
          // ✅ INTEGRATED: Order Status Card directly built in
          SlideTransition(
            position: _cardAnimations[0],
            child: _buildOrderStatusCard(),
          ),

          // Order Date and Status Section
          _buildCard(
            index: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today, color: GlobalStyle.primaryColor),
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
                _buildInfoRow(
                    'Tanggal Pesanan',
                    DateFormat('dd MMM yyyy, hh.mm a')
                        .format(_orderDetail!.createdAt)),
                const SizedBox(height: 8),
                _buildInfoRow('Status Pesanan',
                    _getStatusText(_orderDetail!.orderStatus)),
                const SizedBox(height: 8),
                _buildInfoRow(
                    'Total Pembayaran', _orderDetail!.formatTotalAmount()),
              ],
            ),
          ),

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
                // ✅ FIXED: Use correct subtotal calculation
                _buildPaymentRow('Subtotal', _orderDetail!.subtotal),
                const SizedBox(height: 12),
                _buildPaymentRow('Biaya Pengiriman', _orderDetail!.deliveryFee),
                const Divider(thickness: 1, height: 24),
                // ✅ FIXED: Use correct total calculation
                _buildPaymentRow('Total', _orderDetail!.totalAmount,
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
                  // ✅ FIXED: Call method properly without closure
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

            // Contact buttons for active orders
            if (!_orderDetail!.orderStatus.isCompleted)
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

  // ✅ FIXED: Enhanced action buttons with fixed "Beli Lagi" visibility
  Widget _buildActionButtonsCard() {
    final bool canCancel =
        _orderDetail!.canBeCancelled && !_orderDetail!.orderStatus.isCompleted;
    final bool canRate =
        _orderDetail!.orderStatus == OrderStatus.delivered && !_hasGivenRating;
    final bool isCompleted = _orderDetail!.orderStatus.isCompleted;

    return _buildCard(
      index: 4,
      child: Column(
        children: [
          // Cancel Order Button (only for pending/confirmed orders)
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

          // Rate Order Button (only for delivered orders without rating)
          if (canRate)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.star),
                  label: const Text('Beri Rating'),
                  onPressed: _handleRatingSubmission,
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
            ),

          // ✅ FIXED: Buy Again Button (only for completed orders - delivered or cancelled)
          if (isCompleted)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.shopping_bag),
                label: const Text('Beli Lagi'),
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    HomePage.route,
                        (route) => false,
                  );
                },
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