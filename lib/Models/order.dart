import 'order_item.dart';
import 'store.dart';
import 'driver.dart';
import 'user.dart';
import 'order_enum.dart';

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
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Relationship data
  final List<OrderItem>? items;
  final Store? store;
  final User? customer;
  final Driver? driver;

  Order({
    required this.id,
    required this.customerId,
    required this.storeId,
    this.driverId,
    this.orderStatus = OrderStatus.pending,
    this.deliveryStatus = DeliveryStatus.pending,
    required this.totalAmount,
    this.deliveryFee = 0.0,
    this.estimatedPickupTime,
    this.actualPickupTime,
    this.estimatedDeliveryTime,
    this.actualDeliveryTime,
    this.trackingUpdates,
    this.createdAt,
    this.updatedAt,
    this.items,
    this.store,
    this.customer,
    this.driver,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    OrderStatus orderStatus = OrderStatus.pending;
    if (json['order_status'] != null) {
      orderStatus = OrderStatus.fromString(json['order_status']);
    }

    DeliveryStatus deliveryStatus = DeliveryStatus.pending;
    if (json['delivery_status'] != null) {
      deliveryStatus = DeliveryStatus.fromString(json['delivery_status']);
    }

    return Order(
      id: json['id'] ?? 0,
      customerId: json['customer_id'] ?? 0,
      storeId: json['store_id'] ?? 0,
      driverId: json['driver_id'],
      orderStatus: orderStatus,
      deliveryStatus: deliveryStatus,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble() ?? 0.0,
      estimatedPickupTime: json['estimated_pickup_time'] != null ? DateTime.parse(json['estimated_pickup_time']) : null,
      actualPickupTime: json['actual_pickup_time'] != null ? DateTime.parse(json['actual_pickup_time']) : null,
      estimatedDeliveryTime: json['estimated_delivery_time'] != null ? DateTime.parse(json['estimated_delivery_time']) : null,
      actualDeliveryTime: json['actual_delivery_time'] != null ? DateTime.parse(json['actual_delivery_time']) : null,
      trackingUpdates: json['tracking_updates'] != null ? List<Map<String, dynamic>>.from(json['tracking_updates']) : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      items: json['items'] != null ? (json['items'] as List).map((item) => OrderItem.fromJson(item)).toList() : null,
      store: json['store'] != null ? Store.fromJson(json['store']) : null,
      customer: json['customer'] != null ? User.fromJson(json['customer']) : null,
      driver: json['driver'] != null ? Driver.fromJson(json['driver']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_id': customerId,
      'store_id': storeId,
      if (driverId != null) 'driver_id': driverId,
      'order_status': orderStatus.toString().split('.').last,
      'delivery_status': deliveryStatus.toString().split('.').last,
      'total_amount': totalAmount,
      'delivery_fee': deliveryFee,
      if (estimatedPickupTime != null) 'estimated_pickup_time': estimatedPickupTime!.toIso8601String(),
      if (actualPickupTime != null) 'actual_pickup_time': actualPickupTime!.toIso8601String(),
      if (estimatedDeliveryTime != null) 'estimated_delivery_time': estimatedDeliveryTime!.toIso8601String(),
      if (actualDeliveryTime != null) 'actual_delivery_time': actualDeliveryTime!.toIso8601String(),
      if (trackingUpdates != null) 'tracking_updates': trackingUpdates,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      if (items != null) 'items': items!.map((item) => item.toJson()).toList(),
      if (store != null) 'store': store!.toJson(),
      if (customer != null) 'customer': customer!.toJson(),
      if (driver != null) 'driver': driver!.toJson(),
    };
  }

  Order copyWith({
    int? id,
    int? customerId,
    int? storeId,
    int? driverId,
    OrderStatus? orderStatus,
    DeliveryStatus? deliveryStatus,
    double? totalAmount,
    double? deliveryFee,
    DateTime? estimatedPickupTime,
    DateTime? actualPickupTime,
    DateTime? estimatedDeliveryTime,
    DateTime? actualDeliveryTime,
    List<Map<String, dynamic>>? trackingUpdates,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<OrderItem>? items,
    Store? store,
    User? customer,
    Driver? driver,
  }) {
    return Order(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      storeId: storeId ?? this.storeId,
      driverId: driverId ?? this.driverId,
      orderStatus: orderStatus ?? this.orderStatus,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      totalAmount: totalAmount ?? this.totalAmount,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      estimatedPickupTime: estimatedPickupTime ?? this.estimatedPickupTime,
      actualPickupTime: actualPickupTime ?? this.actualPickupTime,
      estimatedDeliveryTime: estimatedDeliveryTime ?? this.estimatedDeliveryTime,
      actualDeliveryTime: actualDeliveryTime ?? this.actualDeliveryTime,
      trackingUpdates: trackingUpdates ?? this.trackingUpdates,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      items: items ?? this.items,
      store: store ?? this.store,
      customer: customer ?? this.customer,
      driver: driver ?? this.driver,
    );
  }

  // Convenience methods
  String formatTotalAmount() {
    return 'Rp${totalAmount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  String formatDeliveryFee() {
    return 'Rp${deliveryFee.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  String get formattedDate {
    if (createdAt == null) return '';
    return '${createdAt!.day}/${createdAt!.month}/${createdAt!.year} ${createdAt!.hour}:${createdAt!.minute.toString().padLeft(2, '0')}';
  }

  String get statusMessage {
    switch (orderStatus) {
      case OrderStatus.pending:
        return 'Menunggu konfirmasi pesanan';
      case OrderStatus.confirmed:
        return 'Pesanan telah dikonfirmasi';
      case OrderStatus.preparing:
        return 'Pesanan sedang dipersiapkan';
      case OrderStatus.ready_for_pickup:
        return 'Pesanan siap diambil';
      case OrderStatus.on_delivery:
        return 'Pesanan sedang dalam pengiriman';
      case OrderStatus.delivered:
        return 'Pesanan telah diterima';
      case OrderStatus.cancelled:
        return 'Pesanan dibatalkan';
    }
  }
}