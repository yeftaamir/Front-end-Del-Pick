import 'item_model.dart';
import 'store.dart';
import 'tracking.dart';
import 'order_enum.dart';

class Order {
  final String id;
  final String? code; // Added to match BE
  final List<Item> items;
  final StoreModel store;
  final String deliveryAddress;
  final double subtotal;
  final double serviceCharge;
  final double total;
  final OrderStatus status; // Order status from enum
  final DeliveryStatus? deliveryStatus; // Added to match BE
  final DateTime orderDate;
  final PaymentMethod paymentMethod;
  final PaymentStatus paymentStatus;
  final Tracking? tracking;
  final String? notes;
  final bool hasGivenRating;
  final int? customerId; // Added to match BE
  final int? driverId; // Added to match BE
  final int? storeId; // Added to match BE

  Order({
    required this.id,
    this.code,
    required this.items,
    required this.store,
    required this.deliveryAddress,
    required this.subtotal,
    required this.serviceCharge,
    required this.total,
    this.status = OrderStatus.pending,
    this.deliveryStatus,
    required this.orderDate,
    this.paymentMethod = PaymentMethod.cash,
    this.paymentStatus = PaymentStatus.pending,
    this.tracking,
    this.notes,
    this.hasGivenRating = false,
    this.customerId,
    this.driverId,
    this.storeId,
  });

  // Calculate subtotal from items
  static double calculateSubtotal(List<Item> items) {
    return items.fold(0, (sum, item) => sum + (item.price * item.quantity));
  }

  // Calculate total from subtotal and service charge
  static double calculateTotal(double subtotal, double serviceCharge) {
    return subtotal + serviceCharge;
  }

  // Add formatting methods for price display
  String formatSubtotal() {
    return 'Rp${subtotal.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  String formatDeliveryFee() {
    return 'Rp${serviceCharge.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  String formatTax() {
    // Assuming tax is 0 or included in the service charge as per requirements
    return 'Rp0';
  }

  String formatTotal() {
    return 'Rp${total.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  // Create a copy of this order with updated values
  Order copyWith({
    String? id,
    String? code,
    List<Item>? items,
    StoreModel? store,
    String? deliveryAddress,
    double? subtotal,
    double? serviceCharge,
    double? total,
    OrderStatus? status,
    DeliveryStatus? deliveryStatus,
    DateTime? orderDate,
    PaymentMethod? paymentMethod,
    PaymentStatus? paymentStatus,
    Tracking? tracking,
    String? notes,
    bool? hasGivenRating,
    int? customerId,
    int? driverId,
    int? storeId,
  }) {
    return Order(
      id: id ?? this.id,
      code: code ?? this.code,
      items: items ?? this.items,
      store: store ?? this.store,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      subtotal: subtotal ?? this.subtotal,
      serviceCharge: serviceCharge ?? this.serviceCharge,
      total: total ?? this.total,
      status: status ?? this.status,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      orderDate: orderDate ?? this.orderDate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      tracking: tracking ?? this.tracking,
      notes: notes ?? this.notes,
      hasGivenRating: hasGivenRating ?? this.hasGivenRating,
      customerId: customerId ?? this.customerId,
      driverId: driverId ?? this.driverId,
      storeId: storeId ?? this.storeId,
    );
  }

  factory Order.fromCart({
    required String id,
    String? code,
    required List<Item> cartItems,
    required StoreModel store,
    required String deliveryAddress,
    required double serviceCharge,
    int? customerId,
  }) {
    final subtotal = calculateSubtotal(cartItems);
    final total = calculateTotal(subtotal, serviceCharge);

    return Order(
      id: id,
      code: code ?? 'ORD-${DateTime
          .now()
          .millisecondsSinceEpoch
          .toString()
          .substring(7)}',
      items: cartItems,
      store: store,
      deliveryAddress: deliveryAddress,
      subtotal: subtotal,
      serviceCharge: serviceCharge,
      total: total,
      orderDate: DateTime.now(),
      hasGivenRating: false,
      customerId: customerId,
      storeId: store.id,
    );
  }

