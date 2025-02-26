import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Views/Driver/track_order.dart';
import 'package:lottie/lottie.dart';

class HistoryDriverDetailPage extends StatefulWidget {
  static const String route = '/Driver/HistoryDriverDetail';
  final Map<String, dynamic> orderDetail;

  const HistoryDriverDetailPage({Key? key, required this.orderDetail}) : super(key: key);

  @override
  _HistoryDriverDetailPageState createState() => _HistoryDriverDetailPageState();
}

class _HistoryDriverDetailPageState extends State<HistoryDriverDetailPage> {
  String? selectedStatus;

  final List<Map<String, dynamic>> statusOptions = [
    {
      'value': 'assigned',
      'label': 'Assigned',
      'color': Colors.blue,
    },
    {
      'value': 'picking_up',
      'label': 'Menjemput',
      'color': Colors.orange,
    },
    {
      'value': 'delivering',
      'label': 'Mengantar',
      'color': Colors.purple,
    },
    {
      'value': 'completed',
      'label': 'Selesai',
      'color': Colors.green,
    },
    {
      'value': 'cancelled',
      'label': 'Dibatalkan',
      'color': Colors.red,
    },
  ];

  @override
  void initState() {
    super.initState();
    String? status = widget.orderDetail['status'] as String?;
    selectedStatus = status ?? statusOptions.first['value'] as String;
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/animations/check_animation.json',
                  width: 200,
                  height: 200,
                  repeat: false,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Pengantaran Selesai!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/Driver/HomePage',
                          (Route<dynamic> route) => false,
                    );
                  },
                  child: const Text('Kembali ke laman Utama'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPickupConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Konfirmasi'),
          content: const Text('Apakah Anda yakin ingin mengambil pesanan ini?'),
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
                  widget.orderDetail['status'] = 'picking_up';
                  selectedStatus = 'picking_up';
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Pesanan sedang diambil')),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _navigateToTrackOrder() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TrackOrderScreen(),
      ),
    );

    if (result == 'completed') {
      setState(() {
        selectedStatus = 'completed';
        widget.orderDetail['status'] = 'completed';
      });
      _showCompletionDialog();
    }
  }

  Future<void> _openWhatsApp(String phoneNumber) async {
    String message = 'Halo, saya driver dari Del Pick mengenai pesanan Anda...';
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

  Widget _buildStatusIndicator() {
    final statusOption = statusOptions.firstWhere(
          (status) => status['value'] == selectedStatus,
      orElse: () => statusOptions.first,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: GlobalStyle.borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: statusOption['color'] as Color,
              shape: BoxShape.circle,
            ),
          ),
          Text(
            statusOption['label'] as String,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    if (selectedStatus == 'assigned') {
      return Row(
        children: [
          IconButton(
            icon: const Icon(Icons.cancel),
            onPressed: () {
              setState(() {
                selectedStatus = 'cancelled';
                widget.orderDetail['status'] = 'cancelled';
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Delivery cancelled')),
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
              onPressed: _showPickupConfirmationDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text(
                'PICKUP ORDER',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      );
    } else if (selectedStatus == 'picking_up') {
      return Row(
        children: [
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  selectedStatus = 'delivering';
                  widget.orderDetail['status'] = 'delivering';
                });
                _navigateToTrackOrder();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text(
                'Mulai Pengiriman',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      );
    } else if (selectedStatus == 'delivering') {
      return Row(
        children: [
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: _navigateToTrackOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text(
                'Lihat Pelacakan',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
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
                icon: Container(
                  padding: const EdgeInsets.all(4.0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.blue, width: 1.0),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new, color: Colors.blue, size: 18),
                ),
                onPressed: () => Navigator.pop(context),
              ),
              const Text(
                'Detail Pengantaran',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Status Pengiriman',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _buildStatusIndicator(),
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Lokasi Penjemputan',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.chat, size: 20),
                                  onPressed: () => _openWhatsApp(widget.orderDetail['storePhone']),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.blue.shade100,
                                    foregroundColor: Colors.blue,
                                  ),
                                ),
                              ],
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  widget.orderDetail['customerName'] ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.chat, size: 20),
                                  onPressed: () => _openWhatsApp(widget.orderDetail['customerPhone']),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.blue.shade100,
                                    foregroundColor: Colors.blue,
                                  ),
                                ),
                              ],
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
    ],
    ),
    )).toList(),
    const SizedBox(height: 8),
    Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
    Text(
    'Biaya Pengiriman',
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
    'Total Biaya',
    style: TextStyle(fontWeight: FontWeight.bold),
    ),
    Text(
    'Rp. $totalAmount',
    style: const TextStyle(fontWeight: FontWeight.bold),
    ),
    ],
    ),
    const SizedBox(height: 20),
    _buildActionButtons(),
    ],
    ),
    ),
    ),
    ),
    );
  }
}