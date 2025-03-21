import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Views/Component/driver_bottom_navigation.dart';
import 'package:del_pick/Views/Driver/history_driver_detail.dart';
import 'package:del_pick/Views/Driver/profil_driver.dart';

class HomeDriverPage extends StatefulWidget {
  static const String route = '/Driver/HomePage';
  const HomeDriverPage({Key? key}) : super(key: key);

  @override
  State<HomeDriverPage> createState() => _HomeDriverPageState();
}

class _HomeDriverPageState extends State<HomeDriverPage> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late List<AnimationController> _cardControllers;
  late List<Animation<Offset>> _cardAnimations;

  final List<Map<String, dynamic>> _deliveries = [
    {
      'customerName': 'John Doe',
      'orderTime': DateTime.now(),
      'totalPrice': 150000,
      'status': 'assigned',
      'items': [
        {
          'name': 'Product 1',
          'quantity': 2,
          'price': 75000,
          'image': 'https://example.com/image1.jpg'
        }
      ],
      'deliveryFee': 10000,
      'amount': 160000,
      'storeAddress': 'Store Address 1',
      'customerAddress': 'Customer Address 1',
      'storePhone': '6281234567890',
      'customerPhone': '6281234567891'
    },
    {
      'customerName': 'Jane Smith',
      'orderTime': DateTime.now().subtract(const Duration(hours: 2)),
      'totalPrice': 75000,
      'status': 'picking_up',
      'items': [
        {
          'name': 'Product 2',
          'quantity': 1,
          'price': 75000,
          'image': 'https://example.com/image2.jpg'
        }
      ],
      'deliveryFee': 10000,
      'amount': 85000,
      'storeAddress': 'Store Address 2',
      'customerAddress': 'Customer Address 2',
      'storePhone': '6281234567892',
      'customerPhone': '6281234567893'
    },
    {
      'customerName': 'Bob Wilson',
      'orderTime': DateTime.now().subtract(const Duration(hours: 4)),
      'totalPrice': 200000,
      'status': 'delivering',
      'items': [
        {
          'name': 'Product 3',
          'quantity': 2,
          'price': 100000,
          'image': 'https://example.com/image3.jpg'
        }
      ],
      'deliveryFee': 10000,
      'amount': 210000,
      'storeAddress': 'Store Address 3',
      'customerAddress': 'Customer Address 3',
      'storePhone': '6281234567894',
      'customerPhone': '6281234567895'
    }
  ];

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers for each delivery card
    _cardControllers = List.generate(
      _deliveries.length,
          (index) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 600 + (index * 200)),
      ),
    );

    // Create slide animations for each card
    _cardAnimations = _cardControllers.map((controller) {
      return Tween<Offset>(
        begin: const Offset(0, 0.5),
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

  List<Map<String, dynamic>> get activeDeliveries {
    return _deliveries.where((delivery) =>
        ['assigned', 'picking_up', 'delivering'].contains(delivery['status'])
    ).toList();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'assigned':
        return Colors.blue;
      case 'picking_up':
        return Colors.orange;
      case 'delivering':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'assigned':
        return 'Pesanan Masuk';
      case 'picking_up':
        return 'Dijemput';
      case 'delivering':
        return 'Diantar';
      default:
        return 'Unknown';
    }
  }

  Widget _buildDeliveryCard(Map<String, dynamic> delivery, int index) {
    String status = delivery['status'] as String;

    return SlideTransition(
      position: _cardAnimations[index],
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.person, color: GlobalStyle.primaryColor),
                            const SizedBox(width: 8),
                            Text(
                              delivery['customerName'],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                fontFamily: GlobalStyle.fontFamily,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.access_time, color: GlobalStyle.fontColor, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('dd MMM yyyy HH:mm').format(delivery['orderTime']),
                              style: TextStyle(
                                color: GlobalStyle.fontColor,
                                fontFamily: GlobalStyle.fontFamily,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.payments, color: GlobalStyle.primaryColor, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              'Rp ${NumberFormat('#,###').format(delivery['totalPrice'])}',
                              style: TextStyle(
                                color: GlobalStyle.primaryColor,
                                fontWeight: FontWeight.bold,
                                fontFamily: GlobalStyle.fontFamily,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getStatusLabel(status),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: GlobalStyle.lightColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on, color: GlobalStyle.primaryColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Jemput: ${delivery['storeAddress']}',
                            style: TextStyle(
                              color: GlobalStyle.fontColor,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Antar: ${delivery['customerAddress']}',
                            style: TextStyle(
                              color: GlobalStyle.fontColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HistoryDriverDetailPage(
                        orderDetail: delivery,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlobalStyle.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  minimumSize: const Size(double.infinity, 40),
                ),
                child: Text(
                  'Lihat Detail',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
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
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: GlobalStyle.lightColor.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.local_shipping_outlined,
              size: 80,
              color: GlobalStyle.primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Tidak ada pengiriman aktif',
            style: TextStyle(
              color: GlobalStyle.fontColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Anda akan melihat pengiriman aktif di sini',
            style: TextStyle(
              color: GlobalStyle.fontColor.withOpacity(0.7),
              fontSize: 14,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deliveries = activeDeliveries;

    return Scaffold(
      backgroundColor: const Color(0xffD6E6F2),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pengantaran',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('EEEE, dd MMMM yyyy').format(DateTime.now()),
                          style: TextStyle(
                            color: GlobalStyle.fontColor,
                            fontSize: 12,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(context, ProfileDriverPage.route);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: GlobalStyle.lightColor.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: FaIcon(
                          FontAwesomeIcons.user,
                          size: 20,
                          color: GlobalStyle.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Delivery List
              Expanded(
                child: deliveries.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                  itemCount: deliveries.length,
                  itemBuilder: (context, index) => _buildDeliveryCard(deliveries[index], index),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: DriverBottomNavigation(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}