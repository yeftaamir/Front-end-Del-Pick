import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';

// Import Models
import 'package:del_pick/Models/order.dart';
import 'package:del_pick/Models/order_enum.dart';
import 'package:del_pick/Models/store.dart';
import 'package:del_pick/Models/order_item.dart';

// Import Services
import 'package:del_pick/Services/order_service.dart';
import 'package:del_pick/Services/store_service.dart';
import 'package:del_pick/Services/image_service.dart';
import 'package:del_pick/Services/auth_service.dart';

// Import Components and Screens
import '../Component/cust_bottom_navigation.dart';
import 'package:del_pick/Common/global_style.dart';
import 'home_cust.dart';
import 'history_detail.dart';

class HistoryCustomer extends StatefulWidget {
  static const String route = "/Customers/HistoryCustomer";

  const HistoryCustomer({Key? key}) : super(key: key);

  @override
  State<HistoryCustomer> createState() => _HistoryCustomerState();
}

class _HistoryCustomerState extends State<HistoryCustomer> with TickerProviderStateMixin {
  int _selectedIndex = 1;
  late TabController _tabController;

  // Animation controllers for cards
  late List<AnimationController> _cardControllers;
  late List<Animation<Offset>> _cardAnimations;

  // Data state variables
  List<OrderModel> orders = [];
  Map<int, StoreModel> storeCache = {}; // Cache stores by ID
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;

  // Pagination variables
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalItems = 0;
  static const int _pageSize = 10;
  bool _hasMoreData = true;

  // Scroll controller for pagination
  late ScrollController _scrollController;

