import 'package:del_pick/Services/image_service.dart';

class Customer {
  final String id;
  final String name;
  final String email;
  final String phoneNumber;
  final String role;
  final String? profileImageUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Customer({
    required this.id,
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.role,
    this.profileImageUrl,
    this.createdAt,
    this.updatedAt,
  });

  // Create a Customer from a JSON map
  factory Customer.fromJson(Map<String, dynamic> json) {
    String? avatarUrl = json['avatar'];

    // Process the avatar URL if it exists
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      avatarUrl = ImageService.getImageUrl(avatarUrl);
    }

    return Customer(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      phoneNumber: json['phone'] ?? '',  // Matches backend field name
      email: json['email'] ?? '',
      role: json['role'] ?? 'customer',
      profileImageUrl: avatarUrl,  // Use processed URL
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  // Convert Customer to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phoneNumber,  // Matches backend field name
      'email': email,
      'role': role,
      'avatar': profileImageUrl,  // Matches backend field name
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  // Create a copy of Customer with some fields replaced
  Customer copyWith({
    String? id,
    String? name,
    String? phoneNumber,
    String? email,
    String? role,
    String? profileImageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      role: role ?? this.role,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
      profileImageUrl: '',
    );
  }

  // Create from stored user data (from login)
  factory Customer.fromStoredData(Map<String, dynamic> data) {
    String? avatarUrl = data['avatar'];

    // Process the avatar URL if it exists
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      avatarUrl = ImageService.getImageUrl(avatarUrl);
    }

    return Customer(
      id: data['id']?.toString() ?? '',
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phoneNumber: data['phone'] ?? '',
      role: data['role'] ?? 'customer',
      profileImageUrl: avatarUrl,  // Use processed URL
      createdAt: data['createdAt'] != null ? DateTime.parse(data['createdAt']) : null,
      updatedAt: data['updatedAt'] != null ? DateTime.parse(data['updatedAt']) : null,
    );
  }

  // Get processed profile image URL
  String? getProcessedImageUrl() {
    if (profileImageUrl == null || profileImageUrl!.isEmpty) {
      return null;
    }
    return ImageService.getImageUrl(profileImageUrl!);
  }
}