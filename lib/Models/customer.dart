// ========================================
// 3. lib/models/customer_model.dart
// ========================================

import 'package:del_pick/Models/user.dart';

class CustomerModel {
  final UserModel user;
  final int totalOrders;
  final double totalSpent;
  final bool isEmailVerified;
  final DateTime? lastOrderDate;

  const CustomerModel({
    required this.user,
    this.totalOrders = 0,
    this.totalSpent = 0.0,
    this.isEmailVerified = false,
    this.lastOrderDate,
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      user: UserModel.fromJson(json),
      totalOrders: json['total_orders'] ?? 0,
      totalSpent: (json['total_spent'] ?? 0).toDouble(),
      isEmailVerified: json['is_email_verified'] ?? false,
      lastOrderDate: json['last_order_date'] != null
          ? DateTime.parse(json['last_order_date'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      ...user.toJson(),
      'total_orders': totalOrders,
      'total_spent': totalSpent,
      'is_email_verified': isEmailVerified,
      if (lastOrderDate != null) 'last_order_date': lastOrderDate!.toIso8601String(),
    };
  }

  CustomerModel copyWith({
    UserModel? user,
    int? totalOrders,
    double? totalSpent,
    bool? isEmailVerified,
    DateTime? lastOrderDate,
  }) {
    return CustomerModel(
      user: user ?? this.user,
      totalOrders: totalOrders ?? this.totalOrders,
      totalSpent: totalSpent ?? this.totalSpent,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      lastOrderDate: lastOrderDate ?? this.lastOrderDate,
    );
  }

  // Convenience getters
  int get id => user.id;
  String get name => user.name;
  String get email => user.email;
  String get phone => user.phone;
  String? get avatar => user.avatar;
  String? get fcmToken => user.fcmToken;
  DateTime? get createdAt => user.createdAt;
  DateTime? get updatedAt => user.updatedAt;

  // Utility methods
  String get customerLevel {
    if (totalOrders >= 50) return 'VIP';
    if (totalOrders >= 20) return 'Gold';
    if (totalOrders >= 10) return 'Silver';
    return 'Bronze';
  }

  String formatTotalSpent() {
    return 'Rp ${totalSpent.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
    )}';
  }
}