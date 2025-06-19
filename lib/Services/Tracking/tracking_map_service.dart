// lib/services/tracking/tracking_map_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../Common/global_style.dart';
import '../../Services/Utils/error_handler.dart';

class TrackingMapService {
  static const String _mapboxAccessToken = 'pk.eyJ1IjoiY3lydWJhZWsxMjMiLCJhIjoiY2ttbWMxYTRrMHhxdjJ3cXBmaGFxcjhlbyJ9.ODLNIKuSUu5-RdAceSXZfw';
  static const String _directionsBaseUrl = 'https://api.mapbox.com/directions/v5/mapbox';

  // Setup map annotations
  static Future<MapAnnotationManagers> setupMapAnnotations(MapboxMap mapboxMap) async {
    final pointManager = await mapboxMap.annotations.createPointAnnotationManager();
    final polylineManager = await mapboxMap.annotations.createPolylineAnnotationManager();

    return MapAnnotationManagers(
      pointManager: pointManager,
      polylineManager: polylineManager,
    );
  }

  // Add markers to map
  static Future<void> addMarkersToMap({
    required PointAnnotationManager pointManager,
    required MapPosition driverPosition,
    required MapPosition storePosition,
    required MapPosition customerPosition,
  }) async {
    // Clear existing markers
    await pointManager.deleteAll();

    // Driver marker (animated)
    final driverOptions = PointAnnotationOptions(
      geometry: Point(coordinates: Position(driverPosition.longitude, driverPosition.latitude)),
      iconImage: "driver-icon",
      iconSize: 1.2,
      iconRotate: driverPosition.bearing ?? 0.0,
    );

    // Store marker
    final storeOptions = PointAnnotationOptions(
      geometry: Point(coordinates: Position(storePosition.longitude, storePosition.latitude)),
      iconImage: "store-icon",
      iconSize: 1.0,
    );

    // Customer marker
    final customerOptions = PointAnnotationOptions(
      geometry: Point(coordinates: Position(customerPosition.longitude, customerPosition.latitude)),
      iconImage: "customer-icon",
      iconSize: 1.0,
    );

    // Create markers
    await pointManager.create(driverOptions);
    await pointManager.create(storeOptions);
    await pointManager.create(customerOptions);
  }

  // Fetch real road route using Mapbox Directions API
  static Future<RouteData> fetchRoadRoute({
    required MapPosition origin,
    required MapPosition destination,
    String profile = 'driving', // driving, walking, cycling
  }) async {
    try {
      final url = '$_directionsBaseUrl/$profile/${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}';
      final queryParams = {
        'access_token': _mapboxAccessToken,
        'geometries': 'geojson',
        'overview': 'full',
        'steps': 'true',
        'annotations': 'duration,distance',
      };

      final uri = Uri.parse(url).replace(queryParameters: queryParams);
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final geometry = route['geometry'];
          final coordinates = geometry['coordinates'] as List;

          // Convert coordinates to MapPosition list
          final List<MapPosition> routePoints = coordinates.map((coord) =>
              MapPosition(
                longitude: coord[0].toDouble(),
                latitude: coord[1].toDouble(),
              )
          ).toList();

          final duration = route['duration']?.toDouble() ?? 0.0;
          final distance = route['distance']?.toDouble() ?? 0.0;

          return RouteData(
            points: routePoints,
            duration: Duration(seconds: duration.toInt()),
            distance: distance / 1000, // Convert to kilometers
            isValid: true,
          );
        }
      }

