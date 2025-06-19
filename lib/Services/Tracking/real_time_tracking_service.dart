// lib/services/tracking/real_time_tracking_service.dart
import 'dart:async';
import 'dart:math' as math;

import '../../Models/Base/api_response.dart';
import '../../Models/Entities/order.dart';
import '../../Models/Entities/driver.dart';
import '../../Models/Enums/order_status.dart';
import '../../Models/Exceptions/api_exception.dart';
import '../../Services/Order/order_service.dart';
import '../../Services/Tracking/tracking_service.dart';
import '../../Services/Driver/driver_service.dart';
import '../../Services/Utils/location_service.dart';
import '../../Services/Utils/error_handler.dart';

class RealTimeTrackingService {
  static Timer? _trackingTimer;
  static StreamController<TrackingUpdate>? _trackingStreamController;

  // Initialize real-time tracking
  static Stream<TrackingUpdate> initializeTracking(int orderId) {
    _trackingStreamController = StreamController<TrackingUpdate>.broadcast();

    // Start periodic updates every 10 seconds
    _trackingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _fetchTrackingUpdate(orderId);
    });

    // Fetch initial data
    _fetchTrackingUpdate(orderId);

    return _trackingStreamController!.stream;
  }

  // Stop real-time tracking
  static void stopTracking() {
    _trackingTimer?.cancel();
    _trackingStreamController?.close();
    _trackingTimer = null;
    _trackingStreamController = null;
  }

  // Fetch tracking update
  static Future<void> _fetchTrackingUpdate(int orderId) async {
    try {
      // Get order details
      final orderResponse = await OrderService.getOrderById(orderId);
      if (!orderResponse.isSuccess || orderResponse.data == null) {
        throw ApiException(message: 'Failed to get order details');
      }

      final order = orderResponse.data!;

      // Get tracking data
      final trackingResponse = await TrackingService.getTrackingData(orderId);
      Map<String, dynamic>? trackingData;
      if (trackingResponse.isSuccess && trackingResponse.data != null) {
        trackingData = trackingResponse.data;
      }

      // Get driver location if available
      Driver? driver;
      DriverLocation? driverLocation;
      if (order.driverId != null) {
        try {
          final driverResponse = await DriverService.getDriverById(order.driverId!);
          if (driverResponse.isSuccess && driverResponse.data != null) {
            driver = driverResponse.data;

            // Get driver location
            final locationResponse = await DriverService.getDriverLocation(order.driverId!);
            if (locationResponse.isSuccess && locationResponse.data != null) {
              final locationData = locationResponse.data!;
              driverLocation = DriverLocation(
                latitude: locationData['latitude']?.toDouble() ?? 0.0,
                longitude: locationData['longitude']?.toDouble() ?? 0.0,
                lastUpdated: DateTime.now(),
              );
            }
          }
        } catch (e) {
          print('Error fetching driver data: $e');
        }
      }

      // Calculate delivery estimates
      DeliveryEstimate? estimate;
      if (driverLocation != null && order.store != null) {
        estimate = _calculateDeliveryEstimate(
          driverLocation,
          order.store!,
          order,
        );
      }

      // Create tracking update
      final update = TrackingUpdate(
        order: order,
        driver: driver,
        driverLocation: driverLocation,
        trackingData: trackingData,
        deliveryEstimate: estimate,
        timestamp: DateTime.now(),
      );

      // Send update to stream
      _trackingStreamController?.add(update);

    } catch (e) {
      // Send error to stream
      final errorUpdate = TrackingUpdate(
        order: null,
        driver: null,
        driverLocation: null,
        trackingData: null,
        deliveryEstimate: null,
        timestamp: DateTime.now(),
        error: ErrorHandler.handleError(e),
      );

      _trackingStreamController?.add(errorUpdate);
    }
  }

  // Calculate delivery estimate
  static DeliveryEstimate _calculateDeliveryEstimate(
      DriverLocation driverLocation,
      dynamic store,
      Order order,
      ) {
    double storeLatitude = 0.0;
    double storeLongitude = 0.0;
    double customerLatitude = 0.0;
    double customerLongitude = 0.0;

    // Extract store coordinates
    if (store is Map<String, dynamic>) {
      storeLatitude = store['latitude']?.toDouble() ?? 0.0;
      storeLongitude = store['longitude']?.toDouble() ?? 0.0;
    } else {
      storeLatitude = store.latitude;
      storeLongitude = store.longitude;
    }

    // For now, use store coordinates as customer location
    // In real implementation, you'd get customer address coordinates
    customerLatitude = storeLatitude + 0.01; // Simulated customer location
    customerLongitude = storeLongitude + 0.01;

    // Calculate distances
    final distanceToStore = LocationService.calculateDistance(
      driverLocation.latitude,
      driverLocation.longitude,
      storeLatitude,
      storeLongitude,
    );

    final distanceToCustomer = LocationService.calculateDistance(
      driverLocation.latitude,
      driverLocation.longitude,
      customerLatitude,
      customerLongitude,
    );

    // Estimate delivery time based on order status
    Duration estimatedTime;
    String statusMessage;

    switch (order.orderStatus) {
      case OrderStatus.confirmed:
      case OrderStatus.preparing:
      // Driver going to store
        estimatedTime = LocationService.estimateDeliveryTime(distanceToStore);
        statusMessage = 'Driver menuju ke toko';
        break;
      case OrderStatus.readyForPickup:
      case OrderStatus.onDelivery:
      // Driver going to customer
        estimatedTime = LocationService.estimateDeliveryTime(distanceToCustomer);
        statusMessage = 'Driver menuju ke lokasi Anda';
        break;
      case OrderStatus.delivered:
        estimatedTime = Duration.zero;
        statusMessage = 'Pesanan telah diterima';
        break;
      default:
        estimatedTime = Duration(minutes: 30);
        statusMessage = 'Memproses pesanan';
    }

    return DeliveryEstimate(
      estimatedTime: estimatedTime,
      distanceToStore: distanceToStore,
      distanceToCustomer: distanceToCustomer,
      statusMessage: statusMessage,
      lastUpdated: DateTime.now(),
    );
  }

  // Subscribe to order updates (WebSocket simulation)
  static Future<void> subscribeToOrderUpdates(int orderId) async {
    try {
      final response = await TrackingService.subscribeToOrderUpdates(orderId);
      if (response.isSuccess) {
        print('Subscribed to real-time updates for order $orderId');
      }
    } catch (e) {
      print('Failed to subscribe to order updates: $e');
    }
  }
}

