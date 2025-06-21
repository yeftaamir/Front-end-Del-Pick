import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Models/order.dart';
import 'package:del_pick/Models/order_item.dart';
import 'package:del_pick/Models/order_enum.dart';
import 'package:del_pick/Models/driver.dart';
import 'package:del_pick/Models/store.dart';
import 'package:del_pick/Views/Customers/rating_cust.dart';
import 'package:audioplayers/audioplayers.dart';

// Import required services based on documentation
import 'package:del_pick/Services/core/token_service.dart';
import 'package:del_pick/Services/location_service.dart';
import 'package:del_pick/Services/image_service.dart';
import 'package:del_pick/Services/menu_item_service.dart';
import 'package:del_pick/Services/order_service.dart';
import 'package:del_pick/Services/driver_service.dart';
import 'package:del_pick/Services/store_service.dart';

// Import rating components
import '../Component/rate_driver.dart';
import '../Component/rate_store.dart';
import '../Component/cust_order_status.dart';

class HistoryDetailScreen extends StatefulWidget {
  static const String route = "/Customers/HistoryDetail";

  final String orderId;
  final Order? initialOrder;

  const HistoryDetailScreen({
    Key? key,
    required this.orderId,
    this.initialOrder,
  }) : super(key: key);

  @override
  State<HistoryDetailScreen> createState() => _HistoryDetailScreenState();
}

class _HistoryDetailScreenState extends State<HistoryDetailScreen> with TickerProviderStateMixin {
  // Core data
  Order? _order;
  Driver? _assignedDriver;
  Store? _storeData;
  List<OrderItem> _orderItems = [];

  // State management
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;
  Timer? _statusUpdateTimer;
  bool _hasGivenRating = false;
  bool _canCancelOrder = false;
  String _driverName = "";
  String _vehicleNumber = "";

  // Rating state
  bool _showRatingSection = false;
  double _storeRating = 5.0;
  double _driverRating = 5.0;
  final TextEditingController _storeReviewController = TextEditingController();
  final TextEditingController _driverReviewController = TextEditingController();
  bool _isSubmittingRating = false;

