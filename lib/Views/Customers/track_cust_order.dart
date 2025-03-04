import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Views/Customers/history_detail.dart';
import 'package:del_pick/Models/tracking.dart';
import 'dart:async';
import '../../Models/driver.dart';

class TrackCustOrderScreen extends StatefulWidget {
  static const String route = "/Customers/TrackOrder";

  final String? orderId;

  const TrackCustOrderScreen({Key? key, this.orderId}) : super(key: key);

  @override
  State<TrackCustOrderScreen> createState() => _TrackCustOrderScreenState();
}

class _TrackCustOrderScreenState extends State<TrackCustOrderScreen> {
  MapboxMap? mapboxMap;
  PointAnnotationManager? pointAnnotationManager;
  PolylineAnnotationManager? polylineAnnotationManager;

  // Tracking model instance
  late Tracking _tracking;

  // Timer for simulating location updates
  Timer? _locationUpdateTimer;

  @override
  void initState() {
    super.initState();

    // Initialize tracking data
    // In a real app, you would fetch this from an API using the orderId
    _tracking = Tracking.sample();

    // Simulate location updates every 3 seconds
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 3), _simulateLocationUpdate);
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
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

      // Update map markers and route
      _updateMapAnnotations();

      // Check if driver has arrived (within 0.0005 degrees, roughly 50m)
      if ((newLng - targetLng).abs() < 0.0005 && (newLat - targetLat).abs() < 0.0005) {
        if (_tracking.status == OrderStatus.driverHeadingToCustomer) {
          setState(() {
            _tracking = _tracking.copyWith(status: OrderStatus.driverArrived);
          });
        } else if (_tracking.status == OrderStatus.driverHeadingToStore) {
          setState(() {
            _tracking = _tracking.copyWith(status: OrderStatus.driverAtStore);
          });

          // After a delay, simulate driver leaving store to customer
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted) {
              setState(() {
                _tracking = _tracking.copyWith(status: OrderStatus.driverHeadingToCustomer);
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

          // Bottom Sheet
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Driver Info
                  Padding(
                    padding: const EdgeInsets.all(16),
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

                  // Complete Order Button
                  Padding(
                    padding: const EdgeInsets.all(16),
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
                          setState(() {
                            _tracking = _tracking.copyWith(status: OrderStatus.completed);
                          });

                          // Navigate to history detail page
                          Navigator.pushNamed(
                            context,
                            HistoryDetailPage.route,
                            arguments: {'orderId': _tracking.orderId},
                          );
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
                ],
              ),
            ),
          ),
        ],
      ),
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
    } else {
      // Route from driver to customer through store if needed
      if (_tracking.status == OrderStatus.driverHeadingToCustomer) {
        routeCoordinates = [
          _tracking.driverPosition,
          _tracking.customerPosition,
        ];
      } else {
        routeCoordinates = [
          _tracking.driverPosition,
          _tracking.customerPosition,
        ];
      }
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