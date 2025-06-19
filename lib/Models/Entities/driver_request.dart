// lib/models/entities/driver_request.dart
import '../Enums/driver_request_status.dart';
import 'driver.dart';
import 'order.dart';

class DriverRequest {
  final int id;
  final int orderId;
  final int driverId;
  final DriverRequestStatus status;
  final DateTime? estimatedPickupTime;
  final DateTime? estimatedDeliveryTime;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Relations
  final Order? order;
  final Driver? driver;

  DriverRequest({
    required this.id,
    required this.orderId,
    required this.driverId,
    required this.status,
    this.estimatedPickupTime,
    this.estimatedDeliveryTime,
    required this.createdAt,
    required this.updatedAt,
    this.order,
    this.driver,
  });

  factory DriverRequest.fromJson(Map<String, dynamic> json) {
    return DriverRequest(
      id: json['id'] as int,
      orderId: json['order_id'] as int,
      driverId: json['driver_id'] as int,
      status: DriverRequestStatus.fromString(json['status'] as String),
      estimatedPickupTime: json['estimated_pickup_time'] != null
          ? DateTime.parse(json['estimated_pickup_time'] as String)
          : null,
      estimatedDeliveryTime: json['estimated_delivery_time'] != null
          ? DateTime.parse(json['estimated_delivery_time'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      order: json['order'] != null ? Order.fromJson(json['order']) : null,
      driver: json['driver'] != null ? Driver.fromJson(json['driver']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'driver_id': driverId,
      'status': status.value,
      'estimated_pickup_time': estimatedPickupTime?.toIso8601String(),
      'estimated_delivery_time': estimatedDeliveryTime?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (order != null) 'order': order!.toJson(),
      if (driver != null) 'driver': driver!.toJson(),
    };
  }
}