import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Models/customer.dart';
import 'package:del_pick/Models/order.dart';
import 'package:del_pick/Models/tracking.dart';
import 'package:del_pick/Services/image_service.dart';
import 'package:del_pick/Services/order_service.dart';
import 'package:del_pick/Services/tracking_service.dart';
import 'package:del_pick/Services/driver_service.dart';
import 'package:del_pick/Services/location_service.dart';
import 'package:del_pick/Services/core/token_service.dart';
import 'dart:async';
import 'package:lottie/lottie.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../Models/order_enum.dart';

class TrackOrderScreen extends StatefulWidget {
  static const String route = "/Driver/TrackOrder";

  final String? orderId;
  final Order? order;

  const TrackOrderScreen({Key? key, this.orderId, this.order}) : super(key: key);

  @override
  State<TrackOrderScreen> createState() => _TrackOrderScreenState();
}

class _TrackOrderScreenState extends State<TrackOrderScreen> with TickerProviderStateMixin {
  // Map-related variables
  MapboxMap? mapboxMap;
  PointAnnotationManager? pointAnnotationManager;
  PolylineAnnotationManager? polylineAnnotationManager;

  // Mapbox access token - this should ideally come from a secure source
  final String mapboxAccessToken = 'pk.eyJ1IjoiaWZzMjEwMDIiLCJhIjoiY2w3MWNyZnozMDBzdzAxczEwemV4b2hkYSJ9.kYLFvXUL90J8kPU9GjrYGA';

  // Expanded bottom sheet controller
  DraggableScrollableController dragController = DraggableScrollableController();
  bool isExpanded = false;

  // State variables
  Order? _order;
  Customer? _customer;
  Tracking? _tracking;

  // Loading states
  bool _isLoading = true;
  bool _isError = false;
  String _errorMessage = '';

  // Card animation controllers
  late List<AnimationController> _cardControllers;
  late List<Animation<Offset>> _cardAnimations;

  // Timer for updating tracking data
  Timer? _trackingUpdateTimer;

  // Location service for managing real-time location
  final LocationService _locationService = LocationService();

  @override
  void initState() {
    super.initState();

    // Initialize with order from widget if provided
    _order = widget.order;

    // Initialize animation controllers
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

    // Initialize location service
    _initializeLocationService();

    // Load data
    _loadOrderData();
  }

  // Initialize location service
  Future<void> _initializeLocationService() async {
    try {
      bool initialized = await _locationService.initialize();
      if (!initialized) {
        print('Failed to initialize location service');
      }
    } catch (e) {
      print('Error initializing location service: $e');
    }
  }

  @override
  void dispose() {
    _trackingUpdateTimer?.cancel();
    for (var controller in _cardControllers) {
      controller.dispose();
    }
    dragController.dispose();
    _locationService.dispose();
    super.dispose();
  }

