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
import 'package:del_pick/Models/user.dart';
import 'package:del_pick/Services/order_service.dart';
import 'package:del_pick/Services/tracking_service.dart';
import 'package:del_pick/Services/driver_service.dart';
import 'package:del_pick/Services/menu_item_service.dart';
import 'package:del_pick/Services/auth_service.dart';
import 'package:del_pick/Services/core/token_service.dart';
import 'package:del_pick/Services/image_service.dart';
import 'package:del_pick/Views/Customers/history_detail.dart';

import '../Component/cust_order_status.dart';

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
  final String _mapboxAccessToken = 'pk.eyJ1IjoiY3lydWJhZWsxMjMiLCJhIjoiY2ttbWMxYTRrMHhxdjJ3cXBmaGFxcjhlbyJ9.ODLNIKuSUu5-RdAceSXZfw';

  // Draggable scroll controller
  DraggableScrollableController dragController = DraggableScrollableController();
  bool isExpanded = false;

  // Data variables
  Order? _order;
  Map<String, dynamic>? _trackingData;
  bool _isLoading = true;
  String _errorMessage = '';
  bool _isTokenValid = false;
  User? _customer;
  Driver? _driver;
  Store? _store;
  String _userRole = 'customer';

  // Driver position data
  PositionCustom? _driverPosition;
  PositionCustom? _storePosition;
  PositionCustom? _customerPosition;

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
          _customer = User.fromJson(userData);
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
      final String orderId = widget.orderId ?? widget.order?.id.toString() ?? '';

      if (orderId.isEmpty) {
        throw Exception('Order ID is required');
      }

      // Get order details if not provided using updated OrderService
      if (widget.order == null) {
        final orderData = await OrderService.getOrderById(orderId);
        _order = Order.fromJson(orderData);
      } else {
        _order = widget.order;
      }

      // Get tracking data using updated TrackingService
      _trackingData = await TrackingService.getTrackingData(orderId);

      if (_trackingData != null) {
        // Process tracking data
        await _processTrackingData();
      }

      // Get additional driver details if driver is assigned
      if (_order?.driverId != null) {
        await _getDriverDetails(_order!.driverId.toString());
      }

      setState(() {
        _isLoading = false;
      });

      // Set up the map if tracking data is available
      if (_trackingData != null && mapboxMap != null) {
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

  // Process tracking data from API response
  Future<void> _processTrackingData() async {
    if (_trackingData == null) return;

    try {
      // Extract position data from tracking response
      if (_trackingData!['driverPosition'] != null) {
        final driverPos = _trackingData!['driverPosition'];
        _driverPosition = PositionCustom(
          driverPos['longitude'] ?? 0.0,
          driverPos['latitude'] ?? 0.0,
        );
        _previousDriverPosition = _driverPosition;
      }

      if (_trackingData!['storePosition'] != null) {
        final storePos = _trackingData!['storePosition'];
        _storePosition = PositionCustom(
          storePos['longitude'] ?? 0.0,
          storePos['latitude'] ?? 0.0,
        );
      }

      if (_trackingData!['customerPosition'] != null) {
        final customerPos = _trackingData!['customerPosition'];
        _customerPosition = PositionCustom(
          customerPos['longitude'] ?? 0.0,
          customerPos['latitude'] ?? 0.0,
        );
      }

      // Get driver data from tracking response
      if (_trackingData!['driver'] != null) {
        _driver = Driver.fromJson(_trackingData!['driver']);
      }

      // Calculate estimated delivery time if positions are available
      if (_driverPosition != null && _customerPosition != null) {
        double distance = _calculateDistance(_driverPosition!, _customerPosition!);
        _estimatedMinutes = _calculateEstimatedDeliveryTime(distance);
        _updateEstimatedArrival();
      }

    } catch (e) {
      print('Error processing tracking data: $e');
    }
  }

  // Get additional driver details using DriverService
  Future<void> _getDriverDetails(String driverId) async {
    try {
      final driverData = await DriverService.getDriverById(driverId);
      if (driverData.isNotEmpty) {
        setState(() {
          _driver = Driver.fromJson(driverData);
        });
      }
    } catch (e) {
      print('Error getting driver details: $e');
      // Continue without driver details
    }
  }

  // Get driver location using DriverService
  Future<void> _getDriverLocation(String driverId) async {
    try {
      final locationData = await DriverService.getDriverLocation(driverId);
      if (locationData.isNotEmpty &&
          locationData['latitude'] != null &&
          locationData['longitude'] != null) {

        final newDriverPosition = PositionCustom(
          locationData['longitude'].toDouble(),
          locationData['latitude'].toDouble(),
        );

        // Store previous position for animation
        _previousDriverPosition = _driverPosition;

        setState(() {
          _driverPosition = newDriverPosition;
        });

        // Animate if position changed
        if (_previousDriverPosition != null &&
            (_previousDriverPosition!.longitude != newDriverPosition.longitude ||
                _previousDriverPosition!.latitude != newDriverPosition.latitude)) {
          _animateDriverMarker();
        }
      }
    } catch (e) {
      print('Error getting driver location: $e');
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
      // Refresh tracking data
      final newTrackingData = await TrackingService.getTrackingData(_order!.id.toString());

      if (newTrackingData != null) {
        // Store previous position before updating
        _previousDriverPosition = _driverPosition;

        setState(() {
          _trackingData = newTrackingData;
        });

        // Process new tracking data
        await _processTrackingData();

        // Only animate marker and update route if position changed
        if (_previousDriverPosition != null && _driverPosition != null) {
          if (_previousDriverPosition!.longitude != _driverPosition!.longitude ||
              _previousDriverPosition!.latitude != _driverPosition!.latitude) {
            _animateDriverMarker();
            _fetchRouteDirections();
          }
        }
      }

      // Also refresh driver location if driver is assigned
      if (_order?.driverId != null) {
        await _getDriverLocation(_order!.driverId.toString());
      }

    } catch (e) {
      print('Error refreshing tracking data: $e');
      // Don't update state to avoid disrupting the UI
    }
  }

  // Set up map annotation managers
  Future<void> _setupMapAnnotations() async {
    if (mapboxMap == null || _driverPosition == null) return;

    pointAnnotationManager = await mapboxMap!.annotations.createPointAnnotationManager();
    polylineAnnotationManager = await mapboxMap!.annotations.createPolylineAnnotationManager();

    // Add initial markers
    _addMapMarkers();

    // Center camera on driver position
    _centerMapOnDriver();
  }

  // Add markers for driver, store, and customer
  Future<void> _addMapMarkers() async {
    if (pointAnnotationManager == null) return;

    // Clear existing markers
    await pointAnnotationManager!.deleteAll();

    // Driver marker
    if (_driverPosition != null) {
      final driverOptions = PointAnnotationOptions(
        geometry: Point(coordinates: Position(_driverPosition!.longitude, _driverPosition!.latitude)),
        iconImage: "assets/images/marker_driver.png",
        iconSize: 1.2,
      );
      await pointAnnotationManager!.create(driverOptions);
    }

    // Store marker
    if (_storePosition != null) {
      final storeOptions = PointAnnotationOptions(
        geometry: Point(coordinates: Position(_storePosition!.longitude, _storePosition!.latitude)),
        iconImage: "assets/images/marker_store.png",
        iconSize: 1.0,
      );
      await pointAnnotationManager!.create(storeOptions);
    }

    // Customer marker
    if (_customerPosition != null) {
      final customerOptions = PointAnnotationOptions(
        geometry: Point(coordinates: Position(_customerPosition!.longitude, _customerPosition!.latitude)),
        iconImage: "assets/images/marker_customer.png",
        iconSize: 1.0,
      );
      await pointAnnotationManager!.create(customerOptions);
    }
  }

  // Animate driver marker when position changes
  void _animateDriverMarker() {
    if (_driverPosition == null || _previousDriverPosition == null) return;

    // Reset animation controller
    _markerAnimationController.reset();

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
          (_driverPosition!.longitude - _previousDriverPosition!.longitude) * t;
      final double newLat = _previousDriverPosition!.latitude +
          (_driverPosition!.latitude - _previousDriverPosition!.latitude) * t;

      // Update driver marker position
      _updateDriverMarkerPosition(PositionCustom(newLng, newLat));
    });

    // Start animation
    _markerAnimationController.forward();
  }

  // Update driver marker position without animation
  Future<void> _updateDriverMarkerPosition(PositionCustom position) async {
    if (pointAnnotationManager == null) return;

    // Remove existing annotations
    await pointAnnotationManager!.deleteAll();

    // Re-create all markers with updated driver position
    // Driver marker (with updated position)
    final driverOptions = PointAnnotationOptions(
      geometry: Point(coordinates: Position(position.longitude, position.latitude)),
      iconImage: "assets/images/marker_driver.png",
      iconSize: 1.2,
    );

    // Store marker
    if (_storePosition != null) {
      final storeOptions = PointAnnotationOptions(
        geometry: Point(coordinates: Position(_storePosition!.longitude, _storePosition!.latitude)),
        iconImage: "assets/images/marker_store.png",
        iconSize: 1.0,
      );
      await pointAnnotationManager!.create(storeOptions);
    }

    // Customer marker
    if (_customerPosition != null) {
      final customerOptions = PointAnnotationOptions(
        geometry: Point(coordinates: Position(_customerPosition!.longitude, _customerPosition!.latitude)),
        iconImage: "assets/images/marker_customer.png",
        iconSize: 1.0,
      );
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

    PositionCustom? driverPos = position ?? _driverPosition;
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
    if (_driverPosition == null || mapboxMap == null) return;

    try {
      // Determine origin and destination based on order status
      PositionCustom origin = _driverPosition!;
      PositionCustom? destination;

      // Check order status to determine destination
      if (_order?.orderStatus == OrderStatus.confirmed ||
          _order?.orderStatus == OrderStatus.preparing) {
        destination = _storePosition;
      } else {
        destination = _customerPosition;
      }

      if (destination == null) return;

      // Request directions
      final directionsResponse = await _getDirections(origin, destination);

      // Process response and draw route
      _drawRoute(directionsResponse);

    } catch (e) {
      print('Error fetching directions: $e');
      // Fallback to direct line if directions API fails
      _drawDirectLine();
    }
  }

  // Get directions (simplified implementation)
  Future<List<PositionCustom>> _getDirections(PositionCustom origin, PositionCustom destination) async {
    // Create a simulated route with waypoints
    List<PositionCustom> waypoints = [];

    // Add origin
    waypoints.add(origin);

    // Add intermediate points (simulating a curved route)
    final double distance = _calculateDistance(origin, destination);
    final int numPoints = (distance * 100).round();

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
    if (polylineAnnotationManager == null || _driverPosition == null) return;

    // Clear existing routes
    await polylineAnnotationManager!.deleteAll();

    // Determine route points based on order status
    List<PositionCustom> routePoints = [];
    if (_order?.orderStatus == OrderStatus.confirmed ||
        _order?.orderStatus == OrderStatus.preparing) {
      if (_storePosition != null) {
        routePoints = [_driverPosition!, _storePosition!];
      }
    } else {
      if (_customerPosition != null) {
        routePoints = [_driverPosition!, _customerPosition!];
      }
    }

    if (routePoints.isEmpty) return;

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
    final double lat1 = pos1.latitude * (math.pi / 180.0);
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
    if (_order == null) {
      return Center(child: Text('No order data available'));
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
            cameraOptions: _driverPosition != null ? CameraOptions(
              center: Point(coordinates: Position(
                  _driverPosition!.longitude,
                  _driverPosition!.latitude
              )),
              zoom: 14.5,
              bearing: 0,
              pitch: 45,
            ) : null,
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
                  _getStatusMessage(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_order!.orderStatus != OrderStatus.delivered &&
                    _order!.orderStatus != OrderStatus.cancelled)
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
                      child: CustomerOrderStatusCard(
                        orderData: {
                          'id': _order!.id,
                          'order_status': _order!.orderStatus.toString().split('.').last,
                          'total_amount': _order!.totalAmount,
                          'estimated_delivery_time': _order!.estimatedDeliveryTime?.toIso8601String(),
                        },
                        animation: null,
                      ),
                    ),

                    // Driver Info
                    _buildDriverInfo(),

                    // Delivery Information
                    _buildDeliveryInfo(),

                    // Confirmation Button
                    if (_order!.orderStatus == OrderStatus.delivered)
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

  // Get status message based on order status
  String _getStatusMessage() {
    switch (_order!.orderStatus) {
      case OrderStatus.pending:
        return 'Menunggu konfirmasi pesanan';
      case OrderStatus.confirmed:
        return 'Pesanan telah dikonfirmasi';
      case OrderStatus.preparing:
        return 'Pesanan sedang dipersiapkan';
      case OrderStatus.ready_for_pickup:
        return 'Pesanan siap diambil';
      case OrderStatus.on_delivery:
        return 'Pesanan sedang dalam pengiriman';
      case OrderStatus.delivered:
        return 'Pesanan telah diterima';
      case OrderStatus.cancelled:
        return 'Pesanan dibatalkan';
    }
  }

  // Build driver info section
  Widget _buildDriverInfo() {
    if (_driver == null) {
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
                child: _driver!.profileImageUrl != null && _driver!.profileImageUrl!.isNotEmpty
                    ? ClipOval(
                  child: ImageService.displayImage(
                    imageSource: _driver!.profileImageUrl!,
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
                      _driver!.name,
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
                          _driver!.vehiclePlate,
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
                          _driver!.rating.toString(),
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
                  onPressed: () => _callDriver(_driver!.phoneNumber),
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
                  onPressed: () => _messageDriver(_driver!.phoneNumber),
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
    if (_storePosition != null && _customerPosition != null) {
      distance = _calculateDistance(_storePosition!, _customerPosition!);
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
            _order!.store?.name ?? 'Unknown Store',
            _order!.store?.address ?? 'Address not available',
            Icons.store,
          ),
          const Divider(height: 24),
          _buildLocationItem(
            'Alamat Pengantaran',
            'Alamat Pengiriman',
            'Customer delivery address', // You may need to add this field to Order model
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
          if (_order!.items != null && _order!.items!.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Rincian Pesanan (${_order!.items!.length} item)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: GlobalStyle.fontColor,
              ),
            ),
            const SizedBox(height: 8),
            ..._order!.items!.map((item) => Padding(
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
                    GlobalStyle.formatRupiah(item.totalPrice),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: GlobalStyle.fontColor,
                    ),
                  ),
                ],
              ),
            )).toList(),
          ],
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
                GlobalStyle.formatRupiah(_order!.totalAmount),
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

    if (_driverPosition != null) {
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
      // Update order status using OrderService
      await OrderService.updateOrderStatus(_order!.id.toString(), {
        'order_status': 'delivered'
      });

      // Navigate to history detail
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HistoryDetailScreen(
            orderId: _order!.id.toString(),
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