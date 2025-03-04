import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../Component/driver_bottom_navigation.dart';
import 'package:del_pick/Models/item_model.dart';
import 'package:del_pick/Models/store.dart';
import 'package:del_pick/Models/tracking.dart';
import 'package:del_pick/Models/order.dart';
import 'package:del_pick/Models/customer.dart';
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
  int? tappedIndex;
  int _selectedIndex = 1; // History tab selected

  // Animation controllers for cards
  late List<AnimationController> _cardControllers;
  late List<Animation<Offset>> _cardAnimations;

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
  ];

  @override
  void initState() {
    super.initState();

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
    for (var controller in _cardControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Map<String, List<Order>> groupedOrders() {
    return {
      'Selesai': orders.where((order) => order.status == OrderStatus.completed).toList(),
      'Dibatalkan': orders.where((order) => order.status == OrderStatus.cancelled).toList(),
    };
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
      position: _cardAnimations[index],
      child: GestureDetector(
        onTap: () {
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
        },
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
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: GlobalStyle.lightColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.local_shipping_outlined,
                      color: GlobalStyle.primaryColor,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.store.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
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
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                statusText,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
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
                          maxLines: 1,
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
                                  'Biaya Pengiriman',
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
                                  ).format(deliveryFee),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: GlobalStyle.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                            if (order.status == OrderStatus.completed)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'Lihat Detail',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
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
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_shipping_outlined,
            size: 80,
            color: GlobalStyle.disableColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Tidak ada riwayat pengiriman',
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

  @override
  Widget build(BuildContext context) {
    final groupedOrdersList = groupedOrders();
    final hasOrders = groupedOrdersList.values.any((list) => list.isNotEmpty);

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
                border: Border.all(color: Colors.blue, width: 1.0),
              ),
              child: const Icon(Icons.arrow_back_ios_new, color: Colors.blue, size: 18),
            ),
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                HomeDriverPage.route,
                    (route) => false,
              );
            },
          ),
        ),
        body: !hasOrders
            ? _buildEmptyState()
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: groupedOrdersList.length,
          itemBuilder: (context, sectionIndex) {
            final status = groupedOrdersList.keys.elementAt(sectionIndex);
            final statusOrders = groupedOrdersList[status] ?? [];

            if (statusOrders.isEmpty) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (sectionIndex > 0) const SizedBox(height: 16),
                Text(
                  status,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...statusOrders.asMap().entries.map(
                      (entry) => _buildOrderCard(entry.value, entry.key),
                ),
              ],
            );
          },
        ),
        bottomNavigationBar: DriverBottomNavigation(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}