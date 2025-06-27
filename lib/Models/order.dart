// ========================================
// Order Model - Fixed Version
// ========================================

import 'dart:convert'; // ✅ TAMBAH: Import untuk jsonDecode
import 'package:del_pick/Models/driver.dart';
import 'package:del_pick/Models/order_enum.dart';
import 'package:del_pick/Models/order_item.dart';
import 'package:del_pick/Models/store.dart';
import 'package:del_pick/Models/user.dart';

class OrderModel {
  final int id;
  final int customerId;
  final int storeId;
  final int? driverId;
  final OrderStatus orderStatus;
  final DeliveryStatus deliveryStatus;
  final double totalAmount;
  final double deliveryFee;
  final double? destinationLatitude;
  final double? destinationLongitude;
  final DateTime? estimatedPickupTime;
  final DateTime? actualPickupTime;
  final DateTime? estimatedDeliveryTime;
  final DateTime? actualDeliveryTime;
  final List<Map<String, dynamic>>? trackingUpdates;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Related models
  final UserModel? customer;
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
    this.destinationLatitude,
    this.destinationLongitude,
    this.estimatedPickupTime,
    this.actualPickupTime,
    this.estimatedDeliveryTime,
    this.actualDeliveryTime,
    this.trackingUpdates,
    this.customer,
    this.store,
    this.driver,
    this.items = const [],
  });

  // Safe parsing untuk numeric values
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  // Safe parsing untuk nullable double values
  static double? _parseNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] ?? 0,
      customerId: json['customer_id'] ?? 0,
      storeId: json['store_id'] ?? 0,
      driverId: json['driver_id'],
      orderStatus:
          OrderStatusExtension.fromString(json['order_status'] ?? 'pending'),
      deliveryStatus: DeliveryStatusExtension.fromString(
          json['delivery_status'] ?? 'pending'),
      totalAmount: _parseDouble(json['total_amount']),
      deliveryFee: _parseDouble(json['delivery_fee']),
      destinationLatitude: _parseNullableDouble(json['destination_latitude']),
      destinationLongitude: _parseNullableDouble(json['destination_longitude']),

      // ✅ PERBAIKAN: Enhanced date parsing
      estimatedPickupTime: _parseDateTime(json['estimated_pickup_time']),
      actualPickupTime: _parseDateTime(json['actual_pickup_time']),
      estimatedDeliveryTime: _parseDateTime(json['estimated_delivery_time']),
      actualDeliveryTime: _parseDateTime(json['actual_delivery_time']),

      // ✅ PERBAIKAN: Handle tracking_updates yang mungkin string JSON
      trackingUpdates: _parseTrackingUpdates(json['tracking_updates']),

      createdAt: _parseDateTime(json['created_at']) ?? DateTime.now(),
      updatedAt: _parseDateTime(json['updated_at']) ?? DateTime.now(),

      // ✅ Existing relationship parsing...
      customer: json['customer'] != null
          ? UserModel.fromJson(json['customer'])
          : null,
      store: json['store'] != null ? StoreModel.fromJson(json['store']) : null,
      driver:
          json['driver'] != null ? DriverModel.fromJson(json['driver']) : null,
      items: _parseOrderItems(json),
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
      'destination_latitude': destinationLatitude,
      'destination_longitude': destinationLongitude,
      if (estimatedPickupTime != null)
        'estimated_pickup_time': estimatedPickupTime!.toIso8601String(),
      if (actualPickupTime != null)
        'actual_pickup_time': actualPickupTime!.toIso8601String(),
      if (estimatedDeliveryTime != null)
        'estimated_delivery_time': estimatedDeliveryTime!.toIso8601String(),
      if (actualDeliveryTime != null)
        'actual_delivery_time': actualDeliveryTime!.toIso8601String(),
      'tracking_updates': trackingUpdates,
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
    double? destinationLatitude,
    double? destinationLongitude,
    DateTime? estimatedPickupTime,
    DateTime? actualPickupTime,
    DateTime? estimatedDeliveryTime,
    DateTime? actualDeliveryTime,
    List<Map<String, dynamic>>? trackingUpdates,
    DateTime? createdAt,
    DateTime? updatedAt,
    UserModel? customer,
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
      destinationLatitude: destinationLatitude ?? this.destinationLatitude,
      destinationLongitude: destinationLongitude ?? this.destinationLongitude,
      estimatedPickupTime: estimatedPickupTime ?? this.estimatedPickupTime,
      actualPickupTime: actualPickupTime ?? this.actualPickupTime,
      estimatedDeliveryTime:
          estimatedDeliveryTime ?? this.estimatedDeliveryTime,
      actualDeliveryTime: actualDeliveryTime ?? this.actualDeliveryTime,
      trackingUpdates: trackingUpdates ?? this.trackingUpdates,
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
  double get grandTotal => totalAmount + deliveryFee;

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        print('⚠️ Failed to parse date: $value');
        return null;
      }
    }
    return null;
  }

  // ✅ PERBAIKAN: Helper method untuk parse tracking updates
  static List<Map<String, dynamic>>? _parseTrackingUpdates(dynamic value) {
    if (value == null) return null;

    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return List<Map<String, dynamic>>.from(decoded);
        }
      } catch (e) {
        print('⚠️ Failed to parse tracking_updates JSON: $e');
        return [];
      }
    }

    if (value is List) {
      return List<Map<String, dynamic>>.from(value);
    }

    return [];
  }

  // ✅ PERBAIKAN: Helper method untuk parse order items (support multiple structures)
  static List<OrderItemModel> _parseOrderItems(Map<String, dynamic> json) {
    List<dynamic>? itemsData;

    // Backend bisa return 'items' atau 'order_items'
    if (json['items'] != null) {
      itemsData = json['items'] as List;
    } else if (json['order_items'] != null) {
      itemsData = json['order_items'] as List;
    }

    if (itemsData == null) return [];

    return itemsData.map((item) {
      if (item is Map<String, dynamic>) {
        final safeItem = Map<String, dynamic>.from(item);
        safeItem['price'] = _parseDouble(item['price']);
        return OrderItemModel.fromJson(safeItem);
      }
      return OrderItemModel.fromJson(item);
    }).toList();
  }

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

  String formatGrandTotal() {
    return 'Rp ${grandTotal.toStringAsFixed(0).replaceAllMapped(
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
        return 'Menunggu konfirmasi toko';
      case OrderStatus.confirmed:
        return 'Pesanan dikonfirmasi toko';
      case OrderStatus.preparing:
        return 'Pesanan sedang disiapkan';
      case OrderStatus.readyForPickup:
        return 'Pesanan siap untuk diambil';
      case OrderStatus.onDelivery:
        return 'Pesanan sedang diantar';
      case OrderStatus.delivered:
        return 'Pesanan berhasil diantar';
      case OrderStatus.cancelled:
        return 'Pesanan dibatalkan';
      case OrderStatus.rejected:
        return 'Pesanan ditolak toko';
    }
  }

  bool get canBeCancelled => orderStatus.canBeCancelled;
  bool get isCompleted => orderStatus.isCompleted;
  bool get hasDriver => driverId != null && driver != null;
  int get totalItems => items.fold(0, (sum, item) => sum + item.quantity);

  // Helper methods untuk tracking
  String? get currentLocationDescription {
    if (trackingUpdates?.isNotEmpty == true) {
      final lastUpdate = trackingUpdates!.last;
      return lastUpdate['message'] as String?;
    }
    return null;
  }

  DateTime? get lastUpdateTime {
    if (trackingUpdates?.isNotEmpty == true) {
      final lastUpdate = trackingUpdates!.last;
      final timestamp = lastUpdate['timestamp'];
      if (timestamp != null) {
        return DateTime.parse(timestamp);
      }
    }
    return null;
  }

  // Method untuk mendapatkan progress order dalam bentuk persentase
  double get orderProgress {
    switch (orderStatus) {
      case OrderStatus.pending:
        return 0.1;
      case OrderStatus.confirmed:
        return 0.25;
      case OrderStatus.preparing:
        return 0.5;
      case OrderStatus.readyForPickup:
        return 0.75;
      case OrderStatus.onDelivery:
        return 0.9;
      case OrderStatus.delivered:
        return 1.0;
      case OrderStatus.cancelled:
      case OrderStatus.rejected:
        return 0.0;
    }
  }
}
