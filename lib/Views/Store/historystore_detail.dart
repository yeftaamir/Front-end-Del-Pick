import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:lottie/lottie.dart';
import 'package:del_pick/Views/Component/order_status_card.dart';
import 'package:del_pick/Models/order.dart';
import 'package:del_pick/Models/item_model.dart';
import 'package:del_pick/Models/store.dart';
import 'package:del_pick/Models/tracking.dart';
import 'package:geotypes/geotypes.dart' as geotypes;
import 'package:audioplayers/audioplayers.dart';

import '../../Models/driver.dart';

class HistoryStoreDetailPage extends StatefulWidget {
  static const String route = '/Store/HistoryStoreDetail';
  final Map<String, dynamic> orderDetail;

  const HistoryStoreDetailPage({Key? key, required this.orderDetail})
      : super(key: key);

  @override
  _HistoryStoreDetailPageState createState() => _HistoryStoreDetailPageState();
}

class _HistoryStoreDetailPageState extends State<HistoryStoreDetailPage>
    with TickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();

  // For status tracking
  String _statusFromDriver = '';

  // Animation controllers
  late List<AnimationController> _cardControllers;
  late List<Animation<Offset>> _cardAnimations;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers for card sections - increased to 6 to include review card
    _cardControllers = List.generate(
      6, // Updated to 6 to match the number of cards being used (including review card)
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

    // Start animations sequentially
    Future.delayed(const Duration(milliseconds: 100), () {
      for (var controller in _cardControllers) {
        controller.forward();
      }
    });
  }

  @override
  void dispose() {
    for (var controller in _cardControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // Supporting function to play sound effects
  Future<void> _playSound(String assetPath) async {
    try {
      await _audioPlayer.play(AssetSource(assetPath));
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }
  }

  // Convert the current status to OrderStatus enum
  OrderStatus _getOrderStatus() {
    String? status = widget.orderDetail['status'] as String?;
    switch (status) {
      case 'assigned':
        return OrderStatus.driverAssigned;
      case 'picking_up':
        return OrderStatus.driverAtStore;
      case 'delivering':
        return OrderStatus.driverHeadingToCustomer;
      case 'completed':
        return OrderStatus.completed;
      case 'cancelled':
        return OrderStatus.cancelled;
      case 'processing':
        return OrderStatus.pending; // Show as pending when being processed
      case 'ready_for_pickup':
        return OrderStatus
            .driverHeadingToStore; // New status for ready to be picked up
      default:
        return OrderStatus.pending;
    }
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlobalStyle.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 12),
                  ),
                  child: const Text(
                    'Back to Home',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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

  void _showReadyForPickupDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Konfirmasi'),
          content: const Text(
              'Apakah pesanan sudah siap untuk diambil driver?'),
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
                  widget.orderDetail['status'] = 'ready_for_pickup';
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Pesanan siap untuk diambil')),
                );
              },
            ),
          ],
        );
      },
    );
  }

  // Create tracking model to pass to OrderStatusCard
  Tracking _createTracking() {
    // Create sample positions
    final storePosition = geotypes.Position(99.10379, 2.34479);
    final customerPosition = geotypes.Position(99.10179, 2.34279);
    final driverPosition = _statusFromDriver == 'delivering'
        ? geotypes.Position(99.10279, 2.34329) // Between store and customer
        : geotypes.Position(99.10329, 2.34429); // Near store

    return Tracking(
      orderId: widget.orderDetail['id'] ?? '',
      driver: widget.orderDetail['driverInfo'] != null
          ? Driver.fromJson(widget.orderDetail['driverInfo'])
          : Driver(
        id: '',
        name: 'Unknown',
        rating: 0.0,
        phoneNumber: 'Unknown',
        vehicleNumber: 'Unknown',
        email: 'Unknown',
      ),
      driverPosition: driverPosition,
      customerPosition: customerPosition,
      storePosition: storePosition,
      routeCoordinates: [
        storePosition,
        customerPosition,
      ],
      status: _getOrderStatus(),
      estimatedArrival: DateTime.now().add(const Duration(minutes: 15)),
      customStatusMessage: _getStatusMessage(_getOrderStatus()),
    );
  }

  String _getStatusMessage(OrderStatus status) {
    switch (status) {
      case OrderStatus.driverAssigned:
        return 'Driver telah ditugaskan ke pesanan Anda';
      case OrderStatus.driverHeadingToStore:
        return 'Pesanan siap untuk diambil driver';
      case OrderStatus.driverAtStore:
        return 'Driver sedang mengambil pesanan Anda';
      case OrderStatus.driverHeadingToCustomer:
        return 'Driver sedang dalam perjalanan mengantar pesanan Anda';
      case OrderStatus.driverArrived:
        return 'Driver telah tiba di lokasi Anda';
      case OrderStatus.completed:
        return 'Pesanan Anda telah selesai';
      case OrderStatus.cancelled:
        return 'Pesanan Anda dibatalkan';
      default:
        return 'Pesanan sedang diproses';
    }
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

  Widget _buildOrderStatusCard() {
    // Create OrderItem objects from the items in orderDetail
    final items = (widget.orderDetail['items'] as List? ?? []).map((item) =>
        Item(
          id: item['id'] ?? '',
          name: item['name'] ?? '',
          price: (item['price'] ?? 0).toDouble(),
          quantity: item['quantity'] ?? 1,
          imageUrl: item['image'] ?? '',
          isAvailable: true,
          status: 'available',
          description: item['description'] ?? '',
        )).toList();

    // Create Store object
    final store = StoreModel(
      name: widget.orderDetail['storeName'] ?? '',
      address: widget.orderDetail['storeAddress'] ?? '',
      openHours: '08:00 - 22:00',
      // Default value
      rating: 4.5,
      // Default value
      reviewCount: 0,
      phoneNumber: widget.orderDetail['storePhone'] ?? '',
    );

    // Create Order object
    final order = Order(
      id: widget.orderDetail['id'] ?? '',
      items: items,
      store: store,
      deliveryAddress: widget.orderDetail['customerAddress'] ?? '',
      subtotal: ((widget.orderDetail['amount'] ?? 0) -
          (widget.orderDetail['deliveryFee'] ?? 0)).toDouble(),
      serviceCharge: (widget.orderDetail['deliveryFee'] ?? 0).toDouble(),
      total: (widget.orderDetail['amount'] ?? 0).toDouble(),
      orderDate: DateTime.now(),
      status: _getOrderStatus(),
      tracking: _createTracking(),
    );

    return OrderStatusCard(
      order: order,
      animation: _cardAnimations[0],
    );
  }

  Widget _buildDriverInfoCard() {
    final driverInfo = widget.orderDetail['driverInfo'] as Map<String,
        dynamic>?;

    // Show driver info based on status
    final currentStatus = widget.orderDetail['status'] as String? ?? 'pending';

    // Only show driver info if we have driver info and status is appropriate
    if (driverInfo == null || (currentStatus != 'ready_for_pickup' &&
        currentStatus != 'picked_up' &&
        _statusFromDriver != 'delivering')) {
      return const SizedBox.shrink();
    }

    return _buildCard(
      index: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.drive_eta, color: GlobalStyle.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Informasi Driver',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
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
                        'Driver: ${driverInfo['name'] ?? ''}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: GlobalStyle.fontColor,
                          fontFamily: GlobalStyle.fontFamily,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Vehicle Number: ${driverInfo['vehicle'] ?? ''}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontFamily: GlobalStyle.fontFamily,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chat),
                  onPressed: () =>
                      _openWhatsApp(
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
                Text(
                  'Informasi Customer',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: GlobalStyle.fontFamily,
                    color: GlobalStyle.fontColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: ClipOval(
                    child: Center(
                      child: Icon(
                        Icons.person,
                        size: 30,
                        color: Colors.grey[400],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.orderDetail['customerName']?.toString() ?? '',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: GlobalStyle.fontColor,
                          fontFamily: GlobalStyle.fontFamily,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.grey[600],
                              size: 16),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              widget.orderDetail['customerAddress']
                                  ?.toString() ?? '',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.call, color: Colors.white),
                    label: const Text(
                      'Hubungi',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GlobalStyle.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      _callCustomer(
                          widget.orderDetail['customerPhone']?.toString());
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.message, color: Colors.white),
                    label: const Text(
                      'Pesan',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[600],
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      _openWhatsApp(
                        widget.orderDetail['customerPhone']?.toString(),
                        isDriver: false,
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreInfoCard() {
    return _buildCard(
      index: 3, // Changed from 4 to 3 to maintain proper sequence
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.store, color: GlobalStyle.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Informasi Toko',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: GlobalStyle.fontFamily,
                    color: GlobalStyle.fontColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: ClipOval(
                    child: Center(
                      child: Icon(
                        Icons.store,
                        size: 30,
                        color: Colors.grey[400],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.orderDetail['storeName']?.toString() ?? '',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: GlobalStyle.fontColor,
                          fontFamily: GlobalStyle.fontFamily,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.grey[600],
                              size: 16),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              widget.orderDetail['storeAddress']?.toString() ??
                                  '',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '4.8',
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w500,
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
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.call, color: Colors.white),
                    label: const Text(
                      'Hubungi',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GlobalStyle.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      _callStore(widget.orderDetail['storePhone']?.toString());
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.message, color: Colors.white),
                    label: const Text(
                      'Pesan',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[600],
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      _openWhatsApp(
                        widget.orderDetail['storePhone']?.toString(),
                        isStore: true,
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Add these methods to handle calls and WhatsApp messages
  Future<void> _callCustomer(String? phoneNumber) async {
    if (phoneNumber == null) return;

    String url = 'tel:$phoneNumber';

    if (await canLaunch(url)) {
      await launch(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak dapat melakukan panggilan')),
        );
      }
    }
  }

  Future<void> _callStore(String? phoneNumber) async {
    if (phoneNumber == null) return;

    String url = 'tel:$phoneNumber';

    if (await canLaunch(url)) {
      await launch(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak dapat melakukan panggilan')),
        );
      }
    }
  }

  Future<void> _openWhatsApp(String? phoneNumber,
      {bool isDriver = false, bool isStore = false}) async {
    if (phoneNumber == null) return;

    String message = '';
    if (isDriver) {
      message = 'Halo, saya dari toko mengenai pesanan yang akan diambil...';
    } else if (isStore) {
      message = 'Halo, saya ingin bertanya mengenai toko Anda...';
    } else {
      message = 'Halo, saya dari toko mengenai pesanan Anda...';
    }

    String url = 'https://wa.me/$phoneNumber?text=${Uri.encodeComponent(
        message)}';

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

  // Update the _buildPaymentRow method to use the Rupiah format
  Widget _buildPaymentRow(String label, double amount, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            fontSize: isTotal ? 16 : 14,
          ),
        ),
        Text(
          GlobalStyle.formatRupiah(amount),
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            fontSize: isTotal ? 16 : 14,
            color: isTotal ? GlobalStyle.primaryColor : Colors.black,
          ),
        ),
      ],
    );
  }

  // Update the item price display in _buildItemsCard
  Widget _buildItemsCard() {
    final items = widget.orderDetail['items'] as List?;
    final totalAmount = double.tryParse(
        widget.orderDetail['amount']?.toString() ?? '0') ?? 0;
    final deliveryFee = double.tryParse(
        widget.orderDetail['deliveryFee']?.toString() ?? '0') ?? 0;

    if (items == null) {
      return const SizedBox.shrink();
    }

    return _buildCard(
      index: 4, // Changed from 3 to 4 to maintain proper sequence
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shopping_bag, color: GlobalStyle.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Detail Pesanan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...items.map((item) =>
                Container(
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
                          item['image']?.toString() ?? '',
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 60,
                              height: 60,
                              color: Colors.grey[300],
                              child: const Icon(Icons.error),
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
                              item['name']?.toString() ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              GlobalStyle.formatRupiah(double.tryParse(
                                  item['price']?.toString() ?? '0') ?? 0),
                              style: TextStyle(
                                color: GlobalStyle.primaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: GlobalStyle.lightColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'x${item['quantity']?.toString() ?? '0'}',
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

            _buildPaymentRow('Subtotal', totalAmount - deliveryFee),
            const SizedBox(height: 8),
            _buildPaymentRow('Biaya Layanan', deliveryFee),
            const SizedBox(height: 8),
            _buildPaymentRow('Total Pembayaran', totalAmount, isTotal: true),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreReviewCard() {
    // Check if review data exists and order is completed
    final reviewData = widget.orderDetail['review'] as Map<String, dynamic>?;
    final isCompleted = widget.orderDetail['status'] == 'completed';

    // Don't show review card if order is not completed or there's no review
    if (!isCompleted || reviewData == null) {
      return const SizedBox.shrink();
    }

    final double rating = (reviewData['rating'] as num?)?.toDouble() ?? 0.0;
    final String reviewText = reviewData['comment']?.toString() ?? '';

    return _buildCard(
      index: 4, // Adjust index as needed based on your card sequence
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: GlobalStyle.borderColor.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, color: Colors.amber),
                  const SizedBox(width: 10),
                  Text(
                    'Ulasan Pelanggan',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade800,
                      fontFamily: GlobalStyle.fontFamily,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                      Icons.person, color: Colors.amber, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.orderDetail['customerName']?.toString() ??
                            'Pelanggan',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Order #${widget.orderDetail['id']
                            ?.toString()
                            .substring(0, 8) ?? ''}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Rating',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: GlobalStyle.fontColor,
                fontFamily: GlobalStyle.fontFamily,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: GlobalStyle.lightColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: GlobalStyle.primaryColor.withOpacity(0.1),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      index < rating ? Icons.star : Icons.star_border,
                      color: index < rating ? Colors.amber : Colors.grey[400],
                      size: 40,
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Komentar',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: GlobalStyle.fontColor,
                fontFamily: GlobalStyle.fontFamily,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: GlobalStyle.borderColor.withOpacity(0.3),
                ),
              ),
              child: Text(
                reviewText.isEmpty ? 'Tidak ada komentar' : reviewText,
                style: TextStyle(
                  color: Colors.grey[800],
                  fontFamily: GlobalStyle.fontFamily,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    // Get current status from order detail
    String status = widget.orderDetail['status'] as String? ?? 'pending';

    switch (status) {
      case 'pending':
        return Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    widget.orderDetail['status'] = 'rejected';
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Pesanan Dibatalkan')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text(
                  'Batalkan Pesanan',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _showConfirmationDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlobalStyle.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text(
                  'Ambil Pesanan',
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
      // When order is being processed, show button to indicate it's ready for pickup
        return Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _showReadyForPickupDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text(
                  'Siap Di Ambil Driver',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      case 'ready_for_pickup':
      // Order is ready for pickup, waiting for driver
        return Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: null, // Disabled button - waiting for driver
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  disabledBackgroundColor: Colors.orange.withOpacity(0.6),
                  disabledForegroundColor: Colors.white,
                ),
                child: const Text(
                  'Menunggu Driver',
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
      // Show different states based on driver's status
        if (_statusFromDriver == 'delivering') {
          return Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: null, // Disabled button - waiting for delivery
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    disabledBackgroundColor: Colors.blue.withOpacity(0.6),
                    disabledForegroundColor: Colors.white,
                  ),
                  child: const Text(
                    'Dalam Pengantaran',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          );
        } else {
          // Driver is picking up
          return Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // Simulate driver picking up and starting delivery
                    setState(() {
                      _statusFromDriver = 'delivering';
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Driver Sedang Mengantar')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    'Konfirmasi Di Ambil Driver',
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
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffD6E6F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Detail Pesanan',
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
            child: Icon(
                Icons.arrow_back_ios_new, color: GlobalStyle.primaryColor,
                size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOrderStatusCard(),
                _buildDriverInfoCard(),
                _buildStoreReviewCard(), // Add the new review card here
                _buildStoreInfoCard(),
                _buildCustomerInfoCard(),
                _buildItemsCard(),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: widget.orderDetail['status'] == 'completed' ||
          widget.orderDetail['status'] == 'rejected'
          ? null
          : Container(
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