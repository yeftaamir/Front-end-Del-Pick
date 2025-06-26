// lib/Services/tracking_service.dart
import 'dart:convert';
import 'dart:math' as math;
import 'core/base_service.dart';
import 'auth_service.dart';

class TrackingService {
  static const String _baseEndpoint = '/orders';

  /// Start delivery for an order (driver only) - FIXED endpoint
  static Future<Map<String, dynamic>> startDelivery(String orderId) async {
    try {
      print('🚀 TrackingService: Starting delivery for order: $orderId');

      // ✅ PERBAIKAN: Validate driver access
      final hasDriverAccess = await AuthService.hasRole('driver');
      if (!hasDriverAccess) {
        throw Exception('Access denied: Driver authentication required');
      }

      final response = await BaseService.apiCall(
        method: 'POST',
        endpoint: '$_baseEndpoint/$orderId/tracking/start',
        requiresAuth: true,
      );

      print('✅ TrackingService: Delivery started successfully');
      return response['data'] ?? {};
    } catch (e) {
      print('❌ TrackingService: Start delivery error: $e');
      throw Exception('Failed to start delivery: $e');
    }
  }

  /// Complete delivery for an order (driver only) - FIXED endpoint
  static Future<Map<String, dynamic>> completeDelivery(String orderId) async {
    try {
      print('🏁 TrackingService: Completing delivery for order: $orderId');

      // Validate driver access
      final hasDriverAccess = await AuthService.hasRole('driver');
      if (!hasDriverAccess) {
        throw Exception('Access denied: Driver authentication required');
      }

      final response = await BaseService.apiCall(
        method: 'POST',
        endpoint: '$_baseEndpoint/$orderId/tracking/complete',
        requiresAuth: true,
      );

      print('✅ TrackingService: Delivery completed successfully');
      return response['data'] ?? {};
    } catch (e) {
      print('❌ TrackingService: Complete delivery error: $e');
      throw Exception('Failed to complete delivery: $e');
    }
  }

  /// Update driver location during delivery (driver only) - FIXED validation
  static Future<Map<String, dynamic>> updateDriverLocation({
    required String orderId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      print('📍 TrackingService: Updating driver location for order: $orderId');

      // Validate driver access
      final hasDriverAccess = await AuthService.hasRole('driver');
      if (!hasDriverAccess) {
        throw Exception('Access denied: Driver authentication required');
      }

      // Validate coordinates
      if (latitude < -90 || latitude > 90) {
        throw Exception('Invalid latitude. Must be between -90 and 90');
      }
      if (longitude < -180 || longitude > 180) {
        throw Exception('Invalid longitude. Must be between -180 and 180');
      }

      final response = await BaseService.apiCall(
        method: 'PUT',
        endpoint: '$_baseEndpoint/$orderId/tracking/location',
        body: {
          'latitude': latitude,
          'longitude': longitude,
        },
        requiresAuth: true,
      );

      print('✅ TrackingService: Driver location updated successfully');
      return response['data'] ?? {};
    } catch (e) {
      print('❌ TrackingService: Update driver location error: $e');
      throw Exception('Failed to update driver location: $e');
    }
  }

