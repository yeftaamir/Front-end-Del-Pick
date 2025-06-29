// ========================================
// Order Model - Enhanced Version with Backend-Aligned Delivery Fee
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

  // ✅ PERBAIKAN: Enhanced safe parsing methods
  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  static double? _parseNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String && value.isNotEmpty) {
      return double.tryParse(value);
    }
    return null;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        print('⚠️ Failed to parse date: $value - $e');
        return null;
      }
    }
    return null;
  }

  // ✅ PERBAIKAN: Safe parsing untuk customer
  static UserModel? _parseCustomer(dynamic customerData) {
    try {
      if (customerData == null) return null;

      if (customerData is Map<String, dynamic>) {
        return UserModel.fromJson(customerData);
      }

      if (customerData is String && customerData.isNotEmpty) {
        print('⚠️ Customer data is String, trying to parse: $customerData');
        final Map<String, dynamic> parsedCustomer = jsonDecode(customerData);
        return UserModel.fromJson(parsedCustomer);
      }

      return null;
    } catch (e) {
      print('❌ Error parsing customer data: $e');
      return null;
    }
  }

  // ✅ PERBAIKAN: Safe parsing untuk store
  static StoreModel? _parseStore(dynamic storeData) {
    try {
      if (storeData == null) return null;

      if (storeData is Map<String, dynamic>) {
        return StoreModel.fromJson(storeData);
      }

      if (storeData is String && storeData.isNotEmpty) {
        print('⚠️ Store data is String, trying to parse: $storeData');
        final Map<String, dynamic> parsedStore = jsonDecode(storeData);
        return StoreModel.fromJson(parsedStore);
      }

      return null;
    } catch (e) {
      print('❌ Error parsing store data: $e');
      return null;
    }
  }

  // ✅ PERBAIKAN: Safe parsing untuk driver
  static DriverModel? _parseDriver(dynamic driverData) {
    try {
      if (driverData == null) return null;

      if (driverData is Map<String, dynamic>) {
        return DriverModel.fromJson(driverData);
      }

      if (driverData is String && driverData.isNotEmpty) {
        print('⚠️ Driver data is String, trying to parse: $driverData');
        final Map<String, dynamic> parsedDriver = jsonDecode(driverData);
        return DriverModel.fromJson(parsedDriver);
      }

      return null;
    } catch (e) {
      print('❌ Error parsing driver data: $e');
      return null;
    }
  }

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    try {
      print('🔍 Parsing Order JSON: ${json.toString()}');

      return OrderModel(
        id: _parseInt(json['id']),
        customerId: _parseInt(json['customer_id']),
        storeId: _parseInt(json['store_id']),
        driverId:
            json['driver_id'] != null ? _parseInt(json['driver_id']) : null,
        orderStatus:
            OrderStatusExtension.fromString(json['order_status'] ?? 'pending'),
        deliveryStatus: DeliveryStatusExtension.fromString(
            json['delivery_status'] ?? 'pending'),
        totalAmount: _parseDouble(json['total_amount']),
        deliveryFee: _parseDouble(json['delivery_fee']),
        destinationLatitude: _parseNullableDouble(json['destination_latitude']),
        destinationLongitude:
            _parseNullableDouble(json['destination_longitude']),

        // ✅ PERBAIKAN: Enhanced date parsing
        estimatedPickupTime: _parseDateTime(json['estimated_pickup_time']),
        actualPickupTime: _parseDateTime(json['actual_pickup_time']),
        estimatedDeliveryTime: _parseDateTime(json['estimated_delivery_time']),
        actualDeliveryTime: _parseDateTime(json['actual_delivery_time']),

        // ✅ PERBAIKAN: Handle tracking_updates yang mungkin string JSON
        trackingUpdates: _parseTrackingUpdates(json['tracking_updates']),

        createdAt: _parseDateTime(json['created_at']) ?? DateTime.now(),
        updatedAt: _parseDateTime(json['updated_at']) ?? DateTime.now(),

        // ✅ PERBAIKAN: Safe relationship parsing
        customer: _parseCustomer(json['customer']),
        store: _parseStore(json['store']),
        driver: _parseDriver(json['driver']),
        items: _parseOrderItems(json),
      );
    } catch (e) {
      print('❌ Error parsing OrderModel: $e');
      print('❌ JSON data: $json');
      rethrow;
    }
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

  // ✅ PERBAIKAN: Helper method untuk parse tracking updates
  static List<Map<String, dynamic>>? _parseTrackingUpdates(dynamic value) {
    try {
      if (value == null) return null;

      if (value is String && value.isNotEmpty) {
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
    } catch (e) {
      print('❌ Error parsing tracking updates: $e');
      return [];
    }
  }

  // ✅ PERBAIKAN: Helper method untuk parse order items (support multiple structures)
  static List<OrderItemModel> _parseOrderItems(Map<String, dynamic> json) {
    try {
      List<dynamic>? itemsData;

      // Backend bisa return 'items' atau 'order_items'
      if (json['items'] != null) {
        itemsData = json['items'] as List?;
      } else if (json['order_items'] != null) {
        itemsData = json['order_items'] as List?;
      }

      if (itemsData == null || itemsData.isEmpty) return [];

      return itemsData
          .map((item) {
            try {
              if (item is Map<String, dynamic>) {
                final safeItem = Map<String, dynamic>.from(item);
                safeItem['price'] = _parseDouble(item['price']);
                safeItem['quantity'] = _parseInt(item['quantity']);
                return OrderItemModel.fromJson(safeItem);
              }
              return OrderItemModel.fromJson(item);
            } catch (e) {
              print('❌ Error parsing order item: $e');
              // Return a default item or skip this item
              return null;
            }
          })
          .where((item) => item != null)
          .cast<OrderItemModel>()
          .toList();
    } catch (e) {
      print('❌ Error parsing order items: $e');
      return [];
    }
  }

  // ✅ BACKEND-ALIGNED: Utility methods sesuai backend calculation
  double get subtotal => items.fold(0, (sum, item) => sum + item.totalPrice);

  // ✅ FIXED: Grand total sekarang totalAmount sudah include delivery fee dari backend
  double get grandTotal => totalAmount; // Backend sudah include delivery fee

  // ✅ NEW: Separate calculation for items only (excludes delivery fee)
  double get itemsTotal => totalAmount - deliveryFee;

  // ✅ BACKEND-ALIGNED: Delivery fee calculation info
  String get deliveryFeeCalculationInfo {
    if (destinationLatitude != null &&
        destinationLongitude != null &&
        store != null) {
      // Backend menggunakan euclideanDistance calculation
      // Jarak dalam degree, kemudian * 111 untuk convert ke km, kemudian * 2000 untuk biaya
      return 'Dihitung berdasarkan jarak dari toko ke destinasi';
    }
    return 'Biaya pengiriman flat rate';
  }

  // ✅ NEW: Destinasi information sesuai backend
  bool get isDeliveryToITDel {
    const itDelLat = 2.3834831864787818;
    const itDelLng = 99.14857915147614;

    if (destinationLatitude != null && destinationLongitude != null) {
      return (destinationLatitude! - itDelLat).abs() < 0.0001 &&
          (destinationLongitude! - itDelLng).abs() < 0.0001;
    }
    return false;
  }

  String get destinationName {
    if (isDeliveryToITDel) {
      return 'IT Del (Institut Teknologi Del)';
    } else if (destinationLatitude != null && destinationLongitude != null) {
      return 'Lat: ${destinationLatitude!.toStringAsFixed(6)}, Lng: ${destinationLongitude!.toStringAsFixed(6)}';
    }
    return 'Destinasi tidak tersedia';
  }

  // ✅ BACKEND-ALIGNED: Distance estimation dari delivery fee
  double get estimatedDistanceKm {
    if (deliveryFee > 0) {
      // Reverse calculation dari backend: distance_km ≈ delivery_fee / 2000
      return deliveryFee / 2000;
    }
    return 0.0;
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

  // ✅ FIXED: Format items total (totalAmount - deliveryFee)
  String formatItemsTotal() {
    return 'Rp ${itemsTotal.toStringAsFixed(0).replaceAllMapped(
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

  // ✅ TAMBAH: Helper methods untuk checking specific status combinations
  bool get isOnDelivery =>
      orderStatus == OrderStatus.onDelivery &&
      deliveryStatus == DeliveryStatus.onWay;

  bool get isDelivered =>
      orderStatus == OrderStatus.delivered &&
      deliveryStatus == DeliveryStatus.delivered;

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
        try {
          return DateTime.parse(timestamp);
        } catch (e) {
          print('⚠️ Error parsing timestamp: $timestamp');
          return null;
        }
      }
    }
    return null;
  }

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

  // ✅ BACKEND-ALIGNED: Driver earning calculation
  double get driverEarning {
    // Backend: Driver mendapat 100% dari delivery fee
    return deliveryFee;
  }

  String get formattedDriverEarning {
    return 'Rp ${driverEarning.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        )}';
  }

  // ✅ NEW: Payment breakdown for UI display
  Map<String, double> get paymentBreakdown {
    return {
      'items_total': itemsTotal,
      'delivery_fee': deliveryFee,
      'grand_total': grandTotal,
    };
  }

  Map<String, String> get formattedPaymentBreakdown {
    return {
      'items_total': formatItemsTotal(),
      'delivery_fee': formatDeliveryFee(),
      'grand_total': formatGrandTotal(),
    };
  }

  // ✅ NEW: Order summary untuk display
  String get orderSummary {
    return '$totalItems item(s) • ${formatGrandTotal()} • ${statusMessage}';
  }

  @override
  String toString() {
    return 'OrderModel(id: $id, orderStatus: ${orderStatus.value}, deliveryStatus: ${deliveryStatus.value})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OrderModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
