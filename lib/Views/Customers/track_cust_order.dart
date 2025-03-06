import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Views/Customers/history_detail.dart';
import 'package:del_pick/Models/tracking.dart';
import 'dart:async';
import '../../Models/driver.dart';
import '../../Models/order.dart';
import 'package:lottie/lottie.dart';

class TrackCustOrderScreen extends StatefulWidget {
  static const String route = "/Customers/TrackOrder";

  final String? orderId;
  final Order? order;

  const TrackCustOrderScreen({Key? key, this.orderId, this.order}) : super(key: key);

  @override
  State<TrackCustOrderScreen> createState() => _TrackCustOrderScreenState();
}

class _TrackCustOrderScreenState extends State<TrackCustOrderScreen> with TickerProviderStateMixin {
  MapboxMap? mapboxMap;
  PointAnnotationManager? pointAnnotationManager;
  PolylineAnnotationManager? polylineAnnotationManager;

  // Expanded bottom sheet controller
  DraggableScrollableController dragController = DraggableScrollableController();
  bool isExpanded = false;

  // Tracking model instance
  late Tracking _tracking;

  // Order reference
  late Order? _order;

  // Order status animation controllers
  late AnimationController _statusAnimationController;
  late Animation<Offset> _statusAnimation;

  // Card animation controllers
  late List<AnimationController> _cardControllers;
  late List<Animation<Offset>> _cardAnimations;

  // Previous status to track changes
  OrderStatus? _previousStatus;

  // Timer for simulating location updates
  Timer? _locationUpdateTimer;

