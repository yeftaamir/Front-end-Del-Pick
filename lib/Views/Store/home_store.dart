import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:del_pick/Views/Component/bottom_navigation.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Views/Store/historystore_detail.dart';
import 'package:del_pick/Views/Store/profil_store.dart';

class HomeStore extends StatefulWidget {
  const HomeStore({Key? key}) : super(key: key);

  @override
  State<HomeStore> createState() => _HomeStoreState();
}

class _HomeStoreState extends State<HomeStore> {
  int _currentIndex = 0;

  // Dummy data with status field
  final List<Map<String, dynamic>> _orders = [
    {
      'customerName': 'John Doe',
      'orderTime': DateTime.now(),
      'totalPrice': 150000,
      'status': 'processed',
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
      'phoneNumber': '6281234567890'
    },
    {
      'customerName': 'Jane Smith',
      'orderTime': DateTime.now().subtract(const Duration(hours: 2)),
      'totalPrice': 75000,
      'status': 'detained',
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
      'phoneNumber': '6281234567891'
    },
    {
      'customerName': 'Bob Wilson',
      'orderTime': DateTime.now().subtract(const Duration(hours: 4)),
      'totalPrice': 200000,
      'status': 'picked_up',
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
      'phoneNumber': '6281234567892'
    }
  ];

  List<Map<String, dynamic>> get filteredOrders {
    return _orders.where((order) =>
        ['processed', 'detained', 'picked_up'].contains(order['status'])
    ).toList();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'processed':
        return Colors.blue;
      case 'detained':
        return Colors.orange;
      case 'picked_up':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'processed':
        return 'Processed';
      case 'detained':
        return 'Detained';
      case 'picked_up':
        return 'Picked Up';
      default:
        return 'Unknown';
    }
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    String status = order['status'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
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
                      Text(
                        order['customerName'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('dd MMM yyyy HH:mm')
                            .format(order['orderTime']),
                        style: TextStyle(color: GlobalStyle.fontColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Rp ${NumberFormat('#,###').format(order['totalPrice'])}',
                        style: TextStyle(
                          color: GlobalStyle.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getStatusLabel(status),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HistoryStoreDetailPage(
                      orderDetail: order,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: GlobalStyle.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                minimumSize: const Size(double.infinity, 36),
              ),
              child: const Text(
                'Lihat Detail',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ],
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
            Icons.inbox_rounded,
            size: 80,
            color: GlobalStyle.disableColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Tidak ada pesanan yang diproses',
            style: TextStyle(
              color: GlobalStyle.fontColor,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orders = filteredOrders;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Delivery',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              Icons.person,
              color: GlobalStyle.fontColor,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileStore(),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daftar Pesanan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (orders.isEmpty)
              _buildEmptyState()
            else
              ...orders.map(_buildOrderCard),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationComponent(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
      ),
    );
  }
}