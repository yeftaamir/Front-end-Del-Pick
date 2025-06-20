import 'package:del_pick/Services/image_service.dart';

class User {
  final int id;
  final String name;
  final String email;
  final String? password; // For registration, optional for responses
  final String role;
  final String? phone;
  final String? fcmToken;
  final String? avatar;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.password,
    required this.role,
    this.phone,
    this.fcmToken,
    this.avatar,
    this.createdAt,
    this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    String? avatarUrl = json['avatar'];
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      avatarUrl = ImageService.getImageUrl(avatarUrl);
    }

    return User(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      password: json['password'], // Only for registration
      role: json['role'] ?? 'customer',
      phone: json['phone'],
      fcmToken: json['fcm_token'],
      avatar: avatarUrl,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      if (password != null) 'password': password,
      'role': role,
      if (phone != null) 'phone': phone,
      if (fcmToken != null) 'fcm_token': fcmToken,
      if (avatar != null) 'avatar': avatar,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  User copyWith({
    int? id,
    String? name,
    String? email,
    String? password,
    String? role,
    String? phone,
    String? fcmToken,
    String? avatar,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      fcmToken: fcmToken ?? this.fcmToken,
      avatar: avatar ?? this.avatar,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory User.empty() {
    return User(
      id: 0,
      name: '',
      email: '',
      role: 'customer',
    );
  }

  String? getProcessedImageUrl() {
    if (avatar == null || avatar!.isEmpty) {
      return null;
    }
    return ImageService.getImageUrl(avatar!);
  }
}

// Alias for backward compatibility
typedef Customer = User;