import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:del_pick/Common/global_style.dart';

class TrackOrderScreen extends StatefulWidget {
  const TrackOrderScreen({Key? key}) : super(key: key);

  @override
  State<TrackOrderScreen> createState() => _TrackOrderScreenState();
}

class _TrackOrderScreenState extends State<TrackOrderScreen> {
  MapboxMap? mapboxMap;
  PointAnnotationManager? pointAnnotationManager;
  PolylineAnnotationManager? polylineAnnotationManager;

  // Define coordinates
  final delPosition = Position(99.10279, 2.34379);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Mapbox View
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: MapWidget(
              key: const ValueKey("mapWidget"),
              onMapCreated: _onMapCreated,
              styleUri: MapboxStyles.MAPBOX_STREETS,
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
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // Order Details Card
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Pemesan',
                    style: TextStyle(
                      color: GlobalStyle.fontColor,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Rifqi Haikal',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tujuan',
                    style: TextStyle(
                      color: GlobalStyle.fontColor,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Institut Teknologi Del',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Total Pembayaran',
                    style: TextStyle(
                      color: GlobalStyle.fontColor,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Rp. 222.000',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16C47F),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {},
                      child: const Text(
                        'Selesai Antar',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
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
    // Create marker images using asset paths
    final customerOptions = PointAnnotationOptions(
        geometry: Point(coordinates: Position(99.10179, 2.34279)),
        iconImage: "assets/images/marker_red.png"  // Add these images to your assets
    );

    final storeOptions = PointAnnotationOptions(
        geometry: Point(coordinates: Position(99.10379, 2.34479)),
        iconImage: "assets/images/marker_blue.png"
    );

    final driverOptions = PointAnnotationOptions(
        geometry: Point(coordinates: delPosition),
        iconImage: "assets/images/marker_green.png"
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