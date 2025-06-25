import 'package:del_pick/Services/driver_request_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Views/Component/driver_bottom_navigation.dart';
import 'package:del_pick/Views/Driver/history_driver_detail.dart';
import 'package:del_pick/Services/driver_service.dart';
import 'package:del_pick/Services/order_service.dart';
import 'package:del_pick/Services/image_service.dart';
import 'package:del_pick/Services/auth_service.dart';

class HistoryDriverPage extends StatefulWidget {
  static const String route = '/Driver/HistoryDriver';

  const HistoryDriverPage({Key? key}) : super(key: key);

  @override
  State<HistoryDriverPage> createState() => _HistoryDriverPageState();
}

class _HistoryDriverPageState extends State<HistoryDriverPage> with TickerProviderStateMixin {
  int _currentIndex = 1; // History tab selected
  late TabController _tabController;

  // State management variables
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  List<Map<String, dynamic>> _orders = [];

  // Authentication state
  bool _isAuthenticated = false;
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _driverData;
  String? _driverId;

  // Pagination
  int _currentPage = 1;
  int _totalPages = 1;
  bool _isLoadingMore = false;

  // Animation controllers for cards
  late List<AnimationController> _cardControllers;
  late List<Animation<Offset>> _cardAnimations;

  // Tab categories based on driver workflow
  final List<String> _tabs = ['Semua', 'Menunggu', 'Disiapkan', 'Diantar', 'Selesai', 'Dibatalkan'];

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: _tabs.length, vsync: this);

    // Initialize with empty controllers and animations
    _cardControllers = [];
    _cardAnimations = [];

    // Initialize authentication and fetch orders
    _initializeAuthentication();
  }

  // Initialize authentication using getUserData and getRoleSpecificData
  Future<void> _initializeAuthentication() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      print('🔍 HistoryDriver: Initializing authentication...');

      // Check authentication status
      final isAuth = await AuthService.isAuthenticated();
      if (!isAuth) {
        throw Exception('User not authenticated');
      }

      // Get user data
      final userData = await AuthService.getUserData();
      if (userData == null) {
        throw Exception('No user data found');
      }

      // Get role-specific data
      final roleSpecificData = await AuthService.getRoleSpecificData();
      if (roleSpecificData == null) {
        throw Exception('No role-specific data found');
      }

      // Verify user role
      final userRole = await AuthService.getUserRole();
      if (userRole?.toLowerCase() != 'driver') {
        throw Exception('User is not a driver');
      }

      // Extract driver information
      _userData = userData;
      _driverData = roleSpecificData;

      // Get driver ID from various possible locations
      if (roleSpecificData['driver'] != null) {
        _driverId = roleSpecificData['driver']['id']?.toString();
      } else if (roleSpecificData['user'] != null) {
        _driverId = roleSpecificData['user']['id']?.toString();
      } else if (userData['id'] != null) {
        _driverId = userData['id']?.toString();
      }

      if (_driverId == null || _driverId!.isEmpty) {
        throw Exception('Driver ID not found');
      }

      setState(() {
        _isAuthenticated = true;
      });

      print('✅ HistoryDriver: Authentication successful, Driver ID: $_driverId');

      // Fetch driver orders
      await _fetchDriverOrders();

    } catch (e) {
      print('❌ HistoryDriver: Authentication error: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Authentication failed: $e';
        _isAuthenticated = false;
      });
    }
  }

  // Fetch driver orders using getDriverRequests
  Future<void> _fetchDriverOrders({bool isRefresh = false}) async {
    if (!_isAuthenticated) {
      print('❌ HistoryDriver: Cannot fetch orders - not authenticated');
      return;
    }

    if (isRefresh) {
      _currentPage = 1;
    }

    setState(() {
      if (isRefresh) {
        _isLoading = true;
      } else {
        _isLoadingMore = true;
      }
      _hasError = false;
    });

    try {
      print('🔄 HistoryDriver: Fetching orders - Page: $_currentPage');

      // Use DriverService.getDriverRequests instead of getDriverOrders
      final orderData = await DriverRequestService.getDriverRequests(
        page: _currentPage,
        limit: 20,
        sortBy: 'created_at',
        sortOrder: 'desc',
      );

      print('📦 HistoryDriver: Response received');

      // Extract data from API response
      final List<dynamic> ordersList = orderData['orders'] ?? orderData['data'] ?? [];
      _totalPages = orderData['totalPages'] ?? 1;

      // Process orders data
      List<Map<String, dynamic>> processedOrders = [];

      for (var orderJson in ordersList) {
        try {
          // Process the order data
          Map<String, dynamic> processedOrder = _processOrderData(orderJson);
          processedOrders.add(processedOrder);
        } catch (e) {
          print('Error processing order: $e');
          // Continue with next order if one fails to process
        }
      }

      setState(() {
        if (isRefresh) {
          _orders = processedOrders;
        } else {
          _orders.addAll(processedOrders);
        }
        _isLoading = false;
        _isLoadingMore = false;

        // Initialize animation controllers for new orders
        _initializeAnimations();
      });

      print('✅ HistoryDriver: Successfully processed ${processedOrders.length} orders');

    } catch (e) {
      print('❌ HistoryDriver: Error fetching orders: $e');
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _hasError = true;
        _errorMessage = 'Failed to load order history: $e';
      });
    }
  }

  // Process individual order data
  Map<String, dynamic> _processOrderData(Map<String, dynamic> orderJson) {
    // Extract customer information
    final customerData = orderJson['user'] ?? orderJson['customer'] ?? {};
    final storeData = orderJson['store'] ?? {};
    final driverData = orderJson['driver'] ?? {};
    final orderItems = orderJson['orderItems'] ?? orderJson['items'] ?? [];

    // Process customer avatar
    String customerAvatar = '';
    if (customerData['avatar'] != null && customerData['avatar'].toString().isNotEmpty) {
      customerAvatar = ImageService.getImageUrl(customerData['avatar']);
    }

    // Process store image
    String storeImage = '';
    if (storeData['imageUrl'] != null && storeData['imageUrl'].toString().isNotEmpty) {
      storeImage = ImageService.getImageUrl(storeData['imageUrl']);
    }

    // Process items images and calculate total items
    List<Map<String, dynamic>> processedItems = [];
    int totalItems = 0;
    if (orderItems is List) {
      processedItems = orderItems.map<Map<String, dynamic>>((item) {
        String imageUrl = '';
        final itemData = item['item'] ?? item;
        if (itemData['imageUrl'] != null && itemData['imageUrl'].toString().isNotEmpty) {
          imageUrl = ImageService.getImageUrl(itemData['imageUrl']);
        }

        final quantity = (item['quantity'] ?? 1);
        totalItems += (quantity is int) ? quantity : (quantity as num).toInt();

        return {
          'id': itemData['id']?.toString() ?? '',
          'name': itemData['name'] ?? 'Product',
          'quantity': quantity,
          'price': _parseDouble(item['price'] ?? itemData['price'] ?? 0),
          'imageUrl': imageUrl,
        };
      }).toList();
    }

    // Parse dates
    DateTime orderDate = DateTime.now();
    if (orderJson['created_at'] != null) {
      try {
        orderDate = DateTime.parse(orderJson['created_at']);
      } catch (e) {
        print('Error parsing date: $e');
      }
    }

    // Calculate driver earnings for delivered orders
    double driverEarnings = 0.0;
    final status = orderJson['status']?.toString() ?? 'pending';
    if (status.toLowerCase() == 'delivered') {
      const double baseDeliveryFee = 5000.0;
      const double commissionRate = 0.8; // 80% of delivery fee
      final deliveryFee = _parseDouble(orderJson['deliveryFee'] ?? orderJson['serviceCharge'] ?? 0);
      driverEarnings = baseDeliveryFee + (deliveryFee * commissionRate);
    }

    return {
      'id': orderJson['id']?.toString() ?? '',
      'status': status,
      'total': _parseDouble(orderJson['total'] ?? orderJson['totalAmount'] ?? 0),
      'deliveryFee': _parseDouble(orderJson['deliveryFee'] ?? orderJson['serviceCharge'] ?? 0),
      'driverEarnings': driverEarnings,
      'orderDate': orderDate,
      'customerName': customerData['name'] ?? 'Unknown Customer',
      'customerPhone': customerData['phone'] ?? customerData['phoneNumber'] ?? '',
      'customerAvatar': customerAvatar,
      'storeName': storeData['name'] ?? 'Unknown Store',
      'storeImage': storeImage,
      'deliveryAddress': orderJson['deliveryAddress'] ?? '',
      'totalItems': totalItems,
      'items': processedItems,
      'notes': orderJson['notes'] ?? '',
    };
  }

  // Helper function to parse double values
  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
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
    for (var controller in _cardControllers) {
      controller.forward();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (var controller in _cardControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // Get filtered orders based on tab index
  List<Map<String, dynamic>> getFilteredOrders(int tabIndex) {
    switch (tabIndex) {
      case 0: // Semua - All orders
        return _orders;
      case 1: // Menunggu - Waiting (pending, confirmed)
        return _orders.where((order) {
          final status = order['status']?.toString().toLowerCase() ?? '';
          return ['pending', 'confirmed'].contains(status);
        }).toList();
      case 2: // Disiapkan - Being prepared (preparing, ready_for_pickup)
        return _orders.where((order) {
          final status = order['status']?.toString().toLowerCase() ?? '';
          return ['preparing', 'ready_for_pickup'].contains(status);
        }).toList();
      case 3: // Diantar - On delivery (on_delivery)
        return _orders.where((order) {
          final status = order['status']?.toString().toLowerCase() ?? '';
          return status == 'on_delivery';
        }).toList();
      case 4: // Selesai - Completed (delivered)
        return _orders.where((order) {
          final status = order['status']?.toString().toLowerCase() ?? '';
          return status == 'delivered';
        }).toList();
      case 5: // Dibatalkan - Cancelled (cancelled, rejected)
        return _orders.where((order) {
          final status = order['status']?.toString().toLowerCase() ?? '';
          return ['cancelled', 'rejected'].contains(status);
        }).toList();
      default:
        return _orders;
    }
  }

  // Convert API status to display text
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

  // Get status color
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
      // Handle navigation to other pages if needed
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

  void _navigateToOrderDetail(Map<String, dynamic> order) {
    // Navigate to order detail page with orderId
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HistoryDriverDetailPage(
          orderId: order['id'],
          orderDetail: order,
        ),
      ),
    ).then((_) {
      // Refresh the list when returning from detail page
      _fetchDriverOrders(isRefresh: true);
    });
  }

  Widget _buildOrderCard(Map<String, dynamic> order, int index) {
    final orderDate = order['orderDate'] as DateTime;
    final formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(orderDate);
    final status = order['status']?.toString() ?? 'pending';
    final statusColor = _getStatusColor(status);
    final statusText = _getStatusText(status);
    final orderTotal = order['total'] ?? 0.0;
    final customerName = order['customerName'] ?? 'Customer';
    final customerAvatar = order['customerAvatar'] ?? '';
    final storeName = order['storeName'] ?? 'Store';
    final storeImage = order['storeImage'] ?? '';
    final totalItems = order['totalItems'] ?? 0;
    final driverEarnings = order['driverEarnings'] ?? 0.0;

    // Ensure index is within bounds of animations array
    final animationIndex = index < _cardAnimations.length ? index : 0;

    return SlideTransition(
      position: _cardAnimations[animationIndex],
      child: Card(
        elevation: 3,
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        color: Colors.white,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () => _navigateToOrderDetail(order),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with order ID and status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Order #${order['id']}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusChip(statusText, statusColor),
                  ],
                ),
                const SizedBox(height: 12),

                // Customer info
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: GlobalStyle.lightColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: customerAvatar.isNotEmpty
                          ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          customerAvatar,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.person,
                            color: GlobalStyle.primaryColor,
                            size: 28,
                          ),
                        ),
                      )
                          : Icon(
                        Icons.person,
                        color: GlobalStyle.primaryColor,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customerName,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formattedDate,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Store info
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: GlobalStyle.lightColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: storeImage.isNotEmpty
                          ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          storeImage,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.store,
                            color: GlobalStyle.primaryColor,
                            size: 28,
                          ),
                        ),
                      )
                          : Icon(
                        Icons.store,
                        color: GlobalStyle.primaryColor,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            storeName,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$totalItems item',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const Divider(height: 24),

                // Bottom section with total and earnings
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
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          GlobalStyle.formatRupiah(orderTotal),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: GlobalStyle.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    // Show earnings for delivered orders
                    if (driverEarnings > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Penghasilan',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green[700],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              GlobalStyle.formatRupiah(driverEarnings),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.green[700],
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ElevatedButton(
                        onPressed: () => _navigateToOrderDetail(order),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Lottie animation for empty state
          Lottie.asset(
            'assets/animations/empty.json',
            width: 200,
            height: 200,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 20),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Belum ada riwayat pesanan',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _fetchDriverOrders(isRefresh: true),
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
            onPressed: () {
              if (!_isAuthenticated) {
                _initializeAuthentication();
              } else {
                _fetchDriverOrders(isRefresh: true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: GlobalStyle.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              !_isAuthenticated ? 'Login Ulang' : 'Coba Lagi',
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

  // Load more orders when reaching the end of list
  Future<void> _loadMoreOrders() async {
    if (_isLoadingMore || _currentPage >= _totalPages || !_isAuthenticated) return;

    _currentPage++;
    await _fetchDriverOrders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Riwayat Pesanan',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        automaticallyImplyLeading: false,
        actions: [
          // Add a refresh button
          IconButton(
            icon: Icon(Icons.refresh, color: GlobalStyle.primaryColor),
            onPressed: () => _fetchDriverOrders(isRefresh: true),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: GlobalStyle.primaryColor,
          unselectedLabelColor: Colors.grey[600],
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
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
            return _buildEmptyState('Tidak ada pesanan ${_tabs[tabIndex].toLowerCase()}');
          }

          return RefreshIndicator(
            onRefresh: () => _fetchDriverOrders(isRefresh: true),
            color: GlobalStyle.primaryColor,
            child: NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification scrollInfo) {
                if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
                  _loadMoreOrders();
                }
                return false;
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredOrders.length + (_isLoadingMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == filteredOrders.length) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  return _buildOrderCard(filteredOrders[index], index);
                },
              ),
            ),
          );
        }),
      ),
      bottomNavigationBar: DriverBottomNavigation(
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}