import 'dart:convert';
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
    try {
      print('🔍 Parsing DriverRequest JSON: ${json.toString()}');

      return DriverRequestModel(
        id: _parseInt(json['id']),
        orderId: _parseInt(json['order_id']),
        driverId: _parseInt(json['driver_id']),
        status: DriverRequestStatusExtension.fromString(
            json['status'] ?? 'pending'),
        estimatedPickupTime: _parseDateTime(json['estimated_pickup_time']),
        estimatedDeliveryTime: _parseDateTime(json['estimated_delivery_time']),
        createdAt: _parseDateTime(json['created_at']) ?? DateTime.now(),
        updatedAt: _parseDateTime(json['updated_at']) ?? DateTime.now(),
        order: _parseOrder(json['order']), // ✅ Safe parsing
        driver: _parseDriver(json['driver']), // ✅ Safe parsing
      );
    } catch (e) {
      print('❌ Error parsing DriverRequestModel: $e');
      print('❌ JSON data: $json');
      rethrow;
    }
  }

  // ✅ Helper methods untuk safe parsing
  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is double) return value.toInt();
    return 0;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is String && value.isNotEmpty) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        print('❌ Error parsing datetime: $value - $e');
        return null;
      }
    }
    return null;
  }

  // ✅ Safe parsing untuk order object
  static OrderModel? _parseOrder(dynamic orderData) {
    try {
      if (orderData == null) return null;

      // Cek apakah orderData adalah Map
      if (orderData is Map<String, dynamic>) {
        return OrderModel.fromJson(orderData);
      }

      // Jika orderData adalah String, coba parse sebagai JSON
      if (orderData is String && orderData.isNotEmpty) {
        print('⚠️ Order data is String, trying to parse: $orderData');
        final Map<String, dynamic> parsedOrder = jsonDecode(orderData);
        return OrderModel.fromJson(parsedOrder);
      }

      print('⚠️ Order data type not supported: ${orderData.runtimeType}');
      return null;
    } catch (e) {
      print('❌ Error parsing order data: $e');
      print('❌ Order data: $orderData');
      return null;
    }
  }

  // ✅ Safe parsing untuk driver object
  static DriverModel? _parseDriver(dynamic driverData) {
    try {
      if (driverData == null) return null;

      // Cek apakah driverData adalah Map
      if (driverData is Map<String, dynamic>) {
        return DriverModel.fromJson(driverData);
      }

      // Jika driverData adalah String, coba parse sebagai JSON
      if (driverData is String && driverData.isNotEmpty) {
        print('⚠️ Driver data is String, trying to parse: $driverData');
        final Map<String, dynamic> parsedDriver = jsonDecode(driverData);
        return DriverModel.fromJson(parsedDriver);
      }

      print('⚠️ Driver data type not supported: ${driverData.runtimeType}');
      return null;
    } catch (e) {
      print('❌ Error parsing driver data: $e');
      print('❌ Driver data: $driverData');
      return null;
    }
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

  // ✅ TAMBAH: Delivery status helper
  String get deliveryStatus => order?.deliveryStatus?.value ?? 'pending';
  DeliveryStatus? get deliveryStatusEnum => order?.deliveryStatus;

  String get requestStatusText => status.displayName;

  bool get isPending => status == DriverRequestStatus.pending;
  bool get isAccepted => status == DriverRequestStatus.accepted;
  bool get isRejected => status == DriverRequestStatus.rejected;
  bool get isCompleted => status == DriverRequestStatus.completed;
  bool get isExpired => status == DriverRequestStatus.expired;

  bool get canRespond => isPending;
  bool get isActive => isPending || isAccepted;

  // ✅ FIXED: Driver earnings calculation sesuai backend logic
  double get driverEarnings {
    if (orderStatusEnum == OrderStatus.delivered && order != null) {
      // ✅ BACKEND LOGIC: Berdasarkan orderController.js - calculateEstimatedEarnings()
      // Driver mendapat delivery fee berdasarkan distance calculation

      // Jarak dihitung menggunakan euclideanDistance * 111 km kemudian * 2000
      // Delivery fee = Math.ceil(distance_km * 2000)
      // Contoh: jika distance 2.5 km, maka delivery_fee = Math.ceil(2.5 * 2000) = 5000

      final deliveryFee = order!.deliveryFee;

      // ✅ BACKEND: Driver mendapat 100% dari delivery fee (tidak ada potongan commission di backend)
      // Berbeda dengan asumsi awal, di backend driver mendapat full delivery fee
      return deliveryFee;
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

  // ✅ TAMBAH: Delivery fee information sesuai backend
  double get orderDeliveryFee => order?.deliveryFee ?? 0.0;

  String get formattedDeliveryFee {
    final fee = orderDeliveryFee;
    return 'Rp ${fee.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        )}';
  }

  // ✅ TAMBAH: Distance information dari backend calculation
  String get distanceInfo {
    if (order != null &&
        order!.destinationLatitude != null &&
        order!.destinationLongitude != null) {
      // Backend menggunakan koordinat tetap: 2.3834831864787818, 99.14857915147614
      // Untuk estimasi distance, kita bisa menggunakan delivery fee sebagai indikator
      final deliveryFee = order!.deliveryFee;

      // Reverse calculation: distance_km ≈ delivery_fee / 2000
      final estimatedDistance = deliveryFee / 2000;

      if (estimatedDistance > 0) {
        return '≈ ${estimatedDistance.toStringAsFixed(1)} km';
      }
    }
    return 'Distance tidak tersedia';
  }

  // Status properties untuk UI
  String get statusDisplayText => status.displayName;
  String get statusValue => status.value;

  // ✅ TAMBAH: Method untuk checking status pengantaran
  bool get isOnDelivery =>
      orderStatusEnum == OrderStatus.onDelivery &&
      deliveryStatusEnum == DeliveryStatus.onWay;

  bool get isDelivered =>
      orderStatusEnum == OrderStatus.delivered &&
      deliveryStatusEnum == DeliveryStatus.delivered;

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

  // ✅ TAMBAH: Backend-specific delivery fee calculation info
  String get deliveryFeeCalculationInfo {
    if (order != null) {
      final fee = order!.deliveryFee;
      return 'Biaya pengiriman: $formattedDeliveryFee (Driver earning: $formattedEarnings)';
    }
    return 'Biaya pengiriman belum dihitung';
  }

  // ✅ TAMBAH: Destination information sesuai backend
  String get destinationInfo {
    if (order != null &&
        order!.destinationLatitude != null &&
        order!.destinationLongitude != null) {
      // Backend menggunakan destinasi tetap ke IT Del
      const itDelLat = 2.3834831864787818;
      const itDelLng = 99.14857915147614;

      if (order!.destinationLatitude == itDelLat &&
          order!.destinationLongitude == itDelLng) {
        return 'IT Del (Institut Teknologi Del)';
      } else {
        return 'Lat: ${order!.destinationLatitude!.toStringAsFixed(6)}, Lng: ${order!.destinationLongitude!.toStringAsFixed(6)}';
      }
    }
    return 'Destinasi belum tersedia';
  }

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
