// lib/models/entities/user.dart
import 'package:del_pick/Models/Entities/store.dart';

import '../Enums/user_role.dart';
import 'driver.dart';

class User {
  final int id;
  final String name;
  final String email;
  final UserRole role;
  final String? phone;
  final String? fcmToken;
  final String? avatar;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Relations
  final Store? store;
  final Driver? driver;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.fcmToken,
    this.avatar,
    required this.createdAt,
    required this.updatedAt,
    this.store,
    this.driver,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      role: UserRole.fromString(json['role'] as String),
      phone: json['phone'] as String?,
      fcmToken: json['fcm_token'] as String?,
      avatar: json['avatar'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      store: json['store'] != null ? Store.fromJson(json['store']) : null,
      driver: json['driver'] != null ? Driver.fromJson(json['driver']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role.value,
      'phone': phone,
      'fcm_token': fcmToken,
      'avatar': avatar,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (store != null) 'store': store!.toJson(),
      if (driver != null) 'driver': driver!.toJson(),
    };
  }

  User copyWith({
    int? id,
    String? name,
    String? email,
    UserRole? role,
    String? phone,
    String? fcmToken,
    String? avatar,
    DateTime? createdAt,
    DateTime? updatedAt,
    Store? store,
    Driver? driver,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      fcmToken: fcmToken ?? this.fcmToken,
      avatar: avatar ?? this.avatar,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      store: store ?? this.store,
      driver: driver ?? this.driver,
    );
  }
}