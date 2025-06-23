import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:lottie/lottie.dart';
import 'package:del_pick/Models/order.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:del_pick/Models/order_enum.dart';
import 'package:del_pick/Models/customer.dart';
import 'package:del_pick/Models/store.dart';
import 'package:del_pick/Models/menu_item.dart';
import 'package:del_pick/Models/order_item.dart';

// Services
import 'package:del_pick/Services/order_service.dart';
import 'package:del_pick/Services/driver_service.dart';
import 'package:del_pick/Services/tracking_service.dart';
import 'package:del_pick/Services/image_service.dart';
import 'package:del_pick/Services/customer_service.dart';
import 'package:del_pick/Services/store_service.dart';
import 'package:del_pick/Services/auth_service.dart';
import 'package:del_pick/Services/menu_service.dart';

import '../Component/driver_order_status.dart';

class HistoryDriverDetailPage extends StatefulWidget {
  static const String route = '/Driver/HistoryDriverDetail';
  final String? orderId;
  final Map<String, dynamic>? orderDetail;
  final bool showTrackButton;
  final VoidCallback? onTrackPressed;

  const HistoryDriverDetailPage({
    Key? key,
    this.orderId,
    this.orderDetail,
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

  // Order data
  late String _orderId;
  OrderModel? _orderData;
  CustomerModel? _customerData;
  StoreModel? _storeData;
  List<MenuItemModel> _menuItems = [];
  List<OrderItemModel> _orderItems = [];
  bool _isLoading = true;
  bool _isFetchingStatus = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    // Initialize orderId
    _orderId = widget.orderId ?? widget.orderDetail?['id']?.toString() ?? '';

    // Initialize card animation controllers
    _cardControllers = List.generate(
      4, // Four card sections
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

    // Load data
    _fetchOrderData();

    // Start animations sequentially
    Future.delayed(const Duration(milliseconds: 100), () {
      for (var i = 0; i < _cardControllers.length; i++) {
        Future.delayed(Duration(milliseconds: 100 * i), () {
          if (mounted) {
            _cardControllers[i].forward();
          }
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

  // Fetch order data using proper services
  Future<void> _fetchOrderData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      if (_orderId.isEmpty) {
        throw Exception('Order ID tidak tersedia');
      }

      // 1. Get order details using OrderService.getOrderById
      final orderData = await OrderService.getOrderById(_orderId);
      _orderData = OrderModel.fromJson(orderData);

      // 2. Get customer details if customerId available
      if (_orderData!.customerId > 0) {
        try {
          final customerData = await CustomerService.getCustomerById(_orderData!.customerId.toString());
          _customerData = CustomerModel.fromJson(customerData);
        } catch (e) {
          print('Error fetching customer data: $e');
          // Continue without customer data
        }
      }

      // 3. Get store details if storeId available
      if (_orderData!.storeId > 0) {
        try {
          final storeData = await StoreService.getStoreById(_orderData!.storeId.toString());
          _storeData = StoreModel.fromJson(storeData);
        } catch (e) {
          print('Error fetching store data: $e');
          // Continue without store data
        }
      }

      // 4. Get menu items from store
      if (_orderData!.storeId > 0) {
        try {
          final menuResponse = await MenuItemService.getMenuItemsByStore(
            storeId: _orderData!.storeId.toString(),
          );
          if (menuResponse['data'] != null) {
            _menuItems = (menuResponse['data'] as List)
                .map((item) => MenuItemModel.fromJson(item))
                .toList();
          }
        } catch (e) {
          print('Error fetching menu items: $e');
          // Continue without menu items
        }
      }

      // 5. Process order items from the order data
      _orderItems = _orderData!.items;

      setState(() {
        _isLoading = false;
      });

    } catch (e) {
      print('Error fetching order data: $e');
      setState(() {
        _errorMessage = 'Gagal memuat data pesanan: $e';
        _isLoading = false;
      });
    }
  }

  // Update order status using OrderService.updateOrderStatus
  Future<void> _updateOrderStatus(String status) async {
    if (_isFetchingStatus) return;

    setState(() {
      _isFetchingStatus = true;
    });

    try {
      // Use OrderService.updateOrderStatus
      await OrderService.updateOrderStatus(
        orderId: _orderId,
        status: status,
        notes: 'Status updated by driver',
      );

      // Play sound
      _playSound('audio/alert.wav');

      // Refresh order data
      await _fetchOrderData();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status berhasil diperbarui ke: ${_getStatusDisplayName(status)}'),
          ),
        );
      }
    } catch (e) {
      print('Error updating order status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memperbarui status: $e')),
        );
      }
    } finally {
      setState(() {
        _isFetchingStatus = false;
      });
    }
  }

