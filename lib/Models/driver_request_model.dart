import 'package:del_pick/Models/driver.dart';
import 'package:del_pick/Models/order.dart';
import 'package:del_pick/Models/order_enum.dart';

class DriverRequestModel {
  final int id;
  final int orderId;
  final int driverId;
  final DriverRequestStatus status;
  final DateTime? estimatedPickupTime;
  final DateTime? estimatedDeliveryTime;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Related models
  final OrderModel? order;
  final DriverModel? driver;

  const DriverRequestModel({
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

  factory DriverRequestModel.fromJson(Map<String, dynamic> json) {
    return DriverRequestModel(
      id: json['id'] ?? 0,
      orderId: json['order_id'] ?? 0,
      driverId: json['driver_id'] ?? 0,
      status:
          DriverRequestStatusExtension.fromString(json['status'] ?? 'pending'),
      estimatedPickupTime: json['estimated_pickup_time'] != null
          ? DateTime.parse(json['estimated_pickup_time'])
          : null,
      estimatedDeliveryTime: json['estimated_delivery_time'] != null
          ? DateTime.parse(json['estimated_delivery_time'])
          : null,
      createdAt: DateTime.parse(
          json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(
          json['updated_at'] ?? DateTime.now().toIso8601String()),
      order: json['order'] != null ? OrderModel.fromJson(json['order']) : null,
      driver:
          json['driver'] != null ? DriverModel.fromJson(json['driver']) : null,
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
      'order': order?.toJson(),
      'driver': driver?.toJson(),
    };
  }

  DriverRequestModel copyWith({
    int? id,
    int? orderId,
    int? driverId,
    DriverRequestStatus? status,
    DateTime? estimatedPickupTime,
    DateTime? estimatedDeliveryTime,
    DateTime? createdAt,
    DateTime? updatedAt,
    OrderModel? order,
    DriverModel? driver,
  }) {
    return DriverRequestModel(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      driverId: driverId ?? this.driverId,
      status: status ?? this.status,
      estimatedPickupTime: estimatedPickupTime ?? this.estimatedPickupTime,
      estimatedDeliveryTime:
          estimatedDeliveryTime ?? this.estimatedDeliveryTime,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      order: order ?? this.order,
      driver: driver ?? this.driver,
    );
  }

  // Helper methods
  String get orderStatus => order?.orderStatus.value ?? 'pending';
  OrderStatus get orderStatusEnum => order?.orderStatus ?? OrderStatus.pending;

  String get requestStatusText => status.displayName;

  bool get isPending => status == DriverRequestStatus.pending;
  bool get isAccepted => status == DriverRequestStatus.accepted;
  bool get isRejected => status == DriverRequestStatus.rejected;
  bool get isCompleted => status == DriverRequestStatus.completed;
  bool get isExpired => status == DriverRequestStatus.expired;

  bool get canRespond => isPending;
  bool get isActive => isPending || isAccepted;

  double get driverEarnings {
    if (orderStatusEnum == OrderStatus.delivered && order != null) {
      const double baseDeliveryFee = 5000.0;
      const double commissionRate = 0.8;
      return baseDeliveryFee + (order!.deliveryFee * commissionRate);
    }
    return 0.0;
  }

  String get formattedEarnings {
    final earnings = driverEarnings;
    if (earnings > 0) {
      return 'Rp ${earnings.toStringAsFixed(0).replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]}.',
          )}';
    }
    return 'Rp 0';
  }

  // Status properties untuk UI
  String get statusDisplayText => status.displayName;
  String get statusValue => status.value;

  // Validation methods
  bool get isValid => id > 0 && orderId > 0 && driverId > 0;

  // Time-related helpers
  String get formattedCreatedAt {
    return '${createdAt.day}/${createdAt.month}/${createdAt.year} ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}';
  }

  Duration? get timeToPickup {
    if (estimatedPickupTime != null) {
      final now = DateTime.now();
      final diff = estimatedPickupTime!.difference(now);
      return diff.isNegative ? null : diff;
    }
    return null;
  }

  Duration? get timeToDelivery {
    if (estimatedDeliveryTime != null) {
      final now = DateTime.now();
      final diff = estimatedDeliveryTime!.difference(now);
      return diff.isNegative ? null : diff;
    }
    return null;
  }

  String? get pickupTimeFormatted {
    if (estimatedPickupTime != null) {
      return '${estimatedPickupTime!.hour}:${estimatedPickupTime!.minute.toString().padLeft(2, '0')}';
    }
    return null;
  }

  String? get deliveryTimeFormatted {
    if (estimatedDeliveryTime != null) {
      return '${estimatedDeliveryTime!.hour}:${estimatedDeliveryTime!.minute.toString().padLeft(2, '0')}';
    }
    return null;
  }

  // Order-related helpers
  String get customerName => order?.customer?.name ?? 'Unknown Customer';
  String get storeName => order?.store?.name ?? 'Unknown Store';
  String? get customerPhone => order?.customer?.phone;
  String? get storePhone => order?.store?.phone;

  int get totalItems => order?.totalItems ?? 0;
  double get totalAmount => order?.totalAmount ?? 0.0;
  String get formattedTotalAmount => order?.formatTotalAmount() ?? 'Rp 0';

  // Driver-related helpers
  String get driverName => driver?.user?.name ?? 'Unknown Driver';
  String? get driverPhone => driver?.user?.phone;
  double? get driverLatitude => driver?.latitude;
  double? get driverLongitude => driver?.longitude;
  DriverStatus get driverStatus => driver?.status ?? DriverStatus.inactive;

  @override
  String toString() {
    return 'DriverRequestModel(id: $id, orderId: $orderId, driverId: $driverId, status: ${status.value})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DriverRequestModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
