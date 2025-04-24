import 'package:del_pick/Services/image_service.dart';

class Driver {
  final String id;           // Represents user id from the User model
  final String name;
  final double rating;
  final String phoneNumber;
  final String vehicleNumber;
  final String email;
  final String role;
  final String? avatar;
  final int reviewsCount;
  final double? latitude;    // Added to match backend
  final double? longitude;   // Added to match backend
  final String status;       // Added to match backend (active/inactive)

  Driver({
    required this.id,
    required this.name,
    required this.rating,
    required this.phoneNumber,
    required this.vehicleNumber,
    required this.email,
    required this.role,
    this.avatar,
    this.reviewsCount = 0,
    this.latitude,
    this.longitude,
    this.status = 'inactive',
  });

  // Factory constructor to create a Driver from stored user data
  factory Driver.fromStoredData(Map<String, dynamic> data) {
    String? avatarUrl = data['avatar'];

    // Process the avatar URL if it exists
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      avatarUrl = ImageService.getImageUrl(avatarUrl);
    }

    return Driver(
      id: data['id']?.toString() ?? '',
      name: data['name'] ?? '',
      rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
      phoneNumber: data['phone'] ?? '',
      vehicleNumber: data['vehicle_number'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? 'driver',
      avatar: avatarUrl,
      reviewsCount: data['reviews_count'] as int? ?? 0,
      latitude: data['latitude'] != null ? double.tryParse(data['latitude'].toString()) : null,
      longitude: data['longitude'] != null ? double.tryParse(data['longitude'].toString()) : null,
      status: data['status'] ?? 'inactive',
    );
  }

  // Factory constructor to create a Driver from JSON data from API
  factory Driver.fromJson(Map<String, dynamic> json) {
    // Handle case where driver info comes directly or nested in 'driver' and 'user' objects
    final Map<String, dynamic> driverData = json['driver'] ?? json;
    final Map<String, dynamic> userData = driverData['user'] ?? json;

    // Process avatar URL
    String? avatarUrl = userData['avatar'];
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      avatarUrl = ImageService.getImageUrl(avatarUrl);
    }

    return Driver(
      id: userData['id']?.toString() ?? '',
      name: userData['name'] ?? '',
      rating: (driverData['rating'] as num?)?.toDouble() ?? 0.0,
      phoneNumber: userData['phone'] ?? '',
      vehicleNumber: driverData['vehicle_number'] ?? '',
      email: userData['email'] ?? '',
      role: userData['role'] ?? 'driver',
      avatar: avatarUrl,
      reviewsCount: driverData['reviews_count'] as int? ?? 0,
      latitude: driverData['latitude'] != null ? double.tryParse(driverData['latitude'].toString()) : null,
      longitude: driverData['longitude'] != null ? double.tryParse(driverData['longitude'].toString()) : null,
      status: driverData['status'] ?? 'inactive',
    );
  }

  // Convert Driver instance to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'rating': rating,
      'phone': phoneNumber,
      'vehicle_number': vehicleNumber,
      'email': email,
      'role': role,
      'avatar': avatar,
      'reviews_count': reviewsCount,
      'latitude': latitude,
      'longitude': longitude,
      'status': status,
    };
  }

  // Create an empty Driver object
  static Driver empty() {
    return Driver(
      id: '',
      name: '',
      rating: 0.0,
      phoneNumber: '',
      vehicleNumber: '',
      email: '',
      role: 'driver',
      avatar: '',
      status: 'inactive',
    );
  }

  // Create a copy of this Driver with the given field values changed
  Driver copyWith({
    String? id,
    String? name,
    double? rating,
    String? phoneNumber,
    String? vehicleNumber,
    String? email,
    String? role,
    String? avatar,
    int? reviewsCount,
    double? latitude,
    double? longitude,
    String? status,
  }) {
    return Driver(
      id: id ?? this.id,
      name: name ?? this.name,
      rating: rating ?? this.rating,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      email: email ?? this.email,
      role: role ?? this.role,
      avatar: avatar ?? this.avatar,
      reviewsCount: reviewsCount ?? this.reviewsCount,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      status: status ?? this.status,
    );
  }

  // Get the processed profile image URL
  String? getProcessedImageUrl() {
    if (avatar == null || avatar!.isEmpty) {
      return null;
    }
    return ImageService.getImageUrl(avatar!);
  }
}