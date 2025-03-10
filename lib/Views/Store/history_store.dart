import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:del_pick/Models/item_model.dart';
import 'package:del_pick/Models/store.dart';
import 'package:del_pick/Models/tracking.dart';
import 'package:del_pick/Models/order.dart';
import 'package:del_pick/Models/customer.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Views/Component/bottom_navigation.dart';
import 'package:del_pick/Views/Store/home_store.dart';
import 'package:del_pick/Views/Store/historystore_detail.dart';

class HistoryStorePage extends StatefulWidget {
  static const String route = '/Store/HistoryStore';

  const HistoryStorePage({Key? key}) : super(key: key);

  @override
  State<HistoryStorePage> createState() => _HistoryStorePageState();
}

class _HistoryStorePageState extends State<HistoryStorePage> with TickerProviderStateMixin {
  int _currentIndex = 2; // History tab selected
  late TabController _tabController;

  // Animation controllers for cards
  late List<AnimationController> _cardControllers;
  late List<Animation<Offset>> _cardAnimations;

  // Tab categories
  final List<String> _tabs = ['Semua', 'Diproses', 'Selesai', 'Dibatalkan'];

  // Sample orders for a store
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
          description: 'Nasi dengan ayam bakar dan lalapan',
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
      serviceCharge: 12000,
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
          description: 'Menu sepasang 3 porsi',
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
          description: 'Nasi dengan telur dadar',
        ),
        Item(
          id: 'ITM-004',
          name: 'Nasi Ayam Goreng',
          price: 21600,
          quantity: 1,
          imageUrl: 'assets/images/menu_item.jpg',
          isAvailable: true,
          status: 'available',
          description: 'Nasi dengan ayam goreng',
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
          description: 'Bakso jumbo dengan daging sapi pilihan',
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
        return 'Dibatalkan';
      case OrderStatus.pending:
        return 'Menunggu';
      case OrderStatus.driverAssigned:
        return 'Driver Ditugaskan';
      case OrderStatus.driverHeadingToStore:
        return 'Dalam Pengambilan';
      case OrderStatus.driverAtStore:
        return 'Driver Di Toko';
      case OrderStatus.driverHeadingToCustomer:
        return 'Dalam Pengantaran';
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
    final customer = 'Pelanggan'; // Normally would come from a Customer model

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
                CircleAvatar(
                  radius: 25,
                  backgroundColor: GlobalStyle.lightColor,
                  child: Icon(
                    Icons.person,
                    color: GlobalStyle.primaryColor,
                    size: 30,
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
                              customer,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 30,
                            width: 70,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => HistoryStoreDetailPage(orderDetail: {
                                      'customerName': customer,
                                      'date': formattedDate,
                                      'amount': order.total,
                                      'icon': 'assets/images/user_avatar.jpg', // Default avatar
                                      'items': order.items.map((item) => {
                                        'name': item.name,
                                        'quantity': item.quantity,
                                        'price': item.price,
                                        'image': item.imageUrl
                                      }).toList(),
                                      'status': order.status == OrderStatus.completed ? 'completed' : 'rejected',
                                      'deliveryFee': order.serviceCharge,
                                      'customerAddress': order.deliveryAddress,
                                      'storeAddress': order.store.address,
                                      'phoneNumber': '6281234567890', // Customer phone number
                                    }),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black87,
                                side: BorderSide(color: Colors.grey),
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                textStyle: TextStyle(fontSize: 12),
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
                        getOrderItemsText(order),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total Pesanan',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                NumberFormat.currency(
                                  locale: 'id',
                                  symbol: 'Rp ',
                                  decimalDigits: 0,
                                ).format(order.total),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: GlobalStyle.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ],
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
            Icon(
              Icons.history,
              size: 70,
              color: GlobalStyle.disableColor,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                color: GlobalStyle.fontColor,
                fontSize: 16,
                fontFamily: GlobalStyle.fontFamily,
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
                border: Border.all(color: Colors.blue, width: 1.0),
              ),
              child: const Icon(Icons.arrow_back_ios_new, color: Colors.blue, size: 18),
            ),
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                HomeStore.route,
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
                return _buildOrderCard(filteredOrders[index], index);
              },
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