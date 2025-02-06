import 'package:flutter/material.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:intl/intl.dart';

class HistoryPage extends StatelessWidget {
  static const String route = "/Customers/HistoryPage";

  const HistoryPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black54),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          'History',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: GlobalStyle.fontColor,
            fontFamily: GlobalStyle.fontFamily,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: const [
                  HistoryItem(
                    storeName: 'Nama Toko',
                    date: '2024-12-24 09:05:00',
                    amount: 120000,
                  ),
                  HistoryItem(
                    storeName: 'Nama Toko',
                    date: '2024-11-26 08:05:00',
                    amount: 30000,
                  ),
                  HistoryItem(
                    storeName: 'Nama Toko',
                    date: '2024-09-16 09:05:00',
                    amount: 60000,
                  ),
                  HistoryItem(
                    storeName: 'Nama Toko',
                    date: '2023-12-24 09:05:00',
                    amount: 70000,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HistoryItem extends StatelessWidget {
  final String storeName;
  final String date;
  final int amount;

  const HistoryItem({
    Key? key,
    required this.storeName,
    required this.date,
    required this.amount,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final parsedDate = DateTime.parse(date);
    final formattedDate = DateFormat('dd MMM yyyy, hh.mm a').format(parsedDate);

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: GlobalStyle.lightColor,
                  borderRadius: BorderRadius.circular(24.0),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Image(
                    image: NetworkImage(
                        'https://storage.googleapis.com/a1aa/image/iR2625wbKq3I2RnOTTQ78WJ20ju6Vqm9JqouNSApRy8.jpg'),
                  ),
                ),
              ),
              const SizedBox(width: 16.0),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    storeName,
                    style: TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.bold,
                      fontFamily: GlobalStyle.fontFamily,
                      color: GlobalStyle.fontColor,
                    ),
                  ),
                  Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 12.0,
                      color: GlobalStyle.fontColor,
                      fontFamily: GlobalStyle.fontFamily,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Text(
            NumberFormat.currency(locale: 'id', symbol: 'Rp. ', decimalDigits: 0)
                .format(amount),
            style: TextStyle(
              fontSize: 16.0,
              fontWeight: FontWeight.bold,
              fontFamily: GlobalStyle.fontFamily,
              color: GlobalStyle.fontColor,
            ),
          ),
        ],
      ),
    );
  }
}
