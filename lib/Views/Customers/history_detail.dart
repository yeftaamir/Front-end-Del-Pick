import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Models/order.dart';
import 'package:del_pick/Models/order_item.dart';
import 'package:del_pick/Models/order_enum.dart';
import 'package:del_pick/Views/Customers/track_cust_order.dart';
import 'package:del_pick/Views/Customers/rating_cust.dart';
import 'package:audioplayers/audioplayers.dart';

// Import required services - UPDATED
import 'package:del_pick/Services/order_service.dart';
import 'package:del_pick/Services/image_service.dart';
import 'package:del_pick/Services/core/token_service.dart';

import '../Component/cust_order_status.dart';

class HistoryDetailScreen extends StatefulWidget {
  static const String route = "/Customers/HistoryDetail";

  final String orderId;
  final Order? initialOrder; // Optional initial order data

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
  Map<String, dynamic>? _orderDetailData;
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;
  Timer? _statusUpdateTimer;
  bool _hasGivenRating = false;

  // UI state
  bool _showTrackButton = false;
  bool _canCancelOrder = false;
  String _driverName = "";
  String _vehicleNumber = "";

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

    // Initialize with provided order if available
    if (widget.initialOrder != null) {
      _order = widget.initialOrder;
      _extractOrderInfo();
    }

