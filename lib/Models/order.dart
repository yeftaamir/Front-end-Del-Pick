// ========================================
// 8. lib/models/order_model.dart
// ========================================

import 'package:del_pick/Models/store.dart';

import 'customer.dart';
import 'driver.dart';
import 'order_enum.dart';
import 'order_item.dart';

class OrderModel {
  final int id;
  final int customerId;
  final int storeId;
  final int? driverId;
  final OrderStatus orderStatus;
  final DeliveryStatus deliveryStatus;
  final double totalAmount;
  final double deliveryFee;
  final String? deliveryAddress;
  final double? customerLatitude;
  final double? customerLongitude;
  final DateTime? estimatedPickupTime;
  final DateTime? actualPickupTime;
  final DateTime? estimatedDeliveryTime;
  final DateTime? actualDeliveryTime;
  final List<Map<String, dynamic>>? trackingUpdates;
  final String? notes;
  final PaymentMethod paymentMethod;
  final PaymentStatus paymentStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Related models
  final CustomerModel? customer;
  final StoreModel? store;
  final DriverModel? driver;
  final List<OrderItemModel> items;

  const OrderModel({
    required this.id,
    required this.customerId,
    required this.storeId,
    required this.totalAmount,
    required this.createdAt,
    required this.updatedAt,
    this.driverId,
    this.orderStatus = OrderStatus.pending,
    this.deliveryStatus = DeliveryStatus.pending,
    this.deliveryFee = 0.0,
    this.deliveryAddress,
    this.customerLatitude,
    this.customerLongitude,
    this.estimatedPickupTime,
    this.actualPickupTime,
    this.estimatedDeliveryTime,
    this.actualDeliveryTime,
    this.trackingUpdates,
    this.notes,
    this.paymentMethod = PaymentMethod.cash,
    this.paymentStatus = PaymentStatus.pending,
    this.customer,
    this.store,
    this.driver,
    this.items = const [],
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] ?? 0,
      customerId: json['customer_id'] ?? 0,
      storeId: json['store_id'] ?? 0,
      driverId: json['driver_id'],
      orderStatus: OrderStatusExtension.fromString(json['order_status'] ?? 'pending'),
      deliveryStatus: DeliveryStatusExtension.fromString(json['delivery_status'] ?? 'pending'),
      totalAmount: (json['total_amount'] ?? 0).toDouble(),
      deliveryFee: (json['delivery_fee'] ?? 0).toDouble(),
      deliveryAddress: json['delivery_address'],
      customerLatitude: json['customer_latitude']?.toDouble(),
      customerLongitude: json['customer_longitude']?.toDouble(),
      estimatedPickupTime: json['estimated_pickup_time'] != null
          ? DateTime.parse(json['estimated_pickup_time'])
          : null,
      actualPickupTime: json['actual_pickup_time'] != null
          ? DateTime.parse(json['actual_pickup_time'])
          : null,
      estimatedDeliveryTime: json['estimated_delivery_time'] != null
          ? DateTime.parse(json['estimated_delivery_time'])
          : null,
      actualDeliveryTime: json['actual_delivery_time'] != null
          ? DateTime.parse(json['actual_delivery_time'])
          : null,
      trackingUpdates: json['tracking_updates'] != null
          ? List<Map<String, dynamic>>.from(json['tracking_updates'])
          : null,
      notes: json['notes'],
      paymentMethod: PaymentMethod.cash, // Default as per requirements
      paymentStatus: PaymentStatus.pending, // Default
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      customer: json['customer'] != null ? CustomerModel.fromJson(json['customer']) : null,
      store: json['store'] != null ? StoreModel.fromJson(json['store']) : null,
      driver: json['driver'] != null ? DriverModel.fromJson(json['driver']) : null,
      items: json['items'] != null
          ? (json['items'] as List).map((item) => OrderItemModel.fromJson(item)).toList()
          : [],
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
      'delivery_address': deliveryAddress,
      'customer_latitude': customerLatitude,
      'customer_longitude': customerLongitude,
      if (estimatedPickupTime != null) 'estimated_pickup_time': estimatedPickupTime!.toIso8601String(),
      if (actualPickupTime != null) 'actual_pickup_time': actualPickupTime!.toIso8601String(),
      if (estimatedDeliveryTime != null) 'estimated_delivery_time': estimatedDeliveryTime!.toIso8601String(),
      if (actualDeliveryTime != null) 'actual_delivery_time': actualDeliveryTime!.toIso8601String(),
      'tracking_updates': trackingUpdates,
      'notes': notes,
      'payment_method': paymentMethod.name,
      'payment_status': paymentStatus.name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (customer != null) 'customer': customer!.toJson(),
      if (store != null) 'store': store!.toJson(),
      if (driver != null) 'driver': driver!.toJson(),
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  OrderModel copyWith({
    int? id,
    int? customerId,
    int? storeId,
    int? driverId,
    OrderStatus? orderStatus,
    DeliveryStatus? deliveryStatus,
    double? totalAmount,
    double? deliveryFee,
    String? deliveryAddress,
    double? customerLatitude,
    double? customerLongitude,
    DateTime? estimatedPickupTime,
    DateTime? actualPickupTime,
    DateTime? estimatedDeliveryTime,
    DateTime? actualDeliveryTime,
    List<Map<String, dynamic>>? trackingUpdates,
    String? notes,
    PaymentMethod? paymentMethod,
    PaymentStatus? paymentStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
    CustomerModel? customer,
    StoreModel? store,
    DriverModel? driver,
    List<OrderItemModel>? items,
  }) {
    return OrderModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      storeId: storeId ?? this.storeId,
      driverId: driverId ?? this.driverId,
      orderStatus: orderStatus ?? this.orderStatus,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      totalAmount: totalAmount ?? this.totalAmount,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      customerLatitude: customerLatitude ?? this.customerLatitude,
      customerLongitude: customerLongitude ?? this.customerLongitude,
      estimatedPickupTime: estimatedPickupTime ?? this.estimatedPickupTime,
      actualPickupTime: actualPickupTime ?? this.actualPickupTime,
      estimatedDeliveryTime: estimatedDeliveryTime ?? this.estimatedDeliveryTime,
      actualDeliveryTime: actualDeliveryTime ?? this.actualDeliveryTime,
      trackingUpdates: trackingUpdates ?? this.trackingUpdates,
      notes: notes ?? this.notes,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      customer: customer ?? this.customer,
      store: store ?? this.store,
      driver: driver ?? this.driver,
      items: items ?? this.items,
    );
  }

