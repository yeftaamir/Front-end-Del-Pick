import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:lottie/lottie.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Models/tracking.dart';
import 'package:del_pick/Models/order.dart';
import 'package:del_pick/Models/order_enum.dart';
import 'package:del_pick/Models/driver.dart';
import 'package:del_pick/Models/store.dart';
import 'package:del_pick/Models/customer.dart';
import 'package:del_pick/Views/Component/order_status_card.dart';
import 'package:del_pick/Services/order_service.dart';
import 'package:del_pick/Services/tracking_service.dart';
import 'package:del_pick/Services/auth_service.dart';
import 'package:del_pick/Services/core/token_service.dart';
import 'package:del_pick/Services/image_service.dart';
import 'package:del_pick/Views/Customers/history_detail.dart';

// Custom Position class to avoid conflicts with geotypes.Position
class PositionCustom {
  final double longitude;
  final double latitude;

  PositionCustom(this.longitude, this.latitude);

  // Convert to Mapbox Point
  Point toPoint() {
    return Point(coordinates: Position(longitude, latitude));
  }
}

class TrackCustOrderScreen extends StatefulWidget {
  static const String route = "/Customers/TrackOrder";

  final String? orderId;
  final Order? order;

  const TrackCustOrderScreen({Key? key, this.orderId, this.order}) : super(key: key);

  @override
  State<TrackCustOrderScreen> createState() => _TrackCustOrderScreenState();
}

class _TrackCustOrderScreenState extends State<TrackCustOrderScreen> with TickerProviderStateMixin {
  // Map configuration
  MapboxMap? mapboxMap;
  PointAnnotationManager? pointAnnotationManager;
  PolylineAnnotationManager? polylineAnnotationManager;
  final String _mapboxAccessToken = 'pk.eyJ1IjoiY3lydWJhZWsxMjMiLCJhIjoiY2ttbWMxYTRrMHhxdjJ3cXBmaGFxcjhlbyJ9.ODLNIKuSUu5-RdAceSXZfw'; // Replace with your actual token

  // Draggable scroll controller
  DraggableScrollableController dragController = DraggableScrollableController();
  bool isExpanded = false;

  // Data variables
  Order? _order;
  Tracking? _tracking;
  bool _isLoading = true;
  String _errorMessage = '';
  bool _isTokenValid = false;
  Customer? _customer;
  Driver? _driver;
  Store? _store;
  String _userRole = 'customer'; // Default role

  // Track estimated delivery time
  String _estimatedArrival = 'Calculating...';
  int _estimatedMinutes = 0;

  // Audio player
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Animation controllers
  late AnimationController _routeAnimationController;
  late AnimationController _markerAnimationController;
  Animation<double>? _markerPositionAnimation;

  // Timer for periodic data refresh
  Timer? _refreshTimer;
  Timer? _driverPositionTimer;

  // Previous driver position for smooth animation
  PositionCustom? _previousDriverPosition;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _routeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _markerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // Get user role
    _getUserRole();

    // Check token validity first
    _checkTokenAndInitialize();

