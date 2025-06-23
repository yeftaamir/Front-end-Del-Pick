// lib/Models/improved_customer.dart
import 'package:del_pick/Services/image_service.dart';

class Customer {
  final String id;
  final String name;
  final String email;
  final String phoneNumber;
  final String role;
  final String? avatar;
  final String? fcmToken;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool? emailVerified;

  Customer({
    required this.id,
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.role,
    this.avatar,
    this.fcmToken,
    this.createdAt,
    this.updatedAt,
    this.emailVerified,
  });

  // Create a Customer from a JSON map (backend response)
  factory Customer.fromJson(Map<String, dynamic> json) {
    String? avatarUrl = json['avatar'];

    // Process the avatar URL if it exists
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      avatarUrl = ImageService.getImageUrl(avatarUrl);
    }

    return Customer(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      phoneNumber: json['phone'] ?? '',  // Backend field name
      email: json['email'] ?? '',
      role: json['role'] ?? 'customer',
      avatar: avatarUrl,
      fcmToken: json['fcm_token'],
      emailVerified: json['email_verified'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  // Convert Customer to a JSON map (for API requests)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phoneNumber,  // Backend field name
      'email': email,
      'role': role,
      'avatar': avatar,
      'fcm_token': fcmToken,
      'email_verified': emailVerified,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  // Create a copy of Customer with some fields replaced
  Customer copyWith({
    String? id,
    String? name,
    String? phoneNumber,
    String? email,
    String? role,
    String? avatar,
    String? fcmToken,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? emailVerified,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      role: role ?? this.role,
      avatar: avatar ?? this.avatar,
      fcmToken: fcmToken ?? this.fcmToken,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      emailVerified: emailVerified ?? this.emailVerified,
    );
  }

  // Create empty customer for fallback
  factory Customer.empty() {
    return Customer(
      id: '',
      name: 'User Not Found',
      email: '',
      phoneNumber: '',
      role: 'customer',
      avatar: '',
    );
  }

  // Get processed profile image URL
  String? getProcessedImageUrl() {
    if (avatar == null || avatar!.isEmpty) {
      return null;
    }
    return ImageService.getImageUrl(avatar!);
  }
}