  @override
  void initState() {
    super.initState();

    // Initialize order data
    _order = widget.order;

    // Initialize tracking data
    // In a real app, you would fetch this from an API using the orderId
    _tracking = Tracking.sample();

    // Initialize animation controllers
    _statusAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _statusAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _statusAnimationController,
      curve: Curves.easeOutCubic,
    ));

    // Initialize card animation controllers
    _cardControllers = List.generate(
      3, // Number of card sections
          (index) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 600 + (index * 200)),
      ),
    );

    // Create slide animations for each card
    _cardAnimations = _cardControllers.map((controller) {
      return Tween<Offset>(
        begin: const Offset(0, 0.5),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeOutCubic,
      ));
    }).toList();

    // Store initial status
    _previousStatus = _tracking.status;

    // Start initial animations
    _statusAnimationController.forward();
    for (var controller in _cardControllers) {
      controller.forward();
    }

    // Simulate location updates every 3 seconds
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 3), _simulateLocationUpdate);
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    _statusAnimationController.dispose();
    for (var controller in _cardControllers) {
      controller.dispose();
    }
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
          driverPosition: Position(newLng, newLat),
        );
      });

      // Update map annotations and route
      _updateMapAnnotations();

      // Check if driver has arrived (within 0.0005 degrees, roughly 50m)
      if ((newLng - targetLng).abs() < 0.0005 && (newLat - targetLat).abs() < 0.0005) {
        if (_tracking.status == OrderStatus.driverHeadingToCustomer) {
          _updateOrderStatus(OrderStatus.driverArrived);
        } else if (_tracking.status == OrderStatus.driverHeadingToStore) {
          _updateOrderStatus(OrderStatus.driverAtStore);

          // After a delay, simulate driver leaving store to customer
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted) {
              _updateOrderStatus(OrderStatus.driverHeadingToCustomer);
            }
          });
        }
      }
    }
  }

  // Updates the order status with animation
  void _updateOrderStatus(OrderStatus newStatus) {
    // Only animate if status has changed
    if (_tracking.status != newStatus) {
      setState(() {
        _previousStatus = _tracking.status;
        _tracking = _tracking.copyWith(status: newStatus);
      });

      // Animate status change
      _statusAnimationController.reset();
      _statusAnimationController.forward();
    }
  }

  // Builds the status tracker UI
  Widget _buildStatusTracker() {
    return SlideTransition(
      position: _statusAnimation,
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 16),
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
            Text(
              'Status Pesanan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: GlobalStyle.fontColor,
              ),
            ),
            const SizedBox(height: 20),
            _buildStatusSteps(),
          ],
        ),
      ),
    );
  }

  // Builds the status steps indicator
  Widget _buildStatusSteps() {
    final List<Map<String, dynamic>> steps = [
      {
        'status': OrderStatus.driverHeadingToStore,
        'label': 'Menjemput',
        'icon': Icons.store,
        'description': 'Driver sedang menuju ke toko',
      },
      {
        'status': OrderStatus.driverAtStore,
        'label': 'Di Toko',
        'icon': Icons.shopping_bag,
        'description': 'Driver sedang mengambil pesanan',
      },
      {
        'status': OrderStatus.driverHeadingToCustomer,
        'label': 'Mengantar',
        'icon': Icons.delivery_dining,
        'description': 'Driver sedang menuju ke lokasi Anda',
      },
      {
        'status': OrderStatus.driverArrived,
        'label': 'Sampai',
        'icon': Icons.location_on,
        'description': 'Driver telah sampai di lokasi Anda',
      },
      {
        'status': OrderStatus.completed,
        'label': 'Selesai',
        'icon': Icons.check_circle,
        'description': 'Pesanan telah selesai',
      },
    ];

    // Determine current step index
    int currentStepIndex = steps.indexWhere((step) => step['status'] == _tracking.status);
    if (currentStepIndex == -1) currentStepIndex = 0;

    return Row(
      children: List.generate(steps.length, (index) {
        // Determine if step is active
        bool isActive = index <= currentStepIndex;
        bool isCurrent = index == currentStepIndex;

        return Expanded(
          child: Row(
            children: [
              // Step indicator
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: isActive ? GlobalStyle.primaryColor : Colors.grey[300],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  steps[index]['icon'] as IconData,
                  color: Colors.white,
                  size: 16,
                ),
              ),

              // Connector line
              if (index < steps.length - 1)
                Expanded(
                  child: Container(
                    height: 3,
                    color: isActive ? GlobalStyle.primaryColor : Colors.grey[300],
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  // Build items list
  Widget _buildItemsList() {
    if (_order == null || _order!.items.isEmpty) {
      return const Center(
        child: Text('No items found'),
      );
    }

    return SlideTransition(
      position: _cardAnimations[0],
      child: Container(
        padding: const EdgeInsets.all(16),
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
                Icon(Icons.shopping_bag, color: GlobalStyle.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Pesanan Anda',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: GlobalStyle.fontColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: _order?.items.length ?? 0,
              itemBuilder: (context, index) {
                final item = _order!.items[index];
                return Container(
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
                        child: Image.asset(
                          item.imageUrl,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
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
                              'Rp ${item.price.toStringAsFixed(0)}',
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
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Build payment details
  Widget _buildPaymentDetails() {
    if (_order == null) return Container();

    final double subtotal = _order!.items
        .fold(0, (sum, item) => sum + (item.price * item.quantity));
    final double serviceCharge = _order!.serviceCharge;
    final double total = subtotal + serviceCharge;

    return SlideTransition(
      position: _cardAnimations[1],
      child: Container(
        padding: const EdgeInsets.all(16),
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
                Icon(Icons.receipt, color: GlobalStyle.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Rincian Pembayaran',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: GlobalStyle.fontColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildPaymentRow('Subtotal untuk Produk', subtotal),
            const SizedBox(height: 8),
            _buildPaymentRow('Biaya Layanan', serviceCharge),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(),
            ),
            _buildPaymentRow('Total Pembayaran', total, isTotal: true),
            const SizedBox(height: 12),
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
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            fontSize: isTotal ? 16 : 14,
          ),
        ),
        Text(
          'Rp ${amount.toStringAsFixed(0)}',
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            fontSize: isTotal ? 16 : 14,
            color: isTotal ? GlobalStyle.primaryColor : Colors.black,
          ),
        ),
      ],
    );
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

          // Bottom Sheet
          DraggableScrollableSheet(
            initialChildSize: 0.25,
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
                child: NotificationListener<DraggableScrollableNotification>(
                  onNotification: (notification) {
                    setState(() {
                      isExpanded = notification.extent > 0.25;
                    });
                    return true;
                  },
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      // Handle Bar
                      Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 12),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      // Driver Info
                      SlideTransition(
                        position: _cardAnimations[2],
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: ClipOval(
                                  child: _tracking.driverImageUrl.isNotEmpty
                                      ? Image.network(
                                    _tracking.driverImageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.person),
                                  )
                                      : const Icon(Icons.person),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _tracking.driverName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _tracking.vehicleNumber,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.chat_bubble_outline),
                                onPressed: () {
                                  // Add chat functionality
                                  _showFeatureNotImplemented('Chat dengan driver');
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.call_outlined),
                                onPressed: () {
                                  // Add call functionality
                                  _showFeatureNotImplemented('Panggil driver');
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Status Tracker (visible when expanded)
                      if (isExpanded) _buildStatusTracker(),

                      // Order Items (visible when expanded)
                      if (isExpanded && _order != null) _buildItemsList(),

                      // Payment Details (visible when expanded)
                      if (isExpanded && _order != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: _buildPaymentDetails(),
                        ),

                      // Complete Order Button
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _tracking.status == OrderStatus.driverArrived
                                  ? GlobalStyle.primaryColor
                                  : Colors.grey,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: _tracking.status == OrderStatus.driverArrived
                                ? () {
                              _showOrderCompletedDialog();
                            }
                                : null,
                            child: Text(
                              _tracking.status == OrderStatus.completed
                                  ? 'Pesanan Selesai'
                                  : 'Konfirmasi Pesanan Diterima',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Extra space for bottom padding when expanded
                      if (isExpanded) const SizedBox(height: 40),
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

  // Show order completed dialog with animation
  void _showOrderCompletedDialog() {
    setState(() {
      _tracking = _tracking.copyWith(status: OrderStatus.completed);
    });

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
                  'assets/animations/check_animation.json',
                  width: 200,
                  height: 200,
                  repeat: false,
                ),
                const SizedBox(height: 20),
                const Text(
                  "Pesanan anda selesai",
                  style: TextStyle(
                    fontSize: 18,
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
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    // Navigate to history detail page
                    Navigator.pushReplacementNamed(
                      context,
                      HistoryDetailPage.route,
                      arguments: {'orderId': _tracking.orderId},
                    );
                  },
                  child: const Text(
                    "Lihat Rincian",
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
  }

  Future<void> _drawRoute() async {
    if (polylineAnnotationManager == null) return;

    // Clear existing annotations
    await polylineAnnotationManager?.deleteAll();

    // Create dynamic route based on current status
    List<Position> routeCoordinates = [];

    if (_tracking.status == OrderStatus.driverHeadingToStore ||
        _tracking.status == OrderStatus.pending ||
        _tracking.status == OrderStatus.driverAssigned) {
      // Route from driver to store
      routeCoordinates = [
        _tracking.driverPosition,
        _tracking.storePosition,
      ];
    } else if (_tracking.status == OrderStatus.driverHeadingToCustomer) {
      // Route from driver to customer
      routeCoordinates = [
        _tracking.driverPosition,
        _tracking.customerPosition,
      ];
    } else {
      // For other statuses, show the full route
      routeCoordinates = [
        _tracking.driverPosition,
        _tracking.customerPosition,
      ];
    }

    final polylineOptions = PolylineAnnotationOptions(
      geometry: LineString(coordinates: routeCoordinates),
      lineColor: Colors.blue.value,
      lineWidth: 3.0,
    );

    await polylineAnnotationManager?.create(polylineOptions);
  }

  // Call this when driver position changes
  void _updateMapAnnotations() {
    _addMarkers();
    _drawRoute();

    // Update camera to follow driver
    mapboxMap?.setCamera(
      CameraOptions(
        center: Point(coordinates: _tracking.driverPosition),
        zoom: 13.0,
      ),
    );
  }

  // Show a toast message for unimplemented features
  void _showFeatureNotImplemented(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature belum tersedia'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}