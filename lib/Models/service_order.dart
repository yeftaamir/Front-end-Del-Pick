// lib/Models/service_order.dart - FIXED VERSION
import 'customer.dart';
import 'driver.dart';
import 'driver_review.dart';
import 'master_location.dart';

enum ServiceOrderStatus {
  pending,
  driverFound,
  inProgress,
  completed,
  cancelled,
}

extension ServiceOrderStatusExtension on ServiceOrderStatus {
  String get value {
    switch (this) {
      case ServiceOrderStatus.pending:
        return 'pending';
      case ServiceOrderStatus.driverFound:
        return 'driver_found';
      case ServiceOrderStatus.inProgress:
        return 'in_progress';
      case ServiceOrderStatus.completed:
        return 'completed';
      case ServiceOrderStatus.cancelled:
        return 'cancelled';
    }
  }

  static ServiceOrderStatus fromString(String value) {
    switch (value.toLowerCase()) {
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
        return ServiceOrderStatus.pending;
    }
  }

  bool get isCompleted =>
      this == ServiceOrderStatus.completed ||
          this == ServiceOrderStatus.cancelled;

  bool get canBeCancelled =>
      this == ServiceOrderStatus.pending ||
          this == ServiceOrderStatus.driverFound;

  bool get isActive =>
      this == ServiceOrderStatus.driverFound ||
          this == ServiceOrderStatus.inProgress;
}

class ServiceOrderModel {
  final int id;
  final int customerId;
  final int? driverId;
  final String pickupAddress;
  final double pickupLatitude;
  final double pickupLongitude;
  final String destinationAddress;
  final double destinationLatitude;
  final double destinationLongitude;
  final String? description;
  final double serviceFee;
  final ServiceOrderStatus status;
  final String customerPhone;
  final String? driverPhone;
  final int? estimatedDuration; // in minutes
  final DateTime? actualStartTime;
  final DateTime? actualCompletionTime;
  final int? pickupLocationId;
  final int? destinationLocationId;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Related models
  final CustomerModel? customer;
  final DriverModel? driver;
  final MasterLocationModel? pickupLocation;
  final MasterLocationModel? destinationLocation;
  final DriverReviewModel? review;

  const ServiceOrderModel({
    required this.id,
    required this.customerId,
    required this.pickupAddress,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.destinationAddress,
    required this.destinationLatitude,
    required this.destinationLongitude,
    required this.serviceFee,
    required this.customerPhone,
    required this.createdAt,
    required this.updatedAt,
    this.driverId,
    this.description,
    this.status = ServiceOrderStatus.pending,
    this.driverPhone,
    this.estimatedDuration,
    this.actualStartTime,
    this.actualCompletionTime,
    this.pickupLocationId,
    this.destinationLocationId,
    this.notes,
    this.customer,
    this.driver,
    this.pickupLocation,
    this.destinationLocation,
    this.review,
  });

