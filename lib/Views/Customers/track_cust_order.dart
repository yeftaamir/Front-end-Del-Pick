import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Views/Customers/history_detail.dart';

class TrackCustOrderScreen extends StatefulWidget {
  static const String route = "/Customers/TrackOrder";

  const TrackCustOrderScreen({Key? key}) : super(key: key);

  @override
  State<TrackCustOrderScreen> createState() => _TrackCustOrderScreenState();
}

class _TrackCustOrderScreenState extends State<TrackCustOrderScreen> {
  MapboxMap? mapboxMap;
  PointAnnotationManager? pointAnnotationManager;
  PolylineAnnotationManager? polylineAnnotationManager;

  // Define coordinates for Institut Teknologi Del
  final delPosition = Position(99.10279, 2.34379);

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
              child: const Text(
                'Tunggu ya, Driver akan menuju ke tempatmu',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
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
                          child: const Icon(Icons.person),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'M. Hermawan',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'BK 1234 ABC',
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
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.person_outline),
                          onPressed: () {
                            // Add profile view functionality
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
                          backgroundColor: GlobalStyle.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            HistoryDetailPage.route,
                          );
                        },
                        child: const Text(
                          'Pesanan Selesai',
                          style: TextStyle(
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
    _setupAnnotationManagers();
    _addMarkers();
    _drawRoute();
  }

  Future<void> _setupAnnotationManagers() async {
    pointAnnotationManager = await mapboxMap?.annotations.createPointAnnotationManager();
    polylineAnnotationManager = await mapboxMap?.annotations.createPolylineAnnotationManager();
  }

  Future<void> _addMarkers() async {
    // Customer marker
    final customerOptions = PointAnnotationOptions(
      geometry: Point(coordinates: Position(99.10179, 2.34279)),
      iconImage: "assets/images/marker_red.png",
    );

    // Store marker
    final storeOptions = PointAnnotationOptions(
      geometry: Point(coordinates: Position(99.10379, 2.34479)),
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
    final routeCoordinates = [
      Position(99.10179, 2.34279), // Customer
      Position(99.10379, 2.34479), // Store
      Position(99.10279, 2.34379), // Driver
    ];

    final polylineOptions = PolylineAnnotationOptions(
      geometry: LineString(coordinates: routeCoordinates),
      lineColor: Colors.blue.value,
      lineWidth: 3.0,
    );

    await polylineAnnotationManager?.create(polylineOptions);
  }
}