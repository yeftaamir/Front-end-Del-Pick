// lib/services/utils/location_service.dart
import 'dart:math' as math;

class LocationService {
  // Calculate distance between two points (Haversine formula)
  static double calculateDistance(
      double lat1,
      double lon1,
      double lat2,
      double lon2,
      ) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  // Calculate delivery fee based on distance
  static double calculateDeliveryFee(double distance) {
    const double baseFee = 5000; // Base fee in IDR
    const double perKmFee = 2000; // Per km fee in IDR

    return baseFee + (distance * perKmFee);
  }

  // Estimate delivery time based on distance
  static Duration estimateDeliveryTime(double distance) {
    const double averageSpeed = 30; // km/h
    final double timeInHours = distance / averageSpeed;
    final int timeInMinutes = (timeInHours * 60).round();

    // Add buffer time
    final int bufferMinutes = math.max(10, (timeInMinutes * 0.2).round());

    return Duration(minutes: timeInMinutes + bufferMinutes);
  }
}