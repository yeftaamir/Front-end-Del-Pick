import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'dart:async';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Models/menu_item.dart';
import 'package:del_pick/Views/Customers/location_access.dart';
import 'package:del_pick/Views/Customers/history_detail.dart';
import 'package:del_pick/Models/store.dart';
import 'package:del_pick/Models/order.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geocoding/geocoding.dart';
import 'package:lucide_icons/lucide_icons.dart';

// Import required services
import 'package:del_pick/Services/order_service.dart';
import 'package:del_pick/Services/store_service.dart';
import 'package:del_pick/Services/image_service.dart';
import 'package:del_pick/Services/auth_service.dart';

import '../../Models/order_enum.dart';

class CartScreen extends StatefulWidget {
  static const String route = "/Customers/Cart";
  final int storeId;
  final List<MenuItemModel> cartItems;
  final Map<int, int>? itemQuantities;

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
  bool _isCreatingOrder = false;

  // Location specific variables
  bool _isLoadingLocation = false;
  bool _hasLocationPermission = false;
  Position? _currentPosition;
  String? _userLocation = '';
  Map<String, dynamic>? _userData;

  // Store data
  StoreModel? _storeDetail;

  // Audio player instance
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Animation controllers
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late List<AnimationController> _cardControllers;
  late List<Animation<Offset>> _cardAnimations;

