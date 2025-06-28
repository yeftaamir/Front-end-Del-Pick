import 'package:flutter/material.dart';

enum OrderStatus {
  pending('pending'),
  confirmed('confirmed'), // ✅ Backend: models/order.js line 30
  preparing('preparing'), // ✅ Backend: models/order.js line 30
  readyForPickup('ready_for_pickup'), // ✅ Backend: models/order.js line 30
  onDelivery('on_delivery'), // ✅ Backend: models/order.js line 30
  delivered('delivered'), // ✅ Backend: models/order.js line 30
  cancelled('cancelled'), // ✅ Backend: models/order.js line 30
  rejected('rejected'); // ✅ Backend: models/order.js line 30

  const OrderStatus(this.value);
  final String value;

  // ✅ PERBAIKAN: Factory constructor untuk parsing dari backend
  factory OrderStatus.fromString(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return OrderStatus.pending;
      case 'confirmed': // ✅ Backend menggunakan 'confirmed'
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

  static OrderStatus fromValue(String value) {
    return OrderStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => OrderStatus.pending,
    );
  }

  bool get isCompleted => [delivered, cancelled, rejected].contains(this);
  bool get isActive => ![delivered, cancelled, rejected].contains(this);
  bool get canCancel => [pending, confirmed].contains(this);
}

enum DeliveryStatus {
  pending('pending'),
  pickedUp('picked_up'), // ✅ Backend: models/order.js line 34
  onWay('on_way'), // ✅ Backend: models/order.js line 34
  delivered('delivered'), // ✅ Backend: models/order.js line 34
  rejected('rejected'); // ✅ Backend: models/order.js line 34

  const DeliveryStatus(this.value);
  final String value;

  // ✅ PERBAIKAN: Factory constructor untuk parsing dari backend
  factory DeliveryStatus.fromString(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return DeliveryStatus.pending;
      case 'picked_up': // ✅ Backend menggunakan 'picked_up'
        return DeliveryStatus.pickedUp;
      case 'on_way': // ✅ Backend menggunakan 'on_way'
        return DeliveryStatus.onWay;
      case 'delivered':
        return DeliveryStatus.delivered;
      case 'rejected':
        return DeliveryStatus.rejected;
      default:
        print('⚠️ Unknown delivery status: $status, defaulting to pending');
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

  // Tambahkan di enum DeliveryStatus:
  static DeliveryStatus fromValue(String value) {
    return DeliveryStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => DeliveryStatus.pending,
    );
  }
}

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
    switch (status.toLowerCase()) {
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
            '⚠️ Unknown driver request status: $status, defaulting to pending');
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
}

enum DriverStatus {
  active('active'),
  inactive('inactive'),
  busy('busy');

  const DriverStatus(this.value);
  final String value;

  factory DriverStatus.fromString(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return DriverStatus.active;
      case 'inactive':
        return DriverStatus.inactive;
      case 'busy':
        return DriverStatus.busy;
      default:
        print('⚠️ Unknown driver status: $status, defaulting to inactive');
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
}

enum StoreStatus {
  active('active'),
  inactive('inactive'),
  closed('closed');

  const StoreStatus(this.value);
  final String value;

  factory StoreStatus.fromString(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return StoreStatus.active;
      case 'inactive':
        return StoreStatus.inactive;
      case 'closed':
        return StoreStatus.closed;
      default:
        print('⚠️ Unknown store status: $status, defaulting to inactive');
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
}

enum ServiceOrderStatus {
  pending('pending'),
  driverFound('driver_found'),
  inProgress('in_progress'),
  completed('completed'),
  cancelled('cancelled');

  const ServiceOrderStatus(this.value);
  final String value;

  factory ServiceOrderStatus.fromString(String status) {
    switch (status.toLowerCase()) {
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
            '⚠️ Unknown service order status: $status, defaulting to pending');
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

  bool get isCompleted => [completed, cancelled].contains(this);
  bool get isActive => ![completed, cancelled].contains(this);
}

enum UserRole {
  admin('admin'),
  customer('customer'),
  store('store'),
  driver('driver');

  const UserRole(this.value);
  final String value;

  factory UserRole.fromString(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'customer':
        return UserRole.customer;
      case 'store':
        return UserRole.store;
      case 'driver':
        return UserRole.driver;
      default:
        print('⚠️ Unknown user role: $role, defaulting to customer');
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

extension OrderStatusExtension on OrderStatus {
  // ✅ FIXED: Gunakan method name yang konsisten dengan enum
  String get name => value;

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

  // ✅ FIXED: Konsistensi method static
  static OrderStatus fromString(String statusString) {
    switch (statusString.toLowerCase()) {
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
        print('⚠️ Unknown order status: $statusString, defaulting to pending');
        return OrderStatus.pending;
    }
  }

  bool get isCompleted => [
        OrderStatus.delivered,
        OrderStatus.cancelled,
        OrderStatus.rejected
      ].contains(this);
  bool get canBeCancelled =>
      [OrderStatus.pending, OrderStatus.confirmed].contains(this);
  bool get canBeUpdatedByStore => [
        OrderStatus.pending,
        OrderStatus.confirmed,
        OrderStatus.preparing,
        OrderStatus.readyForPickup
      ].contains(this);
  bool get isActive => !isCompleted;
}

// Extension methods for DeliveryStatus
extension DeliveryStatusExtension on DeliveryStatus {
  String get name => value;

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

  static DeliveryStatus fromString(String statusString) {
    switch (statusString.toLowerCase()) {
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
        print(
            '⚠️ Unknown delivery status: $statusString, defaulting to pending');
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
      case DriverRequestStatus.cancelled:
        return 'cancelled';
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
