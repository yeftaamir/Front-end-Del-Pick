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

// Updated to match backend's order_status enum
enum OrderStatus {
  pending,
  approved,       // New status from backend
  preparing,      // New status from backend
  on_delivery,    // New status from backend
  delivered,      // New status from backend
  cancelled,      // Kept from original FE

  // Keep original FE statuses for backward compatibility
  driverAssigned,
  driverHeadingToStore,
  driverAtStore,
  driverHeadingToCustomer,
  driverArrived,
  completed;

  bool get isCompleted =>
      this == OrderStatus.completed ||
          this == OrderStatus.cancelled ||
          this == OrderStatus.delivered;

  // Convert backend status string to OrderStatus enum
  static OrderStatus fromString(String status) {
    try {
      return OrderStatus.values.firstWhere(
              (e) => e.toString().split('.').last.toLowerCase() == status.toLowerCase()
      );
    } catch (_) {
      return OrderStatus.pending; // Default value
    }
  }
}

// New enum to match backend's delivery_status
enum DeliveryStatus {
  waiting,
  picking_up,
  on_delivery,
  delivered;

  // Convert string to DeliveryStatus enum
  static DeliveryStatus fromString(String status) {
    try {
      return DeliveryStatus.values.firstWhere(
              (e) => e.toString().split('.').last.toLowerCase() == status.toLowerCase()
      );
    } catch (_) {
      return DeliveryStatus.waiting; // Default value
    }
  }
}