  // Authentication state
  Map<String, dynamic>? _customerData;
  Map<String, dynamic>? _roleSpecificData;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 4, vsync: this);
    _scrollController = ScrollController();

    // Initialize with empty controllers, will be updated when data is fetched
    _cardControllers = [];
    _cardAnimations = [];

    // Setup scroll listener for pagination
    _scrollController.addListener(_onScroll);

    // Validate authentication first before fetching orders
    _validateAuthenticationAndFetchHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    for (var controller in _cardControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // ✅ Safe parsing untuk numeric values
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  // ✅ Validate customer authentication first
  Future<void> _validateAuthenticationAndFetchHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('🔍 HistoryCustomer: Starting authentication validation...');

      // Step 1: Validate customer access
      final hasAccess = await AuthService.validateCustomerAccess();
      if (!hasAccess) {
        throw Exception('Access denied: Customer authentication required');
      }

      // Step 2: Get customer data
      _customerData = await AuthService.getCustomerData();
      if (_customerData == null) {
        throw Exception('Unable to retrieve customer data');
      }

      // Step 3: Get role-specific data for additional validation
      _roleSpecificData = await AuthService.getRoleSpecificData();
      if (_roleSpecificData == null) {
        throw Exception('Unable to retrieve role-specific data');
      }

      _isAuthenticated = true;

      print('✅ HistoryCustomer: Authentication validated successfully');
      print('   - Customer ID: ${_customerData!['id']}');
      print('   - Customer Name: ${_customerData!['name']}');
      print('   - Role: ${_roleSpecificData!['role'] ?? 'customer'}');

      // Step 4: Now fetch orders
      await _fetchOrderHistory(isRefresh: true);

    } catch (e) {
      print('❌ HistoryCustomer: Authentication error: $e');
      setState(() {
        _isLoading = false;
        _isAuthenticated = false;
        _errorMessage = 'Authentication failed: $e';
      });
    }
  }

  // Scroll listener for pagination
  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8) {
      _loadMoreHistory();
    }
  }

  // ✅ Fetch order history using getOrdersByUser()
  Future<void> _fetchOrderHistory({bool isRefresh = false}) async {
    // Check authentication before proceeding
    if (!_isAuthenticated) {
      print('⚠️ HistoryCustomer: Not authenticated, skipping fetch history');
      return;
    }

    if (isRefresh) {
      setState(() {
        _currentPage = 1;
        _hasMoreData = true;
        _isLoading = true;
        _errorMessage = null;
        orders.clear();
        storeCache.clear();
      });
    }

    try {
      print('🔍 HistoryCustomer: Fetching order history (page $_currentPage)...');

      // Get current tab filter
      String? statusFilter = _getStatusFilter(_tabController.index);

      // Fetch orders using OrderService.getOrdersByUser()
      final orderData = await OrderService.getOrdersByUser(
        page: _currentPage,
        limit: _pageSize,
        status: statusFilter,
        sortBy: 'created_at',
        sortOrder: 'desc',
      );

      print('📋 HistoryCustomer: Order data received');
      print('   - Status filter: $statusFilter');
      print('   - Total items: ${orderData['totalItems'] ?? 0}');
      print('   - Current page: ${orderData['currentPage'] ?? 1}');
      print('   - Total pages: ${orderData['totalPages'] ?? 1}');

      // Parse orders from response
      List<OrderModel> fetchedOrders = [];
      if (orderData['orders'] != null && orderData['orders'] is List) {
        for (var orderJson in orderData['orders']) {
          try {
            // ✅ Safe parsing untuk order data
            final safeOrderJson = _safeParseOrderJson(orderJson);

            // ✅ Create basic OrderModel from order data
            final order = await _buildCompleteOrderModel(safeOrderJson);
            if (order != null) {
              fetchedOrders.add(order);
            }
          } catch (e) {
            print('❌ HistoryCustomer: Error parsing order: $e');
            print('   Order data: $orderJson');
            // Continue with next order if one fails to parse
          }
        }
      }

      // Update pagination info
      _totalItems = orderData['totalItems'] ?? 0;
      _totalPages = orderData['totalPages'] ?? 1;
      _hasMoreData = _currentPage < _totalPages;

      // Update orders list
      if (isRefresh) {
        orders = fetchedOrders;
      } else {
        orders.addAll(fetchedOrders);
      }

      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });

      // Setup animations after data is fetched
      if (isRefresh) {
        _setupAnimations(orders.length);
        _startAnimations();
      }

      print('✅ HistoryCustomer: Orders fetched and displayed successfully');
      print('   - Total orders: ${orders.length}');

    } catch (e) {
      print('❌ HistoryCustomer: Error fetching order history: $e');
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _errorMessage = 'Failed to load order history: $e';
      });

      // Handle authentication errors specifically
      if (e.toString().contains('authentication') || e.toString().contains('Access denied')) {
        _handleAuthenticationError();
      }
    }
  }

  // ✅ Build complete OrderModel with store data and proper parsing
  Future<OrderModel?> _buildCompleteOrderModel(Map<String, dynamic> orderJson) async {
    try {
      // Extract store ID
      final storeId = _parseInt(orderJson['store_id']);

      // Get store data
      StoreModel? store = await _getStoreData(storeId);

      // Parse tracking updates from JSON string if needed
      List<Map<String, dynamic>>? trackingUpdates;
      if (orderJson['tracking_updates'] != null) {
        trackingUpdates = _parseTrackingUpdates(orderJson['tracking_updates']);
      }

      // Create OrderModel with all data
      final order = OrderModel(
        id: _parseInt(orderJson['id']),
        customerId: _parseInt(orderJson['customer_id']),
        storeId: storeId,
        driverId: orderJson['driver_id'] != null ? _parseInt(orderJson['driver_id']) : null,
        orderStatus: OrderStatusExtension.fromString(orderJson['order_status'] ?? 'pending'),
        deliveryStatus: DeliveryStatusExtension.fromString(orderJson['delivery_status'] ?? 'pending'),
        totalAmount: _parseDouble(orderJson['total_amount']),
        deliveryFee: _parseDouble(orderJson['delivery_fee']),
        estimatedPickupTime: orderJson['estimated_pickup_time'] != null
            ? DateTime.tryParse(orderJson['estimated_pickup_time'])
            : null,
        actualPickupTime: orderJson['actual_pickup_time'] != null
            ? DateTime.tryParse(orderJson['actual_pickup_time'])
            : null,
        estimatedDeliveryTime: orderJson['estimated_delivery_time'] != null
            ? DateTime.tryParse(orderJson['estimated_delivery_time'])
            : null,
        actualDeliveryTime: orderJson['actual_delivery_time'] != null
            ? DateTime.tryParse(orderJson['actual_delivery_time'])
            : null,
        trackingUpdates: trackingUpdates,
        createdAt: DateTime.parse(orderJson['created_at']),
        updatedAt: DateTime.parse(orderJson['updated_at']),
        store: store,
        items: [], // Will be populated if available in response
      );

      return order;
    } catch (e) {
      print('❌ HistoryCustomer: Error building OrderModel: $e');
      return null;
    }
  }

  // ✅ Get store data with caching
  Future<StoreModel?> _getStoreData(int storeId) async {
    // Check cache first
    if (storeCache.containsKey(storeId)) {
      return storeCache[storeId];
    }

    try {
      print('🏪 HistoryCustomer: Fetching store data for ID: $storeId');

      final storeResponse = await StoreService.getStoreById(storeId.toString());

      if (storeResponse['success'] == true && storeResponse['data'] != null) {
        final storeData = storeResponse['data'];
        final store = StoreModel.fromJson(storeData);

        // Cache the store
        storeCache[storeId] = store;

        print('✅ HistoryCustomer: Store data cached for: ${store.name}');
        return store;
      } else {
        print('❌ HistoryCustomer: Failed to get store data: ${storeResponse['error']}');
        return null;
      }
    } catch (e) {
      print('❌ HistoryCustomer: Error fetching store data: $e');
      return null;
    }
  }

  // ✅ Parse tracking updates from JSON string
  List<Map<String, dynamic>>? _parseTrackingUpdates(dynamic trackingData) {
    try {
      if (trackingData is String) {
        // Parse JSON string
        final parsed = jsonDecode(trackingData);
        if (parsed is List) {
          return List<Map<String, dynamic>>.from(parsed);
        }
      } else if (trackingData is List) {
        return List<Map<String, dynamic>>.from(trackingData);
      }
      return null;
    } catch (e) {
      print('❌ HistoryCustomer: Error parsing tracking updates: $e');
      return null;
    }
  }

  // ✅ Safe parsing untuk order JSON dengan numeric fields
  Map<String, dynamic> _safeParseOrderJson(Map<String, dynamic> json) {
    final safeJson = Map<String, dynamic>.from(json);

    // Safe parse numeric fields
    safeJson['id'] = _parseInt(json['id']);
    safeJson['customer_id'] = _parseInt(json['customer_id']);
    safeJson['store_id'] = _parseInt(json['store_id']);
    safeJson['driver_id'] = json['driver_id'] != null ? _parseInt(json['driver_id']) : null;
    safeJson['total_amount'] = _parseDouble(json['total_amount']);
    safeJson['delivery_fee'] = _parseDouble(json['delivery_fee']);

    return safeJson;
  }

  // Load more orders for pagination
  Future<void> _loadMoreHistory() async {
    if (_isLoadingMore || !_hasMoreData || !_isAuthenticated) return;

    setState(() {
      _isLoadingMore = true;
    });

    _currentPage++;
    await _fetchOrderHistory(isRefresh: false);
  }

  // ✅ Handle authentication errors
  void _handleAuthenticationError() {
    setState(() {
      _isAuthenticated = false;
      _customerData = null;
      _roleSpecificData = null;
      _errorMessage = 'Session expired. Please login again.';
    });
  }

  // Get status filter based on tab index
  String? _getStatusFilter(int tabIndex) {
    switch (tabIndex) {
      case 0: // All orders
        return null;
      case 1: // In progress
        return 'pending,confirmed,preparing,ready_for_pickup,on_delivery';
      case 2: // Completed
        return 'delivered';
      case 3: // Cancelled
        return 'cancelled,rejected';
      default:
        return null;
    }
  }

  // Setup animations based on number of items
  void _setupAnimations(int totalCards) {
    // Clean up existing controllers if any
    for (var controller in _cardControllers) {
      controller.dispose();
    }

    // Create new controllers
    _cardControllers = List.generate(
      totalCards,
          (index) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 600 + (index * 100)),
      ),
    );

    // Create slide animations for each card
    _cardAnimations = _cardControllers.map((controller) {
      return Tween<Offset>(
        begin: const Offset(0.5, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeOutCubic,
      ));
    }).toList();
  }

  // Start animations
  void _startAnimations() {
    Future.delayed(const Duration(milliseconds: 100), () {
      for (var controller in _cardControllers) {
        controller.forward();
      }
    });
  }

  // ✅ Get filtered orders based on tab index
  List<OrderModel> getFilteredOrders(int tabIndex) {
    switch (tabIndex) {
      case 0: // All orders
        return orders;
      case 1: // In progress
        return orders.where((order) => !order.orderStatus.isCompleted).toList();
      case 2: // Completed
        return orders.where((order) => order.orderStatus == OrderStatus.delivered).toList();
      case 3: // Cancelled
        return orders.where((order) =>
        order.orderStatus == OrderStatus.cancelled ||
            order.orderStatus == OrderStatus.rejected
        ).toList();
      default:
        return orders;
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      if (index == 0) {
        Navigator.pushReplacementNamed(context, HomePage.route);
      }
    });
  }

  Widget _buildStatusChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  // ✅ Helper methods for order display
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
        return 'Diproses';
    }
  }

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
      case OrderStatus.confirmed:
        return Colors.indigo;
      default:
        return GlobalStyle.primaryColor;
    }
  }

  String _getOrderItemsText(OrderModel order) {
    if (order.items.isEmpty) {
      return "Detail pesanan tersedia di halaman detail";
    }
    if (order.items.length == 1) {
      return order.items[0].name;
    } else {
      final firstItem = order.items[0].name;
      final otherItemsCount = order.items.length - 1;
      return '$firstItem, +$otherItemsCount item lainnya';
    }
  }

  String? _getFirstItemImageUrl(OrderModel order) {
    if (order.items.isNotEmpty && order.items[0].imageUrl != null) {
      return order.items[0].imageUrl;
    }
    return null;
  }

  // ✅ Build order history card
  Widget _buildOrderCard(OrderModel order, int index) {
    final formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(order.createdAt);
    final statusText = _getStatusText(order.orderStatus);
    final statusColor = _getStatusColor(order.orderStatus);
    final itemsText = _getOrderItemsText(order);
    final imageUrl = _getFirstItemImageUrl(order);

    return SlideTransition(
      position: index < _cardAnimations.length ? _cardAnimations[index] : const AlwaysStoppedAnimation(Offset.zero),
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
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Navigate to HistoryDetailPage with complete order data
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => HistoryDetailPage(
                  order: order,
                ),
              ),
            ).then((_) => _fetchOrderHistory(isRefresh: true));
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Order item image or store image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: imageUrl != null
                          ? ImageService.displayImage(
                        imageSource: imageUrl,
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
                      )
                          : order.store?.imageUrl != null
                          ? ImageService.displayImage(
                        imageSource: order.store!.imageUrl!,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        placeholder: Container(
                          width: 60,
                          height: 60,
                          color: Colors.grey[200],
                          child: const Icon(Icons.store, color: Colors.grey),
                        ),
                        errorWidget: Container(
                          width: 60,
                          height: 60,
                          color: Colors.grey[300],
                          child: const Icon(Icons.store, color: Colors.grey),
                        ),
                      )
                          : Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.restaurant_menu,
                          color: Colors.grey,
                          size: 30,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  order.store?.name ?? 'Unknown Store',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: GlobalStyle.fontColor,
                                    fontFamily: GlobalStyle.fontFamily,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildStatusChip(statusText, statusColor),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Order #${order.id}',
                            style: TextStyle(
                              fontSize: 13,
                              color: GlobalStyle.primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formattedDate,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            itemsText,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w500,
                              fontFamily: GlobalStyle.fontFamily,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Pembayaran',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          order.formatTotalAmount(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: GlobalStyle.primaryColor,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => HistoryDetailPage(
                              order: order,
                            ),
                          ),
                        ).then((_) => _fetchOrderHistory(isRefresh: true));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GlobalStyle.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Lihat Detail',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/animations/empty.json',
              width: 200,
              height: 200,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
                fontFamily: GlobalStyle.fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Belum ada pesanan untuk ditampilkan',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontFamily: GlobalStyle.fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushReplacementNamed(context, HomePage.route);
              },
              icon: const Icon(Icons.shopping_bag),
              label: const Text('Mulai Belanja'),
              style: ElevatedButton.styleFrom(
                backgroundColor: GlobalStyle.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
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
            'Memuat riwayat pesanan...',
            style: TextStyle(
              fontSize: 16,
              color: GlobalStyle.primaryColor,
              fontWeight: FontWeight.w500,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Enhanced error state with authentication handling
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/animations/caution.json',
            width: 150,
            height: 150,
          ),
          const SizedBox(height: 16),
          Text(
            !_isAuthenticated ? 'Session Expired' : 'Gagal Memuat Data',
            style: TextStyle(
              fontSize: 18,
              color: Colors.red[600],
              fontWeight: FontWeight.bold,
              fontFamily: GlobalStyle.fontFamily,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage ?? 'Terjadi kesalahan saat memuat data',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontFamily: GlobalStyle.fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              if (!_isAuthenticated) {
                // Redirect to login or home
                Navigator.pushReplacementNamed(context, HomePage.route);
              } else {
                // Retry fetching orders
                _fetchOrderHistory(isRefresh: true);
              }
            },
            icon: Icon(!_isAuthenticated ? Icons.home : Icons.refresh),
            label: Text(!_isAuthenticated ? 'Kembali ke Home' : 'Coba Lagi'),
            style: ElevatedButton.styleFrom(
              backgroundColor: GlobalStyle.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadMoreIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(GlobalStyle.primaryColor),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Memuat lebih banyak...',
            style: TextStyle(
              color: GlobalStyle.primaryColor,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pushNamedAndRemoveUntil(
          context,
          HomePage.route,
              (route) => false,
        );
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xffF5F7FA),
        appBar: AppBar(
          elevation: 0.5,
          backgroundColor: Colors.white,
          title: Text(
            'Riwayat Pesanan',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: GlobalStyle.fontColor,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(4.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: GlobalStyle.primaryColor, width: 1.0),
              ),
              child: Icon(Icons.arrow_back_ios_new, color: GlobalStyle.primaryColor, size: 18),
            ),
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                HomePage.route,
                    (route) => false,
              );
            },
          ),
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: GlobalStyle.primaryColor,
            unselectedLabelColor: Colors.grey[600],
            labelStyle: const TextStyle(fontWeight: FontWeight.w600),
            indicatorColor: GlobalStyle.primaryColor,
            indicatorWeight: 3,
            onTap: (index) {
              // Refresh data when tab changes
              if (_isAuthenticated) {
                _fetchOrderHistory(isRefresh: true);
              }
            },
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Semua'),
                    if (orders.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: GlobalStyle.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          orders.length.toString(),
                          style: TextStyle(
                            fontSize: 11,
                            color: GlobalStyle.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Tab(text: 'Diproses'),
              const Tab(text: 'Selesai'),
              const Tab(text: 'Dibatalkan'),
            ],
          ),
        ),
        body: _isLoading
            ? _buildLoadingState()
            : _errorMessage != null
            ? _buildErrorState()
            : RefreshIndicator(
          onRefresh: () => _isAuthenticated
              ? _fetchOrderHistory(isRefresh: true)
              : _validateAuthenticationAndFetchHistory(),
          color: GlobalStyle.primaryColor,
          child: TabBarView(
            controller: _tabController,
            children: List.generate(4, (tabIndex) {
              final filteredOrders = getFilteredOrders(tabIndex);

              if (filteredOrders.isEmpty && !_isLoading) {
                return _buildEmptyState(
                    'Tidak ada pesanan ${tabIndex == 0 ? '' :
                    tabIndex == 1 ? 'yang sedang diproses' :
                    tabIndex == 2 ? 'yang selesai' : 'yang dibatalkan'}'
                );
              }

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: filteredOrders.length + (_isLoadingMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index < filteredOrders.length) {
                    return _buildOrderCard(filteredOrders[index], index);
                  } else {
                    return _buildLoadMoreIndicator();
                  }
                },
              );
            }),
          ),
        ),
        bottomNavigationBar: CustomBottomNavigation(
          selectedIndex: _selectedIndex,
          onItemTapped: _onItemTapped,
        ),
      ),
    );
  }
}