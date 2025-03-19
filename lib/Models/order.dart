import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'item_model.dart';
import 'store.dart';
import 'tracking.dart';

class Order {
  final String id;
  final List<Item> items;
  final StoreModel store;
  final String deliveryAddress;
  final double subtotal;
  final double serviceCharge;
  final double total;
  final OrderStatus status;
  final DateTime orderDate;
  final PaymentMethod paymentMethod;
  final PaymentStatus paymentStatus;
  final Tracking? tracking;
  final String? notes;

  Order({
    required this.id,
    required this.items,
    required this.store,
    required this.deliveryAddress,
    required this.subtotal,
    required this.serviceCharge,
    required this.total,
    this.status = OrderStatus.pending,
    required this.orderDate,
    this.paymentMethod = PaymentMethod.cash,  // Cash only as per requirement
    this.paymentStatus = PaymentStatus.pending,
    this.tracking,
    this.notes,
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
    return 'Rp${subtotal.toStringAsFixed(0)}';
  }

  String formatDeliveryFee() {
    return 'Rp${serviceCharge.toStringAsFixed(0)}';
  }

  String formatTax() {
    // Assuming tax is 0 or included in the service charge as per requirements
    return 'Rp0';
  }

  String formatTotal() {
    return 'Rp${total.toStringAsFixed(0)}';
  }

  // Create a copy of this order with updated values
  Order copyWith({
    String? id,
    List<Item>? items,
    StoreModel? store,
    String? deliveryAddress,
    double? subtotal,
    double? serviceCharge,
    double? total,
    OrderStatus? status,
    DateTime? orderDate,
    PaymentMethod? paymentMethod,
    PaymentStatus? paymentStatus,
    Tracking? tracking,
    String? notes,
  }) {
    return Order(
      id: id ?? this.id,
      items: items ?? this.items,
      store: store ?? this.store,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      subtotal: subtotal ?? this.subtotal,
      serviceCharge: serviceCharge ?? this.serviceCharge,
      total: total ?? this.total,
      status: status ?? this.status,
      orderDate: orderDate ?? this.orderDate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      tracking: tracking ?? this.tracking,
      notes: notes ?? this.notes,
    );
  }

  // Create an order from the cart items
  factory Order.fromCart({
    required String id,
    required List<Item> cartItems,
    required StoreModel store,
    required String deliveryAddress,
    required double serviceCharge,
  }) {
    final subtotal = calculateSubtotal(cartItems);
    final total = calculateTotal(subtotal, serviceCharge);

    return Order(
      id: id,
      items: cartItems,
      store: store,
      deliveryAddress: deliveryAddress,
      subtotal: subtotal,
      serviceCharge: serviceCharge,
      total: total,
      orderDate: DateTime.now(),
    );
  }

  // Convert from JSON
  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'],
      items: (json['items'] as List).map((item) => _itemFromJson(item)).toList(),
      store: _storeFromJson(json['store']),
      deliveryAddress: json['deliveryAddress'],
      subtotal: json['subtotal'],
      serviceCharge: json['serviceCharge'],
      total: json['total'],
      status: OrderStatus.values.firstWhere(
            (e) => e.toString() == 'OrderStatus.${json['status']}',
        orElse: () => OrderStatus.pending,
      ),
      orderDate: DateTime.parse(json['orderDate']),
      paymentMethod: PaymentMethod.values.firstWhere(
            (e) => e.toString() == 'PaymentMethod.${json['paymentMethod']}',
        orElse: () => PaymentMethod.cash,
      ),
      paymentStatus: PaymentStatus.values.firstWhere(
            (e) => e.toString() == 'PaymentStatus.${json['paymentStatus']}',
        orElse: () => PaymentStatus.pending,
      ),
      tracking: json['tracking'] != null ? Tracking.fromJson(json['tracking']) : null,
      notes: json['notes'],
    );
  }

  // Helper method to convert Item from JSON
  static Item _itemFromJson(Map<String, dynamic> json) {
    return Item(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      price: json['price'],
      quantity: json['quantity'],
      imageUrl: json['imageUrl'],
      isAvailable: json['isAvailable'],
      status: json['status'],
    );
  }

  // Helper method to convert StoreModel from JSON
  static StoreModel _storeFromJson(Map<String, dynamic> json) {
    return StoreModel(
      name: json['name'],
      address: json['address'],
      openHours: json['openHours'],
      distance: json['distance'] ?? 0.0,
      rating: json['rating'] ?? 0.0,
      reviewCount: json['reviewCount'] ?? 0,
      imageUrl: json['imageUrl'] ?? 'assets/images/store_front.jpg',
      phoneNumber: json['phoneNumber'] ?? '',
      productCount: json['productCount'] ?? 0,
      description: json['description'] ?? '',
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'items': items.map((item) => _itemToJson(item)).toList(),
      'store': _storeToJson(store),
      'deliveryAddress': deliveryAddress,
      'subtotal': subtotal,
      'serviceCharge': serviceCharge,
      'total': total,
      'status': status.toString().split('.').last,
      'orderDate': orderDate.toIso8601String(),
      'paymentMethod': paymentMethod.toString().split('.').last,
      'paymentStatus': paymentStatus.toString().split('.').last,
      'tracking': tracking?.toJson(),
      'notes': notes,
    };
  }

  // Helper method to convert Item to JSON
  static Map<String, dynamic> _itemToJson(Item item) {
    return {
      'id': item.id,
      'name': item.name,
      'description': item.description,
      'price': item.price,
      'quantity': item.quantity,
      'imageUrl': item.imageUrl,
      'isAvailable': item.isAvailable,
      'status': item.status,
    };
  }

  // Helper method to convert StoreModel to JSON
  static Map<String, dynamic> _storeToJson(StoreModel store) {
    return {
      'name': store.name,
      'address': store.address,
      'openHours': store.openHours,
      'distance': store.distance,
      'rating': store.rating,
      'reviewCount': store.reviewCount,
      'imageUrl': store.imageUrl,
      'phoneNumber': store.phoneNumber,
      'productCount': store.productCount,
      'description': store.description,
    };
  }

  // Get formatted date
  String get formattedDate {
    return '${orderDate.day}/${orderDate.month}/${orderDate.year} ${orderDate.hour}:${orderDate.minute.toString().padLeft(2, '0')}';
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

  // Get a sample order for testing
  factory Order.sample() {
    return Order(
      id: 'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      items: [
        Item(
          id: '1',
          name: 'Mie Goreng Spesial',
          price: 15000,
          quantity: 2,
          imageUrl: 'assets/images/menu_item.jpg',
          isAvailable: true,
          status: 'available',
          description: 'Mie goreng dengan telur dan sayuran',
        ),
        Item(
          id: '2',
          name: 'Es Teh Manis',
          price: 5000,
          quantity: 2,
          imageUrl: 'assets/images/menu_item.jpg',
          isAvailable: true,
          status: 'available',
          description: 'Teh manis dengan es',
        ),
      ],
      store: StoreModel(
        name: 'Warmindo Kayungyun',
        address: 'Jl. P.I. Del, Sitoluama, Laguboti',
        openHours: '08:00 - 22:00',
        rating: 4.8,
        reviewCount: 120,
      ),
      deliveryAddress: 'Asrama Mahasiswa Del Institute, Laguboti',
      subtotal: 40000,
      serviceCharge: 30000,
      total: 70000,
      orderDate: DateTime.now(),
      tracking: Tracking.sample(),
    );
  }
}

// Payment method enum
enum PaymentMethod {
  cash, // Only accepting cash as per requirement
}

// Payment status enum
enum PaymentStatus {
  pending,
  paid,
  failed,
  refunded,
}