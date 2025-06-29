import 'package:flutter/material.dart';

// ========================================
// ORDER STATUS ENUM
// ========================================
enum OrderStatus {
  pending('pending'),
  confirmed('confirmed'),
  preparing('preparing'),
  readyForPickup('ready_for_pickup'),
  onDelivery('on_delivery'),
  delivered('delivered'),
  cancelled('cancelled'),
  rejected('rejected');

  const OrderStatus(this.value);
  final String value;

  // ✅ SATU-SATUNYA method parsing - tidak ada duplikasi
  factory OrderStatus.fromString(String status) {
    switch (status.toLowerCase().trim()) {
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
        print('⚠️ Unknown order status: "$status", defaulting to pending');
        return OrderStatus.pending;
    }
  }

  String get displayName {
    switch (this) {
      case OrderStatus.pending:
        return 'Menunggu Konfirmasi';
      case OrderStatus.confirmed:
        return 'Dikonfirmasi';
      case OrderStatus.preparing:
        return 'Sedang Diproses';
      case OrderStatus.readyForPickup:
        return 'Siap Diambil';
      case OrderStatus.onDelivery:
        return 'Sedang Diantar';
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

  bool get isCompleted => [delivered, cancelled, rejected].contains(this);
  bool get isActive => !isCompleted;
  bool get canBeCancelled => [pending, confirmed].contains(this);
  bool get canBeUpdatedByStore =>
      [pending, confirmed, preparing, readyForPickup].contains(this);
}

// ========================================
// DELIVERY STATUS ENUM
// ========================================
enum DeliveryStatus {
  pending('pending'),
  pickedUp('picked_up'),
  onWay('on_way'),
  delivered('delivered'),
  rejected('rejected');

  const DeliveryStatus(this.value);
  final String value;

  // ✅ SATU-SATUNYA method parsing - tidak ada duplikasi
  factory DeliveryStatus.fromString(String status) {
    switch (status.toLowerCase().trim()) {
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
        print('⚠️ Unknown delivery status: "$status", defaulting to pending');
        return DeliveryStatus.pending;
    }
  }

  String get displayName {
    switch (this) {
      case DeliveryStatus.pending:
        return 'Menunggu Penjemputan';
      case DeliveryStatus.pickedUp:
        return 'Sudah Diambil';
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
}

// ========================================
// DRIVER REQUEST STATUS ENUM
// ========================================
enum DriverRequestStatus {
  pending('pending'),
  accepted('accepted'),
  rejected('rejected'),
  completed('completed'),
  expired('expired'),
  cancelled('cancelled');

  const DriverRequestStatus(this.value);
  final String value;

  factory DriverRequestStatus.fromString(String status) {
    switch (status.toLowerCase().trim()) {
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
      case 'cancelled':
        return DriverRequestStatus.cancelled;
      default:
        print(
            '⚠️ Unknown driver request status: "$status", defaulting to pending');
        return DriverRequestStatus.pending;
    }
  }

  String get displayName {
    switch (this) {
      case DriverRequestStatus.pending:
        return 'Menunggu Respons';
      case DriverRequestStatus.accepted:
        return 'Diterima';
      case DriverRequestStatus.rejected:
        return 'Ditolak';
      case DriverRequestStatus.completed:
        return 'Selesai';
      case DriverRequestStatus.expired:
        return 'Kadaluarsa';
      case DriverRequestStatus.cancelled:
        return 'Dibatalkan';
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
      case DriverRequestStatus.cancelled:
        return Colors.red.shade700;
    }
  }
}

// ========================================
// DRIVER STATUS ENUM
// ========================================
enum DriverStatus {
  active('active'),
  inactive('inactive'),
  busy('busy');

  const DriverStatus(this.value);
  final String value;

  factory DriverStatus.fromString(String status) {
    switch (status.toLowerCase().trim()) {
      case 'active':
        return DriverStatus.active;
      case 'inactive':
        return DriverStatus.inactive;
      case 'busy':
        return DriverStatus.busy;
      default:
        print('⚠️ Unknown driver status: "$status", defaulting to inactive');
        return DriverStatus.inactive;
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
}

// ========================================
// STORE STATUS ENUM
// ========================================
enum StoreStatus {
  active('active'),
  inactive('inactive'),
  closed('closed');

  const StoreStatus(this.value);
  final String value;

  factory StoreStatus.fromString(String status) {
    switch (status.toLowerCase().trim()) {
      case 'active':
        return StoreStatus.active;
      case 'inactive':
        return StoreStatus.inactive;
      case 'closed':
        return StoreStatus.closed;
      default:
        print('⚠️ Unknown store status: "$status", defaulting to inactive');
        return StoreStatus.inactive;
    }
  }

  String get displayName {
    switch (this) {
      case StoreStatus.active:
        return 'Buka';
      case StoreStatus.inactive:
        return 'Tidak Aktif';
      case StoreStatus.closed:
        return 'Tutup';
    }
  }

  Color get color {
    switch (this) {
      case StoreStatus.active:
        return Colors.green;
      case StoreStatus.inactive:
        return Colors.grey;
      case StoreStatus.closed:
        return Colors.red;
    }
  }
}

// ========================================
// SERVICE ORDER STATUS ENUM
// ========================================
enum ServiceOrderStatus {
  pending('pending'),
  driverFound('driver_found'),
  inProgress('in_progress'),
  completed('completed'),
  cancelled('cancelled');

  const ServiceOrderStatus(this.value);
  final String value;

  factory ServiceOrderStatus.fromString(String status) {
    switch (status.toLowerCase().trim()) {
      case 'pending':
        return ServiceOrderStatus.pending;
      case 'driver_found':
        return ServiceOrderStatus.driverFound;
      case 'in_progress':
        return ServiceOrderStatus.inProgress;
      case 'completed':
        return ServiceOrderStatus.completed;
      case 'cancelled':
        return ServiceOrderStatus.cancelled;
      default:
        print(
            '⚠️ Unknown service order status: "$status", defaulting to pending');
        return ServiceOrderStatus.pending;
    }
  }

  String get displayName {
    switch (this) {
      case ServiceOrderStatus.pending:
        return 'Mencari Driver';
      case ServiceOrderStatus.driverFound:
        return 'Driver Ditemukan';
      case ServiceOrderStatus.inProgress:
        return 'Sedang Berlangsung';
      case ServiceOrderStatus.completed:
        return 'Selesai';
      case ServiceOrderStatus.cancelled:
        return 'Dibatalkan';
    }
  }

  Color get color {
    switch (this) {
      case ServiceOrderStatus.pending:
        return Colors.orange;
      case ServiceOrderStatus.driverFound:
        return Colors.blue;
      case ServiceOrderStatus.inProgress:
        return Colors.purple;
      case ServiceOrderStatus.completed:
        return Colors.green;
      case ServiceOrderStatus.cancelled:
        return Colors.red;
    }
  }

  bool get isCompleted => [completed, cancelled].contains(this);
  bool get isActive => !isCompleted;
}

// ========================================
// USER ROLE ENUM
// ========================================
enum UserRole {
  admin('admin'),
  customer('customer'),
  store('store'),
  driver('driver');

  const UserRole(this.value);
  final String value;

  factory UserRole.fromString(String role) {
    switch (role.toLowerCase().trim()) {
      case 'admin':
        return UserRole.admin;
      case 'customer':
        return UserRole.customer;
      case 'store':
        return UserRole.store;
      case 'driver':
        return UserRole.driver;
      default:
        print('⚠️ Unknown user role: "$role", defaulting to customer');
        return UserRole.customer;
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'Administrator';
      case UserRole.customer:
        return 'Pelanggan';
      case UserRole.store:
        return 'Toko';
      case UserRole.driver:
        return 'Driver';
    }
  }

  Color get color {
    switch (this) {
      case UserRole.admin:
        return Colors.purple;
      case UserRole.customer:
        return Colors.blue;
      case UserRole.store:
        return Colors.green;
      case UserRole.driver:
        return Colors.orange;
    }
  }
}

// ========================================
// PAYMENT ENUMS
// ========================================
enum PaymentMethod {
  cash('cash');

  const PaymentMethod(this.value);
  final String value;

  factory PaymentMethod.fromString(String method) {
    switch (method.toLowerCase().trim()) {
      case 'cash':
        return PaymentMethod.cash;
      default:
        print('⚠️ Unknown payment method: "$method", defaulting to cash');
        return PaymentMethod.cash;
    }
  }

  String get displayName {
    switch (this) {
      case PaymentMethod.cash:
        return 'Tunai';
    }
  }
}

enum PaymentStatus {
  pending('pending'),
  paid('paid'),
  failed('failed'),
  refunded('refunded');

  const PaymentStatus(this.value);
  final String value;

  factory PaymentStatus.fromString(String status) {
    switch (status.toLowerCase().trim()) {
      case 'pending':
        return PaymentStatus.pending;
      case 'paid':
        return PaymentStatus.paid;
      case 'failed':
        return PaymentStatus.failed;
      case 'refunded':
        return PaymentStatus.refunded;
      default:
        print('⚠️ Unknown payment status: "$status", defaulting to pending');
        return PaymentStatus.pending;
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
}
