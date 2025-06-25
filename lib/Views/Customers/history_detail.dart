import 'package:flutter/material.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';

// Import Models
import 'package:del_pick/Models/order.dart';
import 'package:del_pick/Models/driver.dart';
import 'package:del_pick/Models/store.dart';
import 'package:del_pick/Models/menu_item.dart';
import 'package:del_pick/Models/order_enum.dart';
import 'package:del_pick/Models/order_item.dart';

// Import Services
import 'package:del_pick/Services/order_service.dart';
import 'package:del_pick/Services/driver_service.dart';
import 'package:del_pick/Services/store_service.dart';
import 'package:del_pick/Services/menu_service.dart';
import 'package:del_pick/Services/image_service.dart';
import 'package:del_pick/Services/auth_service.dart';

// Import Components
import '../Component/cust_order_status.dart';
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

class _HistoryDetailPageState extends State<HistoryDetailPage> with TickerProviderStateMixin {
  // Animation controllers
  late List<AnimationController> _cardControllers;
  late List<Animation<Offset>> _cardAnimations;
  late AnimationController _driverCardController;
  late AnimationController _reviewCardController;
  late Animation<Offset> _driverCardAnimation;
  late Animation<Offset> _reviewCardAnimation;

  // State variables
  bool _isLoading = false;
  bool _isLoadingDriver = false;
  bool _isLoadingStore = false;
  bool _isLoadingReviews = false;
  bool _isCancelling = false;
  String? _errorMessage;

  // Data objects
  OrderModel? _orderDetail;
  DriverModel? _driverDetail;
  StoreModel? _storeDetail;
  List<MenuItemModel> _menuItems = [];
  Map<String, dynamic>? _orderReviews;
  Map<String, dynamic>? _driverReviews;
  Map<String, dynamic>? _customerData;

