import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import '../Component/driver_bottom_navigation.dart';
import 'package:del_pick/Models/item_model.dart';
import 'package:del_pick/Models/store.dart';
import 'package:del_pick/Models/tracking.dart';
import 'package:del_pick/Models/order.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Views/Driver/history_driver_detail.dart';
import 'home_driver.dart';

class HistoryDriverPage extends StatefulWidget {
  static const String route = '/Driver/HistoryDriver';

  const HistoryDriverPage({Key? key}) : super(key: key);

  @override
  State<HistoryDriverPage> createState() => _HistoryDriverPageState();
}

class _HistoryDriverPageState extends State<HistoryDriverPage> with TickerProviderStateMixin {
  int _selectedIndex = 1; // History tab selected
  late TabController _tabController;

  // Animation controllers for cards
  late List<AnimationController> _cardControllers;
  late List<Animation<Offset>> _cardAnimations;

  // Tab categories
  final List<String> _tabs = ['Semua', 'Diproses', 'Selesai', 'Di Batalkan'];

  // Sample orders for a driver
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
        phoneNumber: '6281234567892',
      ),
      deliveryAddress: 'Asrama Mahasiswa Del Institute, Laguboti',
      subtotal: 27700,
      serviceCharge: 12000, // Delivery fee for driver
      total: 39700,
      status: OrderStatus.completed,
      orderDate: DateTime.parse('2024-12-24 09:05:00'),
      tracking: Tracking.sample(),
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
        phoneNumber: '6281234567893',
      ),
      deliveryAddress: 'Asrama Mahasiswa Del Institute, Laguboti',
      subtotal: 41100,
      serviceCharge: 12000,
      total: 53100,
      status: OrderStatus.completed,
      orderDate: DateTime.parse('2024-11-26 08:05:00'),
      tracking: Tracking.sample(),
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
        phoneNumber: '6281234567894',
      ),
      deliveryAddress: 'Asrama Mahasiswa Del Institute, Laguboti',
      subtotal: 43200,
      serviceCharge: 12000,
      total: 55200,
      status: OrderStatus.cancelled,
      orderDate: DateTime.parse('2024-09-16 09:05:00'),
      tracking: Tracking.sample(),
    ),
    // Added in-progress order for example
    Order(
      id: 'ORD-004',
      items: [
        Item(
          id: 'ITM-005',
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
        phoneNumber: '6281234567895',
      ),
      deliveryAddress: 'Asrama Mahasiswa Del Institute, Laguboti',
      subtotal: 25000,
      serviceCharge: 12000,
      total: 37000,
      status: OrderStatus.driverHeadingToCustomer,
      orderDate: DateTime.parse('2024-12-28 14:15:00'),
      tracking: Tracking.sample(),
    ),
  ];

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
        Navigator.pushReplacementNamed(context, HomeDriverPage.route);
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

  Widget _buildOrderCard(Order order, int index) {
    final formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(order.orderDate);
    final statusColor = getStatusColor(order.status);
    final statusText = getStatusText(order.status);
    final deliveryFee = order.serviceCharge; // For driver, we show the delivery fee

    return SlideTransition(
      position: _cardAnimations[index % _cardAnimations.length],
      child: Card(
        elevation: 3,
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        color: Colors.white, // Changed card color to white
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () {
            _navigateToOrderDetail(order, formattedDate, deliveryFee);
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: GlobalStyle.lightColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.local_shipping_outlined,
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
                          'Biaya Pengiriman',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          GlobalStyle.formatRupiah(deliveryFee.toDouble()),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: GlobalStyle.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: () {
                        _navigateToOrderDetail(order, formattedDate, deliveryFee);
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

  void _navigateToOrderDetail(Order order, String formattedDate, double deliveryFee) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HistoryDriverDetailPage(orderDetail: {
          'customerName': 'Customer', // Usually would come from a Customer model
          'date': formattedDate,
          'amount': order.total,
          'items': order.items.map((item) => {
            'name': item.name,
            'quantity': item.quantity,
            'price': item.price,
            'image': item.imageUrl
          }).toList(),
          'status': order.status.toString().split('.').last,
          'deliveryFee': deliveryFee,
          'customerAddress': order.deliveryAddress,
          'storeAddress': order.store.address,
          'storePhone': order.store.phoneNumber,
          'customerPhone': '6281234567891', // Usually would come from a Customer model
        }),
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
            'Belum ada riwayat pengiriman',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
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
          HomeDriverPage.route,
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
            'Riwayat Pengiriman',
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
                HomeDriverPage.route,
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
            tabs: _tabs.map((String tab) => Tab(text: tab)).toList(),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: List.generate(_tabs.length, (tabIndex) {
            final filteredOrders = getFilteredOrders(tabIndex);

            if (filteredOrders.isEmpty) {
              return _buildEmptyState('Tidak ada pengiriman ${_tabs[tabIndex].toLowerCase()}');
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
        bottomNavigationBar: DriverBottomNavigation(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}