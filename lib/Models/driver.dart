import 'package:del_pick/Services/image_service.dart';
import 'user.dart';

class Driver {
  final int id;
  final int userId;
  final String licenseNumber;
  final String vehiclePlate;
  final String status; // 'active', 'inactive', 'busy'
  final double rating;
  final int reviewsCount;
  final double? latitude;
  final double? longitude;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // User relationship data
  final User? user;

  Driver({
    required this.id,
    required this.userId,
    required this.licenseNumber,
    required this.vehiclePlate,
    this.status = 'inactive',
    this.rating = 5.00,
    this.reviewsCount = 0,
    this.latitude,
    this.longitude,
    this.createdAt,
    this.updatedAt,
    this.user,
  });

  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      licenseNumber: json['license_number'] ?? '',
      vehiclePlate: json['vehicle_plate'] ?? '',
      status: json['status'] ?? 'inactive',
      rating: (json['rating'] as num?)?.toDouble() ?? 5.00,
      reviewsCount: json['reviews_count'] ?? 0,
      latitude: json['latitude'] != null ? double.tryParse(json['latitude'].toString()) : null,
      longitude: json['longitude'] != null ? double.tryParse(json['longitude'].toString()) : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      user: json['user'] != null ? User.fromJson(json['user']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'license_number': licenseNumber,
      'vehicle_plate': vehiclePlate,
      'status': status,
      'rating': rating,
      'reviews_count': reviewsCount,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      if (user != null) 'user': user!.toJson(),
    };
  }

  Driver copyWith({
    int? id,
    int? userId,
    String? licenseNumber,
    String? vehiclePlate,
    String? status,
    double? rating,
    int? reviewsCount,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
    DateTime? updatedAt,
    User? user,
  }) {
    return Driver(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      status: status ?? this.status,
      rating: rating ?? this.rating,
      reviewsCount: reviewsCount ?? this.reviewsCount,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      user: user ?? this.user,
    );
  }

  // Convenience getters
  String get name => user?.name ?? '';
  String get phoneNumber => user?.phone ?? '';
  String get email => user?.email ?? '';
  String? get profileImageUrl => user?.getProcessedImageUrl();

  static Driver empty() {
    return Driver(
      id: 0,
      userId: 0,
      licenseNumber: '',
      vehiclePlate: '',
    );
  }
}