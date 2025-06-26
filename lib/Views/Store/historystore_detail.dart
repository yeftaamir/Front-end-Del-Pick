import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:lottie/lottie.dart';
import 'package:intl/intl.dart';

// Import updated services
import 'package:del_pick/Services/order_service.dart';
import 'package:del_pick/Services/auth_service.dart';
import 'package:del_pick/Services/image_service.dart';

// Import StoreOrderStatusCard component
import '../Component/store_order_status.dart';

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
  Map<String, dynamic> _orderData = {};
  Map<String, dynamic>? _storeData;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isUpdatingStatus = false;
  bool _isRefreshing = false;

  // Animation controllers
  late List<AnimationController> _cardControllers;
  late List<Animation<Offset>> _cardAnimations;
  late AnimationController _statusController;

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

      print('🏪 HistoryStoreDetail: Starting validation and data loading...');

      // ✅ FIXED: Validate store access menggunakan AuthService
      final hasStoreAccess = await AuthService.hasRole('store');
      if (!hasStoreAccess) {
        throw Exception('Access denied: Store authentication required');
      }

      // ✅ FIXED: Ensure valid user session
      final hasValidSession = await AuthService.ensureValidUserData();
      if (!hasValidSession) {
        throw Exception('Invalid user session. Please login again.');
      }

      // ✅ FIXED: Get store data for context
      final roleData = await AuthService.getRoleSpecificData();
      if (roleData != null && roleData['store'] != null) {
        _storeData = roleData['store'];
        print('✅ HistoryStoreDetail: Store data loaded - ID: ${_storeData!['id']}');
      }

      print('✅ HistoryStoreDetail: Store access validated');

      // Load order data
      await _loadOrderData();

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

  // ✅ FIXED: Enhanced order data loading menggunakan OrderService.getOrderById
  Future<void> _loadOrderData() async {
    try {
      print('📋 HistoryStoreDetail: Loading order data for ID: ${widget.orderId}');

      // ✅ FIXED: Validate store access before loading
      final hasStoreAccess = await AuthService.hasRole('store');
      if (!hasStoreAccess) {
        throw Exception('Access denied: Store authentication required');
      }

      // ✅ FIXED: Get order detail menggunakan OrderService.getOrderById
      final orderData = await OrderService.getOrderById(widget.orderId);

      if (orderData.isNotEmpty) {
        setState(() {
          _orderData = orderData;
        });

        // ✅ FIXED: Process order data structure
        _processOrderData(orderData);
        print('✅ HistoryStoreDetail: Order data loaded successfully');
        print('   - Order ID: ${orderData['id']}');
        print('   - Order Status: ${orderData['order_status']}');
        print('   - Customer: ${orderData['customer']?['name']}');
      } else {
        throw Exception('Order not found or empty response');
      }
    } catch (e) {
      print('❌ HistoryStoreDetail: Error loading order data: $e');
      throw Exception('Failed to load order: $e');
    }
  }

  // ✅ FIXED: Process order data structure sesuai backend response
  void _processOrderData(Map<String, dynamic> orderData) {
    try {
      // Ensure proper data structure
      orderData['order_status'] = orderData['order_status'] ?? 'pending';
      orderData['delivery_status'] = orderData['delivery_status'] ?? 'pending';
      orderData['total_amount'] = orderData['total_amount'] ?? 0.0;
      orderData['delivery_fee'] = orderData['delivery_fee'] ?? 0.0;

      // Process customer data
      if (orderData['customer'] != null) {
        final customer = orderData['customer'];
        customer['name'] = customer['name'] ?? 'Unknown Customer';
        customer['phone'] = customer['phone'] ?? '';

        // Process customer avatar
        if (customer['avatar'] != null && customer['avatar'].toString().isNotEmpty) {
          customer['avatar'] = ImageService.getImageUrl(customer['avatar']);
        }
      }

      // Process driver data (if exists)
      if (orderData['driver'] != null) {
        final driver = orderData['driver'];
        if (driver['user'] != null) {
          final driverUser = driver['user'];
          driverUser['name'] = driverUser['name'] ?? 'Unknown Driver';
          driverUser['phone'] = driverUser['phone'] ?? '';

          // Process driver avatar
          if (driverUser['avatar'] != null && driverUser['avatar'].toString().isNotEmpty) {
            driverUser['avatar'] = ImageService.getImageUrl(driverUser['avatar']);
          }
        }
        driver['license_number'] = driver['license_number'] ?? '';
        driver['vehicle_plate'] = driver['vehicle_plate'] ?? '';
      }

      // Process order items
      if (orderData['items'] != null) {
        final items = orderData['items'] as List;
        for (var item in items) {
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

      // Process tracking updates if exist
      if (orderData['tracking_updates'] != null && orderData['tracking_updates'] is String) {
        try {
          final parsed = jsonDecode(orderData['tracking_updates']);
          if (parsed is List) {
            orderData['tracking_updates'] = parsed;
          }
        } catch (e) {
          print('⚠️ Failed to parse tracking_updates: $e');
          orderData['tracking_updates'] = [];
        }
      }

      print('📊 HistoryStoreDetail: Order data processed successfully');
    } catch (e) {
      print('❌ HistoryStoreDetail: Error processing order data: $e');
    }
  }

  Future<void> _refreshOrderData() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      await _loadOrderData();
      print('✅ HistoryStoreDetail: Data refreshed successfully');
    } catch (e) {
      print('❌ HistoryStoreDetail: Error refreshing data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh order: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
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

  // ✅ FIXED: Enhanced status mapping sesuai backend
  String _getStatusText(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return 'Menunggu Konfirmasi';
      case 'confirmed':
        return 'Dikonfirmasi';
      case 'preparing':
        return 'Sedang Dipersiapkan';
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
        return Colors.red;
      case 'rejected':
        return Colors.red[800]!;
      default:
        return Colors.grey;
    }
  }

  @override
  void dispose() {
    for (var controller in _cardControllers) {
      controller.dispose();
    }
    _statusController.dispose();
    super.dispose();
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

  // ✅ FIXED: Enhanced status card menggunakan StoreOrderStatusCard
  Widget _buildStatusCard() {
    final slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _statusController,
      curve: Curves.easeOutCubic,
    ));

    return AnimatedBuilder(
      animation: _statusController,
      child: StoreOrderStatusCard(
        orderId: widget.orderId,
        initialOrderData: _orderData,
        animation: slideAnimation,
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

  Widget _buildCustomerInfoCard() {
    final customerData = _orderData['customer'] ?? {};
    final customerName = customerData['name']?.toString() ?? 'Customer';
    final customerPhone = customerData['phone']?.toString() ?? '';
    final destinationLatitude = _orderData['destination_latitude']?.toString() ?? '';
    final destinationLongitude = _orderData['destination_longitude']?.toString() ?? '';

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
                    child: customerData['avatar'] != null
                        ? Image.network(
                      customerData['avatar'],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.person,
                        size: 30,
                        color: GlobalStyle.primaryColor,
                      ),
                    )
                        : Icon(
                      Icons.person,
                      size: 30,
                      color: GlobalStyle.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customerName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: GlobalStyle.fontColor,
                          fontFamily: GlobalStyle.fontFamily,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (customerPhone.isNotEmpty)
                        Row(
                          children: [
                            Icon(
                              Icons.phone,
                              color: Colors.grey[600],
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              customerPhone,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                                fontFamily: GlobalStyle.fontFamily,
                              ),
                            ),
                          ],
                        ),
                      if (destinationLatitude.isNotEmpty && destinationLongitude.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                color: Colors.grey[600],
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Koordinat tujuan tersedia',
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
              ],
            ),
            if (customerPhone.isNotEmpty) ...[
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
                          onTap: () => _callCustomer(customerPhone),
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
                          onTap: () => _openWhatsApp(customerPhone),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.message, color: Colors.white, size: 18),
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
    final driverData = _orderData['driver'] ?? {};
    final orderStatus = _orderData['order_status']?.toString() ?? '';

    // Only show driver info if driver is assigned and order is in delivery phase
    if (driverData.isEmpty || !['ready_for_pickup', 'on_delivery', 'delivered'].contains(orderStatus)) {
      return const SizedBox.shrink();
    }

    final driverUser = driverData['user'] ?? {};
    final driverName = driverUser['name']?.toString() ?? 'Driver';
    final driverPhone = driverUser['phone']?.toString() ?? '';
    final vehiclePlate = driverData['vehicle_plate']?.toString() ?? '';
    final licenseNumber = driverData['license_number']?.toString() ?? '';

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
                    child: driverUser['avatar'] != null
                        ? Image.network(
                      driverUser['avatar'],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.person,
                        size: 30,
                        color: Colors.blue,
                      ),
                    )
                        : Icon(
                      Icons.person,
                      size: 30,
                      color: Colors.blue,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driverName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: GlobalStyle.fontColor,
                          fontFamily: GlobalStyle.fontFamily,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (vehiclePlate.isNotEmpty)
                        Row(
                          children: [
                            Icon(
                              Icons.directions_car,
                              color: Colors.grey[600],
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Plat: $vehiclePlate',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                                fontFamily: GlobalStyle.fontFamily,
                              ),
                            ),
                          ],
                        ),
                      if (licenseNumber.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.badge,
                                color: Colors.grey[600],
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'SIM: $licenseNumber',
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
                if (driverPhone.isNotEmpty)
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
                      onPressed: () => _openWhatsApp(driverPhone),
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
    final orderItems = _orderData['items'] ?? [];
    final totalAmount = ((_orderData['total_amount'] as num?) ?? 0).toDouble();
    final deliveryFee = ((_orderData['delivery_fee'] as num?) ?? 0).toDouble();
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
              final itemName = item['name']?.toString() ?? 'Item';
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

  Widget _buildActionButtons() {
    final orderStatus = _orderData['order_status']?.toString() ?? 'pending';

    switch (orderStatus.toLowerCase()) {
      case 'pending':
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
                      onTap: _isUpdatingStatus ? null : () => _processOrder('reject'),
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
                        onTap: _isUpdatingStatus ? null : () => _processOrder('approve'),
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

      case 'confirmed':
        return _buildCard(
          index: 3,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.indigo, Colors.indigo.withOpacity(0.8)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.indigo.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _isUpdatingStatus ? null : () => _updateOrderStatus('preparing'),
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
                      'Mulai Persiapan',
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

      case 'preparing':
        return _buildCard(
          index: 3,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple, Colors.purple.withOpacity(0.8)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _isUpdatingStatus ? null : () => _updateOrderStatus('ready_for_pickup'),
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
                      'Siap Diambil',
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

      case 'ready_for_pickup':
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

      default:
        return const SizedBox.shrink();
    }
  }

  // ✅ FIXED: Enhanced order processing menggunakan OrderService.processOrderByStore
  Future<void> _processOrder(String action) async {
    if (_isUpdatingStatus) return;

    setState(() {
      _isUpdatingStatus = true;
    });

    try {
      print('⚙️ HistoryStoreDetail: Processing order with action: $action');

      // ✅ FIXED: Validate store access
      final hasStoreAccess = await AuthService.hasRole('store');
      if (!hasStoreAccess) {
        throw Exception('Access denied: Store authentication required');
      }

      // ✅ FIXED: Process order menggunakan OrderService.processOrderByStore
      await OrderService.processOrderByStore(
        orderId: widget.orderId,
        action: action, // 'approve' atau 'reject'
        rejectionReason: action == 'reject' ? 'Toko tidak dapat memproses pesanan saat ini' : null,
      );

      // Refresh order data
      await _loadOrderData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == 'approve' ? 'Pesanan berhasil diterima' : 'Pesanan berhasil ditolak',
            ),
            backgroundColor: action == 'approve' ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  // ✅ FIXED: Enhanced status update menggunakan OrderService.updateOrderStatus
  Future<void> _updateOrderStatus(String status) async {
    if (_isUpdatingStatus) return;

    setState(() {
      _isUpdatingStatus = true;
    });

    try {
      print('📝 HistoryStoreDetail: Updating order status to: $status');

      // ✅ FIXED: Validate store access
      final hasStoreAccess = await AuthService.hasRole('store');
      if (!hasStoreAccess) {
        throw Exception('Access denied: Store authentication required');
      }

      // ✅ FIXED: Update status menggunakan OrderService.updateOrderStatus
      await OrderService.updateOrderStatus(
        orderId: widget.orderId,
        orderStatus: status,
        notes: 'Status diupdate oleh toko',
      );

      // Refresh order data
      await _loadOrderData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status pesanan berhasil diupdate ke ${_getStatusText(status)}'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }

      print('✅ HistoryStoreDetail: Order status updated successfully');
    } catch (e) {
      print('❌ HistoryStoreDetail: Error updating status: $e');
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
    final message = 'Halo! Saya dari $storeName mengenai pesanan #$orderId Anda. Apakah ada yang bisa saya bantu?';
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        ),
      );
    }

    final orderStatus = _orderData['order_status']?.toString() ?? '';
    final isCompleted = ['delivered', 'cancelled', 'rejected'].contains(orderStatus.toLowerCase());

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
                  // ✅ FIXED: Menggunakan StoreOrderStatusCard
                  _buildStatusCard(),
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