  /// Get tracking data for an order - FIXED dengan enhanced authentication
  static Future<Map<String, dynamic>> getTrackingData(String orderId) async {
    try {
      print('🔍 TrackingService: Getting tracking data for order: $orderId');

      // Validate authentication (customer, driver, store, admin can access)
      final isAuth = await AuthService.isAuthenticated();
      if (!isAuth) {
        throw Exception('Authentication required');
      }

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/$orderId/tracking',
        requiresAuth: true,
      );

      if (response['data'] != null) {
        _processTrackingData(response['data']);
        print('✅ TrackingService: Tracking data retrieved successfully');
        return response['data'];
      }

      return {};
    } catch (e) {
      print('❌ TrackingService: Get tracking data error: $e');
      throw Exception('Failed to get tracking data: $e');
    }
  }

  /// Get tracking history for an order - FIXED endpoint
  static Future<Map<String, dynamic>> getTrackingHistory(String orderId) async {
    try {
      print('📚 TrackingService: Getting tracking history for order: $orderId');

      // Validate authentication
      final isAuth = await AuthService.isAuthenticated();
      if (!isAuth) {
        throw Exception('Authentication required');
      }

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/$orderId/tracking/history',
        requiresAuth: true,
      );

      if (response['data'] != null) {
        _processTrackingHistory(response['data']);
        print('✅ TrackingService: Tracking history retrieved successfully');
        return response['data'];
      }

      return {'history': []};
    } catch (e) {
      print('❌ TrackingService: Get tracking history error: $e');
      throw Exception('Failed to get tracking history: $e');
    }
  }

  /// ✅ BARU: Get real-time tracking updates dengan polling
  static Future<Map<String, dynamic>> getRealtimeUpdates(String orderId) async {
    try {
      print('⏱️ TrackingService: Getting realtime updates for order: $orderId');

      final trackingData = await getTrackingData(orderId);

      // Extract key tracking information
      return {
        'order_id': orderId,
        'driver_location': {
          'latitude': trackingData['driver_latitude'],
          'longitude': trackingData['driver_longitude'],
        },
        'order_status': trackingData['order_status'],
        'delivery_status': trackingData['delivery_status'],
        'estimated_arrival': trackingData['estimated_delivery_time'],
        'actual_pickup_time': trackingData['actual_pickup_time'],
        'actual_delivery_time': trackingData['actual_delivery_time'],
        'last_updated': trackingData['updated_at'] ?? DateTime.now().toIso8601String(),
        'tracking_updates': trackingData['tracking_updates'] ?? [],
      };
    } catch (e) {
      print('❌ TrackingService: Get realtime updates error: $e');
      throw Exception('Failed to get realtime updates: $e');
    }
  }

  /// ✅ BARU: Parse dan format tracking updates dari response
  static List<Map<String, dynamic>> parseTrackingUpdates(dynamic trackingUpdates) {
    try {
      if (trackingUpdates == null) return [];

      List<Map<String, dynamic>> updates = [];

      if (trackingUpdates is String) {
        // Parse JSON string
        try {
          final parsed = jsonDecode(trackingUpdates);
          if (parsed is List) {
            updates = List<Map<String, dynamic>>.from(parsed);
          }
        } catch (e) {
          print('⚠️ Failed to parse tracking updates JSON: $e');
          return [];
        }
      } else if (trackingUpdates is List) {
        updates = List<Map<String, dynamic>>.from(trackingUpdates);
      }

      // Sort by timestamp (newest first)
      updates.sort((a, b) {
        final timestampA = DateTime.tryParse(a['timestamp'] ?? '');
        final timestampB = DateTime.tryParse(b['timestamp'] ?? '');
        if (timestampA == null || timestampB == null) return 0;
        return timestampB.compareTo(timestampA);
      });

      return updates;
    } catch (e) {
      print('❌ TrackingService: Error parsing tracking updates: $e');
      return [];
    }
  }

  /// Calculate distance between two points (Haversine formula)
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

      final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
          math.cos(_degreesToRadians(lat1)) * math.cos(_degreesToRadians(lat2)) *
              math.sin(dLon / 2) * math.sin(dLon / 2);

      final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

      return earthRadius * c;
    } catch (e) {
      print('❌ TrackingService: Calculate distance error: $e');
      return 0.0;
    }
  }

  /// Get estimated time of arrival
  static Duration getEstimatedArrival({
    required double distanceKm,
    double averageSpeedKmh = 25.0, // Average delivery speed in city
  }) {
    try {
      if (distanceKm <= 0) return Duration(minutes: 5); // Minimum 5 minutes

      final hours = distanceKm / averageSpeedKmh;
      final minutes = (hours * 60).round();

      // Minimum 5 minutes, maximum 2 hours
      final clampedMinutes = math.max(5, math.min(120, minutes));

      return Duration(minutes: clampedMinutes);
    } catch (e) {
      return Duration(minutes: 30); // Default 30 minutes
    }
  }

  /// Check if order is trackable based on status
  static bool isOrderTrackable(String orderStatus, String deliveryStatus) {
    const trackableOrderStatuses = [
      'confirmed',
      'preparing',
      'ready_for_pickup',
      'on_delivery'
    ];

    const trackableDeliveryStatuses = [
      'picked_up',
      'on_way'
    ];

    return trackableOrderStatuses.contains(orderStatus.toLowerCase()) ||
        trackableDeliveryStatuses.contains(deliveryStatus.toLowerCase());
  }

  /// Get tracking status display text for UI
  static String getTrackingStatusText(String orderStatus, String deliveryStatus) {
    // Prioritize delivery status if order is on delivery
    if (orderStatus.toLowerCase() == 'on_delivery') {
      switch (deliveryStatus.toLowerCase()) {
        case 'picked_up':
          return 'Pesanan Diambil Driver';
        case 'on_way':
          return 'Dalam Perjalanan';
        case 'delivered':
          return 'Telah Diterima';
        default:
          return 'Sedang Diantar';
      }
    }

    // Otherwise use order status
    switch (orderStatus.toLowerCase()) {
      case 'pending':
        return 'Menunggu Konfirmasi';
      case 'confirmed':
        return 'Pesanan Dikonfirmasi';
      case 'preparing':
        return 'Sedang Dipersiapkan';
      case 'ready_for_pickup':
        return 'Siap Diambil';
      case 'delivered':
        return 'Telah Diterima';
      case 'cancelled':
        return 'Dibatalkan';
      case 'rejected':
        return 'Ditolak';
      default:
        return 'Status Tidak Diketahui';
    }
  }

  /// ✅ BARU: Get estimated delivery progress percentage
  static double getDeliveryProgress(String orderStatus, String deliveryStatus) {
    if (orderStatus.toLowerCase() == 'delivered' ||
        deliveryStatus.toLowerCase() == 'delivered') {
      return 1.0; // 100%
    }

    switch (orderStatus.toLowerCase()) {
      case 'pending':
        return 0.1; // 10%
      case 'confirmed':
        return 0.2; // 20%
      case 'preparing':
        return 0.4; // 40%
      case 'ready_for_pickup':
        return 0.6; // 60%
      case 'on_delivery':
        switch (deliveryStatus.toLowerCase()) {
          case 'picked_up':
            return 0.7; // 70%
          case 'on_way':
            return 0.9; // 90%
          default:
            return 0.8; // 80%
        }
      default:
        return 0.0;
    }
  }

  /// ✅ BARU: Check if driver location updates are available
  static bool hasDriverLocationUpdates(Map<String, dynamic> trackingData) {
    try {
      final driverLat = trackingData['driver_latitude'];
      final driverLon = trackingData['driver_longitude'];

      return driverLat != null &&
          driverLon != null &&
          driverLat.toString().isNotEmpty &&
          driverLon.toString().isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// ✅ BARU: Format time remaining for delivery
  static String formatTimeRemaining(DateTime? estimatedTime) {
    if (estimatedTime == null) return 'Waktu tidak diketahui';

    final now = DateTime.now();
    final difference = estimatedTime.difference(now);

    if (difference.isNegative) {
      return 'Sudah melewati estimasi';
    }

    final hours = difference.inHours;
    final minutes = difference.inMinutes % 60;

    if (hours > 0) {
      return '${hours}j ${minutes}m lagi';
    } else {
      return '${minutes}m lagi';
    }
  }

  // PRIVATE HELPER METHODS

  /// Process tracking data response
  static void _processTrackingData(Map<String, dynamic> data) {
    try {
      // Parse tracking updates if they're JSON strings
      if (data['tracking_updates'] != null) {
        data['tracking_updates'] = parseTrackingUpdates(data['tracking_updates']);
      }

      // Ensure numeric values are properly typed
      if (data['driver_latitude'] != null) {
        data['driver_latitude'] = double.tryParse(data['driver_latitude'].toString());
      }
      if (data['driver_longitude'] != null) {
        data['driver_longitude'] = double.tryParse(data['driver_longitude'].toString());
      }

      // Parse datetime strings
      final dateFields = [
        'estimated_pickup_time',
        'actual_pickup_time',
        'estimated_delivery_time',
        'actual_delivery_time'
      ];

      for (final field in dateFields) {
        if (data[field] != null && data[field] is String) {
          try {
            data[field] = DateTime.parse(data[field]);
          } catch (e) {
            print('⚠️ Failed to parse datetime field $field: $e');
          }
        }
      }
    } catch (e) {
      print('❌ TrackingService: Error processing tracking data: $e');
    }
  }

  /// Process tracking history response
  static void _processTrackingHistory(Map<String, dynamic> data) {
    try {
      if (data['history'] != null && data['history'] is List) {
        final history = data['history'] as List;

        // Sort history by timestamp
        history.sort((a, b) {
          final timestampA = DateTime.tryParse(a['timestamp'] ?? '');
          final timestampB = DateTime.tryParse(b['timestamp'] ?? '');
          if (timestampA == null || timestampB == null) return 0;
          return timestampB.compareTo(timestampA);
        });

        data['history'] = history;
      }
    } catch (e) {
      print('❌ TrackingService: Error processing tracking history: $e');
    }
  }

  /// Convert degrees to radians
  static double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }
}