  // Utility methods
  double get subtotal => items.fold(0, (sum, item) => sum + item.totalPrice);
  double get grandTotal => subtotal + deliveryFee;

  String formatTotalAmount() {
    return 'Rp ${totalAmount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
    )}';
  }

  String formatDeliveryFee() {
    return 'Rp ${deliveryFee.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
    )}';
  }

  String formatSubtotal() {
    return 'Rp ${subtotal.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
    )}';
  }

  String get formattedDate {
    return '${createdAt.day}/${createdAt.month}/${createdAt.year} ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}';
  }

  String get statusMessage {
    switch (orderStatus) {
      case OrderStatus.pending:
        return 'Waiting for store confirmation';
      case OrderStatus.confirmed:
        return 'Order confirmed by store';
      case OrderStatus.preparing:
        return 'Order is being prepared';
      case OrderStatus.readyForPickup:
        return 'Order ready for pickup';
      case OrderStatus.onDelivery:
        return 'Order is on the way';
      case OrderStatus.delivered:
        return 'Order delivered successfully';
      case OrderStatus.cancelled:
        return 'Order cancelled';
      case OrderStatus.rejected:
        return 'Order rejected by store';
    }
  }

  bool get canBeCancelled =>
      orderStatus == OrderStatus.pending ||
          orderStatus == OrderStatus.confirmed;

  bool get isCompleted => orderStatus.isCompleted;

  bool get hasDriver => driverId != null && driver != null;

  int get totalItems => items.fold(0, (sum, item) => sum + item.quantity);
}
