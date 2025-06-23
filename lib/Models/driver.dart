// ========================================
// 4. lib/models/driver_model.dart
// ========================================

import 'package:del_pick/Models/user.dart';
import 'order_enum.dart';

class DriverModel {
  final UserModel user;
  final int driverId;
  final String licenseNumber;
  final String vehiclePlate;
  final double rating;
  final int reviewsCount;
  final DriverStatus status;
  final double? latitude;
  final double? longitude;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DriverModel({
    required this.user,
    required this.driverId,
    required this.licenseNumber,
    required this.vehiclePlate,
    this.rating = 5.0,
    this.reviewsCount = 0,
    this.status = DriverStatus.inactive,
    this.latitude,
    this.longitude,
    this.createdAt,
    this.updatedAt,
  });

  factory DriverModel.fromJson(Map<String, dynamic> json) {
    final userData = json['user'] ?? json;
    final driverData = json['driver'] ?? json;

    return DriverModel(
      user: UserModel.fromJson(userData),
      driverId: driverData['id'] ?? 0,
      licenseNumber: driverData['license_number'] ?? '',
      vehiclePlate: driverData['vehicle_plate'] ?? '',
      rating: (driverData['rating'] ?? 5.0).toDouble(),
      reviewsCount: driverData['reviews_count'] ?? 0,
      status: _parseDriverStatus(driverData['status']),
      latitude: driverData['latitude']?.toDouble(),
      longitude: driverData['longitude']?.toDouble(),
      createdAt: driverData['created_at'] != null
          ? DateTime.parse(driverData['created_at'])
          : null,
      updatedAt: driverData['updated_at'] != null
          ? DateTime.parse(driverData['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'driver': {
        'id': driverId,
        'license_number': licenseNumber,
        'vehicle_plate': vehiclePlate,
        'rating': rating,
        'reviews_count': reviewsCount,
        'status': status.name,
        'latitude': latitude,
        'longitude': longitude,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      }
    };
  }

  DriverModel copyWith({
    UserModel? user,
    int? driverId,
    String? licenseNumber,
    String? vehiclePlate,
    double? rating,
    int? reviewsCount,
    DriverStatus? status,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DriverModel(
      user: user ?? this.user,
      driverId: driverId ?? this.driverId,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      rating: rating ?? this.rating,
      reviewsCount: reviewsCount ?? this.reviewsCount,
      status: status ?? this.status,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DriverStatus _parseDriverStatus(dynamic status) {
    if (status == null) return DriverStatus.inactive;
    final statusString = status.toString().toLowerCase();
    return DriverStatus.values.firstWhere(
          (e) => e.name == statusString,
      orElse: () => DriverStatus.inactive,
    );
  }

  // Convenience getters
  int get userId => user.id;
  String get name => user.name;
  String get email => user.email;
  String get phone => user.phone;
  String? get avatar => user.avatar;

  // Utility methods
  bool get isAvailable => status == DriverStatus.active;
  bool get hasLocation => latitude != null && longitude != null;

  String get formattedRating => '${rating.toStringAsFixed(1)} (${reviewsCount} reviews)';

  String get statusDisplayName {
    switch (status) {
      case DriverStatus.active:
        return 'Available';
      case DriverStatus.busy:
        return 'On Delivery';
      case DriverStatus.inactive:
        return 'Offline';
    }
  }
}