  // Status tracking
  Timer? _statusUpdateTimer;
  bool _hasGivenRating = false;

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
    _statusUpdateTimer?.cancel();
    super.dispose();
  }

  // ✅ PERBAIKAN: Validate customer access and load data
  Future<void> _validateAndLoadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('🔍 HistoryDetailPage: Validating customer access...');

      // ✅ PERBAIKAN: Validate customer access first
      final hasAccess = await AuthService.validateCustomerAccess();
      if (!hasAccess) {
        throw Exception('Access denied: Customer authentication required');
      }

      // ✅ PERBAIKAN: Get customer data
      _customerData = await AuthService.getCustomerData();
      if (_customerData == null) {
        throw Exception('Unable to retrieve customer data');
      }

      print('✅ HistoryDetailPage: Customer access validated');
      print('   - Customer ID: ${_customerData!['id']}');
      print('   - Customer Name: ${_customerData!['name']}');

      // Load order detail
      await _loadOrderDetail();

      setState(() {
        _isLoading = false;
      });

      // Start animations for loaded content
      if (_driverDetail != null) {
        _driverCardController.forward();
      }
      if (_orderReviews != null || _driverReviews != null) {
        _reviewCardController.forward();
      }
    } catch (e) {
      print('❌ HistoryDetailPage: Validation/Load error: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load order details: $e';
      });
    }
  }

  // ✅ PERBAIKAN: Load order detail using OrderService.getOrderById() with enhanced auth
  Future<void> _loadOrderDetail() async {
    try {
      print('🔍 HistoryDetailPage: Loading order detail: ${widget.order.id}');

      // ✅ PERBAIKAN: Ensure valid user session
      final hasValidSession = await AuthService.ensureValidUserData();
      if (!hasValidSession) {
        throw Exception('Invalid user session. Please login again.');
      }

      // Get order detail with enhanced error handling
      final orderData = await OrderService.getOrderById(widget.order.id.toString());
      _orderDetail = OrderModel.fromJson(orderData);

      print('✅ HistoryDetailPage: Order detail loaded successfully');
      print('   - Order Status: ${_orderDetail!.orderStatus.name}');
      print('   - Driver ID: ${_orderDetail?.driverId}');
      print('   - Store ID: ${_orderDetail?.storeId}');

      // Load related data
      await Future.wait([
        _loadDriverDetail(),
        _loadStoreDetail(),
        _loadOrderReviews(),
      ]);

      // Start status tracking if order is not completed
      if (!_orderDetail!.orderStatus.isCompleted) {
        _startStatusTracking();
      }
    } catch (e) {
      print('❌ HistoryDetailPage: Error loading order detail: $e');
      throw Exception('Failed to load order details: $e');
    }
  }

  // ✅ PERBAIKAN: Load driver detail using DriverService.getDriverById() with validation
  Future<void> _loadDriverDetail() async {
    if (_orderDetail?.driverId == null) {
      print('⚠️ HistoryDetailPage: No driver assigned to this order');
      return;
    }

    setState(() {
      _isLoadingDriver = true;
    });

    try {
      print('🔍 HistoryDetailPage: Loading driver detail: ${_orderDetail!.driverId}');

      final driverData = await DriverService.getDriverById(_orderDetail!.driverId.toString());
      setState(() {
        _driverDetail = DriverModel.fromJson(driverData);
        _isLoadingDriver = false;
      });

      print('✅ HistoryDetailPage: Driver detail loaded successfully');
      print('   - Driver Name: ${_driverDetail!.name}');
      print('   - Driver Rating: ${_driverDetail!.rating}');
    } catch (e) {
      setState(() {
        _isLoadingDriver = false;
      });
      print('❌ HistoryDetailPage: Error loading driver detail: $e');
    }
  }

  // ✅ PERBAIKAN: Load store detail using StoreService.getStoreById() with validation
  Future<void> _loadStoreDetail() async {
    if (_orderDetail?.storeId == null) {
      print('⚠️ HistoryDetailPage: No store ID found for this order');
      return;
    }

    setState(() {
      _isLoadingStore = true;
    });

    try {
      print('🔍 HistoryDetailPage: Loading store detail: ${_orderDetail!.storeId}');

      final storeData = await StoreService.getStoreById(_orderDetail!.storeId.toString());
      if (storeData['success'] == true && storeData['data'] != null) {
        _storeDetail = StoreModel.fromJson(storeData['data']);

        print('✅ HistoryDetailPage: Store detail loaded successfully');
        print('   - Store Name: ${_storeDetail!.name}');
        print('   - Store Rating: ${_storeDetail!.rating}');

        // Load menu items from store using MenuService.getMenuItemsByStore()
        try {
          final menuData = await MenuItemService.getMenuItemsByStore(
            storeId: _orderDetail!.storeId.toString(),
            page: 1,
            limit: 50,
          );

          if (menuData['success'] == true && menuData['data'] != null) {
            _menuItems = (menuData['data'] as List)
                .map((item) => MenuItemModel.fromJson(item))
                .toList();
            print('✅ HistoryDetailPage: Menu items loaded: ${_menuItems.length} items');
          }
        } catch (menuError) {
          print('⚠️ HistoryDetailPage: Error loading menu items: $menuError');
        }
      }

      setState(() {
        _isLoadingStore = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingStore = false;
      });
      print('❌ HistoryDetailPage: Error loading store detail: $e');
    }
  }

  // ✅ PERBAIKAN: Load existing reviews with enhanced structure
  Future<void> _loadOrderReviews() async {
    setState(() {
      _isLoadingReviews = true;
    });

    try {
      print('🔍 HistoryDetailPage: Loading order reviews...');

      // Get fresh order data to check for reviews
      final orderData = await OrderService.getOrderById(_orderDetail!.id.toString());

      // ✅ PERBAIKAN: Check for reviews in different possible structures
      if (orderData['orderReviews'] != null) {
        final reviews = orderData['orderReviews'];
        if (reviews is List && reviews.isNotEmpty) {
          _orderReviews = Map<String, dynamic>.from(reviews.first as Map);
          print('✅ HistoryDetailPage: Order review found');
        } else if (reviews is Map) {
          _orderReviews = Map<String, dynamic>.from(reviews as Map);
          print('✅ HistoryDetailPage: Order review found (Map structure)');
        }
      }

      if (orderData['driverReviews'] != null) {
        final reviews = orderData['driverReviews'];
        if (reviews is List && reviews.isNotEmpty) {
          _driverReviews = Map<String, dynamic>.from(reviews.first as Map);
          print('✅ HistoryDetailPage: Driver review found');
        } else if (reviews is Map) {
          _driverReviews = Map<String, dynamic>.from(reviews as Map);
          print('✅ HistoryDetailPage: Driver review found (Map structure)');
        }
      }

      // ✅ PERBAIKAN: Alternative review structure check
      if (orderData['reviews'] != null) {
        final reviews = orderData['reviews'] as List;
        for (var review in reviews) {
          if (review['type'] == 'store' || review['target_type'] == 'store') {
            _orderReviews = review;
          } else if (review['type'] == 'driver' || review['target_type'] == 'driver') {
            _driverReviews = review;
          }
        }
      }

      // Check if user has given rating
      _hasGivenRating = _orderReviews != null || _driverReviews != null;

      print('📊 HistoryDetailPage: Review status:');
      print('   - Has Order Review: ${_orderReviews != null}');
      print('   - Has Driver Review: ${_driverReviews != null}');
      print('   - Has Given Rating: $_hasGivenRating');

      setState(() {
        _isLoadingReviews = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingReviews = false;
      });
      print('❌ HistoryDetailPage: Error loading reviews: $e');
    }
  }

  // ✅ PERBAIKAN: Enhanced status tracking for active orders
  void _startStatusTracking() {
    if (_orderDetail == null || _orderDetail!.orderStatus.isCompleted) {
      print('⚠️ HistoryDetailPage: Order is completed, skipping status tracking');
      return;
    }

    print('🔄 HistoryDetailPage: Starting status tracking for order ${_orderDetail!.id}');

    _statusUpdateTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      if (!mounted) {
        print('⚠️ HistoryDetailPage: Widget unmounted, stopping timer');
        timer.cancel();
        return;
      }

      try {
        print('📡 HistoryDetailPage: Checking order status update...');

        // ✅ PERBAIKAN: Ensure valid session before API call
        final hasValidSession = await AuthService.ensureValidUserData();
        if (!hasValidSession) {
          print('❌ HistoryDetailPage: Invalid session, stopping tracking');
          timer.cancel();
          return;
        }

        final updatedOrderData = await OrderService.getOrderById(widget.order.id.toString());
        final updatedOrder = OrderModel.fromJson(updatedOrderData);

        if (mounted) {
          print('✅ HistoryDetailPage: Order status updated: ${updatedOrder.orderStatus.name}');

          setState(() {
            _orderDetail = updatedOrder;
          });

          // Load driver if newly assigned
          if (updatedOrder.driverId != null && _driverDetail == null) {
            print('🚗 HistoryDetailPage: New driver assigned, loading driver details...');
            await _loadDriverDetail();
            if (_driverDetail != null) {
              _driverCardController.forward();
            }
          }

          // Stop tracking if order is completed
          if (updatedOrder.orderStatus.isCompleted) {
            print('✅ HistoryDetailPage: Order completed, stopping tracking');
            timer.cancel();
            await _loadOrderReviews();
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

  // ✅ PERBAIKAN: Cancel order using OrderService.cancelOrder() with validation
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
            child: const Text('Ya, Batalkan', style: TextStyle(color: Colors.white)),
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

      // ✅ PERBAIKAN: Validate customer access before cancelling
      final hasAccess = await AuthService.validateCustomerAccess();
      if (!hasAccess) {
        throw Exception('Access denied: Customer authentication required');
      }

      await OrderService.cancelOrder(_orderDetail!.id.toString());

      // Refresh order detail
      await _loadOrderDetail();

      print('✅ HistoryDetailPage: Order cancelled successfully');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Pesanan berhasil dibatalkan'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      setState(() {
        _isCancelling = false;
      });
    }
  }

  // ✅ PERBAIKAN: Handle rating submission using OrderService.createReview() with validation
  Future<void> _handleRatingSubmission() async {
    if (_orderDetail == null) return;

    try {
      print('⭐ HistoryDetailPage: Opening rating page for order: ${_orderDetail!.id}');

      // ✅ PERBAIKAN: Validate customer access before rating
      final hasAccess = await AuthService.validateCustomerAccess();
      if (!hasAccess) {
        throw Exception('Access denied: Customer authentication required for rating');
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

        // ✅ PERBAIKAN: Submit review using OrderService.createReview()
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

        // Reload reviews to display them
        await _loadOrderReviews();

        if (_orderReviews != null || _driverReviews != null) {
          _reviewCardController.forward();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Rating berhasil dikirim. Terima kasih!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  // Call driver
  Future<void> _callDriver() async {
    if (_driverDetail?.phone == null || _driverDetail!.phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nomor telepon driver tidak tersedia'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final Uri uri = Uri.parse('tel:${_driverDetail!.phone}');
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

  // Message driver
  Future<void> _messageDriver() async {
    if (_driverDetail?.phone == null || _driverDetail!.phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nomor telepon driver tidak tersedia'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final Uri uri = Uri.parse('sms:${_driverDetail!.phone}');
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xffF0F7FF),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          title: const Text('Detail Pesanan', style: TextStyle(color: Colors.black)),
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(7.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: GlobalStyle.primaryColor, width: 1.0),
              ),
              child: Icon(Icons.arrow_back_ios_new, color: GlobalStyle.primaryColor, size: 18),
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
          title: const Text('Detail Pesanan', style: TextStyle(color: Colors.black)),
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(7.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: GlobalStyle.primaryColor, width: 1.0),
              ),
              child: Icon(Icons.arrow_back_ios_new, color: GlobalStyle.primaryColor, size: 18),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
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
            child: Icon(Icons.arrow_back_ios_new, color: GlobalStyle.primaryColor, size: 18),
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
          // ✅ PERBAIKAN: CustomerOrderStatusCard integration
          if (_orderDetail != null)
            SlideTransition(
              position: _cardAnimations[0],
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                child: CustomerOrderStatusCard(
                  initialOrderData: {
                    'id': _orderDetail!.id,
                    'order_status': _orderDetail!.orderStatus.name,
                    'total': _orderDetail!.totalAmount,
                    'estimatedDeliveryTime': _orderDetail!.estimatedDeliveryTime?.toIso8601String() ??
                        DateTime.now().add(const Duration(minutes: 30)).toIso8601String(),
                    'store': _storeDetail != null ? {
                      'name': _storeDetail!.name,
                      'address': _storeDetail!.address,
                      'phone': _storeDetail!.phone,
                    } : null,
                    'driver': _driverDetail != null ? {
                      'name': _driverDetail!.name,
                      'phone': _driverDetail!.phone,
                      'vehicle_plate': _driverDetail!.vehiclePlate,
                      'rating': _driverDetail!.rating,
                    } : null,
                    'customer': _customerData != null ? {
                      'name': _customerData!['name'],
                      'phone': _customerData!['phone'] ?? '',
                      'avatar': _customerData!['avatar'],
                    } : null,
                  },
                ),
              ),
            ),

          // Order Date Section
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
                      'Tanggal Pesanan',
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
                Text(
                  _orderDetail != null
                      ? DateFormat('dd MMM yyyy, hh.mm a').format(_orderDetail!.createdAt)
                      : 'Tanggal tidak tersedia',
                  style: TextStyle(
                    color: GlobalStyle.fontColor,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
                if (_orderDetail?.orderStatus != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _getStatusColor(_orderDetail!.orderStatus).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        _getStatusText(_orderDetail!.orderStatus),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(_orderDetail!.orderStatus),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Delivery Address Section
          _buildCard(
            index: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on, color: GlobalStyle.primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'Alamat Pengiriman',
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
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.home_rounded, color: GlobalStyle.primaryColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _orderDetail?.deliveryAddress ?? 'Alamat tidak tersedia',
                          style: TextStyle(
                            color: GlobalStyle.fontColor,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Driver Information Section
          if (_driverDetail != null || _isLoadingDriver)
            _buildDriverCard(),

          // Store and Items Section
          if (_orderDetail != null)
            _buildStoreAndItemsCard(),

          // Payment Details Section
          if (_orderDetail != null)
            _buildPaymentDetailsCard(),

          // Reviews Section (shown after rating is given)
          if (_orderReviews != null || _driverReviews != null)
            _buildReviewsCard(),

          // Action Buttons Section
          if (_orderDetail != null)
            _buildActionButtonsCard(),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

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
            if (_isLoadingDriver)
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(color: Colors.orange),
                    SizedBox(height: 12),
                    Text('Memuat data driver...'),
                  ],
                ),
              )
            else if (_driverDetail != null)
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
                    child: _driverDetail!.avatar != null && _driverDetail!.avatar!.isNotEmpty
                        ? ClipOval(
                      child: ImageService.displayImage(
                        imageSource: _driverDetail!.avatar!,
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
                                _driverDetail!.name,
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
                                  const Icon(Icons.star, color: Colors.amber, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    _driverDetail!.rating.toStringAsFixed(1),
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
                              Icon(Icons.motorcycle, color: Colors.grey[700], size: 16),
                              const SizedBox(width: 4),
                              Text(
                                _driverDetail!.vehiclePlate,
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
                          '${_driverDetail!.reviewsCount} reviews',
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
              )
            else
              const Center(
                child: Text(
                  'Driver belum ditugaskan',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ),

            // Contact buttons for active orders
            if (_driverDetail != null &&
                _orderDetail != null &&
                !_orderDetail!.orderStatus.isCompleted)
              Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.call, color: Colors.white, size: 18),
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
                        onPressed: _callDriver,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.message, color: Colors.white, size: 18),
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
                        onPressed: _messageDriver,
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

  Widget _buildStoreAndItemsCard() {
    return _buildCard(
      index: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.store, color: GlobalStyle.primaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _storeDetail?.name ?? _orderDetail!.store?.name ?? 'Store',
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
          if (_storeDetail != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _storeDetail!.address,
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
                child: const Icon(Icons.image_not_supported, color: Colors.grey),
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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

  Widget _buildPaymentDetailsCard() {
    return _buildCard(
      index: 4,
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
                _buildPaymentRow('Total', _orderDetail!.totalAmount, isTotal: true),
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
                  'Pembayaran: ${_getPaymentMethodText(_orderDetail!.paymentMethod)}',
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
                          const Icon(Icons.delivery_dining, color: Colors.orange, size: 20),
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
                    Icon(Icons.check_circle, color: Colors.green[700], size: 16),
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
    final bool canCancel = _orderDetail!.canBeCancelled &&
        !_orderDetail!.orderStatus.isCompleted;
    final bool canRate = _orderDetail!.orderStatus == OrderStatus.delivered &&
        !_hasGivenRating;
    final bool isCompleted = _orderDetail!.orderStatus.isCompleted;

    return _buildCard(
      index: 5,
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
                  label: Text(_isCancelling ? 'Membatalkan...' : 'Batalkan Pesanan'),
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

          // Buy Again Button (always shown)
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
                backgroundColor: isCompleted ? GlobalStyle.primaryColor : Colors.white,
                foregroundColor: isCompleted ? Colors.white : GlobalStyle.primaryColor,
                side: isCompleted ? null : BorderSide(color: GlobalStyle.primaryColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: isCompleted ? 2 : 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.delivered:
        return Colors.green;
      case OrderStatus.cancelled:
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

  String _getPaymentMethodText(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return 'Tunai';
      default:
        return 'Unknown';
    }
  }
}