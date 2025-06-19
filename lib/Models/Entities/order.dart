// lib/models/entities/order.dart
import 'package:del_pick/Models/Entities/store.dart';
import 'package:del_pick/Models/Entities/user.dart';

import '../Enums/delivery_status.dart';
import '../Enums/order_status.dart';
import 'driver.dart';
import 'driver_review.dart';
import 'order_item.dart';
import 'order_review.dart';

class Order {
  final int id;
  final int customerId;
  final int storeId;
  final int? driverId;
  final OrderStatus orderStatus;
  final DeliveryStatus deliveryStatus;
  final double totalAmount;
  final double deliveryFee;
  final DateTime? estimatedPickupTime;
  final DateTime? actualPickupTime;
  final DateTime? estimatedDeliveryTime;
  final DateTime? actualDeliveryTime;
  final List<Map<String, dynamic>>? trackingUpdates;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Relations
  final User? customer;
  final Store? store;
  final Driver? driver;
  final List<OrderItem>? items;
  final List<OrderReview>? orderReviews;
  final List<DriverReview>? driverReviews;

  Order({
    required this.id,
    required this.customerId,
    required this.storeId,
    this.driverId,
    required this.orderStatus,
    required this.deliveryStatus,
    required this.totalAmount,
    required this.deliveryFee,
    this.estimatedPickupTime,
    this.actualPickupTime,
    this.estimatedDeliveryTime,
    this.actualDeliveryTime,
    this.trackingUpdates,
    required this.createdAt,
    required this.updatedAt,
    this.customer,
    this.store,
    this.driver,
    this.items,
    this.orderReviews,
    this.driverReviews,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as int,
      customerId: json['customer_id'] as int,
      storeId: json['store_id'] as int,
      driverId: json['driver_id'] as int?,
      orderStatus: OrderStatus.fromString(json['order_status'] as String),
      deliveryStatus: DeliveryStatus.fromString(json['delivery_status'] as String),
      totalAmount: double.parse(json['total_amount'].toString()),
      deliveryFee: double.parse(json['delivery_fee'].toString()),
      estimatedPickupTime: json['estimated_pickup_time'] != null
          ? DateTime.parse(json['estimated_pickup_time'] as String)
          : null,
      actualPickupTime: json['actual_pickup_time'] != null
          ? DateTime.parse(json['actual_pickup_time'] as String)
          : null,
      estimatedDeliveryTime: json['estimated_delivery_time'] != null
          ? DateTime.parse(json['estimated_delivery_time'] as String)
          : null,
      actualDeliveryTime: json['actual_delivery_time'] != null
          ? DateTime.parse(json['actual_delivery_time'] as String)
          : null,
      trackingUpdates: json['tracking_updates'] != null
          ? List<Map<String, dynamic>>.from(json['tracking_updates'])
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      customer: json['customer'] != null ? User.fromJson(json['customer']) : null,
      store: json['store'] != null ? Store.fromJson(json['store']) : null,
      driver: json['driver'] != null ? Driver.fromJson(json['driver']) : null,
      items: json['items'] != null
          ? (json['items'] as List)
          .map((item) => OrderItem.fromJson(item))
          .toList()
          : null,
      orderReviews: json['orderReviews'] != null
          ? (json['orderReviews'] as List)
          .map((review) => OrderReview.fromJson(review))
          .toList()
          : null,
      driverReviews: json['driverReviews'] != null
          ? (json['driverReviews'] as List)
          .map((review) => DriverReview.fromJson(review))
          .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_id': customerId,
      'store_id': storeId,
      'driver_id': driverId,
      'order_status': orderStatus.value,
      'delivery_status': deliveryStatus.value,
      'total_amount': totalAmount,
      'delivery_fee': deliveryFee,
      'estimated_pickup_time': estimatedPickupTime?.toIso8601String(),
      'actual_pickup_time': actualPickupTime?.toIso8601String(),
      'estimated_delivery_time': estimatedDeliveryTime?.toIso8601String(),
      'actual_delivery_time': actualDeliveryTime?.toIso8601String(),
      'tracking_updates': trackingUpdates,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (customer != null) 'customer': customer!.toJson(),
      if (store != null) 'store': store!.toJson(),
      if (driver != null) 'driver': driver!.toJson(),
      if (items != null) 'items': items!.map((item) => item.toJson()).toList(),
      if (orderReviews != null)
        'orderReviews': orderReviews!.map((review) => review.toJson()).toList(),
      if (driverReviews != null)
        'driverReviews': driverReviews!.map((review) => review.toJson()).toList(),
    };
  }
}