      // Fallback to direct line if API fails
      return _createDirectLineRoute(origin, destination);

    } catch (e) {
      ErrorHandler.logError(e, context: 'TrackingMapService.fetchRoadRoute');
      return _createDirectLineRoute(origin, destination);
    }
  }

  // Create direct line route as fallback
  static RouteData _createDirectLineRoute(MapPosition origin, MapPosition destination) {
    final distance = _calculateDistance(origin, destination);
    final estimatedDuration = Duration(minutes: (distance * 2).round()); // Rough estimate

    return RouteData(
      points: [origin, destination],
      duration: estimatedDuration,
      distance: distance,
      isValid: false, // Mark as not a real road route
    );
  }

  // Draw animated route on map
  static Future<void> drawAnimatedRoute({
    required PolylineAnnotationManager polylineManager,
    required List<MapPosition> routePoints,
    required Function(double) onProgressUpdate,
    Duration animationDuration = const Duration(seconds: 2),
  }) async {
    if (routePoints.length < 2) return;

    // Clear existing routes
    await polylineManager.deleteAll();

    const int totalSteps = 50;
    const stepDuration = Duration(milliseconds: 40);

    for (int step = 0; step <= totalSteps; step++) {
      final progress = step / totalSteps;
      final pointsToShow = _getRoutePointsForProgress(routePoints, progress);

      if (pointsToShow.length >= 2) {
        // Clear previous route
        await polylineManager.deleteAll();

        // Create background route (full route, lighter color)
        if (step == totalSteps) {
          final fullRouteOptions = PolylineAnnotationOptions(
            geometry: LineString(coordinates: routePoints.map((p) =>
                Position(p.longitude, p.latitude)).toList()),
            lineWidth: 8.0,
            lineColor: GlobalStyle.primaryColor.withOpacity(0.3).value,
          );
          await polylineManager.create(fullRouteOptions);
        }

        // Create animated route
        final routeOptions = PolylineAnnotationOptions(
          geometry: LineString(coordinates: pointsToShow.map((p) =>
              Position(p.longitude, p.latitude)).toList()),
          lineWidth: 6.0,
          lineColor: GlobalStyle.primaryColor.value,
        );

        await polylineManager.create(routeOptions);
      }

      onProgressUpdate(progress);

      if (step < totalSteps) {
        await Future.delayed(stepDuration);
      }
    }
  }

  // Get route points for animation progress
  static List<MapPosition> _getRoutePointsForProgress(List<MapPosition> allPoints, double progress) {
    if (progress <= 0) return [];
    if (progress >= 1) return allPoints;

    final int pointsToInclude = (allPoints.length * progress).round();
    return allPoints.take(math.max(2, pointsToInclude)).toList();
  }

  // Update driver marker with smooth animation
  static Future<void> updateDriverMarkerSmooth({
    required PointAnnotationManager pointManager,
    required MapPosition oldPosition,
    required MapPosition newPosition,
    required MapPosition storePosition,
    required MapPosition customerPosition,
    Duration animationDuration = const Duration(milliseconds: 1000),
  }) async {
    const int steps = 30;
    final stepDuration = Duration(milliseconds: animationDuration.inMilliseconds ~/ steps);

    for (int i = 0; i <= steps; i++) {
      final progress = i / steps;

      // Interpolate position
      final interpolatedPosition = MapPosition(
        longitude: oldPosition.longitude +
            (newPosition.longitude - oldPosition.longitude) * progress,
        latitude: oldPosition.latitude +
            (newPosition.latitude - oldPosition.latitude) * progress,
        bearing: _interpolateBearing(oldPosition.bearing, newPosition.bearing, progress),
      );

      // Update markers
      await addMarkersToMap(
        pointManager: pointManager,
        driverPosition: interpolatedPosition,
        storePosition: storePosition,
        customerPosition: customerPosition,
      );

      if (i < steps) {
        await Future.delayed(stepDuration);
      }
    }
  }

  // Calculate bearing between two points
  static double calculateBearing(MapPosition from, MapPosition to) {
    final lat1 = from.latitude * (math.pi / 180);
    final lat2 = to.latitude * (math.pi / 180);
    final deltaLon = (to.longitude - from.longitude) * (math.pi / 180);

    final y = math.sin(deltaLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(deltaLon);

    final bearing = math.atan2(y, x) * (180 / math.pi);
    return (bearing + 360) % 360; // Normalize to 0-360
  }

  // Interpolate bearing for smooth rotation
  static double? _interpolateBearing(double? oldBearing, double? newBearing, double progress) {
    if (oldBearing == null || newBearing == null) return newBearing;

    // Handle bearing wrap around
    double diff = newBearing - oldBearing;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;

    return (oldBearing + diff * progress) % 360;
  }

  // Calculate distance between two positions
  static double _calculateDistance(MapPosition pos1, MapPosition pos2) {
    const double earthRadius = 6371.0; // Earth radius in kilometers

    final lat1Rad = pos1.latitude * (math.pi / 180);
    final lat2Rad = pos2.latitude * (math.pi / 180);
    final deltaLatRad = (pos2.latitude - pos1.latitude) * (math.pi / 180);
    final deltaLonRad = (pos2.longitude - pos1.longitude) * (math.pi / 180);

    final a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
            math.sin(deltaLonRad / 2) * math.sin(deltaLonRad / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  // Fit map bounds to show all markers
  static Future<void> fitMapToBounds({
    required MapboxMap mapboxMap,
    required List<MapPosition> positions,
    EdgeInsets padding = const EdgeInsets.all(50),
  }) async {
    if (positions.isEmpty) return;

    double minLat = positions.first.latitude;
    double maxLat = positions.first.latitude;
    double minLon = positions.first.longitude;
    double maxLon = positions.first.longitude;

    for (final pos in positions) {
      minLat = math.min(minLat, pos.latitude);
      maxLat = math.max(maxLat, pos.latitude);
      minLon = math.min(minLon, pos.longitude);
      maxLon = math.max(maxLon, pos.longitude);
    }

    // Add some padding
    final latPadding = (maxLat - minLat) * 0.1;
    final lonPadding = (maxLon - minLon) * 0.1;

    final bounds = CoordinateBounds(
      southwest: Point(coordinates: Position(minLon - lonPadding, minLat - latPadding)),
      northeast: Point(coordinates: Position(maxLon + lonPadding, maxLat + latPadding)),
      infiniteBounds: false,
    );

    await mapboxMap.setBounds(
      CameraBoundsOptions(bounds: bounds),
    );
  }

  // Center map on position with animation
  static Future<void> centerMapOnPosition({
    required MapboxMap mapboxMap,
    required MapPosition position,
    double zoom = 15.0,
    double bearing = 0.0,
    double pitch = 0.0,
  }) async {
    await mapboxMap.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(position.longitude, position.latitude)),
        zoom: zoom,
        bearing: bearing,
        pitch: pitch,
      ),
      MapAnimationOptions(duration: 1500),
    );
  }
}

// Data classes
class MapAnnotationManagers {
  final PointAnnotationManager pointManager;
  final PolylineAnnotationManager polylineManager;

  MapAnnotationManagers({
    required this.pointManager,
    required this.polylineManager,
  });
}

class MapPosition {
  final double longitude;
  final double latitude;
  final double? bearing;

  MapPosition({
    required this.longitude,
    required this.latitude,
    this.bearing,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is MapPosition &&
              runtimeType == other.runtimeType &&
              longitude == other.longitude &&
              latitude == other.latitude;

  @override
  int get hashCode => longitude.hashCode ^ latitude.hashCode;
}

class RouteData {
  final List<MapPosition> points;
  final Duration duration;
  final double distance; // in kilometers
  final bool isValid; // true if real road route, false if direct line

  RouteData({
    required this.points,
    required this.duration,
    required this.distance,
    required this.isValid,
  });

  String get formattedDistance {
    if (distance < 1) {
      return '${(distance * 1000).toInt()} m';
    } else {
      return '${distance.toStringAsFixed(1)} km';
    }
  }

  String get formattedDuration {
    final minutes = duration.inMinutes;
    if (minutes < 60) {
      return '$minutes min';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      return '$hours h ${remainingMinutes} min';
    }
  }
}