  // Audio player
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Animation controllers
  late AnimationController _slideController;
  late AnimationController _driverCardController;
  late AnimationController _statusCardController;
  late AnimationController _pulseController;
  late List<AnimationController> _cardControllers;
  late List<Animation<Offset>> _cardAnimations;
  late Animation<Offset> _driverCardAnimation;
  late Animation<Offset> _statusCardAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeData();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _cardControllers = List.generate(
      6,
          (index) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 600 + (index * 200)),
      ),
    );

    _cardAnimations = _cardControllers.map((controller) {
      return Tween<Offset>(
        begin: const Offset(0, -0.5),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeOutCubic,
      ));
    }).toList();

    _driverCardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _statusCardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _driverCardAnimation = Tween<Offset>(
      begin: const Offset(0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _driverCardController,
      curve: Curves.easeOutCubic,
    ));

    _statusCardAnimation = Tween<Offset>(
      begin: const Offset(0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _statusCardController,
      curve: Curves.easeOutCubic,
    ));

    // Start animations
    Future.delayed(const Duration(milliseconds: 100), () {
      for (var controller in _cardControllers) {
        controller.forward();
      }
      _driverCardController.forward();
      _statusCardController.forward();
    });
  }

  void _initializeData() {
    if (widget.initialOrder != null) {
      _order = widget.initialOrder;
      _extractOrderInfo();
      _loadAdditionalData();
    } else {
      _loadOrderDetail();
    }
  }

  Future<void> _loadOrderDetail() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Load order detail using OrderService.getOrderById()
      final orderData = await OrderService.getOrderById(widget.orderId);

      if (orderData.isNotEmpty) {
        _order = Order.fromJson(orderData);
        _extractOrderInfo();
        await _loadAdditionalData();
        _checkOrderCapabilities();
        await _checkOrderRatingStatus();

        setState(() => _isLoading = false);
        await _playSound('audio/success.mp3');
        _startPeriodicStatusUpdate();
      } else {
        throw Exception('Order data is empty');
      }
    } catch (e) {
      print('Error loading order detail: $e');
      setState(() {
        _errorMessage = 'Failed to load order details: ${e.toString()}';
        _isLoading = false;
      });
      await _playSound('audio/wrong.mp3');
    }
  }

  Future<void> _loadAdditionalData() async {
    if (_order == null) return;

    try {
      // Load store data using StoreService.getStoreById()
      if (_order!.storeId != null) {
        final storeData = await StoreService.getStoreById(_order!.storeId.toString());
        if (storeData.isNotEmpty) {
          _storeData = Store.fromJson(storeData);
        }
      }

      // Load driver data using DriverService.getDriverById()
      if (_order!.driverId != null) {
        final driverData = await DriverService.getDriverById(_order!.driverId.toString());
        if (driverData.isNotEmpty) {
          _assignedDriver = Driver.fromJson(driverData);
          _driverName = _assignedDriver?.name ?? '';
          _vehicleNumber = _assignedDriver?.vehiclePlate ?? '';
        }
      }

      // Extract order items
      if (_order!.items != null) {
        _orderItems = _order!.items!;
      }

      setState(() {});
    } catch (e) {
      print('Error loading additional data: $e');
    }
  }

  Future<void> _refreshOrderData() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);

    try {
      final orderData = await OrderService.getOrderById(widget.orderId);
      if (orderData.isNotEmpty) {
        _order = Order.fromJson(orderData);
        _extractOrderInfo();
        await _loadAdditionalData();
        _checkOrderCapabilities();
      }
    } catch (e) {
      print('Error refreshing order data: $e');
      _showErrorSnackBar('Failed to refresh order data');
    } finally {
      setState(() => _isRefreshing = false);
    }
  }

  void _extractOrderInfo() {
    if (_order == null) return;

    // Extract driver information if available
    if (_order!.driver != null) {
      _driverName = _order!.driver!.name;
      _vehicleNumber = _order!.driver!.vehiclePlate;
    }
  }

  void _checkOrderCapabilities() {
    if (_order == null) return;

    setState(() {
      // Can cancel if order is pending or confirmed and not yet preparing
      _canCancelOrder = (_order!.orderStatus == OrderStatus.pending ||
          _order!.orderStatus == OrderStatus.confirmed) &&
          _order!.orderStatus != OrderStatus.preparing;
    });
  }

  Future<void> _checkOrderRatingStatus() async {
    if (_order == null) return;

    try {
      // Re-fetch order to check for reviews
      final orderData = await OrderService.getOrderById(_order!.id.toString());

      setState(() {
        bool hasReviews = false;

        // Check for any reviews in the order
        if (orderData['order_reviews'] != null && (orderData['order_reviews'] as List).isNotEmpty) {
          hasReviews = true;
        }
        if (orderData['driver_reviews'] != null && (orderData['driver_reviews'] as List).isNotEmpty) {
          hasReviews = true;
        }

        _hasGivenRating = hasReviews;
      });
    } catch (e) {
      print('Error checking rating status: $e');
      setState(() => _hasGivenRating = false);
    }
  }

  void _startPeriodicStatusUpdate() {
    _statusUpdateTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && _order != null && !_order!.orderStatus.isCompleted) {
        _refreshOrderData();
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _playSound(String assetPath) async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource(assetPath));
    } catch (e) {
      print('Error playing sound: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _cancelOrder() async {
    if (_order == null || !_canCancelOrder) return;

    final shouldCancel = await _showCancelConfirmationDialog();
    if (!shouldCancel) return;

    try {
      setState(() => _isLoading = true);

      // Use OrderService.cancelOrder()
      final result = await OrderService.cancelOrder(_order!.id.toString());

      if (result.isNotEmpty) {
        await _playSound('audio/success.mp3');
        _showSuccessSnackBar('Pesanan berhasil dibatalkan');
        await _refreshOrderData();
      } else {
        throw Exception('Failed to cancel order');
      }
    } catch (e) {
      print('Error cancelling order: $e');
      await _playSound('audio/wrong.mp3');
      _showErrorSnackBar('Gagal membatalkan pesanan: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _showCancelConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Batalkan Pesanan', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset('assets/animations/caution.json', height: 100, width: 100),
            const SizedBox(height: 16),
            const Text('Apakah Anda yakin ingin membatalkan pesanan ini?', textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Tidak', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _submitRating() async {
    if (_order == null || _assignedDriver == null || _storeData == null) return;

    setState(() => _isSubmittingRating = true);

    try {
      // Submit rating through OrderService
      final reviewData = {
        'order_id': _order!.id,
        'store_rating': _storeRating,
        'store_comment': _storeReviewController.text,
        'driver_rating': _driverRating,
        'driver_comment': _driverReviewController.text,
      };

      // This would call the appropriate review submission endpoint
      // await OrderService.submitReview(_order!.id.toString(), reviewData);

      setState(() {
        _hasGivenRating = true;
        _showRatingSection = false;
        _isSubmittingRating = false;
      });

      await _playSound('audio/success.mp3');
      _showSuccessSnackBar('Rating berhasil dikirim. Terima kasih!');
    } catch (e) {
      setState(() => _isSubmittingRating = false);
      await _playSound('audio/wrong.mp3');
      _showErrorSnackBar('Gagal mengirim rating: $e');
    }
  }

  double get subtotal {
    if (_order == null) return 0;
    return _order!.totalAmount - _order!.deliveryFee;
  }

  double get total {
    if (_order == null) return 0;
    return _order!.totalAmount;
  }

  String get formattedOrderDate {
    if (_order?.createdAt == null) return '';
    return DateFormat('dd MMM yyyy, hh.mm a').format(_order!.createdAt!);
  }

  Color _getStatusColor() {
    if (_order == null) return Colors.grey;

    switch (_order!.orderStatus) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.confirmed:
        return Colors.blue;
      case OrderStatus.preparing:
        return Colors.purple;
      case OrderStatus.ready_for_pickup:
        return Colors.teal;
      case OrderStatus.on_delivery:
        return Colors.green;
      case OrderStatus.delivered:
        return Colors.green;
      case OrderStatus.cancelled:
        return Colors.red;
    }
  }

  String _getStatusText() {
    if (_order == null) return 'Unknown';

    switch (_order!.orderStatus) {
      case OrderStatus.pending:
        return 'Menunggu';
      case OrderStatus.confirmed:
        return 'Dikonfirmasi';
      case OrderStatus.preparing:
        return 'Diproses';
      case OrderStatus.ready_for_pickup:
        return 'Siap Diambil';
      case OrderStatus.on_delivery:
        return 'Dalam Pengiriman';
      case OrderStatus.delivered:
        return 'Selesai';
      case OrderStatus.cancelled:
        return 'Dibatalkan';
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _driverCardController.dispose();
    _statusCardController.dispose();
    _pulseController.dispose();
    for (var controller in _cardControllers) {
      controller.dispose();
    }
    _audioPlayer.dispose();
    _statusUpdateTimer?.cancel();
    _storeReviewController.dispose();
    _driverReviewController.dispose();
    super.dispose();
  }

  Widget _buildDriverCard() {
    if (_assignedDriver == null) return const SizedBox.shrink();

    return SlideTransition(
      position: _driverCardAnimation,
      child: Container(
        padding: const EdgeInsets.all(20),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, GlobalStyle.primaryColor.withOpacity(0.05)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: GlobalStyle.primaryColor.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 2))],
          border: Border.all(color: GlobalStyle.primaryColor.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: GlobalStyle.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.delivery_dining, color: GlobalStyle.primaryColor, size: 24),
                ),
                const SizedBox(width: 12),
                Text('Informasi Driver', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: GlobalStyle.fontColor)),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: GlobalStyle.primaryColor.withOpacity(0.3), width: 3),
                  ),
                  child: _assignedDriver?.profileImageUrl != null
                      ? ClipOval(
                    child: ImageService.displayImage(
                      imageSource: _assignedDriver!.profileImageUrl!,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorWidget: Icon(Icons.person, size: 40, color: GlobalStyle.primaryColor),
                    ),
                  )
                      : ClipOval(
                    child: Container(
                      color: GlobalStyle.primaryColor.withOpacity(0.1),
                      child: Icon(Icons.person, size: 40, color: GlobalStyle.primaryColor),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_driverName.isNotEmpty ? _driverName : 'Driver', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (_assignedDriver?.rating != null && _assignedDriver!.rating > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star, color: Colors.amber, size: 16),
                              const SizedBox(width: 4),
                              Text('${_assignedDriver!.rating}', style: TextStyle(color: Colors.amber[800], fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                        ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(20)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.motorcycle, color: Colors.grey[700], size: 16),
                            const SizedBox(width: 4),
                            Text(_vehicleNumber.isNotEmpty ? _vehicleNumber : 'Unknown', style: TextStyle(color: Colors.grey[700], fontSize: 14, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.call, color: Colors.white, size: 18),
                    label: const Text('Hubungi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GlobalStyle.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    onPressed: () {},
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.message, color: Colors.white, size: 18),
                    label: const Text('Pesan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[700],
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderDateCard() {
    return _buildCard(
      index: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: GlobalStyle.primaryColor),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tanggal Pesanan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: GlobalStyle.fontColor)),
                const SizedBox(height: 4),
                Text(formattedOrderDate, style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItemsCard() {
    String storeName = _storeData?.name ?? 'Unknown Store';

    return _buildCard(
      index: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(Icons.restaurant_menu, color: GlobalStyle.primaryColor),
                const SizedBox(width: 8),
                Row(
                  children: [
                    Text(storeName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: GlobalStyle.fontColor)),
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: _getStatusColor().withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                      child: Text(_getStatusText(), style: TextStyle(fontSize: 12, color: _getStatusColor(), fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_orderItems.isNotEmpty)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _orderItems.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = _orderItems[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  leading: SizedBox(
                    width: 60,
                    height: 60,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: ImageService.displayImage(
                        imageSource: item.imageUrl ?? '',
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        placeholder: Container(color: Colors.grey[300], child: const Icon(Icons.image, color: Colors.white70)),
                        errorWidget: Container(color: Colors.grey[300], child: const Icon(Icons.image_not_supported, color: Colors.white70)),
                      ),
                    ),
                  ),
                  title: Text(item.name, style: TextStyle(fontWeight: FontWeight.bold, color: GlobalStyle.fontColor)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(GlobalStyle.formatRupiah(item.price), style: const TextStyle(color: Colors.grey)),
                      Text('Quantity: ${item.quantity}', style: const TextStyle(color: Colors.grey)),
                      if (item.notes != null && item.notes!.isNotEmpty)
                        Text('Catatan: ${item.notes}', style: TextStyle(color: Colors.grey[600], fontSize: 12, fontStyle: FontStyle.italic)),
                    ],
                  ),
                  trailing: Text(GlobalStyle.formatRupiah(item.totalPrice), style: TextStyle(fontWeight: FontWeight.bold, color: GlobalStyle.primaryColor)),
                );
              },
            )
          else
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('No items found', style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic)),
            ),
        ],
      ),
    );
  }

  Widget _buildDeliveryAddressCard() {
    // Get delivery address from order
    String deliveryAddress = 'Alamat tidak tersedia';
    if (_order != null) {
      // Try to get delivery address from order properties
      deliveryAddress = 'Alamat pengiriman'; // This should be from order model
    }

    return _buildCard(
      index: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: GlobalStyle.primaryColor),
                const SizedBox(width: 8),
                Text('Alamat Pengiriman', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: GlobalStyle.fontColor)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.home_rounded, color: GlobalStyle.primaryColor),
                  const SizedBox(width: 12),
                  Expanded(child: Text(deliveryAddress, style: TextStyle(color: GlobalStyle.fontColor))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentDetailsCard() {
    return _buildCard(
      index: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.payment, color: GlobalStyle.primaryColor),
                const SizedBox(width: 8),
                Text('Rincian Pembayaran', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: GlobalStyle.fontColor)),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  _buildPaymentRow('Subtotal', subtotal),
                  const SizedBox(height: 12),
                  _buildPaymentRow('Biaya Pengiriman', _order?.deliveryFee ?? 0),
                  const Divider(thickness: 1, height: 24),
                  _buildPaymentRow('Total', total, isTotal: true),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Expanded(child: Text('Pembayaran tunai saat pesanan tiba', style: TextStyle(fontSize: 12, color: Colors.blue[700], fontStyle: FontStyle.italic))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentRow(String label, double amount, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? GlobalStyle.fontColor : Colors.grey[700],
          ),
        ),
        Text(
          GlobalStyle.formatRupiah(amount),
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? GlobalStyle.primaryColor : GlobalStyle.fontColor,
          ),
        ),
      ],
    );
  }

  Widget _buildRatingSection() {
    return _buildCard(
      index: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star, color: Colors.amber),
                const SizedBox(width: 8),
                Text('Beri Rating', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: GlobalStyle.fontColor)),
              ],
            ),
            const SizedBox(height: 20),

            // Store Rating Section
            if (_storeData != null)
              RateStore(
                store: _storeData!,
                initialRating: _storeRating,
                onRatingChanged: (rating) => setState(() => _storeRating = rating),
                reviewController: _storeReviewController,
                isLoading: _isSubmittingRating,
              ),

            const SizedBox(height: 24),

            // Driver Rating Section
            if (_assignedDriver != null)
              RateDriver(
                driver: _assignedDriver!,
                initialRating: _driverRating,
                onRatingChanged: (rating) => setState(() => _driverRating = rating),
                reviewController: _driverReviewController,
                isLoading: _isSubmittingRating,
              ),

            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmittingRating ? null : _submitRating,
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlobalStyle.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  disabledBackgroundColor: Colors.grey[400],
                ),
                child: _isSubmittingRating
                    ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                    SizedBox(width: 12),
                    Text('Mengirim Rating...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                )
                    : const Text('Kirim Rating', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtonsCard() {
    bool showRatingButton = _order?.orderStatus == OrderStatus.delivered && !_hasGivenRating;
    bool showCancelButton = _canCancelOrder;

    if (!showRatingButton && !showCancelButton) return const SizedBox.shrink();

    return _buildCard(
      index: 5,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (showRatingButton) ...[
              ElevatedButton.icon(
                icon: const Icon(Icons.star),
                label: const Text("Beri Rating"),
                onPressed: () => setState(() => _showRatingSection = true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlobalStyle.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                  minimumSize: const Size(double.infinity, 54),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (showCancelButton) ...[
              ElevatedButton.icon(
                icon: const Icon(Icons.cancel_outlined),
                label: const Text("Batalkan Pesanan"),
                onPressed: _cancelOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                  minimumSize: const Size(double.infinity, 54),
                ),
              ),
              const SizedBox(height: 12),
            ],
            OutlinedButton.icon(
              icon: const Icon(Icons.shopping_bag),
              label: const Text("Pesan Lagi"),
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: GlobalStyle.primaryColor,
                side: BorderSide(color: GlobalStyle.primaryColor, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                minimumSize: const Size(double.infinity, 54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required int index, required Widget child}) {
    return SlideTransition(
      position: _cardAnimations[index < _cardAnimations.length ? index : 0],
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
        ),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF0F7FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text('Detail Pesanan', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
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
        actions: [
          IconButton(
            icon: _isRefreshing
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: GlobalStyle.primaryColor))
                : Icon(Icons.refresh, color: GlobalStyle.primaryColor),
            onPressed: _isRefreshing ? null : _refreshOrderData,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset('assets/animations/loading_animation.json', width: 150, height: 150),
            const SizedBox(height: 16),
            Text("Memuat Detail Pesanan...", style: TextStyle(color: GlobalStyle.primaryColor, fontWeight: FontWeight.w500, fontSize: 16)),
          ],
        ),
      )
          : _errorMessage != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset('assets/animations/error.json', width: 200, height: 200),
            const SizedBox(height: 16),
            Text("Gagal Memuat Data", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[700])),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[500], fontSize: 16)),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _loadOrderDetail,
              icon: const Icon(Icons.refresh),
              label: const Text("Coba Lagi"),
              style: ElevatedButton.styleFrom(
                backgroundColor: GlobalStyle.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _refreshOrderData,
        color: GlobalStyle.primaryColor,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Order status card
            if (_order != null)
              CustomerOrderStatusCard(
                orderData: {
                  'id': _order!.id,
                  'order_status': _order!.orderStatus.toString().split('.').last,
                  'total_amount': _order!.totalAmount,
                  'estimated_delivery_time': _order!.estimatedDeliveryTime?.toIso8601String() ?? DateTime.now().add(Duration(minutes: 30)).toIso8601String(),
                },
                animation: _cardAnimations[0],
              ),

            // Driver information (if available)
            if (_assignedDriver != null) _buildDriverCard(),

            // Order date
            _buildOrderDateCard(),

            // Order items
            _buildOrderItemsCard(),

            // Delivery address
            _buildDeliveryAddressCard(),

            // Payment details
            _buildPaymentDetailsCard(),

            // Rating section (appears when user clicks "Beri Rating")
            if (_showRatingSection && _assignedDriver != null && _storeData != null) _buildRatingSection(),

            // Action buttons
            _buildActionButtonsCard(),

            // Extra space at bottom
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}