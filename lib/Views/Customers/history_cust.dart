import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../Models/order_enum.dart';
import '../Component/cust_bottom_navigation.dart';
import 'package:del_pick/Models/item_model.dart';
import 'package:del_pick/Models/store.dart';
import 'package:del_pick/Models/tracking.dart';
import 'package:del_pick/Models/order.dart';
import 'package:del_pick/Views/Customers/history_detail.dart';
import 'package:del_pick/Services/order_service.dart';
import 'package:del_pick/Services/image_service.dart';
import 'package:del_pick/Common/global_style.dart';
import 'home_cust.dart';

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

  // List for storing orders from API
  List<Order> orders = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 4, vsync: this);

    // Initialize with placeholders, will be updated when data is fetched
    _cardControllers = [];
    _cardAnimations = [];

    // Fetch orders on init
    _fetchOrders();
  }

  // Fetch orders from API
  Future<void> _fetchOrders() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Call the API service to get customer orders
      final orderData = await OrderService.getCustomerOrders();

      // Parse order data into Order objects
      List<Order> fetchedOrders = [];
      if (orderData != null && orderData['orders'] is List) {
        for (var orderJson in orderData['orders']) {
          try {
            // Use the Order.fromJson factory constructor directly
            final order = Order.fromJson(orderJson);
            fetchedOrders.add(order);
          } catch (e) {
            print('Error parsing order: $e');
            // Continue with next order if one fails to parse
          }
        }
      }

      // Setup animations after data is fetched
      _setupAnimations(fetchedOrders.length);

      setState(() {
        orders = fetchedOrders;
        _isLoading = false;
      });

      // Start animations
      Future.delayed(const Duration(milliseconds: 100), () {
        for (var controller in _cardControllers) {
          controller.forward();
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load orders: $e';
      });
      print('Error fetching orders: $e');
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
        return orders;
      case 1: // In progress
        return orders.where((order) =>
        !order.status.isCompleted
        ).toList();
      case 2: // Completed
        return orders.where((order) => order.status == OrderStatus.completed ||
            order.status == OrderStatus.delivered).toList();
      case 3: // Cancelled
        return orders.where((order) => order.status == OrderStatus.cancelled).toList();
      default:
        return orders;
    }
  }

  // Get status color based on order status
  Color getStatusColor(OrderStatus status) {
    if (status == OrderStatus.completed || status == OrderStatus.delivered) {
      return Colors.green;
    } else if (status == OrderStatus.cancelled) {
      return Colors.red;
    } else if (status == OrderStatus.on_delivery ||
        status == OrderStatus.driverHeadingToCustomer) {
      return Colors.blue;
    } else if (status == OrderStatus.preparing ||
        status == OrderStatus.driverAtStore) {
      return Colors.orange;
    } else {
      return Colors.blue.shade300; // Default for other statuses
    }
  }

  // Get human-readable status text
  String getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.completed:
        return 'Selesai';
      case OrderStatus.delivered:
        return 'Terkirim';
      case OrderStatus.cancelled:
        return 'Dibatalkan';
      case OrderStatus.pending:
        return 'Menunggu';
      case OrderStatus.approved:
        return 'Disetujui';
      case OrderStatus.preparing:
        return 'Diproses';
      case OrderStatus.on_delivery:
        return 'Diantar';
      case OrderStatus.driverAssigned:
        return 'Driver Ditugaskan';
      case OrderStatus.driverHeadingToStore:
        return 'Driver Menuju Toko';
      case OrderStatus.driverAtStore:
        return 'Driver Di Toko';
      case OrderStatus.driverHeadingToCustomer:
        return 'Driver Menuju Anda';
      case OrderStatus.driverArrived:
        return 'Driver Tiba';
      default:
        return 'Diproses';
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

  // Create a summary of items for display
  String getOrderItemsText(Order order) {
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

  Widget _buildOrderCard(Order order, int index) {
    final formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(order.orderDate);
    final statusColor = getStatusColor(order.status);
    final statusText = getStatusText(order.status);
    final itemsText = getOrderItemsText(order);

    return SlideTransition(
      position: index < _cardAnimations.length ? _cardAnimations[index] : const AlwaysStoppedAnimation(Offset.zero),
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
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => HistoryDetailPage(
                  order: order,
                ),
              ),
            ).then((_) => _fetchOrders()); // Refresh when returning from detail page
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Use ImageService to display the image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: order.items.isNotEmpty && order.items.first.imageUrl.isNotEmpty
                          ? ImageService.displayImage(
                        imageSource: order.items.first.imageUrl,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        placeholder: Container(
                          width: 60,
                          height: 60,
                          color: Colors.grey[200],
                          child: const Icon(Icons.restaurant_menu, color: Colors.grey),
                        ),
                      )
                          : Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey[200],
                        child: const Icon(Icons.restaurant_menu, color: Colors.grey),
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
                                  order.store.name,
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
                            order.code != null && order.code!.isNotEmpty
                                ? 'Order #${order.code}'
                                : 'Order #${order.id}',
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
                          order.formatTotal(),
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
                        ).then((_) => _fetchOrders()); // Refresh when returning from detail page
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
            Icon(Icons.receipt_long, size: 70, color: Colors.grey[400]),
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
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, HomePage.route);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: GlobalStyle.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text(
                'Pesan Sekarang',
                style: TextStyle(fontWeight: FontWeight.w500),
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
          CircularProgressIndicator(color: GlobalStyle.primaryColor),
          const SizedBox(height: 16),
          Text(
            'Memuat riwayat pesanan...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 70, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? 'Terjadi kesalahan',
            style: TextStyle(
              fontSize: 16,
              color: Colors.red[600],
              fontWeight: FontWeight.w500,
              fontFamily: GlobalStyle.fontFamily,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _fetchOrders,
            style: ElevatedButton.styleFrom(
              backgroundColor: GlobalStyle.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Coba Lagi'),
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
          elevation: 0,
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
            tabs: const [
              Tab(text: 'Semua'),
              Tab(text: 'Diproses'),
              Tab(text: 'Selesai'),
              Tab(text: 'Dibatalkan'),
            ],
          ),
        ),
        body: _isLoading
            ? _buildLoadingState()
            : _errorMessage != null
            ? _buildErrorState()
            : RefreshIndicator(
          onRefresh: _fetchOrders,
          color: GlobalStyle.primaryColor,
          child: TabBarView(
            controller: _tabController,
            children: List.generate(4, (tabIndex) {
              final filteredOrders = getFilteredOrders(tabIndex);

              if (filteredOrders.isEmpty) {
                return _buildEmptyState('Tidak ada pesanan ${tabIndex == 0 ? '' : tabIndex == 1 ? 'diproses' : tabIndex == 2 ? 'selesai' : 'dibatalkan'}');
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredOrders.length,
                itemBuilder: (context, index) {
                  return _buildOrderCard(filteredOrders[index], index);
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