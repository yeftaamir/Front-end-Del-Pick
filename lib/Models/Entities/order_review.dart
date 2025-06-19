// lib/models/entities/order_review.dart
import 'package:del_pick/Models/Entities/user.dart';

import 'order.dart';

class OrderReview {
  final int id;
  final int orderId;
  final int customerId;
  final int rating;
  final String? comment;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Relations
  final Order? order;
  final User? customer;

  OrderReview({
    required this.id,
    required this.orderId,
    required this.customerId,
    required this.rating,
    this.comment,
    required this.createdAt,
    required this.updatedAt,
    this.order,
    this.customer,
  });

  factory OrderReview.fromJson(Map<String, dynamic> json) {
    return OrderReview(
      id: json['id'] as int,
      orderId: json['order_id'] as int,
      customerId: json['customer_id'] as int,
      rating: json['rating'] as int,
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      order: json['order'] != null ? Order.fromJson(json['order']) : null,
      customer: json['customer'] != null ? User.fromJson(json['customer']) : null,
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
}