import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'history_detail.dart';

class HistoryCustomer extends StatefulWidget {
  static const String route = "/Customers/HistoryCustomer";

  const HistoryCustomer({Key? key}) : super(key: key);

  @override
  State<HistoryCustomer> createState() => _HistoryCustomerState();
}

class _HistoryCustomerState extends State<HistoryCustomer> {
  // Track which item is being tapped
  int? tappedIndex;

  // Sample order data - you can replace this with your actual data
  final List<Map<String, dynamic>> orders = [
    {
      'storeName': 'Nama Toko 1',
      'date': '2024-12-24 09:05:00',
      'amount': 120000,
      'status': 'Completed',
    },
    {
      'storeName': 'Nama Toko 2',
      'date': '2024-11-26 08:05:00',
      'amount': 30000,
      'status': 'Completed',
    },
    {
      'storeName': 'Nama Toko 3',
      'date': '2024-09-16 09:05:00',
      'amount': 60000,
      'status': 'Completed',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black54),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Riwayat Pesanan',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          final parsedDate = DateTime.parse(order['date']);
          final formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(parsedDate);

          return AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: tappedIndex == index ? 0.5 : 1.0,
            child: GestureDetector(
              onTapDown: (_) {
                setState(() {
                  tappedIndex = index;
                });
              },
              onTapUp: (_) async {
                await Future.delayed(const Duration(milliseconds: 200));
                if (mounted) {
                  setState(() {
                    tappedIndex = null;
                  });
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
                }
              },
              onTapCancel: () {
                setState(() {
                  tappedIndex = null;
                });
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
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.store,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 16),
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
                          Text(
                            formattedDate,
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
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        order['status'],
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}