    _initializeAnimations();
    _loadOrderDetail();
    _startPeriodicStatusUpdate();
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
    super.dispose();
  }

  // Initialize all animations
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
      5,
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

  // UPDATED: Load order detail using OrderService.getOrderById()
  Future<void> _loadOrderDetail() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // UPDATED: Use OrderService.getOrderById()
      final orderDetailData = await OrderService.getOrderById(widget.orderId);

      if (orderDetailData.isNotEmpty) {
        setState(() {
          _orderDetailData = orderDetailData;
          _order = Order.fromJson(orderDetailData);
          _extractOrderInfo();
          _checkOrderCapabilities();
          _checkOrderRatingStatus();
          _isLoading = false;
        });

        await _playSound('audio/success.mp3');
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

  // Refresh order data
  Future<void> _refreshOrderData() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      // UPDATED: Use OrderService.getOrderById()
      final orderDetailData = await OrderService.getOrderById(widget.orderId);

      if (orderDetailData.isNotEmpty) {
        setState(() {
          _orderDetailData = orderDetailData;
          _order = Order.fromJson(orderDetailData);
          _extractOrderInfo();
          _checkOrderCapabilities();
        });
      }
    } catch (e) {
      print('Error refreshing order data: $e');
      _showErrorSnackBar('Failed to refresh order data');
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  // Extract order information
  void _extractOrderInfo() {
    if (_order == null) return;

    // Extract driver information
    if (_order!.driver != null) {
      _driverName = _order!.driver!.name;
      _vehicleNumber = _order!.driver!.vehiclePlate;
    } else if (_orderDetailData != null && _orderDetailData!['driver'] != null) {
      final driverData = _orderDetailData!['driver'];
      _driverName = driverData['user']?['name'] ?? driverData['name'] ?? '';
      _vehicleNumber = driverData['vehicle_plate'] ?? '';
    }
  }

  // Check order capabilities (cancel, track, etc.)
  void _checkOrderCapabilities() {
    if (_order == null) return;

    setState(() {
      // Can cancel if order is pending or confirmed and not yet preparing
      _canCancelOrder = (_order!.orderStatus == OrderStatus.pending ||
          _order!.orderStatus == OrderStatus.confirmed) &&
          _order!.orderStatus != OrderStatus.preparing;

      // Show track button if on delivery
      _showTrackButton = _order!.orderStatus == OrderStatus.on_delivery ||
          _order!.deliveryStatus == DeliveryStatus.on_way;
    });
  }

  // UPDATED: Check if the order has already been rated using OrderService.getOrderById()
  Future<void> _checkOrderRatingStatus() async {
    if (_order == null) return;

    try {
      final orderDetails = await OrderService.getOrderById(_order!.id.toString());

      setState(() {
        bool hasReviews = false;

        // Check for order reviews
        if (orderDetails['orderReviews'] != null &&
            orderDetails['orderReviews'] is List &&
            (orderDetails['orderReviews'] as List).isNotEmpty) {
          hasReviews = true;
        }

        // Check for driver reviews
        if (orderDetails['driverReviews'] != null &&
            orderDetails['driverReviews'] is List &&
            (orderDetails['driverReviews'] as List).isNotEmpty) {
          hasReviews = true;
        }

        _hasGivenRating = hasReviews;
      });
    } catch (e) {
      print('Error checking order rating status: $e');
      setState(() {
        _hasGivenRating = false;
      });
    }
  }

  // Start periodic status updates
  void _startPeriodicStatusUpdate() {
    _statusUpdateTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && _order != null && !_order!.orderStatus.isCompleted) {
        _refreshOrderData();
      } else {
        timer.cancel();
      }
    });
  }

  // Play sound helper method
  Future<void> _playSound(String assetPath) async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource(assetPath));
    } catch (e) {
      print('Error playing sound: $e');
    }
  }

  // Show error snack bar
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

  // Show success snack bar
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

  // UPDATED: Cancel order using OrderService.cancelOrder()
  Future<void> _cancelOrder() async {
    if (_order == null || !_canCancelOrder) return;

    // Show confirmation dialog
    final shouldCancel = await _showCancelConfirmationDialog();
    if (!shouldCancel) return;

    try {
      setState(() {
        _isLoading = true;
      });

      // UPDATED: Use OrderService.cancelOrder()
      final success = await OrderService.cancelOrder(_order!.id.toString());

      if (success) {
        await _playSound('audio/success.mp3');
        _showSuccessSnackBar('Pesanan berhasil dibatalkan');

        // Refresh order data to get updated status
        await _refreshOrderData();
      } else {
        throw Exception('Failed to cancel order');
      }
    } catch (e) {
      print('Error cancelling order: $e');
      await _playSound('audio/wrong.mp3');
      _showErrorSnackBar('Gagal membatalkan pesanan: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Show cancel confirmation dialog
  Future<bool> _showCancelConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Batalkan Pesanan',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset(
              'assets/animations/caution.json',
              height: 100,
              width: 100,
            ),
            const SizedBox(height: 16),
            const Text(
              'Apakah Anda yakin ingin membatalkan pesanan ini?',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Tidak',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    ) ?? false;
  }

  // UPDATED: Handle rating using OrderService.createReview()
  Future<void> _handleRatingPress() async {
    if (_order == null) return;

    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RatingCustomerPage(
            order: _order!,
          ),
        ),
      );

      if (result != null && result is Map<String, dynamic>) {
        // UPDATED: Prepare review data structure for OrderService.createReview()
        final Map<String, dynamic> reviewData = {};

        // Add order review if provided
        if (result['storeRating'] != null) {
          reviewData['order_review'] = {
            'rating': result['storeRating'],
            'comment': result['storeComment'] ?? '',
          };
        }

        // Add driver review if provided
        if (result['driverRating'] != null) {
          reviewData['driver_review'] = {
            'rating': result['driverRating'],
            'comment': result['driverComment'] ?? '',
          };
        }

        // UPDATED: Submit the review using OrderService.createReview()
        final reviewResponse = await OrderService.createReview(_order!.id.toString(), reviewData);

        if (reviewResponse.isNotEmpty) {
          setState(() {
            _hasGivenRating = true;
          });

          await _playSound('audio/success.mp3');
          _showSuccessSnackBar('Rating berhasil dikirim. Terima kasih atas feedback Anda!');
        }
      }
    } catch (e) {
      print('Error submitting rating: $e');
      await _playSound('audio/wrong.mp3');
      _showErrorSnackBar('Gagal mengirim rating. Silakan coba lagi.');
    }
  }

  // Navigate to order tracking screen
  void _navigateToTrackOrder() {
    if (_order == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TrackCustOrderScreen(
          order: _order!,
        ),
      ),
    );
  }

  // Build driver card
  Widget _buildDriverCard() {
    if (_order?.driver == null && (_orderDetailData?['driver'] == null)) {
      return const SizedBox.shrink();
    }

    String driverImageUrl = '';
    double driverRating = 4.8;

    // Get driver info from order detail data
    if (_orderDetailData != null && _orderDetailData!['driver'] != null) {
      final driverData = _orderDetailData!['driver'];

      // Handle nested user data structure
      if (driverData['user'] != null) {
        driverImageUrl = driverData['user']['avatar'] ?? '';
        _driverName = driverData['user']['name'] ?? _driverName;
      }

      driverRating = (driverData['rating'] ?? 4.8).toDouble();
      _vehicleNumber = driverData['vehicle_plate'] ?? _vehicleNumber;
    } else if (_order?.driver != null) {
      driverImageUrl = _order!.driver!.user?.avatar ?? '';
      driverRating = _order!.driver!.rating;
    }

    return SlideTransition(
      position: _driverCardAnimation,
      child: Container(
        padding: const EdgeInsets.all(20),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              GlobalStyle.primaryColor.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: GlobalStyle.primaryColor.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
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
                  child: Icon(
                    Icons.delivery_dining,
                    color: GlobalStyle.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Informasi Driver',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: GlobalStyle.fontColor,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                // Driver Avatar
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: GlobalStyle.primaryColor.withOpacity(0.3),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: driverImageUrl.isNotEmpty
                      ? ClipOval(
                    child: ImageService.displayImage(
                      imageSource: driverImageUrl,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      placeholder: Center(
                        child: Icon(
                          Icons.person,
                          size: 30,
                          color: Colors.grey[400],
                        ),
                      ),
                      errorWidget: Center(
                        child: Icon(
                          Icons.person,
                          size: 30,
                          color: Colors.grey[400],
                        ),
                      ),
                    ),
                  )
                      : ClipOval(
                    child: Container(
                      color: GlobalStyle.primaryColor.withOpacity(0.1),
                      child: Icon(
                        Icons.person,
                        size: 40,
                        color: GlobalStyle.primaryColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _driverName.isNotEmpty ? _driverName : 'Driver',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: GlobalStyle.fontColor,
                                fontFamily: GlobalStyle.fontFamily,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.star, color: Colors.amber, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  driverRating.toString(),
                                  style: TextStyle(
                                    color: Colors.amber[800],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.motorcycle, color: Colors.grey[700], size: 16),
                            const SizedBox(width: 4),
                            Text(
                              _vehicleNumber.isNotEmpty ? _vehicleNumber : 'Unknown',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Driver Berpengalaman',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
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
                    label: const Text(
                      'Hubungi',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GlobalStyle.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      elevation: 2,
                    ),
                    onPressed: () {
                      // Phone call implementation
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.message, color: Colors.white, size: 18),
                    label: const Text(
                      'Pesan',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[700],
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      elevation: 2,
                    ),
                    onPressed: () {
                      // Messaging implementation
                    },
                  ),
                ),
              ],
            ),
            // Track order button when status is "on_delivery"
            if (_showTrackButton)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _navigateToTrackOrder,
                    icon: const Icon(Icons.location_on, color: Colors.white, size: 18),
                    label: const Text(
                      'Lacak Pesanan',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Build order items card
  Widget _buildOrderItemsCard() {
    if (_order == null) return const SizedBox.shrink();

    String storeName = 'Unknown Store';
    if (_orderDetailData != null && _orderDetailData!['store'] != null) {
      storeName = _orderDetailData!['store']['name'] ?? 'Unknown Store';
    } else if (_order!.store != null) {
      storeName = _order!.store!.name;
    }

    return _buildCard(
      index: 0,
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
                    Text(
                      storeName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: GlobalStyle.fontColor,
                        fontFamily: GlobalStyle.fontFamily,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getStatusColor().withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getStatusText(),
                        style: TextStyle(
                          fontSize: 12,
                          color: _getStatusColor(),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_order!.items != null && _order!.items!.isNotEmpty)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _order!.items!.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = _order!.items![index];
                return _buildOrderItemRow(item);
              },
            )
          else
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'No items found',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Build order item row
  Widget _buildOrderItemRow(OrderItem item) {
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
            placeholder: Container(
              color: Colors.grey[300],
              child: const Icon(Icons.image, color: Colors.white70),
            ),
            errorWidget: Container(
              color: Colors.grey[300],
              child: const Icon(Icons.image_not_supported, color: Colors.white70),
            ),
          ),
        ),
      ),
      title: Text(
        item.name,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: GlobalStyle.fontColor,
          fontFamily: GlobalStyle.fontFamily,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            GlobalStyle.formatRupiah(item.price),
            style: const TextStyle(color: Colors.grey),
          ),
          Text(
            'Quantity: ${item.quantity}',
            style: const TextStyle(color: Colors.grey),
          ),
          if (item.notes != null && item.notes!.isNotEmpty)
            Text(
              'Catatan: ${item.notes}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
      trailing: Text(
        GlobalStyle.formatRupiah(item.totalPrice),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: GlobalStyle.primaryColor,
          fontFamily: GlobalStyle.fontFamily,
        ),
      ),
    );
  }

  // Build delivery address card
  Widget _buildDeliveryAddressCard() {
    if (_order == null) return const SizedBox.shrink();

    // Get delivery address from order detail data
    String? deliveryAddress;
    if (_orderDetailData != null && _orderDetailData!['delivery_address'] != null) {
      deliveryAddress = _orderDetailData!['delivery_address'];
    }

    return _buildCard(
      index: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: GlobalStyle.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Alamat Pengiriman',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: GlobalStyle.fontColor,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
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
                  Icon(
                    Icons.home_rounded,
                    color: GlobalStyle.primaryColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      deliveryAddress ?? 'Alamat tidak tersedia',
                      style: TextStyle(
                        color: GlobalStyle.fontColor,
                        fontFamily: GlobalStyle.fontFamily,
                      ),
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

  // Build payment details card
  Widget _buildPaymentDetailsCard() {
    if (_order == null) return const SizedBox.shrink();

    double subtotal = _order!.totalAmount - _order!.deliveryFee;

    return _buildCard(
      index: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.payment, color: GlobalStyle.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Rincian Pembayaran',
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
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  _buildPaymentRow('Subtotal', subtotal),
                  const SizedBox(height: 12),
                  _buildPaymentRow('Biaya Pengiriman', _order!.deliveryFee),
                  const Divider(thickness: 1, height: 24),
                  _buildPaymentRow('Total', _order!.totalAmount, isTotal: true),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.blue[700],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pembayaran tunai saat pesanan tiba',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w500,
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

  // Build payment row
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
            fontFamily: GlobalStyle.fontFamily,
          ),
        ),
        Text(
          GlobalStyle.formatRupiah(amount),
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? GlobalStyle.primaryColor : GlobalStyle.fontColor,
            fontFamily: GlobalStyle.fontFamily,
          ),
        ),
      ],
    );
  }

  // Build order date card
  Widget _buildOrderDateCard() {
    if (_order == null || _order!.createdAt == null) return const SizedBox.shrink();

    String formattedOrderDate = DateFormat('dd MMM yyyy, hh.mm a')
        .format(_order!.createdAt!);

    return _buildCard(
      index: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: GlobalStyle.primaryColor),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tanggal Pesanan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: GlobalStyle.fontColor,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formattedOrderDate,
                  style: TextStyle(
                    color: Colors.grey[600],
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

  // Build action buttons card
  Widget _buildActionButtonsCard() {
    if (_order == null) return const SizedBox.shrink();

    bool showRatingButton = _order!.orderStatus == OrderStatus.delivered && !_hasGivenRating;
    bool showCancelButton = _canCancelOrder;

    if (!showRatingButton && !showCancelButton) {
      return const SizedBox.shrink();
    }

    return _buildCard(
      index: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (showRatingButton) ...[
              ElevatedButton.icon(
                icon: const Icon(Icons.star),
                label: const Text("Beri Rating"),
                onPressed: _handleRatingPress,
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlobalStyle.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                  minimumSize: const Size(double.infinity, 54),
                  elevation: 2,
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                  minimumSize: const Size(double.infinity, 54),
                  elevation: 2,
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                minimumSize: const Size(double.infinity, 54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods
  Widget _buildCard({required int index, required Widget child}) {
    return SlideTransition(
      position: _cardAnimations[index < _cardAnimations.length ? index : 0],
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: child,
      ),
    );
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF0F7FF),
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
            child: Icon(Icons.arrow_back_ios_new,
                color: GlobalStyle.primaryColor, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: _isRefreshing
                ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: GlobalStyle.primaryColor,
              ),
            )
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
            Lottie.asset(
              'assets/animations/loading_animation.json',
              width: 150,
              height: 150,
            ),
            const SizedBox(height: 16),
            Text(
              "Memuat Detail Pesanan...",
              style: TextStyle(
                color: GlobalStyle.primaryColor,
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
          ],
        ),
      )
          : _errorMessage != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/animations/error.json',
              width: 200,
              height: 200,
            ),
            const SizedBox(height: 16),
            Text(
              "Gagal Memuat Data",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _loadOrderDetail,
              icon: const Icon(Icons.refresh),
              label: const Text("Coba Lagi"),
              style: ElevatedButton.styleFrom(
                backgroundColor: GlobalStyle.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
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
                  'estimated_delivery_time': _order!.estimatedDeliveryTime?.toIso8601String() ??
                      DateTime.now().add(Duration(minutes: 30)).toIso8601String(),
                },
                animation: _cardAnimations[0],
              ),

            // Driver information
            _buildDriverCard(),

            // Order date
            _buildOrderDateCard(),

            // Order items
            _buildOrderItemsCard(),

            // Delivery address
            _buildDeliveryAddressCard(),

            // Payment details
            _buildPaymentDetailsCard(),

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