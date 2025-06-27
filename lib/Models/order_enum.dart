// ========================================
// Order Status Constants
// ========================================

import 'package:flutter/material.dart';

// ✅ PERBAIKAN OrderEnum untuk match dengan backend

// ✅ PERBAIKAN 1: Update OrderStatus enum untuk include 'confirmed'
enum OrderStatus {
  pending('pending'),
  confirmed('confirmed'), // ✅ TAMBAHAN: Backend menggunakan 'confirmed'
  preparing('preparing'), // ✅ Backend menggunakan 'preparing'
  readyForPickup(
      'ready_for_pickup'), // ✅ Backend menggunakan 'ready_for_pickup'
  onDelivery('on_delivery'),
  delivered('delivered'),
  cancelled('cancelled'),
  rejected('rejected');

  const OrderStatus(this.value);
  final String value;

  // ✅ PERBAIKAN: Factory constructor untuk parsing dari backend
  factory OrderStatus.fromString(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return OrderStatus.pending;
      case 'confirmed': // ✅ TAMBAHAN: Handle 'confirmed' status
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
        print('⚠️ Unknown order status: $status, defaulting to pending');
        return OrderStatus.pending;
    }
  }

  String get name => value;

  bool get isCompleted => [delivered, cancelled, rejected].contains(this);
  bool get isActive => ![delivered, cancelled, rejected].contains(this);
}

enum DeliveryStatus {
  pending,
  pickedUp,
  onWay,
  delivered,
  rejected,
}

enum DriverRequestStatus {
  pending,
  accepted,
  rejected,
  completed,
  expired,
}

enum PaymentMethod {
  cash,
}

enum PaymentStatus {
  pending,
  paid,
  failed,
  refunded,
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

// Extension methods for OrderStatus
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

  String get displayName {
    switch (this) {
      case OrderStatus.pending:
        return 'Menunggu';
      case OrderStatus.confirmed:
        return 'Dikonfirmasi';
      case OrderStatus.preparing:
        return 'Disiapkan';
      case OrderStatus.readyForPickup:
        return 'Siap Diambil';
      case OrderStatus.onDelivery:
        return 'Diantar';
      case OrderStatus.delivered:
        return 'Selesai';
      case OrderStatus.cancelled:
        return 'Dibatalkan';
      case OrderStatus.rejected:
        return 'Ditolak';
    }
  }

  Color get color {
    switch (this) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.confirmed:
        return Colors.blue;
      case OrderStatus.preparing:
        return Colors.purple;
      case OrderStatus.readyForPickup:
        return Colors.teal;
      case OrderStatus.onDelivery:
        return Colors.indigo;
      case OrderStatus.delivered:
        return Colors.green;
      case OrderStatus.cancelled:
        return Colors.red;
      case OrderStatus.rejected:
        return Colors.red.shade700;
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

  bool get canBeCancelled =>
      this == OrderStatus.pending || this == OrderStatus.confirmed;

  bool get isActive => !isCompleted;
}

// Extension methods for DeliveryStatus
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
      case DeliveryStatus.rejected:
        return 'rejected';
    }
  }

  String get displayName {
    switch (this) {
      case DeliveryStatus.pending:
        return 'Menunggu';
      case DeliveryStatus.pickedUp:
        return 'Diambil';
      case DeliveryStatus.onWay:
        return 'Dalam Perjalanan';
      case DeliveryStatus.delivered:
        return 'Terkirim';
      case DeliveryStatus.rejected:
        return 'Ditolak';
    }
  }

  Color get color {
    switch (this) {
      case DeliveryStatus.pending:
        return Colors.orange;
      case DeliveryStatus.pickedUp:
        return Colors.blue;
      case DeliveryStatus.onWay:
        return Colors.purple;
      case DeliveryStatus.delivered:
        return Colors.green;
      case DeliveryStatus.rejected:
        return Colors.red;
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
      case 'rejected':
        return DeliveryStatus.rejected;
      default:
        return DeliveryStatus.pending;
    }
  }
}