  // Helper to get item quantity from external map
  int _getItemQuantity(MenuItemModel item) {
    return widget.itemQuantities?[item.id] ?? 0;
  }

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeStoreLocation();
    _loadInitialData();
    _initializeLocation();
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
      4, // Location, items, payment, submit button
          (index) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 600 + (index * 100)),
      ),
    );

    _cardAnimations = _cardControllers.map((controller) {
      return Tween<Offset>(
        begin: const Offset(0, 0.3),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeOutCubic,
      ));
    }).toList();

    _startCardAnimations();
  }

  void _startCardAnimations() {
    for (int i = 0; i < _cardControllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted && _cardControllers[i].isCompleted == false) {
          _cardControllers[i].forward();
        }
      });
    }
  }

  void _initializeStoreLocation() {
    // Use data from store_detail if available
    if (widget.storeLatitude != null && widget.storeLongitude != null) {
      _storeLatitude = widget.storeLatitude;
      _storeLongitude = widget.storeLongitude;
      print('✅ CartScreen: Store location initialized: $_storeLatitude, $_storeLongitude');
    }

    if (widget.storeDistance != null) {
      _storeDistance = widget.storeDistance;
      print('✅ CartScreen: Store distance initialized: $_storeDistance km');
    }

    if (widget.customerAddress != null) {
      _deliveryAddress = widget.customerAddress;
      print('✅ CartScreen: Customer address initialized: $_deliveryAddress');
    }

    if (widget.customerLatitude != null && widget.customerLongitude != null) {
      _latitude = widget.customerLatitude;
      _longitude = widget.customerLongitude;
      print('✅ CartScreen: Customer location initialized: $_latitude, $_longitude');
    }

    _calculateInitialDeliveryFee();
  }

  void _calculateInitialDeliveryFee() {
    if (_storeDistance != null) {
      setState(() {
        double fee = calculateDeliveryFee(_storeDistance!);
        _serviceCharge = (fee % 1000 == 0) ? fee : ((fee / 1000).ceil() * 1000);
      });
      print('✅ CartScreen: Initial delivery fee calculated: ${GlobalStyle.formatRupiah(_serviceCharge)}');
      return;
    }

    if (_latitude != null && _longitude != null &&
        _storeLatitude != null && _storeLongitude != null) {
      _updateDeliveryFee();
      print('✅ CartScreen: Initial delivery fee calculated from coordinates');
    } else {
      print('⚠️ CartScreen: Cannot calculate initial delivery fee - missing location data');
    }
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Validate customer access
      final hasAccess = await AuthService.validateCustomerAccess();
      if (!hasAccess) {
        throw Exception('Invalid customer access');
      }

      // Get user data
      _userData = await AuthService.getCustomerData();
      if (_userData == null) {
        throw Exception('Unable to get customer data');
      }

      // Get store details if location is not available
      if (_storeLatitude == null || _storeLongitude == null) {
        final storeData = await StoreService.getStoreById(widget.storeId.toString());

        if (storeData['success'] == true && storeData['data'] != null) {
          final store = storeData['data'];
          _storeDetail = StoreModel.fromJson(store);

          if (_storeDetail != null) {
            _storeLatitude = _storeDetail!.latitude;
            _storeLongitude = _storeDetail!.longitude;
            print('✅ CartScreen: Store location loaded from API: $_storeLatitude, $_storeLongitude');
            _updateDeliveryFee();
          }
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load data: $e';
        _isLoading = false;
      });
      print('Error loading initial data: $e');
    }
  }

  void _initializeLocation() {
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      var status = await Permission.location.status;
      if (!status.isGranted) {
        status = await Permission.location.request();
        if (!status.isGranted) {
          throw Exception('Location permission denied');
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      String locationText = await _getAddressFromCoordinates(position);

      setState(() {
        _currentPosition = position;
        _latitude = position.latitude;
        _longitude = position.longitude;
        _userLocation = locationText;

        if (_deliveryAddress == null || _deliveryAddress!.isEmpty) {
          _deliveryAddress = locationText;
        }

        _hasLocationPermission = true;
        _isLoadingLocation = false;
      });

      print('✅ CartScreen: User location obtained: $_latitude, $_longitude');
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

  void _updateDeliveryFee() {
    print('🔄 CartScreen: Attempting to update delivery fee...');
    print('   - User location: $_latitude, $_longitude');
    print('   - Store location: $_storeLatitude, $_storeLongitude');

    if (_latitude != null && _longitude != null &&
        _storeLatitude != null && _storeLongitude != null) {

      _storeDistance = calculateDistance(
          _latitude!, _longitude!, _storeLatitude!, _storeLongitude!);

      final calculatedFee = calculateDeliveryFee(_storeDistance!);

      setState(() {
        _serviceCharge = calculatedFee;
      });

      print('✅ CartScreen: Delivery fee updated successfully!');
      print('   - Distance: ${_getFormattedDistance()}');
      print('   - Fee: ${GlobalStyle.formatRupiah(_serviceCharge)}');
    } else {
      print('⚠️ CartScreen: Cannot update delivery fee - missing location data');
    }
  }

  double calculateDeliveryFee(double distance) {
    double rawFee = distance * 2500;
    double roundedFee = rawFee.ceilToDouble();
    return roundedFee;
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    double distanceInMeters = Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
    return distanceInMeters / 1000;
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
    return 'Balige, North Sumatra';
  }

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

  @override
  void dispose() {
    _slideController.dispose();
    _pulseController.dispose();
    for (var controller in _cardControllers) {
      controller.dispose();
    }
    _audioPlayer.dispose();
    super.dispose();
  }

  double get subtotal {
    double total = 0;
    for (var item in widget.cartItems) {
      final quantity = _getItemQuantity(item);
      total += item.price * quantity;
    }
    return total;
  }

  double get total {
    return subtotal + _serviceCharge;
  }

  Future<void> _playSound(String assetPath) async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource(assetPath));
    } catch (e) {
      print('Error playing sound: $e');
    }
  }

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
                SizedBox(
                  height: 180,
                  width: 180,
                  child: Lottie.asset(
                    'assets/animations/caution.json',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.warning_amber_rounded,
                        size: 100,
                        color: Colors.orange,
                      );
                    },
                  ),
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

  Future<void> _createOrder() async {
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

    // Validate customer access
    final hasAccess = await AuthService.validateCustomerAccess();
    if (!hasAccess) {
      await _showErrorDialog(
          'Akses Ditolak',
          'Anda harus login sebagai customer untuk membuat pesanan.'
      );
      return;
    }

    setState(() {
      _isCreatingOrder = true;
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
                  SizedBox(
                    width: 150,
                    height: 150,
                    child: Lottie.asset(
                      'assets/animations/loading_animation.json',
                      repeat: true,
                      errorBuilder: (context, error, stackTrace) {
                        return CircularProgressIndicator(
                          color: GlobalStyle.primaryColor,
                        );
                      },
                    ),
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

      // Close creating order dialog
      Navigator.of(context, rootNavigator: true).pop();

      if (orderResponse.isNotEmpty && orderResponse['id'] != null) {
        // Show success and get order details
        await _showOrderCreatedSuccess(orderResponse['id'].toString());

        // Get full order details for navigation
        final orderDetails = await OrderService.getOrderById(orderResponse['id'].toString());
        final createdOrder = OrderModel.fromJson(orderDetails);

        setState(() {
          _isCreatingOrder = false;
        });

        // Navigate to history detail page
        Navigator.pushReplacementNamed(
          context,
          HistoryDetailPage.route,
          arguments: createdOrder,
        );
      } else {
        throw Exception('Order created but no order ID returned');
      }
    } catch (e) {
      print('Error creating order: $e');

      Navigator.of(context, rootNavigator: true).pop();

      setState(() {
        _isCreatingOrder = false;
      });

      await _showErrorDialog(
          'Gagal Membuat Pesanan',
          'Terjadi kesalahan saat membuat pesanan: $e'
      );
    }
  }

  Future<void> _showOrderCreatedSuccess(String orderId) async {
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
                SizedBox(
                  width: 180,
                  height: 180,
                  child: Lottie.asset(
                    'assets/animations/check_animation.json',
                    repeat: false,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.check_circle,
                        size: 100,
                        color: Colors.green,
                      );
                    },
                  ),
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
                  "Order ID: $orderId",
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

  @override
  Widget build(BuildContext context) {
    String storeName = 'Pesanan';
    if (_storeDetail != null) {
      storeName = _storeDetail!.name;
    }

    return Scaffold(
      backgroundColor: const Color(0xffF0F7FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Keranjang Pesanan',
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
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 150,
              height: 150,
              child: Lottie.asset(
                'assets/animations/loading_animation.json',
                errorBuilder: (context, error, stackTrace) {
                  return CircularProgressIndicator(
                    color: GlobalStyle.primaryColor,
                  );
                },
              ),
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
          : widget.cartItems.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 200,
              height: 200,
              child: Lottie.asset(
                'assets/animations/empty_cart.json',
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.shopping_cart_outlined,
                    size: 100,
                    color: Colors.grey[400],
                  );
                },
              ),
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
              // Location card
              _buildCard(
                index: 0,
                child: _buildLocationCard(),
              ),

              // Order items
              _buildCard(
                index: 1,
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
                          Text(
                            storeName,
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

              // Payment details
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
                            if (_storeDistance != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    const SizedBox(width: 4),
                                    Text(
                                      'Jarak: ${_getFormattedDistance()} × Rp 2.500/km ',
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
                              'Pembayaran hanya menerima tunai saat ini.',
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

              // Add some bottom spacing
              const SizedBox(height: 100),
            ],
          ),

          // Order button
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
                onPressed: _isCreatingOrder || _isLoading ? null : _createOrder,
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
                child: _isCreatingOrder || _isLoading
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

  Widget _buildCard({required int index, required Widget child}) {
    final safeIndex = index < _cardAnimations.length ? index : 0;

    return SlideTransition(
      position: _cardAnimations[safeIndex],
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
}