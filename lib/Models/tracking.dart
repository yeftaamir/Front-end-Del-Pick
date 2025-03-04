import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'driver.dart';

class Tracking {
  final String orderId;
  final Driver driver;
  final Position driverPosition;
  final Position customerPosition;
  final Position storePosition;
  final List<Position> routeCoordinates;
  final OrderStatus status;
  final DateTime estimatedArrival;

  // Add these getters to access driver properties directly from Tracking
  String get driverImageUrl => driver.profileImageUrl ?? '';
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
    required this.estimatedArrival,
  });

  factory Tracking.sample() {
    return Tracking(
      orderId: 'ORD-12345',
      driver: Driver.sample(),
      driverPosition: Position(99.10279, 2.34379),
      customerPosition: Position(99.10179, 2.34279),
      storePosition: Position(99.10379, 2.34479),
      routeCoordinates: [
        Position(99.10279, 2.34379), // Driver
        Position(99.10379, 2.34479), // Store
        Position(99.10179, 2.34279), // Customer
      ],
      status: OrderStatus.driverHeadingToCustomer,
      estimatedArrival: DateTime.now().add(const Duration(minutes: 15)),
    );
  }

  // Create a copy of the current tracking with updated fields
  Tracking copyWith({
    String? orderId,
    Driver? driver,
    Position? driverPosition,
    Position? customerPosition,
    Position? storePosition,
    List<Position>? routeCoordinates,
    OrderStatus? status,
    DateTime? estimatedArrival,
  }) {
    return Tracking(
      orderId: orderId ?? this.orderId,
      driver: driver ?? this.driver,
      driverPosition: driverPosition ?? this.driverPosition,
      customerPosition: customerPosition ?? this.customerPosition,
      storePosition: storePosition ?? this.storePosition,
      routeCoordinates: routeCoordinates ?? this.routeCoordinates,
      status: status ?? this.status,
      estimatedArrival: estimatedArrival ?? this.estimatedArrival,
    );
  }

  // Convert from JSON
  factory Tracking.fromJson(Map<String, dynamic> json) {
    return Tracking(
      orderId: json['orderId'] as String,
      driver: Driver.fromJson(json['driver'] as Map<String, dynamic>),
      driverPosition: Position(
        json['driverPosition']['longitude'] as double,
        json['driverPosition']['latitude'] as double,
      ),
      customerPosition: Position(
        json['customerPosition']['longitude'] as double,
        json['customerPosition']['latitude'] as double,
      ),
      storePosition: Position(
        json['storePosition']['longitude'] as double,
        json['storePosition']['latitude'] as double,
      ),
      routeCoordinates: (json['routeCoordinates'] as List).map((pos) =>
          Position(pos['longitude'] as double, pos['latitude'] as double)
      ).toList(),
      status: OrderStatus.values.firstWhere(
            (e) => e.toString() == 'OrderStatus.${json['status']}',
        orElse: () => OrderStatus.pending,
      ),
      estimatedArrival: DateTime.parse(json['estimatedArrival'] as String),
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
      'estimatedArrival': estimatedArrival.toIso8601String(),
    };
  }

  // Get the status message based on current order status
  String get statusMessage {
    switch (status) {
      case OrderStatus.pending:
        return 'Menunggu konfirmasi pesanan';
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

// Enum for different order statuses
enum OrderStatus {
  pending,
  driverAssigned,
  driverHeadingToStore,
  driverAtStore,
  driverHeadingToCustomer,
  driverArrived,
  completed,
  cancelled,
}