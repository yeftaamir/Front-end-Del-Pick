import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Models/tracking.dart';
import 'package:del_pick/Views/Component/order_status_card.dart';
import 'dart:async';
import 'package:lottie/lottie.dart';
import '../../Models/order.dart';
import 'cart_screen.dart';
import 'history_detail.dart';
import 'package:geotypes/geotypes.dart' as geotypes;

class TrackCustOrderScreen extends StatefulWidget {
  static const String route = "/Customers/TrackOrder";

  final String? orderId;
  final Order? order;

  const TrackCustOrderScreen({Key? key, this.orderId, this.order}) : super(key: key);

  @override
  State<TrackCustOrderScreen> createState() => _TrackCustOrderScreenState();
}

class _TrackCustOrderScreenState extends State<TrackCustOrderScreen> {
  MapboxMap? mapboxMap;
  PointAnnotationManager? pointAnnotationManager;
  PolylineAnnotationManager? polylineAnnotationManager;

  // Draggable scroll controller
  DraggableScrollableController dragController = DraggableScrollableController();
  bool isExpanded = false;

  // Define coordinates
  final delPosition = Position(99.10279, 2.34379);
  final driverPosition = Position(99.10179, 2.34279);
  final storePosition = Position(99.10379, 2.34479);
  String _driverName = "Budi Santoso";
  String _vehicleNumber = "B 1234 ABC";
  // Tracking model instance
  late Tracking _tracking;
  late Order _order;

  // Timer for simulating location updates
  Timer? _locationUpdateTimer;

