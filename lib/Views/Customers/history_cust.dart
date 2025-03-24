import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../Component/cust_bottom_navigation.dart';
import 'package:del_pick/Models/item_model.dart';
import 'package:del_pick/Models/store.dart';
import 'package:del_pick/Models/tracking.dart';
import 'package:del_pick/Models/order.dart';
import 'package:del_pick/Views/Customers/history_detail.dart';
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

  // Sample order data using Order model
  final List<Order> orders = [
    Order(
      id: 'ORD-001',
      items: [
        Item(
          id: 'ITM-001',
          name: 'Nasi Ayam Bakar Komplit + EsTeh / Teh Hangat',
          price: 27700,
          quantity: 1,
          imageUrl: 'assets/images/menu_item.jpg',
          isAvailable: true,
          status: 'available',
        ),
      ],
      store: StoreModel(
        name: 'RM Padang Sabana 01',
        address: 'Jl. Padang Sabana No. A1',
        openHours: '07:00 - 21:00',
      ),
      deliveryAddress: 'Asrama Mahasiswa Del Institute, Laguboti',
      subtotal: 27700,
      serviceCharge: 0,
      total: 27700,
      status: OrderStatus.completed,
      orderDate: DateTime.parse('2024-12-24 09:05:00'),
    ),
    Order(
      id: 'ORD-002',
      items: [
        Item(
          id: 'ITM-002',
          name: 'Sepasang 3',
          price: 41100,
          quantity: 1,
          imageUrl: 'assets/images/menu_item.jpg',
          isAvailable: true,
          status: 'available',
        ),
      ],
      store: StoreModel(
        name: 'Keju Kesu, Letda Sujono',
        address: 'Jl. Letda Sujono',
        openHours: '08:00 - 22:00',
      ),
      deliveryAddress: 'Asrama Mahasiswa Del Institute, Laguboti',
      subtotal: 41100,
      serviceCharge: 0,
      total: 41100,
      status: OrderStatus.completed,
      orderDate: DateTime.parse('2024-11-26 08:05:00'),
    ),
    Order(
      id: 'ORD-003',
      items: [
        Item(
          id: 'ITM-003',
          name: 'Nasi Telor Dadar',
          price: 21600,
          quantity: 1,
          imageUrl: 'assets/images/menu_item.jpg',
          isAvailable: true,
          status: 'available',
        ),
        Item(
          id: 'ITM-004',
          name: 'Nasi Ayam Goreng',
          price: 21600,
          quantity: 1,
          imageUrl: 'assets/images/menu_item.jpg',
          isAvailable: true,
          status: 'available',
        ),
      ],
      store: StoreModel(
        name: 'RM Padang Sabana 01',
        address: 'Jl. Padang Sabana No. A1',
        openHours: '07:00 - 21:00',
      ),
      deliveryAddress: 'Asrama Mahasiswa Del Institute, Laguboti',
      subtotal: 43200,
      serviceCharge: 0,
      total: 43200,
      status: OrderStatus.completed,
      orderDate: DateTime.parse('2024-09-16 09:05:00'),
    ),
    // Added cancelled order for example
    Order(
      id: 'ORD-004',
      items: [
        Item(
          id: 'ITM-005',
          name: 'Nasi Goreng Spesial',
          price: 32500,
          quantity: 1,
          imageUrl: 'assets/images/menu_item.jpg',
          isAvailable: true,
          status: 'available',
        ),
      ],
      store: StoreModel(
        name: 'Warung Makan Barokah',
        address: 'Jl. Barokah No. 12',
        openHours: '08:00 - 21:00',
      ),
      deliveryAddress: 'Asrama Mahasiswa Del Institute, Laguboti',
      subtotal: 32500,
      serviceCharge: 0,
      total: 32500,
      status: OrderStatus.cancelled,
      orderDate: DateTime.parse('2024-10-10 12:30:00'),
    ),
    // Added in-progress order for example
    Order(
      id: 'ORD-005',
      items: [
        Item(
          id: 'ITM-006',
          name: 'Bakso Jumbo Spesial',
          price: 25000,
          quantity: 1,
          imageUrl: 'assets/images/menu_item.jpg',
          isAvailable: true,
          status: 'available',
        ),
      ],
      store: StoreModel(
        name: 'Bakso Pak Joko',
        address: 'Jl. Melati No. 5',
        openHours: '10:00 - 22:00',
      ),
      deliveryAddress: 'Asrama Mahasiswa Del Institute, Laguboti',
      subtotal: 25000,
      serviceCharge: 0,
      total: 25000,
      status: OrderStatus.driverHeadingToCustomer,
      orderDate: DateTime.parse('2024-12-28 14:15:00'),
    ),
  ];

  // Tab categories
  final List<String> _tabs = ['Semua', 'Diproses', 'Selesai', 'Di Batalkan'];

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: _tabs.length, vsync: this);

    // Initialize animation controllers for the maximum possible number of cards
    final totalCards = orders.length;
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

    // Start animations sequentially
    Future.delayed(const Duration(milliseconds: 100), () {
      for (var controller in _cardControllers) {
        controller.forward();
      }
    });
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
        order.status != OrderStatus.completed &&
            order.status != OrderStatus.cancelled
        ).toList();
      case 2: // Completed
        return orders.where((order) => order.status == OrderStatus.completed).toList();
      case 3: // Cancelled
        return orders.where((order) => order.status == OrderStatus.cancelled).toList();
      default:
        return orders;
    }
  }

  Color getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.completed:
        return Colors.green;
      case OrderStatus.cancelled:
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  String getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.completed:
        return 'Selesai';
      case OrderStatus.cancelled:
        return 'Di Batalkan';
      case OrderStatus.pending:
        return 'Menunggu';
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
      _selectedIndex = index;
      if (index == 0) {
        Navigator.pushReplacementNamed(context, HomePage.route);
      }
    });
  }

  String getOrderItemsText(Order order) {
    if (order.items.length == 1) {
      return order.items[0].name;
    } else {
      final firstItem = order.items[0].name;
      final otherItemsCount = order.items.length - 1;
      return '$firstItem, +$otherItemsCount item lainnya';
    }
  }

  // New method to handle navigation based on order status
  void navigateToCartScreen(Order order) {
    // Convert Order items to MenuItem items if needed for CartScreen
    List<MenuItem> menuItems = order.items.map((item) =>
        MenuItem(
          id: item.id,
          name: item.name,
          price: item.price,
          imageUrl: item.imageUrl,
          isAvailable: item.isAvailable,
          status: item.status,
        )
    ).toList();

    // Navigate to CartScreen with the order as completedOrder parameter
    Navigator.pushNamed(
      context,
      '/Customers/Cart',
      arguments: {
        'cartItems': menuItems,
        'completedOrder': order,
      },
    );
  }

  Widget _buildOrderCard(Order order, int index) {
    final formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(order.orderDate);
    final statusColor = getStatusColor(order.status);
    final statusText = getStatusText(order.status);
    final itemsText = getOrderItemsText(order);

    return SlideTransition(
      position: _cardAnimations[index % _cardAnimations.length],
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: AssetImage(order.items.first.imageUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
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
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Smaller right-aligned view button - Updated to navigate to CartScreen
                          SizedBox(
                            height: 30,
                            width: 70,
                            child: ElevatedButton(
                              onPressed: () {
                                // Always navigate to HistoryDetailPage for all order statuses
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => HistoryDetailPage(
                                      order: order,
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black87,
                                side: const BorderSide(color: Colors.grey),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                textStyle: const TextStyle(fontSize: 12),
                              ),
                              child: const Text('Lihat'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            formattedDate,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '•',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 14,
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        itemsText,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        NumberFormat.currency(
                          locale: 'id',
                          symbol: 'Rp ',
                          decimalDigits: 0,
                        ).format(order.total),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
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
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            padding: const EdgeInsets.all(5.0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.blue, width: 1.0),
            ),
            child: const Icon(Icons.arrow_back_ios_new, color: Colors.blue, size: 18),
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
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: Colors.blue,
          indicatorWeight: 3,
          tabs: _tabs.map((String tab) => Tab(text: tab)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: List.generate(_tabs.length, (tabIndex) {
          final filteredOrders = getFilteredOrders(tabIndex);

          if (filteredOrders.isEmpty) {
            return _buildEmptyState('Tidak ada pesanan ${_tabs[tabIndex].toLowerCase()}');
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredOrders.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  // Always navigate to HistoryDetailPage for all order statuses
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HistoryDetailPage(
                        order: filteredOrders[index],
                      ),
                    ),
                  );
                },
                child: _buildOrderCard(filteredOrders[index], index),
              );
            },
          );
        }),
      ),
      bottomNavigationBar: CustomBottomNavigation(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }
}

// Helper class to match CartScreen's expected item type
class MenuItem {
  final String id;
  final String name;
  final double price;
  final String imageUrl;
  final bool isAvailable;
  final String status;
  int quantity = 1;

  MenuItem({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.isAvailable,
    required this.status,
  });
}