import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'driver.dart';
import 'order.dart';
import 'order_enum.dart';

class Tracking {
  final int orderId;  // ✅ Changed to int to match backend
  final Driver driver;
  final Position driverPosition;
  final Position customerPosition;
  final Position storePosition;
  final List<Position> routeCoordinates;
  final OrderStatus orderStatus;  // ✅ Updated to use backend enum
  final DeliveryStatus deliveryStatus;  // ✅ Updated to use backend enum
  final DateTime estimatedArrival;
  final String? customStatusMessage;
  final List<TrackingUpdate>? trackingUpdates;  // ✅ Added to match backend

  // Convenience getters
  String get driverImageUrl => driver.profileImageUrl ?? '';
  String get driverName => driver.name;
  String get vehicleNumber => driver.vehiclePlate;  // ✅ Updated field name

  Tracking({
    required this.orderId,
    required this.driver,
    required this.driverPosition,
    required this.customerPosition,
    required this.storePosition,
    required this.routeCoordinates,
    required this.orderStatus,
    required this.deliveryStatus,
    required this.estimatedArrival,
    this.customStatusMessage,
    this.trackingUpdates,
  });

  factory Tracking.fromJson(Map<String, dynamic> json) {
    // Parse dari backend Order model dengan tracking_updates
    OrderStatus orderStatus = OrderStatus.pending;
    if (json['order_status'] != null) {
      orderStatus = OrderStatus.fromString(json['order_status']);
    }

    DeliveryStatus deliveryStatus = DeliveryStatus.pending;
    if (json['delivery_status'] != null) {
      deliveryStatus = DeliveryStatus.fromString(json['delivery_status']);
    }

    return Tracking(
      orderId: json['id'] ?? 0,  // ✅ Use order ID from backend
      driver: Driver.fromJson(json['driver'] as Map<String, dynamic>),
      driverPosition: Position(
        json['driverPosition']['longitude'] as double? ?? 0.0,
        json['driverPosition']['latitude'] as double? ?? 0.0,
      ),
      customerPosition: Position(
        json['customerPosition']['longitude'] as double? ?? 0.0,
        json['customerPosition']['latitude'] as double? ?? 0.0,
      ),
      storePosition: Position(
        json['storePosition']['longitude'] as double? ?? 0.0,
        json['storePosition']['latitude'] as double? ?? 0.0,
      ),
      routeCoordinates: (json['routeCoordinates'] as List? ?? []).map((pos) =>
          Position(
              pos['longitude'] as double? ?? 0.0,
              pos['latitude'] as double? ?? 0.0)
      ).toList(),
      orderStatus: orderStatus,  // ✅ Use backend enum
      deliveryStatus: deliveryStatus,  // ✅ Use backend enum
      estimatedArrival: json['estimated_delivery_time'] != null
          ? DateTime.parse(json['estimated_delivery_time'] as String)
          : DateTime.now().add(const Duration(minutes: 15)),
      customStatusMessage: json['customStatusMessage'] as String?,
      trackingUpdates: json['tracking_updates'] != null
          ? (json['tracking_updates'] as List).map((e) => TrackingUpdate.fromJson(e)).toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': orderId,  // ✅ Match backend field
      'driver': driver.toJson(),
      'driverPosition': {
        'longitude': driverPosition.lng,
        'latitude': driverPosition.lat,
      },
      'customerPosition': {
        'longitude': customerPosition.lng,
        'latitude': customerPosition.lat,
      },
      'storePosition': {
        'longitude': storePosition.lng,
        'latitude': storePosition.lat,
      },
      'routeCoordinates': routeCoordinates.map((pos) => {
        'longitude': pos.lng,
        'latitude': pos.lat,
      }).toList(),
      'order_status': orderStatus.toString().split('.').last,  // ✅ Backend format
      'delivery_status': deliveryStatus.toString().split('.').last,  // ✅ Backend format
      'estimated_delivery_time': estimatedArrival.toIso8601String(),  // ✅ Backend field name
      if (customStatusMessage != null) 'customStatusMessage': customStatusMessage,
      if (trackingUpdates != null) 'tracking_updates': trackingUpdates!.map((e) => e.toJson()).toList(),
    };
  }

  // Updated status message to match backend enum
  String get statusMessage {
    if (customStatusMessage != null) {
      return customStatusMessage!;
    }

    switch (orderStatus) {
      case OrderStatus.pending:
        return 'Menunggu konfirmasi pesanan';
      case OrderStatus.confirmed:  // ✅ Updated from 'approved'
        return 'Pesanan telah dikonfirmasi';
      case OrderStatus.preparing:
        return 'Pesanan sedang dipersiapkan';
      case OrderStatus.ready_for_pickup:  // ✅ New status from backend
        return 'Pesanan siap diambil';
      case OrderStatus.on_delivery:
        return 'Pesanan sedang dalam pengiriman';
      case OrderStatus.delivered:
        return 'Pesanan telah diterima';
      case OrderStatus.cancelled:
        return 'Pesanan dibatalkan';
    }
  }

  // Rest of the methods remain the same...
  String get formattedETA {
    final now = DateTime.now();
    final difference = estimatedArrival.difference(now);

    if (difference.inMinutes <= 0) {
      return 'Segera tiba';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} menit';
    } else {
      final hours = difference.inHours;
      final minutes = difference.inMinutes % 60;
      return '$hours jam ${minutes > 0 ? '$minutes menit' : ''}';
    }
  }

  Tracking copyWith({
    int? orderId,
    Driver? driver,
    Position? driverPosition,
    Position? customerPosition,
    Position? storePosition,
    List<Position>? routeCoordinates,
    OrderStatus? orderStatus,
    DeliveryStatus? deliveryStatus,
    DateTime? estimatedArrival,
    String? customStatusMessage,
    List<TrackingUpdate>? trackingUpdates,
  }) {
    return Tracking(
      orderId: orderId ?? this.orderId,
      driver: driver ?? this.driver,
      driverPosition: driverPosition ?? this.driverPosition,
      customerPosition: customerPosition ?? this.customerPosition,
      storePosition: storePosition ?? this.storePosition,
      routeCoordinates: routeCoordinates ?? this.routeCoordinates,
      orderStatus: orderStatus ?? this.orderStatus,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      estimatedArrival: estimatedArrival ?? this.estimatedArrival,
      customStatusMessage: customStatusMessage ?? this.customStatusMessage,
      trackingUpdates: trackingUpdates ?? this.trackingUpdates,
    );
  }
}

// Supporting model for tracking_updates JSON field from backend
class TrackingUpdate {
  final DateTime timestamp;
  final String status;
  final String message;
  final Position? location;

  TrackingUpdate({
    required this.timestamp,
    required this.status,
    required this.message,
    this.location,
  });

  factory TrackingUpdate.fromJson(Map<String, dynamic> json) {
    return TrackingUpdate(
      timestamp: DateTime.parse(json['timestamp']),
      status: json['status'],
      message: json['message'],
      location: json['location'] != null
          ? Position(json['location']['longitude'], json['location']['latitude'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'status': status,
      'message': message,
      if (location != null) 'location': {
        'longitude': location!.lng,
        'latitude': location!.lat,
      },
    };
  }
}