// lib/models/responses/order_responses.dart
import '../Entities/driver.dart';
import '../Entities/menu_item.dart';
import '../Entities/order.dart';

class OrderTrackingResponse {
  final Order order;
  final Driver? driver;
  final List<Map<String, dynamic>> trackingHistory;
  final Map<String, dynamic>? currentLocation;

  OrderTrackingResponse({
    required this.order,
    this.driver,
    required this.trackingHistory,
    this.currentLocation,
  });

  factory OrderTrackingResponse.fromJson(Map<String, dynamic> json) {
    return OrderTrackingResponse(
      order: Order.fromJson(json['order'] as Map<String, dynamic>),
      driver: json['driver'] != null
          ? Driver.fromJson(json['driver'] as Map<String, dynamic>)
          : null,
      trackingHistory: List<Map<String, dynamic>>.from(
          json['trackingHistory'] ?? []
      ),
      currentLocation: json['currentLocation'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'order': order.toJson(),
      if (driver != null) 'driver': driver!.toJson(),
      'trackingHistory': trackingHistory,
      if (currentLocation != null) 'currentLocation': currentLocation,
    };
  }
}

// lib/models/cart/cart_item.dart
class CartItem {
  final MenuItem menuItem;
  final int quantity;
  final String? notes;

  CartItem({
    required this.menuItem,
    required this.quantity,
    this.notes,
  });

  double get totalPrice => menuItem.price * quantity;

  CartItem copyWith({
    MenuItem? menuItem,
    int? quantity,
    String? notes,
  }) {
    return CartItem(
      menuItem: menuItem ?? this.menuItem,
      quantity: quantity ?? this.quantity,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'menuItem': menuItem.toJson(),
      'quantity': quantity,
      'notes': notes,
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      menuItem: MenuItem.fromJson(json['menuItem'] as Map<String, dynamic>),
      quantity: json['quantity'] as int,
      notes: json['notes'] as String?,
    );
  }
}