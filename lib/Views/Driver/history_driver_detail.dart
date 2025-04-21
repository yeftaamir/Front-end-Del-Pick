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
import 'package:geotypes/geotypes.dart' as geotypes;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

// Services
import 'package:del_pick/Services/order_service.dart';
import 'package:del_pick/Services/driver_service.dart';
import 'package:del_pick/Services/tracking_service.dart';
import 'package:del_pick/Services/image_service.dart';
import 'package:del_pick/Services/Core/token_service.dart';
import 'dart:convert';

import '../../Models/order_enum.dart';

class HistoryDriverDetailPage extends StatefulWidget {
  static const String route = '/Driver/HistoryDriverDetail';
  final Map<String, dynamic> orderDetail;
  final bool showTrackButton;
  final VoidCallback? onTrackPressed;

  const HistoryDriverDetailPage({
    Key? key,
    required this.orderDetail,
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
  Map<String, dynamic>? _orderData;
  Map<String, dynamic>? _trackingData;
  Driver? _driverData;
  StoreModel? _storeData;
  List<Item> _orderItems = [];
  bool _isLoading = true;
  String _currentStatus = '';
  String _orderCode = '';
  bool _isFetchingStatus = false;

  // Map related variables
  MapboxMap? mapboxMap;
  PointAnnotationManager? pointAnnotationManager;
  PolylineAnnotationManager? polylineAnnotationManager;
  bool _isMapExpanded = false;
  final GlobalKey _mapKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    // Initialize orderId from widget.orderDetail
    _orderId = widget.orderDetail['orderId'] ?? '';
    _currentStatus = widget.orderDetail['status'] ?? '';
    _orderCode = widget.orderDetail['code'] ?? '';

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

  // Fetch order data from API
  Future<void> _fetchOrderData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Get driver data from token
      await _getDriverData();

      // Get order details
      await _getOrderDetails();

      // Get tracking data if available
      if (_orderId.isNotEmpty) {
        await _getTrackingData();
      }

    } catch (e) {
      print('Error fetching order data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Get driver data from token
  Future<void> _getDriverData() async {
    try {
      final String? rawUserData = await TokenService.getUserData();
      if (rawUserData != null) {
        final Map<String, dynamic> userData = json.decode(rawUserData);
        if (userData['data'] != null && userData['data']['driver'] != null) {
          final driverId = userData['data']['driver']['id'];
          if (driverId != null) {
            final driverData = await DriverService.getDriverById(driverId.toString());
            setState(() {
              _driverData = Driver.fromJson(driverData);
            });
          }
        }
      }
    } catch (e) {
      print('Error getting driver data: $e');
    }
  }

  // Get order details
  Future<void> _getOrderDetails() async {
    try {
      if (_orderId.isNotEmpty) {
        final orderData = await OrderService.getOrderById(_orderId);

        setState(() {
          _orderData = orderData;

          // Update status if available
          if (orderData['delivery_status'] != null) {
            _currentStatus = orderData['delivery_status'];
          } else if (orderData['status'] != null) {
            _currentStatus = orderData['status'];
          }

          // Get store data
          if (orderData['store'] != null) {
            _storeData = StoreModel.fromJson(orderData['store']);
          }

          // Get order items
          if (orderData['items'] != null && orderData['items'] is List) {
            _orderItems = (orderData['items'] as List)
                .map((item) => Item.fromJson(item))
                .toList();
          }

          // Get order code
          _orderCode = orderData['code'] ?? _orderCode;
        });
      } else {
        // If no orderId, use the provided orderDetail directly
        setState(() {
          _orderData = widget.orderDetail;

          // Extract items if available
          if (widget.orderDetail['items'] != null && widget.orderDetail['items'] is List) {
            _orderItems = (widget.orderDetail['items'] as List)
                .map((item) => Item.fromJson(item))
                .toList();
          }
        });
      }
    } catch (e) {
      print('Error getting order details: $e');
    }
  }

  // Get tracking data
  Future<void> _getTrackingData() async {
    try {
      final trackingData = await TrackingService.getOrderTracking(_orderId);
      setState(() {
        _trackingData = trackingData;
      });
    } catch (e) {
      print('Error getting tracking data: $e');
    }
  }

  // Update order status for driver - using the correct endpoint for driver actions
  Future<void> _updateOrderStatus(String status) async {
    if (_isFetchingStatus) return;

    setState(() {
      _isFetchingStatus = true;
    });

    try {
      // Only perform API call if we have a valid order ID
      if (_orderId.isNotEmpty) {
        // Use driver-specific endpoint for status updates
        await OrderService.processOrderByStore(_orderId, status);

        // Play sound
        _playSound('audio/alert.wav');

        // Update local status
        setState(() {
          _currentStatus = status;
        });

        // Refresh order data and tracking data after update
        await _getOrderDetails();
        await _getTrackingData();

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Status pengantaran diperbarui menjadi: ${_getStatusDisplayName(status)}')),
          );
        }
      } else {
        // For demo purposes, just update local state
        setState(() {
          _currentStatus = status;
        });

        // Play sound
        _playSound('audio/alert.wav');
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

  // Helper to get display name for status
  String _getStatusDisplayName(String status) {
    switch (status.toLowerCase()) {
      case 'assigned':
        return 'Driver Ditugaskan';
      case 'picking_up':
        return 'Pengambilan Pesanan';
      case 'on_delivery':
        return 'Dalam Pengantaran';
      case 'delivered':
        return 'Pesanan Diterima';
      case 'completed':
        return 'Pesanan Selesai';
      case 'cancelled':
        return 'Pesanan Dibatalkan';
      default:
        return status;
    }
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
                        _cancelOrder();
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

  // Cancel order
  Future<void> _cancelOrder() async {
    try {
      // Play sound
      _playSound('audio/alert.wav');

      if (_orderId.isNotEmpty) {
        await OrderService.cancelOrder(_orderId, 'Dibatalkan oleh driver');
        setState(() {
          _currentStatus = 'cancelled';
        });

        // Refresh order data after cancellation
        await _getOrderDetails();
        await _getTrackingData();
      } else {
        setState(() {
          _currentStatus = 'cancelled';
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengantaran dibatalkan')),
      );
    } catch (e) {
      print('Error cancelling order: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membatalkan pengantaran: $e')),
      );
    }
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
                        Navigator.of(context).pop();
                        _updateOrderStatus('picking_up');
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

  // Show confirmation dialog for completing order
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
                const Text(
                  'Selesaikan Pengantaran?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Pastikan pelanggan telah menerima pesanan dengan baik',
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

  // Complete the delivery
  Future<void> _completeDelivery() async {
    await _updateOrderStatus('delivered');
    _showCompletionDialog();
  }

  void _navigateToTrackOrder() async {
    // Play alert sound when changing status
    _playSound('audio/alert.wav');

    if (_currentStatus == 'picking_up') {
      // Update to on_delivery before tracking
      await _updateOrderStatus('on_delivery');
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TrackOrderScreen(
          orderId: _orderId,
          order: _orderData != null && _storeData != null ?
          Order.fromJson(_orderData!) : null,
        ),
      ),
    );

    if (result == 'completed') {
      await _updateOrderStatus('delivered');
      _showCompletionDialog();
    }
  }

  Future<void> _openWhatsApp(String phoneNumber) async {
    // Format phone number correctly
    String formattedPhone = phoneNumber;
    if (phoneNumber.startsWith('0')) {
      formattedPhone = '62${phoneNumber.substring(1)}';
    } else if (!phoneNumber.startsWith('+') && !phoneNumber.startsWith('62')) {
      formattedPhone = '62$phoneNumber';
    }

    String message = 'Halo, saya driver dari Del Pick mengenai pesanan Anda...';
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

  // Setup map functionality
  void _onMapCreated(MapboxMap mapboxMap) {
    this.mapboxMap = mapboxMap;
    _setupAnnotationManagers().then((_) {
      _updateMapAnnotations();
    });
  }

  Future<void> _setupAnnotationManagers() async {
    pointAnnotationManager = await mapboxMap?.annotations.createPointAnnotationManager();
    polylineAnnotationManager = await mapboxMap?.annotations.createPolylineAnnotationManager();
  }

  // Update map annotations with the latest position data
  Future<void> _updateMapAnnotations() async {
    // If tracking data is available, draw markers and route
    if (_trackingData != null) {
      _addMarkers();
      _drawRoute();
    }
  }

  // Add markers for driver, store, and customer locations
  Future<void> _addMarkers() async {
    if (pointAnnotationManager == null) return;

    // Clear existing annotations
    await pointAnnotationManager?.deleteAll();

    // Extract positions from tracking data
    final driverLat = _trackingData?['driver']?['latitude'] ?? 0.0;
    final driverLng = _trackingData?['driver']?['longitude'] ?? 0.0;
    final storeLat = _storeData?.latitude ?? _orderData?['store']?['latitude'] ?? 0.0;
    final storeLng = _storeData?.longitude ?? _orderData?['store']?['longitude'] ?? 0.0;
    final customerLat = _orderData?['delivery_latitude'] ?? _orderData?['user']?['latitude'] ?? 0.0;
    final customerLng = _orderData?['delivery_longitude'] ?? _orderData?['user']?['longitude'] ?? 0.0;

    // Customer marker
    final customerOptions = PointAnnotationOptions(
      geometry: Point(coordinates: Position(customerLng, customerLat)),
      iconImage: "assets/images/marker_red.png",
    );

    // Store marker
    final storeOptions = PointAnnotationOptions(
      geometry: Point(coordinates: Position(storeLng, storeLat)),
      iconImage: "assets/images/marker_blue.png",
    );

    // Driver marker
    final driverOptions = PointAnnotationOptions(
      geometry: Point(coordinates: Position(driverLng, driverLat)),
      iconImage: "assets/images/marker_green.png",
    );

    await pointAnnotationManager?.create(customerOptions);
    await pointAnnotationManager?.create(storeOptions);
    await pointAnnotationManager?.create(driverOptions);
  }

  // Draw route between points
  Future<void> _drawRoute() async {
    if (polylineAnnotationManager == null) return;

    // Clear existing annotations
    await polylineAnnotationManager?.deleteAll();

    // Extract positions from tracking data
    final driverLat = _trackingData?['driver']?['latitude'] ?? 0.0;
    final driverLng = _trackingData?['driver']?['longitude'] ?? 0.0;
    final storeLat = _storeData?.latitude ?? _orderData?['store']?['latitude'] ?? 0.0;
    final storeLng = _storeData?.longitude ?? _orderData?['store']?['longitude'] ?? 0.0;
    final customerLat = _orderData?['delivery_latitude'] ?? _orderData?['user']?['latitude'] ?? 0.0;
    final customerLng = _orderData?['delivery_longitude'] ?? _orderData?['user']?['longitude'] ?? 0.0;

    // Create route based on current delivery status
    List<Position> routeCoordinates = [];

    if (_currentStatus == 'assigned' || _currentStatus == 'picking_up') {
      // Route from driver to store
      routeCoordinates = [
        Position(driverLng, driverLat),
        Position(storeLng, storeLat),
      ];
    } else if (_currentStatus == 'on_delivery') {
      // Route from driver to customer (possibly via store)
      routeCoordinates = [
        Position(driverLng, driverLat),
        Position(customerLng, customerLat),
      ];
    }

    final polylineOptions = PolylineAnnotationOptions(
      geometry: LineString(coordinates: routeCoordinates),
      lineColor: Colors.blue.value,
      lineWidth: 3.0,
    );

    await polylineAnnotationManager?.create(polylineOptions);
  }

  // Convert the current status to OrderStatus enum
  OrderStatus _getOrderStatus() {
    switch (_currentStatus.toLowerCase()) {
      case 'assigned':
        return OrderStatus.driverAssigned;
      case 'picking_up':
        return OrderStatus.driverAtStore;
      case 'on_delivery':
        return OrderStatus.driverHeadingToCustomer;
      case 'delivered':
        return OrderStatus.delivered;
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
    // Create Store object
    final store = _storeData ?? StoreModel(
      name: _orderData?['store']?['name'] ?? '',
      address: _orderData?['store']?['address'] ?? '',
      openHours: '08:00 - 22:00', // Default value if not available
      rating: 4.5, // Default value if not available
      reviewCount: 0,
      phoneNumber: _orderData?['store']?['phone'] ?? '',
    );

    // Create tracking object if available
    Tracking? tracking;
    if (_trackingData != null && _driverData != null) {
      // Get positions from tracking data
      final driverLat = _trackingData?['driver']?['latitude'] ?? 0.0;
      final driverLng = _trackingData?['driver']?['longitude'] ?? 0.0;
      final storeLat = _orderData?['store']?['latitude'] ?? 0.0;
      final storeLng = _orderData?['store']?['longitude'] ?? 0.0;
      final customerLat = _orderData?['user']?['latitude'] ?? 0.0;
      final customerLng = _orderData?['user']?['longitude'] ?? 0.0;

      tracking = Tracking(
        orderId: _orderId,
        driver: _driverData!,
        driverPosition: geotypes.Position(driverLng, driverLat),
        customerPosition: geotypes.Position(customerLng, customerLat),
        storePosition: geotypes.Position(storeLng, storeLat),
        routeCoordinates: [
          geotypes.Position(driverLng, driverLat),
          geotypes.Position(storeLng, storeLat),
          geotypes.Position(customerLng, customerLat),
        ],
        status: _getOrderStatus(),
        estimatedArrival: DateTime.now().add(const Duration(minutes: 15)),
        customStatusMessage: _getStatusMessage(_getOrderStatus()),
      );
    }

    // Create Order object
    final order = Order(
      id: _orderId,
      code: _orderCode,
      items: _orderItems,
      store: store,
      deliveryAddress: _orderData?['delivery_address'] ?? '',
      subtotal: double.tryParse(_orderData?['subtotal']?.toString() ?? '0') ?? 0,
      serviceCharge: double.tryParse(_orderData?['service_charge']?.toString() ?? '0') ?? 0,
      total: double.tryParse(_orderData?['total']?.toString() ?? '0') ?? 0,
      orderDate: _orderData?['created_at'] != null
          ? DateTime.parse(_orderData!['created_at'])
          : DateTime.now(),
      status: _getOrderStatus(),
      tracking: tracking,
    );

    return OrderStatusCard(
      order: order,
      animation: _cardAnimations[0],
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
      case OrderStatus.delivered:
        return 'Pesanan Anda telah selesai';
      case OrderStatus.cancelled:
        return 'Pesanan Anda dibatalkan';
      default:
        return 'Pesanan sedang diproses';
    }
  }

  Widget _buildMapWidget() {
    // Extract positions from tracking data or order data
    final driverLat = _trackingData?['driver']?['latitude'] ?? 0.0;
    final driverLng = _trackingData?['driver']?['longitude'] ?? 0.0;
    final storeLat = _storeData?.latitude ?? _orderData?['store']?['latitude'] ?? 0.0;
    final storeLng = _storeData?.longitude ?? _orderData?['store']?['longitude'] ?? 0.0;

    // Center map on driver location
    return _buildCard(
      index: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.map, color: GlobalStyle.primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'Lokasi Pengantaran',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: GlobalStyle.fontColor,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _isMapExpanded = !_isMapExpanded;
                    });
                  },
                  icon: Icon(
                    _isMapExpanded ? Icons.fullscreen_exit : Icons.fullscreen,
                    color: GlobalStyle.primaryColor,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: _isMapExpanded ? 300 : 150,
            key: _mapKey,
            child: MapWidget(
              key: ValueKey("MapWidget-Order-$_orderId"),
              onMapCreated: _onMapCreated,
              styleUri: "mapbox://styles/ifs21002/cm71crfz300sw01s10wsh3zia",
              cameraOptions: CameraOptions(
                center: Point(coordinates: Position(driverLng, driverLat)),
                zoom: 13.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreInfoCard() {
    final storeName = _orderData?['store']?['name'] ?? widget.orderDetail['storeName'] ?? '';
    final storeAddress = _orderData?['store']?['address'] ?? widget.orderDetail['storeAddress'] ?? '';
    final storePhone = _orderData?['store']?['phone'] ?? widget.orderDetail['storePhone'] ?? '';
    final storeImage = _orderData?['store']?['image'] ?? widget.orderDetail['storeImage'] ?? '';
    final storeRating = _orderData?['store']?['rating'] ?? 4.5; // Default if not available

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
                    imageSource: storeImage,
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
                      child: Center(
                        child: Icon(
                          Icons.store,
                          size: 30,
                          color: Colors.grey[400],
                        ),
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
                        storeName,
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
                              storeAddress,
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
                            storeRating.toString(),
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
                      _openWhatsApp(storePhone);
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
                      _openWhatsApp(storePhone);
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
    final customerName = _orderData?['user']?['name'] ?? widget.orderDetail['customerName'] ?? '';
    final customerAddress = _orderData?['delivery_address'] ?? widget.orderDetail['customerAddress'] ?? '';
    final customerPhone = _orderData?['user']?['phone'] ?? widget.orderDetail['customerPhone'] ?? '';
    final customerAvatar = _orderData?['user']?['avatar'] ?? '';

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
                customerAvatar.isNotEmpty ?
                ClipOval(
                  child: ImageService.displayImage(
                    imageSource: customerAvatar,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                  ),
                ) :
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
                        customerName,
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
                              customerAddress,
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
                            customerPhone,
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
                      _openWhatsApp(customerPhone);
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
                      _openWhatsApp(customerPhone);
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
    final totalAmount = double.tryParse(_orderData?['total'].toString() ?? '0') ??
        (widget.orderDetail['amount'] as num?)?.toDouble() ?? 0.0;
    final deliveryFee = double.tryParse(_orderData?['service_charge'].toString() ?? '0') ??
        (widget.orderDetail['deliveryFee'] as num?)?.toDouble() ?? 0.0;

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
            ..._orderItems.map((item) =>
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
                        child: ImageService.displayImage(
                          imageSource: item.imageUrl,
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              GlobalStyle.formatRupiah(item.price),
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
                          'x${item.quantity}',
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
    // Get review data from orderData if available
    final double rating = double.tryParse(_orderData?['driver_rating']?.toString() ?? '0') ?? 0.0;
    final String review = _orderData?['driver_review'] as String? ?? '';

    return _buildCard(
      index: 0,
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
                  _driverData?.profileImageUrl != null && _driverData!.profileImageUrl!.isNotEmpty ?
                  ClipOval(
                    child: ImageService.displayImage(
                      imageSource: _driverData!.profileImageUrl!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  ) :
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
                          _driverData?.name ?? 'Driver',
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
                                _driverData?.vehicleNumber ?? 'No. Kendaraan',
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

  Widget _buildLoadingIndicator() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Memuat data...'),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_isFetchingStatus) {
      return Center(
        child: CircularProgressIndicator(),
      );
    }

    OrderStatus status = _getOrderStatus();

    // If order is cancelled, don't show action buttons
    if (status == OrderStatus.cancelled || _currentStatus == 'cancelled') {
      return const SizedBox.shrink();
    }

    // If order is completed, don't show action buttons
    if (status == OrderStatus.completed || status == OrderStatus.delivered ||
        _currentStatus == 'completed' || _currentStatus == 'delivered') {
      return const SizedBox.shrink();
    }

    // Driver assigned - show pickup button
    if (status == OrderStatus.driverAssigned || _currentStatus == 'assigned') {
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
    }
    // Driver at store - show start delivery button
    else if (status == OrderStatus.driverAtStore || _currentStatus == 'picking_up') {
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
              onPressed: () {
                _playSound('audio/alert.wav');
                _updateOrderStatus('on_delivery');
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
                'Mulai Pengantaran',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      );
    }
    // On delivery - show track and complete delivery buttons
    else if (status == OrderStatus.driverHeadingToCustomer || _currentStatus == 'on_delivery') {
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
              onPressed: _navigateToTrackOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
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
          const SizedBox(width: 8),
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
              child: const Text(
                'Selesai',
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
        child: _isLoading
            ? _buildLoadingIndicator()
            : SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOrderStatusCard(),
                const SizedBox(height: 16),
                if (_trackingData != null)
                  _buildMapWidget(),
                const SizedBox(height: 16),
                _buildItemsCard(),
                const SizedBox(height: 16),
                _buildStoreInfoCard(),
                const SizedBox(height: 16),
                _buildCustomerInfoCard(),
                // Only show the review card if order is completed
                if (_getOrderStatus() == OrderStatus.completed || _currentStatus == 'delivered' || _currentStatus == 'completed')
                  Column(
                    children: [
                      const SizedBox(height: 16),
                      _buildDriverReviewCard(),
                    ],
                  ),
                const SizedBox(height: 80), // Extra space at bottom for the action buttons
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _isLoading
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