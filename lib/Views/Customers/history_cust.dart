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
import 'package:del_pick/Models/driver.dart'; // ✅ Tambahkan untuk DriverModel

// Import Services
import 'package:del_pick/Services/order_service.dart';
import 'package:del_pick/Services/store_service.dart';
import 'package:del_pick/Services/image_service.dart';
import 'package:del_pick/Services/auth_service.dart';

// Import Components and Screens
import '../../Models/user.dart';
import '../Component/cust_bottom_navigation.dart';
import 'package:del_pick/Common/global_style.dart';
import 'home_cust.dart';
import 'history_detail.dart';

// Ultra-Optimized Cache System for History
class _HistoryCacheManager {
  static final Map<String, List<OrderModel>> _ordersCache = {};
  static final Map<int, StoreModel> _storeCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 1);
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

  static List<OrderModel>? getCachedOrders(String key,
      {bool forceExpire = false}) {
    if (forceExpire) {
      // ✅ Force expire cache jika diminta
      _ordersCache.remove(key);
      _cacheTimestamps.remove('orders_$key');
      return null;
    }

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

  static void clearAllCache() {
    _ordersCache.clear();
    _storeCache.clear();
    _cacheTimestamps.clear();
  }

  static void clearExpiredCache() {
    final now = DateTime.now();
    final expiredKeys = _cacheTimestamps.entries
        .where((entry) =>
            now.difference(entry.value) >=
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
  // ✅ Method untuk memproses data order mentah dari API
  static Map<String, dynamic> processOrderDataInBackground(
      List<dynamic> rawOrders) {
    final orders = <OrderModel>[];
    final storeIds = <int>{};

    for (final orderData in rawOrders) {
      try {
        if (orderData is Map<String, dynamic>) {
          // ✅ Parse order menggunakan method fromJson yang sudah ada
          final order = OrderModel.fromJson(orderData);
          orders.add(order);

          // Collect unique store IDs for batch fetching
          storeIds.add(order.storeId);
        }
      } catch (e) {
        print('Error parsing order data: $e');
        // Skip invalid order data
        continue;
      }
    }

    return {
      'orders': orders,
      'storeIds': storeIds.toList(),
    };
  }

// Di dalam class _HistoryBackgroundProcessor, method batchFetchStoresInBackground
  static Future<List<StoreModel>> batchFetchStoresInBackground(
      List<int> storeIds) async {
    final stores = <StoreModel>[];

    // ✅ Buat placeholder UserModel untuk owner
    final placeholderOwner = UserModel(
      id: 0,
      name: 'Unknown Owner',
      email: 'unknown@store.com',
      phone: '',
      role: UserRole.store,
      avatar: null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    for (final storeId in storeIds) {
      try {
        // Cek cache terlebih dahulu
        final cachedStore = _HistoryCacheManager.getCachedStore(storeId);
        if (cachedStore != null) {
          stores.add(cachedStore);
          continue;
        }

        // ✅ Fetch dari API dengan error handling yang lebih baik
        final storeResponse =
            await StoreService.getStoreById(storeId.toString());

        if (storeResponse['success'] == true && storeResponse['data'] != null) {
          final store = StoreModel.fromJson(storeResponse['data']);
          stores.add(store);
          _HistoryCacheManager.cacheStore(storeId, store);
        } else {
          // ✅ Jika API gagal, buat store placeholder dengan struktur yang benar
          final placeholderStore = StoreModel(
            owner: placeholderOwner, // ✅ Gunakan placeholder owner
            storeId: storeId,
            name: 'Memuat toko...',
            description: '',
            address: '',
            phone: '',
            openTime: '08:00',
            closeTime: '22:00',
            imageUrl: null,
            latitude: 0.0,
            longitude: 0.0,
            rating: 0.0,
            totalProducts: 0,
            reviewCount: 0,
            status: StoreStatus.active,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          stores.add(placeholderStore);
        }
      } catch (e) {
        // ✅ Jika error, buat store fallback dengan struktur yang benar
        final fallbackStore = StoreModel(
          owner: placeholderOwner, // ✅ Gunakan placeholder owner
          storeId: storeId,
          name: 'Toko #$storeId',
          description: 'Informasi toko tidak tersedia',
          address: '',
          phone: '',
          openTime: '08:00',
          closeTime: '22:00',
          imageUrl: null,
          latitude: 0.0,
          longitude: 0.0,
          rating: 0.0,
          totalProducts: 0,
          reviewCount: 0,
          status: StoreStatus.active,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        stores.add(fallbackStore);
      }
    }

    return stores;
  }
}

class HistoryCustomer extends StatefulWidget {
  static const String route = "/Customers/HistoryCustomer";

  const HistoryCustomer({Key? key}) : super(key: key);

  @override
  State<HistoryCustomer> createState() => _HistoryCustomerState();
}

class _HistoryCustomerState extends State<HistoryCustomer>
    with
        TickerProviderStateMixin,
        AutomaticKeepAliveClientMixin,
        WidgetsBindingObserver {
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
  final ValueNotifier<Map<int, bool>> _storeLoadingNotifier = ValueNotifier({});

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
    WidgetsBinding.instance.addObserver(this);

    // ✅ TAMBAH: Delayed refresh untuk memastikan data terbaru
    Timer(const Duration(milliseconds: 500), () {
      if (mounted && _isAuthenticatedNotifier.value) {
        _fetchOrderHistoryOptimized(isRefresh: true, forceRefresh: true);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isAuthenticatedNotifier.value) {
      // ✅ Force refresh ketika app resumed
      _HistoryCacheManager.clearAllCache();
      _fetchOrderHistoryOptimized(isRefresh: true, forceRefresh: true);
    }
  }

  void _initializeControllers() {
    _tabController = TabController(
        length: 9, vsync: this); // ✅ 9 tab berdasarkan kombinasi status
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

  static List<Map<String, dynamic>>? _parseTrackingUpdates(dynamic value) {
    try {
      if (value == null) return [];

      // Jika sudah berupa List
      if (value is List) {
        return value.map((item) {
          if (item is Map<String, dynamic>) {
            return item;
          } else if (item is String) {
            try {
              final decoded = jsonDecode(item);
              if (decoded is Map<String, dynamic>) {
                return decoded;
              }
            } catch (e) {
              print('⚠️ Failed to parse tracking update item: $e');
            }
          }
          return <String, dynamic>{};
        }).toList();
      }

      // Jika berupa String, coba parse sebagai JSON
      if (value is String && value.isNotEmpty) {
        try {
          final decoded = jsonDecode(value);
          if (decoded is List) {
            return decoded.map((item) {
              if (item is Map<String, dynamic>) {
                return item;
              }
              return <String, dynamic>{};
            }).toList();
          } else if (decoded is Map<String, dynamic>) {
            return [decoded];
          }
        } catch (e) {
          print('⚠️ Failed to parse tracking_updates JSON: $e');
          // Jika JSON parsing gagal, return empty list
          return [];
        }
      }

      return [];
    } catch (e) {
      print('❌ Error parsing tracking updates: $e');
      return [];
    }
  }

  PreferredSizeWidget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      isScrollable: true,
      labelColor: GlobalStyle.primaryColor,
      unselectedLabelColor: Colors.grey[600],
      labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      unselectedLabelStyle: const TextStyle(fontSize: 12),
      indicatorColor: GlobalStyle.primaryColor,
      indicatorWeight: 3,
      tabs: [
        _buildTab('Semua', 0),
        _buildTab('Menunggu', 1),
        _buildTab('Proses Driver', 2),
        _buildTab('Proses Toko', 3),
        _buildTab('Dikonfirmasi', 4),
        _buildTab('Siap Diambil', 5),
        _buildTab('Diantar', 6),
        _buildTab('Selesai', 7),
        _buildTab('Batal/Tolak', 8),
      ],
    );
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
        // ✅ Force refresh pada tab change
        _fetchOrderHistoryOptimized(isRefresh: true, forceRefresh: true);
      }
    });
  }

  String _getStoreName(OrderModel order) {
    if (order.store != null) {
      // ✅ Jika store sudah ada, gunakan nama asli
      return order.store!.name;
    } else {
      // ✅ Jika store belum dimuat, cek apakah sedang loading
      final isLoading = _storeLoadingNotifier.value[order.storeId] ?? false;
      if (isLoading) {
        return 'Memuat toko...';
      } else {
        return 'Toko #${order.storeId}';
      }
    }
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
  Future<void> _fetchOrderHistoryOptimized(
      {bool isRefresh = false, bool forceRefresh = false}) async {
    try {
      _log(
          '🔄 Fetching order history (page $_currentPage, force: $forceRefresh)...');

      if (!_isAuthenticatedNotifier.value || _customerData == null) {
        _log('❌ Not authenticated, re-authenticating...');
        await _authenticateAndLoadData();
        return;
      }

      if (isRefresh || forceRefresh) {
        _currentPage = 1;
        _hasMoreData = true;
        _isLoadingNotifier.value = true;
        _errorNotifier.value = null;
        _ordersNotifier.value = [];

        if (forceRefresh) {
          _HistoryCacheManager.clearAllCache();
        }
      }

      // Check cache dengan force expire option
      final cacheKey = 'all_page_$_currentPage';
      final cachedOrders = _HistoryCacheManager.getCachedOrders(cacheKey,
          forceExpire: forceRefresh);

      if (cachedOrders != null && !forceRefresh) {
        _log('📦 Using cached orders: ${cachedOrders.length}');
        _updateOrdersFromCache(cachedOrders, isRefresh);
        return;
      }

      // ✅ PERBAIKAN: Gunakan method yang sudah ada dengan timestamp support
      Map<String, dynamic> orderData;

      if (forceRefresh) {
        // Gunakan forceRefreshOrdersByUser untuk force refresh
        orderData = await OrderService.forceRefreshOrdersByUser(
          page: _currentPage,
          limit: _pageSize,
          status: null,
          sortBy: 'created_at',
          sortOrder: 'desc',
        );
      } else {
        // Gunakan getOrdersByUserSmart untuk smart refresh
        orderData = await OrderService.getOrdersByUserSmart(
          page: _currentPage,
          limit: _pageSize,
          status: null,
          sortBy: 'created_at',
          sortOrder: 'desc',
          forceRefresh: false,
        );
      }

      _log('📥 Raw order data received: ${orderData.keys}');
      _log('📊 Orders count: ${(orderData['orders'] as List?)?.length ?? 0}');

      if (orderData['orders'] == null) {
        throw Exception('Invalid response: No orders data found');
      }

      // Background processing
      final processedData =
          _HistoryBackgroundProcessor.processOrderDataInBackground(
              orderData['orders'] ?? []);

      final orders = processedData['orders'] as List<OrderModel>;
      final storeIds = processedData['storeIds'] as List<int>;

      _log(
          '✅ Processed ${orders.length} orders, ${storeIds.length} unique stores');

      // Background fetch stores
      if (storeIds.isNotEmpty) {
        _fetchStoresInBackground(orders, storeIds);
      }

      // Update UI immediately
      _updatePaginationInfo(orderData);
      _updateOrdersList(orders, isRefresh);

      // Cache dengan key yang spesifik
      _HistoryCacheManager.cacheOrders(cacheKey, orders);

      _log('✅ Orders fetched successfully: ${orders.length}');
    } catch (e) {
      _log('❌ Error fetching order history: $e');
      _errorNotifier.value = 'Failed to load order history: ${e.toString()}';

      if (e.toString().contains('authentication') ||
          e.toString().contains('Access denied') ||
          e.toString().contains('token') ||
          e.toString().contains('401')) {
        _handleAuthenticationError();
      }
    } finally {
      _isLoadingNotifier.value = false;
      _isLoadingMoreNotifier.value = false;
    }
  }

  // Background Store Fetching
  Future<void> _fetchStoresInBackground(
      List<OrderModel> orders, List<int> storeIds) async {
    try {
      // ✅ Set loading state untuk setiap store
      final storeLoadingMap = <int, bool>{};
      for (int storeId in storeIds) {
        storeLoadingMap[storeId] = true;
      }
      _storeLoadingNotifier.value = storeLoadingMap;

      final stores =
          await _HistoryBackgroundProcessor.batchFetchStoresInBackground(
              storeIds);

      // ✅ Map stores to orders dengan validasi
      final storeMap = <int, StoreModel>{};
      for (var store in stores) {
        storeMap[store.storeId] = store;
      }

      // ✅ Update orders dengan store data
      final updatedOrders = orders.map((order) {
        final store = storeMap[order.storeId];
        if (store != null) {
          return order.copyWith(store: store);
        }
        return order;
      }).toList();

      // ✅ Update UI jika masih mounted
      if (!_disposed && mounted) {
        // Gabungkan orders lama dengan yang sudah diupdate
        final currentOrders = _ordersNotifier.value;
        final newOrdersList = <OrderModel>[];

        // Tambahkan orders yang sudah ada tapi belum diupdate
        for (var existingOrder in currentOrders) {
          final updatedOrder = updatedOrders.firstWhere(
            (order) => order.id == existingOrder.id,
            orElse: () => existingOrder,
          );
          newOrdersList.add(updatedOrder);
        }

        // Tambahkan orders baru yang belum ada
        for (var newOrder in updatedOrders) {
          if (!newOrdersList.any((order) => order.id == newOrder.id)) {
            newOrdersList.add(newOrder);
          }
        }

        _ordersNotifier.value = newOrdersList;
      }

      // ✅ Clear loading state
      _storeLoadingNotifier.value = {};
    } catch (e) {
      _log('Error fetching stores in background: $e');
      // ✅ Clear loading state pada error
      _storeLoadingNotifier.value = {};
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

    _log(
        '📊 Pagination updated: $_currentPage/$_totalPages ($_totalItems total)');
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
    if (_isLoadingMoreNotifier.value ||
        !_hasMoreData ||
        !_isAuthenticatedNotifier.value) {
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

  Color _getTabColor(int tabIndex) {
    const tabColors = [
      Colors.grey, // Semua
      Colors.orange, // Menunggu
      Colors.blue, // Diproses Driver (tukar)
      Colors.amber, // Diproses Toko (tukar)
      Colors.purple, // Disiapkan
      Colors.indigo, // Siap Diambil
      Colors.cyan, // Diantar
      Colors.green, // Selesai
      Colors.red, // Dibatalkan
    ];
    return tabIndex < tabColors.length
        ? tabColors[tabIndex]
        : GlobalStyle.primaryColor;
  }

//Filter berdasarkan alur bisnis yang benar
  List<OrderModel> _getFilteredOrders(int tabIndex, List<OrderModel> orders) {
    // ✅ TAMBAH: Sort berdasarkan created_at dan id untuk memastikan order terbaru di atas
    List<OrderModel> sortedOrders = List.from(orders);
    sortedOrders.sort((a, b) {
      // Prioritas 1: Sort by created_at (terbaru dulu)
      int dateComparison = b.createdAt.compareTo(a.createdAt);
      if (dateComparison != 0) return dateComparison;

      // Prioritas 2: Jika tanggal sama, sort by id (terbesar dulu)
      return b.id.compareTo(a.id);
    });

    switch (tabIndex) {
      case 0: // Semua
        return sortedOrders;

      case 1: // Menunggu - pending + pending
        return sortedOrders
            .where((order) =>
                order.orderStatus == OrderStatus.pending &&
                order.deliveryStatus == DeliveryStatus.pending)
            .toList();

      case 2: // Diproses Driver
        return sortedOrders
            .where((order) =>
                order.driverId != null &&
                (order.deliveryStatus == DeliveryStatus.pending ||
                    order.deliveryStatus == DeliveryStatus.pickedUp) &&
                order.orderStatus != OrderStatus.delivered &&
                order.orderStatus != OrderStatus.cancelled &&
                order.orderStatus != OrderStatus.rejected)
            .toList();

      case 3: // Diproses Toko
        return sortedOrders
            .where((order) => order.orderStatus == OrderStatus.preparing)
            .toList();

      case 4: // Dikonfirmasi
        return sortedOrders
            .where((order) => order.orderStatus == OrderStatus.confirmed)
            .toList();

      case 5: // Siap Diambil
        return sortedOrders
            .where((order) => order.orderStatus == OrderStatus.readyForPickup)
            .toList();

      case 6: // Diantar
        return sortedOrders
            .where((order) =>
                order.orderStatus == OrderStatus.onDelivery &&
                order.deliveryStatus == DeliveryStatus.onWay)
            .toList();

      case 7: // Selesai
        return sortedOrders
            .where((order) =>
                order.orderStatus == OrderStatus.delivered &&
                order.deliveryStatus == DeliveryStatus.delivered)
            .toList();

      case 8: // Dibatalkan/Ditolak
        return sortedOrders
            .where((order) =>
                order.orderStatus == OrderStatus.cancelled ||
                order.orderStatus == OrderStatus.rejected ||
                order.deliveryStatus == DeliveryStatus.rejected)
            .toList();

      default:
        return sortedOrders;
    }
  }

  void _onItemTapped(int index) {
    _selectedIndexNotifier.value = index;
    if (index == 0) {
      Navigator.pushReplacementNamed(context, HomePage.route);
    }
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

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
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
    _storeLoadingNotifier.dispose();

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
            body: isLoading ? _buildLoadingState() : _buildMainContent(),
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
          child: Icon(Icons.arrow_back_ios_new,
              color: GlobalStyle.primaryColor, size: 18),
        ),
        onPressed: () {
          Navigator.pushNamedAndRemoveUntil(
            context,
            HomePage.route,
            (route) => false,
          );
        },
      ),
      actions: [
        // ✅ TAMBAH: Manual refresh button
        IconButton(
          icon: Icon(Icons.refresh, color: GlobalStyle.primaryColor),
          onPressed: () {
            _fetchOrderHistoryOptimized(isRefresh: true, forceRefresh: true);
          },
          tooltip: 'Refresh Data',
        ),
      ],
      bottom: _buildTabBar(),
    );
  }

  Widget _buildTab(String title, int index) {
    return ValueListenableBuilder<List<OrderModel>>(
      valueListenable: _ordersNotifier,
      builder: (context, orders, _) {
        final filteredOrders = _getFilteredOrders(index, orders);
        final count = filteredOrders.length;

        return Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getTabColor(index).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 10,
                      color: _getTabColor(index),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ]
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
              ? _fetchOrderHistoryOptimized(
                  isRefresh: true, forceRefresh: true) // ✅ Force refresh
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
          children: List.generate(9, (tabIndex) {
            // ✅ 9 tab sekarang
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
      'Tidak ada riwayat pesanan',
      'Tidak ada pesanan yang menunggu konfirmasi',
      'Tidak ada pesanan yang diproses driver',
      'Tidak ada pesanan yang diproses toko',
      'Tidak ada pesanan yang dikonfirmasi',
      'Tidak ada pesanan yang siap diambil',
      'Tidak ada pesanan yang sedang diantar',
      'Tidak ada pesanan yang selesai',
      'Tidak ada pesanan yang dibatalkan/ditolak',
    ];
    return tabIndex < messages.length ? messages[tabIndex] : messages[0];
  }

  // ✅ PERBAIKAN: Optimized Order Card dengan logika status yang benar
  Widget _buildOrderCardOptimized(OrderModel order, int index) {
    final formattedDate =
        DateFormat('dd MMM yyyy, HH:mm').format(order.createdAt);
    final detailedStatusText = _getDetailedStatusText(order);
    final detailedStatusColor = _getDetailedStatusColor(order);

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
                    Expanded(
                        child: _buildOrderInfo(order, formattedDate,
                            detailedStatusText, detailedStatusColor)),
                  ],
                ),
                const Divider(height: 24),
                // ✅ GUNAKAN: Footer yang sudah diperbaiki
                _buildOrderFooter(order), // atau _buildOrderFooterSimple(order)
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

  Widget _buildOrderInfo(OrderModel order, String formattedDate,
      String statusText, Color statusColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: ValueListenableBuilder<Map<int, bool>>(
                valueListenable: _storeLoadingNotifier,
                builder: (context, loadingMap, _) {
                  return Text(
                    _getStoreName(order),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: GlobalStyle.fontColor,
                      fontFamily: GlobalStyle.fontFamily,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  );
                },
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

        // Info delivery status jika ada driver
        if (order.driverId != null) ...[
          Row(
            children: [
              Icon(Icons.local_shipping, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                _getDeliveryStatusText(order.deliveryStatus),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],

        // Info items count
        Text(
          '${order.totalItems} item • ${order.items.isNotEmpty ? order.items.map((e) => e.name).join(", ") : "Detail di halaman detail"}',
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

  // Widget _buildOrderInfo(OrderModel order, String formattedDate,
  //     String statusText, Color statusColor) {
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       Row(
  //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //         children: [
  //           Expanded(
  //             child: ValueListenableBuilder<Map<int, bool>>(
  //               valueListenable: _storeLoadingNotifier,
  //               builder: (context, loadingMap, _) {
  //                 return Text(
  //                   _getStoreName(order),
  //                   style: TextStyle(
  //                     fontSize: 16,
  //                     fontWeight: FontWeight.bold,
  //                     color: GlobalStyle.fontColor,
  //                     fontFamily: GlobalStyle.fontFamily,
  //                   ),
  //                   maxLines: 1,
  //                   overflow: TextOverflow.ellipsis,
  //                 );
  //               },
  //             ),
  //           ),
  //           const SizedBox(width: 8),
  //           _buildStatusChip(statusText, statusColor),
  //         ],
  //       ),
  //       const SizedBox(height: 8),
  //       // Text(
  //       //   'Order #${order.id}',
  //       //   style: TextStyle(
  //       //     fontSize: 13,
  //       //     color: GlobalStyle.primaryColor,
  //       //     fontWeight: FontWeight.w500,
  //       //   ),
  //       // ),
  //       // const SizedBox(height: 4),
  //       Text(
  //         formattedDate,
  //         style: TextStyle(fontSize: 13, color: Colors.grey[700]),
  //       ),
  //       const SizedBox(height: 6),
  //       // ✅ Tampilkan info delivery status jika relevan
  //       if (order.driverId != null) ...[
  //         Row(
  //           children: [
  //             Icon(Icons.local_shipping, size: 14, color: Colors.grey[600]),
  //             const SizedBox(width: 4),
  //             Text(
  //               _getDeliveryStatusText(order.deliveryStatus),
  //               style: TextStyle(
  //                 fontSize: 12,
  //                 color: Colors.grey[600],
  //                 fontStyle: FontStyle.italic,
  //               ),
  //             ),
  //           ],
  //         ),
  //         const SizedBox(height: 4),
  //       ],
  //       Text(
  //         'Detail pesanan tersedia di halaman detail',
  //         style: TextStyle(
  //           fontSize: 14,
  //           color: Colors.grey[800],
  //           fontWeight: FontWeight.w500,
  //           fontFamily: GlobalStyle.fontFamily,
  //         ),
  //         maxLines: 2,
  //         overflow: TextOverflow.ellipsis,
  //       ),
  //     ],
  //   );
  // }

  String _getDeliveryStatusText(DeliveryStatus deliveryStatus) {
    switch (deliveryStatus) {
      case DeliveryStatus.pending:
        return 'Menunggu pickup';
      case DeliveryStatus.pickedUp:
        return 'Sudah diambil driver';
      case DeliveryStatus.onWay:
        return 'Dalam perjalanan';
      case DeliveryStatus.delivered:
        return 'Sudah diterima';
      case DeliveryStatus.rejected:
        return 'Delivery ditolak';
      default:
        return 'Status tidak diketahui';
    }
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
            // ✅ GUNAKAN: Method dari OrderModel untuk grand total
            Text(
              order.formatGrandTotal(), // ✅ Bukan order.formatTotalAmount()
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Lihat Detail',
              style: TextStyle(fontWeight: FontWeight.w500)),
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
    ).then((_) {
      // ✅ Force refresh setelah kembali dari detail
      _fetchOrderHistoryOptimized(isRefresh: true, forceRefresh: true);
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

  // ✅ PERBAIKAN: Method untuk status text berdasarkan alur bisnis yang benar
  String _getDetailedStatusText(OrderModel order) {
    // Prioritas: cek status cancelled/rejected dulu
    if (order.orderStatus == OrderStatus.cancelled) {
      return 'Dibatalkan';
    }
    if (order.orderStatus == OrderStatus.rejected) {
      return 'Ditolak Toko';
    }
    if (order.deliveryStatus == DeliveryStatus.rejected) {
      return 'Ditolak Driver';
    }

    // Status normal berdasarkan kombinasi order_status dan delivery_status
    switch (order.orderStatus) {
      case OrderStatus.pending:
        if (order.driverId != null) {
          return 'Menunggu Driver';
        }
        return 'Menunggu Konfirmasi';

      case OrderStatus.confirmed:
        return 'Dikonfirmasi Toko';

      case OrderStatus.preparing:
        if (order.deliveryStatus == DeliveryStatus.pickedUp) {
          return 'Disiapkan (Driver Standby)';
        }
        return 'Sedang Disiapkan';

      case OrderStatus.readyForPickup:
        if (order.deliveryStatus == DeliveryStatus.pickedUp) {
          return 'Sudah Diambil Driver';
        }
        return 'Siap Diambil';

      case OrderStatus.onDelivery:
        return 'Sedang Diantar';

      case OrderStatus.delivered:
        return 'Selesai';

      default:
        return 'Diproses';
    }
  }
  // String _getDetailedStatusText(OrderModel order) {
  //   // Kombinasi order_status dan delivery_status berdasarkan alur bisnis
  //   if (order.orderStatus == OrderStatus.pending &&
  //       order.deliveryStatus == DeliveryStatus.pending) {
  //     return 'Menunggu Konfirmasi';
  //   } else if (order.orderStatus == OrderStatus.preparing &&
  //       order.deliveryStatus == DeliveryStatus.pending) {
  //     return 'Diproses Toko';
  //   } else if (order.orderStatus == OrderStatus.pending &&
  //       order.deliveryStatus == DeliveryStatus.pickedUp) {
  //     return 'Diproses Driver';
  //   } else if (order.orderStatus == OrderStatus.preparing &&
  //       order.deliveryStatus == DeliveryStatus.pickedUp) {
  //     return 'Disiapkan';
  //   } else if (order.orderStatus == OrderStatus.readyForPickup &&
  //       order.deliveryStatus == DeliveryStatus.pickedUp) {
  //     return 'Siap Diambil';
  //   } else if (order.orderStatus == OrderStatus.onDelivery &&
  //       order.deliveryStatus == DeliveryStatus.onWay) {
  //     return 'Sedang Diantar';
  //   } else if (order.orderStatus == OrderStatus.delivered &&
  //       order.deliveryStatus == DeliveryStatus.delivered) {
  //     return 'Selesai';
  //   } else if (order.orderStatus == OrderStatus.cancelled) {
  //     return 'Dibatalkan';
  //   } else if (order.orderStatus == OrderStatus.rejected) {
  //     return 'Ditolak';
  //   } else if (order.deliveryStatus == DeliveryStatus.rejected) {
  //     return 'Delivery Ditolak';
  //   } else {
  //     return 'Diproses'; // Fallback
  //   }
  // }

  // ✅ PERBAIKAN: Method untuk status color berdasarkan alur bisnis yang benar
  Color _getDetailedStatusColor(OrderModel order) {
    if (order.orderStatus == OrderStatus.pending &&
        order.deliveryStatus == DeliveryStatus.pending) {
      return Colors.orange; // Menunggu
    } else if (order.orderStatus == OrderStatus.preparing &&
        order.deliveryStatus == DeliveryStatus.pending) {
      return Colors.amber; // Diproses Toko
    } else if (order.orderStatus == OrderStatus.pending &&
        order.deliveryStatus == DeliveryStatus.pickedUp) {
      return Colors.blue; // Diproses Driver
    } else if (order.orderStatus == OrderStatus.preparing &&
        order.deliveryStatus == DeliveryStatus.pickedUp) {
      return Colors.purple; // Disiapkan
    } else if (order.orderStatus == OrderStatus.readyForPickup &&
        order.deliveryStatus == DeliveryStatus.pickedUp) {
      return Colors.indigo; // Siap Diambil
    } else if (order.orderStatus == OrderStatus.onDelivery &&
        order.deliveryStatus == DeliveryStatus.onWay) {
      return Colors.cyan; // Sedang Diantar
    } else if (order.orderStatus == OrderStatus.delivered &&
        order.deliveryStatus == DeliveryStatus.delivered) {
      return Colors.green; // Selesai
    } else if (order.orderStatus == OrderStatus.cancelled ||
        order.orderStatus == OrderStatus.rejected ||
        order.deliveryStatus == DeliveryStatus.rejected) {
      return Colors.red; // Dibatalkan/Ditolak
    } else {
      return GlobalStyle.primaryColor; // Fallback
    }
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset('assets/animations/empty.json',
                width: 200, height: 200),
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
              onPressed: () =>
                  Navigator.pushReplacementNamed(context, HomePage.route),
              icon: const Icon(Icons.shopping_bag),
              label: const Text('Mulai Belanja'),
              style: ElevatedButton.styleFrom(
                backgroundColor: GlobalStyle.primaryColor,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
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
          Lottie.asset('assets/animations/loading_animation.json',
              width: 150, height: 150),
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
              Lottie.asset('assets/animations/caution.json',
                  width: 150, height: 150),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
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
              valueColor:
                  AlwaysStoppedAnimation<Color>(GlobalStyle.primaryColor),
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
