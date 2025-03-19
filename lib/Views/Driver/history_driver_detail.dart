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

class _HistoryDriverDetailPageState extends State<HistoryDriverDetailPage> with TickerProviderStateMixin {
  String? selectedStatus;

  // Animation controllers for card sections
  late List<AnimationController> _cardControllers;
  late List<Animation<Offset>> _cardAnimations;
  late AnimationController _statusController;
  late Animation<Offset> _statusAnimation;

  final List<Map<String, dynamic>> statusOptions = [
    {
      'value': 'assigned',
      'label': 'Terima Pesanan',
      'color': Colors.blue,
    },
    {
      'value': 'picking_up',
      'label': 'Di Ambil',
      'color': Colors.orange,
    },
    {
      'value': 'delivering',
      'label': 'Di Antar',
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

    // Initialize card animation controllers
    _cardControllers = List.generate(
      4, // Number of card sections
          (index) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 600 + (index * 200)),
      ),
    );

    // Create slide animations for each card
    _cardAnimations = _cardControllers.map((controller) {
      return Tween<Offset>(
        begin: const Offset(0, -0.5),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeOutCubic,
      ));
    }).toList();

    // Initialize status animation controller
    _statusController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Create status animation
    _statusAnimation = Tween<Offset>(
      begin: const Offset(-0.5, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _statusController,
      curve: Curves.easeOutCubic,
    ));

    // Start animations sequentially
    Future.delayed(const Duration(milliseconds: 100), () {
      _statusController.forward();
      for (var i = 0; i < _cardControllers.length; i++) {
        Future.delayed(Duration(milliseconds: 100 * i), () {
          _cardControllers[i].forward();
        });
      }
    });
  }

  @override
  void dispose() {
    _statusController.dispose();
    for (var controller in _cardControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlobalStyle.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/Driver/HomePage',
                          (Route<dynamic> route) => false,
                    );
                  },
                  child: const Text(
                    'Kembali ke laman Utama',
                    style: TextStyle(color: Colors.white),
                  ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
              style: TextButton.styleFrom(
                foregroundColor: GlobalStyle.primaryColor,
              ),
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

    return SlideTransition(
      position: _statusAnimation,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_shipping, color: GlobalStyle.primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Status Pengiriman',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: statusOption['color'].withOpacity(0.2),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: statusOption['color']),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
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
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: statusOption['color'],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child, required int index}) {
    return SlideTransition(
      position: _cardAnimations[index],
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      ),
    );
  }

  Widget _buildLocationCard() {
    return _buildCard(
      index: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: GlobalStyle.primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Detail Lokasi',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: GlobalStyle.borderColor),
                borderRadius: BorderRadius.circular(12),
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
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(),
                  ),
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
          ],
        ),
      ),
    );
  }

  Widget _buildStoreInfoCard() {
    return _buildCard(
      index: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.store, color: GlobalStyle.primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Informasi Toko',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: GlobalStyle.borderColor),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      widget.orderDetail['storeImage'] ?? '',
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 60,
                          height: 60,
                          color: Colors.grey[300],
                          child: const Icon(Icons.store),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.orderDetail['storeName'] ?? 'Toko',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.orderDetail['storeAddress'] ?? '',
                          style: TextStyle(
                            color: GlobalStyle.fontColor,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.phone,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.orderDetail['storePhone'] ?? '',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerInfoCard() {
    return _buildCard(
      index: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: GlobalStyle.primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Informasi Pelanggan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: GlobalStyle.borderColor),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: GlobalStyle.lightColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.person,
                        color: GlobalStyle.primaryColor,
                        size: 30,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.orderDetail['customerName'] ?? 'Pelanggan',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.orderDetail['customerAddress'] ?? '',
                          style: TextStyle(
                            color: GlobalStyle.fontColor,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.phone,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.orderDetail['customerPhone'] ?? '',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsCard() {
    final items = widget.orderDetail['items'] as List;
    final totalAmount = widget.orderDetail['amount'];
    final deliveryFee = widget.orderDetail['deliveryFee'];

    return _buildCard(
      index: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shopping_bag, color: GlobalStyle.primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Item Pesanan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...items.map((item) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: GlobalStyle.borderColor),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      item['image'] ?? '',
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 60,
                          height: 60,
                          color: Colors.grey[300],
                          child: const Icon(Icons.image),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['name'] ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Rp. ${item['price'] ?? 0}',
                          style: TextStyle(
                            color: GlobalStyle.primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: GlobalStyle.lightColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'x${item['quantity'] ?? 0}',
                      style: TextStyle(
                        color: GlobalStyle.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )).toList(),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(),
            ),
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
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: GlobalStyle.primaryColor,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
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
                backgroundColor: GlobalStyle.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text(
                'Ambil Pesanan',
                style: TextStyle(
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
                backgroundColor: GlobalStyle.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text(
                'Mulai Pengiriman',
                style: TextStyle(
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
                backgroundColor: GlobalStyle.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text(
                'Lihat Rute',
                style: TextStyle(
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
    return Scaffold(
      backgroundColor: const Color(0xffD6E6F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Detail Pengantaran',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(7.0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: GlobalStyle.primaryColor, width: 1.0),
            ),
            child: Icon(Icons.arrow_back_ios_new, color: GlobalStyle.primaryColor, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusIndicator(),
                const SizedBox(height: 16),
                _buildLocationCard(),
                _buildStoreInfoCard(),
                _buildCustomerInfoCard(),
                _buildItemsCard(),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: _buildActionButtons(),
      ),
    );
  }
}