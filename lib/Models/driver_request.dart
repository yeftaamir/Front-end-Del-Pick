// ========================================
// 10. lib/models/review_models.dart
// ========================================

import 'customer.dart';
import 'driver.dart';
import 'order.dart';

class OrderReviewModel {
  final int id;
  final int orderId;
  final int customerId;
  final int rating;
  final String? comment;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Related models
  final OrderModel? order;
  final CustomerModel? customer;

  const OrderReviewModel({
    required this.id,
    required this.orderId,
    required this.customerId,
    required this.rating,
    required this.createdAt,
    required this.updatedAt,
    this.comment,
    this.order,
    this.customer,
  });

  factory OrderReviewModel.fromJson(Map<String, dynamic> json) {
    return OrderReviewModel(
      id: json['id'] ?? 0,
      orderId: json['order_id'] ?? 0,
      customerId: json['customer_id'] ?? 0,
      rating: json['rating'] ?? 5,
      comment: json['comment'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      order: json['order'] != null ? OrderModel.fromJson(json['order']) : null,
      customer: json['customer'] != null ? CustomerModel.fromJson(json['customer']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'customer_id': customerId,
      'rating': rating,
      'comment': comment,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (order != null) 'order': order!.toJson(),
      if (customer != null) 'customer': customer!.toJson(),
    };
  }

  OrderReviewModel copyWith({
    int? id,
    int? orderId,
    int? customerId,
    int? rating,
    String? comment,
    DateTime? createdAt,
    DateTime? updatedAt,
    OrderModel? order,
    CustomerModel? customer,
  }) {
    return OrderReviewModel(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      customerId: customerId ?? this.customerId,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      order: order ?? this.order,
      customer: customer ?? this.customer,
    );
  }

  // Utility methods
  bool get hasComment => comment != null && comment!.isNotEmpty;

  String get ratingDisplayText {
    switch (rating) {
      case 1:
        return 'Very Poor';
      case 2:
        return 'Poor';
      case 3:
        return 'Average';
      case 4:
        return 'Good';
      case 5:
        return 'Excellent';
      default:
        return 'Unknown';
    }
  }

  String get formattedDate {
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }
}

class DriverReviewModel {
  final int id;
  final int orderId;
  final int driverId;
  final int customerId;
  final int rating;
  final String? comment;
  final bool isAutoGenerated;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Related models
  final OrderModel? order;
  final DriverModel? driver;
  final CustomerModel? customer;

  const DriverReviewModel({
    required this.id,
    required this.orderId,
    required this.driverId,
    required this.customerId,
    required this.rating,
    required this.createdAt,
    required this.updatedAt,
    this.comment,
    this.isAutoGenerated = false,
    this.order,
    this.driver,
    this.customer,
  });

  factory DriverReviewModel.fromJson(Map<String, dynamic> json) {
    return DriverReviewModel(
      id: json['id'] ?? 0,
      orderId: json['order_id'] ?? 0,
      driverId: json['driver_id'] ?? 0,
      customerId: json['customer_id'] ?? 0,
      rating: json['rating'] ?? 5,
      comment: json['comment'],
      isAutoGenerated: json['is_auto_generated'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      order: json['order'] != null ? OrderModel.fromJson(json['order']) : null,
      driver: json['driver'] != null ? DriverModel.fromJson(json['driver']) : null,
      customer: json['customer'] != null ? CustomerModel.fromJson(json['customer']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'driver_id': driverId,
      'customer_id': customerId,
      'rating': rating,
      'comment': comment,
      'is_auto_generated': isAutoGenerated,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (order != null) 'order': order!.toJson(),
      if (driver != null) 'driver': driver!.toJson(),
      if (customer != null) 'customer': customer!.toJson(),
    };
  }

  DriverReviewModel copyWith({
    int? id,
    int? orderId,
    int? driverId,
    int? customerId,
    int? rating,
    String? comment,
    bool? isAutoGenerated,
    DateTime? createdAt,
    DateTime? updatedAt,
    OrderModel? order,
    DriverModel? driver,
    CustomerModel? customer,
  }) {
    return DriverReviewModel(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      driverId: driverId ?? this.driverId,
      customerId: customerId ?? this.customerId,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      isAutoGenerated: isAutoGenerated ?? this.isAutoGenerated,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      order: order ?? this.order,
      driver: driver ?? this.driver,
      customer: customer ?? this.customer,
    );
  }

  // Utility methods
  bool get hasComment => comment != null && comment!.isNotEmpty;

  String get ratingDisplayText {
    switch (rating) {
      case 1:
        return 'Very Poor';
      case 2:
        return 'Poor';
      case 3:
        return 'Average';
      case 4:
        return 'Good';
      case 5:
        return 'Excellent';
      default:
        return 'Unknown';
    }
  }

  String get formattedDate {
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }

  String get reviewTypeDisplayText => isAutoGenerated ? 'Auto Generated' : 'Customer Review';
}