  @override
  void initState() {
    super.initState();

    // Initialize tracking data
    _tracking = widget.order?.tracking ?? Tracking.sample();
    _order = widget.order ?? Order.sample();

    // Simulate location updates every 3 seconds
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 3), _simulateLocationUpdate);
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    dragController.dispose();
    super.dispose();
  }

  // Simulates driver movement for demo purposes
  void _simulateLocationUpdate(Timer timer) {
    // Only simulate if order is in progress
    if (_tracking.status == OrderStatus.driverHeadingToCustomer ||
        _tracking.status == OrderStatus.driverHeadingToStore) {

      // Calculate new position - moving slightly toward destination
      final targetPosition = _tracking.status == OrderStatus.driverHeadingToCustomer
          ? _tracking.customerPosition
          : _tracking.storePosition;

      final currentLng = _tracking.driverPosition.lng;
      final currentLat = _tracking.driverPosition.lat;

      final targetLng = targetPosition.lng;
      final targetLat = targetPosition.lat;

      // Move 5% closer to destination
      final newLng = currentLng + (targetLng - currentLng) * 0.05;
      final newLat = currentLat + (targetLat - currentLat) * 0.05;

      // Update tracking with new position
      setState(() {
        _tracking = _tracking.copyWith(
          driverPosition: Position(newLng, newLat), statusMessage: '',
        );
      });

      // Update map annotations and route
      _updateMapAnnotations();

      // Check if driver has arrived (within 0.0005 degrees, roughly 50m)
      if ((newLng - targetLng).abs() < 0.0005 && (newLat - targetLat).abs() < 0.0005) {
        if (_tracking.status == OrderStatus.driverHeadingToCustomer) {
          setState(() {
            _tracking = _tracking.copyWith(status: OrderStatus.driverArrived, statusMessage: '');
          });
        } else if (_tracking.status == OrderStatus.driverHeadingToStore) {
          setState(() {
            _tracking = _tracking.copyWith(status: OrderStatus.driverAtStore, statusMessage: '');
          });

          // After a delay, simulate driver leaving store to customer
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted) {
              setState(() {
                _tracking = _tracking.copyWith(status: OrderStatus.driverHeadingToCustomer, statusMessage: '');
              });
            }
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Mapbox View
          SizedBox(
            height: MediaQuery.of(context).size.height,
            child: MapWidget(
              key: const ValueKey("mapWidget"),
              onMapCreated: _onMapCreated,
              styleUri: "mapbox://styles/ifs21002/cm71crfz300sw01s10wsh3zia",
              cameraOptions: CameraOptions(
                center: Point(coordinates: _tracking.driverPosition),
                zoom: 13.0,
              ),
            ),
          ),

          // Back Button
          Positioned(
            top: 40,
            left: 16,
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.blue, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // Status Bar at Top
          Positioned(
            top: 40,
            left: 70,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _tracking.statusMessage,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_tracking.status != OrderStatus.completed && _tracking.status != OrderStatus.cancelled)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Estimasi tiba: ${_tracking.formattedETA}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Expandable Bottom Sheet
          DraggableScrollableSheet(
            initialChildSize: 0.35,
            minChildSize: 0.15,
            maxChildSize: 0.8,
            controller: dragController,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle for dragging
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 12, bottom: 8),
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),

                      // Order Status using OrderStatusCard
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: OrderStatusCard(
                          order: _order.copyWith(tracking: _tracking),
                        ),
                      ),

                      // Driver Info
                      _buildDriverInfo(),

                      // Delivery Information
                      _buildDeliveryInfo(),

                      // Confirmation Button
                      if (_tracking.status == OrderStatus.driverArrived)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: GlobalStyle.primaryColor,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  _tracking = _tracking.copyWith(status: OrderStatus.completed, statusMessage: '');
                                });

                                // Navigate to CartScreen with order details
                                Navigator.pushNamed(
                                  context,
                                  HistoryDetailPage.route,
                                  arguments: {'orderId': _tracking.orderId},
                                );
                              },
                              child: const Text(
                                'Konfirmasi Pesanan Diterima',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Build driver info section
  Widget _buildDriverInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                      _driverName,
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
                        Icon(Icons.motorcycle, color: Colors.grey[600], size: 16),
                        const SizedBox(width: 4),
                        Text(
                          _vehicleNumber,
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
                    // Implementasi fungsi panggilan
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
                    // Implementasi fungsi pesan
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Build delivery info card
  Widget _buildDeliveryInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: GlobalStyle.primaryColor),
              const SizedBox(width: 8),
              Text(
                'Informasi Pengantaran',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: GlobalStyle.fontColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildLocationItem(
            'Alamat Penjemputan',
            _order.store.name,
            _order.store.address,
            Icons.store,
          ),
          const Divider(height: 24),
          _buildLocationItem(
            'Alamat Pengantaran',
            'Alamat Pengiriman',
            _order.deliveryAddress,
            Icons.location_on,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                'Estimasi Waktu: ${_tracking.formattedETA}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.route, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                'Jarak: 2.5 km',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),

          // Order Items Summary
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Pembayaran',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                GlobalStyle.formatRupiah(_calculateTotal()),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: GlobalStyle.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              Icon(Icons.payment, size: 16, color: Colors.grey),
              SizedBox(width: 8),
              Text(
                'Metode Pembayaran: Tunai',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationItem(String title, String location, String address, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: GlobalStyle.lightColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: GlobalStyle.primaryColor,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                location,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                address,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  double _calculateTotal() {
    double itemsTotal = 0;
    for (final item in _order.items) {
      itemsTotal += item.price * item.quantity;
    }
    return itemsTotal + _order.serviceCharge;
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    this.mapboxMap = mapboxMap;
    _setupAnnotationManagers().then((_) {
      _addMarkers();
      _drawRoute();
    });
  }

  Future<void> _setupAnnotationManagers() async {
    pointAnnotationManager = await mapboxMap?.annotations.createPointAnnotationManager();
    polylineAnnotationManager = await mapboxMap?.annotations.createPolylineAnnotationManager();
  }

  Future<void> _addMarkers() async {
    if (pointAnnotationManager == null) return;

    // Clear existing annotations
    await pointAnnotationManager?.deleteAll();

    // Customer marker
    final customerOptions = PointAnnotationOptions(
      geometry: Point(coordinates: _tracking.customerPosition),
      iconImage: "assets/images/marker_red.png",
    );

    // Store marker
    final storeOptions = PointAnnotationOptions(
      geometry: Point(coordinates: _tracking.storePosition),
      iconImage: "assets/images/marker_blue.png",
    );

    // Driver marker
    final driverOptions = PointAnnotationOptions(
      geometry: Point(coordinates: _tracking.driverPosition),
      iconImage: "assets/images/marker_green.png",
    );

    await pointAnnotationManager?.create(customerOptions);
    await pointAnnotationManager?.create(storeOptions);
    await pointAnnotationManager?.create(driverOptions);

    // Center map on driver
    await mapboxMap?.flyTo(
      CameraOptions(
        center: Point(coordinates: _tracking.driverPosition),
        zoom: 14.0,
      ),
      MapAnimationOptions(duration: 1000),
    );
  }

  Future<void> _drawRoute() async {
    if (polylineAnnotationManager == null) return;

    // Clear existing route
    await polylineAnnotationManager?.deleteAll();

    // Create a simple route line between points
    List<Position> routePoints = [];

    if (_tracking.status == OrderStatus.driverHeadingToStore ||
        _tracking.status == OrderStatus.driverAssigned) {
      // Route from driver to store
      routePoints = [
        _tracking.driverPosition,
        _tracking.storePosition,
      ];
    } else if (_tracking.status == OrderStatus.driverAtStore ||
        _tracking.status == OrderStatus.driverHeadingToCustomer ||
        _tracking.status == OrderStatus.driverArrived) {
      // Route from store/driver to customer
      routePoints = [
        _tracking.driverPosition,
        _tracking.customerPosition,
      ];
    }

    // Create route line
    if (routePoints.isNotEmpty) {
      final routeOptions = PolylineAnnotationOptions(
        geometry: LineString(coordinates: routePoints),
        lineWidth: 4.0,
        lineColor: GlobalStyle.primaryColor.value,
      );

      await polylineAnnotationManager?.create(routeOptions);
    }
  }

  // Update map annotations with new driver position
  void _updateMapAnnotations() {
    if (mapboxMap == null) return;

    _addMarkers();
    _drawRoute();
  }

  // Show not implemented feature dialog
  void _showFeatureNotImplemented(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature belum tersedia saat ini'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Add this method to the appropriate class (likely in TrackOrderScreen)
  void _showOrderCompletedDialog() async {
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
                  'assets/animations/delivery_complete.json',
                  width: 200,
                  height: 200,
                  repeat: false,
                ),
                const SizedBox(height: 20),
                const Text(
                  "Pesanan telah diselesaikan",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Terima kasih telah menggunakan layanan kami!",
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
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                  ),
                  onPressed: () {
                    // Update order status and return to previous screen
                    _completeOrder();
                    Navigator.pop(context); // Close dialog
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

// Add this method to handle the order completion
  void _completeOrder() {
    if (widget.order != null) {
      // Update the order status to completed
      final Order completedOrder = widget.order!.copyWith(
        status: OrderStatus.completed,
        tracking: widget.order?.tracking?.copyWith(
          status: OrderStatus.completed,
          statusMessage: "Pesanan telah selesai",
        ),
      );

      // Navigate back to CartScreen with the completed order
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => CartScreen(
            cartItems: const [], // Empty cart since order is completed
            completedOrder: completedOrder, // Pass the completed order
          ),
        ),
      );
    }
  }

// Make sure you have a playSound method like this one
  Future<void> _playSound(String assetPath) async {
    final AudioPlayer audioPlayer = AudioPlayer();
    await audioPlayer.stop();
    await audioPlayer.play(AssetSource(assetPath));
  }
}