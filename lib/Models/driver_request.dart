import 'order.dart';
import 'driver.dart';

enum DriverRequestStatus {
  pending,
  accepted,
  rejected,
  completed,
  expired;

  static DriverRequestStatus fromString(String status) {
    try {
      return DriverRequestStatus.values.firstWhere(
              (e) => e.toString().split('.').last.toLowerCase() == status.toLowerCase()
      );
    } catch (_) {
      return DriverRequestStatus.pending;
    }
  }
}

class DriverRequest {
  final int id;
  final int orderId;
  final int driverId;
  final DriverRequestStatus status;
  final DateTime? estimatedPickupTime;
  final DateTime? estimatedDeliveryTime;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Relationship data
  final Order? order;
  final Driver? driver;

  DriverRequest({
    required this.id,
    required this.orderId,
    required this.driverId,
    this.status = DriverRequestStatus.pending,
    this.estimatedPickupTime,
    this.estimatedDeliveryTime,
    this.createdAt,
    this.updatedAt,
    this.order,
    this.driver,
  });

  factory DriverRequest.fromJson(Map<String, dynamic> json) {
    DriverRequestStatus status = DriverRequestStatus.pending;
    if (json['status'] != null) {
      status = DriverRequestStatus.fromString(json['status']);
    }

    return DriverRequest(
      id: json['id'] ?? 0,
      orderId: json['order_id'] ?? 0,
      driverId: json['driver_id'] ?? 0,
      status: status,
      estimatedPickupTime: json['estimated_pickup_time'] != null ? DateTime.parse(json['estimated_pickup_time']) : null,
      estimatedDeliveryTime: json['estimated_delivery_time'] != null ? DateTime.parse(json['estimated_delivery_time']) : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      order: json['order'] != null ? Order.fromJson(json['order']) : null,
      driver: json['driver'] != null ? Driver.fromJson(json['driver']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'driver_id': driverId,
      'status': status.toString().split('.').last,
      if (estimatedPickupTime != null) 'estimated_pickup_time': estimatedPickupTime!.toIso8601String(),
      if (estimatedDeliveryTime != null) 'estimated_delivery_time': estimatedDeliveryTime!.toIso8601String(),
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      if (order != null) 'order': order!.toJson(),
      if (driver != null) 'driver': driver!.toJson(),
    };
  }

  DriverRequest copyWith({
    int? id,
    int? orderId,
    int? driverId,
    DriverRequestStatus? status,
    DateTime? estimatedPickupTime,
    DateTime? estimatedDeliveryTime,
    DateTime? createdAt,
    DateTime? updatedAt,
    Order? order,
    Driver? driver,
  }) {
    return DriverRequest(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      driverId: driverId ?? this.driverId,
      status: status ?? this.status,
      estimatedPickupTime: estimatedPickupTime ?? this.estimatedPickupTime,
      estimatedDeliveryTime: estimatedDeliveryTime ?? this.estimatedDeliveryTime,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      order: order ?? this.order,
      driver: driver ?? this.driver,
    );
  }
}