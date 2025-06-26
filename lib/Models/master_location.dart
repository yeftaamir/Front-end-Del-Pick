// lib/Models/master_location.dart
import 'dart:math' show sin, cos, atan2, sqrt, pi;
import 'service_order.dart';

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

  // Related models
  final List<ServiceOrderModel> pickupOrders;
  final List<ServiceOrderModel> destinationOrders;

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
    this.pickupOrders = const [],
    this.destinationOrders = const [],
  });

  factory MasterLocationModel.fromJson(Map<String, dynamic> json) {
    return MasterLocationModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      serviceFee: (json['service_fee'] ?? 0.0).toDouble(),
      estimatedDurationMinutes: json['estimated_duration_minutes'] ?? 0,
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      pickupOrders: json['pickup_orders'] != null
          ? (json['pickup_orders'] as List)
          .map((order) => ServiceOrderModel.fromJson(order))
          .toList()
          : [],
      destinationOrders: json['destination_orders'] != null
          ? (json['destination_orders'] as List)
          .map((order) => ServiceOrderModel.fromJson(order))
          .toList()
          : [],
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
      'pickup_orders': pickupOrders.map((order) => order.toJson()).toList(),
      'destination_orders': destinationOrders.map((order) => order.toJson()).toList(),
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
    List<ServiceOrderModel>? pickupOrders,
    List<ServiceOrderModel>? destinationOrders,
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
      pickupOrders: pickupOrders ?? this.pickupOrders,
      destinationOrders: destinationOrders ?? this.destinationOrders,
    );
  }

  // Utility methods - sesuai dengan backend methods

  /// Get fixed service fee for this location (destinasi tetap ke IT Del)
  double getServiceFee() {
    return serviceFee;
  }

  /// Get estimated duration for this location
  int getEstimatedDuration() {
    return estimatedDurationMinutes;
  }

  /// Format service fee for display
  String get formattedServiceFee {
    return 'Rp ${serviceFee.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
    )}';
  }

  /// Format estimated duration for display
  String get formattedEstimatedDuration {
    if (estimatedDurationMinutes >= 60) {
      final hours = estimatedDurationMinutes ~/ 60;
      final minutes = estimatedDurationMinutes % 60;
      if (minutes > 0) {
        return '${hours}j ${minutes}m';
      } else {
        return '${hours}j';
      }
    } else {
      return '${estimatedDurationMinutes}m';
    }
  }

  /// Get coordinates as a formatted string
  String get coordinatesString {
    return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  }

  /// Get location summary for display
  String get locationSummary {
    return '$name • $formattedServiceFee • $formattedEstimatedDuration';
  }

  /// Check if location is available for service
  bool get isAvailable => isActive;

  /// Get total pickup orders count
  int get totalPickupOrders => pickupOrders.length;

  /// Get total destination orders count
  int get totalDestinationOrders => destinationOrders.length;

  /// Get total orders count (pickup + destination)
  int get totalOrders => totalPickupOrders + totalDestinationOrders;

  /// Get recent pickup orders (last 10)
  List<ServiceOrderModel> get recentPickupOrders {
    final sortedOrders = [...pickupOrders];
    sortedOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sortedOrders.take(10).toList();
  }

  /// Get recent destination orders (last 10)
  List<ServiceOrderModel> get recentDestinationOrders {
    final sortedOrders = [...destinationOrders];
    sortedOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sortedOrders.take(10).toList();
  }

  /// Calculate distance from another location
  double calculateDistanceFrom({
    required double fromLatitude,
    required double fromLongitude,
  }) {
    const double earthRadius = 6371; // Earth radius in kilometers

    final double dLat = _degreesToRadians(latitude - fromLatitude);
    final double dLon = _degreesToRadians(longitude - fromLongitude);

    final double a =
        (sin(dLat / 2) * sin(dLat / 2)) +
            cos(_degreesToRadians(fromLatitude)) * cos(_degreesToRadians(latitude)) *
                (sin(dLon / 2) * sin(dLon / 2));

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  /// Get Google Maps URL for this location
  String get googleMapsUrl {
    return 'https://maps.google.com/?q=$latitude,$longitude';
  }

  /// Get search relevance score for a query
  double getSearchRelevanceScore(String query) {
    if (query.isEmpty) return 0.0;

    final lowercaseQuery = query.toLowerCase();
    final lowercaseName = name.toLowerCase();

    // Exact match gets highest score
    if (lowercaseName == lowercaseQuery) return 1.0;

    // Starts with query gets high score
    if (lowercaseName.startsWith(lowercaseQuery)) return 0.8;

    // Contains query gets medium score
    if (lowercaseName.contains(lowercaseQuery)) return 0.6;

    // Check for partial word matches
    final nameWords = lowercaseName.split(' ');
    final queryWords = lowercaseQuery.split(' ');

    int matchingWords = 0;
    for (final queryWord in queryWords) {
      for (final nameWord in nameWords) {
        if (nameWord.startsWith(queryWord) || nameWord.contains(queryWord)) {
          matchingWords++;
          break;
        }
      }
    }

    if (matchingWords > 0) {
      return 0.4 * (matchingWords / queryWords.length);
    }

    return 0.0;
  }

  /// Create a location for autocomplete/suggestion
  Map<String, dynamic> toSuggestion() {
    return {
      'id': id,
      'name': name,
      'display_text': name,
      'latitude': latitude,
      'longitude': longitude,
      'service_fee': serviceFee,
      'estimated_duration': estimatedDurationMinutes,
      'formatted_service_fee': formattedServiceFee,
      'formatted_duration': formattedEstimatedDuration,
    };
  }

  /// Check if this location is IT Del (default destination)
  bool get isITDel {
    return name.toLowerCase().contains('it del') ||
        name.toLowerCase().contains('institut teknologi del');
  }

  /// Get location priority for sorting (IT Del gets highest priority)
  int get sortPriority {
    if (isITDel) return 0;
    if (isActive) return 1;
    return 2;
  }

  // PRIVATE HELPER METHODS

  /// Convert degrees to radians
  static double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }
}
