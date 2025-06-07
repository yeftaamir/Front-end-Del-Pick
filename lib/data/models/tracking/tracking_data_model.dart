// lib/data/models/tracking/tracking_data_model.dart
import 'package:del_pick/data/models/tracking/location_model.dart';
class TrackingData {
  final int orderId;
  final String status;
  final LocationModel? storeLocation;
  final LocationModel? driverLocation;
  final LocationModel? customerLocation;
  final String? estimatedDeliveryTime;
  final DriverInfo? driver;
  final String? message;
  final DateTime? lastUpdated;

  TrackingData({
    required this.orderId,
    required this.status,
    this.storeLocation,
    this.driverLocation,
    this.customerLocation,
    this.estimatedDeliveryTime,
    this.driver,
    this.message,
    this.lastUpdated,
  });

  factory TrackingData.fromJson(Map<String, dynamic> json) {
    return TrackingData(
      orderId: json['orderId'] as int,
      status: json['status'] as String,
      storeLocation: json['storeLocation'] != null
          ? LocationModel.fromJson(
              json['storeLocation'] as Map<String, dynamic>)
          : null,
      driverLocation: json['driverLocation'] != null
          ? LocationModel.fromJson(
              json['driverLocation'] as Map<String, dynamic>)
          : null,
      customerLocation: json['customerLocation'] != null
          ? LocationModel.fromJson(
              json['customerLocation'] as Map<String, dynamic>)
          : null,
      estimatedDeliveryTime: json['estimatedDeliveryTime'] as String?,
      driver: json['driver'] != null
          ? DriverInfo.fromJson(json['driver'] as Map<String, dynamic>)
          : null,
      message: json['message'] as String?,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'orderId': orderId,
      'status': status,
      'storeLocation': storeLocation?.toJson(),
      'driverLocation': driverLocation?.toJson(),
      'customerLocation': customerLocation?.toJson(),
      'estimatedDeliveryTime': estimatedDeliveryTime,
      'driver': driver?.toJson(),
      'message': message,
      'lastUpdated': lastUpdated?.toIso8601String(),
    };
  }

  TrackingData copyWith({
    int? orderId,
    String? status,
    LocationModel? storeLocation,
    LocationModel? driverLocation,
    LocationModel? customerLocation,
    String? estimatedDeliveryTime,
    DriverInfo? driver,
    String? message,
    DateTime? lastUpdated,
  }) {
    return TrackingData(
      orderId: orderId ?? this.orderId,
      status: status ?? this.status,
      storeLocation: storeLocation ?? this.storeLocation,
      driverLocation: driverLocation ?? this.driverLocation,
      customerLocation: customerLocation ?? this.customerLocation,
      estimatedDeliveryTime:
          estimatedDeliveryTime ?? this.estimatedDeliveryTime,
      driver: driver ?? this.driver,
      message: message ?? this.message,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  // Helper getters
  bool get hasDriver => driver != null;
  bool get hasDriverLocation => driverLocation != null;
  bool get hasStoreLocation => storeLocation != null;
  bool get hasCustomerLocation => customerLocation != null;

  String get statusDisplayName {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Menunggu Konfirmasi';
      case 'preparing':
        return 'Sedang Disiapkan';
      case 'on_the_way':
        return 'Dalam Perjalanan';
      case 'delivered':
        return 'Terkirim';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return status;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackingData &&
          runtimeType == other.runtimeType &&
          orderId == other.orderId;

  @override
  int get hashCode => orderId.hashCode;

  @override
  String toString() {
    return 'TrackingData{orderId: $orderId, status: $status, hasDriver: $hasDriver}';
  }
}

class DriverInfo {
  final int id;
  final String name;
  final String? phone;
  final String? vehicleType;
  final String? vehicleNumber;
  final double? rating;
  final String? avatar;

  DriverInfo({
    required this.id,
    required this.name,
    this.phone,
    this.vehicleType,
    this.vehicleNumber,
    this.rating,
    this.avatar,
  });

  factory DriverInfo.fromJson(Map<String, dynamic> json) {
    return DriverInfo(
      id: json['id'] as int,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      vehicleType: json['vehicleType'] as String?,
      vehicleNumber: json['vehicleNumber'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      avatar: json['avatar'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'vehicleType': vehicleType,
      'vehicleNumber': vehicleNumber,
      'rating': rating,
      'avatar': avatar,
    };
  }

  String get displayRating => rating?.toStringAsFixed(1) ?? '0.0';

  @override
  String toString() {
    return 'DriverInfo{id: $id, name: $name, vehicle: $vehicleNumber}';
  }
}
