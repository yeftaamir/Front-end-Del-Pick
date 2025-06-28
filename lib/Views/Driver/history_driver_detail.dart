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
  DeliveryStatus? _previousDeliveryStatus; // ✅ FIXED: Track delivery status changes
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

  // ✅ FIXED: Delivery status timeline untuk driver (bukan order status)
  final List<Map<String, dynamic>> _deliveryStatusTimeline = [
    {
      'status': 'pending',
      'label': 'Menunggu',
      'icon': Icons.schedule,
      'color': Colors.orange,
      'animation': 'assets/animations/diambil.json'
    },
    {
      'status': 'picked_up',
      'label': 'Diambil',
      'icon': Icons.shopping_bag,
      'color': Colors.blue,
      'animation': 'assets/animations/diproses.json'
    },
    {
      'status': 'on_way',
      'label': 'Dalam Perjalanan',
      'icon': Icons.directions_bike,
      'color': Colors.purple,
      'animation': 'assets/animations/diantar.json'
    },
    {
      'status': 'delivered',
      'label': 'Terkirim',
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

  // ✅ FIXED: Enhanced safe type conversion with better error handling
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

  // ✅ FIXED: Safe type conversion for lists containing maps
  static List<dynamic> _safeListConversion(List<dynamic> list) {
    return list.map((item) {
      if (item is Map && item is! Map<String, dynamic>) {
        return _safeMapConversion(item);
      }
      return item;
    }).toList();
  }

  // ✅ FIXED: Safe number parsing with comprehensive error handling
  static double _safeParseDouble(dynamic value) {
    if (value == null) return 0.0;

    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();

    if (value is String) {
      try {
        // Remove any non-numeric characters except decimal point and negative sign
        final cleanedValue = value.replaceAll(RegExp(r'[^\d.-]'), '');
        if (cleanedValue.isEmpty) return 0.0;
        return double.parse(cleanedValue);
      } catch (e) {
        print('⚠️ Error parsing string to double: "$value" -> $e');
        return 0.0;
      }
    }

    print('⚠️ Unknown type for double conversion: ${value.runtimeType} -> $value');
    return 0.0;
  }

  // ✅ FIXED: Safe integer parsing
  static int _safeParseInt(dynamic value) {
    if (value == null) return 0;

    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.round();

    if (value is String) {
      try {
        final cleanedValue = value.replaceAll(RegExp(r'[^\d-]'), '');
        if (cleanedValue.isEmpty) return 0;
        return int.parse(cleanedValue);
      } catch (e) {
        print('⚠️ Error parsing string to int: "$value" -> $e');
        return 0;
      }
    }

    return 0;
  }

  // ✅ FIXED: Enhanced validation and data loading
  Future<void> _validateAndLoadData() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      print('🚗 HistoryDriverDetail: Starting validation and data loading...');

      // ✅ FIXED: Validate driver access menggunakan AuthService
      final hasDriverAccess = await AuthService.hasRole('driver');
      if (!hasDriverAccess) {
        throw Exception('Access denied: Driver authentication required');
      }

      // ✅ FIXED: Ensure valid user session
      final hasValidSession = await AuthService.ensureValidUserData();
      if (!hasValidSession) {
        throw Exception('Invalid user session. Please login again.');
      }

      // ✅ FIXED: Get driver data for context
      final roleData = await AuthService.getRoleSpecificData();
      if (roleData != null && roleData['driver'] != null) {
        _driverData = roleData['driver'];
        print(
            '✅ HistoryDriverDetail: Driver data loaded - ID: ${_driverData!['id']}');
      }

      print('✅ HistoryDriverDetail: Driver access validated');

      // Load request and order data
      await _loadRequestData();

      // Start animations
      _startAnimations();

      // Handle initial status for pulse animation
      if (_currentOrder != null) {
        _handleInitialDeliveryStatus(_getDeliveryStatus());
      }

      // Start status polling
      _startStatusPolling();

      setState(() {
        _isLoading = false;
      });

      print('✅ HistoryDriverDetail: Data loading completed successfully');
    } catch (e) {
      print('❌ HistoryDriverDetail: Validation/loading error: $e');
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  // ✅ FIXED: Enhanced request data loading menggunakan DriverRequestService.getDriverRequestDetail
  Future<void> _loadRequestData() async {
    try {
      print('📋 HistoryDriverDetail: Loading request data...');

      // ✅ FIXED: Validate driver access before loading
      final hasDriverAccess = await AuthService.hasRole('driver');
      if (!hasDriverAccess) {
        throw Exception('Access denied: Driver authentication required');
      }

      Map<String, dynamic> requestData;

      // ✅ FIXED: Use requestId if available, otherwise use orderId
      if (widget.requestId != null) {
        // ✅ FIXED: Get driver request detail menggunakan DriverRequestService.getDriverRequestDetail
        requestData = await DriverRequestService.getDriverRequestDetail(
            widget.requestId!);
      } else {
        // ✅ FIXED: Fallback to finding request by order ID
        final requests = await DriverRequestService.getDriverRequests(
          page: 1,
          limit: 50,
        );

        final requestsList = requests['requests'] as List? ?? [];
        final targetRequest = requestsList.firstWhere(
              (req) => req['order']?['id']?.toString() == widget.orderId,
          orElse: () => throw Exception(
              'Driver request not found for order ${widget.orderId}'),
        );

        requestData = targetRequest;
      }

      if (requestData.isNotEmpty) {
        setState(() {
          _requestData = requestData;
        });

        // ✅ FIXED: Process request data structure
        _processRequestData(requestData);
        print('✅ HistoryDriverDetail: Request data loaded successfully');
        print('   - Request ID: ${requestData['id']}');
        print('   - Order ID: ${_orderData['id']}');
        print('   - Request Status: ${requestData['status']}');
        print('   - Order Status: ${_orderData['order_status']}');
        print('   - Delivery Status: ${_orderData['delivery_status']}');
      } else {
        throw Exception('Request data not found or empty response');
      }
    } catch (e) {
      print('❌ HistoryDriverDetail: Error loading request data: $e');
      throw Exception('Failed to load request data: $e');
    }
  }

  // ✅ FIXED: Process request data structure with enhanced type safety
  void _processRequestData(Map<String, dynamic> requestData) {
    try {
      // Extract order data from request
      _orderData = requestData['order'] ?? {};

      // ✅ FIXED: Safe conversion with type safety
      final safeOrderData = _safeMapConversion(_orderData);

      // ✅ FIXED: Ensure proper data structure with safe parsing
      safeOrderData['order_status'] = safeOrderData['order_status'] ?? 'pending';
      safeOrderData['delivery_status'] = safeOrderData['delivery_status'] ?? 'pending';
      safeOrderData['total_amount'] = _safeParseDouble(safeOrderData['total_amount']);
      safeOrderData['delivery_fee'] = _safeParseDouble(safeOrderData['delivery_fee']);

      // Create OrderModel for status card
      try {
        _currentOrder = OrderModel.fromJson(safeOrderData);
        print('✅ HistoryDriverDetail: OrderModel created successfully');
      } catch (e) {
        print('⚠️ HistoryDriverDetail: Error creating OrderModel: $e');
        // Continue without OrderModel, using raw data
      }

      // Process customer data
      if (_orderData['customer'] != null) {
        _customerData = _safeMapConversion(_orderData['customer']);
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
        _storeData = _safeMapConversion(_orderData['store']);
        _storeData!['name'] = _storeData!['name'] ?? 'Unknown Store';
        _storeData!['phone'] = _storeData!['phone'] ?? '';

        // Process store image
        if (_storeData!['image_url'] != null &&
            _storeData!['image_url'].toString().isNotEmpty) {
          _storeData!['image_url'] =
              ImageService.getImageUrl(_storeData!['image_url']);
        }
      }

      // ✅ FIXED: Process order items with safe type conversion
      if (_orderData['items'] != null) {
        _orderItems = _safeListConversion(_orderData['items'] as List);
        for (var item in _orderItems) {
          // Process item image
          if (item['image_url'] != null &&
              item['image_url'].toString().isNotEmpty) {
            item['image_url'] = ImageService.getImageUrl(item['image_url']);
          }

          // ✅ FIXED: Ensure required fields with safe parsing
          item['name'] = item['name'] ?? 'Unknown Item';
          item['quantity'] = _safeParseInt(item['quantity']);
          item['price'] = _safeParseDouble(item['price']);
        }
      }

      // Process driver data from request
      if (requestData['driver'] != null) {
        final requestDriver = _safeMapConversion(requestData['driver']);
        if (requestDriver['user'] != null) {
          final driverUser = _safeMapConversion(requestDriver['user']);
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

  // ✅ FIXED: Handle initial delivery status instead of order status
  void _handleInitialDeliveryStatus(String deliveryStatus) {
    if (['cancelled', 'rejected'].contains(deliveryStatus)) {
      _playCancelSound();
    } else if (deliveryStatus == 'pending') {
      _pulseController.repeat(reverse: true);
    }
  }

  // ✅ FIXED: Handle delivery status changes
  void _handleDeliveryStatusChange(String newStatus) {
    if (['cancelled', 'rejected'].contains(newStatus)) {
      _playCancelSound();
      _pulseController.stop();
    } else {
      _playStatusChangeSound();
      if (newStatus == 'pending') {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
      }
    }
  }

  void _startStatusPolling() {
    _statusUpdateTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted &&
          widget.orderId != null &&
          _currentOrder != null &&
          !_isDeliveryCompleted()) {
        print('🔄 HistoryDriverDetail: Polling status update...');
        _loadRequestData();
      }
    });
  }

  // ✅ FIXED: Check if delivery is completed
  bool _isDeliveryCompleted() {
    final deliveryStatus = _getDeliveryStatus();
    return ['delivered', 'cancelled', 'rejected'].contains(deliveryStatus);
  }

  // ✅ FIXED: Get current delivery status
  String _getDeliveryStatus() {
    return _orderData['delivery_status']?.toString() ?? 'pending';
  }

  // ✅ FIXED: Get current order status
  String _getOrderStatus() {
    return _orderData['order_status']?.toString() ?? 'pending';
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

  // ✅ FIXED: Enhanced status card dengan delivery status focus
  Widget _buildDriverOrderStatusCard() {
    if (_currentOrder == null) {
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

    final deliveryStatus = _getDeliveryStatus();
    final orderStatus = _getOrderStatus();
    final currentStatusInfo = _getCurrentDeliveryStatusInfo();
    final currentIndex = _getCurrentDeliveryStatusIndex();

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
                      Icons.delivery_dining,
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
                          'Status Pengiriman',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                        Text(
                          'Order #${_currentOrder!.id}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_currentOrder!.customer != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            child: _currentOrder!.customer!.avatar != null &&
                                _currentOrder!.customer!.avatar!.isNotEmpty
                                ? ClipOval(
                              child: ImageService.displayImage(
                                imageSource:
                                _currentOrder!.customer!.avatar!,
                                width: 24,
                                height: 24,
                                fit: BoxFit.cover,
                                placeholder: Icon(Icons.person,
                                    size: 16, color: Colors.white),
                                errorWidget: Icon(Icons.person,
                                    size: 16, color: Colors.white),
                              ),
                            )
                                : Icon(Icons.person,
                                size: 16, color: Colors.white),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _currentOrder!.customer!.name,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
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
                  if (deliveryStatus == 'pending')
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            height: 140,
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
                      height: 140,
                      child: Lottie.asset(
                        currentStatusInfo['animation'],
                        repeat: !['delivered', 'cancelled', 'rejected']
                            .contains(deliveryStatus),
                      ),
                    ),

                  const SizedBox(height: 20),

                  // ✅ FIXED: Delivery Status Timeline
                  if (!['cancelled', 'rejected'].contains(deliveryStatus))
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        children: [
                          // Status Icons Row
                          Row(
                            children: List.generate(
                                _deliveryStatusTimeline.length, (index) {
                              final isActive = index <= currentIndex;
                              final isCurrent = index == currentIndex;
                              final isLast =
                                  index == _deliveryStatusTimeline.length - 1;
                              final statusItem = _deliveryStatusTimeline[index];

                              return Expanded(
                                child: Row(
                                  children: [
                                    // Status Icon
                                    AnimatedContainer(
                                      duration:
                                      const Duration(milliseconds: 300),
                                      width: isCurrent ? 28 : 22,
                                      height: isCurrent ? 28 : 22,
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
                                            blurRadius: 6,
                                            spreadRadius: 1,
                                          ),
                                        ]
                                            : [],
                                      ),
                                      child: Icon(
                                        statusItem['icon'],
                                        color: Colors.white,
                                        size: isCurrent ? 14 : 12,
                                      ),
                                    ),
                                    // Connector Line
                                    if (!isLast)
                                      Expanded(
                                        child: Container(
                                          height: 2,
                                          margin: const EdgeInsets.symmetric(
                                              horizontal: 4),
                                          decoration: BoxDecoration(
                                            color: index < currentIndex
                                                ? _deliveryStatusTimeline[index]
                                            ['color']
                                                : Colors.grey[300],
                                            borderRadius:
                                            BorderRadius.circular(1),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 12),
                          // Current status label
                          Container(
                            alignment: Alignment.center,
                            child: Text(
                              currentStatusInfo['label'],
                              style: TextStyle(
                                fontSize: 12,
                                color: currentStatusInfo['color'],
                                fontWeight: FontWeight.bold,
                                fontFamily: GlobalStyle.fontFamily,
                              ),
                              textAlign: TextAlign.center,
                            ),
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
                          _getDeliveryStatusDescription(deliveryStatus),
                          style: TextStyle(
                            color: currentStatusInfo['color'].withOpacity(0.8),
                            fontSize: 14,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        // ✅ FIXED: Show order status as additional info
                        Text(
                          'Status Pesanan: ${_getOrderStatusDescription(orderStatus)}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  // Location info
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
                          Icon(Icons.location_on,
                              size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _getDeliveryLocationInfo(),
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 12,
                                fontFamily: GlobalStyle.fontFamily,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Earnings info for completed orders
                  if (deliveryStatus == 'delivered')
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.monetization_on,
                                size: 16, color: Colors.green),
                            const SizedBox(width: 6),
                            Text(
                              'Pendapatan: ${GlobalStyle.formatRupiah(_calculateEstimatedEarnings())}',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                fontFamily: GlobalStyle.fontFamily,
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

  // ✅ FIXED: Enhanced delivery status descriptions
  String _getDeliveryStatusDescription(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Menunggu untuk diambil dari toko';
      case 'picked_up':
        return 'Pesanan sudah diambil dari toko';
      case 'on_way':
        return 'Driver sedang menuju ke lokasi customer';
      case 'delivered':
        return 'Pesanan sudah sampai ke customer';
      case 'cancelled':
        return 'Pengiriman dibatalkan';
      case 'rejected':
        return 'Pengiriman ditolak';
      default:
        return 'Status tidak diketahui';
    }
  }

  String _getOrderStatusDescription(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Menunggu konfirmasi toko';
      case 'confirmed':
        return 'Dikonfirmasi oleh toko';
      case 'preparing':
        return 'Sedang diproses di toko';
      case 'ready_for_pickup':
        return 'Siap untuk diambil';
      case 'on_delivery':
        return 'Sedang diantar';
      case 'delivered':
        return 'Sudah diterima customer';
      case 'cancelled':
        return 'Dibatalkan';
      case 'rejected':
        return 'Ditolak oleh toko';
      default:
        return 'Status tidak diketahui';
    }
  }

  Map<String, dynamic> _getCurrentDeliveryStatusInfo() {
    final deliveryStatus = _getDeliveryStatus();

    // Handle cancelled/rejected status
    if (deliveryStatus == 'cancelled') {
      return {
        'status': 'cancelled',
        'label': 'Dibatalkan',
        'icon': Icons.cancel_outlined,
        'color': Colors.red,
        'animation': 'assets/animations/cancel.json'
      };
    }

    if (deliveryStatus == 'rejected') {
      return {
        'status': 'rejected',
        'label': 'Ditolak',
        'icon': Icons.block,
        'color': Colors.red,
        'animation': 'assets/animations/cancel.json'
      };
    }

    return _deliveryStatusTimeline.firstWhere(
          (item) => item['status'] == deliveryStatus,
      orElse: () => _deliveryStatusTimeline[0],
    );
  }

  int _getCurrentDeliveryStatusIndex() {
    final deliveryStatus = _getDeliveryStatus();
    return _deliveryStatusTimeline
        .indexWhere((item) => item['status'] == deliveryStatus);
  }

  double _calculateEstimatedEarnings() {
    if (_currentOrder == null) return 0.0;
    const double baseDeliveryFee = 5000.0;
    const double commissionRate = 0.8;
    return baseDeliveryFee + (_currentOrder!.deliveryFee * commissionRate);
  }

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

    final orderStatus = _getOrderStatus();
    final deliveryStatus = _getDeliveryStatus();
    final requestStatus = _requestData['status']?.toString() ?? 'pending';
    final createdAt = _orderData['created_at']?.toString() ?? '';
    final estimatedPickupTime =
        _requestData['estimated_pickup_time']?.toString() ?? '';
    final estimatedDeliveryTime =
        _requestData['estimated_delivery_time']?.toString() ?? '';

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
                    Icons.receipt_long,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Informasi Pesanan',
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
            _buildInfoRow('Order ID', '#${widget.orderId}'),
            const SizedBox(height: 12),
            _buildInfoRow('Request ID', '#${_requestData['id'] ?? 'N/A'}'),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Status Request',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getRequestStatusColor(requestStatus).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getRequestStatusColor(requestStatus).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    _getRequestStatusText(requestStatus),
                    style: TextStyle(
                      color: _getRequestStatusColor(requestStatus),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Status Pesanan',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getOrderStatusColor(orderStatus).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getOrderStatusColor(orderStatus).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    _getOrderStatusText(orderStatus),
                    style: TextStyle(
                      color: _getOrderStatusColor(orderStatus),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Status Pengiriman',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getDeliveryStatusColor(deliveryStatus).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getDeliveryStatusColor(deliveryStatus).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    _getDeliveryStatusText(deliveryStatus),
                    style: TextStyle(
                      color: _getDeliveryStatusColor(deliveryStatus),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            if (createdAt.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                'Waktu Pesanan',
                DateFormat('dd MMM yyyy, HH:mm')
                    .format(DateTime.parse(createdAt)),
              ),
            ],
            if (estimatedPickupTime.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                'Estimasi Pickup',
                DateFormat('dd MMM yyyy, HH:mm')
                    .format(DateTime.parse(estimatedPickupTime)),
              ),
            ],
            if (estimatedDeliveryTime.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                'Estimasi Delivery',
                DateFormat('dd MMM yyyy, HH:mm')
                    .format(DateTime.parse(estimatedDeliveryTime)),
              ),
            ],
          ],
        ),
      ),
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

    // ✅ FIXED: Safe number parsing for totals
    final totalAmount = _safeParseDouble(_orderData['total_amount']);
    final deliveryFee = _safeParseDouble(_orderData['delivery_fee']);
    final subtotal = totalAmount - deliveryFee;

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

  // ✅ FIXED: Enhanced action buttons dengan proper delivery status flow
  Widget _buildActionButtons() {
    final requestStatus = _requestData['status']?.toString() ?? 'pending';
    final orderStatus = _getOrderStatus();
    final deliveryStatus = _getDeliveryStatus();

    print('🎯 Action buttons - Request: $requestStatus, Order: $orderStatus, Delivery: $deliveryStatus');

    // If request is pending, show approve/reject buttons
    if (requestStatus == 'pending') {
      return _buildCard(
        index: 4,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    Icons.help_outline,
                    color: Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Request Menunggu Konfirmasi',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                      fontFamily: GlobalStyle.fontFamily,
                    ),
                  ),
                ],
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

    // If request is accepted, show delivery action buttons
    if (requestStatus == 'accepted') {
      return _buildDeliveryActionButtons(orderStatus, deliveryStatus);
    }

    // ✅ FIXED: Show appropriate message for rejected/expired requests
    return _buildCard(
      index: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Icon(
                requestStatus == 'rejected' ? Icons.cancel_outlined : Icons.timer_off,
                color: Colors.grey,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                requestStatus == 'rejected' ? 'Request Ditolak' : 'Request Expired',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  fontFamily: GlobalStyle.fontFamily,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ FIXED: Delivery action buttons berdasarkan order_status dan delivery_status
  Widget _buildDeliveryActionButtons(String orderStatus, String deliveryStatus) {
    bool canUpdate = false;
    String buttonText = '';
    Color statusColor = Colors.grey;
    String? nextAction;

    // ✅ FIXED: Correct logic sesuai requirement user
    // Driver bisa "Mulai Pengantaran" ketika order_status == 'ready_for_pickup' DAN delivery_status == 'picked_up'
    // Driver bisa "Pengantaran Selesai" ketika delivery_status == 'on_way'

    if (orderStatus == 'ready_for_pickup' && deliveryStatus == 'picked_up') {
      canUpdate = true;
      nextAction = 'start_delivery';
      buttonText = 'Mulai Pengantaran';
      statusColor = Colors.purple;
    } else if (deliveryStatus == 'on_way') {
      canUpdate = true;
      nextAction = 'complete_delivery';
      buttonText = 'Pengantaran Selesai';
      statusColor = Colors.green;
    }

    return _buildCard(
      index: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Status info
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getDeliveryStatusColor(deliveryStatus).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getDeliveryStatusIcon(deliveryStatus),
                    color: _getDeliveryStatusColor(deliveryStatus),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status Pengiriman Saat Ini',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontFamily: GlobalStyle.fontFamily,
                        ),
                      ),
                      Text(
                        _getDeliveryStatusText(deliveryStatus),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _getDeliveryStatusColor(deliveryStatus),
                          fontFamily: GlobalStyle.fontFamily,
                        ),
                      ),
                      Text(
                        'Pesanan: ${_getOrderStatusText(orderStatus)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontFamily: GlobalStyle.fontFamily,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (canUpdate) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [statusColor, statusColor.withOpacity(0.8)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withOpacity(0.3),
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
                        : () => _handleDeliveryAction(nextAction!),
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
            ] else ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Icon(
                      _getWaitingIcon(orderStatus, deliveryStatus),
                      color: Colors.grey[600],
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getWaitingMessage(orderStatus, deliveryStatus),
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        fontFamily: GlobalStyle.fontFamily,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ✅ FIXED: Handle delivery actions menggunakan TrackingService
  Future<void> _handleDeliveryAction(String action) async {
    if (_isUpdatingStatus) return;

    setState(() {
      _isUpdatingStatus = true;
    });

    try {
      print('🚚 HistoryDriverDetail: Handling delivery action: $action');

      // ✅ FIXED: Validate driver access
      final hasDriverAccess = await AuthService.hasRole('driver');
      if (!hasDriverAccess) {
        throw Exception('Access denied: Driver authentication required');
      }

      switch (action) {
        case 'start_delivery':
        // ✅ FIXED: Start delivery menggunakan TrackingService
          await TrackingService.startDelivery(widget.orderId);
          break;
        case 'complete_delivery':
        // ✅ FIXED: Complete delivery menggunakan TrackingService
          await TrackingService.completeDelivery(widget.orderId);
          _showCompletionDialog();
          break;
        default:
          throw Exception('Unknown delivery action: $action');
      }

      // Refresh data
      await _loadRequestData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == 'start_delivery'
                  ? 'Pengantaran dimulai'
                  : 'Pengantaran selesai',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }

      // Play sound
      _playSound('audio/kring.mp3');

      print('✅ HistoryDriverDetail: Delivery action processed successfully');
    } catch (e) {
      print('❌ HistoryDriverDetail: Error handling delivery action: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memproses aksi pengiriman: $e'),
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

  // ✅ FIXED: Status helper methods
  String _getRequestStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Menunggu Respon';
      case 'accepted':
        return 'Diterima';
      case 'rejected':
        return 'Ditolak';
      case 'expired':
        return 'Kadaluarsa';
      case 'completed':
        return 'Selesai';
      default:
        return 'Status Tidak Diketahui';
    }
  }

  Color _getRequestStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'expired':
        return Colors.grey;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getOrderStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Menunggu Konfirmasi';
      case 'confirmed':
        return 'Dikonfirmasi';
      case 'preparing':
        return 'Sedang Diproses';
      case 'ready_for_pickup':
        return 'Siap Diambil';
      case 'on_delivery':
        return 'Sedang Diantar';
      case 'delivered':
        return 'Selesai';
      case 'cancelled':
        return 'Dibatalkan';
      case 'rejected':
        return 'Ditolak';
      default:
        return 'Status Tidak Diketahui';
    }
  }

  Color _getOrderStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'preparing':
        return Colors.purple;
      case 'ready_for_pickup':
        return Colors.indigo;
      case 'on_delivery':
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

  String _getDeliveryStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Menunggu Pickup';
      case 'picked_up':
        return 'Sudah Diambil';
      case 'on_way':
        return 'Dalam Perjalanan';
      case 'delivered':
        return 'Terkirim';
      case 'cancelled':
        return 'Dibatalkan';
      case 'rejected':
        return 'Ditolak';
      default:
        return 'Status Tidak Diketahui';
    }
  }

  Color _getDeliveryStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'picked_up':
        return Colors.blue;
      case 'on_way':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getDeliveryStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.schedule;
      case 'picked_up':
        return Icons.shopping_bag;
      case 'on_way':
        return Icons.directions_bike;
      case 'delivered':
        return Icons.check_circle;
      case 'cancelled':
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  IconData _getWaitingIcon(String orderStatus, String deliveryStatus) {
    if (deliveryStatus == 'delivered') {
      return Icons.check_circle;
    } else if (['cancelled', 'rejected'].contains(deliveryStatus)) {
      return Icons.cancel;
    } else {
      return Icons.schedule;
    }
  }

  String _getWaitingMessage(String orderStatus, String deliveryStatus) {
    if (deliveryStatus == 'delivered') {
      return 'Pengantaran Selesai';
    } else if (['cancelled', 'rejected'].contains(deliveryStatus)) {
      return 'Pengantaran Dibatalkan';
    } else if (deliveryStatus == 'pending') {
      if (orderStatus == 'ready_for_pickup') {
        return 'Silakan ambil pesanan dari toko';
      } else {
        return 'Menunggu pesanan siap diambil';
      }
    } else if (deliveryStatus == 'picked_up') {
      if (orderStatus == 'ready_for_pickup') {
        return 'Pesanan sudah diambil, siap diantar';
      } else {
        return 'Menunggu pesanan siap untuk diantar';
      }
    }
    return 'Menunggu aksi selanjutnya';
  }

  // ✅ FIXED: Enhanced request response menggunakan DriverRequestService.respondToDriverRequest
  Future<void> _respondToRequest(String action) async {
    if (_isRespondingRequest) return;

    setState(() {
      _isRespondingRequest = true;
    });

    try {
      print(
          '📝 HistoryDriverDetail: Responding to request with action: $action');

      // ✅ FIXED: Validate driver access
      final hasDriverAccess = await AuthService.hasRole('driver');
      if (!hasDriverAccess) {
        throw Exception('Access denied: Driver authentication required');
      }

      // ✅ FIXED: Respond to request menggunakan DriverRequestService.respondToDriverRequest
      await DriverRequestService.respondToDriverRequest(
        requestId: _requestData['id'].toString(),
        action: action,
        notes: action == 'accept'
            ? 'Driver menerima permintaan pengantaran'
            : 'Driver menolak permintaan pengantaran',
      );

      // Refresh data
      await _loadRequestData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == 'accept'
                  ? 'Request berhasil diterima'
                  : 'Request berhasil ditolak',
            ),
            backgroundColor: action == 'accept' ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }

      // Play sound
      _playSound(action == 'accept' ? 'audio/kring.mp3' : 'audio/wrong.mp3');

      print('✅ HistoryDriverDetail: Request response processed successfully');
    } catch (e) {
      print('❌ HistoryDriverDetail: Error responding to request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal merespon request: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      setState(() {
        _isRespondingRequest = false;
      });
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
            ElevatedButton(
              onPressed: _validateAndLoadData,
              style: ElevatedButton.styleFrom(
                backgroundColor: GlobalStyle.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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