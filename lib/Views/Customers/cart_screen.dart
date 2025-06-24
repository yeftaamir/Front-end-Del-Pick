import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'dart:async';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Models/menu_item.dart';
import 'package:del_pick/Views/Customers/location_access.dart';
import 'package:del_pick/Views/Customers/rating_cust.dart';
import 'package:del_pick/Models/store.dart';
import 'package:del_pick/Models/driver.dart';
import 'package:del_pick/Models/order.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geocoding/geocoding.dart';
import 'package:lucide_icons/lucide_icons.dart';

// Import required services
import 'package:del_pick/Services/order_service.dart';
import 'package:del_pick/Services/store_service.dart';
import 'package:del_pick/Services/driver_service.dart';
import 'package:del_pick/Services/menu_service.dart';
import 'package:del_pick/Services/image_service.dart';
import 'package:del_pick/Services/auth_service.dart';

import '../../Models/order_enum.dart';
import '../../Services/Core/token_service.dart';
import '../Component/cust_order_status.dart';
class CartScreen extends StatefulWidget {
  static const String route = "/Customers/Cart";
  final int storeId;
  final List<MenuItemModel> cartItems;
  final Map<int, int>? itemQuantities; // Added for quantity tracking
  final OrderModel? completedOrder; // Add completed order parameter

  final double? customerLatitude;
  final double? customerLongitude;
  final String? customerAddress;
  final double? storeLatitude;
  final double? storeLongitude;
  final double? storeDistance;

