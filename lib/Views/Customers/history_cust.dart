import 'dart:convert';
import 'dart:isolate';
import 'dart:async';

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

// Ultra-Optimized Cache System for History
class _HistoryCacheManager {
  static final Map<String, List<OrderModel>> _ordersCache = {};
  static final Map<int, StoreModel> _storeCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 3);
  static const Duration _storeCacheExpiry = Duration(minutes: 10);

  static bool _isCacheValid(String key, {Duration? customExpiry}) {
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null) return false;
    final expiry = customExpiry ?? _cacheExpiry;
    return DateTime.now().difference(timestamp) < expiry;
  }

  static void cacheOrders(String key, List<OrderModel> orders) {
    _ordersCache[key] = orders;
    _cacheTimestamps['orders_$key'] = DateTime.now();
  }

  static List<OrderModel>? getCachedOrders(String key) {
    if (_isCacheValid('orders_$key')) {
      return _ordersCache[key];
    }
    return null;
  }

  static void cacheStore(int storeId, StoreModel store) {
    _storeCache[storeId] = store;
    _cacheTimestamps['store_$storeId'] = DateTime.now();
  }

  static StoreModel? getCachedStore(int storeId) {
    if (_isCacheValid('store_$storeId', customExpiry: _storeCacheExpiry)) {
      return _storeCache[storeId];
    }
    return null;
  }

  static void clearExpiredCache() {
    final now = DateTime.now();
    final expiredKeys = _cacheTimestamps.entries
        .where((entry) => now.difference(entry.value) >=
        (entry.key.startsWith('store_') ? _storeCacheExpiry : _cacheExpiry))
        .map((entry) => entry.key)
        .toList();

    for (final key in expiredKeys) {
      _cacheTimestamps.remove(key);
      if (key.startsWith('orders_')) {
        _ordersCache.remove(key.substring(7));
      } else if (key.startsWith('store_')) {
        _storeCache.remove(int.tryParse(key.substring(6)) ?? 0);
      }
    }
  }
}

// Background Processing for Heavy Operations
class _HistoryBackgroundProcessor {
  static Future<List<StoreModel>> batchFetchStoresInBackground(List<int> storeIds) async {
    return await Isolate.run(() async {
      final stores = <StoreModel>[];

      for (final storeId in storeIds) {
        try {
          final cachedStore = _HistoryCacheManager.getCachedStore(storeId);
          if (cachedStore != null) {
            stores.add(cachedStore);
            continue;
          }

          final storeResponse = await StoreService.getStoreById(storeId.toString());
          if (storeResponse['success'] == true && storeResponse['data'] != null) {
            final store = StoreModel.fromJson(storeResponse['data']);
            stores.add(store);
            _HistoryCacheManager.cacheStore(storeId, store);
          }
        } catch (e) {
          // Skip failed stores but continue processing
          continue;
        }
      }

      return stores;
    });
  }

  static Map<String, dynamic> processOrderDataInBackground(List<dynamic> rawOrders) {
    final orders = <OrderModel>[];
    final storeIds = <int>[];

    for (var orderJson in rawOrders) {
      try {
        final safeOrderJson = _safeParseOrderJson(orderJson);
        final order = _buildBasicOrderModel(safeOrderJson);
        if (order != null) {
          orders.add(order);
          if (!storeIds.contains(order.storeId)) {
            storeIds.add(order.storeId);
          }
        }
      } catch (e) {
        continue; // Skip invalid orders
      }
    }

    return {
      'orders': orders,
      'storeIds': storeIds,
    };
  }

  static Map<String, dynamic> _safeParseOrderJson(Map<String, dynamic> json) {
    return {
      'id': _parseInt(json['id']),
      'customer_id': _parseInt(json['customer_id']),
      'store_id': _parseInt(json['store_id']),
      'driver_id': json['driver_id'] != null ? _parseInt(json['driver_id']) : null,
      'total_amount': _parseDouble(json['total_amount']),
      'delivery_fee': _parseDouble(json['delivery_fee']),
      'order_status': json['order_status'] ?? 'pending',
      'delivery_status': json['delivery_status'] ?? 'pending',
      'created_at': json['created_at'],
      'updated_at': json['updated_at'],
      'tracking_updates': json['tracking_updates'],
      'estimated_pickup_time': json['estimated_pickup_time'],
      'actual_pickup_time': json['actual_pickup_time'],
      'estimated_delivery_time': json['estimated_delivery_time'],
      'actual_delivery_time': json['actual_delivery_time'],
    };
  }

