import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:del_pick/Models/item_model.dart';
import 'package:del_pick/Models/store.dart';
import 'package:del_pick/Models/tracking.dart';
import 'package:del_pick/Models/order.dart';
import 'package:del_pick/Models/order_enum.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Views/Component/bottom_navigation.dart';
import 'package:del_pick/Views/Store/home_store.dart';
import 'package:del_pick/Views/Store/historystore_detail.dart';
import 'package:del_pick/Services/order_service.dart';
import 'package:del_pick/Services/store_service.dart';
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
  List<Order> _orders = [];

  // Animation controllers for cards
  late List<AnimationController> _cardControllers;
  late List<Animation<Offset>> _cardAnimations;

  // Tab categories
  final List<String> _tabs = ['Semua', 'Diproses', 'Selesai', 'Dibatalkan'];

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
  Future<void> _fetchOrderHistory() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // Use OrderService.getOrdersByStore() from the updated services
      final orderData = await OrderService.getOrdersByStore();

      // Adapt to the structure returned by the updated API
      final List<dynamic> ordersList = orderData['orders'] ?? [];

      // Convert raw order data to Order objects
      List<Order> orders = [];

      for (var orderJson in ordersList) {
        try {
          // Process images in order data using ImageService if needed
          if (orderJson['store'] != null && orderJson['store']['image'] != null) {
            orderJson['store']['image'] =
                ImageService.getImageUrl(orderJson['store']['image']);
          }

          // Process customer avatar if present
          if (orderJson['customer'] != null && orderJson['customer']['avatar'] != null) {
            orderJson['customer']['avatar'] =
                ImageService.getImageUrl(orderJson['customer']['avatar']);
          }

          // Process items images if present
          if (orderJson['items'] != null && orderJson['items'] is List) {
            for (var item in orderJson['items']) {
              if (item['imageUrl'] != null) {
                item['imageUrl'] = ImageService.getImageUrl(item['imageUrl']);
              }
            }
          }

          Order order = Order.fromJson(orderJson);
          orders.add(order);
        } catch (e) {
          print('Error parsing order: $e');
          // Continue with next order if one fails to parse
        }
      }

      // Sort orders by date (newest first)
      orders.sort((a, b) => b.orderDate.compareTo(a.orderDate));

      setState(() {
        _orders = orders;
        _isLoading = false;

        // Initialize animation controllers for each order card
        _cardControllers = List.generate(
          orders.length,
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
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Failed to load order history: $e';
      });
      print('Error in _fetchOrderHistory: $e');
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
  List<Order> getFilteredOrders(int tabIndex) {
    switch (tabIndex) {
      case 0: // All orders
        return _orders;
      case 1: // In progress
        return _orders.where((order) =>
        order.status != OrderStatus.completed &&
            order.status != OrderStatus.cancelled &&
            order.status != OrderStatus.delivered
        ).toList();
      case 2: // Completed
        return _orders.where((order) =>
        order.status == OrderStatus.completed ||
            order.status == OrderStatus.delivered
        ).toList();
      case 3: // Cancelled
        return _orders.where((order) => order.status == OrderStatus.cancelled).toList();
      default:
        return _orders;
    }
  }

  Color getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.completed:
      case OrderStatus.delivered:
        return Colors.green;
      case OrderStatus.cancelled:
        return Colors.red;
      case OrderStatus.approved:
        return Colors.teal;
      case OrderStatus.preparing:
        return Colors.orange;
      case OrderStatus.on_delivery:
        return Colors.blue;
      default:
        return Colors.blue;
    }
  }

  String getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.completed:
      case OrderStatus.delivered:
        return 'Selesai';
      case OrderStatus.cancelled:
        return 'Di Batalkan';
      case OrderStatus.pending:
        return 'Menunggu';
      case OrderStatus.approved:
        return 'Disetujui';
      case OrderStatus.preparing:
        return 'Disiapkan';
      case OrderStatus.on_delivery:
        return 'Diantar';
      case OrderStatus.driverAssigned:
        return 'Driver Ditugaskan';
      case OrderStatus.driverHeadingToStore:
        return 'Di Ambil';
      case OrderStatus.driverAtStore:
        return 'Di Toko';
      case OrderStatus.driverHeadingToCustomer:
        return 'Di Antar';
      case OrderStatus.driverArrived:
        return 'Driver Tiba';
      default:
        return 'Diproses';
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

      // Call the processOrderByStore method from updated OrderService
      await OrderService.processOrderByStore(orderId, action);

      // Refresh the order list
      await _fetchOrderHistory();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            action == 'approve'
                ? 'Pesanan berhasil disetujui'
                : 'Pesanan ditolak',
          ),
          backgroundColor: action == 'approve' ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Failed to process order: $e';
      });

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memproses pesanan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String getOrderItemsText(Order order) {
    if (order.items.isEmpty) {
      return "Tidak ada item";
    } else if (order.items.length == 1) {
      return order.items[0].name;
    } else {
      final firstItem = order.items[0].name;
      final otherItemsCount = order.items.length - 1;
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

  void _navigateToOrderDetail(Order order) {
    // Navigate to order detail page with orderId using updated services
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HistoryStoreDetailPage(orderId: order.id),
      ),
    ).then((_) {
      // Refresh the list when returning from detail page
      _fetchOrderHistory();
    });
  }

  Widget _buildOrderCard(Order order, int index) {
    final formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(order.orderDate);
    final statusColor = getStatusColor(order.status);
    final statusText = getStatusText(order.status);
    final orderTotal = order.total;

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
          onTap: () {
            _navigateToOrderDetail(order);
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Customer image if available
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: GlobalStyle.lightColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
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
                                  'Order #${order.id.substring(0, min(order.id.length, 8))}',
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
                            formattedDate,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            getOrderItemsText(order),
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
                    if (order.status == OrderStatus.pending)
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: () => _processOrder(order.id, 'reject'),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            child: Text(
                              'Tolak',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => _processOrder(order.id, 'approve'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            child: Text('Terima'),
                          ),
                        ],
                      )
                    else
                      ElevatedButton(
                        onPressed: () {
                          _navigateToOrderDetail(order);
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

  // Helper function to get minimum of two integers
  int min(int a, int b) {
    return a < b ? a : b;
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
            onPressed: _fetchOrderHistory,
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
          Icon(Icons.error_outline, color: Colors.red, size: 64),
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
            onPressed: _fetchOrderHistory,
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
              onPressed: _fetchOrderHistory,
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
              onRefresh: _fetchOrderHistory,
              color: GlobalStyle.primaryColor,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredOrders.length,
                itemBuilder: (context, index) {
                  return _buildOrderCard(filteredOrders[index], index);
                },
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