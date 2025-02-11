import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:del_pick/Common/global_style.dart';

class HistoryStoreDetailPage extends StatefulWidget {
  static const String route = '/Store/HistoryStoreDetail';
  final Map<String, dynamic> orderDetail;

  const HistoryStoreDetailPage({Key? key, required this.orderDetail}) : super(key: key);

  @override
  _HistoryStoreDetailPageState createState() => _HistoryStoreDetailPageState();
}

class _HistoryStoreDetailPageState extends State<HistoryStoreDetailPage> {
  String? selectedStatus;  // Make nullable

  // Define status options
  final List<Map<String, dynamic>> statusOptions = [
    {
      'value': 'rejected',
      'label': 'Rejected',
      'color': Colors.red,
    },
    {
      'value': 'processed',
      'label': 'Processed',
      'color': Colors.blue,
    },
    {
      'value': 'detained',
      'label': 'Detained',
      'color': Colors.orange,
    },
    {
      'value': 'picked_up',
      'label': 'Picked Up',
      'color': Colors.purple,
    },
    {
      'value': 'completed',
      'label': 'Completed',
      'color': Colors.green,
    },
  ];

  @override
  void initState() {
    super.initState();
    // Set initial status with proper null handling
    String? status = widget.orderDetail['status'] as String?;
    selectedStatus = status ?? statusOptions.first['value'] as String;
  }

  void _showConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Konfirmasi'),
          content: const Text('Apakah Anda yakin ingin menerima pesanan ini?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Batal'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Ya'),
              onPressed: () {
                setState(() {
                  widget.orderDetail['status'] = 'processed';
                  selectedStatus = 'processed';
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Pesanan diterima')),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _openWhatsApp() async {
    String phoneNumber = widget.orderDetail['phoneNumber'];
    String message = 'Halo, saya dari toko mengenai pesanan Anda...';
    String url = 'https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}';

    if (await canLaunch(url)) {
      await launch(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak dapat membuka WhatsApp')),
        );
      }
    }
  }

  Widget _buildStatusDropdown() {
    // Ensure we have a valid initial value
    if (selectedStatus == null ||
        !statusOptions.any((status) => status['value'] == selectedStatus)) {
      selectedStatus = statusOptions.first['value'] as String;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: GlobalStyle.borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedStatus,
          isExpanded: true,
          items: statusOptions.map((status) {
            return DropdownMenuItem<String>(
              value: status['value'] as String,
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: status['color'] as Color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Text(status['label'] as String),
                ],
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                selectedStatus = newValue;
                widget.orderDetail['status'] = newValue;
              });

              // Find the label for the selected status
              final selectedStatusOption = statusOptions.firstWhere(
                    (status) => status['value'] == newValue,
                orElse: () => statusOptions.first,
              );

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Status updated to ${selectedStatusOption['label']}'),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.orderDetail['items'] as List;
    final totalAmount = widget.orderDetail['amount'];
    final deliveryFee = widget.orderDetail['deliveryFee'];

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      color: GlobalStyle.primaryColor,
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text(
                      'Delivery',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Order Status',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                _buildStatusDropdown(),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: GlobalStyle.borderColor),
                      bottom: BorderSide(color: GlobalStyle.borderColor),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            margin: const EdgeInsets.only(top: 4),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Toko Indonesia',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  widget.orderDetail['storeAddress'] ?? '',
                                  style: TextStyle(
                                    color: GlobalStyle.fontColor,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                            margin: const EdgeInsets.only(top: 4),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.orderDetail['customerName'] ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  widget.orderDetail['customerAddress'] ?? '',
                                  style: TextStyle(
                                    color: GlobalStyle.fontColor,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ...items.map((item) => Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Image.network(
                        item['image'] ?? '',
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 50,
                            height: 50,
                            color: Colors.grey[300],
                            child: const Icon(Icons.error),
                          );
                        },
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['name'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'x${item['quantity'] ?? 0}',
                              style: TextStyle(
                                color: GlobalStyle.fontColor,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'Rp. ${item['price'] ?? 0}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                )).toList(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tarif pengiriman',
                      style: TextStyle(
                        color: GlobalStyle.fontColor,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Rp. $deliveryFee',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total harga',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Rp. $totalAmount',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chat),
                      onPressed: _openWhatsApp,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.blue.shade100,
                        foregroundColor: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        setState(() {
                          selectedStatus = 'rejected';
                          widget.orderDetail['status'] = 'rejected';
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Order rejected')),
                        );
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.red.shade100,
                        foregroundColor: Colors.red,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _showConfirmationDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'TERIMA',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}