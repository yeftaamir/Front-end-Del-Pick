import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Views/Component/bottom_navigation.dart';
import 'package:del_pick/Views/Store/home_store.dart';
import 'package:del_pick/Views/Store/historystore_detail.dart';
import 'package:del_pick/Services/order_service.dart';
import 'package:del_pick/Services/image_service.dart';

class HistoryStorePage extends StatefulWidget {
  static const String route = '/Store/HistoryStore';

  const HistoryStorePage({Key? key}) : super(key: key);

  @override
  State<HistoryStorePage> createState() => _HistoryStorePageState();
}

class _HistoryStorePageState extends State<HistoryStorePage> with TickerProviderStateMixin {
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

  // Animation controllers for cards
  late List<AnimationController> _cardControllers;
  late List<Animation<Offset>> _cardAnimations;

  // Updated tab categories based on new status mapping
  final List<String> _tabs = ['Semua', 'Menunggu', 'Disiapkan', 'Diantar', 'Selesai', 'Dibatalkan'];

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: _tabs.length, vsync: this);

    // Initialize with empty controllers and animations
    _cardControllers = [];
    _cardAnimations = [];

    // Fetch order data
    _fetchOrderHistory();
  }

  // Fetch order history from the API
  Future<void> _fetchOrderHistory({bool isRefresh = false}) async {
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
      // Use OrderService.getOrdersByStore() with pagination
      final orderData = await OrderService.getOrdersByStore(
        page: _currentPage,
        limit: 20,
        sortBy: 'created_at',
        sortOrder: 'desc',
      );

      // Extract data from API response
      final List<dynamic> ordersList = orderData['orders'] ?? [];
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
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _hasError = true;
        _errorMessage = 'Failed to load order history: $e';
      });
      print('Error in _fetchOrderHistory: $e');
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

    // Process items images
    List<Map<String, dynamic>> processedItems = [];
    if (orderItems is List) {
      processedItems = orderItems.map<Map<String, dynamic>>((item) {
        String imageUrl = '';
        final itemData = item['item'] ?? item;
        if (itemData['imageUrl'] != null && itemData['imageUrl'].toString().isNotEmpty) {
          imageUrl = ImageService.getImageUrl(itemData['imageUrl']);
        }

        return {
          'id': itemData['id']?.toString() ?? '',
          'name': itemData['name'] ?? 'Product',
          'quantity': item['quantity'] ?? 1,
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

    return {
      'id': orderJson['id']?.toString() ?? '',
      'status': orderJson['status']?.toString() ?? 'pending',
      'total': _parseDouble(orderJson['total'] ?? orderJson['totalAmount'] ?? 0),
      'serviceCharge': _parseDouble(orderJson['serviceCharge'] ?? orderJson['deliveryFee'] ?? 0),
      'orderDate': orderDate,
      'customerName': customerData['name'] ?? 'Unknown Customer',
      'customerPhone': customerData['phone'] ?? customerData['phoneNumber'] ?? '',
      'customerAvatar': customerAvatar,
      'deliveryAddress': orderJson['deliveryAddress'] ?? '',
      'items': processedItems,
      'driver': driverData,
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

  // Get filtered orders based on tab index with updated status mapping
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

  // Updated status text mapping
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

  // Updated status color mapping
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

  // Process the order - approve or reject
  Future<void> _processOrder(String orderId, String action) async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Call the processOrderByStore method from OrderService
      await OrderService.processOrderByStore(
        orderId: orderId,
        action: action,
      );

      // Refresh the order list
      await _fetchOrderHistory(isRefresh: true);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == 'accept' ? 'Pesanan berhasil disetujui' : 'Pesanan ditolak',
            ),
            backgroundColor: action == 'accept' ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memproses pesanan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Get order items summary text
  String getOrderItemsText(List<dynamic> items) {
    if (items.isEmpty) {
      return "Tidak ada item";
    } else if (items.length == 1) {
      return items[0]['name'] ?? 'Item';
    } else {
      final firstItem = items[0]['name'] ?? 'Item';
      final otherItemsCount = items.length - 1;
      return '$firstItem, +$otherItemsCount item lainnya';
    }
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
        builder: (context) => HistoryStoreDetailPage(orderId: order['id']),
      ),
    ).then((_) {
      // Refresh the list when returning from detail page
      _fetchOrderHistory(isRefresh: true);
    });
  }

  Widget _buildOrderCard(Map<String, dynamic> order, int index) {
    final orderDate = order['orderDate'] as DateTime;
    final formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(orderDate);
    final status = order['status']?.toString() ?? 'pending';
    final statusColor = _getStatusColor(status);
    final statusText = _getStatusText(status);
    final orderTotal = order['total'] ?? 0.0;
    final items = order['items'] as List<dynamic>;
    final customerName = order['customerName'] ?? 'Customer';
    final customerAvatar = order['customerAvatar'] ?? '';

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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Customer image
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: GlobalStyle.lightColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: customerAvatar.isNotEmpty
                          ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          customerAvatar,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
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
                              fontSize: 14,
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formattedDate,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            getOrderItemsText(items),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w500,
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
                    // Show approval buttons for pending orders
                    if (status.toLowerCase() == 'pending')
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: () => _processOrder(order['id'], 'reject'),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            child: const Text(
                              'Tolak',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => _processOrder(order['id'], 'accept'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            child: const Text('Terima'),
                          ),
                        ],
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
            onPressed: () => _fetchOrderHistory(isRefresh: true),
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

  // Load more orders when reaching the end of list
  Future<void> _loadMoreOrders() async {
    if (_isLoadingMore || _currentPage >= _totalPages) return;

    _currentPage++;
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
          title: const Text(
            'Riwayat Pesanan',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
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
              onRefresh: () => _fetchOrderHistory(isRefresh: true),
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
        bottomNavigationBar: BottomNavigationComponent(
          currentIndex: _currentIndex,
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}