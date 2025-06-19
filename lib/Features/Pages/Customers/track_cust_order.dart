// lib/features/pages/customers/track_cust_order.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../../Common/global_style.dart';
import '../../../Models/Entities/order.dart';
import '../../../Models/Entities/driver.dart';
import '../../../Models/Enums/order_status.dart';
import '../../../Models/Enums/user_role.dart';
import '../../../Services/Tracking/real_time_tracking_service.dart';
import '../../../Services/Tracking/tracking_map_service.dart';
import '../../../Services/Utils/auth_manager.dart';
import '../../../Services/Utils/error_handler.dart';
import '../Shared/order_status_widgets.dart';
import 'widgets/tracking_widgets.dart';

class TrackCustOrderScreen extends StatefulWidget {
  static const String route = "/Customers/TrackOrder";

  final int? orderId;
  final Order? order;

  const TrackCustOrderScreen({
    Key? key,
    this.orderId,
    this.order,
  }) : super(key: key);

  @override
  State<TrackCustOrderScreen> createState() => _TrackCustOrderScreenState();
}

class _TrackCustOrderScreenState extends State<TrackCustOrderScreen>
    with TickerProviderStateMixin {

  // Map configuration
  static const String _mapboxAccessToken = 'pk.eyJ1IjoiY3lydWJhZWsxMjMiLCJhIjoiY2ttbWMxYTRrMHhxdjJ3cXBmaGFxcjhlbyJ9.ODLNIKuSUu5-RdAceSXZfw';
  MapboxMap? _mapboxMap;
  MapAnnotationManagers? _annotationManagers;

  // Draggable scroll controller
  final DraggableScrollableController _dragController = DraggableScrollableController();

  // Data variables
  Order? _order;
  Driver? _driver;
  DriverLocation? _driverLocation;
  DeliveryEstimate? _deliveryEstimate;
  RouteData? _currentRoute;

  // State variables
  bool _isLoading = true;
  bool _isTokenValid = false;
  String _errorMessage = '';

  // Streaming
  StreamSubscription<TrackingUpdate>? _trackingSubscription;

  // Audio player
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Animation controllers
  late AnimationController _routeAnimationController;
  late AnimationController _slideController;

  // Animation
  late Animation<Offset> _slideAnimation;

  // Previous positions for smooth animation
  MapPosition? _previousDriverPosition;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _checkTokenAndInitialize();
  }

  @override
  void dispose() {
    _disposeResources();
    super.dispose();
  }

  // Initialize animations
  void _initializeAnimations() {
    _routeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
  }

  // Dispose resources
  void _disposeResources() {
    _trackingSubscription?.cancel();
    RealTimeTrackingService.stopTracking();
    _routeAnimationController.dispose();
    _slideController.dispose();
    _dragController.dispose();
    _audioPlayer.dispose();
  }

  // Check token validity and initialize
  Future<void> _checkTokenAndInitialize() async {
    try {
      // Check if user is logged in
      if (!AuthManager.isLoggedIn) {
        setState(() {
          _isTokenValid = false;
          _isLoading = false;
          _errorMessage = 'Authentication required. Please login again.';
        });
        return;
      }

      setState(() {
        _isTokenValid = true;
      });

      await _initializeTracking();

    } catch (e) {
      setState(() {
        _isTokenValid = false;
        _isLoading = false;
        _errorMessage = 'Authentication error: ${ErrorHandler.handleError(e)}';
      });
    }
  }

  // Initialize tracking
  Future<void> _initializeTracking() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      // Determine order ID
      final int? orderId = widget.orderId ?? widget.order?.id;
      if (orderId == null) {
        throw Exception('Order ID is required');
      }

      // Set initial order if provided
      if (widget.order != null) {
        _order = widget.order;
      }

      // Start real-time tracking
      _trackingSubscription = RealTimeTrackingService.initializeTracking(orderId)
          .listen(
        _handleTrackingUpdate,
        onError: _handleTrackingError,
      );

      // Subscribe to real-time updates
      await RealTimeTrackingService.subscribeToOrderUpdates(orderId);

      // Start slide animation
      _slideController.forward();

    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = ErrorHandler.handleError(e);
      });
    }
  }

  // Handle tracking update
  void _handleTrackingUpdate(TrackingUpdate update) {
    if (!mounted) return;

    if (update.hasError) {
      setState(() {
        _errorMessage = update.error!;
        _isLoading = false;
      });
      return;
    }

    if (!update.isValid) {
      setState(() {
        _errorMessage = 'Invalid tracking data received';
        _isLoading = false;
      });
      return;
    }

    // Update state
    setState(() {
      _order = update.order;
      _driver = update.driver;
      _driverLocation = update.driverLocation;
      _deliveryEstimate = update.deliveryEstimate;
      _isLoading = false;
      _errorMessage = '';
    });

    // Update map if available
    if (_mapboxMap != null && _annotationManagers != null && _driverLocation != null) {
      _updateMapWithNewData();
    }

    // Play notification sound for status changes
    _playStatusUpdateSound();
  }

  // Handle tracking error
  void _handleTrackingError(dynamic error) {
    if (!mounted) return;

    setState(() {
      _errorMessage = ErrorHandler.handleError(error);
      _isLoading = false;
    });
  }

  // Update map with new tracking data
  Future<void> _updateMapWithNewData() async {
    if (_driverLocation == null || _order?.store == null || _annotationManagers == null) return;

    final driverPos = MapPosition(
      longitude: _driverLocation!.longitude,
      latitude: _driverLocation!.latitude,
      bearing: _calculateBearing(),
    );

    final storePos = MapPosition(
      longitude: _order!.store!.longitude,
      latitude: _order!.store!.latitude,
    );

    // For now, use store position as customer position
    // In real implementation, get customer address coordinates
    final customerPos = MapPosition(
      longitude: _order!.store!.longitude + 0.01,
      latitude: _order!.store!.latitude + 0.01,
    );

    // Update markers with smooth animation if driver moved
    if (_previousDriverPosition != null) {
      await TrackingMapService.updateDriverMarkerSmooth(
        pointManager: _annotationManagers!.pointManager,
        oldPosition: _previousDriverPosition!,
        newPosition: driverPos,
        storePosition: storePos,
        customerPosition: customerPos,
      );
    } else {
      await TrackingMapService.addMarkersToMap(
        pointManager: _annotationManagers!.pointManager,
        driverPosition: driverPos,
        storePosition: storePos,
        customerPosition: customerPos,
      );
    }

    // Update route if needed
    await _updateRoute(driverPos, storePos, customerPos);

    // Store current position as previous
    _previousDriverPosition = driverPos;
  }

  // Update route based on order status
  Future<void> _updateRoute(MapPosition driverPos, MapPosition storePos, MapPosition customerPos) async {
    if (_annotationManagers == null || _order == null) return;

    MapPosition destination;

    // Determine destination based on order status
    switch (_order!.orderStatus) {
      case OrderStatus.confirmed:
      case OrderStatus.preparing:
        destination = storePos;
        break;
      case OrderStatus.readyForPickup:
      case OrderStatus.onDelivery:
        destination = customerPos;
        break;
      default:
        return; // No route needed for other statuses
    }

    // Fetch new route
    final routeData = await TrackingMapService.fetchRoadRoute(
      origin: driverPos,
      destination: destination,
    );

    // Draw route with animation
    await TrackingMapService.drawAnimatedRoute(
      polylineManager: _annotationManagers!.polylineManager,
      routePoints: routeData.points,
      onProgressUpdate: (progress) {
        // Could update UI with route drawing progress
      },
    );

    _currentRoute = routeData;
  }

  // Calculate bearing for driver marker
  double? _calculateBearing() {
    if (_previousDriverPosition == null || _driverLocation == null) return null;

    return TrackingMapService.calculateBearing(
      _previousDriverPosition!,
      MapPosition(
        longitude: _driverLocation!.longitude,
        latitude: _driverLocation!.latitude,
      ),
    );
  }

  // Play status update sound
  void _playStatusUpdateSound() {
    if (_order?.orderStatus == OrderStatus.delivered) {
      _audioPlayer.play(AssetSource('audio/kring.mp3'));
    }
  }

  // Map created callback
  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;

    // Setup annotations
    _annotationManagers = await TrackingMapService.setupMapAnnotations(mapboxMap);

    // Update map if we already have data
    if (_driverLocation != null) {
      _updateMapWithNewData();
    }
  }

  // Handle driver call
  void _handleDriverCall() {
    if (_driver?.user?.phone != null) {
      TrackingWidgets.callDriver(_driver!.user!.phone!);
    } else {
      _showMessage('Nomor telepon driver tidak tersedia');
    }
  }

  // Handle driver message
  void _handleDriverMessage() {
    if (_driver?.user?.phone != null) {
      TrackingWidgets.messageDriver(_driver!.user!.phone!);
    } else {
      _showMessage('Nomor telepon driver tidak tersedia');
    }
  }

  // Handle order completion
  void _handleOrderCompletion() {
    TrackingWidgets.showOrderCompletedDialog(
      context: context,
      onComplete: () {
        // Navigate to order history or home
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
    );
  }

  // Show message
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Retry initialization
  void _retryInitialization() {
    if (_isTokenValid) {
      _initializeTracking();
    } else {
      _checkTokenAndInitialize();
    }
  }

  // Navigate to login
  void _navigateToLogin() {
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/Controls/Login',
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
    );
  }

  // Build main body
  Widget _buildBody() {
    if (_isLoading) {
      return TrackingWidgets.buildLoadingView();
    }

    if (_errorMessage.isNotEmpty) {
      return TrackingWidgets.buildErrorView(
        errorMessage: _errorMessage,
        isTokenValid: _isTokenValid,
        onRetry: _retryInitialization,
        onGoToLogin: _navigateToLogin,
      );
    }

    if (_order == null) {
      return TrackingWidgets.buildErrorView(
        errorMessage: 'Order data not available',
        isTokenValid: _isTokenValid,
        onRetry: _retryInitialization,
        onGoToLogin: _navigateToLogin,
      );
    }

    return _buildTrackingView();
  }

  // Build main tracking view
  Widget _buildTrackingView() {
    return Stack(
      children: [
        // Mapbox View
        SizedBox(
          height: MediaQuery.of(context).size.height,
          child: MapWidget(
            key: const ValueKey("trackingMapWidget"),
            // accessToken: _mapboxAccessToken,
            onMapCreated: _onMapCreated,
            styleUri: MapboxStyles.MAPBOX_STREETS,
            cameraOptions: _driverLocation != null
                ? CameraOptions(
              center: Point(coordinates: Position(
                _driverLocation!.longitude,
                _driverLocation!.latitude,
              )),
              zoom: 14.5,
              bearing: 0,
              pitch: 45,
            )
                : CameraOptions(zoom: 10.0),
          ),
        ),

        // Back Button
        Positioned(
          top: 40,
          left: 16,
          child: SafeArea(
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new,
                  color: GlobalStyle.primaryColor,
                  size: 18,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ),

        // Status Bar at Top
        if (_deliveryEstimate != null)
          Positioned(
            top: 40,
            left: 70,
            right: 16,
            child: SafeArea(
              child: TrackingWidgets.buildStatusBar(
                statusMessage: _deliveryEstimate!.statusMessage,
                estimatedArrival: _deliveryEstimate!.formattedEstimatedTime,
                isCompleted: _order!.orderStatus == OrderStatus.delivered,
              ),
            ),
          ),

        // Expandable Bottom Sheet
        DraggableScrollableSheet(
          initialChildSize: 0.35,
          minChildSize: 0.15,
          maxChildSize: 0.8,
          controller: _dragController,
          builder: (context, scrollController) {
            return SlideTransition(
              position: _slideAnimation,
              child: Container(
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
                      // Drag handle
                      TrackingWidgets.buildDragHandle(),

                      // Order Status Card
                      if (_order != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: OrderStatusWidgets.buildOrderStatusCard(
                            order: _order!,
                            userRole: AuthManager.currentUser?.role ?? UserRole.customer,
                            slideAnimation: null,
                            pulseAnimation: _routeAnimationController,
                            floatAnimation: _routeAnimationController,
                            shimmerAnimation: _routeAnimationController,
                          ),
                        ),

                      // Driver Info
                      if (_driver != null)
                        TrackingWidgets.buildDriverInfoCard(
                          driver: _driver!,
                          onCallPressed: _handleDriverCall,
                          onMessagePressed: _handleDriverMessage,
                        ),

                      // Delivery Information
                      if (_order != null)
                        TrackingWidgets.buildDeliveryInfoCard(
                          order: _order!,
                          estimatedArrival: _deliveryEstimate?.formattedEstimatedTime ?? 'Calculating...',
                          formattedDistance: _currentRoute?.formattedDistance ?? 'Calculating...',
                        ),

                      // Completion Button
                      if (_order!.orderStatus == OrderStatus.delivered)
                        TrackingWidgets.buildCompletionButton(
                          onPressed: _handleOrderCompletion,
                        ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}