  // ✅ TAMBAHAN: Safe parsing untuk numeric values yang mungkin berupa string
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  // ✅ TAMBAHAN: Safe parsing untuk nullable double values
  static double? _parseNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  factory ServiceOrderModel.fromJson(Map<String, dynamic> json) {
    return ServiceOrderModel(
      id: json['id'] ?? 0,
      customerId: json['customer_id'] ?? 0,
      driverId: json['driver_id'],
      pickupAddress: json['pickup_address'] ?? '',
      // ✅ PERBAIKAN: Safe parsing untuk coordinate fields
      pickupLatitude: _parseDouble(json['pickup_latitude']),
      pickupLongitude: _parseDouble(json['pickup_longitude']),
      destinationAddress: json['destination_address'] ?? '',
      destinationLatitude: _parseDouble(json['destination_latitude']),
      destinationLongitude: _parseDouble(json['destination_longitude']),
      description: json['description'],
      // ✅ PERBAIKAN: Safe parsing untuk service_fee field
      serviceFee: _parseDouble(json['service_fee']),
      status: ServiceOrderStatusExtension.fromString(json['status'] ?? 'pending'),
      customerPhone: json['customer_phone'] ?? '',
      driverPhone: json['driver_phone'],
      estimatedDuration: json['estimated_duration'],
      actualStartTime: json['actual_start_time'] != null
          ? DateTime.parse(json['actual_start_time'])
          : null,
      actualCompletionTime: json['actual_completion_time'] != null
          ? DateTime.parse(json['actual_completion_time'])
          : null,
      pickupLocationId: json['pickup_location_id'],
      destinationLocationId: json['destination_location_id'],
      notes: json['notes'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      customer: json['customer'] != null ? CustomerModel.fromJson(json['customer']) : null,
      driver: json['driver'] != null ? DriverModel.fromJson(json['driver']) : null,
      pickupLocation: json['pickup_location'] != null
          ? MasterLocationModel.fromJson(json['pickup_location']) : null,
      destinationLocation: json['destination_location'] != null
          ? MasterLocationModel.fromJson(json['destination_location']) : null,
      review: json['review'] != null ? DriverReviewModel.fromJson(json['review']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_id': customerId,
      'driver_id': driverId,
      'pickup_address': pickupAddress,
      'pickup_latitude': pickupLatitude,
      'pickup_longitude': pickupLongitude,
      'destination_address': destinationAddress,
      'destination_latitude': destinationLatitude,
      'destination_longitude': destinationLongitude,
      'description': description,
      'service_fee': serviceFee,
      'status': status.value,
      'customer_phone': customerPhone,
      'driver_phone': driverPhone,
      'estimated_duration': estimatedDuration,
      if (actualStartTime != null) 'actual_start_time': actualStartTime!.toIso8601String(),
      if (actualCompletionTime != null) 'actual_completion_time': actualCompletionTime!.toIso8601String(),
      'pickup_location_id': pickupLocationId,
      'destination_location_id': destinationLocationId,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (customer != null) 'customer': customer!.toJson(),
      if (driver != null) 'driver': driver!.toJson(),
      if (pickupLocation != null) 'pickup_location': pickupLocation!.toJson(),
      if (destinationLocation != null) 'destination_location': destinationLocation!.toJson(),
      if (review != null) 'review': review!.toJson(),
    };
  }

  ServiceOrderModel copyWith({
    int? id,
    int? customerId,
    int? driverId,
    String? pickupAddress,
    double? pickupLatitude,
    double? pickupLongitude,
    String? destinationAddress,
    double? destinationLatitude,
    double? destinationLongitude,
    String? description,
    double? serviceFee,
    ServiceOrderStatus? status,
    String? customerPhone,
    String? driverPhone,
    int? estimatedDuration,
    DateTime? actualStartTime,
    DateTime? actualCompletionTime,
    int? pickupLocationId,
    int? destinationLocationId,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    CustomerModel? customer,
    DriverModel? driver,
    MasterLocationModel? pickupLocation,
    MasterLocationModel? destinationLocation,
    DriverReviewModel? review,
  }) {
    return ServiceOrderModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      driverId: driverId ?? this.driverId,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      pickupLatitude: pickupLatitude ?? this.pickupLatitude,
      pickupLongitude: pickupLongitude ?? this.pickupLongitude,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      destinationLatitude: destinationLatitude ?? this.destinationLatitude,
      destinationLongitude: destinationLongitude ?? this.destinationLongitude,
      description: description ?? this.description,
      serviceFee: serviceFee ?? this.serviceFee,
      status: status ?? this.status,
      customerPhone: customerPhone ?? this.customerPhone,
      driverPhone: driverPhone ?? this.driverPhone,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      actualStartTime: actualStartTime ?? this.actualStartTime,
      actualCompletionTime: actualCompletionTime ?? this.actualCompletionTime,
      pickupLocationId: pickupLocationId ?? this.pickupLocationId,
      destinationLocationId: destinationLocationId ?? this.destinationLocationId,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      customer: customer ?? this.customer,
      driver: driver ?? this.driver,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      destinationLocation: destinationLocation ?? this.destinationLocation,
      review: review ?? this.review,
    );
  }

  // Utility methods
  String get statusDisplayText {
    switch (status) {
      case ServiceOrderStatus.pending:
        return 'Mencari Driver';
      case ServiceOrderStatus.driverFound:
        return 'Driver Ditemukan';
      case ServiceOrderStatus.inProgress:
        return 'Sedang Dikerjakan';
      case ServiceOrderStatus.completed:
        return 'Selesai';
      case ServiceOrderStatus.cancelled:
        return 'Dibatalkan';
    }
  }

  String get formattedServiceFee {
    return 'Rp ${serviceFee.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
    )}';
  }

  String get formattedEstimatedDuration {
    if (estimatedDuration == null) return 'Tidak tersedia';

    if (estimatedDuration! < 60) {
      return '${estimatedDuration} menit';
    } else {
      final hours = estimatedDuration! ~/ 60;
      final minutes = estimatedDuration! % 60;
      if (minutes == 0) {
        return '${hours} jam';
      } else {
        return '${hours} jam ${minutes} menit';
      }
    }
  }

  String get formattedPickupLocation {
    return pickupAddress;
  }

  String get formattedDestinationLocation {
    return destinationAddress;
  }

  String get formattedCreatedAt {
    return '${createdAt.day}/${createdAt.month}/${createdAt.year} ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}';
  }

  bool get canTrack =>
      status == ServiceOrderStatus.driverFound ||
          status == ServiceOrderStatus.inProgress;

  bool get hasDriver => driverId != null && driver != null;

  Duration? get estimatedDurationTime {
    if (estimatedDuration == null) return null;
    return Duration(minutes: estimatedDuration!);
  }

  Duration? get actualDuration {
    if (actualStartTime != null && actualCompletionTime != null) {
      return actualCompletionTime!.difference(actualStartTime!);
    }
    return null;
  }
}