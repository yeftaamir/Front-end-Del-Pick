// Updated to match backend's order_status enum exactly
enum OrderStatus {
  pending,
  confirmed,
  preparing,
  ready_for_pickup,
  on_delivery,
  delivered,
  cancelled;

  bool get isCompleted =>
      this == OrderStatus.delivered ||
          this == OrderStatus.cancelled;

  static OrderStatus fromString(String status) {
    try {
      return OrderStatus.values.firstWhere(
              (e) => e.toString().split('.').last.toLowerCase() == status.toLowerCase()
      );
    } catch (_) {
      return OrderStatus.pending;
    }
  }
}

// Updated to match backend's delivery_status enum exactly
enum DeliveryStatus {
  pending,
  picked_up,
  on_way,
  delivered;

  static DeliveryStatus fromString(String status) {
    try {
      return DeliveryStatus.values.firstWhere(
              (e) => e.toString().split('.').last.toLowerCase() == status.toLowerCase()
      );
    } catch (_) {
      return DeliveryStatus.pending;
    }
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