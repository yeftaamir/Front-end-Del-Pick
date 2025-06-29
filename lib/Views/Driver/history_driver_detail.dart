import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:lottie/lottie.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';

// Import updated services
import 'package:del_pick/Services/driver_request_service.dart';
import 'package:del_pick/Services/order_service.dart';
import 'package:del_pick/Services/tracking_service.dart';
import 'package:del_pick/Services/image_service.dart';
import 'package:del_pick/Services/auth_service.dart';

// Import Models
import 'package:del_pick/Models/order.dart';
import 'package:del_pick/Models/order_enum.dart';

class HistoryDriverDetailPage extends StatefulWidget {
  static const String route = '/Driver/HistoryDriverDetail';
  final String orderId;
  final String? requestId; // Driver request ID
  final Map<String, dynamic>? orderDetail;

  const HistoryDriverDetailPage({
    Key? key,
    required this.orderId,
    this.requestId,
    this.orderDetail,
  }) : super(key: key);

  @override
  _HistoryDriverDetailPageState createState() =>
      _HistoryDriverDetailPageState();
}

class _HistoryDriverDetailPageState extends State<HistoryDriverDetailPage>
    with TickerProviderStateMixin {
  // Audio player initialization
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Animation controllers for card sections
  late List<AnimationController> _cardControllers;
  late List<Animation<Offset>> _cardAnimations;
  late AnimationController _statusController;

  // Driver Order Status Card Animation Controllers
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  OrderModel? _currentOrder;
  OrderStatus? _previousOrderStatus;
  DeliveryStatus? _previousDeliveryStatus;
  Timer? _statusUpdateTimer;

  // Data state
  Map<String, dynamic> _requestData = {};
  Map<String, dynamic> _orderData = {};
  Map<String, dynamic>? _customerData;
  Map<String, dynamic>? _storeData;
  Map<String, dynamic>? _driverData;
  List<dynamic> _orderItems = [];

  bool _isLoading = true;
  bool _isUpdatingStatus = false;
  bool _isRespondingRequest = false;
  bool _hasError = false;
  String _errorMessage = '';

  // Driver-specific color theme for status card
  final Color _primaryColor = const Color(0xFF2E7D32);
  final Color _secondaryColor = const Color(0xFF66BB6A);

  // ✅ UPDATED: Dual status timeline untuk order_status dan delivery_status
  final List<Map<String, dynamic>> _orderStatusTimeline = [
    {
      'status': OrderStatus.pending,
      'label': 'Menunggu',
      'description': 'Pesanan baru masuk',
      'icon': Icons.schedule,
      'color': Colors.orange,
    },
    {
      'status': OrderStatus.preparing,
      'label': 'Disiapkan',
      'description': 'Toko sedang menyiapkan',
      'icon': Icons.restaurant,
      'color': Colors.purple,
    },
    {
      'status': OrderStatus.readyForPickup,
      'label': 'Siap Diambil',
      'description': 'Pesanan siap diambil',
      'icon': Icons.shopping_bag,
      'color': Colors.indigo,
    },
    // Delivery statuses dalam timeline
    {
      'status': 'on_way', // Dari delivery status
      'label': 'Diantar',
      'description': 'Dalam perjalanan',
      'icon': Icons.directions_bike,
      'color': Colors.teal,
    },
    {
      'status': 'delivered', // Dari delivery status
      'label': 'Selesai',
      'description': 'Pesanan selesai',
      'icon': Icons.check_circle,
      'color': Colors.green,
    },
  ];

  final List<Map<String, dynamic>> _deliveryStatusTimeline = [
    {
      'status': DeliveryStatus.pending,
      'label': 'Menunggu',
      'description': 'Menunggu driver',
      'icon': Icons.schedule,
      'color': Colors.orange,
      'animation': 'assets/animations/diambil.json'
    },
    {
      'status': DeliveryStatus.pickedUp,
      'label': 'Diambil',
      'description': 'Driver mengambil pesanan',
      'icon': Icons.drive_eta,
      'color': Colors.blue,
      'animation': 'assets/animations/diproses.json'
    },
    {
      'status': DeliveryStatus.onWay,
      'label': 'Diantar',
      'description': 'Dalam perjalanan',
      'icon': Icons.directions_bike,
      'color': Colors.teal,
      'animation': 'assets/animations/diantar.json'
    },
    {
      'status': DeliveryStatus.delivered,
      'label': 'Selesai',
      'description': 'Pesanan terkirim',
      'icon': Icons.check_circle,
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
      5, // Status, Order Info, Store, Customer, Items cards
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

    // Initialize pulse animation for driver status card
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

  // ✅ ENHANCED: Comprehensive safe type conversion for deeply nested maps
  static Map<String, dynamic> _safeMapConversion(dynamic data) {
    if (data == null) return {};

    if (data is Map<String, dynamic>) {
      return Map<String, dynamic>.from(data);
    } else if (data is Map) {
      // Convert Map<dynamic, dynamic> to Map<String, dynamic> recursively
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

  // ✅ ENHANCED: Safe type conversion for lists containing maps
  static List<dynamic> _safeListConversion(List<dynamic> list) {
    return list.map((item) {
      if (item is Map && item is! Map<String, dynamic>) {
        return _safeMapConversion(item);
      }
      return item;
    }).toList();
  }

  // ✅ FIXED: Enhanced validation and data loading
  Future<void> _validateAndLoadData() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      print('🚗 HistoryDriverDetail: Starting validation and data loading...');

      // ✅ FIX: Simplified authentication check
      final isAuthenticated = await AuthService.isAuthenticated();
      if (!isAuthenticated) {
        _handleAuthenticationError();
        return;
      }

      // ✅ FIX: Optional role-specific data loading
      try {
        final roleData = await AuthService.getRoleSpecificData();
        if (roleData != null && roleData['driver'] != null) {
          _driverData = roleData['driver'];
          print(
              '✅ HistoryDriverDetail: Driver data loaded - ID: ${_driverData!['id']}');
        }
      } catch (e) {
        print('⚠️ Role data loading error (non-critical): $e');
        // Continue without driver data
      }

      print('✅ HistoryDriverDetail: Authentication validated');

      // Load request and order data dengan improved error handling
      await _loadRequestData();

      // Start animations
      _startAnimations();

      // Handle initial status
      if (_currentOrder != null || _orderData.isNotEmpty) {
        print('🎵 HistoryDriverDetail: Handling initial status animations...');
        _handleInitialStatuses();
      }

      // Start status polling
      _startStatusPolling();

      setState(() {
        _isLoading = false;
      });

      print('✅ HistoryDriverDetail: Data loading completed successfully');
    } catch (e) {
      print('❌ HistoryDriverDetail: Validation/loading error: $e');

      // ✅ FIX: Handle authentication errors specially
      if (e.toString().contains('authentication') ||
          e.toString().contains('Unauthorized') ||
          e.toString().contains('Access denied')) {
        _handleAuthenticationError();
        return;
      }

      setState(() {
        _hasError = true;
        _errorMessage = 'Gagal memuat data. Silakan coba lagi.';
        _isLoading = false;
      });
    }
  }

  // ✅ FIXED: Enhanced request data loading menggunakan DriverRequestService.getDriverRequestDetail
  Future<void> _loadRequestData() async {
    try {
      print('📋 HistoryDriverDetail: Loading request data...');

      // ✅ FIX: Simplified authentication check
      final isAuthenticated = await AuthService.isAuthenticated();
      if (!isAuthenticated) {
        throw Exception('Authentication required');
      }

      Map<String, dynamic> requestData;

      // ✅ FIX: Use requestId if available, otherwise use orderId
      if (widget.requestId != null) {
        requestData = await DriverRequestService.getDriverRequestDetail(
            widget.requestId!);
      } else {
        // ✅ FIX: Fallback to finding request by order ID dengan improved error handling
        try {
          final requests = await DriverRequestService.getDriverRequests(
            page: 1,
            limit: 50,
          );

          final requestsList = requests['requests'] as List? ?? [];
          final targetRequest = requestsList.firstWhere(
            (req) => req['order']?['id']?.toString() == widget.orderId,
            orElse: () => throw Exception('Request not found'),
          );

          requestData = targetRequest;
        } catch (e) {
          // ✅ FIX: If can't find by driver requests, try direct order approach
          print('⚠️ Driver request not found, using order data: $e');

          // Create minimal request data from order
          try {
            final orderData = await OrderService.getOrderById(widget.orderId);
            requestData = {
              'id': 'unknown',
              'status': 'accepted', // Assume accepted since we're in detail
              'order': orderData,
              'driver': _driverData,
            };
          } catch (orderError) {
            throw Exception('Failed to load order data: $orderError');
          }
        }
      }

      if (requestData.isNotEmpty) {
        setState(() {
          _requestData = requestData;
        });

        _processRequestData(requestData);
        print('✅ HistoryDriverDetail: Request data loaded successfully');
      } else {
        throw Exception('Request data not found or empty response');
      }
    } catch (e) {
      print('❌ HistoryDriverDetail: Error loading request data: $e');
      throw Exception('Failed to load request data: $e');
    }
  }

  Future<bool> _validateDriverAuthentication() async {
    try {
      // Check basic authentication
      final isAuth = await AuthService.isAuthenticated();
      if (!isAuth) {
        print('❌ Driver not authenticated');
        return false;
      }

      // Check if user has driver role
      final hasDriverRole = await AuthService.hasRole('driver');
      if (!hasDriverRole) {
        print('❌ User does not have driver role');
        return false;
      }

      // Validate session is still valid
      final sessionValid = await AuthService.isSessionValid();
      if (!sessionValid) {
        print('❌ Driver session invalid');
        return false;
      }

      print('✅ Driver authentication validated successfully');
      return true;
    } catch (e) {
      print('❌ Driver authentication validation error: $e');
      return false;
    }
  }

  void _handleOperationError(dynamic error, String operation) {
    print('❌ $operation error: $error');

    if (!mounted) return;

    String errorMessage = 'Terjadi kesalahan. Silakan coba lagi.';
    bool shouldRedirectToLogin = false;

    // Check for authentication errors
    final errorString = error.toString().toLowerCase();
    if (errorString.contains('unauthorized') ||
        errorString.contains('authentication') ||
        errorString.contains('access denied') ||
        errorString.contains('please login') ||
        errorString.contains('token') && errorString.contains('invalid')) {
      shouldRedirectToLogin = true;
      errorMessage = 'Sesi berakhir. Silakan login ulang.';
    } else if (errorString.contains('network') ||
        errorString.contains('connection')) {
      errorMessage = 'Koneksi bermasalah. Periksa internet Anda.';
    } else if (errorString.contains('permission') ||
        errorString.contains('access')) {
      errorMessage = 'Anda tidak memiliki akses untuk operasi ini.';
    } else if (errorString.contains('not found')) {
      errorMessage = 'Data tidak ditemukan. Mungkin sudah dihapus.';
    }

    if (shouldRedirectToLogin) {
      _handleAuthenticationError();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          action: operation.contains('update')
              ? SnackBarAction(
                  label: 'Coba Lagi',
                  textColor: Colors.white,
                  onPressed: () {
                    // Retry the last operation
                    if (operation.contains('delivery')) {
                      // Could implement retry logic here
                    }
                  },
                )
              : null,
        ),
      );
    }
  }

  void _handleAuthenticationError() {
    print(
        '🔐 HistoryDriverDetail: Authentication error detected, redirecting to login...');

    if (mounted) {
      // Clear any existing timers
      _statusUpdateTimer?.cancel();

      // Show authentication error dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(
              'Sesi Berakhir',
              style: TextStyle(
                fontFamily: GlobalStyle.fontFamily,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              'Sesi login Anda telah berakhir. Silakan login kembali untuk melanjutkan.',
              style: TextStyle(
                fontFamily: GlobalStyle.fontFamily,
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  // Clear auth data and redirect to login
                  AuthService.logout().then((_) {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/login',
                      (Route<dynamic> route) => false,
                    );
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlobalStyle.primaryColor,
                ),
                child: Text(
                  'Login Ulang',
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
  }

  void _processRequestData(Map<String, dynamic> requestData) {
    try {
      // Extract order data from request
      _orderData = requestData['order'] ?? {};

      // ✅ CRITICAL: Safe conversion before creating OrderModel
      final safeOrderData = _safeMapConversion(_orderData);

      // ✅ FIXED: Ensure proper dual status structure sesuai backend
      safeOrderData['order_status'] =
          safeOrderData['order_status'] ?? 'pending';
      safeOrderData['delivery_status'] =
          safeOrderData['delivery_status'] ?? 'pending';

      // ✅ FIX: Safe numeric conversion untuk mencegah type casting error
      safeOrderData['total_amount'] =
          _safeParseDouble(safeOrderData['total_amount']);
      safeOrderData['delivery_fee'] =
          _safeParseDouble(safeOrderData['delivery_fee']);
      safeOrderData['destination_latitude'] =
          _safeParseDouble(safeOrderData['destination_latitude']);
      safeOrderData['destination_longitude'] =
          _safeParseDouble(safeOrderData['destination_longitude']);

      // ✅ FIX: Safe conversion untuk ID fields
      safeOrderData['id'] = _safeParseInt(safeOrderData['id']);
      safeOrderData['customer_id'] =
          _safeParseInt(safeOrderData['customer_id']);
      safeOrderData['store_id'] = _safeParseInt(safeOrderData['store_id']);
      safeOrderData['driver_id'] = safeOrderData['driver_id'] != null
          ? _safeParseInt(safeOrderData['driver_id'])
          : null;

      // ✅ FIXED: Ensure required fields untuk OrderModel.fromJson()
      safeOrderData['created_at'] =
          safeOrderData['created_at'] ?? DateTime.now().toIso8601String();
      safeOrderData['updated_at'] =
          safeOrderData['updated_at'] ?? DateTime.now().toIso8601String();

      // ✅ FIXED: Process nested objects secara proper
      if (safeOrderData['customer'] != null) {
        safeOrderData['customer'] =
            _safeMapConversion(safeOrderData['customer']);
      }
      if (safeOrderData['store'] != null) {
        safeOrderData['store'] = _safeMapConversion(safeOrderData['store']);
      }
      if (safeOrderData['items'] != null) {
        safeOrderData['items'] = _safeListConversion(safeOrderData['items']);
      }

      print('📊 HistoryDriverDetail: Processing order data structure:');
      print('   - Order ID: ${safeOrderData['id']}');
      print('   - Order Status: ${safeOrderData['order_status']}');
      print('   - Delivery Status: ${safeOrderData['delivery_status']}');
      print('   - Total Amount: ${safeOrderData['total_amount']}');
      print(
          '   - Customer: ${safeOrderData['customer'] != null ? 'Available' : 'Null'}');
      print(
          '   - Store: ${safeOrderData['store'] != null ? 'Available' : 'Null'}');
      print(
          '   - Items count: ${(safeOrderData['items'] as List?)?.length ?? 0}');

      // ✅ FIXED: Create OrderModel dengan improved error handling
      try {
        _currentOrder = OrderModel.fromJson(safeOrderData);
        print('✅ HistoryDriverDetail: OrderModel created successfully');
        print('   - Order Status: ${_currentOrder!.orderStatus}');
        print('   - Delivery Status: ${_currentOrder!.deliveryStatus}');
      } catch (e) {
        print('⚠️ HistoryDriverDetail: Error creating OrderModel: $e');
        print('   - Attempting to create fallback OrderModel...');

        // ✅ FALLBACK: Create minimal OrderModel manually jika fromJson gagal
        try {
          _currentOrder = _createFallbackOrderModel(safeOrderData);
          print('✅ HistoryDriverDetail: Fallback OrderModel created');
        } catch (fallbackError) {
          print(
              '❌ HistoryDriverDetail: Fallback OrderModel creation failed: $fallbackError');
          print('   - Will continue without OrderModel, using raw data');
          // Continue without OrderModel, using raw data
        }
      }

      // Process customer data
      if (_orderData['customer'] != null) {
        _customerData = _orderData['customer'];
        _customerData!['name'] = _customerData!['name'] ?? 'Unknown Customer';
        _customerData!['phone'] = _customerData!['phone'] ?? '';

        // Process customer avatar
        if (_customerData!['avatar'] != null &&
            _customerData!['avatar'].toString().isNotEmpty) {
          _customerData!['avatar'] =
              ImageService.getImageUrl(_customerData!['avatar']);
        }
      }

      // Process store data
      if (_orderData['store'] != null) {
        _storeData = _orderData['store'];
        _storeData!['name'] = _storeData!['name'] ?? 'Unknown Store';
        _storeData!['phone'] = _storeData!['phone'] ?? '';

        // Process store image
        if (_storeData!['image_url'] != null &&
            _storeData!['image_url'].toString().isNotEmpty) {
          _storeData!['image_url'] =
              ImageService.getImageUrl(_storeData!['image_url']);
        }
      }

      // Process order items
      if (_orderData['items'] != null) {
        _orderItems = _orderData['items'] as List;
        for (var item in _orderItems) {
          // Process item image
          if (item['image_url'] != null &&
              item['image_url'].toString().isNotEmpty) {
            item['image_url'] = ImageService.getImageUrl(item['image_url']);
          }

          // ✅ FIX: Safe conversion untuk item fields
          item['name'] = item['name'] ?? 'Unknown Item';
          item['quantity'] = _safeParseInt(item['quantity']);
          item['price'] = _safeParseDouble(item['price']);
        }
      }

      // Process driver data from request
      if (requestData['driver'] != null) {
        final requestDriver = requestData['driver'];
        if (requestDriver['user'] != null) {
          final driverUser = requestDriver['user'];
          driverUser['name'] = driverUser['name'] ?? 'Driver';
          driverUser['phone'] = driverUser['phone'] ?? '';

          // Process driver avatar
          if (driverUser['avatar'] != null &&
              driverUser['avatar'].toString().isNotEmpty) {
            driverUser['avatar'] =
                ImageService.getImageUrl(driverUser['avatar']);
          }
        }
      }

      print('📊 HistoryDriverDetail: Request data processed successfully');
    } catch (e) {
      print('❌ HistoryDriverDetail: Error processing request data: $e');
    }
  }

  // ✅ NEW: Create fallback OrderModel when fromJson fails
  OrderModel _createFallbackOrderModel(Map<String, dynamic> orderData) {
    try {
      // Create minimal but functional OrderModel manually
      final fallbackData = <String, dynamic>{
        'id': orderData['id'] ?? 0,
        'customer_id': orderData['customer_id'] ?? 0,
        'store_id': orderData['store_id'] ?? 0,
        'driver_id': orderData['driver_id'],
        'order_status': orderData['order_status'] ?? 'pending',
        'delivery_status': orderData['delivery_status'] ?? 'pending',
        'total_amount': orderData['total_amount'] ?? 0.0,
        'delivery_fee': orderData['delivery_fee'] ?? 0.0,
        'destination_latitude': orderData['destination_latitude'],
        'destination_longitude': orderData['destination_longitude'],
        'pickup_address': orderData['pickup_address'] ?? '',
        'destination_address': orderData['destination_address'] ?? '',
        'notes': orderData['notes'] ?? '',
        'created_at':
            orderData['created_at'] ?? DateTime.now().toIso8601String(),
        'updated_at':
            orderData['updated_at'] ?? DateTime.now().toIso8601String(),

        // Add nested objects if available
        'customer': orderData['customer'],
        'store': orderData['store'],
        'items': orderData['items'] ?? [],
      };

      return OrderModel.fromJson(fallbackData);
    } catch (e) {
      print('❌ Fallback OrderModel creation error: $e');
      throw Exception('Cannot create fallback OrderModel: $e');
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

  // ✅ UPDATED: Handle initial statuses untuk dual status dengan fallback
  void _handleInitialStatuses() {
    // ✅ FIXED: Get status dengan fallback mechanism
    String orderStatus = 'pending';
    String deliveryStatus = 'pending';

    if (_currentOrder != null) {
      orderStatus = _currentOrder!.orderStatus.value;
      deliveryStatus = _currentOrder!.deliveryStatus.value;
    } else if (_orderData.isNotEmpty) {
      orderStatus = _orderData['order_status']?.toString() ?? 'pending';
      deliveryStatus = _orderData['delivery_status']?.toString() ?? 'pending';
    }

    if (['cancelled', 'rejected'].contains(orderStatus)) {
      _playCancelSound();
    } else if (orderStatus == 'pending' && deliveryStatus == 'pending') {
      _pulseController.repeat(reverse: true);
    }

    // Store previous statuses for change detection
    _previousOrderStatus = OrderStatus.fromString(orderStatus);
    _previousDeliveryStatus = DeliveryStatus.fromString(deliveryStatus);
  }

  // ✅ UPDATED: Handle status changes untuk dual status dengan fallback
  void _handleStatusChanges() {
    // ✅ FIXED: Get current status dengan fallback
    String newOrderStatus = 'pending';
    String newDeliveryStatus = 'pending';

    if (_currentOrder != null) {
      newOrderStatus = _currentOrder!.orderStatus.value;
      newDeliveryStatus = _currentOrder!.deliveryStatus.value;
    } else if (_orderData.isNotEmpty) {
      newOrderStatus = _orderData['order_status']?.toString() ?? 'pending';
      newDeliveryStatus =
          _orderData['delivery_status']?.toString() ?? 'pending';
    }

    final newOrderStatusEnum = OrderStatus.fromString(newOrderStatus);
    final newDeliveryStatusEnum = DeliveryStatus.fromString(newDeliveryStatus);

    // Check for order status changes (dengan null safety)
    if (_previousOrderStatus != null &&
        _previousOrderStatus != newOrderStatusEnum) {
      if (['cancelled', 'rejected'].contains(newOrderStatus)) {
        _playCancelSound();
        _pulseController.stop();
      } else {
        _playStatusChangeSound();
      }
      _previousOrderStatus = newOrderStatusEnum;
    }

    // Check for delivery status changes (dengan null safety)
    if (_previousDeliveryStatus != null &&
        _previousDeliveryStatus != newDeliveryStatusEnum) {
      _playStatusChangeSound();
      _previousDeliveryStatus = newDeliveryStatusEnum;
    }

    // Update pulse animation based on current statuses
    if (newOrderStatus == 'pending' && newDeliveryStatus == 'pending') {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
    }
  }

  void _startStatusPolling() {
    _statusUpdateTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && widget.orderId != null) {
        // Check completion status
        bool isCompleted = false;

        if (_currentOrder != null) {
          isCompleted = _currentOrder!.orderStatus.isCompleted;
        } else if (_orderData.isNotEmpty) {
          final orderStatus =
              _orderData['order_status']?.toString() ?? 'pending';
          final deliveryStatus =
              _orderData['delivery_status']?.toString() ?? 'pending';
          isCompleted =
              ['delivered', 'cancelled', 'rejected'].contains(orderStatus) ||
                  ['delivered', 'rejected'].contains(deliveryStatus);
        }

        if (!isCompleted) {
          print('🔄 HistoryDriverDetail: Polling status update...');

          // ✅ FIX: Soft polling - tidak crash jika gagal
          _loadRequestData().catchError((error) {
            print('⚠️ Polling error (non-critical): $error');

            // ✅ FIX: Handle authentication errors in polling
            if (error.toString().contains('authentication') ||
                error.toString().contains('Unauthorized')) {
              timer.cancel();
              _handleAuthenticationError();
            }
          });
        } else {
          timer.cancel();
        }
      }
    });
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

  // ✅ UPDATED: Driver Order Status Card with dual status tracking
  Widget _buildDriverOrderStatusCard() {
    // ✅ FIXED: Pastikan selalu ada data untuk ditampilkan, tidak stuck di loading
    if (_currentOrder == null && _orderData.isEmpty) {
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
                'Memuat status pengiriman...',
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

    // ✅ FIXED: Use _orderData sebagai fallback jika _currentOrder null
    final currentOrderStatus = _currentOrder?.orderStatus.value ??
        _orderData['order_status']?.toString() ??
        'pending';
    final currentDeliveryStatus = _currentOrder?.deliveryStatus.value ??
        _orderData['delivery_status']?.toString() ??
        'pending';
    final orderId = _currentOrder?.id ?? _orderData['id'] ?? widget.orderId;
    final totalAmount = _currentOrder?.totalAmount ??
        _safeParseDouble(_orderData['total_amount']);

    print('🎨 Building status card with:');
    print('   - Order Status: $currentOrderStatus');
    print('   - Delivery Status: $currentDeliveryStatus');
    print('   - Order ID: $orderId');
    print('   - Total Amount: $totalAmount');

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
            // ✅ FIXED: Header dengan gradient purple sesuai gambar
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF9C27B0), // Purple primary
                    const Color(0xFFE1BEE7), // Purple secondary
                  ],
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
                          'Status Pesanan',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                        Text(
                          'Driver',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ✅ FIXED: Show total amount di header sesuai gambar
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      GlobalStyle.formatRupiah(totalAmount),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: GlobalStyle.fontFamily,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ✅ FIXED: Show Order ID di bawah header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Text(
                'Order #$orderId',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: GlobalStyle.fontColor,
                  fontFamily: GlobalStyle.fontFamily,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // Content
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // ✅ FIXED: Shopping cart animation sesuai gambar
                  Container(
                    height: 120,
                    child: Image.asset(
                      'assets/images/shopping_cart.png', // Ganti dengan shopping cart image
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.shopping_cart,
                            size: 60,
                            color: Colors.white,
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ✅ FIXED: Timeline horizontal sesuai gambar
                  _buildHorizontalStatusTimeline(
                      currentOrderStatus, currentDeliveryStatus),

                  const SizedBox(height: 20),

                  // ✅ FIXED: Status message sesuai current status
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _getStatusColor(currentDeliveryStatus)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getStatusColor(currentDeliveryStatus)
                            .withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _getStatusButtonText(currentDeliveryStatus),
                          style: TextStyle(
                            color: _getStatusColor(currentDeliveryStatus),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getStatusDescription(currentDeliveryStatus),
                          style: TextStyle(
                            color: _getStatusColor(currentDeliveryStatus)
                                .withOpacity(0.8),
                            fontSize: 14,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  // ✅ FIXED: Show customer info di bawah status message
                  if (_customerData != null) ...[
                    const SizedBox(height: 16),
                    Container(
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
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.grey[300],
                            child: _customerData!['avatar'] != null &&
                                    _customerData!['avatar']
                                        .toString()
                                        .isNotEmpty
                                ? ClipOval(
                                    child: Image.network(
                                      _customerData!['avatar'],
                                      width: 32,
                                      height: 32,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) => Icon(
                                        Icons.person,
                                        size: 20,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  )
                                : Icon(
                                    Icons.person,
                                    size: 20,
                                    color: Colors.grey[600],
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _customerData!['name'] ?? 'Customer',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: GlobalStyle.fontColor,
                                    fontFamily: GlobalStyle.fontFamily,
                                  ),
                                ),
                                if (_customerData!['phone'] != null &&
                                    _customerData!['phone']
                                        .toString()
                                        .isNotEmpty)
                                  Text(
                                    _customerData!['phone'],
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                      fontFamily: GlobalStyle.fontFamily,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (_customerData!['phone'] != null &&
                              _customerData!['phone'].toString().isNotEmpty)
                            GestureDetector(
                              onTap: () =>
                                  _openWhatsApp(_customerData!['phone']),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF25D366),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.phone,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ NEW: Build horizontal status timeline sesuai gambar store order detail
  Widget _buildHorizontalStatusTimeline(
      String currentOrderStatus, String currentDeliveryStatus) {
    // ✅ STATUS: menunggu, disiapkan, siap diambil, diantar, selesai (5 status)
    final List<Map<String, dynamic>> timeline = [
      {
        'status': 'pending',
        'label': 'Menunggu',
        'icon': Icons.schedule,
        'color': Colors.orange,
      },
      {
        'status': 'preparing',
        'label': 'Disiapkan',
        'icon': Icons.restaurant,
        'color': Colors.purple,
      },
      {
        'status': 'ready_for_pickup',
        'label': 'Siap Diambil',
        'icon': Icons.shopping_bag,
        'color': Colors.indigo,
      },
      {
        'status': 'on_way',
        'label': 'Diantar',
        'icon': Icons.directions_bike,
        'color': Colors.teal,
      },
      {
        'status': 'delivered',
        'label': 'Selesai',
        'icon': Icons.check_circle,
        'color': Colors.green,
      },
    ];

    // ✅ Determine current index based on status
    int currentIndex = 0;

    // Prioritize delivery status for progression
    if (currentDeliveryStatus == 'delivered') {
      currentIndex = 4; // Selesai
    } else if (currentDeliveryStatus == 'on_way') {
      currentIndex = 3; // Diantar
    } else if (currentOrderStatus == 'ready_for_pickup') {
      currentIndex = 2; // Siap Diambil
    } else if (currentOrderStatus == 'preparing') {
      currentIndex = 1; // Disiapkan
    } else {
      currentIndex = 0; // Menunggu
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: List.generate(timeline.length, (index) {
          final isActive = index <= currentIndex;
          final isCurrent = index == currentIndex;
          final isLast = index == timeline.length - 1;
          final statusItem = timeline[index];

          return Expanded(
            child: Row(
              children: [
                Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: isCurrent ? 28 : 20,
                      height: isCurrent ? 28 : 20,
                      decoration: BoxDecoration(
                        color:
                            isActive ? statusItem['color'] : Colors.grey[300],
                        shape: BoxShape.circle,
                        boxShadow: isCurrent
                            ? [
                                BoxShadow(
                                  color: statusItem['color'].withOpacity(0.4),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ]
                            : [],
                      ),
                      child: Icon(
                        statusItem['icon'],
                        color: Colors.white,
                        size: isCurrent ? 14 : 10,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      statusItem['label'],
                      style: TextStyle(
                        fontSize: 9,
                        color: isActive ? statusItem['color'] : Colors.grey,
                        fontWeight:
                            isCurrent ? FontWeight.bold : FontWeight.normal,
                        fontFamily: GlobalStyle.fontFamily,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: index < currentIndex
                            ? timeline[index]['color']
                            : Colors.grey[300],
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
  // Widget _buildHorizontalStatusTimeline(
  //     String currentOrderStatus, String currentDeliveryStatus) {
  //   // ✅ Define timeline sesuai gambar
  //   final List<Map<String, dynamic>> timeline = [
  //     {
  //       'status': 'pending',
  //       'label': 'Menunggu',
  //       'icon': Icons.schedule,
  //       'color': Colors.orange,
  //     },
  //     {
  //       'status': 'confirmed',
  //       'label': 'Dikonfirmasi',
  //       'icon': Icons.check_circle,
  //       'color': Colors.blue,
  //     },
  //     {
  //       'status': 'preparing',
  //       'label': 'Disiapkan',
  //       'icon': Icons.restaurant,
  //       'color': Colors.purple,
  //     },
  //     {
  //       'status': 'ready_for_pickup',
  //       'label': 'Siap Diambil',
  //       'icon': Icons.shopping_bag,
  //       'color': Colors.indigo,
  //     },
  //     {
  //       'status': 'on_way',
  //       'label': 'Diantar',
  //       'icon': Icons.directions_bike,
  //       'color': Colors.teal,
  //     },
  //     {
  //       'status': 'delivered',
  //       'label': 'Selesai',
  //       'icon': Icons.check_circle,
  //       'color': Colors.green,
  //     },
  //   ];
  //
  //   // ✅ Determine current index based on status
  //   int currentIndex = 0;
  //
  //   // Prioritize delivery status for progression
  //   if (currentDeliveryStatus == 'delivered') {
  //     currentIndex = 5;
  //   } else if (currentDeliveryStatus == 'on_way') {
  //     currentIndex = 4;
  //   } else if (currentOrderStatus == 'ready_for_pickup') {
  //     currentIndex = 3;
  //   } else if (currentOrderStatus == 'preparing') {
  //     currentIndex = 2;
  //   } else if (currentOrderStatus == 'confirmed') {
  //     currentIndex = 1;
  //   } else {
  //     currentIndex = 0;
  //   }
  //
  //   return Container(
  //     padding: const EdgeInsets.symmetric(horizontal: 10),
  //     child: Row(
  //       children: List.generate(timeline.length, (index) {
  //         final isActive = index <= currentIndex;
  //         final isCurrent = index == currentIndex;
  //         final isLast = index == timeline.length - 1;
  //         final statusItem = timeline[index];
  //
  //         return Expanded(
  //           child: Row(
  //             children: [
  //               Column(
  //                 children: [
  //                   AnimatedContainer(
  //                     duration: const Duration(milliseconds: 300),
  //                     width: isCurrent ? 28 : 20,
  //                     height: isCurrent ? 28 : 20,
  //                     decoration: BoxDecoration(
  //                       color:
  //                           isActive ? statusItem['color'] : Colors.grey[300],
  //                       shape: BoxShape.circle,
  //                       boxShadow: isCurrent
  //                           ? [
  //                               BoxShadow(
  //                                 color: statusItem['color'].withOpacity(0.4),
  //                                 blurRadius: 6,
  //                                 spreadRadius: 1,
  //                               ),
  //                             ]
  //                           : [],
  //                     ),
  //                     child: Icon(
  //                       statusItem['icon'],
  //                       color: Colors.white,
  //                       size: isCurrent ? 14 : 10,
  //                     ),
  //                   ),
  //                   const SizedBox(height: 6),
  //                   Text(
  //                     statusItem['label'],
  //                     style: TextStyle(
  //                       fontSize: 9,
  //                       color: isActive ? statusItem['color'] : Colors.grey,
  //                       fontWeight:
  //                           isCurrent ? FontWeight.bold : FontWeight.normal,
  //                       fontFamily: GlobalStyle.fontFamily,
  //                     ),
  //                     textAlign: TextAlign.center,
  //                   ),
  //                 ],
  //               ),
  //               if (!isLast)
  //                 Expanded(
  //                   child: Container(
  //                     height: 2,
  //                     margin: const EdgeInsets.only(bottom: 16),
  //                     decoration: BoxDecoration(
  //                       color: index < currentIndex
  //                           ? timeline[index]['color']
  //                           : Colors.grey[300],
  //                       borderRadius: BorderRadius.circular(1),
  //                     ),
  //                   ),
  //                 ),
  //             ],
  //           ),
  //         );
  //       }),
  //     ),
  //   );
  // }

  // ✅ NEW: Get status description
  String _getStatusDescription(String status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return 'Menunggu konfirmasi toko';
      case 'confirmed':
        return 'Pesanan telah dikonfirmasi';
      case 'preparing':
        return 'Toko sedang menyiapkan pesanan';
      case 'ready_for_pickup':
        return 'Pesanan siap untuk diambil';
      case 'picked_up':
        return 'Driver telah mengambil pesanan';
      case 'on_way':
        return 'Pesanan sedang dalam perjalanan';
      case 'delivered':
        return 'Pesanan telah sampai tujuan';
      case 'cancelled':
        return 'Pesanan dibatalkan';
      case 'rejected':
        return 'Pesanan ditolak';
      default:
        return 'Status sedang diproses';
    }
  }

  // ✅ NEW: Build order status timeline (toko progress)
  Widget _buildOrderStatusTimeline() {
    final currentOrderStatus = _currentOrder!.orderStatus;
    final currentOrderIndex = _getCurrentOrderStatusIndex();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Progress Toko',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
            fontFamily: GlobalStyle.fontFamily,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: List.generate(_orderStatusTimeline.length, (index) {
              final isActive = index <= currentOrderIndex;
              final isCurrent = index == currentOrderIndex;
              final isLast = index == _orderStatusTimeline.length - 1;
              final statusItem = _orderStatusTimeline[index];

              return Expanded(
                child: Row(
                  children: [
                    Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: isCurrent ? 28 : 20,
                          height: isCurrent ? 28 : 20,
                          decoration: BoxDecoration(
                            color: isActive
                                ? statusItem['color']
                                : Colors.grey[300],
                            shape: BoxShape.circle,
                            boxShadow: isCurrent
                                ? [
                                    BoxShadow(
                                      color:
                                          statusItem['color'].withOpacity(0.4),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : [],
                          ),
                          child: Icon(
                            statusItem['icon'],
                            color: Colors.white,
                            size: isCurrent ? 14 : 10,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          statusItem['label'],
                          style: TextStyle(
                            fontSize: 9,
                            color: isActive ? statusItem['color'] : Colors.grey,
                            fontWeight:
                                isCurrent ? FontWeight.bold : FontWeight.normal,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          height: 2,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: index < currentOrderIndex
                                ? _orderStatusTimeline[index]['color']
                                : Colors.grey[300],
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  // ✅ NEW: Build delivery status timeline (driver progress)
  Widget _buildDeliveryStatusTimeline() {
    final currentDeliveryStatus = _currentOrder!.deliveryStatus;
    final currentDeliveryIndex = _getCurrentDeliveryStatusIndex();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Progress Pengiriman',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
            fontFamily: GlobalStyle.fontFamily,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: List.generate(_deliveryStatusTimeline.length, (index) {
              final isActive = index <= currentDeliveryIndex;
              final isCurrent = index == currentDeliveryIndex;
              final isLast = index == _deliveryStatusTimeline.length - 1;
              final statusItem = _deliveryStatusTimeline[index];

              return Expanded(
                child: Row(
                  children: [
                    Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: isCurrent ? 28 : 20,
                          height: isCurrent ? 28 : 20,
                          decoration: BoxDecoration(
                            color: isActive
                                ? statusItem['color']
                                : Colors.grey[300],
                            shape: BoxShape.circle,
                            boxShadow: isCurrent
                                ? [
                                    BoxShadow(
                                      color:
                                          statusItem['color'].withOpacity(0.4),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : [],
                          ),
                          child: Icon(
                            statusItem['icon'],
                            color: Colors.white,
                            size: isCurrent ? 14 : 10,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          statusItem['label'],
                          style: TextStyle(
                            fontSize: 9,
                            color: isActive ? statusItem['color'] : Colors.grey,
                            fontWeight:
                                isCurrent ? FontWeight.bold : FontWeight.normal,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          height: 2,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: index < currentDeliveryIndex
                                ? _deliveryStatusTimeline[index]['color']
                                : Colors.grey[300],
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  // ✅ UPDATED: Get current delivery status info dengan fallback
  Map<String, dynamic> _getCurrentDeliveryStatusInfo() {
    // ✅ FIXED: Use fallback data jika _currentOrder null
    String currentDeliveryStatus = 'pending';

    if (_currentOrder != null) {
      currentDeliveryStatus = _currentOrder!.deliveryStatus.value;
    } else if (_orderData.isNotEmpty) {
      currentDeliveryStatus =
          _orderData['delivery_status']?.toString() ?? 'pending';
    }

    // Handle rejected status
    if (currentDeliveryStatus == 'rejected') {
      return {
        'status': 'rejected',
        'label': 'Ditolak',
        'description': 'Pengiriman ditolak',
        'icon': Icons.block,
        'color': Colors.red,
        'animation': 'assets/animations/cancel.json'
      };
    }

    return _deliveryStatusTimeline.firstWhere(
      (item) => item['status'].toString() == currentDeliveryStatus,
      orElse: () => _deliveryStatusTimeline[0],
    );
  }

  int _getCurrentOrderStatusIndex() {
    String currentStatus = 'pending';

    if (_currentOrder != null) {
      currentStatus = _currentOrder!.orderStatus.value;
    } else if (_orderData.isNotEmpty) {
      currentStatus = _orderData['order_status']?.toString() ?? 'pending';
    }

    final index = _orderStatusTimeline
        .indexWhere((item) => item['status'].toString() == currentStatus);
    return index >= 0 ? index : 0;
  }

  int _getCurrentDeliveryStatusIndex() {
    String currentStatus = 'pending';

    if (_currentOrder != null) {
      currentStatus = _currentOrder!.deliveryStatus.value;
    } else if (_orderData.isNotEmpty) {
      currentStatus = _orderData['delivery_status']?.toString() ?? 'pending';
    }

    final index = _deliveryStatusTimeline
        .indexWhere((item) => item['status'].toString() == currentStatus);
    return index >= 0 ? index : 0;
  }

  double _calculateEstimatedEarnings() {
    // ✅ FIX: Driver mendapat 100% delivery fee sesuai backend alignment
    double deliveryFee = 0.0;

    if (_currentOrder != null) {
      deliveryFee = _currentOrder!.deliveryFee;
    } else if (_orderData.isNotEmpty) {
      deliveryFee = _safeParseDouble(_orderData['delivery_fee']);
    }

    // ✅ BACKEND-ALIGNED: Driver earning = 100% delivery fee (tidak ada potongan)
    return deliveryFee;
  }

  // ✅ NEW: Helper method untuk menampilkan driver earning yang akan diterima
  String _getDriverEarningInfo() {
    final driverEarning = _calculateEstimatedEarnings();

    if (driverEarning > 0) {
      return 'Penghasilan Driver: ${GlobalStyle.formatRupiah(driverEarning)}';
    } else {
      return 'Biaya pengiriman belum tersedia';
    }
  }

  // ✅ ADD: Helper method untuk mendapatkan info lokasi
  String _getDeliveryLocationInfo() {
    // Check if we have store information from _storeData
    if (_storeData != null && _storeData!['address'] != null) {
      return _storeData!['address'];
    }

    // Check if we have destination coordinates from _orderData
    if (_orderData['destination_latitude'] != null &&
        _orderData['destination_longitude'] != null) {
      final lat = _orderData['destination_latitude'];
      final lng = _orderData['destination_longitude'];
      return 'Lat: ${lat.toString()}, Lng: ${lng.toString()}';
    }

    // Check if we have pickup address from order data
    if (_orderData['pickup_address'] != null) {
      return _orderData['pickup_address'];
    }

    // Default fallback
    return 'Lokasi tujuan belum tersedia';
  }

  // ✅ UPDATED: Enhanced status mapping sesuai backend
  String _getStatusButtonText(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return 'Menunggu Konfirmasi';
      case 'confirmed':
        return 'Pesanan Dikonfirmasi';
      case 'preparing':
        return 'Pesanan Sedang Diproses';
      case 'ready_for_pickup':
        return 'Pesanan Siap Diambil';
      case 'picked_up':
        return 'Pesanan Sudah Diambil';
      case 'on_way':
        return 'Sedang Diantar';
      case 'delivered':
        return 'Pesanan Selesai';
      case 'cancelled':
        return 'Pesanan Dibatalkan';
      case 'rejected':
        return 'Pesanan Ditolak';
      default:
        return 'Status Tidak Diketahui';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'preparing':
        return Colors.indigo;
      case 'ready_for_pickup':
        return Colors.purple;
      case 'picked_up':
        return Colors.blue;
      case 'on_way':
        return Colors.teal;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
      case 'rejected':
        return Colors.red;
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

  Widget _buildOrderInfoCard() {
    if (_orderData.isEmpty) return const SizedBox.shrink();

    final orderStatus = _orderData['order_status']?.toString() ?? 'pending';
    final deliveryStatus =
        _orderData['delivery_status']?.toString() ?? 'pending';
    final requestStatus = _requestData['status']?.toString() ?? 'pending';
    final createdAt = _orderData['created_at']?.toString() ?? '';
    final estimatedPickupTime =
        _requestData['estimated_pickup_time']?.toString() ?? '';
    final estimatedDeliveryTime =
        _requestData['estimated_delivery_time']?.toString() ?? '';

    return _buildCard(
      index: 0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF667eea),
              const Color(0xFF764ba2),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF667eea).withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background pattern
            Positioned(
              top: -20,
              right: -20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            Positioned(
              bottom: -30,
              left: -30,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.assignment,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Informasi Pesanan',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                fontFamily: GlobalStyle.fontFamily,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Detail status dan waktu',
                              style: TextStyle(
                                fontSize: 14,
                                fontFamily: GlobalStyle.fontFamily,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Status Cards Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatusMiniCard(
                          'Request',
                          _getStatusButtonText(requestStatus),
                          _getStatusColor(requestStatus),
                          Icons.handshake,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatusMiniCard(
                          'Order',
                          _getStatusButtonText(orderStatus),
                          _getStatusColor(orderStatus),
                          Icons.store,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Delivery Status Card (Full Width)
                  _buildStatusMiniCard(
                    'Pengiriman',
                    _getStatusButtonText(deliveryStatus),
                    _getStatusColor(deliveryStatus),
                    Icons.local_shipping,
                    isFullWidth: true,
                  ),

                  // Waktu Section
                  if (createdAt.isNotEmpty ||
                      estimatedPickupTime.isNotEmpty ||
                      estimatedDeliveryTime.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Informasi Waktu',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontFamily: GlobalStyle.fontFamily,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (createdAt.isNotEmpty)
                            _buildTimeInfoRow(
                              'Waktu Pesanan',
                              DateFormat('dd MMM yyyy, HH:mm')
                                  .format(DateTime.parse(createdAt)),
                              Icons.schedule,
                            ),
                          if (estimatedPickupTime.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _buildTimeInfoRow(
                              'Estimasi Pickup',
                              DateFormat('dd MMM yyyy, HH:mm')
                                  .format(DateTime.parse(estimatedPickupTime)),
                              Icons.departure_board,
                            ),
                          ],
                          if (estimatedDeliveryTime.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _buildTimeInfoRow(
                              'Estimasi Delivery',
                              DateFormat('dd MMM yyyy, HH:mm').format(
                                  DateTime.parse(estimatedDeliveryTime)),
                              Icons.flag,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusMiniCard(
      String label, String value, Color color, IconData icon,
      {bool isFullWidth = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: isFullWidth
          ? Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.8),
                          fontFamily: GlobalStyle.fontFamily,
                        ),
                      ),
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: GlobalStyle.fontFamily,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(icon, color: Colors.white, size: 12),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.8),
                        fontFamily: GlobalStyle.fontFamily,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
    );
  }

  // ✅ NEW: Time info row helper
  Widget _buildTimeInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.white.withOpacity(0.8),
          size: 14,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withOpacity(0.8),
            fontFamily: GlobalStyle.fontFamily,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontFamily: GlobalStyle.fontFamily,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            fontFamily: GlobalStyle.fontFamily,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: GlobalStyle.fontColor,
              fontFamily: GlobalStyle.fontFamily,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _buildStoreInfoCard() {
    if (_storeData == null) return const SizedBox.shrink();

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
                    Icons.store,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Informasi Toko',
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
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.blue.withOpacity(0.1),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _storeData!['image_url'] != null
                        ? Image.network(
                            _storeData!['image_url'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.store,
                              color: Colors.blue,
                              size: 28,
                            ),
                          )
                        : Icon(
                            Icons.store,
                            color: Colors.blue,
                            size: 28,
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _storeData!['name'] ?? 'Unknown Store',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: GlobalStyle.fontColor,
                          fontFamily: GlobalStyle.fontFamily,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (_storeData!['address'] != null)
                        Row(
                          children: [
                            Icon(Icons.location_on,
                                color: Colors.grey[600], size: 16),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _storeData!['address'],
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                  fontFamily: GlobalStyle.fontFamily,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      if (_storeData!['phone'] != null &&
                          _storeData!['phone'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(Icons.phone,
                                  color: Colors.grey[600], size: 16),
                              const SizedBox(width: 4),
                              Text(
                                _storeData!['phone'],
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                  fontFamily: GlobalStyle.fontFamily,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (_storeData!['phone'] != null &&
                _storeData!['phone'].toString().isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue, Colors.blue.withOpacity(0.8)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _openWhatsApp(_storeData!['phone']),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.message, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Hubungi Toko',
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
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerInfoCard() {
    if (_customerData == null) return const SizedBox.shrink();

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
                    Icons.person,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Informasi Pelanggan',
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
                    color: Colors.green.withOpacity(0.1),
                    border: Border.all(
                      color: Colors.green.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: _customerData!['avatar'] != null
                        ? Image.network(
                            _customerData!['avatar'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.person,
                              color: Colors.green,
                              size: 28,
                            ),
                          )
                        : Icon(
                            Icons.person,
                            color: Colors.green,
                            size: 28,
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _customerData!['name'] ?? 'Unknown Customer',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: GlobalStyle.fontColor,
                          fontFamily: GlobalStyle.fontFamily,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (_orderData['destination_latitude'] != null &&
                          _orderData['destination_longitude'] != null)
                        Row(
                          children: [
                            Icon(Icons.location_on,
                                color: Colors.grey[600], size: 16),
                            const SizedBox(width: 4),
                            Text(
                              'Koordinat tujuan tersedia',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                                fontFamily: GlobalStyle.fontFamily,
                              ),
                            ),
                          ],
                        ),
                      if (_customerData!['phone'] != null &&
                          _customerData!['phone'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(Icons.phone,
                                  color: Colors.grey[600], size: 16),
                              const SizedBox(width: 4),
                              Text(
                                _customerData!['phone'],
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                  fontFamily: GlobalStyle.fontFamily,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (_customerData!['phone'] != null &&
                _customerData!['phone'].toString().isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
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
                    onTap: () => _openWhatsApp(_customerData!['phone']),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.message, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Hubungi Pelanggan',
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
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildItemsCard() {
    if (_orderItems.isEmpty) return const SizedBox.shrink();

    // ✅ FIX: Safe numeric conversion untuk total amounts
    final totalAmount = _safeParseDouble(_orderData['total_amount']);
    final deliveryFee = _safeParseDouble(_orderData['delivery_fee']);
    final subtotal = totalAmount - deliveryFee;
    final driverEarning =
        _calculateEstimatedEarnings(); // ✅ Driver earning = delivery fee

    return _buildCard(
      index: 3,
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
                      colors: [Colors.purple, Colors.purple.withOpacity(0.8)],
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
                  'Item Pesanan',
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

            // ✅ ITEMS LIST (same as before)
            ..._orderItems.map<Widget>((item) {
              final itemName = item['name']?.toString() ?? 'Unknown Item';
              final quantity = _safeParseInt(item['quantity']);
              final price = _safeParseDouble(item['price']);
              final imageUrl = item['image_url']?.toString() ?? '';
              final totalPrice = price * quantity;

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
                      child: imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
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
                                );
                              },
                            )
                          : Container(
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
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            itemName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              fontFamily: GlobalStyle.fontFamily,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            GlobalStyle.formatRupiah(price),
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
                            'x$quantity',
                            style: TextStyle(
                              color: GlobalStyle.primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          GlobalStyle.formatRupiah(totalPrice),
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

            // ✅ PAYMENT BREAKDOWN
            Container(
              margin: const EdgeInsets.symmetric(vertical: 16),
              height: 1,
              color: Colors.grey.shade300,
            ),
            _buildPaymentRow('Subtotal', subtotal),
            const SizedBox(height: 12),
            _buildPaymentRow('Biaya Pengiriman', deliveryFee),

            // ✅ DRIVER EARNING SECTION (NEW)
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.green.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet,
                        color: Colors.green[700],
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Penghasilan Driver',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.green[700],
                          fontFamily: GlobalStyle.fontFamily,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    GlobalStyle.formatRupiah(driverEarning),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.green[700],
                      fontFamily: GlobalStyle.fontFamily,
                    ),
                  ),
                ],
              ),
            ),

            // ✅ TOTAL PAYMENT
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

  // ✅ UPDATED: Enhanced action buttons dengan fallback data support
  Widget _buildActionButtons() {
    // ✅ FIX: Get status dengan fallback mechanism yang robust
    final requestStatus = _requestData['status']?.toString() ?? 'pending';
    String orderStatus = 'pending';
    String deliveryStatus = 'pending';

    if (_currentOrder != null) {
      orderStatus = _currentOrder!.orderStatus.value;
      deliveryStatus = _currentOrder!.deliveryStatus.value;
    } else if (_orderData.isNotEmpty) {
      orderStatus = _orderData['order_status']?.toString() ?? 'pending';
      deliveryStatus = _orderData['delivery_status']?.toString() ?? 'pending';
    }

    print('🔄 Building action buttons:');
    print('   - Request Status: $requestStatus');
    print('   - Order Status: $orderStatus');
    print('   - Delivery Status: $deliveryStatus');

    // ✅ ALUR 1: Request masih pending - show accept/reject buttons
    if (requestStatus == 'pending') {
      final canAccept = (deliveryStatus == 'pending') &&
          (orderStatus == 'pending' || orderStatus == 'preparing');

      if (canAccept) {
        return _buildRequestResponseButtons();
      } else {
        return _buildInfoCard(
            'Request sudah tidak dapat diproses', Colors.grey);
      }
    }

    // ✅ ALUR 2: Request accepted - show delivery action buttons
    if (requestStatus == 'accepted') {
      return _buildDeliveryActionButtons(orderStatus, deliveryStatus);
    }

    // ✅ ALUR 3: Request rejected/expired - show status only
    return _buildInfoCard(
      requestStatus == 'rejected' ? 'Request Ditolak' : 'Request Kedaluwarsa',
      Colors.red,
    );
  }

  // ✅ NEW: Build request response buttons (accept/reject)
  Widget _buildRequestResponseButtons() {
    return _buildCard(
      index: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Request Pengantaran',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: GlobalStyle.fontColor,
                fontFamily: GlobalStyle.fontFamily,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pesanan ini membutuhkan konfirmasi dari Anda. Terima atau tolak request ini.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontFamily: GlobalStyle.fontFamily,
              ),
            ),
            const SizedBox(height: 16),
            Row(
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
                      onTap: _isRespondingRequest
                          ? null
                          : () => _respondToRequest('reject'),
                      child: Center(
                        child: Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 24,
                        ),
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
                        onTap: _isRespondingRequest
                            ? null
                            : () => _respondToRequest('accept'),
                        child: Center(
                          child: _isRespondingRequest
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
                                  'Terima Request',
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
          ],
        ),
      ),
    );
  }

  // ✅ NEW: Build delivery action buttons based on status
  Widget _buildDeliveryActionButtons(
      String orderStatus, String deliveryStatus) {
    print('🚚 Building delivery action buttons:');
    print('   - Order Status: $orderStatus');
    print('   - Delivery Status: $deliveryStatus');

    // ✅ ALUR 1: ready_for_pickup + pending = Pickup Order (optional)
    if (orderStatus == 'ready_for_pickup' && deliveryStatus == 'pending') {
      return Column(
        children: [
          _buildActionButton(
            title: 'Ambil Pesanan',
            description: 'Konfirmasi pengambilan pesanan dari toko',
            buttonText: 'Ambil dari Toko',
            buttonColor: Colors.orange,
            onPressed: () => _updatePickupStatus(),
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            title: 'Langsung Mulai Pengantaran',
            description: 'Langsung mulai pengantaran (skip pickup)',
            buttonText: 'Mulai Pengantaran',
            buttonColor: Colors.blue,
            onPressed: () => _updateDeliveryStatus('on_way'),
          ),
        ],
      );
    }

    // ✅ ALUR 2: ready_for_pickup + picked_up = Mulai Pengantaran
    if (orderStatus == 'ready_for_pickup' && deliveryStatus == 'picked_up') {
      return _buildActionButton(
        title: 'Mulai Pengantaran',
        description: 'Ubah status menjadi "Dalam Perjalanan"',
        buttonText: 'Mulai Pengantaran',
        buttonColor: Colors.blue,
        onPressed: () => _updateDeliveryStatus('on_way'),
      );
    }

    // ✅ ALUR 3: on_delivery + on_way = Selesaikan Pengantaran
    if (orderStatus == 'on_delivery' && deliveryStatus == 'on_way') {
      return _buildActionButton(
        title: 'Selesaikan Pengantaran',
        description: 'Tandai pesanan sebagai terkirim',
        buttonText: 'Pengantaran Selesai',
        buttonColor: Colors.green,
        onPressed: () => _updateDeliveryStatus('delivered'),
      );
    }

    // ✅ ALUR 4: delivered = Completed
    if (deliveryStatus == 'delivered' || orderStatus == 'delivered') {
      return _buildInfoCard('Pengantaran Selesai', Colors.green);
    }

    // ✅ ALUR 5: Waiting for store or other statuses
    return _buildInfoCard(
      _getWaitingMessage(orderStatus, deliveryStatus),
      Colors.orange,
    );
  }

  // ✅ NEW: Build action button helper
  Widget _buildActionButton({
    required String title,
    required String description,
    required String buttonText,
    required Color buttonColor,
    required VoidCallback onPressed,
  }) {
    return _buildCard(
      index: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: GlobalStyle.fontColor,
                fontFamily: GlobalStyle.fontFamily,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontFamily: GlobalStyle.fontFamily,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [buttonColor, buttonColor.withOpacity(0.8)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: buttonColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _isUpdatingStatus ? null : onPressed,
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
                        : Text(
                            buttonText,
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
          ],
        ),
      ),
    );
  }

  // ✅ NEW: Build info card for status display
  Widget _buildInfoCard(String message, Color color) {
    return _buildCard(
      index: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
        ),
      ),
    );
  }

  // ✅ NEW: Get waiting message based on statuses
  String _getWaitingMessage(String orderStatus, String deliveryStatus) {
    if (orderStatus == 'pending') {
      return 'Menunggu konfirmasi toko';
    } else if (orderStatus == 'confirmed') {
      return 'Toko sedang menyiapkan pesanan';
    } else if (orderStatus == 'preparing') {
      return 'Pesanan sedang diproses toko';
    } else if (orderStatus == 'ready_for_pickup' &&
        deliveryStatus == 'pending') {
      return 'Pesanan siap diambil - Menunggu pickup';
    } else {
      return 'Menunggu update status';
    }
  }

  // ✅ UPDATED: Enhanced request response menggunakan DriverRequestService.respondToDriverRequest
  Future<void> _respondToRequest(String action) async {
    if (_isRespondingRequest) return;

    setState(() {
      _isRespondingRequest = true;
    });

    try {
      print(
          '📝 HistoryDriverDetail: Responding to request with action: $action');

      // ✅ FIX: Simplified validation - cukup cek basic auth tanpa role validation yang terlalu ketat
      final isAuthenticated = await AuthService.isAuthenticated();
      if (!isAuthenticated) {
        // ✅ FIX: Redirect to login instead of throwing error
        _handleAuthenticationError();
        return;
      }

      // ✅ FIX: Respond to request dengan improved error handling
      await DriverRequestService.respondToDriverRequest(
        requestId: _requestData['id'].toString(),
        action: action,
        notes: action == 'accept'
            ? 'Driver menerima permintaan pengantaran'
            : 'Driver menolak permintaan pengantaran',
      );

      // ✅ FIX: Soft refresh - jika gagal tidak throw error
      try {
        await _loadRequestData();
      } catch (refreshError) {
        print('⚠️ Refresh error (non-critical): $refreshError');
        // Continue tanpa refresh jika gagal
      }

      if (mounted) {
        if (action == 'accept') {
          _showAcceptSuccessDialog();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Request berhasil ditolak'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }

      _playSound(action == 'accept' ? 'audio/kring.mp3' : 'audio/wrong.mp3');
      print('✅ HistoryDriverDetail: Request response processed successfully');
    } catch (e) {
      print('❌ HistoryDriverDetail: Error responding to request: $e');

      // ✅ FIX: Handle authentication errors gracefully
      if (e.toString().contains('authentication') ||
          e.toString().contains('Unauthorized') ||
          e.toString().contains('Access denied')) {
        _handleAuthenticationError();
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal merespon request. Silakan coba lagi.'),
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
          _isRespondingRequest = false;
        });
      }
    }
  }

  // ✅ NEW: Show accept success dialog with contact customer option
  void _showAcceptSuccessDialog() {
    // ✅ FIXED: Get total amount dengan fallback
    double totalAmount = 0.0;
    if (_currentOrder != null) {
      totalAmount = _currentOrder!.totalAmount;
    } else if (_orderData.isNotEmpty) {
      totalAmount = _safeParseDouble(_orderData['total_amount']);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/animations/diproses.json',
                  width: 150,
                  height: 150,
                  repeat: false,
                ),
                const SizedBox(height: 16),
                Text(
                  'Request Diterima!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Order #${widget.orderId}',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Total: ${GlobalStyle.formatRupiah(totalAmount)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: GlobalStyle.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey[600],
                          side: BorderSide(color: Colors.grey[300]!),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          'Tutup',
                          style: TextStyle(
                            fontFamily: GlobalStyle.fontFamily,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          if (_customerData?['phone'] != null) {
                            _openWhatsApp(_customerData!['phone']);
                          }
                        },
                        child: Text(
                          'Contact Customer',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: GlobalStyle.fontFamily,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _updateDeliveryStatus(String deliveryStatus) async {
    if (_isUpdatingStatus) return;

    setState(() {
      _isUpdatingStatus = true;
    });

    try {
      print(
          '🚚 HistoryDriverDetail: Updating delivery status to: $deliveryStatus');

      // ✅ FIX: Simplified authentication check
      final isAuthenticated = await AuthService.isAuthenticated();
      if (!isAuthenticated) {
        _handleAuthenticationError();
        return;
      }

      // ✅ FIXED: Gunakan tracking endpoint yang benar untuk driver
      if (deliveryStatus == 'on_way') {
        // Driver memulai pengantaran - gunakan TrackingService.startDelivery
        print('📍 Using TrackingService.startDelivery for driver');
        await TrackingService.startDelivery(widget.orderId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Pengantaran dimulai! Status berubah ke "Dalam Perjalanan"'),
              backgroundColor: Colors.blue,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } else if (deliveryStatus == 'delivered') {
        // Driver selesaikan pengantaran - gunakan TrackingService.completeDelivery
        print('✅ Using TrackingService.completeDelivery for driver');
        await TrackingService.completeDelivery(widget.orderId);
        _showCompletionDialog();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Pengantaran selesai! Pesanan telah terkirim.'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } else {
        // ✅ FALLBACK: Untuk status lain, tetap gunakan OrderService tapi dengan error handling
        print(
            '📝 Using OrderService.updateOrderStatus for status: $deliveryStatus');

        // Get current order status dengan fallback mechanism
        String currentOrderStatus = 'pending';
        if (_currentOrder != null) {
          currentOrderStatus = _currentOrder!.orderStatus.value;
        } else if (_orderData.isNotEmpty) {
          currentOrderStatus =
              _orderData['order_status']?.toString() ?? 'pending';
        }

        try {
          await OrderService.updateOrderStatus(
            orderId: widget.orderId,
            orderStatus: currentOrderStatus,
            deliveryStatus: deliveryStatus,
            notes: 'Delivery status diupdate oleh driver ke $deliveryStatus',
          );
        } catch (orderError) {
          // ✅ Jika gagal dengan OrderService, coba dengan TrackingService
          print(
              '⚠️ OrderService failed, trying alternative method: $orderError');

          if (deliveryStatus == 'picked_up') {
            // Untuk picked_up, mungkin ada endpoint khusus di tracking
            throw Exception(
                'Status picked_up belum didukung melalui tracking service');
          } else {
            rethrow;
          }
        }
      }

      // ✅ REFRESH: Load ulang data setelah berhasil update
      try {
        await _loadRequestData();
        print('✅ Data refreshed successfully after status update');
      } catch (refreshError) {
        print('⚠️ Refresh error (non-critical): $refreshError');
        // Continue tanpa refresh jika gagal
      }

      _playSound('audio/kring.mp3');
      print('✅ HistoryDriverDetail: Delivery status updated successfully');
    } catch (e) {
      print('❌ HistoryDriverDetail: Error updating delivery status: $e');

      // ✅ FIX: Handle specific error types
      if (e.toString().contains('authentication') ||
          e.toString().contains('Unauthorized') ||
          e.toString().contains('Access denied') ||
          e.toString().contains('Please login again')) {
        _handleAuthenticationError();
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Gagal mengupdate status: ${e.toString().contains('Unauthorized') ? 'Sesi berakhir, silakan login ulang' : 'Silakan coba lagi'}'),
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

  Future<void> _updatePickupStatus() async {
    if (_isUpdatingStatus) return;

    setState(() {
      _isUpdatingStatus = true;
    });

    try {
      print('📦 HistoryDriverDetail: Updating pickup status');

      final isAuthenticated = await AuthService.isAuthenticated();
      if (!isAuthenticated) {
        _handleAuthenticationError();
        return;
      }

      // ✅ Untuk pickup, kita mungkin perlu endpoint khusus atau update manual
      // Sementara gunakan OrderService dengan handling yang lebih baik
      String currentOrderStatus = _currentOrder?.orderStatus.value ??
          _orderData['order_status']?.toString() ??
          'ready_for_pickup';

      await OrderService.updateOrderStatus(
        orderId: widget.orderId,
        orderStatus: currentOrderStatus,
        deliveryStatus: 'picked_up',
        notes: 'Driver telah mengambil pesanan dari toko',
      );

      // Refresh data
      try {
        await _loadRequestData();
      } catch (refreshError) {
        print('⚠️ Refresh error (non-critical): $refreshError');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pesanan berhasil diambil dari toko'),
            backgroundColor: Colors.blue,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }

      _playSound('audio/kring.mp3');
      print('✅ HistoryDriverDetail: Pickup status updated successfully');
    } catch (e) {
      print('❌ HistoryDriverDetail: Error updating pickup status: $e');

      if (e.toString().contains('authentication') ||
          e.toString().contains('Unauthorized') ||
          e.toString().contains('Access denied')) {
        _handleAuthenticationError();
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengupdate status pickup. Silakan coba lagi.'),
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

  Future<void> _playSound(String assetPath) async {
    try {
      await _audioPlayer.play(AssetSource(assetPath));
    } catch (e) {
      print('Error playing sound: $e');
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/animations/pesanan_selesai.json',
                  width: 200,
                  height: 200,
                  repeat: false,
                ),
                const SizedBox(height: 20),
                Text(
                  'Pengantaran Selesai!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Terima kasih telah menyelesaikan pengantaran dengan baik',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlobalStyle.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/Driver/HomePage',
                      (Route<dynamic> route) => false,
                    );
                  },
                  child: Text(
                    'Kembali ke Beranda',
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
        );
      },
    );
  }

  // ✅ ADD: Helper method untuk safe numeric conversion
  static double _safeParseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed ?? 0.0;
    }
    if (value is num) return value.toDouble();
    return 0.0;
  }

// ✅ ADD: Helper method untuk safe integer conversion
  static int _safeParseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      return parsed ?? 0;
    }
    if (value is num) return value.toInt();
    return 0;
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

    final message =
        'Halo! Saya driver dari Del Pick mengenai pesanan #${widget.orderId}. Apakah ada yang bisa saya bantu?';
    final encodedMessage = Uri.encodeComponent(message);
    final url = 'https://wa.me/$cleanPhone?text=$encodedMessage';

    try {
      if (await canLaunchUrlString(url)) {
        await launchUrlString(url);
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

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: GlobalStyle.primaryColor),
          const SizedBox(height: 16),
          Text(
            'Memuat detail pengantaran...',
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

  Widget _buildErrorState() {
    return Center(
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ✅ ADD: Back button
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                    side: BorderSide(color: Colors.grey[300]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                  child: Text(
                    'Kembali',
                    style: TextStyle(
                      fontFamily: GlobalStyle.fontFamily,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // ✅ FIX: Retry button
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
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text(
          'Detail Pengantaran',
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
          onPressed: () => Navigator.pop(context, 'refresh'),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingState()
            : _hasError
                ? _buildErrorState()
                : SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ✅ INTEGRATED: Driver Order Status Card directly built in
                          AnimatedBuilder(
                            animation: _statusController,
                            child: _buildDriverOrderStatusCard(),
                            builder: (context, child) {
                              return SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, -0.3),
                                  end: Offset.zero,
                                ).animate(CurvedAnimation(
                                  parent: _statusController,
                                  curve: Curves.easeOutCubic,
                                )),
                                child: FadeTransition(
                                  opacity: _statusController,
                                  child: child,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildOrderInfoCard(),
                          _buildStoreInfoCard(),
                          _buildCustomerInfoCard(),
                          _buildItemsCard(),
                          _buildActionButtons(),
                          const SizedBox(height: 100), // Bottom padding
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }
}
