// lib/models/extensions/order_extensions.dart
import '../Entities/order.dart';
import '../Enums/delivery_status.dart';
import '../Enums/order_status.dart';

extension OrderExtensions on Order {
  String get statusDisplayName {
    switch (orderStatus) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.preparing:
        return 'Preparing';
      case OrderStatus.readyForPickup:
        return 'Ready for Pickup';
      case OrderStatus.onDelivery:
        return 'On Delivery';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get deliveryStatusDisplayName {
    switch (deliveryStatus) {
      case DeliveryStatus.pending:
        return 'Pending';
      case DeliveryStatus.pickedUp:
        return 'Picked Up';
      case DeliveryStatus.onWay:
        return 'On the Way';
      case DeliveryStatus.delivered:
        return 'Delivered';
    }
  }

  bool get canBeCancelled {
    return orderStatus == OrderStatus.pending ||
        orderStatus == OrderStatus.confirmed;
  }

  bool get isCompleted {
    return orderStatus == OrderStatus.delivered ||
        orderStatus == OrderStatus.cancelled;
  }

  bool get isActive {
    return !isCompleted;
  }

  Duration? get estimatedDeliveryDuration {
    if (estimatedDeliveryTime == null) return null;

    final now = DateTime.now();
    if (estimatedDeliveryTime!.isBefore(now)) return null;

    return estimatedDeliveryTime!.difference(now);
  }

  String get formattedTotalAmount {
    return 'Rp ${totalAmount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
    )}';
  }
}