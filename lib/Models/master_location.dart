// lib/Models/master_location.dart - FIXED VERSION
import 'dart:math' show sin, cos, atan2, sqrt, pi;

class MasterLocationModel {
  final int id;
  final String name;
  final double latitude;
  final double longitude;
  final double serviceFee;
  final int estimatedDurationMinutes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MasterLocationModel({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.serviceFee,
    required this.estimatedDurationMinutes,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
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

  factory MasterLocationModel.fromJson(Map<String, dynamic> json) {
    return MasterLocationModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      // ✅ PERBAIKAN: Safe parsing untuk coordinate fields
      latitude: _parseDouble(json['latitude']),
      longitude: _parseDouble(json['longitude']),
      // ✅ PERBAIKAN: Safe parsing untuk service_fee field
      serviceFee: _parseDouble(json['service_fee']),
      estimatedDurationMinutes: json['estimated_duration_minutes'] ?? 0,
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'service_fee': serviceFee,
      'estimated_duration_minutes': estimatedDurationMinutes,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  MasterLocationModel copyWith({
    int? id,
    String? name,
    double? latitude,
    double? longitude,
    double? serviceFee,
    int? estimatedDurationMinutes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MasterLocationModel(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      serviceFee: serviceFee ?? this.serviceFee,
      estimatedDurationMinutes: estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Utility methods
  String get formattedServiceFee {
    return 'Rp ${serviceFee.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
    )}';
  }

  String get formattedEstimatedDuration {
    if (estimatedDurationMinutes < 60) {
      return '${estimatedDurationMinutes} menit';
    } else {
      final hours = estimatedDurationMinutes ~/ 60;
      final minutes = estimatedDurationMinutes % 60;
      if (minutes == 0) {
        return '${hours} jam';
      } else {
        return '${hours} jam ${minutes} menit';
      }
    }
  }

  // Calculate distance to another location using Haversine formula
  double distanceTo(double lat, double lon) {
    const double earthRadius = 6371; // Earth radius in kilometers

    final double dLat = _degreesToRadians(lat - latitude);
    final double dLon = _degreesToRadians(lon - longitude);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(latitude)) * cos(_degreesToRadians(lat)) *
            sin(dLon / 2) * sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  // Get location display string
  String get displayName => name;

  // Check if location is within operational area
  bool get isOperational => isActive;

  // Get formatted coordinates
  String get coordinatesString => '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
}