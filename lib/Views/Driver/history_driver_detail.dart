import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:lottie/lottie.dart';
import 'package:del_pick/Models/order.dart';
import 'package:del_pick/Models/tracking.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:del_pick/Models/menu_item.dart';
import 'package:del_pick/Models/driver.dart';
import 'package:del_pick/Models/store.dart';
import 'package:del_pick/Models/user.dart';
import 'package:geotypes/geotypes.dart' as geotypes;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

// Services
import 'package:del_pick/Services/order_service.dart';
import 'package:del_pick/Services/driver_service.dart';
import 'package:del_pick/Services/driver_request.dart'; // Updated import
import 'package:del_pick/Services/tracking_service.dart';
import 'package:del_pick/Services/image_service.dart';
import 'package:del_pick/Services/Core/token_service.dart';
import 'package:del_pick/Services/auth_service.dart';
import 'package:del_pick/Services/store_service.dart';
import 'dart:convert';

import '../../Models/order_enum.dart';
import '../Component/driver_order_status.dart';

class HistoryDriverDetailPage extends StatefulWidget {
  static const String route = '/Driver/HistoryDriverDetail';
  final Map<String, dynamic>? orderDetail;
  final String? orderId;
  final bool showTrackButton;
  final VoidCallback? onTrackPressed;

