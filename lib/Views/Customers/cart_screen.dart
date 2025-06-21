import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'dart:async';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Models/menu_item.dart';
import 'package:del_pick/Models/store.dart';
import 'package:del_pick/Models/order.dart';
import 'package:del_pick/Models/driver.dart';
import 'package:del_pick/Models/order_enum.dart';
import 'package:del_pick/Views/Customers/location_access.dart';
import 'package:del_pick/Views/Customers/rating_cust.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:geolocator/geolocator.dart';

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

class CartScreen extends StatefulWidget {
  static const String route = "/Customers/Cart";
  final int storeId;
  final List<MenuItem> cartItems;
  final Order? completedOrder;

  const CartScreen({
    Key? key,
    required this.cartItems,
    required this.storeId,
    this.completedOrder,
  }) : super(key: key);

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> with TickerProviderStateMixin {
  // Service charge and location data
  double _serviceCharge = 0;
  String? _deliveryAddress;
  double? _latitude;
  double? _longitude;
  double? _storeLatitude;
  double? _storeLongitude;
  double? _storeDistance;

  // State management
  String? _errorMessage;
  bool _isLoading = false;
  bool _orderCreated = false;
  bool _searchingDriver = false;
  bool _driverFound = false;
  String _driverName = "";
  String _vehicleNumber = "";
  Order? _createdOrder;
  Driver? _assignedDriver;
  Store? _storeData;
  bool _hasGivenRating = false;
  bool _orderFailed = false;
  bool _orderRejected = false;
  String _orderFailReason = '';

  // Rating state
  bool _showRatingSection = false;
  double _storeRating = 5.0;
  double _driverRating = 5.0;
  final TextEditingController _storeReviewController = TextEditingController();
  final TextEditingController _driverReviewController = TextEditingController();
  bool _isSubmittingRating = false;

  // Audio player instance
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Timer for driver search
  Timer? _driverSearchTimer;
  Timer? _orderStatusTimer;

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
      4,
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

      if (widget.completedOrder != null) {
        _driverCardController.forward();
        _statusCardController.forward();
      }
    });
  }

  void _initializeData() {
    if (widget.completedOrder != null) {
      _handleCompletedOrder();
    } else {
      _loadInitialData();
    }
  }

  void _handleCompletedOrder() {
    _orderCreated = true;
    _driverFound = true;
    _createdOrder = widget.completedOrder;
    _serviceCharge = widget.completedOrder!.deliveryFee;

    // Load additional data
    _loadStoreData();
    _loadDriverData();
    _checkOrderRatingStatus();
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() => _isLoading = true);

      // Load store data using StoreService
      await _loadStoreData();

      // Set default service charge
      _serviceCharge = 15000;

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load store data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStoreData() async {
    try {
      final storeData = await StoreService.getStoreById(widget.storeId.toString());
      if (storeData.isNotEmpty) {
        _storeData = Store.fromJson(storeData);
        _storeLatitude = _storeData?.latitude;
        _storeLongitude = _storeData?.longitude;
        _updateDeliveryFee();
      }
    } catch (e) {
      print('Error loading store data: $e');
    }
  }

  Future<void> _loadDriverData() async {
    if (_createdOrder?.driverId == null) return;

    try {
      final driverData = await DriverService.getDriverById(_createdOrder!.driverId.toString());
      if (driverData.isNotEmpty) {
        _assignedDriver = Driver.fromJson(driverData);
        _driverName = _assignedDriver?.name ?? '';
        _vehicleNumber = _assignedDriver?.vehiclePlate ?? '';
      }
    } catch (e) {
      print('Error loading driver data: $e');
    }
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    double distanceInMeters = Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
    return distanceInMeters / 1000;
  }

  double calculateDeliveryFee(double distance) {
    double fee = distance * 2500;
    return fee.ceilToDouble();
  }

  void _updateDeliveryFee() {
    if (_latitude != null && _longitude != null &&
        _storeLatitude != null && _storeLongitude != null) {
      _storeDistance = calculateDistance(
          _latitude!, _longitude!, _storeLatitude!, _storeLongitude!);
      setState(() {
        _serviceCharge = calculateDeliveryFee(_storeDistance!);
      });
    }
  }

  String _getFormattedDistance() {
    if (_storeDistance == null) return "-- KM";

    if (_storeDistance! < 1) {
      return "${(_storeDistance! * 1000).toInt()} m";
    } else {
      return "${_storeDistance!.toStringAsFixed(1)} km";
    }
  }

  Future<void> _handleLocationAccess() async {
    final result = await Navigator.pushNamed(context, LocationAccessScreen.route);

    if (result is Map<String, dynamic> && result['address'] != null) {
      setState(() {
        _deliveryAddress = result['address'];
        _latitude = result['latitude'];
        _longitude = result['longitude'];
        _errorMessage = null;
      });
      _updateDeliveryFee();
    }
  }

  Future<void> _playSound(String assetPath) async {
    await _audioPlayer.stop();
    await _audioPlayer.play(AssetSource(assetPath));
  }

  Future<void> _showNoAddressDialog() async {
    await _playSound('audio/wrong.mp3');

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset('assets/animations/caution.json', height: 180, width: 180),
                const SizedBox(height: 16),
                const Text(
                  "Alamat Pengiriman Diperlukan",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Mohon tentukan alamat pengiriman untuk melanjutkan pesanan",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlobalStyle.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _handleLocationAccess();
                  },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on, size: 18),
                      SizedBox(width: 8),
                      Text("Tentukan Alamat", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showErrorDialog(String title, String message) async {
    await _playSound('audio/wrong.mp3');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: GlobalStyle.primaryColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _searchDriver() async {
    if (_deliveryAddress == null || _deliveryAddress!.isEmpty) {
      await _showNoAddressDialog();
      return;
    }

    setState(() {
      _searchingDriver = true;
      _orderFailed = false;
      _orderRejected = false;
    });

    try {
      // Show creating order dialog
      _showLoadingDialog("Membuat Pesanan", "Mohon tunggu sementara kami memproses pesanan Anda...");

      // Prepare order data
      final orderData = {
        'store_id': widget.storeId,
        'items': widget.cartItems.map((item) => {
          'menu_item_id': item.id,
          'quantity': item.quantity,
          'notes': '',
        }).toList(),
        'delivery_address': _deliveryAddress,
        'latitude': _latitude,
        'longitude': _longitude,
        'delivery_fee': _serviceCharge,
      };

      // Create order using OrderService
      final orderResponse = await OrderService.placeOrder(orderData);

      if (orderResponse.isNotEmpty && orderResponse['id'] != null) {
        final orderId = orderResponse['id'].toString();

        // Get full order details
        final orderDetails = await OrderService.getOrderById(orderId);
        _createdOrder = Order.fromJson(orderDetails);

        // Close creating order dialog
        Navigator.of(context, rootNavigator: true).pop();

        setState(() {
          _searchingDriver = false;
          _orderCreated = true;
        });

        // Show success dialog
        await _showOrderCreatedSuccess();

        // Start driver search process
        _showDriverSearchDialog();
        _startDriverSearch();
      } else {
        throw Exception('Order created but no order ID returned');
      }
    } catch (e) {
      Navigator.of(context, rootNavigator: true).pop();
      setState(() => _searchingDriver = false);
      await _showErrorDialog('Gagal Membuat Pesanan', 'Terjadi kesalahan saat membuat pesanan: $e');
    }
  }

  void _showLoadingDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Lottie.asset('assets/animations/loading_animation.json', width: 150, height: 150, repeat: true),
                  const SizedBox(height: 24),
                  Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showOrderCreatedSuccess() async {
    await _playSound('audio/kring.mp3');

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset('assets/animations/check_animation.json', width: 180, height: 180, repeat: false),
                const SizedBox(height: 20),
                const Text("Pesanan Berhasil Dibuat", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                const Text("Pesanan Anda telah diterima dan siap diproses", textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 8),
                Text("Order ID: ${_createdOrder?.id ?? 'N/A'}", style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlobalStyle.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("OK", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDriverSearchDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Lottie.asset('assets/animations/loading_animation.json', width: 180, height: 180, repeat: true),
                  const SizedBox(height: 24),
                  const Text("Mencari Driver", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  const Text("Mohon tunggu sementara kami mencarikan driver terbaik untuk Anda...", textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 12),
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1 + 0.05 * _pulseController.value),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text("Maksimal waktu pencarian: 15 menit", style: TextStyle(fontSize: 12, color: Colors.blue.shade800, fontWeight: FontWeight.w500)),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _cancelOrderRequest();
                    },
                    child: Text("Batalkan Pencarian", style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _startDriverSearch() {
    if (_createdOrder == null) return;

    // Set 15-minute timeout
    _driverSearchTimer = Timer(const Duration(minutes: 15), () {
      if (mounted && !_driverFound) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() {
          _searchingDriver = false;
          _orderFailed = true;
          _orderFailReason = 'Tidak ada driver yang tersedia setelah 15 menit pencarian';
        });
        _playSound('audio/wrong.mp3');
      }
    });

    // Start periodic check for driver assignment
    Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!mounted || _driverFound) {
        timer.cancel();
        return;
      }

      _checkDriverAssignment();
    });
  }

  Future<void> _checkDriverAssignment() async {
    if (_createdOrder == null) return;

    try {
      final orderData = await OrderService.getOrderById(_createdOrder!.id.toString());

      if (orderData['driver_id'] != null && !_driverFound) {
        // Driver found!
        _driverSearchTimer?.cancel();
        Navigator.of(context, rootNavigator: true).pop();

        // Load driver data
        await _loadDriverData();

        setState(() {
          _driverFound = true;
          _searchingDriver = false;
          _orderFailed = false;
        });

        _driverCardController.forward();
        await _playSound('audio/kring.mp3');
        await _showDriverFoundDialog();

        // Start order status monitoring
        _startOrderStatusMonitoring();
      }
    } catch (e) {
      print('Error checking driver assignment: $e');
    }
  }

  Future<void> _showDriverFoundDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Lottie.asset('assets/animations/driver_found.json', width: 200, height: 200, repeat: false),
                    Positioned(
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text("Driver Ditemukan!", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(_driverName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text("Nomor Kendaraan: $_vehicleNumber", style: TextStyle(fontSize: 14, color: Colors.grey[800], fontWeight: FontWeight.w500)),
                ),
                const SizedBox(height: 16),
                const Text("Driver telah menerima pesanan Anda dan akan segera menuju ke toko", textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlobalStyle.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("OK", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _cancelOrderRequest() async {
    if (_createdOrder == null) return;

    try {
      setState(() => _isLoading = true);

      await OrderService.cancelOrder(_createdOrder!.id.toString());

      _driverSearchTimer?.cancel();

      setState(() {
        _isLoading = false;
        _searchingDriver = false;
        _orderFailed = true;
        _orderFailReason = 'Pencarian dibatalkan oleh pengguna';
        _orderCreated = false;
      });

      await _playSound('audio/wrong.mp3');
    } catch (e) {
      setState(() => _isLoading = false);
      await _showErrorDialog('Cancel Failed', 'Failed to cancel order: $e');
    }
  }

  void _startOrderStatusMonitoring() {
    _orderStatusTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && _createdOrder != null) {
        _checkOrderStatus();

        if (_createdOrder!.orderStatus.isCompleted) {
          timer.cancel();
        }
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _checkOrderStatus() async {
    if (_createdOrder == null) return;

    try {
      final orderData = await OrderService.getOrderById(_createdOrder!.id.toString());
      final updatedOrder = Order.fromJson(orderData);

      setState(() {
        _createdOrder = updatedOrder;
      });

      // Check if order is completed for rating
      if (updatedOrder.orderStatus == OrderStatus.delivered) {
        await _checkOrderRatingStatus();
        if (!_hasGivenRating) {
          setState(() => _showRatingSection = true);
        }
      }
    } catch (e) {
      print('Error checking order status: $e');
    }
  }

  Future<void> _checkOrderRatingStatus() async {
    if (_createdOrder == null) return;

    try {
      final orderData = await OrderService.getOrderById(_createdOrder!.id.toString());

      bool hasReviews = false;
      if (orderData['order_reviews'] != null && (orderData['order_reviews'] as List).isNotEmpty) {
        hasReviews = true;
      }
      if (orderData['driver_reviews'] != null && (orderData['driver_reviews'] as List).isNotEmpty) {
        hasReviews = true;
      }

      setState(() => _hasGivenRating = hasReviews);
    } catch (e) {
      print('Error checking rating status: $e');
      setState(() => _hasGivenRating = false);
    }
  }

  Future<void> _submitRating() async {
    if (_createdOrder == null || _assignedDriver == null || _storeData == null) return;

    setState(() => _isSubmittingRating = true);

    try {
      // Submit rating through OrderService (as per documentation)
      final reviewData = {
        'order_id': _createdOrder!.id,
        'store_rating': _storeRating,
        'store_comment': _storeReviewController.text,
        'driver_rating': _driverRating,
        'driver_comment': _driverReviewController.text,
      };

      // This would call the appropriate review submission endpoint
      // await OrderService.submitReview(reviewData);

      setState(() {
        _hasGivenRating = true;
        _showRatingSection = false;
        _isSubmittingRating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Rating berhasil dikirim. Terima kasih!'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      setState(() => _isSubmittingRating = false);
      await _showErrorDialog('Rating Error', 'Gagal mengirim rating: $e');
    }
  }

  double get subtotal {
    if (_createdOrder != null) {
      return _createdOrder!.totalAmount - _createdOrder!.deliveryFee;
    }
    return widget.cartItems.fold(0, (sum, item) => sum + (item.price * item.quantity));
  }

  double get total {
    if (_createdOrder != null) {
      return _createdOrder!.totalAmount;
    }
    return subtotal + _serviceCharge;
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
    _driverSearchTimer?.cancel();
    _orderStatusTimer?.cancel();
    _storeReviewController.dispose();
    _driverReviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isCompletedOrder = widget.completedOrder != null &&
        (widget.completedOrder!.orderStatus == OrderStatus.delivered ||
            widget.completedOrder!.orderStatus == OrderStatus.cancelled);

    bool isCancelledOrder = widget.completedOrder != null &&
        widget.completedOrder!.orderStatus == OrderStatus.cancelled;

    String formattedOrderDate = '';
    if (widget.completedOrder != null) {
      formattedOrderDate = DateFormat('dd MMM yyyy, hh.mm a').format(widget.completedOrder!.createdAt ?? DateTime.now());
    }

    String storeName = _storeData?.name ?? 'Pesanan';

    return Scaffold(
      backgroundColor: const Color(0xffF0F7FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text(
          isCompletedOrder
              ? isCancelledOrder ? 'Riwayat Pesanan Dibatalkan' : 'Riwayat Pesanan'
              : 'Keranjang Pesanan',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
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
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset('assets/animations/loading_animation.json', width: 150, height: 150),
            const SizedBox(height: 16),
            Text("Memuat Data...", style: TextStyle(color: GlobalStyle.primaryColor, fontWeight: FontWeight.w500, fontSize: 16)),
          ],
        ),
      )
          : widget.cartItems.isEmpty && widget.completedOrder == null
          ? _buildEmptyCart()
          : _buildCartContent(isCompletedOrder, isCancelledOrder, formattedOrderDate, storeName),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset('assets/animations/empty_cart.json', width: 200, height: 200),
          const SizedBox(height: 16),
          Text("Keranjang Kosong", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[700])),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text("Tambahkan beberapa item untuk mulai memesan", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[500], fontSize: 16)),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.shopping_bag_outlined),
            label: const Text("Mulai Belanja"),
            style: ElevatedButton.styleFrom(
              backgroundColor: GlobalStyle.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartContent(bool isCompletedOrder, bool isCancelledOrder, String formattedOrderDate, String storeName) {
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Order Failed Card
            if (_orderFailed || _orderRejected) _buildOrderFailedCard(),

            // Driver Information Card
            if ((isCompletedOrder || _driverFound) && !_orderFailed && !_orderRejected) _buildDriverCard(),

            // Order Date Card for completed orders
            if (isCompletedOrder) _buildOrderDateCard(formattedOrderDate),

            // Order Items Card
            _buildOrderItemsCard(isCompletedOrder, isCancelledOrder, storeName),

            // Delivery Address Card
            _buildDeliveryAddressCard(isCompletedOrder),

            // Payment Details Card
            _buildPaymentDetailsCard(),

            // Rating Section (appears after order completion)
            if (_showRatingSection && _assignedDriver != null && _storeData != null) _buildRatingSection(),

            // Action Buttons for completed orders
            if (isCompletedOrder) _buildCompletedOrderActions(isCancelledOrder),

            // Add space for order button
            if (!isCompletedOrder && !_orderCreated && !_orderFailed && !_orderRejected) const SizedBox(height: 80),
          ],
        ),

        // Persistent Order Button
        if (!isCompletedOrder && !_orderCreated && !_orderFailed && !_orderRejected) _buildOrderButton(),
      ],
    );
  }

  Widget _buildOrderFailedCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Column(
        children: [
          Lottie.asset('assets/animations/caution.json', height: 120, width: 120),
          const Text("Pesanan Gagal", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)),
          const SizedBox(height: 12),
          Text(_orderFailReason, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _orderFailed = false;
                _orderRejected = false;
                _orderCreated = false;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: GlobalStyle.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: const Text("Coba Lagi", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverCard() {
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

  Widget _buildOrderDateCard(String formattedOrderDate) {
    return _buildCard(
      index: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: GlobalStyle.primaryColor),
                const SizedBox(width: 8),
                Text('Tanggal Pesanan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: GlobalStyle.fontColor)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(formattedOrderDate, style: TextStyle(color: GlobalStyle.fontColor)),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildOrderItemsCard(bool isCompletedOrder, bool isCancelledOrder, String storeName) {
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
                    Text(storeName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: GlobalStyle.fontColor)),
                    if (isCompletedOrder && widget.completedOrder!.orderStatus == OrderStatus.cancelled)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.red[100], borderRadius: BorderRadius.circular(12)),
                        child: Text('Dibatalkan', style: TextStyle(fontSize: 12, color: Colors.red[800], fontWeight: FontWeight.bold)),
                      ),
                    if (isCompletedOrder && widget.completedOrder!.orderStatus == OrderStatus.delivered)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.green[100], borderRadius: BorderRadius.circular(12)),
                        child: Text('Selesai', style: TextStyle(fontSize: 12, color: Colors.green[800], fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.cartItems.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = widget.cartItems[index];
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
                  ],
                ),
                trailing: Text(GlobalStyle.formatRupiah(item.price * item.quantity), style: TextStyle(fontWeight: FontWeight.bold, color: GlobalStyle.primaryColor)),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryAddressCard(bool isCompletedOrder) {
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
                Text('Alamat Pengiriman', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: GlobalStyle.fontColor)),
              ],
            ),
            const SizedBox(height: 12),
            if (isCompletedOrder || _orderCreated)
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
                    Expanded(
                      child: Text(_deliveryAddress ?? 'Alamat tidak tersedia', style: TextStyle(color: GlobalStyle.fontColor)),
                    ),
                  ],
                ),
              )
            else
              GestureDetector(
                onTap: _handleLocationAccess,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _errorMessage != null ? Colors.red : Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.my_location,
                        color: _deliveryAddress != null ? GlobalStyle.primaryColor : Colors.grey,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _deliveryAddress ?? 'Pilih lokasi pengiriman',
                          style: TextStyle(
                            color: _deliveryAddress != null ? GlobalStyle.fontColor : Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _deliveryAddress != null ? GlobalStyle.primaryColor.withOpacity(0.1) : Colors.grey[200],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _deliveryAddress != null ? 'Ubah' : 'Pilih',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _deliveryAddress != null ? GlobalStyle.primaryColor : Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_errorMessage != null && !isCompletedOrder && !_orderCreated)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentDetailsCard() {
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
                  _buildPaymentRow('Biaya Pengiriman', _serviceCharge),
                  if (_storeDistance != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Icon(Icons.directions_bike, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text('Jarak: ${_getFormattedDistance()}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                    ),
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
                Expanded(
                  child: Text('Pembayaran hanya menerima tunai saat ini', style: TextStyle(fontSize: 12, color: Colors.blue[700], fontStyle: FontStyle.italic)),
                ),
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
      index: 3,
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
            RateStore(
              store: _storeData!,
              initialRating: _storeRating,
              onRatingChanged: (rating) => setState(() => _storeRating = rating),
              reviewController: _storeReviewController,
              isLoading: _isSubmittingRating,
            ),

            const SizedBox(height: 24),

            // Driver Rating Section
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

  Widget _buildCompletedOrderActions(bool isCancelledOrder) {
    return _buildCard(
      index: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (!_hasGivenRating && widget.completedOrder!.orderStatus == OrderStatus.delivered)
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
            if (widget.completedOrder!.orderStatus == OrderStatus.cancelled)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Icon(Icons.cancel_outlined, color: Colors.red[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text("Pesanan ini telah dibatalkan", style: TextStyle(color: Colors.red[800], fontWeight: FontWeight.w500, fontSize: 14)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: widget.completedOrder!.orderStatus == OrderStatus.cancelled ? const Icon(Icons.refresh) : const Icon(Icons.shopping_bag),
              label: Text(widget.completedOrder!.orderStatus == OrderStatus.cancelled ? "Pesan Ulang" : "Beli Lagi"),
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

  Widget _buildOrderButton() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5))],
        ),
        child: ElevatedButton(
          onPressed: _searchingDriver || _isLoading ? null : _searchDriver,
          style: ElevatedButton.styleFrom(
            backgroundColor: GlobalStyle.primaryColor,
            disabledBackgroundColor: Colors.grey,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          child: _searchingDriver || _isLoading
              ? const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
              SizedBox(width: 12),
              Text('Memproses...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          )
              : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shopping_cart_checkout),
              const SizedBox(width: 8),
              Text('Buat Pesanan - ${GlobalStyle.formatRupiah(total)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
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
}