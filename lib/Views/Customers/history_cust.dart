import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';

// Import Models
import 'package:del_pick/Models/order.dart';
import 'package:del_pick/Models/order_enum.dart';
import 'package:del_pick/Models/store.dart';
import 'package:del_pick/Models/menu_item.dart';
import 'package:del_pick/Models/service_order.dart';

// Import Services
import 'package:del_pick/Services/order_service.dart';
import 'package:del_pick/Services/service_order_service.dart';
import 'package:del_pick/Services/menu_service.dart';
import 'package:del_pick/Services/image_service.dart';
import 'package:del_pick/Services/auth_service.dart';

// Import Components and Screens
import '../Component/cust_bottom_navigation.dart';
import 'package:del_pick/Common/global_style.dart';
import 'home_cust.dart';
import 'history_detail.dart';

// ✅ TAMBAHAN: Base class untuk unified history items
abstract class HistoryItem {
  int get id;
  DateTime get createdAt;
  String get displayName;
  String get statusText;
  Color get statusColor;
  String get formattedAmount;
  String get itemsText;
  String? get imageUrl;
  bool get isCompleted;
  String get orderType; // 'food_order' atau 'service_order'
}

// ✅ TAMBAHAN: Wrapper untuk regular orders
class FoodOrderHistoryItem extends HistoryItem {
  final OrderModel order;

  FoodOrderHistoryItem(this.order);

  @override
  int get id => order.id;

  @override
  DateTime get createdAt => order.createdAt;

  @override
  String get displayName => order.store?.name ?? 'Unknown Store';

  @override
  String get statusText => _getStatusText(order.orderStatus);

  @override
  Color get statusColor => _getStatusColor(order.orderStatus);

  @override
  String get formattedAmount => order.formatTotalAmount();

  @override
  String get itemsText => _getOrderItemsText(order);

  @override
  String? get imageUrl => _getFirstItemImageUrl(order);

  @override
  bool get isCompleted => order.orderStatus.isCompleted;

  @override
  String get orderType => 'food_order';

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
      return "Tidak ada item";
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
}

// ✅ TAMBAHAN: Wrapper untuk service orders
class ServiceOrderHistoryItem extends HistoryItem {
  final ServiceOrderModel serviceOrder;

  ServiceOrderHistoryItem(this.serviceOrder);

  @override
  int get id => serviceOrder.id;

  @override
  DateTime get createdAt => serviceOrder.createdAt;

  @override
  String get displayName => 'Jasa Titip ke IT Del';

  @override
  String get statusText => ServiceOrderService.getStatusDisplayText(serviceOrder.status.value);

  @override
  Color get statusColor => _getServiceOrderStatusColor(serviceOrder.status);

  @override
  String get formattedAmount => serviceOrder.formattedServiceFee;

  @override
  String get itemsText => serviceOrder.description ?? 'Jasa Titip';

  @override
  String? get imageUrl => null; // Service orders don't have images

  @override
  bool get isCompleted => serviceOrder.status.isCompleted;

  @override
  String get orderType => 'service_order';

