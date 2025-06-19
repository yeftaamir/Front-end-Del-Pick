// lib/Models/Extensions/cart_extensions.dart
import '../Entities/menu_item.dart';
import '../Entities/order.dart';
import '../Enums/order_status.dart';
import '../Responses/order_responses.dart';

extension OrderExtensions on Order {
  // Check if order is active (not completed or cancelled)
  bool get isActive {
    return orderStatus != OrderStatus.delivered &&
        orderStatus != OrderStatus.cancelled;
  }

  // Check if order is completed
  bool get isCompleted {
    return orderStatus == OrderStatus.delivered ||
        orderStatus == OrderStatus.cancelled;
  }

  // Check if order can be cancelled
  bool get canBeCancelled {
    return orderStatus == OrderStatus.pending ||
        orderStatus == OrderStatus.confirmed;
  }

  // Check if order can be tracked
  bool get canBeTracked {
    return driverId != null &&
        (orderStatus == OrderStatus.onDelivery ||
            orderStatus == OrderStatus.preparing ||
            orderStatus == OrderStatus.readyForPickup);
  }

  // Get estimated delivery time remaining
  Duration? get estimatedTimeRemaining {
    if (estimatedDeliveryTime == null) return null;

    final now = DateTime.now();
    if (estimatedDeliveryTime!.isBefore(now)) return null;

    return estimatedDeliveryTime!.difference(now);
  }

  // Get formatted time remaining
  String get formattedTimeRemaining {
    final remaining = estimatedTimeRemaining;
    if (remaining == null) return '';

    if (remaining.inMinutes < 60) {
      return '${remaining.inMinutes} menit lagi';
    } else {
      final hours = remaining.inHours;
      final minutes = remaining.inMinutes % 60;
      return '${hours}j ${minutes}m lagi';
    }
  }

  // Get order age
  Duration get orderAge {
    return DateTime.now().difference(createdAt);
  }

  // Get formatted order age
  String get formattedOrderAge {
    final age = orderAge;

    if (age.inMinutes < 1) {
      return 'Baru saja';
    } else if (age.inMinutes < 60) {
      return '${age.inMinutes} menit yang lalu';
    } else if (age.inHours < 24) {
      return '${age.inHours} jam yang lalu';
    } else {
      return '${age.inDays} hari yang lalu';
    }
  }

  // Get total items count
  int get totalItemsCount {
    return items?.fold(0, (sum, item) => sum! + item.quantity) ?? 0;
  }

  // Get subtotal (total amount minus delivery fee)
  double get subtotal {
    return totalAmount - deliveryFee;
  }

  // Create a copy with updated status
  Order copyWithStatus(OrderStatus newStatus) {
    return Order(
      id: id,
      customerId: customerId,
      storeId: storeId,
      driverId: driverId,
      orderStatus: newStatus,
      deliveryStatus: deliveryStatus,
      totalAmount: totalAmount,
      deliveryFee: deliveryFee,
      estimatedPickupTime: estimatedPickupTime,
      actualPickupTime: actualPickupTime,
      estimatedDeliveryTime: estimatedDeliveryTime,
      actualDeliveryTime: actualDeliveryTime,
      trackingUpdates: trackingUpdates,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      customer: customer,
      store: store,
      driver: driver,
      items: items,
      orderReviews: orderReviews,
      driverReviews: driverReviews,
    );
  }
}

extension CartItemExtensions on CartItem {
  // Get formatted price
  String get formattedPrice {
    return 'Rp ${menuItem.price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
    )}';
  }

  // Get formatted total price
  String get formattedTotalPrice {
    return 'Rp ${totalPrice.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
    )}';
  }

  // Check if item is available
  bool get isAvailable {
    return menuItem.isAvailable;
  }

  // Get item summary text
  String get summaryText {
    return '${menuItem.name} x$quantity';
  }

  // Create cart item from menu item
  static CartItem fromMenuItem(MenuItem menuItem, {int quantity = 1, String? notes}) {
    return CartItem(
      menuItem: menuItem,
      quantity: quantity,
      notes: notes,
    );
  }

  // Update quantity
  CartItem withQuantity(int newQuantity) {
    return CartItem(
      menuItem: menuItem,
      quantity: newQuantity,
      notes: notes,
    );
  }

  // Add notes
  CartItem withNotes(String newNotes) {
    return CartItem(
      menuItem: menuItem,
      quantity: quantity,
      notes: newNotes,
    );
  }
}