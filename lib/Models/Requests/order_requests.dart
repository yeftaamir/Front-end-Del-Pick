// lib/models/requests/order_requests.dart
class CreateOrderRequest {
  final int storeId;
  final List<OrderItemRequest> items;

  CreateOrderRequest({
    required this.storeId,
    required this.items,
  });

  Map<String, dynamic> toJson() {
    return {
      'storeId': storeId,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }
}

class OrderItemRequest {
  final int menuItemId;
  final int quantity;

  OrderItemRequest({
    required this.menuItemId,
    required this.quantity,
  });

  Map<String, dynamic> toJson() {
    return {
      'menuItemId': menuItemId,
      'quantity': quantity,
    };
  }
}