  Color _getServiceOrderStatusColor(ServiceOrderStatus status) {
    switch (status) {
      case ServiceOrderStatus.completed:
        return Colors.green;
      case ServiceOrderStatus.cancelled:
        return Colors.red;
      case ServiceOrderStatus.inProgress:
        return Colors.blue;
      case ServiceOrderStatus.driverFound:
        return Colors.orange;
      case ServiceOrderStatus.pending:
        return GlobalStyle.primaryColor;
      default:
        return GlobalStyle.primaryColor;
    }
  }
}

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
  List<ServiceOrderModel> serviceOrders = [];
  List<HistoryItem> allHistoryItems = []; // ✅ TAMBAHAN: Combined history items
  Map<int, List<MenuItemModel>> storeMenuItems = {}; // Cache menu items by store ID
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

  // ✅ TAMBAHAN: Authentication state
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

    // ✅ PERBAIKAN: Validate authentication first before fetching orders
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

  // ✅ TAMBAHAN: Safe parsing untuk numeric values yang mungkin berupa string
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  // ✅ BARU: Validate customer authentication first
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

      // Step 4: Now fetch both orders and service orders
      await _fetchAllHistory(isRefresh: true);

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

  // ✅ BARU: Fetch both food orders and service orders
  Future<void> _fetchAllHistory({bool isRefresh = false}) async {
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
      });
    }

    try {
      print('🔍 HistoryCustomer: Fetching all history (page $_currentPage)...');

      // Get current tab filter
      String? statusFilter = _getStatusFilter(_tabController.index);

      // ✅ TAMBAHAN: Fetch both food orders and service orders in parallel
      final List<Future> futures = [
        _fetchFoodOrders(statusFilter),
        _fetchServiceOrders(statusFilter),
      ];

      await Future.wait(futures);

      // ✅ TAMBAHAN: Combine and sort all items by date
      _combineAndSortHistoryItems();

      // Load menu items for stores if needed
      await _loadMenuItemsForOrders(orders);

      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });

      // Setup animations after data is fetched
      if (isRefresh) {
        _setupAnimations(allHistoryItems.length);
        _startAnimations();
      }

      print('✅ HistoryCustomer: All history fetched and displayed successfully');
      print('   - Food orders: ${orders.length}');
      print('   - Service orders: ${serviceOrders.length}');
      print('   - Total items: ${allHistoryItems.length}');

    } catch (e) {
      print('❌ HistoryCustomer: Error fetching history: $e');
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _errorMessage = 'Failed to load history: $e';
      });

      // ✅ TAMBAHAN: Handle authentication errors specifically
      if (e.toString().contains('authentication') || e.toString().contains('Access denied')) {
        _handleAuthenticationError();
      }
    }
  }

  // ✅ BARU: Fetch food orders
  Future<void> _fetchFoodOrders(String? statusFilter) async {
    try {
      print('🍽️ HistoryCustomer: Fetching food orders...');

      final orderData = await OrderService.getOrdersByUser(
        page: _currentPage,
        limit: _pageSize,
        status: statusFilter,
        sortBy: 'created_at',
        sortOrder: 'desc',
      );

      print('📋 HistoryCustomer: Food order data received');
      print('   - Status filter: $statusFilter');
      print('   - Total items: ${orderData['totalItems'] ?? 0}');

      // Parse the response with safe numeric parsing
      List<OrderModel> fetchedOrders = [];
      if (orderData['orders'] != null && orderData['orders'] is List) {
        for (var orderJson in orderData['orders']) {
          try {
            // ✅ PERBAIKAN: Safe parsing untuk numeric fields
            final safeOrderJson = _safeParseOrderJson(orderJson);
            final order = OrderModel.fromJson(safeOrderJson);
            fetchedOrders.add(order);
          } catch (e) {
            print('❌ HistoryCustomer: Error parsing food order: $e');
            print('   Order data: $orderJson');
            // Continue with next order if one fails to parse
          }
        }
      }

      // Update pagination info
      _totalItems = orderData['totalItems'] ?? 0;
      _totalPages = orderData['totalPages'] ?? 1;
      _hasMoreData = _currentPage < _totalPages;

      orders = fetchedOrders;
      print('✅ HistoryCustomer: Parsed ${fetchedOrders.length} food orders successfully');

    } catch (e) {
      print('❌ HistoryCustomer: Error fetching food orders: $e');
      // Don't throw, let service orders still be fetched
    }
  }

  // ✅ BARU: Fetch service orders (jastip)
  Future<void> _fetchServiceOrders(String? statusFilter) async {
    try {
      print('🚚 HistoryCustomer: Fetching service orders...');

      // Convert status filter for service orders
      String? serviceOrderStatus = _convertToServiceOrderStatus(statusFilter);

      final serviceOrderData = await ServiceOrderService.getServiceOrdersByCustomer(
        page: _currentPage,
        limit: _pageSize,
        status: serviceOrderStatus,
      );

      print('📋 HistoryCustomer: Service order data received');
      print('   - Status filter: $serviceOrderStatus');
      print('   - Total items: ${serviceOrderData['totalItems'] ?? 0}');

      // Parse the response
      List<ServiceOrderModel> fetchedServiceOrders = [];
      if (serviceOrderData['serviceOrders'] != null && serviceOrderData['serviceOrders'] is List) {
        for (var serviceOrderJson in serviceOrderData['serviceOrders']) {
          try {
            final serviceOrder = ServiceOrderModel.fromJson(serviceOrderJson);
            fetchedServiceOrders.add(serviceOrder);
          } catch (e) {
            print('❌ HistoryCustomer: Error parsing service order: $e');
            print('   Service Order data: $serviceOrderJson');
            // Continue with next order if one fails to parse
          }
        }
      }

      serviceOrders = fetchedServiceOrders;
      print('✅ HistoryCustomer: Parsed ${fetchedServiceOrders.length} service orders successfully');

    } catch (e) {
      print('❌ HistoryCustomer: Error fetching service orders: $e');
      // Don't throw, let the function continue
    }
  }

  // ✅ BARU: Safe parsing untuk order JSON dengan numeric fields
  Map<String, dynamic> _safeParseOrderJson(Map<String, dynamic> json) {
    final safeJson = Map<String, dynamic>.from(json);

    // Safe parse numeric fields yang mungkin berupa string
    safeJson['total_amount'] = _parseDouble(json['total_amount']);
    safeJson['delivery_fee'] = _parseDouble(json['delivery_fee']);
    safeJson['customer_latitude'] = _parseDouble(json['customer_latitude']);
    safeJson['customer_longitude'] = _parseDouble(json['customer_longitude']);

    // Safe parse items if present
    if (safeJson['items'] != null && safeJson['items'] is List) {
      final List<dynamic> items = safeJson['items'];
      for (int i = 0; i < items.length; i++) {
        if (items[i] is Map<String, dynamic>) {
          final Map<String, dynamic> item = Map<String, dynamic>.from(items[i]);
          item['price'] = _parseDouble(item['price']);
          items[i] = item;
        }
      }
    }

    return safeJson;
  }

  // ✅ BARU: Convert food order status filter to service order status
  String? _convertToServiceOrderStatus(String? foodOrderStatus) {
    if (foodOrderStatus == null) return null;

    // Map food order statuses to service order statuses
    if (foodOrderStatus.contains('pending') ||
        foodOrderStatus.contains('confirmed') ||
        foodOrderStatus.contains('preparing') ||
        foodOrderStatus.contains('ready_for_pickup') ||
        foodOrderStatus.contains('on_delivery')) {
      return 'pending,driver_found,in_progress';
    } else if (foodOrderStatus.contains('delivered')) {
      return 'completed';
    } else if (foodOrderStatus.contains('cancelled')) {
      return 'cancelled';
    }

    return null;
  }

  // ✅ BARU: Combine and sort all history items
  void _combineAndSortHistoryItems() {
    allHistoryItems.clear();

    // Add food orders
    for (final order in orders) {
      allHistoryItems.add(FoodOrderHistoryItem(order));
    }

    // Add service orders
    for (final serviceOrder in serviceOrders) {
      allHistoryItems.add(ServiceOrderHistoryItem(serviceOrder));
    }

    // Sort by creation date (newest first)
    allHistoryItems.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    print('✅ HistoryCustomer: Combined and sorted ${allHistoryItems.length} history items');
  }

  // Load more orders for pagination
  Future<void> _loadMoreHistory() async {
    if (_isLoadingMore || !_hasMoreData || !_isAuthenticated) return;

    setState(() {
      _isLoadingMore = true;
    });

    _currentPage++;
    await _fetchAllHistory(isRefresh: false);
  }

  // ✅ BARU: Handle authentication errors
  void _handleAuthenticationError() {
    setState(() {
      _isAuthenticated = false;
      _customerData = null;
      _roleSpecificData = null;
      _errorMessage = 'Session expired. Please login again.';
    });
  }

  // ✅ PERBAIKAN: Enhanced menu items loading with better error handling
  Future<void> _loadMenuItemsForOrders(List<OrderModel> ordersList) async {
    // Get unique store IDs that we don't have menu items for yet
    Set<int> storeIds = {};
    for (var order in ordersList) {
      if (!storeMenuItems.containsKey(order.storeId)) {
        storeIds.add(order.storeId);
      }
    }

    print('🍽️ HistoryCustomer: Loading menu items for ${storeIds.length} stores...');

    // Load menu items for each store
    for (int storeId in storeIds) {
      try {
        final menuData = await MenuItemService.getMenuItemsByStore(
          storeId: storeId.toString(),
          page: 1,
          limit: 50, // Get enough items to cover order items
          isAvailable: null, // Get all items regardless of availability
        );

        if (menuData['data'] != null && menuData['data'] is List) {
          List<MenuItemModel> menuItems = [];
          for (var menuJson in menuData['data']) {
            try {
              final menuItem = MenuItemModel.fromJson(menuJson);
              menuItems.add(menuItem);
            } catch (e) {
              print('❌ HistoryCustomer: Error parsing menu item: $e');
            }
          }
          storeMenuItems[storeId] = menuItems;
          print('✅ HistoryCustomer: Loaded ${menuItems.length} menu items for store $storeId');
        }
      } catch (e) {
        print('❌ HistoryCustomer: Error loading menu items for store $storeId: $e');
        // Continue with other stores if one fails
      }
    }
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
        return 'cancelled';
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

  // ✅ PERBAIKAN: Get filtered history items based on tab index
  List<HistoryItem> getFilteredHistoryItems(int tabIndex) {
    switch (tabIndex) {
      case 0: // All orders
        return allHistoryItems;
      case 1: // In progress
        return allHistoryItems.where((item) => !item.isCompleted).toList();
      case 2: // Completed
        return allHistoryItems.where((item) => item.isCompleted).toList();
      case 3: // Cancelled
        return allHistoryItems.where((item) =>
        item.statusText.toLowerCase().contains('batal') ||
            item.statusText.toLowerCase().contains('ditolak')
        ).toList();
      default:
        return allHistoryItems;
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

  // ✅ PERBAIKAN: Unified history card yang bisa handle food orders dan service orders
  Widget _buildHistoryCard(HistoryItem item, int index) {
    final formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(item.createdAt);

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
            if (item is FoodOrderHistoryItem) {
              // Navigate to existing HistoryDetailPage for food orders
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HistoryDetailPage(
                    order: item.order,
                  ),
                ),
              ).then((_) => _fetchAllHistory(isRefresh: true));
            } else if (item is ServiceOrderHistoryItem) {
              // TODO: Navigate to service order detail page
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Detail jasa titip order #${item.id}'),
                  backgroundColor: GlobalStyle.primaryColor,
                ),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Order item image or icon
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: item.imageUrl != null
                          ? ImageService.displayImage(
                        imageSource: item.imageUrl!,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        placeholder: Container(
                          width: 60,
                          height: 60,
                          color: Colors.grey[200],
                          child: Icon(
                              item.orderType == 'service_order'
                                  ? Icons.delivery_dining
                                  : Icons.restaurant_menu,
                              color: Colors.grey
                          ),
                        ),
                        errorWidget: Container(
                          width: 60,
                          height: 60,
                          color: Colors.grey[300],
                          child: const Icon(Icons.image_not_supported, color: Colors.grey),
                        ),
                      )
                          : Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: item.orderType == 'service_order'
                              ? Colors.blue[50]
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          item.orderType == 'service_order'
                              ? Icons.delivery_dining
                              : Icons.restaurant_menu,
                          color: item.orderType == 'service_order'
                              ? Colors.blue
                              : Colors.grey,
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
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.displayName,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: GlobalStyle.fontColor,
                                        fontFamily: GlobalStyle.fontFamily,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    // ✅ TAMBAHAN: Badge untuk type order
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: item.orderType == 'service_order'
                                            ? Colors.blue.withOpacity(0.1)
                                            : Colors.green.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        item.orderType == 'service_order' ? 'Jasa Titip' : 'Pesan Makanan',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                          color: item.orderType == 'service_order'
                                              ? Colors.blue[700]
                                              : Colors.green[700],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildStatusChip(item.statusText, item.statusColor),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${item.orderType == 'service_order' ? 'Service Order' : 'Order'} #${item.id}',
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
                            item.itemsText,
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
                          item.orderType == 'service_order' ? 'Biaya Layanan' : 'Total Pembayaran',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.formattedAmount,
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
                        if (item is FoodOrderHistoryItem) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => HistoryDetailPage(
                                order: item.order,
                              ),
                            ),
                          ).then((_) => _fetchAllHistory(isRefresh: true));
                        } else if (item is ServiceOrderHistoryItem) {
                          // TODO: Navigate to service order detail page
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Detail jasa titip #${item.id}'),
                              backgroundColor: GlobalStyle.primaryColor,
                            ),
                          );
                        }
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

  // ✅ PERBAIKAN: Enhanced error state with authentication handling
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
                _fetchAllHistory(isRefresh: true);
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
                _fetchAllHistory(isRefresh: true);
              }
            },
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Semua'),
                    if (allHistoryItems.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: GlobalStyle.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          allHistoryItems.length.toString(),
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
          onRefresh: () => _isAuthenticated ? _fetchAllHistory(isRefresh: true) : _validateAuthenticationAndFetchHistory(),
          color: GlobalStyle.primaryColor,
          child: TabBarView(
            controller: _tabController,
            children: List.generate(4, (tabIndex) {
              final filteredItems = getFilteredHistoryItems(tabIndex);

              if (filteredItems.isEmpty && !_isLoading) {
                return _buildEmptyState(
                    'Tidak ada pesanan ${tabIndex == 0 ? '' : tabIndex == 1 ? 'yang sedang diproses' : tabIndex == 2 ? 'yang selesai' : 'yang dibatalkan'}'
                );
              }

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: filteredItems.length + (_isLoadingMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index < filteredItems.length) {
                    return _buildHistoryCard(filteredItems[index], index);
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