  const HistoryDriverDetailPage({
    Key? key,
    this.orderDetail,
    this.orderId,
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
  Order? _order;
  Map<String, dynamic>? _orderData;
  Map<String, dynamic>? _trackingData;
  Map<String, dynamic>? _driverRequestData;
  Driver? _driverData;
  Store? _storeData;
  User? _customerData;
  List<MenuItem> _orderItems = [];
  bool _isLoading = true;
  OrderStatus _currentOrderStatus = OrderStatus.pending;
  DeliveryStatus _currentDeliveryStatus = DeliveryStatus.pending;
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

    // Initialize orderId from widget parameters
    _orderId = widget.orderId ?? widget.orderDetail?['id']?.toString() ?? '';
    if (_orderId.isEmpty && widget.orderDetail?['orderId'] != null) {
      _orderId = widget.orderDetail!['orderId'].toString();
    }

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
          if (mounted) _cardControllers[i].forward();
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

  // Fetch order data from API using correct services
  Future<void> _fetchOrderData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Get driver data from token/profile
      await _getDriverData();

      // Get order details using OrderService.getOrderById
      if (_orderId.isNotEmpty) {
        await _getOrderDetails();
      } else {
        // Use provided orderDetail if no orderId
        _processProvidedOrderDetail();
      }

      // Get driver request data if available
      if (_orderId.isNotEmpty) {
        await _getDriverRequestData();
      }

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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Get driver data from AuthService
  Future<void> _getDriverData() async {
    try {
      final profileData = await AuthService.getProfile();

      if (profileData.containsKey('driver')) {
        setState(() {
          _driverData = Driver.fromJson(profileData['driver']);
        });
      } else {
        // Fallback to get user data from storage
        final userData = await AuthService.getUserData();
        if (userData != null && userData['driver'] != null) {
          setState(() {
            _driverData = Driver.fromJson(userData['driver']);
          });
        }
      }
    } catch (e) {
      print('Error getting driver data: $e');
    }
  }

  // Get order details using OrderService.getOrderById
  Future<void> _getOrderDetails() async {
    try {
      final orderData = await OrderService.getOrderById(_orderId);

      setState(() {
        _orderData = orderData;
        _order = Order.fromJson(orderData);

        // Update status from order data
        _currentOrderStatus = _order?.orderStatus ?? OrderStatus.pending;
        _currentDeliveryStatus = _order?.deliveryStatus ?? DeliveryStatus.pending;

        // Get store data
        if (_order?.store != null) {
          _storeData = _order!.store!;
        }

        // Get customer data
        if (_order?.customer != null) {
          _customerData = _order!.customer!;
        }

        // Get order items
        if (_order?.items != null && _order!.items!.isNotEmpty) {
          _orderItems = _order!.items!.map((orderItem) => MenuItem(
            id: orderItem.menuItemId,
            name: orderItem.name,
            price: orderItem.price,
            description: orderItem.description,
            imageUrl: orderItem.imageUrl,
            storeId: _order!.storeId,
            category: orderItem.category,
            quantity: orderItem.quantity,
          )).toList();
        }

        // Get order code/ID
        _orderCode = _order?.id.toString() ?? _orderId;
      });
    } catch (e) {
      print('Error getting order details: $e');
    }
  }

  // Process provided order detail if no API call needed
  void _processProvidedOrderDetail() {
    if (widget.orderDetail != null) {
      setState(() {
        _orderData = widget.orderDetail;

        // Try to parse status
        final statusString = widget.orderDetail!['status']?.toString() ?? 'pending';
        _currentOrderStatus = OrderStatus.fromString(statusString);

        // Extract items if available
        if (widget.orderDetail!['items'] != null && widget.orderDetail!['items'] is List) {
          _orderItems = (widget.orderDetail!['items'] as List).map((item) {
            return MenuItem(
              id: item['id'] ?? 0,
              name: item['name'] ?? '',
              price: (item['price'] as num?)?.toDouble() ?? 0.0,
              description: item['description'],
              imageUrl: item['imageUrl'],
              storeId: 0,
              category: item['category'] ?? '',
              quantity: item['quantity'] ?? 1,
            );
          }).toList();
        }

        _orderCode = widget.orderDetail!['code']?.toString() ?? '';
      });
    }
  }

  // Get driver request data using DriverRequestService
  Future<void> _getDriverRequestData() async {
    try {
      // Try to get driver request detail for this order
      // Note: This assumes there's a relationship between order and driver request
      final requests = await DriverRequestService.getDriverRequests(
        page: 1,
        limit: 50, // Get recent requests
      );

      if (requests['requests'] != null) {
        final requestList = requests['requests'] as List;
        final orderRequest = requestList.firstWhere(
              (request) => request['order']?['id']?.toString() == _orderId,
          orElse: () => null,
        );

        if (orderRequest != null) {
          setState(() {
            _driverRequestData = orderRequest;
          });
        }
      }
    } catch (e) {
      print('Error getting driver request data: $e');
    }
  }

  // Get tracking data using TrackingService
  Future<void> _getTrackingData() async {
    try {
      final trackingData = await TrackingService.getTrackingData(_orderId);
      setState(() {
        _trackingData = trackingData;
      });
    } catch (e) {
      print('Error getting tracking data: $e');
    }
  }

  // Update order status using appropriate service based on current status
  Future<void> _updateOrderStatus(String action) async {
    if (_isFetchingStatus) return;

    setState(() {
      _isFetchingStatus = true;
    });

    try {
      if (_orderId.isNotEmpty) {
        switch (action) {
          case 'accept':
          // Accept driver request
            if (_driverRequestData != null) {
              await DriverRequestService.respondToDriverRequest(
                _driverRequestData!['id'].toString(),
                'accept',
                estimatedPickupTime: DateTime.now().add(const Duration(minutes: 15)),
                estimatedDeliveryTime: DateTime.now().add(const Duration(minutes: 30)),
              );
              _currentOrderStatus = OrderStatus.confirmed;
              _currentDeliveryStatus = DeliveryStatus.pending;
            }
            break;

          case 'start_pickup':
          // Start delivery tracking
            await TrackingService.startDelivery(_orderId);
            _currentOrderStatus = OrderStatus.ready_for_pickup;
            _currentDeliveryStatus = DeliveryStatus.picked_up;
            break;

          case 'start_delivery':
          // Update order status to on delivery
            await OrderService.updateOrderStatus(_orderId, {
              'order_status': 'on_delivery',
              'delivery_status': 'on_way'
            });
            _currentOrderStatus = OrderStatus.on_delivery;
            _currentDeliveryStatus = DeliveryStatus.on_way;
            break;

          case 'complete':
          // Complete delivery
            await TrackingService.completeDelivery(_orderId);
            _currentOrderStatus = OrderStatus.delivered;
            _currentDeliveryStatus = DeliveryStatus.delivered;
            break;

          case 'cancel':
          // Cancel/reject driver request
            if (_driverRequestData != null) {
              await DriverRequestService.respondToDriverRequest(
                _driverRequestData!['id'].toString(),
                'reject',
              );
            } else {
              // Cancel order
              await OrderService.cancelOrder(_orderId);
            }
            _currentOrderStatus = OrderStatus.cancelled;
            break;
        }

        // Play sound
        _playSound('audio/alert.wav');

        // Refresh data after update
        await _fetchOrderData();

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Status berhasil diperbarui')),
          );
        }
      } else {
        // For demo purposes, just update local state
        setState(() {
          switch (action) {
            case 'accept':
              _currentOrderStatus = OrderStatus.confirmed;
              break;
            case 'start_pickup':
              _currentOrderStatus = OrderStatus.ready_for_pickup;
              _currentDeliveryStatus = DeliveryStatus.picked_up;
              break;
            case 'start_delivery':
              _currentOrderStatus = OrderStatus.on_delivery;
              _currentDeliveryStatus = DeliveryStatus.on_way;
              break;
            case 'complete':
              _currentOrderStatus = OrderStatus.delivered;
              _currentDeliveryStatus = DeliveryStatus.delivered;
              break;
            case 'cancel':
              _currentOrderStatus = OrderStatus.cancelled;
              break;
          }
        });
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
      if (mounted) {
        setState(() {
          _isFetchingStatus = false;
        });
      }
    }
  }

  // Helper to get display name for status
  String _getStatusDisplayName(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Menunggu Konfirmasi';
      case OrderStatus.confirmed:
        return 'Dikonfirmasi';
      case OrderStatus.preparing:
        return 'Sedang Dipersiapkan';
      case OrderStatus.ready_for_pickup:
        return 'Siap Diambil';
      case OrderStatus.on_delivery:
        return 'Dalam Pengantaran';
      case OrderStatus.delivered:
        return 'Pesanan Diterima';
      case OrderStatus.cancelled:
        return 'Pesanan Dibatalkan';
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
                        _updateOrderStatus('cancel');
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
                        Navigator.of(context).pop();
                        _updateOrderStatus('start_pickup');
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

  Future<void> _completeDelivery() async {
    try {
      await _updateOrderStatus('complete');
      _showCompletionDialog();
    } catch (e) {
      print('Error completing delivery: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyelesaikan pengantaran: $e')),
        );
      }
    }
  }

  void _navigateToTrackOrder() async {
    _playSound('audio/alert.wav');

    if (_currentOrderStatus == OrderStatus.ready_for_pickup) {
      await _updateOrderStatus('start_delivery');
      // No navigation to TrackOrderScreen
    }
  }
  Future<void> _openWhatsApp(String phoneNumber) async {
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

  Future<void> _updateMapAnnotations() async {
    if (_trackingData != null) {
      _addMarkers();
      _drawRoute();
    }
  }

  Future<void> _addMarkers() async {
    if (pointAnnotationManager == null) return;

    await pointAnnotationManager?.deleteAll();

    final driverLat = _trackingData?['driverPosition']?['latitude'] ?? 0.0;
    final driverLng = _trackingData?['driverPosition']?['longitude'] ?? 0.0;
    final storeLat = _storeData?.latitude ?? 0.0;
    final storeLng = _storeData?.longitude ?? 0.0;
    final customerLat = _trackingData?['customerPosition']?['latitude'] ?? 0.0;
    final customerLng = _trackingData?['customerPosition']?['longitude'] ?? 0.0;

    final customerOptions = PointAnnotationOptions(
      geometry: Point(coordinates: Position(customerLng, customerLat)),
      iconImage: "assets/images/marker_red.png",
    );

    final storeOptions = PointAnnotationOptions(
      geometry: Point(coordinates: Position(storeLng, storeLat)),
      iconImage: "assets/images/marker_blue.png",
    );

    final driverOptions = PointAnnotationOptions(
      geometry: Point(coordinates: Position(driverLng, driverLat)),
      iconImage: "assets/images/marker_green.png",
    );

    await pointAnnotationManager?.create(customerOptions);
    await pointAnnotationManager?.create(storeOptions);
    await pointAnnotationManager?.create(driverOptions);
  }

  Future<void> _drawRoute() async {
    if (polylineAnnotationManager == null) return;

    await polylineAnnotationManager?.deleteAll();

    if (_trackingData?['routeCoordinates'] != null) {
      final routeCoords = _trackingData!['routeCoordinates'] as List;
      final positions = routeCoords.map((coord) =>
          Position(coord['longitude'], coord['latitude'])
      ).toList();

      final polylineOptions = PolylineAnnotationOptions(
        geometry: LineString(coordinates: positions),
        lineColor: Colors.blue.value,
        lineWidth: 3.0,
      );

      await polylineAnnotationManager?.create(polylineOptions);
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
    return _buildCard(
      index: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assignment, color: GlobalStyle.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Status Pesanan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: GlobalStyle.fontColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: GlobalStyle.lightColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: GlobalStyle.primaryColor.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getStatusColor(),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getStatusIcon(),
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pesanan #$_orderCode',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getStatusDisplayName(_currentOrderStatus),
                          style: TextStyle(
                            color: _getStatusColor(),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          GlobalStyle.formatRupiah(_order?.totalAmount ?? 0),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: GlobalStyle.primaryColor,
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
    );
  }

  Color _getStatusColor() {
    switch (_currentOrderStatus) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.confirmed:
        return Colors.blue;
      case OrderStatus.preparing:
        return Colors.purple;
      case OrderStatus.ready_for_pickup:
        return Colors.green;
      case OrderStatus.on_delivery:
        return Colors.teal;
      case OrderStatus.delivered:
        return Colors.green;
      case OrderStatus.cancelled:
        return Colors.red;
    }
  }

  IconData _getStatusIcon() {
    switch (_currentOrderStatus) {
      case OrderStatus.pending:
        return Icons.access_time;
      case OrderStatus.confirmed:
        return Icons.check_circle;
      case OrderStatus.preparing:
        return Icons.restaurant;
      case OrderStatus.ready_for_pickup:
        return Icons.shopping_basket;
      case OrderStatus.on_delivery:
        return Icons.local_shipping;
      case OrderStatus.delivered:
        return Icons.check_circle;
      case OrderStatus.cancelled:
        return Icons.cancel;
    }
  }

  Widget _buildMapWidget() {
    final driverLat = _trackingData?['driverPosition']?['latitude'] ?? 0.0;
    final driverLng = _trackingData?['driverPosition']?['longitude'] ?? 0.0;

    return _buildCard(
      index: 1,
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
    return _buildCard(
      index: 2,
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
                    imageSource: _storeData?.imageUrl ?? '',
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    placeholder: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.store, color: Colors.grey[600]),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _storeData?.name ?? 'Nama Toko',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: GlobalStyle.fontColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.grey[600], size: 16),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _storeData?.address ?? 'Alamat toko',
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
                            (_storeData?.rating ?? 0.0).toString(),
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
                      _openWhatsApp(_storeData?.phone ?? '');
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
                      _openWhatsApp(_storeData?.phone ?? '');
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
      index: 3,
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
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ClipOval(
                  child: ImageService.displayImage(
                    imageSource: _customerData?.avatar ?? '',
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    placeholder: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[300],
                      ),
                      child: Icon(Icons.person, color: Colors.grey[600]),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _customerData?.name ?? 'Nama Pelanggan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: GlobalStyle.fontColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.phone, color: Colors.grey[600], size: 16),
                          const SizedBox(width: 4),
                          Text(
                            _customerData?.phone ?? 'No. telepon',
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
                      _openWhatsApp(_customerData?.phone ?? '');
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
                      _openWhatsApp(_customerData?.phone ?? '');
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
    return _buildCard(
      index: 4,
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                  GlobalStyle.formatRupiah(_order?.deliveryFee ?? 0),
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
                  GlobalStyle.formatRupiah(_order?.totalAmount ?? 0),
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

  Widget _buildLoadingIndicator() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Memuat data pesanan...'),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_isFetchingStatus) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // If order is cancelled or delivered, don't show action buttons
    if (_currentOrderStatus == OrderStatus.cancelled ||
        _currentOrderStatus == OrderStatus.delivered) {
      return const SizedBox.shrink();
    }

    // Show different buttons based on current status
    switch (_currentOrderStatus) {
      case OrderStatus.pending:
        return Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => _updateOrderStatus('cancel'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text('Tolak'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: () => _updateOrderStatus('accept'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlobalStyle.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text('Terima Pesanan'),
              ),
            ),
          ],
        );

      case OrderStatus.confirmed:
      case OrderStatus.preparing:
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
                child: const Text('Ambil Pesanan'),
              ),
            ),
          ],
        );

      case OrderStatus.ready_for_pickup:
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
                  backgroundColor: GlobalStyle.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text('Mulai Pengantaran'),
              ),
            ),
          ],
        );

      case OrderStatus.on_delivery:
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
                child: const Text('Lihat Rute'),
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
                child: const Text('Selesai'),
              ),
            ),
          ],
        );

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
                const SizedBox(height: 80), // Extra space for action buttons
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