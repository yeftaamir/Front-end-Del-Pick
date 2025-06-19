// lib/models/entities/driver.dart
import 'package:del_pick/Models/Entities/user.dart';

import '../Enums/driver_status.dart';
import 'driver_request.dart';
import 'driver_review.dart';
import 'order.dart';

class Driver {
  final int id;
  final int userId;
  final String licenseNumber;
  final String vehiclePlate;
  final DriverStatus status;
  final double rating;
  final int reviewsCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double? latitude;
  final double? longitude;

  // Relations
  final User? user;
  final List<Order>? orders;
  final List<DriverReview>? driverReviews;
  final List<DriverRequest>? driverRequests;

  Driver({
    required this.id,
    required this.userId,
    required this.licenseNumber,
    required this.vehiclePlate,
    required this.status,
    required this.rating,
    required this.reviewsCount,
    required this.createdAt,
    required this.updatedAt,
    this.latitude,
    this.longitude,
    this.user,
    this.orders,
    this.driverReviews,
    this.driverRequests,
  });

  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      licenseNumber: json['license_number'] as String,
      vehiclePlate: json['vehicle_plate'] as String,
      status: DriverStatus.fromString(json['status'] as String),
      rating: double.parse(json['rating'].toString()),
      reviewsCount: json['reviews_count'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      latitude: json['latitude'] != null
          ? double.parse(json['latitude'].toString())
          : null,
      longitude: json['longitude'] != null
          ? double.parse(json['longitude'].toString())
          : null,
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      orders: json['orders'] != null
          ? (json['orders'] as List)
          .map((order) => Order.fromJson(order))
          .toList()
          : null,
      driverReviews: json['driverReviews'] != null
          ? (json['driverReviews'] as List)
          .map((review) => DriverReview.fromJson(review))
          .toList()
          : null,
      driverRequests: json['driverRequests'] != null
          ? (json['driverRequests'] as List)
          .map((request) => DriverRequest.fromJson(request))
          .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'license_number': licenseNumber,
      'vehicle_plate': vehiclePlate,
      'status': status.value,
      'rating': rating,
      'reviews_count': reviewsCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      if (user != null) 'user': user!.toJson(),
      if (orders != null) 'orders': orders!.map((order) => order.toJson()).toList(),
      if (driverReviews != null)
        'driverReviews': driverReviews!.map((review) => review.toJson()).toList(),
      if (driverRequests != null)
        'driverRequests': driverRequests!.map((request) => request.toJson()).toList(),
    };
  }
}