import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:lottie/lottie.dart';

class HistoryStoreDetailPage extends StatefulWidget {
  static const String route = '/Store/HistoryStoreDetail';
  final Map<String, dynamic> orderDetail;

  const HistoryStoreDetailPage({Key? key, required this.orderDetail}) : super(key: key);

  @override
  _HistoryStoreDetailPageState createState() => _HistoryStoreDetailPageState();
}

class _HistoryStoreDetailPageState extends State<HistoryStoreDetailPage> {
  String _status = 'pending';

  // Simplified status options with only necessary information
  final Map<String, Color> statusColors = {
    'pending': Colors.orange,
    'processing': Colors.blue,
    'picked_up': Colors.indigo,
    'completed': Colors.green,
    'rejected': Colors.red,
  };

  final Map<String, String> statusLabels = {
    'pending': 'Confirmation',
    'processing': 'Processing',
    'picked_up': 'Picked Up',
    'completed': 'Completed',
    'rejected': 'Rejected',
  };

  @override
  void initState() {
    super.initState();
    // Safely initialize status from order detail
    _status = widget.orderDetail['status']?.toString() ?? 'pending';
    if (!statusColors.containsKey(_status)) {
      _status = 'pending';
    }
  }

  Future<void> _openWhatsApp(String? phoneNumber, {bool isDriver = false}) async {
    if (phoneNumber == null) return;

    String message = isDriver
        ? 'Halo, saya dari toko mengenai pesanan yang akan diambil...'
        : 'Halo, saya dari toko mengenai pesanan Anda...';
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
                  'Order Completed!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/Store/HomePage',
                          (Route<dynamic> route) => false,
                    );
                  },
                  child: const Text('Back to Home'),
                ),
              ],
            ),
          ),
        );
      },
    );
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
                  _status = 'processing';
                  widget.orderDetail['status'] = 'processing';
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Pesanan sedang diproses')),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusIndicator() {
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
              color: statusColors[_status],
              shape: BoxShape.circle,
            ),
          ),
          Text(
            statusLabels[_status] ?? 'Unknown',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    switch (_status) {
      case 'pending':
        return Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _status = 'rejected';
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
        );
      case 'processing':
        return Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _status = 'picked_up';
                    widget.orderDetail['status'] = 'picked_up';
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'MARK AS PICKED UP',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      case 'picked_up':
        return Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _status = 'completed';
                    widget.orderDetail['status'] = 'completed';
                  });
                  _showCompletionDialog();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'COMPLETE ORDER',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.orderDetail['items'] as List?;
    final totalAmount = widget.orderDetail['amount'];
    final deliveryFee = widget.orderDetail['deliveryFee'];
    final driverInfo = widget.orderDetail['driverInfo'] as Map<String, dynamic>?;

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
                'Order Details',
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
                  if (driverInfo != null) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Colors.blue,
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
                                    'Driver Information',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.chat, size: 20),
                                    onPressed: () => _openWhatsApp(
                                      driverInfo['phone']?.toString(),
                                      isDriver: true,
                                    ),
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.blue.shade100,
                                      foregroundColor: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                'Driver: ${driverInfo['name'] ?? ''}',
                                style: TextStyle(
                                  color: GlobalStyle.fontColor,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                'Vehicle Number: ${driverInfo['vehicle'] ?? ''}',
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
                  ],
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
                            // Customer Information
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.orderDetail['customerName']?.toString() ?? '',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.chat, size: 20),
                                  onPressed: () => _openWhatsApp(
                                    widget.orderDetail['customerPhone']?.toString(),
                                  ),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.blue.shade100,
                                    foregroundColor: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              widget.orderDetail['customerAddress']?.toString() ?? '',
                              style: TextStyle(
                                color: GlobalStyle.fontColor,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Driver Information
                            if (widget.orderDetail['driverInfo'] != null) ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Driver: ${widget.orderDetail['driverInfo']['name']?.toString() ?? ''}',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.chat, size: 20),
                                    onPressed: () => _openWhatsApp(
                                      widget.orderDetail['driverInfo']['phone']?.toString(),
                                      isDriver: true,
                                    ),
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.blue.shade100,
                                      foregroundColor: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                'Vehicle Number: ${widget.orderDetail['driverInfo']['vehicle']?.toString() ?? ''}',
                                style: TextStyle(
                                  color: GlobalStyle.fontColor,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (items != null) ...[
        ...items.map((item) => Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Image.network(
            item['image']?.toString() ?? '',
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
                  item['name']?.toString() ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'x${item['quantity']?.toString() ?? '0'}',
                  style: TextStyle(
                    color: GlobalStyle.fontColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'Rp. ${item['price']?.toString() ?? '0'}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    )).toList(),
    ],
    const SizedBox(height: 8),
    Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
    Text(
    'Delivery Fee',
    style: TextStyle(
    color: GlobalStyle.fontColor,
    fontSize: 14,
    ),
    ),
    Text(
    'Rp. ${deliveryFee?.toString() ?? '0'}',
    style: const TextStyle(fontWeight: FontWeight.bold),
    ),
    ],
    ),
    const SizedBox(height: 8),
    Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
    const Text(
    'Total Amount',
    style: TextStyle(fontWeight: FontWeight.bold),
    ),
    Text(
    'Rp. ${totalAmount?.toString() ?? '0'}',
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