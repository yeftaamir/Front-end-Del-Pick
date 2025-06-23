// ========================================
// 1. lib/models/enums/order_enums.dart
// ========================================

enum PaymentMethod {
  cash,
}

enum PaymentStatus {
  pending,
  paid,
  failed,
  refunded,
}

enum OrderStatus {
  pending,
  confirmed,
  preparing,
  readyForPickup,
  onDelivery,
  delivered,
  cancelled,
  rejected,
}

enum DeliveryStatus {
  pending,
  pickedUp,
  onWay,
  delivered,
}

enum DriverStatus {
  active,
  inactive,
  busy,
}

enum StoreStatus {
  active,
  inactive,
  closed,
}

enum UserRole {
  admin,
  customer,
  store,
  driver,
}

// Extension methods for enum conversions
extension OrderStatusExtension on OrderStatus {
  String get value {
    switch (this) {
      case OrderStatus.pending:
        return 'pending';
      case OrderStatus.confirmed:
        return 'confirmed';
      case OrderStatus.preparing:
        return 'preparing';
      case OrderStatus.readyForPickup:
        return 'ready_for_pickup';
      case OrderStatus.onDelivery:
        return 'on_delivery';
      case OrderStatus.delivered:
        return 'delivered';
      case OrderStatus.cancelled:
        return 'cancelled';
      case OrderStatus.rejected:
        return 'rejected';
    }
  }

  static OrderStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'pending':
        return OrderStatus.pending;
      case 'confirmed':
        return OrderStatus.confirmed;
      case 'preparing':
        return OrderStatus.preparing;
      case 'ready_for_pickup':
        return OrderStatus.readyForPickup;
      case 'on_delivery':
        return OrderStatus.onDelivery;
      case 'delivered':
        return OrderStatus.delivered;
      case 'cancelled':
        return OrderStatus.cancelled;
      case 'rejected':
        return OrderStatus.rejected;
      default:
        return OrderStatus.pending;
    }
  }

  bool get isCompleted =>
      this == OrderStatus.delivered ||
          this == OrderStatus.cancelled ||
          this == OrderStatus.rejected;
}

extension DeliveryStatusExtension on DeliveryStatus {
  String get value {
    switch (this) {
      case DeliveryStatus.pending:
        return 'pending';
      case DeliveryStatus.pickedUp:
        return 'picked_up';
      case DeliveryStatus.onWay:
        return 'on_way';
      case DeliveryStatus.delivered:
        return 'delivered';
    }
  }

  static DeliveryStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'pending':
        return DeliveryStatus.pending;
      case 'picked_up':
        return DeliveryStatus.pickedUp;
      case 'on_way':
        return DeliveryStatus.onWay;
      case 'delivered':
        return DeliveryStatus.delivered;
      default:
        return DeliveryStatus.pending;
    }
  }
}