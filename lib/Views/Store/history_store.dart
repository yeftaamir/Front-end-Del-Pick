import 'package:del_pick/Views/Store/home_store.dart';
import 'package:flutter/material.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Views/Component/bottom_navigation.dart';
import 'historystore_detail.dart';

class HistoryStorePage extends StatefulWidget {
  static const String route = '/Store/HistoryStore';

  const HistoryStorePage({Key? key}) : super(key: key);

  @override
  _HistoryStorePageState createState() => _HistoryStorePageState();
}

class _HistoryStorePageState extends State<HistoryStorePage> {
  final List<Map<String, dynamic>> historyItems = [
    {
      'customerName': 'Nama Pelanggan',
      'date': '24 Des 2024, 09.05 AM',
      'amount': 120000,
      'icon': 'https://storage.googleapis.com/a1aa/image/8GC3tfIZERZXkmfEAZRR1JKQRw_0G7KXJDBbvR_awxk.jpg',
      'items': [
        {
          'name': 'Nama Item',
          'quantity': 1,
          'price': 120000,
          'image': 'https://storage.googleapis.com/a1aa/image/OQKvf9mggQG7uy7G60NIX8Q2rTlFJGSj6NluabntevY.jpg'
        }
      ],
      'status': 'rejected',
      'deliveryFee': 12000,
      'customerAddress': 'Institut Teknologi Del, Sitoluama, Kec. Balige, Toba, Sumatera Utara 22381',
      'storeAddress': 'Jalan Bunga Mawar, No. 10, RT 04/32',
      'phoneNumber': '+6281234567890'
    },
    {
      'customerName': 'Nama Pelanggan',
      'date': '26 Nov 2024, 08.05 AM',
      'amount': 30000,
      'icon': 'https://storage.googleapis.com/a1aa/image/8GC3tfIZERZXkmfEAZRR1JKQRw_0G7KXJDBbvR_awxk.jpg',
      'items': [
        {
          'name': 'Nama Item',
          'quantity': 1,
          'price': 30000,
          'image': 'https://storage.googleapis.com/a1aa/image/OQKvf9mggQG7uy7G60NIX8Q2rTlFJGSj6NluabntevY.jpg'
        }
      ],
      'status': 'completed',
      'deliveryFee': 12000,
      'customerAddress': 'Institut Teknologi Del, Sitoluama, Kec. Balige, Toba, Sumatera Utara 22381',
      'storeAddress': 'Jalan Bunga Mawar, No. 10, RT 04/32',
      'phoneNumber': '+6281234567890'
    }
  ];

  int _currentIndex = 2;

  // Filter items to show only rejected and completed orders
  List<Map<String, dynamic>> get filteredHistoryItems {
    return historyItems.where((item) =>
        ['rejected', 'completed'].contains(item['status'])
    ).toList();
  }

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onHistoryItemTapped(Map<String, dynamic> item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HistoryStoreDetailPage(orderDetail: item),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'rejected':
        return Colors.red;
      case 'completed':
        return Colors.green;
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
            Icons.history,
            size: 80,
            color: GlobalStyle.disableColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Tidak ada riwayat pesanan',
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
    final filteredItems = filteredHistoryItems;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
            'Riwayat',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black,
            )
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
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HomeStore(),
                ),
              );
            },
        ),
        backgroundColor: Colors.white,
        elevation: 0,
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
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: GlobalStyle.lightColor,
                    backgroundImage: NetworkImage(item['icon']),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['customerName'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item['date'],
                          style: TextStyle(
                            color: GlobalStyle.fontColor,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(item['status']).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _capitalizeStatus(item['status']),
                            style: TextStyle(
                              color: _getStatusColor(item['status']),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Rp. ${item['amount']}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: BottomNavigationComponent(
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}