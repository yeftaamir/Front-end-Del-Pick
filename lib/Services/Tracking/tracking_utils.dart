// lib/services/tracking/tracking_utils.dart
import 'dart:math' as math;

import '../../Models/Entities/order.dart';
import '../../Models/Enums/order_status.dart';
import '../../Services/Utils/location_service.dart';

class TrackingUtils {

  // Convert order status to readable message
  static String getStatusMessage(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Pesanan sedang diproses';
      case OrderStatus.confirmed:
        return 'Pesanan dikonfirmasi, mencari driver';
      case OrderStatus.preparing:
        return 'Driver menuju ke toko';
      case OrderStatus.readyForPickup:
        return 'Driver mengambil pesanan';
      case OrderStatus.onDelivery:
        return 'Driver menuju ke lokasi Anda';
      case OrderStatus.delivered:
        return 'Pesanan telah diterima';
      case OrderStatus.cancelled:
        return 'Pesanan dibatalkan';
    }
  }

  // Calculate delivery time estimate based on distance and traffic
  static Duration calculateDeliveryTime({
    required double distanceKm,
    required OrderStatus orderStatus,
    bool rushHour = false,
  }) {
    // Base speed (km/h) - adjusted for traffic conditions
    double baseSpeed = rushHour ? 20.0 : 30.0;

    // Adjust speed based on order status
    switch (orderStatus) {
      case OrderStatus.preparing:
      // Driver going to store - city traffic
        baseSpeed = rushHour ? 18.0 : 25.0;
        break;
      case OrderStatus.onDelivery:
      // Driver going to customer - faster delivery
        baseSpeed = rushHour ? 22.0 : 32.0;
        break;
      default:
        break;
    }

    // Calculate base time
    double timeInHours = distanceKm / baseSpeed;
    int timeInMinutes = (timeInHours * 60).round();

    // Add buffer time based on distance
    int bufferMinutes = 5;
    if (distanceKm > 5) bufferMinutes = 10;
    if (distanceKm > 10) bufferMinutes = 15;

    // Add preparation time based on order status
    int preparationTime = 0;
    switch (orderStatus) {
      case OrderStatus.preparing:
        preparationTime = 10; // Time to prepare food
        break;
      case OrderStatus.readyForPickup:
        preparationTime = 5; // Time to pick up
        break;
      default:
        break;
    }

    return Duration(minutes: timeInMinutes + bufferMinutes + preparationTime);
  }

  // Check if it's currently rush hour
  static bool isRushHour() {
    final now = DateTime.now();
    final hour = now.hour;

    // Morning rush: 7-9 AM, Evening rush: 5-7 PM
    return (hour >= 7 && hour <= 9) || (hour >= 17 && hour <= 19);
  }

  // Generate realistic route waypoints for better visualization
  static List<TrackingPosition> generateRouteWaypoints({
    required TrackingPosition start,
    required TrackingPosition end,
    int waypointCount = 10,
  }) {
    List<TrackingPosition> waypoints = [];
    waypoints.add(start);

    if (waypointCount > 0) {
      final latDiff = end.latitude - start.latitude;
      final lonDiff = end.longitude - start.longitude;

      for (int i = 1; i < waypointCount; i++) {
        final fraction = i / waypointCount;

        // Add some curve to make route look more realistic
        final curveFactor = math.sin(fraction * math.pi) * 0.001;

        final lat = start.latitude + (latDiff * fraction) + curveFactor;
        final lon = start.longitude + (lonDiff * fraction) + (curveFactor * 0.5);

        waypoints.add(TrackingPosition(
          latitude: lat,
          longitude: lon,
        ));
      }
    }

    waypoints.add(end);
    return waypoints;
  }

  // Calculate bearing between two positions
  static double calculateBearing(TrackingPosition from, TrackingPosition to) {
    final lat1 = from.latitude * (math.pi / 180);
    final lat2 = to.latitude * (math.pi / 180);
    final deltaLon = (to.longitude - from.longitude) * (math.pi / 180);

    final y = math.sin(deltaLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(deltaLon);

    final bearing = math.atan2(y, x) * (180 / math.pi);
    return (bearing + 360) % 360;
  }

  // Calculate distance using Haversine formula
  static double calculateDistance(TrackingPosition pos1, TrackingPosition pos2) {
    return LocationService.calculateDistance(
      pos1.latitude,
      pos1.longitude,
      pos2.latitude,
      pos2.longitude,
    );
  }

  // Format distance for display
  static String formatDistance(double distanceKm) {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).toInt()} m';
    } else if (distanceKm < 10) {
      return '${distanceKm.toStringAsFixed(1)} km';
    } else {
      return '${distanceKm.toStringAsFixed(0)} km';
    }
  }

  // Format duration for display
  static String formatDuration(Duration duration) {
    if (duration.inMinutes < 1) {
      return 'Kurang dari 1 menit';
    } else if (duration.inMinutes < 60) {
      return '${duration.inMinutes} menit';
    } else {
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      return '$hours jam ${minutes} menit';
    }
  }

  // Get estimated time of arrival
  static DateTime getEstimatedArrival(Duration estimatedDuration) {
    return DateTime.now().add(estimatedDuration);
  }

  // Format ETA for display
  static String formatETA(DateTime eta) {
    final now = DateTime.now();
    final difference = eta.difference(now);

    if (difference.isNegative) {
      return 'Sudah tiba';
    }

    return formatDuration(difference);
  }

  // Check if driver is near destination (within 100m)
  static bool isDriverNearDestination({
    required TrackingPosition driverPosition,
    required TrackingPosition destinationPosition,
    double thresholdKm = 0.1, // 100 meters
  }) {
    final distance = calculateDistance(driverPosition, destinationPosition);
    return distance <= thresholdKm;
  }

  // Get next destination based on order status
  static TrackingPosition? getNextDestination({
    required Order order,
    required TrackingPosition storePosition,
    required TrackingPosition customerPosition,
  }) {
    switch (order.orderStatus) {
      case OrderStatus.confirmed:
      case OrderStatus.preparing:
        return storePosition;
      case OrderStatus.readyForPickup:
      case OrderStatus.onDelivery:
        return customerPosition;
      default:
        return null;
    }
  }

  // Calculate delivery fee based on distance
  static double calculateDeliveryFee(double distanceKm) {
    return LocationService.calculateDeliveryFee(distanceKm);
  }

  // Determine if order can be tracked (has driver assigned)
  static bool canTrackOrder(Order order) {
    return order.driverId != null &&
        order.orderStatus != OrderStatus.pending &&
        order.orderStatus != OrderStatus.cancelled &&
        order.orderStatus != OrderStatus.delivered;
  }

  // Get tracking update interval based on order status
  static Duration getUpdateInterval(OrderStatus status) {
    switch (status) {
      case OrderStatus.onDelivery:
        return const Duration(seconds: 5); // More frequent when delivering
      case OrderStatus.preparing:
      case OrderStatus.readyForPickup:
        return const Duration(seconds: 10);
      default:
        return const Duration(seconds: 30);
    }
  }

  // Validate position data
  static bool isValidPosition(TrackingPosition position) {
    return position.latitude >= -90 &&
        position.latitude <= 90 &&
        position.longitude >= -180 &&
        position.longitude <= 180;
  }

  // Smooth position interpolation for animations
  static TrackingPosition interpolatePosition({
    required TrackingPosition start,
    required TrackingPosition end,
    required double progress, // 0.0 to 1.0
  }) {
    final lat = start.latitude + (end.latitude - start.latitude) * progress;
    final lon = start.longitude + (end.longitude - start.longitude) * progress;

    return TrackingPosition(latitude: lat, longitude: lon);
  }

  // Convert degrees to radians
  static double toRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  // Convert radians to degrees
  static double toDegrees(double radians) {
    return radians * (180 / math.pi);
  }

  // Get order progress percentage (0.0 to 1.0)
  static double getOrderProgress(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 0.1;
      case OrderStatus.confirmed:
        return 0.2;
      case OrderStatus.preparing:
        return 0.4;
      case OrderStatus.readyForPickup:
        return 0.6;
      case OrderStatus.onDelivery:
        return 0.8;
      case OrderStatus.delivered:
        return 1.0;
      case OrderStatus.cancelled:
        return 0.0;
    }
  }

  // Get status color
  static int getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 0xFFFF9800; // Orange
      case OrderStatus.confirmed:
        return 0xFF2196F3; // Blue
      case OrderStatus.preparing:
        return 0xFF9C27B0; // Purple
      case OrderStatus.readyForPickup:
        return 0xFF3F51B5; // Indigo
      case OrderStatus.onDelivery:
        return 0xFF4CAF50; // Green
      case OrderStatus.delivered:
        return 0xFF8BC34A; // Light Green
      case OrderStatus.cancelled:
        return 0xFFE53E3E; // Red
    }
  }

  // Check if order status allows real-time tracking
  static bool allowsRealTimeTracking(OrderStatus status) {
    return status == OrderStatus.preparing ||
        status == OrderStatus.readyForPickup ||
        status == OrderStatus.onDelivery;
  }
}

// Simple position class for tracking
class TrackingPosition {
  final double latitude;
  final double longitude;

  TrackingPosition({
    required this.latitude,
    required this.longitude,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is TrackingPosition &&
              runtimeType == other.runtimeType &&
              latitude == other.latitude &&
              longitude == other.longitude;

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode;

  @override
  String toString() => 'TrackingPosition(lat: $latitude, lng: $longitude)';

  // Convert to map
  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  // Create from map
  factory TrackingPosition.fromMap(Map<String, dynamic> map) {
    return TrackingPosition(
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
    );
  }
}