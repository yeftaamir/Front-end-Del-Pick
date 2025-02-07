import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:del_pick/Views/Component/bottom_navigation.dart';
import 'package:del_pick/Common/global_style.dart';
import 'add_item.dart';

class HomeStore extends StatefulWidget {
  const HomeStore({Key? key}) : super(key: key);

  @override
  State<HomeStore> createState() => _HomeStoreState();
}

class _HomeStoreState extends State<HomeStore> {
  int _currentIndex = 0;

  // Dummy data for demonstration
  final List<Map<String, dynamic>> _newOrders = [
    {
      'customerName': 'John Doe',
      'orderTime': DateTime.now(),
      'totalPrice': 150000,
    },
    // Add more orders as needed
  ];

  final List<Map<String, dynamic>> _processedOrders = [
    {
      'customerName': 'Jane Smith',
      'orderTime': DateTime.now().subtract(const Duration(hours: 2)),
      'totalPrice': 75000,
    },
    // Add more processed orders
  ];

  Widget _buildOrderCard(Map<String, dynamic> order, bool isNew) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isNew ? GlobalStyle.borderColor : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: isNew
            ? Border.all(color: GlobalStyle.primaryColor, width: 1)
            : null,
      ),
      child: Stack(
        children: [
          if (isNew)
            Positioned(
              right: 8,
              top: 9,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: GlobalStyle.newInfo,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'New',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
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
                ElevatedButton(
                  onPressed: () {
                    // Handle view detail
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlobalStyle.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),

                    ),
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
        ],
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
            'Belum ada pesanan masuk',
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
              // Handle profile action
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_newOrders.isNotEmpty) ...[
              Text(
                'Pesanan Baru',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: GlobalStyle.primaryColor,
                ),
              ),
              const SizedBox(height: 12),
              ..._newOrders.map((order) => _buildOrderCard(order, true)),
              const SizedBox(height: 24),
            ],
            if (_processedOrders.isNotEmpty) ...[
              const Text(
                'Sedang Diproses',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ..._processedOrders.map((order) => _buildOrderCard(order, false)),
            ],
            if (_newOrders.isEmpty && _processedOrders.isEmpty)
              _buildEmptyState(),
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