  // Convert from JSON
  factory Order.fromJson(Map<String, dynamic> json) {
    // Handle order status based on BE format
    OrderStatus orderStatus;
    if (json['order_status'] != null) {
      orderStatus = OrderStatus.fromString(json['order_status']);
    } else if (json['status'] != null) {
      orderStatus = OrderStatus.fromString(json['status']);
    } else {
      orderStatus = OrderStatus.pending;
    }

    // Handle delivery status if it exists
    DeliveryStatus? deliveryStatus;
    if (json['delivery_status'] != null) {
      deliveryStatus = DeliveryStatus.fromString(json['delivery_status']);
    }

    return Order(
      id: json['id']?.toString() ?? '',
      code: json['code'],
      items: json['items'] != null
          ? (json['items'] as List).map((item) => Item.fromJson(item)).toList()
          : [],
      store: json['store'] != null
          ? StoreModel.fromJson(json['store'])
          : StoreModel(name: '', address: '', openHours: ''),
      deliveryAddress: json['deliveryAddress'] ?? '',
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      serviceCharge: (json['serviceCharge'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      status: orderStatus,
      deliveryStatus: deliveryStatus,
      orderDate: json['orderDate'] != null
          ? DateTime.parse(json['orderDate'])
          : DateTime.now(),
      paymentMethod: PaymentMethod.cash,
      // Default as per requirement
      paymentStatus: PaymentStatus.pending,
      // Default
      tracking: json['tracking'] != null
          ? Tracking.fromJson(json['tracking'])
          : null,
      notes: json['notes'],
      hasGivenRating: json['hasGivenRating'] ?? false,
      customerId: json['customerId'],
      driverId: json['driverId'],
      storeId: json['storeId'],
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'items': items.map((item) => item.toJson()).toList(),
      // Convert the store to a simplified format for backend
      'store': {
        'id': store.id,
        'name': store.name,
        'address': store.address,
        // Include other essential store fields
        'phone': store.phoneNumber,
        'description': store.description,
      },
      'storeId': store.id,
      'deliveryAddress': deliveryAddress,
      'subtotal': subtotal,
      'serviceCharge': serviceCharge,
      'total': total,
      'order_status': status
          .toString()
          .split('.')
          .last,
      if (deliveryStatus != null) 'delivery_status': deliveryStatus!
          .toString()
          .split('.')
          .last,
      'orderDate': orderDate.toIso8601String(),
      'notes': notes,
      'hasGivenRating': hasGivenRating,
      if (customerId != null) 'customerId': customerId,
      if (driverId != null) 'driverId': driverId,
    };
  }

  // Get formatted date
  String get formattedDate {
    return '${orderDate.day}/${orderDate.month}/${orderDate.year} ${orderDate
        .hour}:${orderDate.minute.toString().padLeft(2, '0')}';
  }

  // Get status message
  String get statusMessage {
    return tracking?.statusMessage ?? _getDefaultStatusMessage();
  }

  // Get default status message if tracking is not available
  String _getDefaultStatusMessage() {
    switch (status) {
      case OrderStatus.pending:
        return 'Menunggu konfirmasi pesanan';
      case OrderStatus.approved:
        return 'Pesanan telah dikonfirmasi';
      case OrderStatus.preparing:
        return 'Pesanan sedang dipersiapkan';
      case OrderStatus.on_delivery:
        return 'Pesanan sedang dalam pengiriman';
      case OrderStatus.delivered:
        return 'Pesanan telah diterima';
      case OrderStatus.driverAssigned:
        return 'Driver telah ditugaskan';
      case OrderStatus.driverHeadingToStore:
        return 'Driver sedang menuju ke toko';
      case OrderStatus.driverAtStore:
        return 'Driver telah sampai di toko';
      case OrderStatus.driverHeadingToCustomer:
        return 'Tunggu ya, Driver akan menuju ke tempatmu';
      case OrderStatus.driverArrived:
        return 'Driver telah tiba di lokasimu';
      case OrderStatus.completed:
        return 'Pesanan telah selesai';
      case OrderStatus.cancelled:
        return 'Pesanan dibatalkan';
    }
  }
}