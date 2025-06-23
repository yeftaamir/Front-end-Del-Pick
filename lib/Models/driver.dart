

// lib/Models/improved_driver.dart
import 'package:del_pick/Services/image_service.dart';

class Driver {
  final String id;           // User ID
  final String name;
  final String email;
  final String phoneNumber;
  final String role;
  final String? avatar;
  final String? fcmToken;

  // Driver-specific fields
  final String licenseNumber;
  final String vehiclePlate;
  final double rating;
  final int reviewsCount;
  final String status;       // active, inactive, busy
  final double? latitude;
  final double? longitude;

  // Timestamps
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Driver({
    required this.id,
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.role,
    required this.licenseNumber,
    required this.vehiclePlate,
    this.avatar,
    this.fcmToken,
    this.rating = 5.0,
    this.reviewsCount = 0,
    this.status = 'inactive',
    this.latitude,
    this.longitude,
    this.createdAt,
    this.updatedAt,
  });

  // Factory constructor to create a Driver from JSON data from API
  factory Driver.fromJson(Map<String, dynamic> json) {
    // Handle case where driver info comes directly or nested
    final Map<String, dynamic> userData = json['user'] ?? json;
    final Map<String, dynamic> driverData = json['driver'] ?? json;

    // Process avatar URL
    String? avatarUrl = userData['avatar'];
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      avatarUrl = ImageService.getImageUrl(avatarUrl);
    }

    return Driver(
      id: userData['id']?.toString() ?? '',
      name: userData['name'] ?? '',
      email: userData['email'] ?? '',
      phoneNumber: userData['phone'] ?? '',
      role: userData['role'] ?? 'driver',
      avatar: avatarUrl,
      fcmToken: userData['fcm_token'],
      licenseNumber: driverData['license_number'] ?? '',
      vehiclePlate: driverData['vehicle_plate'] ?? '',
      rating: (driverData['rating'] as num?)?.toDouble() ?? 5.0,
      reviewsCount: driverData['reviews_count'] as int? ?? 0,
      status: driverData['status'] ?? 'inactive',
      latitude: driverData['latitude'] != null ?
      double.tryParse(driverData['latitude'].toString()) : null,
      longitude: driverData['longitude'] != null ?
      double.tryParse(driverData['longitude'].toString()) : null,
      createdAt: userData['created_at'] != null ?
      DateTime.parse(userData['created_at']) : null,
      updatedAt: userData['updated_at'] != null ?
      DateTime.parse(userData['updated_at']) : null,
    );
  }

  // Convert Driver instance to JSON
  Map<String, dynamic> toJson() {
    return {
      'user': {
        'id': id,
        'name': name,
        'email': email,
        'phone': phoneNumber,
        'role': role,
        'avatar': avatar,
        'fcm_token': fcmToken,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      },
      'driver': {
        'license_number': licenseNumber,
        'vehicle_plate': vehiclePlate,
        'rating': rating,
        'reviews_count': reviewsCount,
        'status': status,
        'latitude': latitude,
        'longitude': longitude,
      }
    };
  }

  // Create a copy of this Driver with the given field values changed
  Driver copyWith({
    String? id,
    String? name,
    String? email,
    String? phoneNumber,
    String? role,
    String? avatar,
    String? fcmToken,
    String? licenseNumber,
    String? vehiclePlate,
    double? rating,
    int? reviewsCount,
    String? status,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Driver(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      avatar: avatar ?? this.avatar,
      fcmToken: fcmToken ?? this.fcmToken,
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

  // Create an empty Driver object
  static Driver empty() {
    return Driver(
      id: '',
      name: '',
      email: '',
      phoneNumber: '',
      role: 'driver',
      licenseNumber: '',
      vehiclePlate: '',
      status: 'inactive',
    );
  }

  // Get the processed profile image URL
  String? getProcessedImageUrl() {
    if (avatar == null || avatar!.isEmpty) {
      return null;
    }
    return ImageService.getImageUrl(avatar!);
  }

  // Check if driver is available for new orders
  bool get isAvailable => status == 'active';

  // Get formatted rating
  String get formattedRating => '${rating.toStringAsFixed(1)} ($reviewsCount reviews)';
}