  const CartScreen({
    Key? key,
    required this.cartItems,
    required this.storeId,
    required this.itemQuantities,
    this.completedOrder,
    this.customerLatitude,
    this.customerLongitude,
    this.customerAddress,
    this.storeLatitude,
    this.storeLongitude,
    this.storeDistance,
  }) : super(key: key);

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> with TickerProviderStateMixin {
  // Service charge will be calculated using Geolocator
  double _serviceCharge = 0;
  String? _deliveryAddress;
  double? _latitude;
  double? _longitude;
  double? _storeLatitude;
  double? _storeLongitude;
  double? _storeDistance;
  String? _errorMessage;
  bool _isLoading = false;
  bool _orderCreated = false;
  bool _searchingDriver = false;
  bool _driverFound = false;
  bool _driverAvailable = false;
  String _driverName = "";
  String _vehicleNumber = "";
  OrderModel? _createdOrder;
  bool _hasGivenRating = false;
  bool _orderFailed = false;
  bool _orderRejected = false;
  String _orderFailReason = '';

  // Location specific variables (similar to home_cust.dart)
  bool _isLoadingLocation = false;
  bool _hasLocationPermission = false;
  Position? _currentPosition;
  String? _userLocation = '';
  Map<String, dynamic>? _userData;

  // Store data
  StoreModel? _storeDetail;
  DriverModel? _driverDetail;

  // Store order detail data
  Map<String, dynamic>? _orderDetailData;
  Timer? _driverSearchTimer;
  StreamSubscription? _driverSearchSubscription;

  // Audio player instance
  final AudioPlayer _audioPlayer = AudioPlayer();

  late AnimationController _slideController;
  late AnimationController _driverCardController;
  late AnimationController _statusCardController;
  late Animation<Offset> _driverCardAnimation;
  late Animation<Offset> _statusCardAnimation;
  late AnimationController _pulseController;

  // Animation controllers for status animations
  late Map<OrderStatus, AnimationController> _statusAnimationControllers;

  // Create multiple animation controllers for different sections
  late List<AnimationController> _cardControllers;
  late List<Animation<Offset>> _cardAnimations;

  // Helper to get item quantity from external map
  int _getItemQuantity(MenuItemModel item) {
    return widget.itemQuantities?[item.id] ?? 0;
  }

  @override
  void initState() {
    super.initState();

    // Initialize with completed order if available
    if (widget.completedOrder != null) {
      _orderCreated = true;
      _driverFound = true;
      _createdOrder = widget.completedOrder;
      _deliveryAddress = widget.completedOrder!.deliveryAddress;
      _serviceCharge = widget.completedOrder!.deliveryFee;

      _checkOrderRatingStatus();
      _loadOrderDetailData();
    } else {
      // Load initial data for new orders
      _loadInitialData();
      _initializeLocation(); // Initialize location similar to home_cust.dart
    }

    // Initialize pulse animation for loading states
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

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
      for (var status in OrderStatus.values)
        status: AnimationController(
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

  // Initialize location similar to home_cust.dart
  void _initializeLocation() {
    _loadUserData();
    _getCurrentLocation();
  }

  // Load user data similar to home_cust.dart
  Future<void> _loadUserData() async {
    try {
      // Get user data from AuthService
      final userData = await AuthService.getUserData();
      if (userData != null) {
        setState(() {
          _userData = userData;
        });
      } else {
        // Fallback to TokenService if AuthService fails
        final tokenUserData = await TokenService.getUserData();
        if (tokenUserData != null) {
          setState(() {
            _userData = tokenUserData;
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
      // Try to get from token service as fallback
      try {
        final tokenUserData = await TokenService.getUserData();
        if (tokenUserData != null) {
          setState(() {
            _userData = tokenUserData;
          });
        }
      } catch (tokenError) {
        print('Error loading user data from token: $tokenError');
      }
    }
  }

  // Process customer specific data for service access
  Future<Map<String, dynamic>?> _processCustomerSpecificData() async {
    try {
      final userData = await AuthService.getUserData();
      if (userData != null) {
        return {
          'userId': userData['user']?['id'] ?? userData['id'],
          'role': userData['user']?['role'] ?? userData['role'],
          'userData': userData,
        };
      }
      return null;
    } catch (e) {
      print('Error processing customer data: $e');
      return null;
    }
  }

  // Get user ID for service access
  Future<int?> _getUserId() async {
    try {
      final customerData = await _processCustomerSpecificData();
      if (customerData != null) {
        final userId = customerData['userId'];
        if (userId is int) {
          return userId;
        } else if (userId is String) {
          return int.tryParse(userId);
        }
      }
      return null;
    } catch (e) {
      print('Error getting user ID: $e');
      return null;
    }
  }

  // Calculate distance using Geolocator
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    double distanceInMeters = Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
    return distanceInMeters / 1000;
  }

  // Calculate delivery fee with ceiling rounding for cash payment convenience
  double calculateDeliveryFee(double distance) {
    double fee = distance * 2500;
    return fee.ceilToDouble(); // Round up to the nearest rupiah for cash convenience
  }

  String _getFormattedDistance() {
    if (_storeDistance == null) {
      return "-- KM";
    }

    if (_storeDistance! < 1) {
      return "${(_storeDistance! * 1000).toInt()} m";
    } else {
      return "${_storeDistance!.toStringAsFixed(1)} km";
    }
  }

  // Get user's current location (similar to home_cust.dart)
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      // Check if location permission is granted
      var status = await Permission.location.status;
      if (!status.isGranted) {
        status = await Permission.location.request();
        if (!status.isGranted) {
          throw Exception('Location permission denied');
        }
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Get address from coordinates
      String locationText = await _getAddressFromCoordinates(position);

      setState(() {
        _currentPosition = position;
        _latitude = position.latitude;
        _longitude = position.longitude;
        _userLocation = locationText;
        _deliveryAddress = locationText; // Set as default delivery address
        _hasLocationPermission = true;
        _isLoadingLocation = false;
      });

      // Update delivery fee calculation
      _updateDeliveryFee();
    } catch (e) {
      print('Error getting location: $e');
      setState(() {
        _hasLocationPermission = false;
        _userLocation = 'Lokasi tidak tersedia';
        _isLoadingLocation = false;
      });
    }
  }

  // Get address from coordinates (similar to home_cust.dart)
  Future<String> _getAddressFromCoordinates(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        return '${place.locality ?? ''}, ${place.subAdministrativeArea ?? ''}';
      }
    } catch (e) {
      print('Error getting address: $e');
    }
    return 'Balige, North Sumatra'; // Default fallback
  }

  // Load initial data using StoreService.getStoreById()
  Future<void> _loadInitialData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Get store details using StoreService
      final storeData = await StoreService.getStoreById(widget.storeId.toString());
      _storeDetail = StoreModel.fromJson(storeData);

      if (_storeDetail != null) {
        _storeLatitude = _storeDetail!.latitude;
        _storeLongitude = _storeDetail!.longitude;
      }

      // Set default service charge
      _serviceCharge = 15000; // Default

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load store data: $e';
        _isLoading = false;
      });
      print('Error loading initial data: $e');
    }
  }

  // Load order detail data using OrderService.getOrderById()
  Future<void> _loadOrderDetailData() async {
    if (_createdOrder == null) return;

    try {
      final orderDetailData = await OrderService.getOrderById(_createdOrder!.id.toString());
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

        if (orderDetailData['customerLatitude'] != null && orderDetailData['customerLongitude'] != null) {
          _latitude = orderDetailData['customerLatitude']?.toDouble();
          _longitude = orderDetailData['customerLongitude']?.toDouble();

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
      _storeDistance = calculateDistance(
          _latitude!, _longitude!, _storeLatitude!, _storeLongitude!);

      setState(() {
        _serviceCharge = calculateDeliveryFee(_storeDistance!);
      });

      print('Jarak ke toko: ${_getFormattedDistance()}');
      print('Biaya pengiriman: ${GlobalStyle.formatRupiah(_serviceCharge)}');
    }
  }

  // Build standardized location card (similar to home_cust.dart)
  Widget _buildLocationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: GlobalStyle.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              LucideIcons.mapPin,
              color: GlobalStyle.primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lokasi Pengiriman',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _userLocation ?? 'Memuat lokasi...',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
                if (_hasLocationPermission && _currentPosition != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Lat: ${_currentPosition!.latitude.toStringAsFixed(4)}, Lng: ${_currentPosition!.longitude.toStringAsFixed(4)}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[500],
                      fontFamily: GlobalStyle.fontFamily,
                    ),
                  ),
                ],
                if (_storeDistance != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.route,
                        size: 12,
                        color: GlobalStyle.primaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Jarak: ${_getFormattedDistance()}',
                        style: TextStyle(
                          fontSize: 12,
                          color: GlobalStyle.primaryColor,
                          fontWeight: FontWeight.w500,
                          fontFamily: GlobalStyle.fontFamily,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (_isLoadingLocation)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (!_hasLocationPermission)
            IconButton(
              onPressed: _getCurrentLocation,
              icon: Icon(
                LucideIcons.refreshCw,
                color: GlobalStyle.primaryColor,
                size: 20,
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.checkCircle,
                    color: Colors.green[700],
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Aktif',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Check if the order has already been rated using OrderService.getOrderById()
  Future<void> _checkOrderRatingStatus() async {
    if (_createdOrder != null) {
      try {
        final orderDetails = await OrderService.getOrderById(_createdOrder!.id.toString());

        setState(() {
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
          _hasGivenRating = false;
        });
      }
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
    for (var controller in _statusAnimationControllers.values) {
      controller.dispose();
    }
    _audioPlayer.dispose();

    _driverSearchTimer?.cancel();
    _driverSearchSubscription?.cancel();

    super.dispose();
  }

  double get subtotal {
    if (_createdOrder != null) {
      return _createdOrder!.totalAmount - _createdOrder!.deliveryFee;
    }

    double total = 0;
    for (var item in widget.cartItems) {
      final quantity = _getItemQuantity(item);
      total += item.price * quantity;
    }
    return total;
  }

  double get total {
    if (_createdOrder != null) {
      return _createdOrder!.totalAmount;
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
      final quantity = _getItemQuantity(item);
      return {
        'itemId': item.id,
        'quantity': quantity,
        'notes': '',
      };
    }).toList();
  }

  Future<void> _handleLocationAccess() async {
    final result = await Navigator.pushNamed(context, LocationAccessScreen.route);

    if (result is Map<String, dynamic> && result['address'] != null) {
      setState(() {
        _deliveryAddress = result['address'];
        _latitude = result['latitude'];
        _longitude = result['longitude'];
        _userLocation = result['address'];
        _hasLocationPermission = true;
        _errorMessage = null;

        _updateDeliveryFee();
      });
    }
  }

  // Show no address dialog with animation and sound
  Future<void> _showNoAddressDialog() async {
    await _playSound('audio/wrong.mp3');

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          elevation: 5,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/animations/caution.json',
                  height: 180,
                  width: 180,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 16),
                const Text(
                  "Alamat Pengiriman Diperlukan",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Mohon tentukan alamat pengiriman untuk melanjutkan pesanan",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlobalStyle.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 14),
                    elevation: 2,
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
                      Text(
                        "Tentukan Alamat",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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

  // Show error dialog
  Future<void> _showErrorDialog(String title, String message) async {
    await _playSound('audio/wrong.mp3');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(
                color: GlobalStyle.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Method to create order and search for drivers
  Future<void> _searchDriver() async {
    // Validate delivery address
    if (_deliveryAddress == null || _deliveryAddress!.isEmpty) {
      await _showNoAddressDialog();
      return;
    }

    // Validate coordinates
    if (_latitude == null || _longitude == null) {
      await _showErrorDialog(
          'Lokasi Tidak Valid',
          'Tidak dapat menentukan koordinat lokasi Anda. Silakan pilih alamat pengiriman kembali.'
      );
      return;
    }

    // Show loading dialog
    setState(() {
      _searchingDriver = true;
      _orderFailed = false;
      _orderRejected = false;
    });

    // Show creating order dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: Colors.white,
            elevation: 5,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Lottie.asset(
                    'assets/animations/loading_animation.json',
                    width: 150,
                    height: 150,
                    repeat: true,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Membuat Pesanan",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Mohon tunggu sebentar sementara kami memproses pesanan Anda...",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    try {
      // Create order using OrderService.placeOrder()
      final orderResponse = await OrderService.placeOrder(
        storeId: widget.storeId.toString(),
        items: _prepareOrderItems(),
        deliveryAddress: _deliveryAddress!,
        latitude: _latitude!,
        longitude: _longitude!,
        serviceCharge: _serviceCharge,
        notes: '',
      );

      // Check if response contains order data
      if (orderResponse.isNotEmpty && orderResponse['id'] != null) {
        // Extract order ID
        final String orderId = orderResponse['id'].toString();

        // Fetch full order details
        final orderDetails = await OrderService.getOrderById(orderId);

        // Create OrderModel object from API response
        _createdOrder = OrderModel.fromJson(orderDetails);
        _orderDetailData = orderDetails;

        // Close creating order dialog
        Navigator.of(context, rootNavigator: true).pop();

        // Update state
        setState(() {
          _searchingDriver = false;
          _orderCreated = true;

          // Update location data
          if (orderDetails['store'] != null) {
            _storeLatitude = orderDetails['store']['latitude']?.toDouble();
            _storeLongitude = orderDetails['store']['longitude']?.toDouble();
          }

          // Check if driver already assigned
          if (orderDetails['driver'] != null) {
            _driverFound = true;
            _driverCardController.forward();

            // Get driver details using DriverService
            final driverId = orderDetails['driver']['id'];
            _loadDriverDetails(driverId.toString());
          }
        });

        // Show success dialog
        await _showOrderCreatedSuccess();

        // Show driver search dialog if no driver assigned yet
        if (!_driverFound) {
          _showDriverSearchDialog();
          _startDriverSearchStream();
        } else {
          _startOrderTracking();
          _statusCardController.forward();
        }
      } else {
        throw Exception('Order created but no order ID returned');
      }
    } catch (e) {
      print('Error creating order: $e');

      Navigator.of(context, rootNavigator: true).pop();

      setState(() {
        _searchingDriver = false;
      });

      await _showErrorDialog(
          'Gagal Membuat Pesanan',
          'Terjadi kesalahan saat membuat pesanan. Silakan coba lagi.'
      );
    }
  }

  // Continue with remaining methods from original cart_screen.dart...
  // [Add all other existing methods here - _loadDriverDetails, _showDriverSearchDialog, etc.]

  @override
  Widget build(BuildContext context) {
    // Determine if order is completed or cancelled (for history display)
    bool isCompletedOrder = widget.completedOrder != null &&
        (widget.completedOrder!.orderStatus == OrderStatus.delivered ||
            widget.completedOrder!.orderStatus == OrderStatus.cancelled);

    bool isCancelledOrder = widget.completedOrder != null &&
        widget.completedOrder!.orderStatus == OrderStatus.cancelled;

    // Format the order date if available
    String formattedOrderDate = '';
    if (widget.completedOrder != null) {
      formattedOrderDate = DateFormat('dd MMM yyyy, hh.mm a')
          .format(widget.completedOrder!.createdAt);
    }

    // Get store name from store detail or fallback
    String storeName = 'Pesanan';
    if (_storeDetail != null) {
      storeName = _storeDetail!.name;
    } else if (widget.completedOrder != null) {
      // Get store name from completed order - need to handle this based on your OrderModel structure
      storeName = 'Pesanan'; // Fallback
    }

    return Scaffold(
      backgroundColor: const Color(0xffF0F7FF),
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
              "Memuat Data...",
              style: TextStyle(
                color: GlobalStyle.primaryColor,
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
          ],
        ),
      )
          : widget.cartItems.isEmpty && widget.completedOrder == null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/animations/empty_cart.json',
              width: 200,
              height: 200,
            ),
            const SizedBox(height: 16),
            Text(
              "Keranjang Kosong",
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
                "Tambahkan beberapa item untuk mulai memesan",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.shopping_bag_outlined),
              label: const Text("Mulai Belanja"),
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
          : Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Standardized location card
              _buildLocationCard(),
              const SizedBox(height: 16),

              // Order status card for active orders
              if (_orderCreated && !isCompletedOrder && _createdOrder != null && !_orderRejected && !_orderFailed)
                CustomerOrderStatusCard(
                  initialOrderData: {
                    'id': _createdOrder!.id,
                    'order_status': _createdOrder!.orderStatus.name,
                    'total': _createdOrder!.totalAmount,
                    'estimatedDeliveryTime': DateTime.now().add(Duration(minutes: 30)).toIso8601String(),
                  },
                  animation: _cardAnimations[0],
                ),

              // Order failed notification
              if (_orderFailed || _orderRejected)
                _buildOrderFailedCard(),

              // Driver information section
              if ((isCompletedOrder || _driverFound) && !_orderFailed && !_orderRejected)
                _buildDriverCard(),

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

              // Show order items
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
                              if (isCompletedOrder && widget.completedOrder!.orderStatus == OrderStatus.cancelled)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red[100],
                                    borderRadius: BorderRadius.circular(12),
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
                              if (isCompletedOrder && widget.completedOrder!.orderStatus == OrderStatus.delivered)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green[100],
                                    borderRadius: BorderRadius.circular(12),
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
                    // Cart items display...
                    if (isCompletedOrder)
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: widget.completedOrder!.items.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = widget.completedOrder!.items[index];
                          return _buildOrderItemRow(item);
                        },
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: widget.cartItems.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = widget.cartItems[index];
                          final quantity = _getItemQuantity(item);
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
                                  item.formatPrice(),
                                  style: const TextStyle(color: Colors.grey),
                                ),
                                Text(
                                  'Quantity: $quantity',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                            trailing: Text(
                              GlobalStyle.formatRupiah(item.price * quantity),
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
                            _buildPaymentRow('Biaya Pengiriman', _serviceCharge),
                            if (!isCompletedOrder && !_orderCreated && _storeDistance != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Icon(
                                      Icons.directions_bike,
                                      size: 14,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Jarak: ${_getFormattedDistance()} × Rp 2.500/km (dibulatkan ke atas)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
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
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Colors.blue[700],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Pembayaran hanya menerima tunai saat ini. Biaya pengiriman dibulatkan ke atas untuk kemudahan pembayaran.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[700],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
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
                        if (!_hasGivenRating && widget.completedOrder!.orderStatus == OrderStatus.delivered)
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
                        if (widget.completedOrder!.orderStatus == OrderStatus.cancelled)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.cancel_outlined, color: Colors.red[700]),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "Pesanan ini telah dibatalkan",
                                    style: TextStyle(
                                      color: Colors.red[800],
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          icon: widget.completedOrder!.orderStatus == OrderStatus.cancelled
                              ? const Icon(Icons.refresh)
                              : const Icon(Icons.shopping_bag),
                          label: Text(
                              widget.completedOrder!.orderStatus == OrderStatus.cancelled
                                  ? "Pesan Ulang"
                                  : "Beli Lagi"
                          ),
                          onPressed: _handleBuyAgain,
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
                ),
            ],
          ),
          // Persistent order button for new orders
          if (!isCompletedOrder && !_orderCreated && !_orderFailed && !_orderRejected)
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
                    elevation: 2,
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
                        'Memproses...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )
                      : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.shopping_cart_checkout),
                      const SizedBox(width: 8),
                      Text(
                        'Buat Pesanan - ${GlobalStyle.formatRupiah(total)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Enhanced Payment Row UI
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

  Widget _buildOrderItemRow(dynamic item) {
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
        item.name ?? 'Unknown Item',
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
            GlobalStyle.formatRupiah(item.price ?? 0),
            style: const TextStyle(color: Colors.grey),
          ),
          Text(
            'Quantity: ${item.quantity ?? 0}',
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
      trailing: Text(
        GlobalStyle.formatRupiah((item.price ?? 0) * (item.quantity ?? 0)),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: GlobalStyle.primaryColor,
          fontFamily: GlobalStyle.fontFamily,
        ),
      ),
    );
  }

  // Build driver card with enhanced UI
  Widget _buildDriverCard() {
    String driverImageUrl = '';
    double driverRating = 4.8;

    // Get driver info from driver detail if available
    if (_driverDetail != null) {
      driverImageUrl = _driverDetail!.avatar ?? '';
      driverRating = _driverDetail!.rating;
      _driverName = _driverDetail!.name;
      _vehicleNumber = _driverDetail!.vehiclePlate;
    } else if (_orderDetailData != null && _orderDetailData!['driver'] != null) {
      final driverData = _orderDetailData!['driver'];
      driverImageUrl = driverData['avatar'] ?? '';
      driverRating = (driverData['rating'] ?? 4.8).toDouble();
      _driverName = driverData['name'] ?? _driverName;
      _vehicleNumber = driverData['vehicle_number'] ?? _vehicleNumber;
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
          border: Border.all(
            color: GlobalStyle.primaryColor.withOpacity(0.1),
          ),
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.star, color: Colors.amber, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  driverRating.toStringAsFixed(1),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.motorcycle,
                                color: Colors.grey[700], size: 16),
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
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GlobalStyle.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
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
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[700],
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 2,
                    ),
                    onPressed: () {
                      // Messaging implementation
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

  Widget _buildOrderFailedCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: Colors.red[700], size: 48),
          const SizedBox(height: 16),
          Text(
            'Pesanan Gagal',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _orderFailReason,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red[600]),
          ),
        ],
      ),
    );
  }

  // Load driver details using DriverService.getDriverById()
  Future<void> _loadDriverDetails(String driverId) async {
    try {
      final driverData = await DriverService.getDriverById(driverId);
      _driverDetail = DriverModel.fromJson(driverData);

      setState(() {
        _driverName = _driverDetail?.name ?? 'Unknown Driver';
        _vehicleNumber = _driverDetail?.vehiclePlate ?? 'Unknown';
      });
    } catch (e) {
      print('Error loading driver details: $e');
    }
  }

  // Show driver search dialog
  void _showDriverSearchDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: Colors.white,
            elevation: 5,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Lottie.asset(
                    'assets/animations/loading_animation.json',
                    width: 180,
                    height: 180,
                    repeat: true,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Mencari Driver",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Mohon tunggu sementara kami mencarikan driver terbaik untuk Anda...",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1 + 0.05 * _pulseController.value),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "Maksimal waktu pencarian: 15 menit",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _cancelOrderRequest();
                    },
                    child: Text(
                      "Batalkan Pencarian",
                      style: TextStyle(
                        color: Colors.red.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Show order created success dialog
  Future<void> _showOrderCreatedSuccess() async {
    await _playSound('audio/kring.mp3');

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          elevation: 5,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/animations/check_animation.json',
                  width: 180,
                  height: 180,
                  repeat: false,
                ),
                const SizedBox(height: 20),
                const Text(
                  "Pesanan Berhasil Dibuat",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Pesanan Anda telah diterima dan siap diproses",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Order ID: ${_createdOrder?.id ?? 'N/A'}",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlobalStyle.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 14),
                    elevation: 2,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "OK",
                    style: TextStyle(
                      fontSize: 16,
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

  // Monitor driver assignment using polling
  void _startDriverSearchStream() {
    if (_createdOrder == null) return;

    // Set up the 15-minute timeout timer
    _driverSearchTimer = Timer(const Duration(minutes: 15), () {
      if (mounted && !_driverFound) {
        print('Driver search timeout after 15 minutes');

        Navigator.of(context, rootNavigator: true).pop();

        setState(() {
          _searchingDriver = false;
          _orderFailed = true;
          _orderFailReason = 'Tidak ada driver yang tersedia setelah 15 menit pencarian';
        });

        _playSound('audio/wrong.mp3');
      }
    });

    // Poll for driver assignment every 5 seconds
    Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!mounted || _driverFound || _orderFailed || _orderRejected) {
        timer.cancel();
        return;
      }

      try {
        // Check order status using OrderService.getOrderById()
        final orderDetails = await OrderService.getOrderById(_createdOrder!.id.toString());

        final String orderStatus = orderDetails['orderStatus'] ?? 'pending';

        // Check if order was rejected
        if (orderStatus == 'rejected' || orderStatus == 'cancelled') {
          timer.cancel();
          Navigator.of(context, rootNavigator: true).pop();

          setState(() {
            _searchingDriver = false;
            _orderRejected = true;
            _orderFailReason = orderStatus == 'rejected'
                ? 'Pesanan ditolak oleh toko'
                : 'Pesanan dibatalkan';
          });

          _driverSearchTimer?.cancel();
          _playSound('audio/wrong.mp3');
          return;
        }

        // Check if a driver has been assigned
        if (orderDetails['driver'] != null && !_driverFound) {
          timer.cancel();
          Navigator.of(context, rootNavigator: true).pop();

          _driverSearchTimer?.cancel();

          // Load driver details
          final driverId = orderDetails['driver']['id'];
          await _loadDriverDetails(driverId.toString());

          setState(() {
            _driverFound = true;
            _searchingDriver = false;
            _orderFailed = false;
            _orderRejected = false;
          });

          _driverCardController.forward();
          _playSound('audio/kring.mp3');
          _showDriverFoundDialog();
          _checkOrderStatus();
          _startOrderTracking();
          _statusCardController.forward();
        }
      } catch (e) {
        print('Error checking order status: $e');
      }
    });
  }

  // Setup periodic order status updates using OrderService.getOrderById()
  void _startOrderTracking() {
    _checkOrderStatus();

    Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted && _createdOrder != null) {
        _checkOrderStatus();

        if (_createdOrder!.orderStatus.isCompleted ||
            _createdOrder!.orderStatus == OrderStatus.cancelled) {
          timer.cancel();
        }
      } else {
        timer.cancel();
      }
    });
  }

  // Check current order status using OrderService.getOrderById()
  Future<void> _checkOrderStatus() async {
    if (_createdOrder == null) return;

    try {
      final orderDetails = await OrderService.getOrderById(_createdOrder!.id.toString());

      setState(() {
        _orderDetailData = orderDetails;

        // Update order object
        _createdOrder = OrderModel.fromJson(orderDetails);

        // If driver is newly assigned
        if (orderDetails['driver'] != null && !_driverFound) {
          _driverFound = true;
          _driverCardController.forward();

          final driverId = orderDetails['driver']['id'];
          _loadDriverDetails(driverId.toString());

          _driverSearchTimer?.cancel();

          _searchingDriver = false;
          _orderFailed = false;
          _orderRejected = false;

          _showDriverFoundDialog();
        }

        // Check if order is completed
        final currentStatus = orderDetails['orderStatus'] ?? '';
        if (currentStatus == 'delivered' || currentStatus == 'completed') {
          _checkOrderRatingStatus();
        }

        // Check if order was rejected or cancelled
        if (currentStatus == 'rejected' || currentStatus == 'cancelled') {
          _orderRejected = true;
          _orderFailReason = currentStatus == 'rejected'
              ? 'Pesanan ditolak oleh toko'
              : 'Pesanan dibatalkan';
        }
      });
    } catch (e) {
      print('Error checking order status: $e');
    }
  }

  // Cancel current order request using OrderService.cancelOrder()
  Future<void> _cancelOrderRequest() async {
    if (_createdOrder == null) return;

    try {
      setState(() {
        _isLoading = true;
      });

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
      setState(() {
        _isLoading = false;
      });
      print('Error cancelling order: $e');
      await _showErrorDialog('Cancel Failed', 'Failed to cancel order. Please try again.');
    }
  }

  // Show driver found dialog with improved UI
  Future<void> _showDriverFoundDialog() async {
    await _playSound('audio/kring.mp3');

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          elevation: 5,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Lottie.asset(
                      'assets/animations/driver_found.json',
                      width: 200,
                      height: 200,
                      repeat: false,
                    ),
                    Positioned(
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          "Driver Ditemukan!",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _driverName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    "Nomor Kendaraan: $_vehicleNumber",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Driver telah menerima pesanan Anda dan akan segera menuju ke toko",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlobalStyle.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 14),
                    elevation: 2,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "OK",
                    style: TextStyle(
                      fontSize: 16,
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
  // Handle rating button press
  void _handleRatingPress() {
    if (widget.completedOrder != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RatingCustomerPage(order: widget.completedOrder!),
        ),
      ).then((_) {
        _checkOrderRatingStatus();
      });
    }
  }

  // Handle buy again button press
  void _handleBuyAgain() {
    // You can implement navigation to the store or cart with the same items
    Navigator.pop(context); // Example: just go back for now
  }
}