  // Load order and tracking data
  Future<void> _loadOrderData() async {
    setState(() {
      _isLoading = true;
      _isError = false;
    });

    try {
      // If we have an orderId but no order, fetch it
      if (widget.orderId != null && _order == null) {
        // First try to get the order detail using driver service
        // as this gives more driver-specific information
        try {
          final requestDetail = await DriverService.getDriverRequestDetail(widget.orderId!);
          if (requestDetail.containsKey('order')) {
            _order = Order.fromJson(requestDetail['order']);
          }
        } catch (e) {
          // Fallback to regular order service if driver-specific API fails
          print('Error loading driver request detail: $e');
          final orderData = await OrderService.getOrderById(widget.orderId!);
          _order = Order.fromJson(orderData);
        }
      }

      // Ensure we have an order at this point
      if (_order == null) {
        throw Exception('Order information not available');
      }

      // Get tracking information for this order
      final trackingData = await TrackingService.getOrderTracking(_order!.id);
      _tracking = Tracking.fromJson(trackingData);

      // Extract customer information from order data
      if (_order!.customerId != null) {
        // Extract customer data from tracking data if available
        Map<String, dynamic> userData = trackingData['user'] ?? {};
        if (userData.isNotEmpty) {
          _customer = Customer.fromJson(userData);
        } else {
          // Fallback to create a minimal customer object
          _customer = Customer(
            id: _order!.customerId.toString(),
            name: "Customer",
            email: "",
            phoneNumber: "",
            role: 'customer',
          );
        }
      }

      // Start location tracking if we're the driver of this order
      await _checkAndStartDriverTracking();

      // Start periodic tracking updates
      _startTrackingUpdates();

      // Start animations
      for (var controller in _cardControllers) {
        controller.forward();
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isError = true;
        _errorMessage = 'Failed to load order: ${e.toString()}';
      });

      print('Error loading order data: $e');
    }
  }

  // Check if we're the driver and start location tracking if so
  Future<void> _checkAndStartDriverTracking() async {
    try {
      // Get the current user's ID
      final String? userId = await TokenService.getUserId();

      if (userId != null && _order != null && _order!.driverId != null) {
        // Check if the current user is the driver for this order
        if (userId == _order!.driverId.toString()) {
          // We are the driver, start location tracking
          await _locationService.startTracking();
        }
      }
    } catch (e) {
      print('Error checking driver status: $e');
    }
  }

  // Start periodic tracking updates
  void _startTrackingUpdates() {
    // Cancel existing timer if any
    _trackingUpdateTimer?.cancel();

    // Set up timer to fetch updates every 10 seconds
    _trackingUpdateTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (_order == null) return;

      try {
        final trackingData = await TrackingService.getOrderTracking(_order!.id);

        if (mounted) {
          setState(() {
            _tracking = Tracking.fromJson(trackingData);
          });

          // Update map with new tracking data
          if (mapboxMap != null) {
            _updateMapAnnotations();
          }
        }
      } catch (e) {
        print('Error updating tracking data: $e');
        // Don't show error to user for background updates
      }
    });
  }

  // Update map markers and route based on current tracking data
  void _updateMapAnnotations() {
    if (_tracking != null) {
      _addMarkers();
      _fetchAndDrawRoute();
    }
  }

  // Fetch route from Mapbox Directions API and draw it
  Future<void> _fetchAndDrawRoute() async {
    if (_tracking == null || polylineAnnotationManager == null) return;

    try {
      // First, clear existing route
      await polylineAnnotationManager?.deleteAll();

      // We need at least driver position and either store or customer position to draw a route
      if (_tracking!.driverPosition.lat == 0 || _tracking!.driverPosition.lng == 0) {
        return; // Invalid driver position
      }

      List<Position> routeCoordinates = [];

      // Determine route waypoints based on order status
      switch (_tracking!.status) {
        case OrderStatus.driverHeadingToStore:
        case OrderStatus.pending:
        case OrderStatus.approved:
        // Driver to store route
          routeCoordinates = await _fetchRouteCoordinates(
              _tracking!.driverPosition,
              _tracking!.storePosition
          );
          break;

        case OrderStatus.driverAtStore:
        case OrderStatus.preparing:
        case OrderStatus.driverHeadingToCustomer:
        case OrderStatus.on_delivery:
        // Store to customer route
          routeCoordinates = await _fetchRouteCoordinates(
              _tracking!.driverPosition,
              _tracking!.customerPosition
          );
          break;

        default:
        // For other statuses, just draw a direct route from driver to customer
          routeCoordinates = await _fetchRouteCoordinates(
              _tracking!.driverPosition,
              _tracking!.customerPosition
          );
          break;
      }

      // If we have route coordinates, draw them
      if (routeCoordinates.isNotEmpty) {
        final polylineOptions = PolylineAnnotationOptions(
          geometry: LineString(coordinates: routeCoordinates),
          lineColor: Colors.blue.value,
          lineWidth: 4.0,
        );

        await polylineAnnotationManager?.create(polylineOptions);
      }
    } catch (e) {
      print('Error fetching or drawing route: $e');
    }
  }

  // Fetch route coordinates from Mapbox Directions API
  Future<List<Position>> _fetchRouteCoordinates(Position origin, Position destination) async {
    try {
      // Skip if either position is invalid
      if (origin.lat == 0 || origin.lng == 0 || destination.lat == 0 || destination.lng == 0) {
        return [];
      }

      final token = await TokenService.getToken();

      // Use the Mapbox Directions API to get the route
      final response = await http.get(
        Uri.parse(
            'https://api.mapbox.com/directions/v5/mapbox/driving/'
                '${origin.lng},${origin.lat};${destination.lng},${destination.lat}'
                '?geometries=geojson&access_token=$mapboxAccessToken'
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['routes'] != null && data['routes'].isNotEmpty) {
          // Extract the route geometry
          final geometry = data['routes'][0]['geometry'];

          if (geometry != null && geometry['coordinates'] != null) {
            // Convert coordinates to List<Position>
            final List coordinates = geometry['coordinates'];
            return coordinates.map((point) =>
                Position(point[0].toDouble(), point[1].toDouble())
            ).toList();
          }
        }
      }

      // If API call fails or no routes found, return a direct line
      return [origin, destination];
    } catch (e) {
      print('Error fetching route: $e');
      // Return a direct line as fallback
      return [origin, destination];
    }
  }

  // Build customer info card
  Widget _buildCustomerInfo() {
    if (_customer == null) {
      return const SizedBox.shrink();
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
                _customer?.profileImageUrl != null && _customer!.profileImageUrl!.isNotEmpty
                    ? ImageService.displayImage(
                  imageSource: _customer!.profileImageUrl!,
                  width: 60,
                  height: 60,
                  borderRadius: BorderRadius.circular(30),
                )
                    : Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: const Icon(Icons.person),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _customer?.name ?? "Customer",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _customer?.phoneNumber ?? "",
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _customer?.email ?? "",
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
    if (_order == null) {
      return const SizedBox.shrink();
    }

    // Calculate estimated time and distance from tracking data
    String estimatedTime = _tracking != null ? _tracking!.formattedETA : "15 menit";
    String distance = _tracking != null
        ? "${(_order!.store.distance).toStringAsFixed(1)} km"
        : "2.5 km";

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
              _order!.store.name,
              _order!.store.address,
              Icons.store,
            ),
            const Divider(height: 24),
            _buildLocationItem(
              'Alamat Pengantaran',
              'Lokasi Pemesan',
              _order!.deliveryAddress,
              Icons.location_on,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  'Estimasi Waktu: $estimatedTime',
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
                  'Jarak: $distance',
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
                      ImageService.displayImage(
                        imageSource: item.imageUrl,
                        width: 60,
                        height: 60,
                        borderRadius: BorderRadius.circular(8),
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
                              item.formatPrice(),
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
                  _order!.formatTotal(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: GlobalStyle.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.payment, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Metode Pembayaran: ${_order!.paymentMethod == PaymentMethod.cash ? 'Tunai' : 'Digital'}',
                  style: const TextStyle(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? _buildLoadingView()
          : _isError
          ? _buildErrorView()
          : _buildMainView(),
    );
  }

  // Loading view
  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Memuat informasi pesanan...'),
        ],
      ),
    );
  }

  // Error view
  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(_errorMessage),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadOrderData,
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  // Main view
  Widget _buildMainView() {
    return Stack(
      children: [
        // Mapbox View
        SizedBox(
          height: MediaQuery.of(context).size.height,
          child: MapWidget(
            key: const ValueKey("mapWidget"),
            onMapCreated: _onMapCreated,
            styleUri: "mapbox://styles/ifs21002/cm71crfz300sw01s10wsh3zia",
            cameraOptions: CameraOptions(
              center: _tracking != null
                  ? Point(coordinates: _tracking!.driverPosition)
                  : Point(coordinates: _getCenterPosition()), // Use calculated position
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
                  _tracking?.statusMessage ?? 'Pengantaran dalam proses',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _tracking != null
                      ? 'Estimasi tiba: ${_tracking!.formattedETA}'
                      : 'Estimasi tiba: 15 menit',
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
                    if (!isExpanded && _customer != null)
                      SlideTransition(
                        position: _cardAnimations[0],
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            children: [
                              _customer?.profileImageUrl != null && _customer!.profileImageUrl!.isNotEmpty
                                  ? ImageService.displayImage(
                                imageSource: _customer!.profileImageUrl!,
                                width: 50,
                                height: 50,
                                borderRadius: BorderRadius.circular(25),
                              )
                                  : Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: const Icon(Icons.person),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _customer?.name ?? "Customer",
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _order?.deliveryAddress ?? '',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_order != null)
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
                                      _order!.formatTotal(),
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
                            _completeOrder();
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
    );
  }

  // Get center position for map (prioritize actual coordinates if available)
  Position _getCenterPosition() {
    // If we have tracking data, use driver position
    if (_tracking != null) {
      return _tracking!.driverPosition;
    }

    // If we have store coordinates, use those
    if (_order != null && _order!.store.latitude != null && _order!.store.longitude != null) {
      return Position(_order!.store.longitude!, _order!.store.latitude!);
    }

    // Try to get current location from location service
    final position = _locationService.currentPosition;
    if (position != null) {
      return Position(position.longitude, position.latitude);
    }

    // Fallback to default position (can be set to a central location in your service area)
    return Position(99.10279, 2.34379);
  }

  // Handle completion of the order
  Future<void> _completeOrder() async {
    try {
      // Show loading dialog first
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Dialog(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Memproses pesanan...'),
                ],
              ),
            ),
          );
        },
      );

      // Call API to update order status through DriverService
      // Updated to respond to driver request with 'complete' action
      if (_order != null) {
        await DriverService.respondToDriverRequest(_order!.id, 'complete');
      }

      // Stop location tracking when order is complete
      _locationService.stopTracking();

      // Close loading dialog
      Navigator.pop(context);

      // Show completion dialog
      _showOrderCompletedDialog();
    } catch (e) {
      // Close loading dialog if open
      Navigator.pop(context);

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyelesaikan pesanan: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
      _updateMapAnnotations();
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

    // If we have tracking data, use it
    if (_tracking != null) {
      // Customer marker
      final customerOptions = PointAnnotationOptions(
        geometry: Point(coordinates: _tracking!.customerPosition),
        iconImage: "assets/images/marker_red.png",
      );

      // Store marker
      final storeOptions = PointAnnotationOptions(
        geometry: Point(coordinates: _tracking!.storePosition),
        iconImage: "assets/images/marker_blue.png",
      );

      // Driver marker
      final driverOptions = PointAnnotationOptions(
        geometry: Point(coordinates: _tracking!.driverPosition),
        iconImage: "assets/images/marker_green.png",
      );

      await pointAnnotationManager?.create(customerOptions);
      await pointAnnotationManager?.create(storeOptions);
      await pointAnnotationManager?.create(driverOptions);
    }
    // If we only have order data, try to use store coordinates
    else if (_order != null && _order!.store.latitude != null && _order!.store.longitude != null) {
      // Store marker
      final storeOptions = PointAnnotationOptions(
        geometry: Point(coordinates: Position(_order!.store.longitude!, _order!.store.latitude!)),
        iconImage: "assets/images/marker_blue.png",
      );

      await pointAnnotationManager?.create(storeOptions);
    }
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