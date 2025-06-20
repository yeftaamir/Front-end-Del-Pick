import 'order.dart';
import 'user.dart';

class OrderReview {
  final int id;
  final int orderId;
  final int customerId;
  final int rating; // 1-5
  final String? comment;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Relationship data
  final Order? order;
  final User? customer;

  OrderReview({
    required this.id,
    required this.orderId,
    required this.customerId,
    required this.rating,
    this.comment,
    this.createdAt,
    this.updatedAt,
    this.order,
    this.customer,
  });

  factory OrderReview.fromJson(Map<String, dynamic> json) {
    return OrderReview(
      id: json['id'] ?? 0,
      orderId: json['order_id'] ?? 0,
      customerId: json['customer_id'] ?? 0,
      rating: json['rating'] ?? 1,
      comment: json['comment'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
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
      if (comment != null) 'comment': comment,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      if (order != null) 'order': order!.toJson(),
      if (customer != null) 'customer': customer!.toJson(),
    };
  }

  OrderReview copyWith({
    int? id,
    int? orderId,
    int? customerId,
    int? rating,
    String? comment,
    DateTime? createdAt,
    DateTime? updatedAt,
    Order? order,
    User? customer,
  }) {
    return OrderReview(
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
}