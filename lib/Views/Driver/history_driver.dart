import 'package:flutter/material.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Views/Component/driver_bottom_navigation.dart';
import 'package:del_pick/Views/Driver/history_driver_detail.dart';

class HistoryDriverPage extends StatefulWidget {
  static const String route = '/Driver/HistoryDriver';

  const HistoryDriverPage({Key? key}) : super(key: key);

  @override
  _HistoryDriverPageState createState() => _HistoryDriverPageState();
}

class _HistoryDriverPageState extends State<HistoryDriverPage> {
  final List<Map<String, dynamic>> historyItems = [
    {
      'customerName': 'John Doe',
      'date': '24 Des 2024, 09.05 AM',
      'amount': 120000,
      'items': [
        {
          'name': 'Product 1',
          'quantity': 2,
          'price': 60000,
          'image': 'https://example.com/image1.jpg'
        }
      ],
      'status': 'completed',
      'deliveryFee': 12000,
      'customerAddress': 'Institut Teknologi Del, Sitoluama',
      'storeAddress': 'Jalan Bunga Mawar, No. 10',
      'storePhone': '6281234567890',
      'customerPhone': '6281234567891'
    },
    {
      'customerName': 'Jane Smith',
      'date': '26 Nov 2024, 08.05 AM',
      'amount': 30000,
      'items': [
        {
          'name': 'Product 2',
          'quantity': 1,
          'price': 30000,
          'image': 'https://example.com/image2.jpg'
        }
      ],
      'status': 'cancelled',
      'deliveryFee': 12000,
      'customerAddress': 'Kec. Balige, Toba, Sumatera Utara',
      'storeAddress': 'Jalan Melati, No. 15',
      'storePhone': '6281234567892',
      'customerPhone': '6281234567893'
    }
  ];

  // Current index for bottom navigation
  int _currentIndex = 1; // Set to 1 for History tab

  // Filter items to show only completed and cancelled deliveries
  List<Map<String, dynamic>> get filteredHistoryItems {
    return historyItems.where((item) =>
        ['completed', 'cancelled'].contains(item['status'])).toList();
  }

  void _onItemTapped(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  void _onHistoryItemTapped(Map<String, dynamic> item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HistoryDriverDetailPage(orderDetail: item),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return GlobalStyle.fontColor;
    }
  }

  String _capitalizeStatus(String status) {
    return status[0].toUpperCase() + status.substring(1);
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
    final filteredItems = filteredHistoryItems;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/Driver/HomePage',
              (route) => false,
        );
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Riwayat',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
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
                '/Driver/HomePage',
                    (route) => false,
              );
            },
          ),
        ),
        body: filteredItems.isEmpty
            ? _buildEmptyState()
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredItems.length,
          itemBuilder: (context, index) {
            final item = filteredItems[index];
            return GestureDetector(
              onTap: () => _onHistoryItemTapped(item),
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
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
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
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['customerName'],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              fontFamily: GlobalStyle.fontFamily,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item['date'],
                            style: TextStyle(
                              color: GlobalStyle.fontColor,
                              fontSize: 12,
                              fontFamily: GlobalStyle.fontFamily,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(item['status'])
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _capitalizeStatus(item['status']),
                              style: TextStyle(
                                color: _getStatusColor(item['status']),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                fontFamily: GlobalStyle.fontFamily,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Rp ${item['deliveryFee']}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            fontFamily: GlobalStyle.fontFamily,
                            color: GlobalStyle.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Biaya Pengiriman',
                          style: TextStyle(
                            fontSize: 12,
                            color: GlobalStyle.fontColor,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        bottomNavigationBar: DriverBottomNavigation(
          currentIndex: _currentIndex,
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}