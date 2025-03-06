import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Models/customer.dart';
import 'package:del_pick/Models/order.dart';
import 'dart:async';
import 'package:lottie/lottie.dart';

class TrackOrderScreen extends StatefulWidget {
  static const String route = "/Driver/TrackOrder";

  final String? orderId;
  final Order? order;

  const TrackOrderScreen({Key? key, this.orderId, this.order}) : super(key: key);

  @override
  State<TrackOrderScreen> createState() => _TrackOrderScreenState();
}

class _TrackOrderScreenState extends State<TrackOrderScreen> with TickerProviderStateMixin {
  MapboxMap? mapboxMap;
  PointAnnotationManager? pointAnnotationManager;
  PolylineAnnotationManager? polylineAnnotationManager;

  // Expanded bottom sheet controller
  DraggableScrollableController dragController = DraggableScrollableController();
  bool isExpanded = false;

  // Define coordinates
  final delPosition = Position(99.10279, 2.34379);
  final customerPosition = Position(99.10179, 2.34279);
  final storePosition = Position(99.10379, 2.34479);

  // Order reference
  late Order? _order;

  // Customer reference
  late Customer _customer;

  // Card animation controllers
  late List<AnimationController> _cardControllers;
  late List<Animation<Offset>> _cardAnimations;

  // Timer for simulating location updates
  Timer? _locationUpdateTimer;

  @override
  void initState() {
    super.initState();

    // Initialize order data using sample() instead of empty()
    _order = widget.order ?? Order.sample();

    // Rest of your initialization code...
    _customer = Customer(
      id: "1",
      name: "Rifqi Haikal",
      phoneNumber: "+62 812 3456 7890",
      email: "rifqi.haikal@example.com",
      profileImageUrl: "https://randomuser.me/api/portraits/men/32.jpg",
    );

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
      return Tween(
        begin: const Offset(0, 0.5),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeOutCubic,
      ));
    }).toList();

    // Start initial animations
    for (var controller in _cardControllers) {
      controller.forward();
    }

    // Simulate location updates every 3 seconds
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 3), _simulateLocationUpdate);
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    for (var controller in _cardControllers) {
      controller.dispose();
    }
    dragController.dispose();
    super.dispose();
  }

  // Simulates location updates for demo purposes
  void _simulateLocationUpdate(Timer timer) {
    // In a real app, this would update the driver's location
    // For demo, we'll just refresh the map occasionally
    _updateMapAnnotations();
  }

  // Build customer info card
  Widget _buildCustomerInfo() {
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
                Icon(Icons.person, color: GlobalStyle.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Informasi Pemesan',
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
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: ClipOval(
                    child: _customer.profileImageUrl != null
                        ? Image.network(
                      _customer.profileImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.person),
                    )
                        : const Icon(Icons.person),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _customer.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _customer.phoneNumber,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _customer.email,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
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
                      _showFeatureNotImplemented('Panggil customer');
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
                      _showFeatureNotImplemented('Kirim pesan');
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

  // Build delivery info card
  Widget _buildDeliveryInfo() {
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
              'Rumah Makan Padang Sederhana',
              'Jl. Sisingamangaraja, Laguboti',
              Icons.store,
            ),
            const Divider(height: 24),
            _buildLocationItem(
              'Alamat Pengantaran',
              'Institut Teknologi Del',
              'Jl. P.I. Del, Sitoluama, Laguboti',
              Icons.location_on,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  'Estimasi Waktu: 15 menit',
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
          ],
        ),
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

  // Build items list
  Widget _buildItemsList() {
    if (_order == null || _order!.items.isEmpty) {
      return const Center(
        child: Text('No items found'),
      );
    }

    return SlideTransition(
        position: _cardAnimations[2],
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
    'Detail Pesanan',
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
    const Divider(height: 24),
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
      'Rp ${_calculateTotal().toStringAsFixed(0)}',
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
        ),
    );
  }

  // Calculate total payment
  double _calculateTotal() {
    if (_order == null) return 0.0;

    final double subtotal = _order!.items
        .fold(0, (sum, item) => sum + (item.price * item.quantity));
    final double serviceCharge = _order!.serviceCharge;

    return subtotal + serviceCharge;
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
                center: Point(coordinates: delPosition),
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
                  const Text(
                    'Pengantaran dalam proses',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Estimasi tiba: 15 menit',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
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

                      // Customer Info (Compact)
                      if (!isExpanded)
                        SlideTransition(
                          position: _cardAnimations[0],
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
                                    child: _customer.profileImageUrl != null
                                        ? Image.network(
                                      _customer.profileImageUrl!,
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
                                        _customer.name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Institut Teknologi Del',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Total',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      'Rp ${_calculateTotal().toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: GlobalStyle.primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Expanded Content
                      if (isExpanded) ...[
                        _buildCustomerInfo(),
                        const SizedBox(height: 16),
                        _buildDeliveryInfo(),
                        const SizedBox(height: 16),
                        _buildItemsList(),
                      ],

                      // Complete Order Button
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
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
                              _showOrderCompletedDialog();
                            },
                            child: const Text(
                              'Selesai Antar',
                              style: TextStyle(
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
                  "Pesanan telah diantar",
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
                    Navigator.pop(context, 'completed');
                  },
                  child: const Text(
                    "Selesai",
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
      geometry: Point(coordinates: customerPosition),
      iconImage: "assets/images/marker_red.png",
    );

    // Store marker
    final storeOptions = PointAnnotationOptions(
      geometry: Point(coordinates: storePosition),
      iconImage: "assets/images/marker_blue.png",
    );

    // Driver marker
    final driverOptions = PointAnnotationOptions(
      geometry: Point(coordinates: delPosition),
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

    // Create route from driver location to customer location
    final routeCoordinates = [
      delPosition,
      customerPosition,
    ];

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