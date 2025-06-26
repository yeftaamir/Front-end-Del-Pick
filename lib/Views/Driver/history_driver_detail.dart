import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:lottie/lottie.dart';
import 'package:audioplayers/audioplayers.dart';

// Import updated services
import 'package:del_pick/Services/driver_request_service.dart';
import 'package:del_pick/Services/order_service.dart';
import 'package:del_pick/Services/tracking_service.dart';
import 'package:del_pick/Services/image_service.dart';
import 'package:del_pick/Services/auth_service.dart';

// Import DriverOrderStatusCard component
import 'package:del_pick/Views/Component/driver_order_status.dart';

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
  _HistoryDriverDetailPageState createState() => _HistoryDriverDetailPageState();
}

class _HistoryDriverDetailPageState extends State<HistoryDriverDetailPage> with TickerProviderStateMixin {

  // Audio player initialization
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Animation controllers for card sections
  late List<AnimationController> _cardControllers;
  late List<Animation<Offset>> _cardAnimations;
  late AnimationController _statusController;

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
        print('✅ HistoryDriverDetail: Driver data loaded - ID: ${_driverData!['id']}');
      }

      print('✅ HistoryDriverDetail: Driver access validated');

      // Load request and order data
      await _loadRequestData();

      // Start animations
      _startAnimations();

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
        requestData = await DriverRequestService.getDriverRequestDetail(widget.requestId!);
      } else {
        // ✅ FIXED: Fallback to finding request by order ID
        final requests = await DriverRequestService.getDriverRequests(
          page: 1,
          limit: 50,
        );

        final requestsList = requests['requests'] as List? ?? [];
        final targetRequest = requestsList.firstWhere(
              (req) => req['order']?['id']?.toString() == widget.orderId,
          orElse: () => throw Exception('Driver request not found for order ${widget.orderId}'),
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
      } else {
        throw Exception('Request data not found or empty response');
      }
    } catch (e) {
      print('❌ HistoryDriverDetail: Error loading request data: $e');
      throw Exception('Failed to load request data: $e');
    }
  }

  // ✅ FIXED: Process request data structure sesuai backend response
  void _processRequestData(Map<String, dynamic> requestData) {
    try {
      // Extract order data from request
      _orderData = requestData['order'] ?? {};

      // Ensure proper data structure
      _orderData['order_status'] = _orderData['order_status'] ?? 'pending';
      _orderData['delivery_status'] = _orderData['delivery_status'] ?? 'pending';
      _orderData['total_amount'] = _orderData['total_amount'] ?? 0.0;
      _orderData['delivery_fee'] = _orderData['delivery_fee'] ?? 0.0;

      // Process customer data
      if (_orderData['customer'] != null) {
        _customerData = _orderData['customer'];
        _customerData!['name'] = _customerData!['name'] ?? 'Unknown Customer';
        _customerData!['phone'] = _customerData!['phone'] ?? '';

        // Process customer avatar
        if (_customerData!['avatar'] != null && _customerData!['avatar'].toString().isNotEmpty) {
          _customerData!['avatar'] = ImageService.getImageUrl(_customerData!['avatar']);
        }
      }

      // Process store data
      if (_orderData['store'] != null) {
        _storeData = _orderData['store'];
        _storeData!['name'] = _storeData!['name'] ?? 'Unknown Store';
        _storeData!['phone'] = _storeData!['phone'] ?? '';

        // Process store image
        if (_storeData!['image_url'] != null && _storeData!['image_url'].toString().isNotEmpty) {
          _storeData!['image_url'] = ImageService.getImageUrl(_storeData!['image_url']);
        }
      }

      // Process order items
      if (_orderData['items'] != null) {
        _orderItems = _orderData['items'] as List;
        for (var item in _orderItems) {
          // Process item image
          if (item['image_url'] != null && item['image_url'].toString().isNotEmpty) {
            item['image_url'] = ImageService.getImageUrl(item['image_url']);
          }

          // Ensure required fields
          item['name'] = item['name'] ?? 'Unknown Item';
          item['quantity'] = item['quantity'] ?? 1;
          item['price'] = item['price'] ?? 0.0;
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
          if (driverUser['avatar'] != null && driverUser['avatar'].toString().isNotEmpty) {
            driverUser['avatar'] = ImageService.getImageUrl(driverUser['avatar']);
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

  @override
  void dispose() {
    for (var controller in _cardControllers) {
      controller.dispose();
    }
    _statusController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // ✅ FIXED: Enhanced status mapping sesuai backend
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
      case 'on_delivery':
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

  Widget _buildCard({required Widget child, required int index}) {
    return SlideTransition(
      position: index < _cardAnimations.length ? _cardAnimations[index] :
      const AlwaysStoppedAnimation(Offset.zero),
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

  // ✅ FIXED: Enhanced status card menggunakan DriverOrderStatusCard
  Widget _buildStatusCard() {
    return AnimatedBuilder(
      animation: _statusController,
      child: DriverOrderStatusCard(
        orderId: widget.orderId,
        initialOrderData: _orderData,
        animation: Tween<Offset>(
          begin: const Offset(0, -0.3),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _statusController,
          curve: Curves.easeOutCubic,
        )),
      ),
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
    );
  }

  Widget _buildOrderInfoCard() {
    if (_orderData.isEmpty) return const SizedBox.shrink();

    final orderStatus = _orderData['order_status']?.toString() ?? 'pending';
    final requestStatus = _requestData['status']?.toString() ?? 'pending';
    final createdAt = _orderData['created_at']?.toString() ?? '';
    final estimatedPickupTime = _requestData['estimated_pickup_time']?.toString() ?? '';
    final estimatedDeliveryTime = _requestData['estimated_delivery_time']?.toString() ?? '';

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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(requestStatus).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getStatusColor(requestStatus).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    _getStatusButtonText(requestStatus),
                    style: TextStyle(
                      color: _getStatusColor(requestStatus),
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
                DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(createdAt)),
              ),
            ],
            if (estimatedPickupTime.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                'Estimasi Pickup',
                DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(estimatedPickupTime)),
              ),
            ],
            if (estimatedDeliveryTime.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                'Estimasi Delivery',
                DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(estimatedDeliveryTime)),
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
                            Icon(Icons.location_on, color: Colors.grey[600], size: 16),
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
                      if (_storeData!['phone'] != null && _storeData!['phone'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(Icons.phone, color: Colors.grey[600], size: 16),
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
            if (_storeData!['phone'] != null && _storeData!['phone'].toString().isNotEmpty) ...[
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
                      if (_orderData['destination_latitude'] != null && _orderData['destination_longitude'] != null)
                        Row(
                          children: [
                            Icon(Icons.location_on, color: Colors.grey[600], size: 16),
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
                      if (_customerData!['phone'] != null && _customerData!['phone'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(Icons.phone, color: Colors.grey[600], size: 16),
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
            if (_customerData!['phone'] != null && _customerData!['phone'].toString().isNotEmpty) ...[
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

    final totalAmount = ((_orderData['total_amount'] as num?) ?? 0).toDouble();
    final deliveryFee = ((_orderData['delivery_fee'] as num?) ?? 0).toDouble();
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
              final quantity = item['quantity'] ?? 1;
              final price = ((item['price'] as num?) ?? 0).toDouble();
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
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

  // ✅ FIXED: Enhanced action buttons sesuai status dan request status
  Widget _buildActionButtons() {
    final requestStatus = _requestData['status']?.toString() ?? 'pending';
    final orderStatus = _orderData['order_status']?.toString() ?? 'pending';

    // If request is pending, show approve/reject buttons
    if (requestStatus == 'pending') {
      return _buildCard(
        index: 4,
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
                    onTap: _isRespondingRequest ? null : () => _respondToRequest('reject'),
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
                      onTap: _isRespondingRequest ? null : () => _respondToRequest('accept'),
                      child: Center(
                        child: _isRespondingRequest
                            ? SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
        ),
      );
    }

    // If request is accepted, show status update buttons based on order status
    if (requestStatus == 'accepted') {
      return _buildStatusUpdateButtons(orderStatus);
    }

    // No action buttons for rejected/expired requests
    return const SizedBox.shrink();
  }

  // ✅ FIXED: Status update buttons sesuai requirement
  Widget _buildStatusUpdateButtons(String orderStatus) {
    String buttonText = _getStatusButtonText(orderStatus);
    Color statusColor = _getStatusColor(orderStatus);
    bool canUpdate = false;
    String? nextStatus;

    switch (orderStatus.toLowerCase()) {
      case 'confirmed':
      case 'preparing':
      case 'ready_for_pickup':
        canUpdate = true;
        nextStatus = _getNextStatus(orderStatus);
        break;
      case 'on_delivery':
        canUpdate = true;
        nextStatus = 'delivered';
        buttonText = 'Selesaikan Pengantaran';
        break;
      case 'delivered':
      case 'cancelled':
      case 'rejected':
        canUpdate = false;
        break;
      default:
        canUpdate = false;
    }

    if (!canUpdate) {
      return _buildCard(
        index: 4,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withOpacity(0.3)),
            ),
            child: Center(
              child: Text(
                buttonText,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  fontFamily: GlobalStyle.fontFamily,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return _buildCard(
      index: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
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
              onTap: _isUpdatingStatus ? null : () => _updateOrderStatus(nextStatus!),
              child: Center(
                child: _isUpdatingStatus
                    ? SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : Text(
                  _getActionButtonText(orderStatus),
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
    );
  }

  String? _getNextStatus(String currentStatus) {
    switch (currentStatus.toLowerCase()) {
      case 'confirmed':
        return 'preparing';
      case 'preparing':
        return 'ready_for_pickup';
      case 'ready_for_pickup':
        return 'on_delivery';
      case 'on_delivery':
        return 'delivered';
      default:
        return null;
    }
  }

  String _getActionButtonText(String orderStatus) {
    switch (orderStatus.toLowerCase()) {
      case 'confirmed':
        return 'Mulai Memproses';
      case 'preparing':
        return 'Selesai Diproses';
      case 'ready_for_pickup':
        return 'Ambil Pesanan';
      case 'on_delivery':
        return 'Selesaikan Pengantaran';
      default:
        return 'Update Status';
    }
  }

  // ✅ FIXED: Enhanced request response menggunakan DriverRequestService.respondToDriverRequest
  Future<void> _respondToRequest(String action) async {
    if (_isRespondingRequest) return;

    setState(() {
      _isRespondingRequest = true;
    });

    try {
      print('📝 HistoryDriverDetail: Responding to request with action: $action');

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
              action == 'accept' ? 'Request berhasil diterima' : 'Request berhasil ditolak',
            ),
            backgroundColor: action == 'accept' ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      setState(() {
        _isRespondingRequest = false;
      });
    }
  }

  // ✅ FIXED: Enhanced status update menggunakan OrderService.updateOrderStatus
  Future<void> _updateOrderStatus(String status) async {
    if (_isUpdatingStatus) return;

    setState(() {
      _isUpdatingStatus = true;
    });

    try {
      print('📝 HistoryDriverDetail: Updating order status to: $status');

      // ✅ FIXED: Validate driver access
      final hasDriverAccess = await AuthService.hasRole('driver');
      if (!hasDriverAccess) {
        throw Exception('Access denied: Driver authentication required');
      }

      // ✅ FIXED: Update status menggunakan OrderService.updateOrderStatus
      await OrderService.updateOrderStatus(
        orderId: widget.orderId,
        orderStatus: status,
        notes: 'Status diupdate oleh driver',
      );

      // Use tracking service for delivery status
      if (status == 'on_delivery') {
        try {
          await TrackingService.startDelivery(widget.orderId);
        } catch (e) {
          print('⚠️ TrackingService error (non-critical): $e');
        }
      } else if (status == 'delivered') {
        try {
          await TrackingService.completeDelivery(widget.orderId);
          _showCompletionDialog();
        } catch (e) {
          print('⚠️ TrackingService error (non-critical): $e');
          _showCompletionDialog();
        }
      }

      // Refresh data
      await _loadRequestData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status berhasil diupdate ke ${_getStatusButtonText(status)}'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }

      // Play sound
      _playSound('audio/kring.mp3');

      print('✅ HistoryDriverDetail: Order status updated successfully');
    } catch (e) {
      print('❌ HistoryDriverDetail: Error updating status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengupdate status: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      setState(() {
        _isUpdatingStatus = false;
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
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
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

    final message = 'Halo! Saya driver dari Del Pick mengenai pesanan #${widget.orderId}. Apakah ada yang bisa saya bantu?';
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                // ✅ FIXED: Menggunakan DriverOrderStatusCard
                _buildStatusCard(),
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