import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../Component/cust_bottom_navigation.dart';
import 'cart_screen.dart';
import 'history_detail.dart';

class HistoryCustomer extends StatefulWidget {
  static const String route = "/Customers/HistoryCustomer";

  const HistoryCustomer({Key? key}) : super(key: key);

  @override
  State<HistoryCustomer> createState() => _HistoryCustomerState();
}

class _HistoryCustomerState extends State<HistoryCustomer> {
  int? tappedIndex;
  int _selectedIndex = 2; // Set to 2 for History tab

  // Sample order data with different statuses
  final List<Map<String, dynamic>> orders = [
    {
      'storeName': 'RM Padang Sabana 01',
      'date': '2024-12-24 09:05:00',
      'amount': 27700,
      'items': '1 Nasi Ayam Bakar Komplit + EsTeh / Teh Hangat',
      'status': 'Selesai',
    },
    {
      'storeName': 'Keju Kesu, Letda Sujono',
      'date': '2024-11-26 08:05:00',
      'amount': 41100,
      'items': '1 Sepasang 3',
      'status': 'Selesai',
    },
    {
      'storeName': 'RM Padang Sabana 01',
      'date': '2024-09-16 09:05:00',
      'amount': 43200,
      'items': '1 Nasi Telor Dadar, 1 Nasi Ayam Goreng',
      'status': 'Selesai',
    },
  ];

  Map<String, List<Map<String, dynamic>>> groupedOrders() {
    return {
      'Selesai': orders.where((order) => order['status'] == 'Selesai').toList(),
      'Diproses': orders.where((order) => order['status'] == 'Diproses').toList(),
      'Dibatalkan': orders.where((order) => order['status'] == 'Dibatalkan').toList(),
    };
  }

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'selesai':
        return Colors.green;
      case 'diproses':
        return Colors.blue;
      case 'dibatalkan':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildOrderCard(Map<String, dynamic> order, int index) {
    final parsedDate = DateTime.parse(order['date']);
    final formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(parsedDate);
    final statusColor = getStatusColor(order['status']);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HistoryDetailPage(
              storeName: order['storeName'],
              date: order['date'],
              amount: order['amount'],
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
                    image: const DecorationImage(
                      image: AssetImage('assets/images/menu_item.jpg'),
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
                        order['storeName'],
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
                            order['status'],
                            style: TextStyle(
                              fontSize: 14,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        order['items'],
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
                        ).format(order['amount']),
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
            if (order['status'] == 'Selesai') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CartScreen(cartItems: []),
                          ),
                              (Route<dynamic> route) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        side: const BorderSide(color: Colors.grey),
                      ),
                      child: const Text('Beli Lagi'),
                    ),
                  ),
                ],
              ),
            ],
          ],
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
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(4.0),
            decoration: BoxDecoration(
              color: Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.blue,
                width: 1.0,
              ),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.blue,
              size: 18,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Riwayat Pesanan',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
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