    // Set up periodic data refresh every 15 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _refreshTrackingData());
  }

  // Get the user role for OrderStatusCard
  Future<void> _getUserRole() async {
    try {
      final role = await TokenService.getUserRole();
      if (role != null) {
        setState(() {
          _userRole = role;
        });
      }
    } catch (e) {
      print('Error getting user role: $e');
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _driverPositionTimer?.cancel();
    _routeAnimationController.dispose();
    _markerAnimationController.dispose();
    dragController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // Check token validity before initializing data
  Future<void> _checkTokenAndInitialize() async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        setState(() {
          _isTokenValid = false;
          _isLoading = false;
          _errorMessage = 'Authentication token not found. Please login again.';
        });
        return;
      }

      // Get user profile to verify token is valid
      final userData = await AuthService.getUserData();
      if (userData == null) {
        setState(() {
          _isTokenValid = false;
          _isLoading = false;
          _errorMessage = 'User data not found. Please login again.';
        });
        return;
      }

      setState(() {
        _isTokenValid = true;
        // Create customer data from user data
        if (userData['role'] == 'customer') {
          _customer = Customer.fromStoredData(userData);
        }
      });

      // Initialize data if token is valid
      await _initializeData();
    } catch (e) {
      setState(() {
        _isTokenValid = false;
        _isLoading = false;
        _errorMessage = 'Authentication error: ${e.toString()}';
      });
    }
  }

  // Initialize data from services
  Future<void> _initializeData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      // Determine which order ID to use
      final String orderId = widget.orderId ?? widget.order?.id ?? '';

      if (orderId.isEmpty) {
        throw Exception('Order ID is required');
      }

      // Get order details if not provided
      if (widget.order == null) {
        // Use updated OrderService.getOrderDetail
        final orderData = await OrderService.getOrderDetail(orderId);
        _order = Order.fromJson(orderData);
      } else {
        _order = widget.order;
      }

      // Get tracking data
      final trackingData = await TrackingService.getOrderTracking(orderId);

      // Create tracking object with tracking data from API
      if (trackingData != null) {
        _tracking = Tracking.fromJson(trackingData);

        // Convert tracking positions to our custom PositionCustom objects
        _previousDriverPosition = _convertToCustomPosition(_tracking!.driverPosition);

        // Calculate estimated delivery time based on distance
        double distance = _calculateDistance(
            _convertToCustomPosition(_tracking!.driverPosition),
            _convertToCustomPosition(_tracking!.customerPosition)
        );
        _estimatedMinutes = _calculateEstimatedDeliveryTime(distance);
        _updateEstimatedArrival();
      }

      // Get driver details from tracking
      if (_tracking?.driver != null) {
        _driver = _tracking?.driver;
      }

      setState(() {
        _isLoading = false;
      });

      // Set up the map if tracking data is available
      if (_tracking != null && mapboxMap != null) {
        _setupMapAnnotations();
        _fetchRouteDirections();
      }

    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load tracking data: ${e.toString()}';
      });
    }
  }

  // Convert from Tracking.Position to our PositionCustom
  PositionCustom _convertToCustomPosition(dynamic position) {
    // Handle different types of position objects
    if (position is Map<String, dynamic>) {
      return PositionCustom(
        position['longitude'] ?? 0.0,
        position['latitude'] ?? 0.0,
      );
    } else {
      // Assuming it's the Position from Tracking model
      return PositionCustom(position.lng, position.lat);
    }
  }

  // Calculate estimated delivery time based on distance
  int _calculateEstimatedDeliveryTime(double distanceInKm) {
    // Average speed: 30 km/h in city traffic
    // Convert to minutes: (distance / speed) * 60
    int minutes = (distanceInKm / 30 * 60).round();

    // Add 5 minutes buffer
    return minutes + 5;
  }

  // Update the estimated arrival time string
  void _updateEstimatedArrival() {
    if (_estimatedMinutes <= 0) {
      _estimatedArrival = 'Arriving soon';
      return;
    }

    if (_estimatedMinutes < 60) {
      _estimatedArrival = '$_estimatedMinutes minutes';
    } else {
      int hours = _estimatedMinutes ~/ 60;
      int minutes = _estimatedMinutes % 60;
      _estimatedArrival = '$hours hour${hours > 1 ? 's' : ''} $minutes minute${minutes > 1 ? 's' : ''}';
    }
  }

  // Refresh tracking data
  Future<void> _refreshTrackingData() async {
    if (_order == null || !_isTokenValid) return;

    try {
      final trackingData = await TrackingService.getOrderTracking(_order!.id);
      final newTracking = Tracking.fromJson(trackingData);

      // Store previous position before updating
      _previousDriverPosition = _convertToCustomPosition(_tracking?.driverPosition);

      setState(() {
        _tracking = newTracking;
      });

      // Recalculate estimated time
      if (_tracking != null) {
        double distance = _calculateDistance(
            _convertToCustomPosition(_tracking!.driverPosition),
            _convertToCustomPosition(_tracking!.customerPosition)
        );
        _estimatedMinutes = _calculateEstimatedDeliveryTime(distance);
        _updateEstimatedArrival();
      }

      // Only animate marker and update route if position changed
      if (_previousDriverPosition != null &&
          _tracking != null) {
        final currentDriverPos = _convertToCustomPosition(_tracking!.driverPosition);
        if (_previousDriverPosition!.longitude != currentDriverPos.longitude ||
            _previousDriverPosition!.latitude != currentDriverPos.latitude) {
          _animateDriverMarker();
          _fetchRouteDirections();
        }
      }

    } catch (e) {
      print('Error refreshing tracking data: $e');
      // Don't update state to avoid disrupting the UI
    }
  }

  // Set up map annotation managers
  Future<void> _setupMapAnnotations() async {
    if (mapboxMap == null || _tracking == null) return;

    pointAnnotationManager = await mapboxMap!.annotations.createPointAnnotationManager();
    polylineAnnotationManager = await mapboxMap!.annotations.createPolylineAnnotationManager();

    // Add initial markers
    _addMapMarkers();

    // Center camera on driver position
    _centerMapOnDriver();
  }

  // Add markers for driver, store, and customer
  Future<void> _addMapMarkers() async {
    if (pointAnnotationManager == null || _tracking == null) return;

    // Clear existing markers
    await pointAnnotationManager!.deleteAll();

    // Driver position as PositionCustom
    final driverPos = _convertToCustomPosition(_tracking!.driverPosition);

    // Store position as PositionCustom
    final storePos = _convertToCustomPosition(_tracking!.storePosition);

    // Customer position as PositionCustom
    final customerPos = _convertToCustomPosition(_tracking!.customerPosition);

    // Driver marker
    final driverOptions = PointAnnotationOptions(
      geometry: Point(coordinates: Position(driverPos.longitude, driverPos.latitude)),
      iconImage: "assets/images/marker_driver.png",
      iconSize: 1.2,
    );

    // Store marker
    final storeOptions = PointAnnotationOptions(
      geometry: Point(coordinates: Position(storePos.longitude, storePos.latitude)),
      iconImage: "assets/images/marker_store.png",
      iconSize: 1.0,
    );

    // Customer marker
    final customerOptions = PointAnnotationOptions(
      geometry: Point(coordinates: Position(customerPos.longitude, customerPos.latitude)),
      iconImage: "assets/images/marker_customer.png",
      iconSize: 1.0,
    );

    await pointAnnotationManager!.create(driverOptions);
    await pointAnnotationManager!.create(storeOptions);
    await pointAnnotationManager!.create(customerOptions);
  }

  // Animate driver marker when position changes
  void _animateDriverMarker() {
    if (_tracking == null || _previousDriverPosition == null) return;

    // Reset animation controller
    _markerAnimationController.reset();

    // Get current driver position
    final currentDriverPos = _convertToCustomPosition(_tracking!.driverPosition);

    // Create animation for driver position
    _markerPositionAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _markerAnimationController,
      curve: Curves.easeInOut,
    ));

    // Listen to animation and update driver marker
    _markerAnimationController.addListener(() {
      if (_markerPositionAnimation == null) return;

      // Calculate interpolated position
      final double t = _markerPositionAnimation!.value;
      final double newLng = _previousDriverPosition!.longitude +
          (currentDriverPos.longitude - _previousDriverPosition!.longitude) * t;
      final double newLat = _previousDriverPosition!.latitude +
          (currentDriverPos.latitude - _previousDriverPosition!.latitude) * t;

      // Update driver marker position
      _updateDriverMarkerPosition(PositionCustom(newLng, newLat));
    });

    // Start animation
    _markerAnimationController.forward();
  }

  // Update driver marker position without animation
  Future<void> _updateDriverMarkerPosition(PositionCustom position) async {
    if (pointAnnotationManager == null) return;

    // First remove existing annotations
    await pointAnnotationManager!.deleteAll();

    // Re-create all markers with updated driver position
    // Driver marker (with updated position)
    final driverOptions = PointAnnotationOptions(
      geometry: Point(coordinates: Position(position.longitude, position.latitude)),
      iconImage: "assets/images/marker_driver.png",
      iconSize: 1.2,
    );

    // Add store and customer markers (unchanged)
    if (_tracking != null) {
      // Store position as PositionCustom
      final storePos = _convertToCustomPosition(_tracking!.storePosition);

      // Customer position as PositionCustom
      final customerPos = _convertToCustomPosition(_tracking!.customerPosition);

      // Store marker
      final storeOptions = PointAnnotationOptions(
        geometry: Point(coordinates: Position(storePos.longitude, storePos.latitude)),
        iconImage: "assets/images/marker_store.png",
        iconSize: 1.0,
      );

      // Customer marker
      final customerOptions = PointAnnotationOptions(
        geometry: Point(coordinates: Position(customerPos.longitude, customerPos.latitude)),
        iconImage: "assets/images/marker_customer.png",
        iconSize: 1.0,
      );

      await pointAnnotationManager!.create(storeOptions);
      await pointAnnotationManager!.create(customerOptions);
    }

    // Always add driver marker last so it appears on top
    await pointAnnotationManager!.create(driverOptions);

    // Center map on driver
    _centerMapOnDriver(position: position);
  }

  // Center map on driver position
  void _centerMapOnDriver({PositionCustom? position}) {
    if (mapboxMap == null) return;

    PositionCustom? driverPos;
    if (position != null) {
      driverPos = position;
    } else if (_tracking != null) {
      driverPos = _convertToCustomPosition(_tracking!.driverPosition);
    }

    if (driverPos == null) return;

    mapboxMap!.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(driverPos.longitude, driverPos.latitude)),
        zoom: 14.5,
        bearing: 0,
        pitch: 45,
      ),
      MapAnimationOptions(duration: 1000),
    );
  }

  // Fetch route directions using Mapbox Directions API
  Future<void> _fetchRouteDirections() async {
    if (_tracking == null || mapboxMap == null) return;

    try {
      // Determine origin and destination based on order status
      PositionCustom origin = _convertToCustomPosition(_tracking!.driverPosition);
      PositionCustom destination;

      // If driver is heading to store, route should be from driver to store
      if (_tracking!.status == OrderStatus.driverHeadingToStore ||
          _tracking!.status == OrderStatus.driverAssigned) {
        destination = _convertToCustomPosition(_tracking!.storePosition);
      }
      // Otherwise, route should be from driver to customer
      else {
        destination = _convertToCustomPosition(_tracking!.customerPosition);
      }

      // Request Mapbox directions
      final directionsResponse = await _getDirections(origin, destination);

      // Process response and draw route
      _drawRoute(directionsResponse);

    } catch (e) {
      print('Error fetching directions: $e');
      // Fallback to direct line if directions API fails
      _drawDirectLine();
    }
  }

  // Get directions from Mapbox Directions API
  Future<List<PositionCustom>> _getDirections(PositionCustom origin, PositionCustom destination) async {
    // This would normally be an API call to Mapbox Directions API
    // For this implementation, we'll simulate a real route with waypoints

    // Create a simulated route with extra waypoints
    List<PositionCustom> waypoints = [];

    // Add origin
    waypoints.add(origin);

    // Add intermediate points (simulating a curved route)
    final double distance = _calculateDistance(origin, destination);
    final int numPoints = (distance * 100).round(); // More points for longer distances

    // Generate intermediate waypoints with some randomness for a realistic path
    if (numPoints > 2) {
      final double baseLat = origin.latitude;
      final double baseLng = origin.longitude;
      final double latDiff = destination.latitude - origin.latitude;
      final double lngDiff = destination.longitude - origin.longitude;

      for (int i = 1; i < numPoints; i++) {
        final double fraction = i / numPoints;

        // Add some random variation to simulate real roads
        final double randomFactor = (i % 2 == 0) ? 0.0002 : -0.0002;

        final double waypointLat = baseLat + (latDiff * fraction) + randomFactor;
        final double waypointLng = baseLng + (lngDiff * fraction) + randomFactor;

        waypoints.add(PositionCustom(waypointLng, waypointLat));
      }
    }

    // Add destination
    waypoints.add(destination);

    return waypoints;
  }

  // Draw an animated route on the map
  Future<void> _drawRoute(List<PositionCustom> routePoints) async {
    if (polylineAnnotationManager == null || routePoints.isEmpty) return;

    // Clear existing routes
    await polylineAnnotationManager!.deleteAll();

    // Reset animation controller
    _routeAnimationController.reset();

    // Create route animation
    Animation<double> routeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _routeAnimationController,
      curve: Curves.easeInOut,
    ));

    // Listen to animation and update route
    _routeAnimationController.addListener(() {
      _updateRouteProgress(routePoints, routeAnimation.value);
    });

    // Start animation
    _routeAnimationController.forward();
  }

  // Update route progress during animation
  Future<void> _updateRouteProgress(List<PositionCustom> routePoints, double progress) async {
    if (polylineAnnotationManager == null) return;

    // Calculate how many points to show based on progress
    int pointsToShow = (routePoints.length * progress).round();
    pointsToShow = pointsToShow.clamp(2, routePoints.length);

    // Get sublist of points to display
    List<PositionCustom> currentRoutePoints = routePoints.sublist(0, pointsToShow);

    // Clear existing routes
    await polylineAnnotationManager!.deleteAll();

    // Convert to mapbox Position
    List<Position> mapboxPositions = currentRoutePoints.map((pos) =>
        Position(pos.longitude, pos.latitude)
    ).toList();

    // Create route line
    final routeOptions = PolylineAnnotationOptions(
      geometry: LineString(coordinates: mapboxPositions),
      lineWidth: 5.0,
      lineColor: GlobalStyle.primaryColor.value,
    );

    // Create route animation effect (secondary line)
    final routeAnimationOptions = PolylineAnnotationOptions(
      geometry: LineString(coordinates: mapboxPositions),
      lineWidth: 8.0,
      lineColor: GlobalStyle.primaryColor.withOpacity(0.4).value,
    );

    await polylineAnnotationManager!.create(routeAnimationOptions);
    await polylineAnnotationManager!.create(routeOptions);
  }

  // Fallback: Draw direct line between points if directions API fails
  Future<void> _drawDirectLine() async {
    if (polylineAnnotationManager == null || _tracking == null) return;

    // Clear existing routes
    await polylineAnnotationManager!.deleteAll();

    // Determine route points based on order status
    List<PositionCustom> routePoints = [];
    if (_tracking!.status == OrderStatus.driverHeadingToStore ||
        _tracking!.status == OrderStatus.driverAssigned) {
      routePoints = [
        _convertToCustomPosition(_tracking!.driverPosition),
        _convertToCustomPosition(_tracking!.storePosition),
      ];
    } else {
      routePoints = [
        _convertToCustomPosition(_tracking!.driverPosition),
        _convertToCustomPosition(_tracking!.customerPosition),
      ];
    }

    // Convert to mapbox Position
    List<Position> mapboxPositions = routePoints.map((pos) =>
        Position(pos.longitude, pos.latitude)
    ).toList();

    // Create route line
    final routeOptions = PolylineAnnotationOptions(
      geometry: LineString(coordinates: mapboxPositions),
      lineWidth: 4.0,
      lineColor: GlobalStyle.primaryColor.value,
    );

    await polylineAnnotationManager!.create(routeOptions);
  }

  // Calculate distance between two positions (Haversine formula)
  double _calculateDistance(PositionCustom pos1, PositionCustom pos2) {
    const double earthRadius = 6371.0; // Earth radius in kilometers
    final double lat1 = pos1.latitude * (math.pi / 180.0); // Convert to radians
    final double lat2 = pos2.latitude * (math.pi / 180.0);
    final double lng1 = pos1.longitude * (math.pi / 180.0);
    final double lng2 = pos2.longitude * (math.pi / 180.0);

    final double dLat = lat2 - lat1;
    final double dLng = lng2 - lng1;

    final double a = math.sin(dLat / 2.0) * math.sin(dLat / 2.0) +
        math.cos(lat1) * math.cos(lat2) *
            math.sin(dLng / 2.0) * math.sin(dLng / 2.0);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? _buildLoadingView()
          : _errorMessage.isNotEmpty
          ? _buildErrorView()
          : _buildTrackingView(),
    );
  }

  // Loading view
  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: GlobalStyle.primaryColor),
          const SizedBox(height: 16),
          const Text('Loading tracking information...'),
        ],
      ),
    );
  }

  // Error view
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _isTokenValid ? _initializeData() : _checkTokenAndInitialize(),
              style: ElevatedButton.styleFrom(
                backgroundColor: GlobalStyle.primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Try Again'),
            ),
            if (!_isTokenValid)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: ElevatedButton(
                  onPressed: () {
                    // Navigate to login screen
                    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('Go to Login'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Main tracking view
  Widget _buildTrackingView() {
    if (_order == null || _tracking == null) {
      return Center(child: Text('No tracking data available'));
    }

    return Stack(
      children: [
        // Mapbox View
        SizedBox(
          height: MediaQuery.of(context).size.height,
          child: MapWidget(
            key: const ValueKey("mapWidget"),
            onMapCreated: _onMapCreated,
            styleUri: MapboxStyles.MAPBOX_STREETS,
            cameraOptions: CameraOptions(
              center: Point(coordinates: Position(
                  _convertToCustomPosition(_tracking!.driverPosition).longitude,
                  _convertToCustomPosition(_tracking!.driverPosition).latitude
              )),
              zoom: 14.5,
              bearing: 0,
              pitch: 45, // Add slight 3D perspective
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
                  _tracking!.statusMessage,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_tracking!.status != OrderStatus.completed && _tracking!.status != OrderStatus.cancelled)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Estimasi tiba: $_estimatedArrival',
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
                        orderId: _order!.id,
                        userRole: _userRole,
                      ),
                    ),

                    // Driver Info
                    _buildDriverInfo(),

                    // Delivery Information
                    _buildDeliveryInfo(),

                    // Confirmation Button
                    if (_tracking!.status == OrderStatus.driverArrived)
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
                              _showOrderCompletedDialog();
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
    );
  }

  // Build driver info section
  Widget _buildDriverInfo() {
    final driver = _tracking?.driver;

    if (driver == null) {
      return const SizedBox.shrink();
    }

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
                child: driver.profileImageUrl != null && driver.profileImageUrl!.isNotEmpty
                    ? ClipOval(
                  child: ImageService.displayImage(
                    imageSource: driver.profileImageUrl!,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                  ),
                )
                    : Icon(
                  Icons.person,
                  size: 30,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver.name,
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
                          driver.vehicleNumber,
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
                          driver.rating.toString(),
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
                  onPressed: () => _callDriver(driver.phoneNumber),
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
                  onPressed: () => _messageDriver(driver.phoneNumber),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Call driver function with url_launcher
  Future<void> _callDriver(String phoneNumber) async {
    if (phoneNumber.isEmpty) {
      _showFeatureNotImplemented('Driver phone number not available');
      return;
    }

    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        _showFeatureNotImplemented('Cannot make phone call');
      }
    } catch (e) {
      print('Error making phone call: $e');
      _showFeatureNotImplemented('Cannot make phone call');
    }
  }

  // Message driver function with url_launcher
  Future<void> _messageDriver(String phoneNumber) async {
    if (phoneNumber.isEmpty) {
      _showFeatureNotImplemented('Driver phone number not available');
      return;
    }

    final Uri smsUri = Uri(scheme: 'sms', path: phoneNumber);
    try {
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      } else {
        _showFeatureNotImplemented('Cannot send message');
      }
    } catch (e) {
      print('Error sending message: $e');
      _showFeatureNotImplemented('Cannot send message');
    }
  }

  // Build delivery info card
  Widget _buildDeliveryInfo() {
    if (_order == null) {
      return const SizedBox.shrink();
    }

    // Calculate distance between store and delivery address
    double distance = 0.0;
    if (_tracking != null) {
      distance = _calculateDistance(
          _convertToCustomPosition(_tracking!.storePosition),
          _convertToCustomPosition(_tracking!.customerPosition)
      );
    }

    final formattedDistance = distance < 10
        ? '${distance.toStringAsFixed(1)} km'
        : '${distance.toStringAsFixed(0)} km';

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
            _order!.store.name,
            _order!.store.address,
            Icons.store,
          ),
          const Divider(height: 24),
          _buildLocationItem(
            'Alamat Pengantaran',
            'Alamat Pengiriman',
            _order!.deliveryAddress,
            Icons.location_on,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                'Estimasi Waktu: $_estimatedArrival',
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
                'Jarak: $formattedDistance',
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
          Text(
            'Rincian Pesanan (${_order!.items.length} item)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: GlobalStyle.fontColor,
            ),
          ),
          const SizedBox(height: 8),
          ..._order!.items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${item.quantity}x ${item.name}',
                  style: TextStyle(
                    fontSize: 14,
                    color: GlobalStyle.fontColor,
                  ),
                ),
                Text(
                  GlobalStyle.formatRupiah(item.price * item.quantity),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: GlobalStyle.fontColor,
                  ),
                ),
              ],
            ),
          )).toList(),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Subtotal',
                style: TextStyle(
                  fontSize: 14,
                ),
              ),
              Text(
                GlobalStyle.formatRupiah(_order!.subtotal),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Biaya Pengiriman',
                style: TextStyle(
                  fontSize: 14,
                ),
              ),
              Text(
                GlobalStyle.formatRupiah(_order!.serviceCharge),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
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
                GlobalStyle.formatRupiah(_order!.total),
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
              Icon(Icons.payment, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
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
            color: GlobalStyle.primaryColor.withOpacity(0.1),
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

  void _onMapCreated(MapboxMap mapboxMap) {
    this.mapboxMap = mapboxMap;

    if (_tracking != null) {
      _setupMapAnnotations();
      _fetchRouteDirections();
    }
  }

  // Show not implemented feature dialog
  void _showFeatureNotImplemented(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

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
                    // Update order status and go to history detail
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

  // Order completion handler
  void _completeOrder() async {
    try {
      // Use updated OrderService instead of TrackingService
      await OrderService.updateOrderStatus(_order!.id, 'completed');

      // Navigate to history detail
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HistoryDetailPage(
            order: _order!,
          ),
        ),
      );
    } catch (e) {
      print('Error completing order: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyelesaikan pesanan: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Play sound
  Future<void> _playSound(String assetPath) async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource(assetPath));
    } catch (e) {
      print('Error playing sound: $e');
    }
  }
}