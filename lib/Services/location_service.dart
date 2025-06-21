// lib/services/location_service.dart
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'core/base_service.dart';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class LocationService extends BaseService {

  // Get current device location
  static Future<Position?> getCurrentLocation() async {
    try {
      // Check if location service is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      );

      debugPrint('Current location: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      debugPrint('Get current location error: $e');
      return null;
    }
  }

  // Request location permissions
  static Future<bool> requestLocationPermission() async {
    try {
      PermissionStatus status = await Permission.location.request();
      return status == PermissionStatus.granted;
    } catch (e) {
      debugPrint('Request location permission error: $e');
      return false;
    }
  }

  // Check if location permissions are granted
  static Future<bool> hasLocationPermission() async {
    try {
      PermissionStatus status = await Permission.location.status;
      return status == PermissionStatus.granted;
    } catch (e) {
      debugPrint('Check location permission error: $e');
      return false;
    }
  }

  // Calculate distance between two points (in kilometers)
  static double calculateDistance(
      double lat1, double lon1,
      double lat2, double lon2,
      ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000;
  }

  // Calculate bearing between two points
  static double calculateBearing(
      double lat1, double lon1,
      double lat2, double lon2,
      ) {
    return Geolocator.bearingBetween(lat1, lon1, lat2, lon2);
  }

  // Update driver location (for drivers)
  static Future<Map<String, dynamic>> updateDriverLocation(
      double latitude,
      double longitude,
      ) async {
    try {
      // Validate coordinates
      if (latitude < -90 || latitude > 90) {
        throw ApiException('Invalid latitude: must be between -90 and 90');
      }
      if (longitude < -180 || longitude > 180) {
        throw ApiException('Invalid longitude: must be between -180 and 180');
      }

      final response = await BaseService.put('/drivers/location', {
        'latitude': latitude,
        'longitude': longitude,
      });

      return response['data'] ?? {};
    } catch (e) {
      debugPrint('Update driver location error: $e');
      rethrow;
    }
  }

  // Get driver location by ID
  static Future<Map<String, dynamic>> getDriverLocation(String driverId) async {
    try {
      final response = await BaseService.get('/drivers/$driverId/location');
      return response['data'] ?? {};
    } catch (e) {
      debugPrint('Get driver location error: $e');
      rethrow;
    }
  }

  // Update order delivery location (for tracking)
  static Future<Map<String, dynamic>> updateOrderDeliveryLocation(
      String orderId,
      double latitude,
      double longitude,
      ) async {
    try {
      final response = await BaseService.put('/orders/$orderId/tracking/location', {
        'latitude': latitude,
        'longitude': longitude,
      });

      return response['data'] ?? {};
    } catch (e) {
      debugPrint('Update order delivery location error: $e');
      rethrow;
    }
  }

  // Get nearby places (stores, drivers, etc.) based on location
  static Future<List<Map<String, dynamic>>> getNearbyPlaces({
    required double latitude,
    required double longitude,
    required String type, // 'stores', 'drivers'
    double radius = 5.0,
    int limit = 20,
  }) async {
    try {
      final queryParams = {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'radius': radius.toString(),
        'limit': limit.toString(),
      };

      final response = await BaseService.get('/$type/nearby', queryParams: queryParams);

      if (response['data'] != null && response['data'] is List) {
        return List<Map<String, dynamic>>.from(response['data']);
      }

      return [];
    } catch (e) {
      debugPrint('Get nearby places error: $e');
      rethrow;
    }
  }

  // Start location tracking (for real-time updates)
  static Stream<Position>? startLocationTracking({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int intervalMs = 5000,
    int distanceFilter = 10,
  }) {
    try {
      return Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          distanceFilter: distanceFilter,
        ),
      );
    } catch (e) {
      debugPrint('Start location tracking error: $e');
      return null;
    }
  }

  // Geocoding: Get address from coordinates
  static Future<String?> getAddressFromCoordinates(
      double latitude,
      double longitude,
      ) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        return '${place.street}, ${place.subLocality}, ${place.locality}, ${place.administrativeArea}';
      }

      return null;
    } catch (e) {
      debugPrint('Get address from coordinates error: $e');
      return null;
    }
  }

  // Check if location is within delivery radius
  static bool isWithinDeliveryRadius(
      double userLat, double userLon,
      double storeLat, double storeLon,
      double maxRadius,
      ) {
    double distance = calculateDistance(userLat, userLon, storeLat, storeLon);
    return distance <= maxRadius;
  }

  // Get optimal route between multiple points
  static Future<Map<String, dynamic>> getOptimalRoute(List<Map<String, double>> waypoints) async {
    try {
      // This would typically integrate with a routing service like Google Maps API
      // For now, we'll return a basic implementation

      double totalDistance = 0;
      List<Map<String, dynamic>> route = [];

      for (int i = 0; i < waypoints.length - 1; i++) {
        double distance = calculateDistance(
          waypoints[i]['latitude']!,
          waypoints[i]['longitude']!,
          waypoints[i + 1]['latitude']!,
          waypoints[i + 1]['longitude']!,
        );

        totalDistance += distance;
        route.add({
          'from': waypoints[i],
          'to': waypoints[i + 1],
          'distance': distance,
        });
      }

      return {
        'route': route,
        'total_distance': totalDistance,
        'estimated_duration': totalDistance * 2, // Rough estimate: 2 minutes per km
      };
    } catch (e) {
      debugPrint('Get optimal route error: $e');
      rethrow;
    }
  }
}

// Add missing import for geocoding