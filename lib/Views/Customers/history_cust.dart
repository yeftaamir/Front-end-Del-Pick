import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../Component/cust_bottom_navigation.dart';
import 'package:del_pick/Models/item_model.dart'; // Import Item model
import 'package:del_pick/Models/store.dart'; // Import StoreModel
import 'package:del_pick/Models/tracking.dart'; // Import Tracking
import 'package:del_pick/Models/order.dart'; // Import Order model
import 'cart_screen.dart';
import 'history_detail.dart';
import 'home_cust.dart';

class HistoryCustomer extends StatefulWidget {
  static const String route = "/Customers/HistoryCustomer";

  const HistoryCustomer({Key? key}) : super(key: key);

  @override
  State<HistoryCustomer> createState() => _HistoryCustomerState();
}

class _HistoryCustomerState extends State<HistoryCustomer> with TickerProviderStateMixin {
  int? tappedIndex;
  int _selectedIndex = 1;

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
      'Diproses': orders.where((order) =>
      order.status != OrderStatus.completed &&
          order.status != OrderStatus.cancelled).toList(),
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
      case OrderStatus.pending:
        return 'Menunggu';
      case OrderStatus.driverAssigned:
        return 'Driver Ditugaskan';
      case OrderStatus.driverHeadingToStore:
        return 'Menuju Toko';
      case OrderStatus.driverAtStore:
        return 'Di Toko';
      case OrderStatus.driverHeadingToCustomer:
        return 'Menuju Anda';
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

  Widget _buildOrderCard(Order order, int index) {
    final formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(order.orderDate);
    final statusColor = getStatusColor(order.status);
    final statusText = getStatusText(order.status);
    final itemsText = getOrderItemsText(order);

    return SlideTransition(
      position: _cardAnimations[index],
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => HistoryDetailPage(
                order: order,
              ),
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
                            Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 14,
                                color: statusColor,
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
              if (order.status == OrderStatus.completed) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
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
                        ),
                        child: const Text('Lihat'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupedOrdersList = groupedOrders();

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
      ),
      body: ListView.builder(
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
      bottomNavigationBar: CustomBottomNavigation(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }
}