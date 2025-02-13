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
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // Bottom Sheet with Fixed Constraints
          DraggableScrollableSheet(
            initialChildSize: 0.3,  // Must be <= maxChildSize
            minChildSize: 0.06,     // Must be <= initialChildSize
            maxChildSize: 0.38,      // Must be >= initialChildSize
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Drag Handle
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),

                      // Content
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20), // Tambah padding vertikal
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Section Pemesan
                            Padding( // Gunakan Padding untuk margin atas
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                'Pemesan',
                                style: TextStyle(
                                  color: GlobalStyle.fontColor,
                                  fontSize: 14,
                                ),
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
                            const SizedBox(height: 12),

                            // Section Tujuan
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
                            const SizedBox(height: 12),

                            // Section Total Pembayaran
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
                                onPressed: () {
                                  // Show confirmation dialog
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        title: const Text('Konfirmasi'),
                                        content: const Text(
                                            'Apakah Anda yakin telah menyelesaikan pengantaran?'),
                                        actions: <Widget>[
                                          TextButton(
                                            child: const Text('Batal'),
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                            },
                                          ),
                                          TextButton(
                                            child: const Text('Ya'),
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                              Navigator.pop(context, 'completed');
                                            },
                                          ),
                                        ],
                                      );
                                    },
                                  );
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
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
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