import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'dart:async';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Models/menu_item.dart';
import 'package:del_pick/Views/Customers/location_access.dart';
import 'package:del_pick/Views/Customers/track_cust_order.dart';
import 'package:del_pick/Views/Customers/rating_cust.dart';
import 'package:del_pick/Models/item_model.dart';
import 'package:del_pick/Models/store.dart';
import 'package:del_pick/Models/tracking.dart';
import 'package:del_pick/Models/order.dart';
import 'package:del_pick/Views/Component/order_status_card.dart';
import 'package:audioplayers/audioplayers.dart';

// Import required services
import 'package:del_pick/Services/order_service.dart';
import 'package:del_pick/Services/image_service.dart';
import 'package:del_pick/Services/core/token_service.dart';

import '../../Models/order_enum.dart';
import '../Driver/track_order.dart';

class CartScreen extends StatefulWidget {
  static const String route = "/Customers/Cart";
  final int storeId;
  final List<MenuItem> cartItems;
  final Order? completedOrder; // Add completed order parameter

  const CartScreen({
    Key? key,
    required this.cartItems,
    required this.storeId,
    this.completedOrder, // Optional completed order
  }) : super(key: key);

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> with TickerProviderStateMixin {
  // Service charge will be calculated using Haversine algorithm
  double _serviceCharge = 0;
  String? _deliveryAddress;
  double? _latitude; // Added to store latitude
  double? _longitude; // Added to store longitude
  double? _storeLatitude; // Store latitude
  double? _storeLongitude; // Store longitude
  String? _errorMessage;
  bool _isLoading = false;
  bool _orderCreated = false;
  bool _searchingDriver = false;
  bool _driverFound = false;
  bool _driverAvailable = false;
  bool _orderFailed = false; // Track if order failed due to no driver
  String _driverName = "";
  String _vehicleNumber = "";
  Order? _createdOrder;
  bool _showTrackButton = false;
  bool _hasGivenRating = false; // Track if user has given rating

  // Store order detail data from OrderService
  Map<String, dynamic>? _orderDetailData;
  Timer? _driverSearchTimer; // Timer to track driver search timeout
  StreamSubscription? _driverSearchSubscription; // To manage stream subscription

  // Audio player instance
  final AudioPlayer _audioPlayer = AudioPlayer();

  late AnimationController _slideController;
  late AnimationController _driverCardController;
  late AnimationController _statusCardController;
  late Animation<Offset> _driverCardAnimation;
  late Animation<Offset> _statusCardAnimation;

  // Animation controllers for status animations
  late Map<OrderStatus, AnimationController> _statusAnimationControllers;

  // Create multiple animation controllers for different sections
  late List<AnimationController> _cardControllers;
  late List<Animation<Offset>> _cardAnimations;

  @override
  void initState() {
    super.initState();

    // Initialize with completed order if available
    if (widget.completedOrder != null) {
      _orderCreated = true;
      _driverFound = true;
      _createdOrder = widget.completedOrder;
      _deliveryAddress = widget.completedOrder!.deliveryAddress;
      _serviceCharge = widget.completedOrder!.serviceCharge;

      if (widget.completedOrder!.tracking != null) {
        _driverName = widget.completedOrder!.tracking!.driverName;
        _vehicleNumber = widget.completedOrder!.tracking!.vehicleNumber;
      }

      _checkOrderRatingStatus();
      _loadOrderDetailData();
    } else {
      // Load initial order data to get store information
      _loadInitialData();
    }

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Initialize animation controllers for each card section
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

    // Initialize driver card animation controller
    _driverCardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Initialize status card animation controller
    _statusCardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Create driver card animation
    _driverCardAnimation = Tween<Offset>(
      begin: const Offset(0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _driverCardController,
      curve: Curves.easeOutCubic,
    ));

    // Create status card animation
    _statusCardAnimation = Tween<Offset>(
      begin: const Offset(0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _statusCardController,
      curve: Curves.easeOutCubic,
    ));

    // Initialize status animation controllers
    _statusAnimationControllers = {
      OrderStatus.driverHeadingToStore: AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2000),
      ),
      OrderStatus.driverAtStore: AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2000),
      ),
      OrderStatus.driverHeadingToCustomer: AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2000),
      ),
      OrderStatus.completed: AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2000),
      ),
    };

    // Start animations sequentially
    Future.delayed(const Duration(milliseconds: 100), () {
      for (var controller in _cardControllers) {
        controller.forward();
      }

      // If we have a completed order, start these animations too
      if (widget.completedOrder != null) {
        _driverCardController.forward();
        _statusCardController.forward();
      }
    });
  }

  // Calculate Haversine distance between two coordinates
  double calculateHaversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Radius of the Earth in kilometers

    // Convert degrees to radians
    double toRadians(double degrees) {
      return degrees * (pi / 180);
    }

    // Calculate differences in coordinates
    double dLat = toRadians(lat2 - lat1);
    double dLon = toRadians(lon2 - lon1);

    // Haversine formula
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(toRadians(lat1)) * cos(toRadians(lat2)) *
            sin(dLon / 2) * sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    double distance = earthRadius * c; // Distance in kilometers

    return distance;
  }

  // Calculate delivery fee based on distance
  double calculateDeliveryFee(double distance) {
    // Calculate fee by multiplying distance by 2500
    double fee = distance * 2500;

    // Round up to the nearest 1000 for easier cash payment
    return (fee / 1000).ceil() * 1000;
  }

  // Load initial data using OrderService.getOrdersByUser() or use default values
  Future<void> _loadInitialData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // For new orders, we can try to get store information from recent orders
      // If no recent orders, use default values
      try {
        final ordersData = await OrderService.getOrdersByUser(page: 1, limit: 5);

        // Look for an order from the same store to get store details
        if (ordersData['orders'] != null && ordersData['orders'] is List) {
          final orders = ordersData['orders'] as List;

          for (var orderData in orders) {
            if (orderData['store'] != null &&
                orderData['store']['id'] == widget.storeId) {
              // Found an order from the same store, use its store data
              final storeData = orderData['store'];
              _storeLatitude = storeData['latitude']?.toDouble();
              _storeLongitude = storeData['longitude']?.toDouble();
              break;
            }
          }
        }
      } catch (e) {
        print('Could not load recent orders for store info: $e');
      }

      // Set default service charge
      _serviceCharge = 30000;

      // Update service charge if we have coordinates
      if (_latitude != null && _longitude != null &&
          _storeLatitude != null && _storeLongitude != null) {
        double distance = calculateHaversineDistance(
            _latitude!, _longitude!, _storeLatitude!, _storeLongitude!);
        _serviceCharge = calculateDeliveryFee(distance);
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load initial data';
        _isLoading = false;
      });
      print('Error loading initial data: $e');
    }
  }

  // Load order detail data using OrderService.getOrderDetail()
  Future<void> _loadOrderDetailData() async {
    if (_createdOrder == null) return;

    try {
      final orderDetailData = await OrderService.getOrderDetail(_createdOrder!.id);
      setState(() {
        _orderDetailData = orderDetailData;

        // Update store coordinates if available
        if (orderDetailData['store'] != null) {
          _storeLatitude = orderDetailData['store']['latitude']?.toDouble();
          _storeLongitude = orderDetailData['store']['longitude']?.toDouble();
        }

        // Update delivery address and coordinates if available
        if (orderDetailData['deliveryAddress'] != null) {
          _deliveryAddress = orderDetailData['deliveryAddress'];
        }

        if (orderDetailData['latitude'] != null && orderDetailData['longitude'] != null) {
          _latitude = orderDetailData['latitude']?.toDouble();
          _longitude = orderDetailData['longitude']?.toDouble();

          // Recalculate service charge if needed
          _updateDeliveryFee();
        }
      });
    } catch (e) {
      print('Error loading order detail data: $e');
    }
  }

  // Update delivery fee when location changes
  void _updateDeliveryFee() {
    if (_latitude != null && _longitude != null &&
        _storeLatitude != null && _storeLongitude != null) {
      double distance = calculateHaversineDistance(
          _latitude!, _longitude!, _storeLatitude!, _storeLongitude!);
      setState(() {
        _serviceCharge = calculateDeliveryFee(distance);
      });
    }
  }

  // Check if the order has already been rated using OrderService.getOrderDetail()
  Future<void> _checkOrderRatingStatus() async {
    if (_createdOrder != null) {
      try {
        // Get the latest order details using OrderService.getOrderDetail()
        final orderDetails = await OrderService.getOrderDetail(_createdOrder!.id);

        setState(() {
          // Check if there are any reviews in the order
          bool hasReviews = false;
          if (orderDetails['orderReviews'] != null &&
              orderDetails['orderReviews'] is List &&
              (orderDetails['orderReviews'] as List).isNotEmpty) {
            hasReviews = true;
          }
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
          _hasGivenRating = false; // Default to false if error
        });
      }
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _driverCardController.dispose();
    _statusCardController.dispose();
    for (var controller in _cardControllers) {
      controller.dispose();
    }
    for (var controller in _statusAnimationControllers.values) {
      controller.dispose();
    }
    _audioPlayer.dispose();

    // Cancel timer and stream subscription if active
    _driverSearchTimer?.cancel();
    _driverSearchSubscription?.cancel();

    super.dispose();
  }

  double get subtotal {
    if (_createdOrder != null) {
      return _createdOrder!.subtotal;
    }
    return widget.cartItems
        .fold(0, (sum, item) => sum + (item.price * item.quantity));
  }

  double get total {
    if (_createdOrder != null) {
      return _createdOrder!.total;
    }
    return subtotal + _serviceCharge;
  }

  // Play sound helper method
  Future<void> _playSound(String assetPath) async {
    await _audioPlayer.stop();
    await _audioPlayer.play(AssetSource(assetPath));
  }

  // Convert cart items to request format for API
  List<Map<String, dynamic>> _prepareOrderItems() {
    return widget.cartItems.map((item) {
      return {
        'itemId': item.id,
        'quantity': item.quantity,
      };
    }).toList();
  }

  // Prepare order data for API request with coordinates
  Map<String, dynamic> _prepareOrderData() {
    return {
      'storeId': widget.storeId,
      'items': _prepareOrderItems(),
      'deliveryAddress': _deliveryAddress,
      'latitude': _latitude,  // Include latitude
      'longitude': _longitude,  // Include longitude
      'notes': '',  // Optional notes
      'serviceCharge': _serviceCharge,
    };
  }

  Future<void> _handleLocationAccess() async {
    final result = await Navigator.pushNamed(context, LocationAccessScreen.route);

    if (result is Map<String, dynamic> && result['address'] != null) {
      setState(() {
        _deliveryAddress = result['address'];
        _latitude = result['latitude'];  // Store latitude
        _longitude = result['longitude'];  // Store longitude
        _errorMessage = null;

        // Update delivery fee based on new location
        _updateDeliveryFee();
      });
    }
  }

  // Show no address dialog with animation and sound
  Future<void> _showNoAddressDialog() async {
    // Play error sound
    await _playSound('audio/wrong.mp3');

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/animations/caution.json',
                  height: 200,
                  width: 200,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 10),
                const Text(
                  "Mohon tentukan alamat pengiriman untuk melanjutkan pesanan",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
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
                    Navigator.pop(context);
                    _handleLocationAccess();
                  },
                  child: const Text(
                    "Tentukan Alamat",
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

  // Show error dialog
  Future<void> _showErrorDialog(String title, String message) async {
    await _playSound('audio/wrong.mp3');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: GlobalStyle.primaryColor)),
          ),
        ],
      ),
    );
  }

  // Show failed order dialog after timeout (15 minutes)
  Future<void> _showOrderFailedDialog() async {
    await _playSound('audio/wrong.mp3');

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/animations/error.json',
                  height: 200,
                  width: 200,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 10),
                const Text(
                  "Maaf, pesanan gagal",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Tidak ada driver yang tersedia setelah 15 menit pencarian. Pesanan akan dibatalkan secara otomatis.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
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
                    Navigator.pop(context);
                    // Cancel the order if it exists
                    _handleOrderFailure();
                  },
                  child: const Text(
                    "OK",
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

  // Handle order failure by cancelling order and resetting state
  Future<void> _handleOrderFailure() async {
    // Cancel driver search subscription
    _driverSearchSubscription?.cancel();
    _driverSearchTimer?.cancel();

    // If we have a created order, attempt to cancel it
    if (_createdOrder != null) {
      try {
        await OrderService.cancelOrderRequest(_createdOrder!.id);
      } catch (e) {
        print('Error cancelling failed order: $e');
        // Continue with UI reset even if cancellation fails
      }
    }

    // Reset UI state
    setState(() {
      _orderFailed = false;
      _searchingDriver = false;
      _orderCreated = false;
      _createdOrder = null;
      _driverFound = false;
      _orderDetailData = null;
    });
  }

  // Place order and start driver search with improved error handling
  Future<void> _searchDriver() async {
    if (_deliveryAddress == null || _deliveryAddress!.isEmpty) {
      await _showNoAddressDialog();
      return;
    }

    setState(() {
      _searchingDriver = true;
      _orderFailed = false;
    });

    // Show driver search dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/animations/loading_animation.json',
                  width: 150,
                  height: 150,
                  repeat: true,
                ),
                const SizedBox(height: 20),
                const Text(
                  "Membuat pesanan...",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Mohon tunggu sebentar",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    try {
      // Create the order through the API
      final orderResponse = await OrderService.placeOrder(_prepareOrderData());

      if (orderResponse['id'] != null || orderResponse['order'] != null) {
        // Get order ID from response
        final String orderId = (orderResponse['id'] ?? orderResponse['order']['id']).toString();

        // Fetch the created order details using getOrderDetail
        final orderDetails = await OrderService.getOrderDetail(orderId);

        // Create Order object from response
        _createdOrder = Order.fromJson(orderDetails);
        _orderDetailData = orderDetails;

        // Close the driver search dialog
        Navigator.of(context, rootNavigator: true).pop();

        setState(() {
          _searchingDriver = false;
          _orderCreated = true;

          // Update store and location data from order details
          if (orderDetails['store'] != null) {
            _storeLatitude = orderDetails['store']['latitude']?.toDouble();
            _storeLongitude = orderDetails['store']['longitude']?.toDouble();
          }

          // Check if driver is already assigned
          if (orderDetails['driver'] != null) {
            _driverFound = true;
            _driverCardController.forward();

            // Get driver details from order data
            final driverData = orderDetails['driver'];
            _driverName = driverData['name'] ?? 'Unknown Driver';
            _vehicleNumber = driverData['vehicle_number'] ?? 'Unknown';
          }
        });

        // Show success dialog and start monitoring
        await _showOrderSuccess();

        // Start monitoring driver assignment if no driver assigned yet
        if (!_driverFound) {
          _startDriverSearchStream();
        } else {
          // Start tracking if driver already assigned
          _startOrderTracking();
          _statusCardController.forward();
        }
      } else {
        throw Exception('Invalid order response');
      }
    } catch (e) {
      // Close the driver search dialog
      Navigator.of(context, rootNavigator: true).pop();

      setState(() {
        _searchingDriver = false;
      });

      print('Error creating order: $e');
      await _showErrorDialog('Order Failed', 'Failed to create order. Please try again.');
    }
  }

  // Monitor driver assignment using Stream with proper 15-minute timeout
  void _startDriverSearchStream() {
    if (_createdOrder == null) return;

    // Set up the 15-minute timeout timer
    _driverSearchTimer = Timer(const Duration(minutes: 15), () {
      if (mounted && !_driverFound) {
        print('Driver search timeout after 15 minutes');
        setState(() {
          _orderFailed = true;
          _searchingDriver = false;
        });
        _showOrderFailedDialog();
      }
    });

    // Use the findDriverInBackground Stream from OrderService
    final driverSearchStream = OrderService.findDriverInBackground(
      _createdOrder!.id,
      checkInterval: const Duration(seconds: 5),
      timeout: const Duration(minutes: 15),
    );

    // Listen for updates
    _driverSearchSubscription = driverSearchStream.listen(
            (statusData) {
          print('Driver search status update: $statusData');

          // Check if a driver has been assigned
          if (statusData['driverAssigned'] == true && !_driverFound) {
            // Cancel the timer as driver is found
            _driverSearchTimer?.cancel();

            // Update driver info
            setState(() {
              _driverFound = true;

              // Get driver details if available
              if (statusData['driverInfo'] != null) {
                final driverInfo = statusData['driverInfo'];
                _driverName = driverInfo['name'] ?? 'Unknown Driver';
                _vehicleNumber = driverInfo['vehicle_number'] ?? 'Unknown';
              }

              // Clear order failed state
              _orderFailed = false;
              _searchingDriver = false;
            });

            // Start driver card animation
            _driverCardController.forward();

            // Play sound for driver found
            _playSound('audio/kring.mp3');

            // Refresh order details and start tracking
            _checkOrderStatus();
            _startOrderTracking();
            _statusCardController.forward();
          }

          // Handle timeout or errors from the stream
          if (statusData['orderStatus'] == 'timeout' || statusData['isError'] == true) {
            _driverSearchTimer?.cancel();

            if (mounted && !_driverFound) {
              setState(() {
                _orderFailed = true;
                _searchingDriver = false;
              });
              _showOrderFailedDialog();
            }
          }
        },
        onError: (e) {
          print('Error in driver search stream: $e');
          _driverSearchTimer?.cancel();

          if (mounted && !_driverFound) {
            setState(() {
              _orderFailed = true;
              _searchingDriver = false;
            });
            _showOrderFailedDialog();
          }
        },
        onDone: () {
          print('Driver search stream completed');
          _driverSearchTimer?.cancel();

          // When the stream completes, check if we found a driver
          if (!_driverFound && mounted) {
            setState(() {
              _orderFailed = true;
              _searchingDriver = false;
            });
            _showOrderFailedDialog();
          }
        }
    );
  }

  // Show order success dialog and begin tracking
  Future<void> _showOrderSuccess() async {
    // Play success sound
    await _playSound('audio/kring.mp3');

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.white,
          child: Padding(
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
                  "Pesanan berhasil dibuat",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _driverFound
                      ? "Driver telah ditemukan"
                      : "Sedang mencari driver untuk Anda...",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
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
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "OK",
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

  // Setup periodic order status updates using OrderService.getOrderDetail()
  void _startOrderTracking() {
    // Check status immediately
    _checkOrderStatus();

    // Setup a periodic timer to check status
    Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted && _createdOrder != null) {
        _checkOrderStatus();

        // Stop timer if order is completed or cancelled
        if (_createdOrder!.status.isCompleted ||
            _createdOrder!.status == OrderStatus.cancelled) {
          timer.cancel();
        }
      } else {
        timer.cancel();
      }
    });
  }

  // Check current order status using OrderService.getOrderDetail()
  Future<void> _checkOrderStatus() async {
    if (_createdOrder == null) return;

    try {
      // Get latest order status using OrderService.getOrderDetail()
      final orderDetails = await OrderService.getOrderDetail(_createdOrder!.id);

      // Update local state with new order details
      setState(() {
        _orderDetailData = orderDetails;

        // Update order object
        _createdOrder = Order.fromJson(orderDetails);

        // If driver is newly assigned
        if (orderDetails['driver'] != null && !_driverFound) {
          _driverFound = true;
          _driverCardController.forward();

          // Get driver information from the order
          final driverData = orderDetails['driver'];
          _driverName = driverData['name'] ?? 'Unknown Driver';
          _vehicleNumber = driverData['vehicle_number'] ?? 'Unknown';

          // Cancel driver search timer as driver is found
          _driverSearchTimer?.cancel();
          _driverSearchSubscription?.cancel();

          // Clear failed state
          _orderFailed = false;
          _searchingDriver = false;
        }

        // Check if status changed to show track button
        final currentStatus = orderDetails['order_status'] ?? '';
        if (currentStatus == 'on_delivery' ||
            currentStatus == 'driverHeadingToCustomer') {
          _showTrackButton = true;
          // Play status change sound
          _playSound('audio/alert.wav');
        }

        // Check if order is completed
        if (currentStatus == 'delivered' || currentStatus == 'completed') {
          _checkOrderRatingStatus();
        }
      });
    } catch (e) {
      print('Error checking order status: $e');
    }
  }

  // Handle "Beri Rating" button press using OrderService.createReview()
  void _handleRatingPress() async {
    if (_createdOrder == null) return;

    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RatingCustomerPage(
            order: _createdOrder!,
          ),
        ),
      );

      // If rating was submitted successfully
      if (result != null && result is Map<String, dynamic>) {
        // Prepare review data structure for OrderService.createReview()
        final Map<String, dynamic> reviewData = {
          'orderId': _createdOrder!.id,
          'rating': result['storeRating'] ?? 5, // Default to store rating if available
          'comment': result['storeComment'] ?? '',
        };

        // Add store specific review if provided
        if (result['storeRating'] != null) {
          reviewData['store'] = {
            'rating': result['storeRating'],
            'comment': result['storeComment'] ?? '',
          };
        }

        // Add driver specific review if provided
        if (result['driverRating'] != null) {
          reviewData['driver'] = {
            'rating': result['driverRating'],
            'comment': result['driverComment'] ?? '',
          };
        }

        // Submit the review using OrderService.createReview()
        final reviewResponse = await OrderService.createReview(reviewData);

        if (reviewResponse.isNotEmpty) {
          setState(() {
            _hasGivenRating = true;
          });

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Rating berhasil dikirim. Terima kasih atas feedback Anda!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      print('Error submitting rating: $e');
      await _showErrorDialog('Rating Error', 'Gagal mengirim rating. Silakan coba lagi.');
    }
  }

  // Handle "Beli Lagi" button press
  void _handleBuyAgain() {
    // Navigate back to the home screen or menu screen
    Navigator.pop(context);
  }

  // Navigate to order tracking screen
  void _navigateToTrackOrder() {
    if (_createdOrder == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TrackCustOrderScreen(
          order: _createdOrder!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine if order is completed or cancelled (for history display)
    bool isCompletedOrder = widget.completedOrder != null &&
        (widget.completedOrder!.status == OrderStatus.completed ||
            widget.completedOrder!.status == OrderStatus.cancelled);

    bool isCancelledOrder = widget.completedOrder != null &&
        widget.completedOrder!.status == OrderStatus.cancelled;

    // Format the order date if available
    String formattedOrderDate = '';
    if (widget.completedOrder != null) {
      formattedOrderDate = DateFormat('dd MMM yyyy, hh.mm a')
          .format(widget.completedOrder!.orderDate);
    }

    // Get store name from order detail data or fallback
    String storeName = 'Pesanan';
    if (_orderDetailData != null && _orderDetailData!['store'] != null) {
      storeName = _orderDetailData!['store']['name'] ?? 'Pesanan';
    } else if (widget.completedOrder != null) {
      storeName = widget.completedOrder!.store.name;
    }

    return Scaffold(
      backgroundColor: const Color(0xffD6E6F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text(
          isCompletedOrder
              ? isCancelledOrder
              ? 'Riwayat Pesanan Dibatalkan'
              : 'Riwayat Pesanan'
              : 'Keranjang Pesanan',
          style: const TextStyle(
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
      ),
      // Show loading indicator while fetching initial data
      body: _isLoading ?
      Center(
        child: CircularProgressIndicator(color: GlobalStyle.primaryColor),
      ) :
      // Handle empty cart, completed orders, and active cart
      widget.cartItems.isEmpty && widget.completedOrder == null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              "Keranjang Kosong",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Tambahkan beberapa item untuk mulai memesan",
              style: TextStyle(
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      )
          : Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Order status card for active orders - MOVED TO TOP
              if (_orderCreated &&
                  !isCompletedOrder &&
                  _createdOrder != null)
                OrderStatusCard(
                  orderId: _createdOrder!.id,
                  userRole: 'customer', // Set role to customer
                  animation: _statusCardAnimation,
                  onStatusUpdate: () {
                    // Refresh order details when status changes
                    _checkOrderStatus();
                  },
                ),

              // Order failed notification with 15-minute timeout message
              if (_orderFailed)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Column(
                    children: [
                      Lottie.asset(
                        'assets/animations/error.json',
                        height: 100,
                        width: 100,
                      ),
                      const Text(
                        "Pesanan Gagal",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Tidak ada driver yang tersedia setelah 15 menit pencarian. Pesanan telah dibatalkan.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _orderFailed = false;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[600],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          "Tutup",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),

              // Driver information section - MOVED BELOW STATUS CARD
              if (isCompletedOrder || _driverFound) _buildDriverCard(),

              // Show order date for completed orders
              if (isCompletedOrder)
                _buildCard(
                  index: 0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today,
                                color: GlobalStyle.primaryColor),
                            const SizedBox(width: 8),
                            Text(
                              'Tanggal Pesanan',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: GlobalStyle.fontColor,
                                fontFamily: GlobalStyle.fontFamily,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          formattedOrderDate,
                          style: TextStyle(
                            color: GlobalStyle.fontColor,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),

              // Show order items for either active cart or completed order
              _buildCard(
                index: 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Icon(Icons.restaurant_menu,
                              color: GlobalStyle.primaryColor),
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
                              if (isCompletedOrder &&
                                  widget.completedOrder!.status ==
                                      OrderStatus.cancelled)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red[100],
                                    borderRadius:
                                    BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Dibatalkan',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red[800],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              if (isCompletedOrder &&
                                  widget.completedOrder!.status ==
                                      OrderStatus.completed)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green[100],
                                    borderRadius:
                                    BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Selesai',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green[800],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (isCompletedOrder)
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: widget.completedOrder!.items.length,
                        separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item =
                          widget.completedOrder!.items[index];
                          return _buildOrderItemRow(item);
                        },
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: widget.cartItems.length,
                        separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = widget.cartItems[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 8.0),
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
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                  GlobalStyle.formatRupiah(item.price),
                                  style: const TextStyle(
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  'Quantity: ${item.quantity}',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Text(
                              GlobalStyle.formatRupiah(
                                  item.price * item.quantity),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: GlobalStyle.primaryColor,
                                fontFamily: GlobalStyle.fontFamily,
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),

              // Delivery address section
              _buildCard(
                index: 1,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.location_on,
                              color: GlobalStyle.primaryColor),
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
                      if (isCompletedOrder || _orderCreated)
                        Text(
                          _deliveryAddress ??
                              widget.completedOrder?.deliveryAddress ??
                              'Alamat tidak tersedia',
                          style: TextStyle(
                            color: GlobalStyle.fontColor,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        )
                      else
                        GestureDetector(
                          onTap: _handleLocationAccess,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _errorMessage != null
                                    ? Colors.red
                                    : Colors.grey[300]!,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.my_location,
                                  color: _deliveryAddress != null
                                      ? GlobalStyle.primaryColor
                                      : Colors.grey,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _deliveryAddress ??
                                        'Pilih lokasi pengiriman',
                                    style: TextStyle(
                                      color: _deliveryAddress != null
                                          ? GlobalStyle.fontColor
                                          : Colors.grey,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: Colors.grey[400],
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (_errorMessage != null &&
                          !isCompletedOrder &&
                          !_orderCreated)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      // Display coordinates if available (for debugging or information)
                      if (_latitude != null && _longitude != null && !isCompletedOrder && !_orderCreated)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Koordinat: ${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Payment details section
              _buildCard(
                index: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.payment,
                              color: GlobalStyle.primaryColor),
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
                      const SizedBox(height: 12),
                      _buildPaymentRow('Subtotal', subtotal),
                      const SizedBox(height: 8),
                      _buildPaymentRow('Biaya Pengiriman', _serviceCharge),
                      if (!isCompletedOrder && !_orderCreated && _latitude != null && _longitude != null &&
                          _storeLatitude != null && _storeLongitude != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            'Jarak pengiriman: ${calculateHaversineDistance(_latitude!, _longitude!, _storeLatitude!, _storeLongitude!).toStringAsFixed(2)} km',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      const Divider(thickness: 1, height: 24),
                      _buildPaymentRow('Total', total, isTotal: true),
                    ],
                  ),
                ),
              ),

              // Action buttons for completed orders
              if (isCompletedOrder)
                _buildCard(
                  index: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        if (!_hasGivenRating &&
                            widget.completedOrder!.status ==
                                OrderStatus.completed)
                          ElevatedButton(
                            onPressed: _handleRatingPress,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: GlobalStyle.primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 24),
                              minimumSize:
                              const Size(double.infinity, 50),
                            ),
                            child: const Text(
                              "Beri Rating",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        if (widget.completedOrder!.status ==
                            OrderStatus.cancelled)
                          Text(
                            "Pesanan ini telah dibatalkan",
                            style: TextStyle(
                              color: Colors.red[800],
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        OutlinedButton(
                          onPressed: _handleBuyAgain,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: GlobalStyle.primaryColor,
                            side: BorderSide(
                                color: GlobalStyle.primaryColor,
                                width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 24),
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: widget.completedOrder!.status ==
                              OrderStatus.cancelled
                              ? const Text(
                            "Pesan Ulang",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                              : const Text(
                            "Beli Lagi",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Add extra space at the bottom if there's a persistent order button
              if (!isCompletedOrder && !_orderCreated && !_orderFailed)
                const SizedBox(height: 80),
            ],
          ),
          // Persistent order button for new orders
          if (!isCompletedOrder && !_orderCreated && !_orderFailed)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
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
                child: ElevatedButton(
                  onPressed: _searchingDriver || _isLoading ? null : _searchDriver,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlobalStyle.primaryColor,
                    disabledBackgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: _searchingDriver || _isLoading
                      ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Mencari Driver...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )
                      : Text(
                    'Buat Pesanan - ${GlobalStyle.formatRupiah(total)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
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
          color: Colors.white, // Changed background to white
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: child,
      ),
    );
  }

  Widget _buildDriverCard() {
    String driverImageUrl = '';
    double driverRating = 4.8;

    // Get driver info from order detail data if available
    if (_orderDetailData != null && _orderDetailData!['driver'] != null) {
      final driverData = _orderDetailData!['driver'];
      driverImageUrl = driverData['avatar'] ?? '';
      driverRating = (driverData['rating'] ?? 4.8).toDouble();
      _driverName = driverData['name'] ?? _driverName;
      _vehicleNumber = driverData['vehicle_number'] ?? _vehicleNumber;
    } else if (widget.completedOrder?.tracking != null) {
      driverImageUrl = widget.completedOrder!.tracking!.driverImageUrl;
      driverRating = widget.completedOrder!.tracking!.driver.rating;
    }

    return SlideTransition(
      position: _driverCardAnimation,
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
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
                Icon(Icons.delivery_dining, color: GlobalStyle.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Informasi Driver',
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
                // Use avatar image if available
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: driverImageUrl.isNotEmpty
                      ? ClipOval(
                    child: ImageService.displayImage(
                      imageSource: driverImageUrl,
                      width: 60,
                      height: 60,
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
                      : Center(
                    child: Icon(
                      Icons.person,
                      size: 30,
                      color: Colors.grey[400],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _driverName.isNotEmpty ? _driverName : 'Driver',
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
                          Icon(Icons.motorcycle,
                              color: Colors.grey[600], size: 16),
                          const SizedBox(width: 4),
                          Text(
                            _vehicleNumber.isNotEmpty ? _vehicleNumber : 'Unknown',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
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
                            driverRating.toString(),
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
                      // Phone call implementation
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
                      // Messaging implementation
                    },
                  ),
                ),
              ],
            ),

            // Add track order button when status is "Di Antar"
            if (_showTrackButton ||
                (_orderDetailData != null &&
                    (_orderDetailData!['order_status'] == 'on_delivery' ||
                        _orderDetailData!['order_status'] == 'driverHeadingToCustomer')))
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _navigateToTrackOrder,
                    icon: const Icon(Icons.location_on,
                        color: Colors.white, size: 18),
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
            color: GlobalStyle.fontColor,
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

  Widget _buildOrderItemRow(Item item) {
    return ListTile(
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      leading: SizedBox(
        width: 60,
        height: 60,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ImageService.displayImage(
            imageSource: item.imageUrl,
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
            style: const TextStyle(
              color: Colors.grey,
            ),
          ),
          Text(
            'Quantity: ${item.quantity}',
            style: const TextStyle(
              color: Colors.grey,
            ),
          ),
        ],
      ),
      trailing: Text(
        GlobalStyle.formatRupiah(item.price * item.quantity),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: GlobalStyle.primaryColor,
          fontFamily: GlobalStyle.fontFamily,
        ),
      ),
    );
  }
}