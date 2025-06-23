// lib/Services/tracking_service.dart
import 'dart:convert';
import 'dart:math' as math;
import 'core/base_service.dart';

class TrackingService {
  static const String _baseEndpoint = '/orders';

  /// Start delivery for an order (driver only)
  static Future<Map<String, dynamic>> startDelivery(String orderId) async {
    try {
      final response = await BaseService.apiCall(
        method: 'POST',
        endpoint: '$_baseEndpoint/$orderId/tracking/start',
        requiresAuth: true,
      );

      return response['data'] ?? {};
    } catch (e) {
      print('Start delivery error: $e');
      throw Exception('Failed to start delivery: $e');
    }
  }

  /// Complete delivery for an order (driver only)
  static Future<Map<String, dynamic>> completeDelivery(String orderId) async {
    try {
      final response = await BaseService.apiCall(
        method: 'POST',
        endpoint: '$_baseEndpoint/$orderId/tracking/complete',
        requiresAuth: true,
      );

      return response['data'] ?? {};
    } catch (e) {
      print('Complete delivery error: $e');
      throw Exception('Failed to complete delivery: $e');
    }
  }

  /// Update driver location during delivery (driver only)
  static Future<Map<String, dynamic>> updateDriverLocation({
    required String orderId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await BaseService.apiCall(
        method: 'PUT',
        endpoint: '$_baseEndpoint/$orderId/tracking/location',
        body: {
          'latitude': latitude,
          'longitude': longitude,
        },
        requiresAuth: true,
      );

      return response['data'] ?? {};
    } catch (e) {
      print('Update driver location error: $e');
      throw Exception('Failed to update driver location: $e');
    }
  }

  /// Get tracking data for an order (customer, driver, store)
  static Future<Map<String, dynamic>> getTrackingData(String orderId) async {
    try {
      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/$orderId/tracking',
        requiresAuth: true,
      );

      return response['data'] ?? {};
    } catch (e) {
      print('Get tracking data error: $e');
      throw Exception('Failed to get tracking data: $e');
    }
  }

  /// Get tracking history for an order
  static Future<Map<String, dynamic>> getTrackingHistory(String orderId) async {
    try {
      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/$orderId/tracking/history',
        requiresAuth: true,
      );

      return response['data'] ?? {};
    } catch (e) {
      print('Get tracking history error: $e');
      throw Exception('Failed to get tracking history: $e');
    }
  }

  /// Get real-time tracking updates (polling method)
  static Future<Map<String, dynamic>> getRealtimeUpdates(String orderId) async {
    try {
      final trackingData = await getTrackingData(orderId);

      return {
        'order_id': orderId,
        'driver_location': {
          'latitude': trackingData['driver_latitude'],
          'longitude': trackingData['driver_longitude'],
        },
        'order_status': trackingData['order_status'],
        'delivery_status': trackingData['delivery_status'],
        'estimated_arrival': trackingData['estimated_arrival'],
        'last_updated': trackingData['last_updated'],
      };
    } catch (e) {
      print('Get realtime updates error: $e');
      throw Exception('Failed to get realtime updates: $e');
    }
  }

  /// Calculate distance between two points (helper method)
  static double calculateDistance({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    try {
      const double earthRadius = 6371; // Earth radius in kilometers

      final double dLat = _degreesToRadians(lat2 - lat1);
      final double dLon = _degreesToRadians(lon2 - lon1);

      final double a = (dLat / 2) * (dLat / 2) +
          _degreesToRadians(lat1) * _degreesToRadians(lat2) *
              (dLon / 2) * (dLon / 2);

      final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

      return earthRadius * c;
    } catch (e) {
      print('Calculate distance error: $e');
      return 0.0;
    }
  }

  /// Get estimated time of arrival
  static Duration getEstimatedArrival({
    required double distanceKm,
    double averageSpeedKmh = 30.0, // Average delivery speed
  }) {
    try {
      final hours = distanceKm / averageSpeedKmh;
      final minutes = (hours * 60).round();
      return Duration(minutes: minutes);
    } catch (e) {
      return Duration(minutes: 30); // Default 30 minutes
    }
  }

  /// Check if order is trackable
  static bool isOrderTrackable(String orderStatus) {
    const trackableStatuses = [
      'confirmed',
      'preparing',
      'ready_for_pickup',
      'picked_up',
      'on_the_way',
      'delivering'
    ];
    return trackableStatuses.contains(orderStatus.toLowerCase());
  }

  /// Get tracking status display text
  static String getTrackingStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Menunggu Konfirmasi';
      case 'confirmed':
        return 'Pesanan Dikonfirmasi';
      case 'preparing':
        return 'Sedang Dipersiapkan';
      case 'ready_for_pickup':
        return 'Siap Diambil';
      case 'picked_up':
        return 'Telah Diambil Driver';
      case 'on_the_way':
        return 'Dalam Perjalanan';
      case 'delivering':
        return 'Sedang Mengantar';
      case 'delivered':
        return 'Telah Diterima';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return 'Status Tidak Diketahui';
    }
  }

  // PRIVATE HELPER METHODS
  static double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }
}