// ========================================
// 2. lib/models/user_model.dart
// ========================================

import 'package:del_pick/services/image_service.dart';
import 'order_enum.dart';

class UserModel {
  final int id;
  final String name;
  final String email;
  final String phone;
  final UserRole role;
  final String? avatar;
  final String? fcmToken;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.avatar,
    this.fcmToken,
    this.createdAt,
    this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    String? processedAvatar;
    if (json['avatar'] != null && json['avatar'].toString().isNotEmpty) {
      processedAvatar = ImageService.getImageUrl(json['avatar']);
    }

    return UserModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      role: _parseUserRole(json['role']),
      avatar: processedAvatar,
      fcmToken: json['fcm_token'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role.name,
      'avatar': avatar,
      'fcm_token': fcmToken,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  UserModel copyWith({
    int? id,
    String? name,
    String? email,
    String? phone,
    UserRole? role,
    String? avatar,
    String? fcmToken,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      avatar: avatar ?? this.avatar,
      fcmToken: fcmToken ?? this.fcmToken,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static UserRole _parseUserRole(dynamic role) {
    if (role == null) return UserRole.customer;
    final roleString = role.toString().toLowerCase();
    return UserRole.values.firstWhere(
          (e) => e.name == roleString,
      orElse: () => UserRole.customer,
    );
  }

  // Utility methods
  String get displayName => name.isNotEmpty ? name : 'Anonymous User';
  String get roleDisplayName => role.name.toUpperCase();
  String? get processedAvatarUrl => avatar != null ? ImageService.getImageUrl(avatar!) : null;
}