  static OrderModel? _buildBasicOrderModel(Map<String, dynamic> orderJson) {
    try {
      return OrderModel(
        id: orderJson['id'],
        customerId: orderJson['customer_id'],
        storeId: orderJson['store_id'],
        driverId: orderJson['driver_id'],
        orderStatus: OrderStatusExtension.fromString(orderJson['order_status']),
        deliveryStatus: DeliveryStatusExtension.fromString(orderJson['delivery_status']),
        totalAmount: orderJson['total_amount'],
        deliveryFee: orderJson['delivery_fee'],
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
        trackingUpdates: _parseTrackingUpdates(orderJson['tracking_updates']),
        createdAt: DateTime.parse(orderJson['created_at']),
        updatedAt: DateTime.parse(orderJson['updated_at']),
        store: null, // Will be set later
        items: [],
      );
    } catch (e) {
      return null;
    }
  }

  static List<Map<String, dynamic>>? _parseTrackingUpdates(dynamic trackingData) {
    try {
      if (trackingData is String) {
        final parsed = jsonDecode(trackingData);
        if (parsed is List) {
          return List<Map<String, dynamic>>.from(parsed);
        }
      } else if (trackingData is List) {
        return List<Map<String, dynamic>>.from(trackingData);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

class HistoryCustomer extends StatefulWidget {
  static const String route = "/Customers/HistoryCustomer";

  const HistoryCustomer({Key? key}) : super(key: key);

  @override
  State<HistoryCustomer> createState() => _HistoryCustomerState();
}

class _HistoryCustomerState extends State<HistoryCustomer>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {

  static const bool _debugMode = false;
  static const int _pageSize = 10;

  void _log(String message) {
    if (_debugMode) print(message);
  }

  @override
  bool get wantKeepAlive => true;

  // Core Controllers
  late TabController _tabController;
  late ScrollController _scrollController;

  // Performance-Optimized State with ValueNotifiers
  final ValueNotifier<int> _selectedIndexNotifier = ValueNotifier(1);
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier(true);
  final ValueNotifier<bool> _isLoadingMoreNotifier = ValueNotifier(false);
  final ValueNotifier<String?> _errorNotifier = ValueNotifier(null);
  final ValueNotifier<List<OrderModel>> _ordersNotifier = ValueNotifier([]);
  final ValueNotifier<bool> _isAuthenticatedNotifier = ValueNotifier(false);

  // Animation optimization
  late List<AnimationController> _cardControllers;
  late List<Animation<Offset>> _cardAnimations;

  // Pagination state
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalItems = 0;
  bool _hasMoreData = true;

  // Authentication state
  Map<String, dynamic>? _customerData;
  Map<String, dynamic>? _roleSpecificData;

  // Performance flags
  bool _disposed = false;
  Timer? _refreshDebounce;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _startBackgroundCacheCleanup();
    _authenticateAndLoadData();
  }

  void _initializeControllers() {
    _tabController = TabController(length: 4, vsync: this);
    _scrollController = ScrollController();
    _cardControllers = [];
    _cardAnimations = [];

    // Optimized scroll listener with throttling
    Timer? scrollThrottle;
    _scrollController.addListener(() {
      scrollThrottle?.cancel();
      scrollThrottle = Timer(const Duration(milliseconds: 100), () {
        if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8) {
          _loadMoreHistory();
        }
      });
    });

    // Tab change listener with debouncing
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _debounceRefresh();
      }
    });
  }

  void _startBackgroundCacheCleanup() {
    Timer.periodic(const Duration(minutes: 1), (timer) {
      if (_disposed) {
        timer.cancel();
        return;
      }
      _HistoryCacheManager.clearExpiredCache();
    });
  }

  void _debounceRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 300), () {
      if (_isAuthenticatedNotifier.value && mounted) {
        _fetchOrderHistoryOptimized(isRefresh: true);
      }
    });
  }

  // Ultra-Fast Authentication and Data Loading
  Future<void> _authenticateAndLoadData() async {
    _isLoadingNotifier.value = true;
    _errorNotifier.value = null;

    try {
      _log('Starting authentication validation...');

      // Parallel authentication checks
      final authResults = await Future.wait([
        AuthService.validateCustomerAccess(),
        AuthService.getCustomerData(),
        AuthService.getRoleSpecificData(),
      ]);

      final hasAccess = authResults[0] as bool;
      _customerData = authResults[1] as Map<String, dynamic>?;
      _roleSpecificData = authResults[2] as Map<String, dynamic>?;

      if (!hasAccess || _customerData == null || _roleSpecificData == null) {
        throw Exception('Access denied: Customer authentication required');
      }

      _isAuthenticatedNotifier.value = true;
      _log('Authentication successful');

      // Load order history
      await _fetchOrderHistoryOptimized(isRefresh: true);

    } catch (e) {
      _log('Authentication error: $e');
      _errorNotifier.value = 'Authentication failed: $e';
      _isAuthenticatedNotifier.value = false;
    } finally {
      _isLoadingNotifier.value = false;
    }
  }

  // Ultra-Optimized Order History Fetching
  Future<void> _fetchOrderHistoryOptimized({bool isRefresh = false}) async {
    if (!_isAuthenticatedNotifier.value) {
      _log('Not authenticated, skipping fetch');
      return;
    }

    if (isRefresh) {
      _currentPage = 1;
      _hasMoreData = true;
      _isLoadingNotifier.value = true;
      _errorNotifier.value = null;
      _ordersNotifier.value = [];
    }

    try {
      _log('Fetching order history (page $_currentPage)...');

      // Check cache first
      final statusFilter = _getStatusFilter(_tabController.index);
      final cacheKey = '${statusFilter ?? 'all'}_page_$_currentPage';
      final cachedOrders = _HistoryCacheManager.getCachedOrders(cacheKey);

      if (cachedOrders != null && !isRefresh) {
        _log('Using cached orders');
        _updateOrdersFromCache(cachedOrders, isRefresh);
        return;
      }

      // Fetch from API
      final orderData = await OrderService.getOrdersByUser(
        page: _currentPage,
        limit: _pageSize,
        status: statusFilter,
        sortBy: 'created_at',
        sortOrder: 'desc',
      );

      // Background processing of order data
      final processedData = _HistoryBackgroundProcessor.processOrderDataInBackground(
          orderData['orders'] ?? []
      );

      final orders = processedData['orders'] as List<OrderModel>;
      final storeIds = processedData['storeIds'] as List<int>;

      // Background fetch stores in parallel
      if (storeIds.isNotEmpty) {
        _fetchStoresInBackground(orders, storeIds);
      }

      // Update UI immediately with basic order data
      _updatePaginationInfo(orderData);
      _updateOrdersList(orders, isRefresh);

      // Cache the results
      _HistoryCacheManager.cacheOrders(cacheKey, orders);

      _log('Orders fetched successfully: ${orders.length}');

    } catch (e) {
      _log('Error fetching order history: $e');
      _errorNotifier.value = 'Failed to load order history: $e';

      if (e.toString().contains('authentication') ||
          e.toString().contains('Access denied')) {
        _handleAuthenticationError();
      }
    } finally {
      _isLoadingNotifier.value = false;
      _isLoadingMoreNotifier.value = false;
    }
  }

  // Background Store Fetching
  Future<void> _fetchStoresInBackground(List<OrderModel> orders, List<int> storeIds) async {
    try {
      final stores = await _HistoryBackgroundProcessor.batchFetchStoresInBackground(storeIds);

      // Map stores to orders
      final storeMap = {for (var store in stores) store.storeId: store};

      // Update orders with store data
      final updatedOrders = orders.map((order) {
        final store = storeMap[order.storeId];
        if (store != null) {
          return order.copyWith(store: store);
        }
        return order;
      }).toList();

      // Update UI if still mounted
      if (!_disposed && mounted) {
        _ordersNotifier.value = [
          ..._ordersNotifier.value.where((o) => !updatedOrders.any((u) => u.id == o.id)),
          ...updatedOrders,
        ];
      }
    } catch (e) {
      _log('Error fetching stores in background: $e');
    }
  }

  void _updateOrdersFromCache(List<OrderModel> cachedOrders, bool isRefresh) {
    if (isRefresh) {
      _ordersNotifier.value = cachedOrders;
    } else {
      _ordersNotifier.value = [..._ordersNotifier.value, ...cachedOrders];
    }

    if (isRefresh) {
      _setupAnimationsOptimized(cachedOrders.length);
      _startAnimationsOptimized();
    }
  }

  void _updatePaginationInfo(Map<String, dynamic> orderData) {
    _totalItems = orderData['totalItems'] ?? 0;
    _totalPages = orderData['totalPages'] ?? 1;
    _hasMoreData = _currentPage < _totalPages;
  }

  void _updateOrdersList(List<OrderModel> orders, bool isRefresh) {
    if (isRefresh) {
      _ordersNotifier.value = orders;
      _setupAnimationsOptimized(orders.length);
      _startAnimationsOptimized();
    } else {
      _ordersNotifier.value = [..._ordersNotifier.value, ...orders];
    }
  }

  Future<void> _loadMoreHistory() async {
    if (_isLoadingMoreNotifier.value || !_hasMoreData || !_isAuthenticatedNotifier.value) {
      return;
    }

    _isLoadingMoreNotifier.value = true;
    _currentPage++;
    await _fetchOrderHistoryOptimized(isRefresh: false);
  }

  void _handleAuthenticationError() {
    _isAuthenticatedNotifier.value = false;
    _customerData = null;
    _roleSpecificData = null;
    _errorNotifier.value = 'Session expired. Please login again.';
  }

  String? _getStatusFilter(int tabIndex) {
    const filters = [
      null, // All orders
      'pending,confirmed,preparing,ready_for_pickup,on_delivery', // In progress
      'delivered', // Completed
      'cancelled,rejected', // Cancelled
    ];
    return tabIndex < filters.length ? filters[tabIndex] : null;
  }

  // Optimized Animation Setup
  void _setupAnimationsOptimized(int totalCards) {
    // Dispose existing controllers
    for (var controller in _cardControllers) {
      controller.dispose();
    }

    // Limit animations for performance
    final animatedCards = totalCards > 20 ? 20 : totalCards;

    _cardControllers = List.generate(
      animatedCards,
          (index) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 300 + (index * 50)),
      ),
    );

    _cardAnimations = _cardControllers.map((controller) {
      return Tween<Offset>(
        begin: const Offset(0.3, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeOut,
      ));
    }).toList();
  }

  void _startAnimationsOptimized() {
    if (_cardControllers.isEmpty) return;

    // Stagger animations efficiently
    for (int i = 0; i < _cardControllers.length; i++) {
      Timer(Duration(milliseconds: i * 50), () {
        if (!_disposed && _cardControllers.length > i) {
          _cardControllers[i].forward();
        }
      });
    }
  }

  // Efficient Filtered Orders
  List<OrderModel> _getFilteredOrders(int tabIndex, List<OrderModel> orders) {
    switch (tabIndex) {
      case 0: return orders;
      case 1: return orders.where((order) => !order.orderStatus.isCompleted).toList();
      case 2: return orders.where((order) => order.orderStatus == OrderStatus.delivered).toList();
      case 3: return orders.where((order) =>
      order.orderStatus == OrderStatus.cancelled ||
          order.orderStatus == OrderStatus.rejected
      ).toList();
      default: return orders;
    }
  }

  void _onItemTapped(int index) {
    _selectedIndexNotifier.value = index;
    if (index == 0) {
      Navigator.pushReplacementNamed(context, HomePage.route);
    }
  }

  @override
  void dispose() {
    _disposed = true;

    // Dispose controllers
    _tabController.dispose();
    _scrollController.dispose();
    for (var controller in _cardControllers) {
      controller.dispose();
    }

    // Dispose ValueNotifiers
    _selectedIndexNotifier.dispose();
    _isLoadingNotifier.dispose();
    _isLoadingMoreNotifier.dispose();
    _errorNotifier.dispose();
    _ordersNotifier.dispose();
    _isAuthenticatedNotifier.dispose();

    // Cancel timers
    _refreshDebounce?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return ValueListenableBuilder<bool>(
      valueListenable: _isLoadingNotifier,
      builder: (context, isLoading, _) {
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
            appBar: _buildAppBar(),
            body: isLoading
                ? _buildLoadingState()
                : _buildMainContent(),
            bottomNavigationBar: ValueListenableBuilder<int>(
              valueListenable: _selectedIndexNotifier,
              builder: (context, selectedIndex, _) {
                return CustomBottomNavigation(
                  selectedIndex: selectedIndex,
                  onItemTapped: _onItemTapped,
                );
              },
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
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
      bottom: _buildTabBar(),
    );
  }

  PreferredSizeWidget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      isScrollable: true,
      labelColor: GlobalStyle.primaryColor,
      unselectedLabelColor: Colors.grey[600],
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      indicatorColor: GlobalStyle.primaryColor,
      indicatorWeight: 3,
      tabs: [
        _buildTab('Semua', 0),
        _buildTab('Diproses', 1),
        _buildTab('Selesai', 2),
        _buildTab('Dibatalkan', 3),
      ],
    );
  }

  Widget _buildTab(String title, int index) {
    return ValueListenableBuilder<List<OrderModel>>(
      valueListenable: _ordersNotifier,
      builder: (context, orders, _) {
        final count = index == 0 ? orders.length : _getFilteredOrders(index, orders).length;

        return Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title),
              if (count > 0 && index == 0)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: GlobalStyle.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 11,
                      color: GlobalStyle.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMainContent() {
    return ValueListenableBuilder<String?>(
      valueListenable: _errorNotifier,
      builder: (context, error, _) {
        if (error != null) {
          return _buildErrorState();
        }

        return RefreshIndicator(
          onRefresh: () => _isAuthenticatedNotifier.value
              ? _fetchOrderHistoryOptimized(isRefresh: true)
              : _authenticateAndLoadData(),
          color: GlobalStyle.primaryColor,
          child: _buildTabBarView(),
        );
      },
    );
  }

  Widget _buildTabBarView() {
    return ValueListenableBuilder<List<OrderModel>>(
      valueListenable: _ordersNotifier,
      builder: (context, orders, _) {
        return TabBarView(
          controller: _tabController,
          children: List.generate(4, (tabIndex) {
            final filteredOrders = _getFilteredOrders(tabIndex, orders);

            if (filteredOrders.isEmpty) {
              return _buildEmptyState(_getEmptyMessage(tabIndex));
            }

            return _buildOrdersList(filteredOrders);
          }),
        );
      },
    );
  }

  Widget _buildOrdersList(List<OrderModel> filteredOrders) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isLoadingMoreNotifier,
      builder: (context, isLoadingMore, _) {
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: filteredOrders.length + (isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index < filteredOrders.length) {
              return _buildOrderCardOptimized(filteredOrders[index], index);
            } else {
              return _buildLoadMoreIndicator();
            }
          },
        );
      },
    );
  }

  String _getEmptyMessage(int tabIndex) {
    const messages = [
      'Tidak ada pesanan',
      'Tidak ada pesanan yang sedang diproses',
      'Tidak ada pesanan yang selesai',
      'Tidak ada pesanan yang dibatalkan',
    ];
    return tabIndex < messages.length ? messages[tabIndex] : messages[0];
  }

  // Optimized Order Card
  Widget _buildOrderCardOptimized(OrderModel order, int index) {
    final formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(order.createdAt);
    final statusText = _getStatusText(order.orderStatus);
    final statusColor = _getStatusColor(order.orderStatus);

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
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _navigateToDetail(order),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildOrderImage(order),
                    const SizedBox(width: 16),
                    Expanded(child: _buildOrderInfo(order, formattedDate, statusText, statusColor)),
                  ],
                ),
                const Divider(height: 24),
                _buildOrderFooter(order),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderImage(OrderModel order) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: order.store?.imageUrl != null
          ? ImageService.displayImage(
        imageSource: order.store!.imageUrl!,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        placeholder: _buildImagePlaceholder(Icons.store),
        errorWidget: _buildImagePlaceholder(Icons.store),
      )
          : _buildImagePlaceholder(Icons.restaurant_menu),
    );
  }

  Widget _buildImagePlaceholder(IconData icon) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: Colors.grey, size: 30),
    );
  }

  Widget _buildOrderInfo(OrderModel order, String formattedDate, String statusText, Color statusColor) {
    return Column(
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
          style: TextStyle(fontSize: 13, color: Colors.grey[700]),
        ),
        const SizedBox(height: 6),
        Text(
          'Detail pesanan tersedia di halaman detail',
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
    );
  }

  Widget _buildOrderFooter(OrderModel order) {
    return Row(
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
          onPressed: () => _navigateToDetail(order),
          style: ElevatedButton.styleFrom(
            backgroundColor: GlobalStyle.primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Lihat Detail', style: TextStyle(fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }

  void _navigateToDetail(OrderModel order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HistoryDetailPage(order: order),
      ),
    ).then((_) => _fetchOrderHistoryOptimized(isRefresh: true));
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

  String _getStatusText(OrderStatus status) {
    const statusTexts = {
      OrderStatus.pending: 'Menunggu',
      OrderStatus.confirmed: 'Dikonfirmasi',
      OrderStatus.preparing: 'Diproses',
      OrderStatus.readyForPickup: 'Siap Diambil',
      OrderStatus.onDelivery: 'Diantar',
      OrderStatus.delivered: 'Selesai',
      OrderStatus.cancelled: 'Dibatalkan',
      OrderStatus.rejected: 'Ditolak',
    };
    return statusTexts[status] ?? 'Diproses';
  }

  Color _getStatusColor(OrderStatus status) {
    const statusColors = {
      OrderStatus.delivered: Colors.green,
      OrderStatus.cancelled: Colors.red,
      OrderStatus.rejected: Colors.red,
      OrderStatus.onDelivery: Colors.blue,
      OrderStatus.preparing: Colors.orange,
      OrderStatus.confirmed: Colors.indigo,
    };
    return statusColors[status] ?? GlobalStyle.primaryColor;
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset('assets/animations/empty.json', width: 200, height: 200),
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
              onPressed: () => Navigator.pushReplacementNamed(context, HomePage.route),
              icon: const Icon(Icons.shopping_bag),
              label: const Text('Mulai Belanja'),
              style: ElevatedButton.styleFrom(
                backgroundColor: GlobalStyle.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
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
          Lottie.asset('assets/animations/loading_animation.json', width: 150, height: 150),
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

  Widget _buildErrorState() {
    return ValueListenableBuilder<bool>(
      valueListenable: _isAuthenticatedNotifier,
      builder: (context, isAuthenticated, _) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset('assets/animations/caution.json', width: 150, height: 150),
              const SizedBox(height: 16),
              Text(
                !isAuthenticated ? 'Session Expired' : 'Gagal Memuat Data',
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
                child: ValueListenableBuilder<String?>(
                  valueListenable: _errorNotifier,
                  builder: (context, errorMessage, _) {
                    return Text(
                      errorMessage ?? 'Terjadi kesalahan saat memuat data',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontFamily: GlobalStyle.fontFamily,
                      ),
                      textAlign: TextAlign.center,
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  if (!isAuthenticated) {
                    Navigator.pushReplacementNamed(context, HomePage.route);
                  } else {
                    _fetchOrderHistoryOptimized(isRefresh: true);
                  }
                },
                icon: Icon(!isAuthenticated ? Icons.home : Icons.refresh),
                label: Text(!isAuthenticated ? 'Kembali ke Home' : 'Coba Lagi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlobalStyle.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        );
      },
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
            style: TextStyle(color: GlobalStyle.primaryColor, fontSize: 14),
          ),
        ],
      ),
    );
  }
}