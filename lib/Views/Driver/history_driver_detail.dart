import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Views/Driver/track_order.dart';
import 'package:lottie/lottie.dart';
import 'package:del_pick/Views/Component/order_status_card.dart';
import 'package:del_pick/Models/order.dart';
import 'package:del_pick/Models/tracking.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:del_pick/Models/item_model.dart';
import 'package:del_pick/Models/driver.dart';
import 'package:del_pick/Models/store.dart';
import 'package:del_pick/Models/position.dart';
import 'package:geotypes/geotypes.dart' as geotypes;

class HistoryDriverDetailPage extends StatefulWidget {
  static const String route = '/Driver/HistoryDriverDetail';
  final Map<String, dynamic> orderDetail;
  // Add these properties
  final bool showTrackButton;
  final VoidCallback? onTrackPressed;

  const HistoryDriverDetailPage({
    Key? key,
    required this.orderDetail,
    // Add default values for the new parameters
    this.showTrackButton = false,
    this.onTrackPressed,
  }) : super(key: key);

  @override
  _HistoryDriverDetailPageState createState() => _HistoryDriverDetailPageState();
}

class _HistoryDriverDetailPageState extends State<HistoryDriverDetailPage> with TickerProviderStateMixin {
  // Audio player initialization
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Animation controllers for card sections
  late List<AnimationController> _cardControllers;
  late List<Animation<Offset>> _cardAnimations;

