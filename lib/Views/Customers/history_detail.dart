import 'package:flutter/material.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:intl/intl.dart';
import 'cart_screen.dart';
import 'rating_cust.dart';

class HistoryDetailPage extends StatelessWidget {
  static const String route = "/Customers/HistoryDetailPage";

  final String storeName;
  final String date;
  final int amount;

  const HistoryDetailPage({
    Key? key,
    required this.storeName,
    required this.date,
    required this.amount,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final parsedDate = DateTime.parse(date);
    final formattedDate = DateFormat('dd MMM yyyy, hh.mm a').format(parsedDate);

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
          'Order Details',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: GlobalStyle.fontColor,
            fontFamily: GlobalStyle.fontFamily,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Delivery Address Section
              _buildSectionHeader('Alamat Pengiriman'),
              Text(
                'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
                style: TextStyle(
                  color: GlobalStyle.fontColor,
                  fontFamily: GlobalStyle.fontFamily,
                ),
              ),
              const SizedBox(height: 16),

              // Driver Information Section
              _buildSectionHeader('Informasi Driver'),
              Text(
                'Nama Driver\nPlat Nomor Kendaraan',
                style: TextStyle(
                  color: GlobalStyle.fontColor,
                  fontFamily: GlobalStyle.fontFamily,
                ),
              ),
              const SizedBox(height: 16),

              // Store and Items Section
              Text(
                storeName,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: GlobalStyle.fontColor,
                  fontFamily: GlobalStyle.fontFamily,
                ),
              ),
              const SizedBox(height: 16),

              // Order Items
              _buildOrderItem(
                'Nama Item 1',
                'https://storage.googleapis.com/a1aa/image/AHpMyzrtoOpMRqFBK3lhQ4JD3zLGRPF0QpMNs5_q-YQ.jpg',
                1,
                120000,
              ),
              _buildOrderItem(
                'Nama Item 2',
                'https://storage.googleapis.com/a1aa/image/uuP832OPNDUbpaSpsDcNn7EzZ9sSO6Q1fAI9sLloJZc.jpg',
                1,
                30000,
              ),
              _buildOrderItem(
                'Nama Item 3',
                'https://storage.googleapis.com/a1aa/image/3PLJlAYPI8CQvHjqfXqNtxLzx8XM-kpXNe756djbY0g.jpg',
                3,
                60000,
              ),

              // Payment Details Section
              const SizedBox(height: 16),
              _buildSectionHeader('Rincian Pembayaran'),
              _buildPaymentRow('Subtotal untuk Produk', 180000),
              _buildPaymentRow('Biaya Layanan', 30000),
              const Divider(thickness: 1),
              _buildTotalPaymentRow(210000),

              // Action Buttons
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
                        foregroundColor: GlobalStyle.fontColor,
                        side: BorderSide(color: GlobalStyle.borderColor),
                      ),
                      child: const Text('Beli Lagi'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RatingCustomerPage(
                              storeName: storeName,
                              driverName: 'Nama Driver',
                              vehicleNumber: 'Plat Nomor Kendaraan',
                              orderItems: [
                                OrderItem(
                                  name: 'Nama Item 1',
                                  formattedPrice: 'Rp 120.000',
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GlobalStyle.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Beri Rating'),
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: GlobalStyle.fontColor,
          fontFamily: GlobalStyle.fontFamily,
        ),
      ),
    );
  }

  Widget _buildOrderItem(String name, String imageUrl, int quantity, int price) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Image.network(
                imageUrl,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: GlobalStyle.fontColor,
                      fontFamily: GlobalStyle.fontFamily,
                    ),
                  ),
                  Text(
                    'x$quantity',
                    style: TextStyle(
                      color: GlobalStyle.fontColor,
                      fontFamily: GlobalStyle.fontFamily,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Text(
            NumberFormat.currency(
              locale: 'id',
              symbol: 'Rp. ',
              decimalDigits: 0,
            ).format(price),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: GlobalStyle.fontColor,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(String label, int amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: GlobalStyle.fontColor,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          Text(
            NumberFormat.currency(
              locale: 'id',
              symbol: 'Rp. ',
              decimalDigits: 0,
            ).format(amount),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: GlobalStyle.fontColor,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalPaymentRow(int amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Total Pembayaran',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: GlobalStyle.fontColor,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          Text(
            NumberFormat.currency(
              locale: 'id',
              symbol: 'Rp. ',
              decimalDigits: 0,
            ).format(amount),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: GlobalStyle.fontColor,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}