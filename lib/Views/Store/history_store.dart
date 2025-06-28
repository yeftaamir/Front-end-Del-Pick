import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Views/Component/bottom_navigation.dart';
import 'package:del_pick/Views/Store/home_store.dart';
import 'package:del_pick/Views/Store/history_store_detail.dart';
import 'package:del_pick/Services/order_service.dart';
import 'package:del_pick/Services/auth_service.dart';
import 'package:del_pick/Services/driver_service.dart';
import 'package:del_pick/Services/customer_service.dart';
import 'package:del_pick/Services/image_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryStorePage extends StatefulWidget {
  static const String route = '/Store/HistoryStore';

  const HistoryStorePage({Key? key}) : super(key: key);

  @override
  State<HistoryStorePage> createState() => _HistoryStorePageState();
}

class _HistoryStorePageState extends State<HistoryStorePage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  //Timer untuk check updates
  Timer? _updateCheckTimer;
  String? _lastUpdateTime;

  int _currentIndex = 2; // History tab selected
  late TabController _tabController;

  // State management variables
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  List<Map<String, dynamic>> _orders = [];

  // Pagination
  int _currentPage = 1;
  int _totalPages = 1;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;

  // Animation controllers for cards
  late List<AnimationController> _cardControllers;
  late List<Animation<Offset>> _cardAnimations;

  // User data for authentication
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _storeData;

  //tab categories based on new status mapping
  final List<String> _tabs = [
    'Semua',
    'Menunggu',
    'Disiapkan',
    'Siap Diambil',
    'Diantar',
    'Selesai',
    'Dibatalkan'
  ];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _tabController = TabController(length: _tabs.length, vsync: this);
    _cardControllers = [];
    _cardAnimations = [];

    _initializeAndValidate();

    //Start checking for updates setiap 10 detik
    _startUpdateChecker();
  }

  /// Enhanced initialization dengan autentikasi yang benar
  Future<void> _initializeAndValidate() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      print('🏪 HistoryStore: Starting validation and initialization...');

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

      // ✅ FIXED: Get role-specific data
      final roleData = await AuthService.getRoleSpecificData();
      final userData = await AuthService.getUserData();

      if (roleData == null || userData == null) {
        throw Exception('Unable to retrieve user data');
      }

      setState(() {
        _userData = userData;
        _storeData = roleData['store'];
      });

      print('✅ HistoryStore: Authentication validated');
      print('   - Store ID: ${_storeData?['id']}');
      print('   - Store Name: ${_storeData?['name']}');

      // Fetch order history
      await _fetchOrderHistory();
    } catch (e) {
      print('❌ HistoryStore: Initialization error: $e');
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Simplified order history fetching - focus on displaying all orders
  Future<void> _fetchOrderHistory({bool isRefresh = false}) async {
    try {
      if (isRefresh) {
        setState(() {
          _currentPage = 1;
          _hasMoreData = true;
          _isLoading = true;
          _orders.clear();
        });
      } else if (!_hasMoreData) {
        return;
      }

      if (!isRefresh) {
        setState(() {
          _isLoadingMore = true;
        });
      }

      print(
          '📋 HistoryStore: Loading order history (page: $_currentPage, refresh: $isRefresh)...');

      final hasStoreAccess = await AuthService.hasRole('store');
      if (!hasStoreAccess) {
        throw Exception('Access denied: Store authentication required');
      }

      // ✅ PERBAIKAN: Gunakan timestamp yang fresh untuk memastikan data terbaru
      final response = await OrderService.getOrdersByStore(
        page: _currentPage,
        limit: isRefresh ? 50 : 20, // Ambil lebih banyak saat refresh
        sortBy:
            'updated_at', // ✅ UBAH: Sort by updated_at untuk pesanan yang baru diproses
        sortOrder: 'desc',
        timestamp: DateTime.now().millisecondsSinceEpoch, // Force fresh data
      );

      final ordersList =
          List<Map<String, dynamic>>.from(response['orders'] ?? []);
      final totalPages = response['totalPages'] ?? 1;
      final totalItems = response['totalItems'] ?? 0;

      print('📋 HistoryStore: Retrieved ${ordersList.length} orders');
      print('   - Total Items: $totalItems');

      // ✅ TAMBAHAN: Log status distribusi untuk debugging
      final statusCount = <String, int>{};
      for (var order in ordersList) {
        final status = order['order_status']?.toString() ?? 'unknown';
        statusCount[status] = (statusCount[status] ?? 0) + 1;
      }
      print('   - Status distribution: $statusCount');

      List<Map<String, dynamic>> processedOrders = [];
      for (var orderJson in ordersList) {
        try {
          Map<String, dynamic> processedOrder =
              _processOrderDataSimplified(orderJson);
          processedOrders.add(processedOrder);
        } catch (e) {
          print(
              '⚠️ HistoryStore: Error processing order ${orderJson['id']}: $e');
          // Add minimal data on error
          processedOrders.add({
            'id': orderJson['id']?.toString() ?? '',
            'order_status': orderJson['order_status'] ?? 'pending',
            'delivery_status': orderJson['delivery_status'] ?? 'pending',
            'total_amount': _parseDouble(orderJson['total_amount']) ?? 0.0,
            'delivery_fee': _parseDouble(orderJson['delivery_fee']) ?? 0.0,
            'created_at': DateTime.now(),
            'updated_at': DateTime.now(), // ✅ TAMBAHAN
            'customer': {
              'id': orderJson['customer_id']?.toString() ?? '',
              'name': 'Unknown Customer',
              'phone': '',
              'avatar': '',
            },
            'driver': null,
            'tracking_updates': [],
            'notes': '',
          });
        }
      }

      setState(() {
        if (isRefresh) {
          _orders = processedOrders;
        } else {
          _orders.addAll(processedOrders);
        }

        _totalPages = totalPages;
        _hasMoreData = _currentPage < totalPages;
        _currentPage++;

        _isLoading = false;
        _isLoadingMore = false;

        _initializeAnimations();
      });

      print('✅ HistoryStore: Order history loaded successfully');
      print('   - Total orders in state: ${_orders.length}');

      // ✅ TAMBAHAN: Update last refresh time
      final prefs = await SharedPreferences.getInstance();
      _lastUpdateTime = DateTime.now().toIso8601String();
      await prefs.setString('last_history_refresh', _lastUpdateTime!);
    } catch (e) {
      print('❌ HistoryStore: Error loading order history: $e');
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _hasError = true;
        _errorMessage = 'Failed to load order history: $e';
      });
    }
  }

  ///Minimal order data processing to ensure all orders are displayed
  Map<String, dynamic> _processOrderDataSimplified(
      Map<String, dynamic> orderJson) {
    try {
      print(
          '🔄 HistoryStore: Processing order ${orderJson['id']} (simplified)...');

      final orderId = orderJson['id']?.toString() ?? '';
      final customerId = orderJson['customer_id']?.toString();
      final driverId = orderJson['driver_id']?.toString();
      final orderStatus = orderJson['order_status'] ?? 'pending';
      final deliveryStatus = orderJson['delivery_status'] ?? 'pending';

      final totalAmount = _parseDouble(orderJson['total_amount']) ?? 0.0;
      final deliveryFee = _parseDouble(orderJson['delivery_fee']) ?? 0.0;

      // Parse dates safely
      DateTime orderDate = DateTime.now();
      DateTime updatedDate = DateTime.now();

      if (orderJson['created_at'] != null) {
        try {
          orderDate = DateTime.parse(orderJson['created_at']);
        } catch (e) {
          print('⚠️ Error parsing order date: $e');
        }
      }

      if (orderJson['updated_at'] != null) {
        try {
          updatedDate = DateTime.parse(orderJson['updated_at']);
        } catch (e) {
          print('⚠️ Error parsing updated date: $e');
          updatedDate = orderDate;
        }
      }

      // ✅ PERBAIKAN: Enhanced customer data processing
      Map<String, dynamic> customerData = {
        'id': customerId ?? '',
        'name': 'Customer #$customerId',
        'phone': '-',
        'avatar': '',
      };

      // ✅ TAMBAHAN: Process customer data jika ada
      if (orderJson['customer'] != null) {
        try {
          final customerInfo = orderJson['customer'];
          if (customerInfo is Map) {
            customerData['name'] =
                customerInfo['name'] ?? 'Customer #$customerId';
            customerData['phone'] = customerInfo['phone'] ?? '-';
            customerData['avatar'] = customerInfo['avatar'] ?? '';
          }
        } catch (e) {
          print('⚠️ Error processing customer data: $e');
        }
      }

      // ✅ PERBAIKAN: Enhanced driver data processing
      Map<String, dynamic>? driverData;
      if (driverId != null && driverId.isNotEmpty && driverId != 'null') {
        driverData = {
          'id': driverId,
          'name': 'Driver #$driverId',
          'phone': '-',
          'avatar': '',
          'status': 'active',
        };

        // ✅ TAMBAHAN: Process driver data jika ada
        if (orderJson['driver'] != null) {
          try {
            final driverInfo = orderJson['driver'];
            if (driverInfo is Map) {
              // Handle nested user data
              final userData = driverInfo['user'];
              if (userData is Map) {
                driverData['name'] = userData['name'] ?? 'Driver #$driverId';
                driverData['phone'] = userData['phone'] ?? '-';
                driverData['avatar'] = userData['avatar'] ?? '';
              } else {
                driverData['name'] = driverInfo['name'] ?? 'Driver #$driverId';
                driverData['phone'] = driverInfo['phone'] ?? '-';
                driverData['avatar'] = driverInfo['avatar'] ?? '';
              }
            }
          } catch (e) {
            print('⚠️ Error processing driver data: $e');
          }
        }
      }

      // ✅ PERBAIKAN: Process tracking updates dengan safe conversion
      List<Map<String, dynamic>> trackingUpdates = [];
      if (orderJson['tracking_updates'] != null) {
        try {
          final trackingData = orderJson['tracking_updates'];
          if (trackingData is String) {
            if (trackingData.isNotEmpty && trackingData != 'null') {
              final decoded = jsonDecode(trackingData);
              if (decoded is List) {
                trackingUpdates = List<Map<String, dynamic>>.from(decoded.map(
                    (item) =>
                        item is Map ? Map<String, dynamic>.from(item) : {}));
              }
            }
          } else if (trackingData is List) {
            trackingUpdates = List<Map<String, dynamic>>.from(trackingData.map(
                (item) => item is Map ? Map<String, dynamic>.from(item) : {}));
          }
        } catch (e) {
          print('⚠️ Error parsing tracking updates: $e');
          trackingUpdates = [];
        }
      }

      final processedOrder = {
        'id': orderId,
        'order_status': orderStatus,
        'delivery_status': deliveryStatus,
        'total_amount': totalAmount,
        'delivery_fee': deliveryFee,
        'estimated_pickup_time': orderJson['estimated_pickup_time'],
        'actual_pickup_time': orderJson['actual_pickup_time'],
        'estimated_delivery_time': orderJson['estimated_delivery_time'],
        'actual_delivery_time': orderJson['actual_delivery_time'],
        'created_at': orderDate,
        'updated_at': updatedDate,
        'customer': customerData,
        'driver': driverData,
        'tracking_updates': trackingUpdates,
        'notes': orderJson['notes'] ?? '',
      };

      return processedOrder;
    } catch (e) {
      print('❌ Error processing order data: $e');
      return {
        'id': orderJson['id']?.toString() ?? '',
        'order_status': orderJson['order_status'] ?? 'pending',
        'delivery_status': orderJson['delivery_status'] ?? 'pending',
        'total_amount': _parseDouble(orderJson['total_amount']) ?? 0.0,
        'delivery_fee': _parseDouble(orderJson['delivery_fee']) ?? 0.0,
        'created_at': DateTime.now(),
        'updated_at': DateTime.now(),
        'customer': {
          'id': orderJson['customer_id']?.toString() ?? '',
          'name': 'Unknown Customer',
          'phone': '',
          'avatar': '',
        },
        'driver': null,
        'tracking_updates': [],
        'notes': '',
      };
    }
  }

  /// Helper function to parse double values
  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  // Initialize animations for cards
  void _initializeAnimations() {
    // Clear existing controllers first
    for (var controller in _cardControllers) {
      controller.dispose();
    }

    if (_orders.isEmpty) return;

    // Initialize new controllers for each card
    _cardControllers = List.generate(
      _orders.length,
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

    // Start animations sequentially
    for (int i = 0; i < _cardControllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 100), () {
        if (mounted) _cardControllers[i].forward();
      });
    }
  }

  void _startUpdateChecker() {
    _updateCheckTimer =
        Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      try {
        final prefs = await SharedPreferences.getInstance();
        final lastUpdate = prefs.getString('last_order_update');

        if (lastUpdate != null && lastUpdate != _lastUpdateTime) {
          print(
              '🔄 HistoryStore: Detected update from HomeStore, refreshing...');
          _lastUpdateTime = lastUpdate;
          await _fetchOrderHistory(isRefresh: true);
        }
      } catch (e) {
        print('⚠️ HistoryStore: Error checking updates: $e');
      }
    });
  }

  //Handle app lifecycle untuk refresh saat kembali ke foreground
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      print('📱 HistoryStore: App resumed, checking for updates...');
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _fetchOrderHistory(isRefresh: true);
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updateCheckTimer?.cancel();
    _tabController.dispose();
    for (var controller in _cardControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // ✅ FIXED: Get filtered orders based on tab index dengan status mapping yang benar
  List<Map<String, dynamic>> getFilteredOrders(int tabIndex) {
    print('🔍 Filtering orders for tab $tabIndex (${_tabs[tabIndex]})');
    print('   - Total orders available: ${_orders.length}');

    List<Map<String, dynamic>> filteredResult;

    switch (tabIndex) {
      case 0: // Semua - All orders
        filteredResult = _orders;
        break;
      case 1: // Menunggu - Waiting (pending)
        filteredResult = _orders.where((order) {
          final status = order['order_status']?.toString().toLowerCase() ?? '';
          return status == 'pending';
        }).toList();
        break;
      case 2: // Disiapkan - Being prepared (preparing)
        filteredResult = _orders.where((order) {
          final status = order['order_status']?.toString().toLowerCase() ?? '';
          return status == 'preparing';
        }).toList();
        break;
      case 3: // Siap Diambil - Ready for pickup
        filteredResult = _orders.where((order) {
          final status = order['order_status']?.toString().toLowerCase() ?? '';
          return status == 'ready_for_pickup';
        }).toList();
        break;
      case 4: // Diantar - On delivery (on_delivery)
        filteredResult = _orders.where((order) {
          final status = order['order_status']?.toString().toLowerCase() ?? '';
          return status == 'on_delivery';
        }).toList();
        break;
      case 5: // Selesai - Completed (delivered)
        filteredResult = _orders.where((order) {
          final status = order['order_status']?.toString().toLowerCase() ?? '';
          return status == 'delivered';
        }).toList();
        break;
      case 6: // Dibatalkan - Cancelled (cancelled, rejected)
        filteredResult = _orders.where((order) {
          final status = order['order_status']?.toString().toLowerCase() ?? '';
          return ['cancelled', 'rejected'].contains(status);
        }).toList();
        break;
      default:
        filteredResult = _orders;
    }

    print('   - Filtered result: ${filteredResult.length} orders');
    print(
        '   - Filtered IDs: ${filteredResult.map((o) => '${o['id']}(${o['order_status']})').toList()}');

    return filteredResult;
  }

  // ✅ FIXED: Updated status text mapping sesuai backend
  String _getStatusText(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return 'Menunggu';
      case 'confirmed':
        return 'Dikonfirmasi';
      case 'preparing':
        return 'Disiapkan';
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
        return 'Diproses';
    }
  }

  // ✅ FIXED: Updated status color mapping
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

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
      if (index == 0) {
        Navigator.pushReplacementNamed(context, HomeStore.route);
      }
    });
  }

  Widget _buildStatusChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.3)),
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

  // ✅ FIXED: Navigate to order detail dengan order ID dan enhanced data
  void _navigateToOrderDetail(Map<String, dynamic> order) {
    print('🔍 HistoryStore: Navigating to order detail: ${order['id']}');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HistoryStoreDetailPage(
          orderId: order['id'],
        ),
      ),
    ).then((_) {
      // Refresh the list when returning from detail page
      _fetchOrderHistory(isRefresh: true);
    });
  }

  // ✅ ENHANCED: Enhanced order card dengan customer dan driver info
  Widget _buildOrderCard(Map<String, dynamic> order, int index) {
    final orderDate = order['created_at'] as DateTime;
    final formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(orderDate);
    final orderStatus = order['order_status']?.toString() ?? 'pending';
    final deliveryStatus = order['delivery_status']?.toString() ?? 'pending';
    final statusColor = _getStatusColor(orderStatus);
    final statusText = _getStatusText(orderStatus);
    final totalAmount = order['total_amount'] ?? 0.0;
    final deliveryFee = order['delivery_fee'] ?? 0.0;

    // Customer info
    final customer = order['customer'] ?? {};
    final customerName = customer['name'] ?? 'Unknown Customer';
    final customerPhone = customer['phone'] ?? '';
    final customerAvatar = customer['avatar'] ?? '';

    // Driver info (jika ada)
    final driver = order['driver'];
    final driverName = driver?['name'] ?? '';

    // Ensure index is within bounds of animations array
    final animationIndex = index < _cardAnimations.length ? index : 0;

    return SlideTransition(
      position: _cardAnimations[animationIndex],
      child: Card(
        elevation: 4,
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: Colors.white,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _navigateToOrderDetail(order),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section
                Row(
                  children: [
                    // Customer Avatar
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: GlobalStyle.lightColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: GlobalStyle.primaryColor.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: customerAvatar.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                customerAvatar,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Icon(
                                  Icons.person,
                                  color: GlobalStyle.primaryColor,
                                  size: 32,
                                ),
                              ),
                            )
                          : Icon(
                              Icons.person,
                              color: GlobalStyle.primaryColor,
                              size: 32,
                            ),
                    ),
                    const SizedBox(width: 16),

                    // Order Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Order #${order['id']}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
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
                            customerName,
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (customerPhone.isNotEmpty)
                            Text(
                              customerPhone,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            formattedDate,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Order Details Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.shade200,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total Pesanan',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                GlobalStyle.formatRupiah(totalAmount),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: GlobalStyle.primaryColor,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Biaya Antar',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                GlobalStyle.formatRupiah(deliveryFee),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Driver info (jika ada)
                      if (driver != null) ...[
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.delivery_dining,
                              color: GlobalStyle.primaryColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Driver: $driverName',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // View Detail Button
                Center(
                  child: Container(
                    width: double.infinity,
                    height: 45,
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
                        onTap: () => _navigateToOrderDetail(order),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.visibility,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Lihat Detail Pesanan',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Lottie animation for empty state
          Lottie.asset(
            'assets/animations/empty.json',
            width: 200,
            height: 200,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.inbox_outlined,
                size: 100,
                color: Colors.grey[400],
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
              fontFamily: GlobalStyle.fontFamily,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Belum ada riwayat pesanan',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontFamily: GlobalStyle.fontFamily,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _fetchOrderHistory(isRefresh: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: GlobalStyle.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  // Loading state widget
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: GlobalStyle.primaryColor),
          const SizedBox(height: 16),
          Text(
            'Memuat riwayat pesanan...',
            style: TextStyle(
              color: GlobalStyle.fontColor,
              fontSize: 16,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  // Error state widget
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 64),
          const SizedBox(height: 16),
          Text(
            'Gagal memuat riwayat pesanan',
            style: TextStyle(
              color: GlobalStyle.fontColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage,
              style: TextStyle(
                color: GlobalStyle.fontColor.withOpacity(0.7),
                fontSize: 14,
                fontFamily: GlobalStyle.fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => _initializeAndValidate(),
            style: ElevatedButton.styleFrom(
              backgroundColor: GlobalStyle.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              'Coba Lagi',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontFamily: GlobalStyle.fontFamily,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ FIXED: Load more orders dengan proper pagination
  Future<void> _loadMoreOrders() async {
    if (_isLoadingMore || !_hasMoreData) return;

    print('📄 HistoryStore: Loading more orders (page: $_currentPage)...');
    await _fetchOrderHistory();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pushNamedAndRemoveUntil(
          context,
          HomeStore.route,
          (route) => false,
        );
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          title: Text(
            'Riwayat Pesanan',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
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
                HomeStore.route,
                (route) => false,
              );
            },
          ),
          actions: [
            // Add a refresh button
            IconButton(
              icon: Icon(Icons.refresh, color: GlobalStyle.primaryColor),
              onPressed: () => _fetchOrderHistory(isRefresh: true),
            ),
            // ✅ NEW: Debug info button
            IconButton(
              icon: Icon(Icons.info_outline, color: Colors.grey[600]),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Debug Info'),
                    content: Text('Total Orders: ${_orders.length}\n'
                        'Page: $_currentPage\n'
                        'Has More: $_hasMoreData\n'
                        'Loading: $_isLoading\n'
                        'Error: $_hasError'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('OK'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: GlobalStyle.primaryColor,
            unselectedLabelColor: Colors.grey[600],
            labelStyle: TextStyle(
              fontWeight: FontWeight.w600,
              fontFamily: GlobalStyle.fontFamily,
            ),
            indicatorColor: GlobalStyle.primaryColor,
            indicatorWeight: 3,
            tabs: _tabs.map((String tab) => Tab(text: tab)).toList(),
          ),
        ),
        body: _isLoading
            ? _buildLoadingState()
            : _hasError
                ? _buildErrorState()
                : TabBarView(
                    controller: _tabController,
                    children: List.generate(_tabs.length, (tabIndex) {
                      final filteredOrders = getFilteredOrders(tabIndex);

                      if (filteredOrders.isEmpty) {
                        return _buildEmptyState(
                            'Tidak ada pesanan ${_tabs[tabIndex].toLowerCase()}');
                      }

                      return RefreshIndicator(
                        onRefresh: () => _fetchOrderHistory(isRefresh: true),
                        color: GlobalStyle.primaryColor,
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (ScrollNotification scrollInfo) {
                            if (scrollInfo.metrics.pixels >=
                                scrollInfo.metrics.maxScrollExtent - 200) {
                              _loadMoreOrders();
                            }
                            return false;
                          },
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredOrders.length +
                                (_isLoadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == filteredOrders.length) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: CircularProgressIndicator(
                                      color: GlobalStyle.primaryColor,
                                    ),
                                  ),
                                );
                              }
                              return _buildOrderCard(
                                  filteredOrders[index], index);
                            },
                          ),
                        ),
                      );
                    }),
                  ),
        bottomNavigationBar: BottomNavigationComponent(
          currentIndex: _currentIndex,
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}