  @override
  void initState() {
    super.initState();

    // Initialize card animation controllers
    _cardControllers = List.generate(
      4, // Updated number of card sections (including the review card)
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
      for (var i = 0; i < _cardControllers.length; i++) {
        Future.delayed(Duration(milliseconds: 100 * i), () {
          _cardControllers[i].forward();
        });
      }
    });
  }

  @override
  void dispose() {
    for (var controller in _cardControllers) {
      controller.dispose();
    }
    _audioPlayer.dispose();
    super.dispose();
  }

  // Play sound effect based on provided asset path
  Future<void> _playSound(String assetPath) async {
    try {
      await _audioPlayer.play(AssetSource(assetPath));
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }
  }

  void _showCompletionDialog() {
    // Play completion sound
    _playSound('audio/kring.mp3');

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
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/animations/pesanan_selesai.json',
                  width: 200,
                  height: 200,
                  repeat: true,
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 12),
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

  void _showCancelConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cancel_outlined,
                  color: Colors.red,
                  size: 60,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Batalkan Pengantaran?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Apakah Anda yakin ingin membatalkan pengantaran ini?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: const Text(
                        'Tidak',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        // Play sound
                        _playSound('audio/alert.wav');
                        setState(() {
                          widget.orderDetail['status'] = 'cancelled';
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text(
                              'Pengantaran dibatalkan')),
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Ya, Batalkan',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
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
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.shopping_basket,
                  color: GlobalStyle.primaryColor,
                  size: 60,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Ambil Pesanan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Apakah Anda yakin ingin mengambil pesanan ini?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: const Text(
                        'Batal',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // Play alert sound
                        _playSound('audio/alert.wav');
                        setState(() {
                          widget.orderDetail['status'] = 'picking_up';
                        });
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text(
                              'Pesanan sedang diambil')),
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        backgroundColor: GlobalStyle.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Ya, Ambil',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _navigateToTrackOrder() async {
    // Play alert sound when changing status
    _playSound('audio/alert.wav');

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TrackOrderScreen(),
      ),
    );

    if (result == 'completed') {
      setState(() {
        widget.orderDetail['status'] = 'completed';
      });
      _showCompletionDialog();
    }
  }

  Future<void> _openWhatsApp(String phoneNumber) async {
    String message = 'Halo, saya driver dari Del Pick mengenai pesanan Anda...';
    String url = 'https://wa.me/$phoneNumber?text=${Uri.encodeComponent(
        message)}';

    if (await canLaunchUrlString(url)) {
      await launchUrlString(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak dapat membuka WhatsApp')),
        );
      }
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
      default:
        return OrderStatus.pending;
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

  // Helper method to create a Tracking object
  Tracking _createTracking() {
    // Create sample driver
    final driver = Driver.sample();

    return Tracking(
      orderId: widget.orderDetail['id'] ?? '',
      driver: driver,
      driverPosition: geotypes.Position(99.10279, 2.34379),
      // Sample position
      customerPosition: geotypes.Position(99.10179, 2.34279),
      // Sample position
      storePosition: geotypes.Position(99.10379, 2.34479),
      // Sample position
      routeCoordinates: [
        geotypes.Position(99.10279, 2.34379), // Driver
        geotypes.Position(99.10379, 2.34479), // Store
        geotypes.Position(99.10179, 2.34279), // Customer
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
        return 'Driver sedang menuju ke toko';
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

  Widget _buildStoreInfoCard() {
    return _buildCard(
      index: 1,
      child: Container(
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
                    color: GlobalStyle.fontColor,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
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
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.store,
                            size: 30,
                            color: Colors.grey[400],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.orderDetail['storeName'] ?? 'Toko',
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
                              widget.orderDetail['storeAddress'] ?? '',
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
                      _openWhatsApp(widget.orderDetail['storePhone'] ?? '');
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
                      _openWhatsApp(widget.orderDetail['storePhone'] ?? '');
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

  Widget _buildCustomerInfoCard() {
    return _buildCard(
      index: 2,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: GlobalStyle.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Informasi Pelanggan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: GlobalStyle.fontColor,
                    fontFamily: GlobalStyle.fontFamily,
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
                        widget.orderDetail['customerName'] ?? 'Pelanggan',
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
                              widget.orderDetail['customerAddress'] ?? '',
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
                          Icon(Icons.phone, color: Colors.grey[600], size: 16),
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
                      _openWhatsApp(widget.orderDetail['customerPhone'] ?? '');
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
                      _openWhatsApp(widget.orderDetail['customerPhone'] ?? '');
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

  Widget _buildItemsCard() {
    final items = widget.orderDetail['items'] as List? ?? [];
    final totalAmount = (widget.orderDetail['amount'] as num?)?.toDouble() ??
        0.0;
    final deliveryFee = (widget.orderDetail['deliveryFee'] as num?)
        ?.toDouble() ?? 0.0;

    return _buildCard(
      index: 0,
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
                  'Item Pesanan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: GlobalStyle.fontColor,
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
                              GlobalStyle.formatRupiah(
                                  (item['price'] as num?)?.toDouble() ?? 0.0),
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
                  GlobalStyle.formatRupiah(deliveryFee),
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
                  GlobalStyle.formatRupiah(totalAmount),
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

  Widget _buildDriverReviewCard() {
    // Get review data from orderDetail, or use placeholder if not available
    final double rating = (widget.orderDetail['driverRating'] as num?)
        ?.toDouble() ?? 0.0;
    final String review = widget.orderDetail['driverReview'] as String? ?? '';

    return _buildCard(
      index: 0, // Use appropriate index based on your animation sequence
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.rate_review, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Ulasan Pelanggan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: GlobalStyle.fontColor,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                        Icons.person, color: Colors.orange, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.orderDetail['driverName'] ?? 'Driver',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.grey.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.directions_car, size: 14,
                                  color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                widget.orderDetail['vehicleNumber'] ??
                                    'BK 1234 XX',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
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
            const SizedBox(height: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rating dari Pelanggan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: GlobalStyle.fontColor,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
                const SizedBox(height: 16),
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
                          color: index < rating ? Colors.orange : Colors
                              .grey[400],
                          size: 40,
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 20),
                if (review.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: GlobalStyle.borderColor.withOpacity(0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: GlobalStyle.primaryColor.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.comment, color: Colors.orange),
                            const SizedBox(width: 8),
                            Text(
                              'Komentar Pelanggan',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: GlobalStyle.fontColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          review,
                          style: TextStyle(
                            color: GlobalStyle.fontColor,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (review.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Text(
                        'Belum ada ulasan tertulis dari pelanggan',
                        style: TextStyle(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
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
    OrderStatus status = _getOrderStatus();

    if (status == OrderStatus.driverAssigned) {
      return Row(
        children: [
          IconButton(
            icon: const Icon(Icons.cancel),
            onPressed: _showCancelConfirmationDialog,
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
    } else if (status == OrderStatus.driverAtStore) {
      return Row(
        children: [
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                _playSound('audio/alert.wav');
                setState(() {
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
    } else if (status == OrderStatus.driverHeadingToCustomer) {
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
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOrderStatusCard(),
                const SizedBox(height: 16),
                _buildItemsCard(),
                _buildStoreInfoCard(),
                _buildCustomerInfoCard(),
                // Only show the review card if order is completed
                if (_getOrderStatus() == OrderStatus.completed)
                  Column(
                    children: [
                      const SizedBox(height: 16),
                      _buildDriverReviewCard(),
                    ],
                  ),
                // Add the track button
                if (_getOrderStatus() == OrderStatus.driverHeadingToCustomer)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _navigateToTrackOrder,
                        icon: const Icon(
                            Icons.location_on, color: Colors.white, size: 18),
                        label: const Text(
                          'Lacak Pesanan',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GlobalStyle.primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
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