  // Start delivery using TrackingService.startDelivery
  Future<void> _startDelivery() async {
    try {
      await TrackingService.startDelivery(_orderId);
      await _updateOrderStatus('on_delivery');
    } catch (e) {
      print('Error starting delivery: $e');
      // Fallback to just updating status
      await _updateOrderStatus('on_delivery');
    }
  }

  // Complete delivery using TrackingService.completeDelivery
  Future<void> _completeDelivery() async {
    try {
      await TrackingService.completeDelivery(_orderId);
      await _updateOrderStatus('delivered');
      _showCompletionDialog();
    } catch (e) {
      print('Error completing delivery: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyelesaikan pengantaran: $e')),
      );
    }
  }

  // Helper to get display name for status
  String _getStatusDisplayName(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Menunggu Konfirmasi';
      case 'confirmed':
        return 'Dikonfirmasi';
      case 'preparing':
        return 'Sedang Disiapkan';
      case 'ready_for_pickup':
        return 'Siap Diambil';
      case 'picked_up':
        return 'Sudah Diambil';
      case 'on_delivery':
        return 'Dalam Pengantaran';
      case 'delivered':
        return 'Sudah Diantar';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return status;
    }
  }

  // Play sound effect
  Future<void> _playSound(String assetPath) async {
    try {
      await _audioPlayer.play(AssetSource(assetPath));
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }
  }

  void _showCompletionDialog() {
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
                Text(
                  'Pengantaran Selesai!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: GlobalStyle.fontFamily,
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
                    'Kembali ke Beranda',
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
                  Icons.shopping_bag,
                  color: GlobalStyle.primaryColor,
                  size: 60,
                ),
                const SizedBox(height: 16),
                Text(
                  'Ambil Pesanan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Apakah Anda yakin sudah mengambil pesanan dari toko?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
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
                        Navigator.of(context).pop();
                        _updateOrderStatus('picked_up');
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
                        'Ya, Sudah Diambil',
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

  void _showDeliveryConfirmationDialog() {
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
                  Icons.check_circle_outline,
                  color: Colors.green,
                  size: 60,
                ),
                const SizedBox(height: 16),
                Text(
                  'Selesaikan Pengantaran?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Pastikan pelanggan telah menerima pesanan dengan baik',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: const Text(
                        'Belum',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _completeDelivery();
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Ya, Selesai',
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

  Future<void> _openWhatsApp(String phoneNumber) async {
    String formattedPhone = phoneNumber;
    if (phoneNumber.startsWith('0')) {
      formattedPhone = '62${phoneNumber.substring(1)}';
    } else if (!phoneNumber.startsWith('+') && !phoneNumber.startsWith('62')) {
      formattedPhone = '62$phoneNumber';
    }

    String message = 'Halo, saya driver dari Del Pick mengenai pesanan #${_orderData?.id ?? _orderId}';
    String url = 'https://wa.me/$formattedPhone?text=${Uri.encodeComponent(message)}';

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
    if (_orderData == null) return const SizedBox.shrink();

    return DriverOrderStatusCard(
      orderId: _orderId,
      initialOrderData: {
        'id': _orderData!.id,
        'order_status': _orderData!.orderStatus.value,
        'delivery_status': _orderData!.deliveryStatus.value,
        'total_amount': _orderData!.totalAmount,
        'delivery_fee': _orderData!.deliveryFee,
        'delivery_address': _orderData!.deliveryAddress,
        'customer': _customerData?.toJson() ?? _orderData!.customer?.toJson(),
        'store': _storeData?.toJson() ?? _orderData!.store?.toJson(),
        'driver': _orderData!.driver?.toJson(),
        'order_items': _orderItems.map((item) => item.toJson()).toList(),
        'created_at': _orderData!.createdAt.toIso8601String(),
        'updated_at': _orderData!.updatedAt.toIso8601String(),
      },
      animation: _cardAnimations[0],
    );
  }

  Widget _buildStoreInfoCard() {
    final store = _storeData ?? _orderData?.store;
    if (store == null) return const SizedBox.shrink();

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
                  child: ImageService.displayImage(
                    imageSource: store.imageUrl ?? '',
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    placeholder: Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey[300],
                      child: Icon(Icons.store, color: Colors.grey[600], size: 20),
                    ),
                    errorWidget: Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey[300],
                      child: Icon(Icons.store, color: Colors.grey[600], size: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        store.name,
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
                          Icon(Icons.location_on, color: Colors.grey[600], size: 16),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              store.address,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                                fontFamily: GlobalStyle.fontFamily,
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
                            store.rating.toString(),
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                              fontFamily: GlobalStyle.fontFamily,
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
                      'Hubungi Toko',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GlobalStyle.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => _openWhatsApp(store.phone),
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
    final customer = _customerData ?? _orderData?.customer;
    if (customer == null) return const SizedBox.shrink();

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
                ClipOval(
                  child: ImageService.displayImage(
                    imageSource: customer.avatar ?? '',
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    placeholder: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Icon(Icons.person, size: 30, color: Colors.grey[400]),
                    ),
                    errorWidget: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Icon(Icons.person, size: 30, color: Colors.grey[400]),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.name,
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
                          Icon(Icons.location_on, color: Colors.grey[600], size: 16),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _orderData?.deliveryAddress ?? 'Alamat tidak tersedia',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                                fontFamily: GlobalStyle.fontFamily,
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
                            customer.phone,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                              fontFamily: GlobalStyle.fontFamily,
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
                      'Hubungi Pelanggan',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GlobalStyle.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => _openWhatsApp(customer.phone),
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
    if (_orderItems.isEmpty) return const SizedBox.shrink();

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
            ..._orderItems.map((item) => Container(
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
                    child: ImageService.displayImage(
                      imageSource: item.imageUrl ?? '',
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      placeholder: Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey[300],
                        child: const Icon(Icons.image),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.formatPrice(),
                          style: TextStyle(
                            color: GlobalStyle.primaryColor,
                            fontWeight: FontWeight.w500,
                            fontFamily: GlobalStyle.fontFamily,
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
                      'x${item.quantity}',
                      style: TextStyle(
                        color: GlobalStyle.primaryColor,
                        fontWeight: FontWeight.w600,
                        fontFamily: GlobalStyle.fontFamily,
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
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
                Text(
                  _orderData?.formatDeliveryFee() ?? GlobalStyle.formatRupiah(0),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Biaya',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
                Text(
                  _orderData?.formatTotalAmount() ?? GlobalStyle.formatRupiah(0),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: GlobalStyle.primaryColor,
                    fontSize: 16,
                    fontFamily: GlobalStyle.fontFamily,
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
    if (_orderData == null || _isFetchingStatus) {
      return const Center(child: CircularProgressIndicator());
    }

    final status = _orderData!.orderStatus;

    // If order is completed or cancelled, don't show action buttons
    if (status.isCompleted) {
      return const SizedBox.shrink();
    }

    switch (status) {
      case OrderStatus.confirmed:
      case OrderStatus.preparing:
      case OrderStatus.readyForPickup:
        return ElevatedButton(
          onPressed: _showPickupConfirmationDialog,
          style: ElevatedButton.styleFrom(
            backgroundColor: GlobalStyle.primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          child: Text(
            'Ambil Pesanan',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
        );

      case OrderStatus.onDelivery:
        return Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => _startDelivery(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: Text(
                  'Mulai Antar',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _showDeliveryConfirmationDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: Text(
                  'Selesai',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: GlobalStyle.fontFamily,
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

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: GlobalStyle.primaryColor),
          const SizedBox(height: 16),
          Text(
            'Memuat data pesanan...',
            style: TextStyle(
              color: GlobalStyle.fontColor,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 60),
          const SizedBox(height: 16),
          Text(
            'Terjadi Kesalahan',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Gagal memuat data pesanan',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchOrderData,
            style: ElevatedButton.styleFrom(
              backgroundColor: GlobalStyle.primaryColor,
            ),
            child: const Text(
              'Coba Lagi',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffD6E6F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text(
          'Detail Pengantaran',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontFamily: GlobalStyle.fontFamily,
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
              Icons.arrow_back_ios_new,
              color: GlobalStyle.primaryColor,
              size: 18,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingIndicator()
            : _errorMessage != null
            ? _buildErrorWidget()
            : SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOrderStatusCard(),
                const SizedBox(height: 16),
                _buildItemsCard(),
                const SizedBox(height: 16),
                _buildStoreInfoCard(),
                const SizedBox(height: 16),
                _buildCustomerInfoCard(),
                const SizedBox(height: 80), // Space for action buttons
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _isLoading || _errorMessage != null
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