// Extension methods for DriverRequestStatus
extension DriverRequestStatusExtension on DriverRequestStatus {
  String get value {
    switch (this) {
      case DriverRequestStatus.pending:
        return 'pending';
      case DriverRequestStatus.accepted:
        return 'accepted';
      case DriverRequestStatus.rejected:
        return 'rejected';
      case DriverRequestStatus.completed:
        return 'completed';
      case DriverRequestStatus.expired:
        return 'expired';
    }
  }

  String get displayName {
    switch (this) {
      case DriverRequestStatus.pending:
        return 'Menunggu Respon';
      case DriverRequestStatus.accepted:
        return 'Diterima';
      case DriverRequestStatus.rejected:
        return 'Ditolak';
      case DriverRequestStatus.completed:
        return 'Selesai';
      case DriverRequestStatus.expired:
        return 'Kedaluwarsa';
    }
  }

  Color get color {
    switch (this) {
      case DriverRequestStatus.pending:
        return Colors.orange;
      case DriverRequestStatus.accepted:
        return Colors.green;
      case DriverRequestStatus.rejected:
        return Colors.red;
      case DriverRequestStatus.completed:
        return Colors.blue;
      case DriverRequestStatus.expired:
        return Colors.grey;
    }
  }

  static DriverRequestStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'pending':
        return DriverRequestStatus.pending;
      case 'accepted':
        return DriverRequestStatus.accepted;
      case 'rejected':
        return DriverRequestStatus.rejected;
      case 'completed':
        return DriverRequestStatus.completed;
      case 'expired':
        return DriverRequestStatus.expired;
      default:
        return DriverRequestStatus.pending;
    }
  }
}

// Extension methods for DriverStatus
extension DriverStatusExtension on DriverStatus {
  String get value {
    switch (this) {
      case DriverStatus.active:
        return 'active';
      case DriverStatus.inactive:
        return 'inactive';
      case DriverStatus.busy:
        return 'busy';
    }
  }

  String get displayName {
    switch (this) {
      case DriverStatus.active:
        return 'Aktif';
      case DriverStatus.inactive:
        return 'Tidak Aktif';
      case DriverStatus.busy:
        return 'Sibuk';
    }
  }

  Color get color {
    switch (this) {
      case DriverStatus.active:
        return Colors.green;
      case DriverStatus.inactive:
        return Colors.grey;
      case DriverStatus.busy:
        return Colors.orange;
    }
  }

  static DriverStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'active':
        return DriverStatus.active;
      case 'inactive':
        return DriverStatus.inactive;
      case 'busy':
        return DriverStatus.busy;
      default:
        return DriverStatus.inactive;
    }
  }
}

// Extension methods for PaymentMethod
extension PaymentMethodExtension on PaymentMethod {
  String get value {
    switch (this) {
      case PaymentMethod.cash:
        return 'cash';
    }
  }

  String get displayName {
    switch (this) {
      case PaymentMethod.cash:
        return 'Tunai';
    }
  }

  static PaymentMethod fromString(String value) {
    switch (value.toLowerCase()) {
      case 'cash':
        return PaymentMethod.cash;
      default:
        return PaymentMethod.cash;
    }
  }
}

// Extension methods for PaymentStatus
extension PaymentStatusExtension on PaymentStatus {
  String get value {
    switch (this) {
      case PaymentStatus.pending:
        return 'pending';
      case PaymentStatus.paid:
        return 'paid';
      case PaymentStatus.failed:
        return 'failed';
      case PaymentStatus.refunded:
        return 'refunded';
    }
  }

  String get displayName {
    switch (this) {
      case PaymentStatus.pending:
        return 'Menunggu';
      case PaymentStatus.paid:
        return 'Dibayar';
      case PaymentStatus.failed:
        return 'Gagal';
      case PaymentStatus.refunded:
        return 'Dikembalikan';
    }
  }

  Color get color {
    switch (this) {
      case PaymentStatus.pending:
        return Colors.orange;
      case PaymentStatus.paid:
        return Colors.green;
      case PaymentStatus.failed:
        return Colors.red;
      case PaymentStatus.refunded:
        return Colors.blue;
    }
  }

  static PaymentStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'pending':
        return PaymentStatus.pending;
      case 'paid':
        return PaymentStatus.paid;
      case 'failed':
        return PaymentStatus.failed;
      case 'refunded':
        return PaymentStatus.refunded;
      default:
        return PaymentStatus.pending;
    }
  }
}
