import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geotypes/src/geojson.dart';
import 'driver.dart';
import 'order.dart';
import 'order_enum.dart';

class Tracking {
  final String orderId;
  final Driver driver;
  final Position driverPosition;
  final Position customerPosition;
  final Position storePosition;
  final List<Position> routeCoordinates;
  final OrderStatus status;
  final DeliveryStatus? deliveryStatus; // Added to match backend
  final DateTime estimatedArrival;
  final String? customStatusMessage;

  // Add these getters to access driver properties directly from Tracking
  String get driverImageUrl => driver.avatar ?? '';
  String get driverName => driver.name;
  String get vehicleNumber => driver.vehicleNumber;

  Tracking({
    required this.orderId,
    required this.driver,
    required this.driverPosition,
    required this.customerPosition,
    required this.storePosition,
    required this.routeCoordinates,
    required this.status,
    this.deliveryStatus,
    required this.estimatedArrival,
    this.customStatusMessage,
  });

  // Corrected copyWith method for Tracking class
  Tracking copyWith({
    String? orderId,
    Driver? driver,
    Position? driverPosition,
    Position? customerPosition,
    Position? storePosition,
    List<Position>? routeCoordinates,
    OrderStatus? status,
    DeliveryStatus? deliveryStatus,
    DateTime? estimatedArrival,
    String? customStatusMessage,
    String? statusMessage,
  }) {
    return Tracking(
      orderId: orderId ?? this.orderId,
      driver: driver ?? this.driver,
      driverPosition: driverPosition ?? this.driverPosition,
      customerPosition: customerPosition ?? this.customerPosition,
      storePosition: storePosition ?? this.storePosition,
      routeCoordinates: routeCoordinates ?? this.routeCoordinates,
      status: status ?? this.status,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      estimatedArrival: estimatedArrival ?? this.estimatedArrival,
      customStatusMessage: customStatusMessage ?? this.customStatusMessage,
    );
  }

  // Convert from JSON
  factory Tracking.fromJson(Map<String, dynamic> json) {
    // Parse order status
    OrderStatus orderStatus;
    if (json['order_status'] != null) {
      orderStatus = OrderStatus.fromString(json['order_status']);
    } else if (json['status'] != null) {
      orderStatus = OrderStatus.fromString(json['status']);
    } else {
      orderStatus = OrderStatus.pending;
    }

    // Parse delivery status if available
    DeliveryStatus? deliveryStatus;
    if (json['delivery_status'] != null) {
      deliveryStatus = DeliveryStatus.fromString(json['delivery_status']);
    }

    return Tracking(
      orderId: json['orderId'] as String? ?? '',
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
      status: orderStatus,
      deliveryStatus: deliveryStatus,
      estimatedArrival: json['estimatedArrival'] != null
          ? DateTime.parse(json['estimatedArrival'] as String)
          : DateTime.now().add(const Duration(minutes: 15)),
      customStatusMessage: json['customStatusMessage'] as String?,
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'orderId': orderId,
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
      'status': status.toString().split('.').last,
      if (deliveryStatus != null) 'delivery_status': deliveryStatus!.toString().split('.').last,
      'estimatedArrival': estimatedArrival.toIso8601String(),
      if (customStatusMessage != null) 'customStatusMessage': customStatusMessage,
    };
  }

  // Get the status message based on current order status
  String get statusMessage {
    // Return custom status message if it exists
    if (customStatusMessage != null) {
      return customStatusMessage!;
    }

    // Otherwise return the default message based on status
    switch (status) {
      case OrderStatus.pending:
        return 'Menunggu konfirmasi pesanan';
      case OrderStatus.approved:
        return 'Pesanan telah dikonfirmasi';
      case OrderStatus.preparing:
        return 'Pesanan sedang dipersiapkan';
      case OrderStatus.on_delivery:
        return 'Pesanan sedang dalam pengiriman';
      case OrderStatus.delivered:
        return 'Pesanan telah diterima';
      case OrderStatus.driverAssigned:
        return 'Driver telah ditugaskan';
      case OrderStatus.driverHeadingToStore:
        return 'Driver sedang menuju ke toko';
      case OrderStatus.driverAtStore:
        return 'Driver telah sampai di toko';
      case OrderStatus.driverHeadingToCustomer:
        return 'Tunggu ya, Driver akan menuju ke tempatmu';
      case OrderStatus.driverArrived:
        return 'Driver telah tiba di lokasimu';
      case OrderStatus.completed:
        return 'Pesanan telah selesai';
      case OrderStatus.cancelled:
        return 'Pesanan dibatalkan';
    }
  }

  // Format estimated arrival time as a string
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
}