// Data classes
class TrackingUpdate {
  final Order? order;
  final Driver? driver;
  final DriverLocation? driverLocation;
  final Map<String, dynamic>? trackingData;
  final DeliveryEstimate? deliveryEstimate;
  final DateTime timestamp;
  final String? error;

  TrackingUpdate({
    required this.order,
    required this.driver,
    required this.driverLocation,
    required this.trackingData,
    required this.deliveryEstimate,
    required this.timestamp,
    this.error,
  });

  bool get hasError => error != null;
  bool get isValid => !hasError && order != null;
}

class DriverLocation {
  final double latitude;
  final double longitude;
  final DateTime lastUpdated;

  DriverLocation({
    required this.latitude,
    required this.longitude,
    required this.lastUpdated,
  });

  // Convert to map for easier usage
  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }
}

class DeliveryEstimate {
  final Duration estimatedTime;
  final double distanceToStore;
  final double distanceToCustomer;
  final String statusMessage;
  final DateTime lastUpdated;

  DeliveryEstimate({
    required this.estimatedTime,
    required this.distanceToStore,
    required this.distanceToCustomer,
    required this.statusMessage,
    required this.lastUpdated,
  });

  String get formattedEstimatedTime {
    if (estimatedTime == Duration.zero) {
      return 'Sudah tiba';
    }

    final minutes = estimatedTime.inMinutes;
    if (minutes < 60) {
      return '$minutes menit';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      return '$hours jam $remainingMinutes menit';
    }
  }

  String get formattedDistanceToStore {
    if (distanceToStore < 1) {
      return '${(distanceToStore * 1000).toInt()} m';
    } else {
      return '${distanceToStore.toStringAsFixed(1)} km';
    }
  }

  String get formattedDistanceToCustomer {
    if (distanceToCustomer < 1) {
      return '${(distanceToCustomer * 1000).toInt()} m';
    } else {
      return '${distanceToCustomer.toStringAsFixed(1)} km';
    }
  }
}