// lib/Models/tracking_update.dart
import 'dart:convert';

class TrackingLocationModel {
  final double latitude;
  final double longitude;

  const TrackingLocationModel({
    required this.latitude,
    required this.longitude,
  });

  factory TrackingLocationModel.fromJson(Map<String, dynamic> json) {
    return TrackingLocationModel(
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  TrackingLocationModel copyWith({
    double? latitude,
    double? longitude,
  }) {
    return TrackingLocationModel(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  String get coordinatesString {
    return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  }

  bool get isValid => latitude != 0.0 && longitude != 0.0;
}

class TrackingEstimatedTimesModel {
  final DateTime? pickup;
  final DateTime? delivery;

  const TrackingEstimatedTimesModel({
    this.pickup,
    this.delivery,
  });

  factory TrackingEstimatedTimesModel.fromJson(Map<String, dynamic> json) {
    return TrackingEstimatedTimesModel(
      pickup: json['pickup'] != null ? DateTime.parse(json['pickup']) : null,
      delivery: json['delivery'] != null ? DateTime.parse(json['delivery']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (pickup != null) 'pickup': pickup!.toIso8601String(),
      if (delivery != null) 'delivery': delivery!.toIso8601String(),
    };
  }

  TrackingEstimatedTimesModel copyWith({
    DateTime? pickup,
    DateTime? delivery,
  }) {
    return TrackingEstimatedTimesModel(
      pickup: pickup ?? this.pickup,
      delivery: delivery ?? this.delivery,
    );
  }
}

class TrackingDistancesModel {
  final double? toStore;
  final double? toDestination;
  final double? total;

  const TrackingDistancesModel({
    this.toStore,
    this.toDestination,
    this.total,
  });

  factory TrackingDistancesModel.fromJson(Map<String, dynamic> json) {
    return TrackingDistancesModel(
      toStore: json['to_store']?.toDouble(),
      toDestination: json['to_destination']?.toDouble(),
      total: json['total']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (toStore != null) 'to_store': toStore,
      if (toDestination != null) 'to_destination': toDestination,
      if (total != null) 'total': total,
    };
  }

  TrackingDistancesModel copyWith({
    double? toStore,
    double? toDestination,
    double? total,
  }) {
    return TrackingDistancesModel(
      toStore: toStore ?? this.toStore,
      toDestination: toDestination ?? this.toDestination,
      total: total ?? this.total,
    );
  }

  String get formattedDistanceToStore {
    if (toStore == null) return 'Tidak tersedia';
    return '${toStore!.toStringAsFixed(1)} km';
  }

  String get formattedDistanceToDestination {
    if (toDestination == null) return 'Tidak tersedia';
    return '${toDestination!.toStringAsFixed(1)} km';
  }

  String get formattedTotalDistance {
    if (total == null) return 'Tidak tersedia';
    return '${total!.toStringAsFixed(1)} km';
  }
}

class TrackingUpdateModel {
  final DateTime timestamp;
  final String status;
  final String message;
  final TrackingLocationModel? location;
  final TrackingEstimatedTimesModel? estimatedTimes;
  final TrackingDistancesModel? distances;
  final Map<String, dynamic>? additionalData;

  const TrackingUpdateModel({
    required this.timestamp,
    required this.status,
    required this.message,
    this.location,
    this.estimatedTimes,
    this.distances,
    this.additionalData,
  });

  factory TrackingUpdateModel.fromJson(Map<String, dynamic> json) {
    return TrackingUpdateModel(
      timestamp: DateTime.parse(json['timestamp']),
      status: json['status'] ?? '',
      message: json['message'] ?? '',
      location: json['location'] != null
          ? TrackingLocationModel.fromJson(json['location'])
          : null,
      estimatedTimes: json['estimated_times'] != null
          ? TrackingEstimatedTimesModel.fromJson(json['estimated_times'])
          : null,
      distances: json['distances'] != null
          ? TrackingDistancesModel.fromJson(json['distances'])
          : null,
      additionalData: json['additional_data'] != null
          ? Map<String, dynamic>.from(json['additional_data'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'status': status,
      'message': message,
      if (location != null) 'location': location!.toJson(),
      if (estimatedTimes != null) 'estimated_times': estimatedTimes!.toJson(),
      if (distances != null) 'distances': distances!.toJson(),
      if (additionalData != null) 'additional_data': additionalData,
    };
  }

  TrackingUpdateModel copyWith({
    DateTime? timestamp,
    String? status,
    String? message,
    TrackingLocationModel? location,
    TrackingEstimatedTimesModel? estimatedTimes,
    TrackingDistancesModel? distances,
    Map<String, dynamic>? additionalData,
  }) {
    return TrackingUpdateModel(
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      message: message ?? this.message,
      location: location ?? this.location,
      estimatedTimes: estimatedTimes ?? this.estimatedTimes,
      distances: distances ?? this.distances,
      additionalData: additionalData ?? this.additionalData,
    );
  }

  // Utility methods
  String get formattedTime {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  String get formattedDate {
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }

  String get formattedDateTime {
    return '$formattedDate $formattedTime';
  }

  String get relativeTime {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays} hari lalu';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} jam lalu';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} menit lalu';
    } else {
      return 'Baru saja';
    }
  }

  bool get hasLocation => location != null && location!.isValid;
  bool get hasEstimatedTimes => estimatedTimes != null;
  bool get hasDistances => distances != null;

  String get statusDisplayText {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Menunggu';
      case 'confirmed':
        return 'Dikonfirmasi';
      case 'preparing':
        return 'Dipersiapkan';
      case 'ready_for_pickup':
        return 'Siap Diambil';
      case 'on_delivery':
        return 'Dalam Pengiriman';
      case 'delivered':
        return 'Terkirim';
      case 'cancelled':
        return 'Dibatalkan';
      case 'rejected':
        return 'Ditolak';
      default:
        return status;
    }
  }

  String get statusIcon {
    switch (status.toLowerCase()) {
      case 'pending':
        return '⏳';
      case 'confirmed':
        return '✅';
      case 'preparing':
        return '👨‍🍳';
      case 'ready_for_pickup':
        return '📦';
      case 'on_delivery':
        return '🚗';
      case 'delivered':
        return '✅';
      case 'cancelled':
        return '❌';
      case 'rejected':
        return '❌';
      default:
        return '📍';
    }
  }

  String get statusColor {
    switch (status.toLowerCase()) {
      case 'pending':
        return '#FFA500'; // Orange
      case 'confirmed':
        return '#4CAF50'; // Green
      case 'preparing':
        return '#2196F3'; // Blue
      case 'ready_for_pickup':
        return '#FF9800'; // Dark Orange
      case 'on_delivery':
        return '#9C27B0'; // Purple
      case 'delivered':
        return '#4CAF50'; // Green
      case 'cancelled':
        return '#F44336'; // Red
      case 'rejected':
        return '#F44336'; // Red
      default:
        return '#757575'; // Grey
    }
  }

  // Create tracking update instances for common scenarios
  static TrackingUpdateModel orderPlaced() {
    return TrackingUpdateModel(
      timestamp: DateTime.now(),
      status: 'pending',
      message: 'Pesanan telah dibuat dan sedang diproses',
    );
  }

  static TrackingUpdateModel orderConfirmed() {
    return TrackingUpdateModel(
      timestamp: DateTime.now(),
      status: 'confirmed',
      message: 'Pesanan dikonfirmasi oleh toko',
    );
  }

  static TrackingUpdateModel orderPreparing() {
    return TrackingUpdateModel(
      timestamp: DateTime.now(),
      status: 'preparing',
      message: 'Pesanan sedang dipersiapkan',
    );
  }

  static TrackingUpdateModel orderReadyForPickup() {
    return TrackingUpdateModel(
      timestamp: DateTime.now(),
      status: 'ready_for_pickup',
      message: 'Pesanan siap untuk diambil driver',
    );
  }

  static TrackingUpdateModel deliveryStarted({
    TrackingLocationModel? driverLocation,
    TrackingEstimatedTimesModel? estimatedTimes,
  }) {
    return TrackingUpdateModel(
      timestamp: DateTime.now(),
      status: 'on_delivery',
      message: 'Driver mulai mengantar pesanan',
      location: driverLocation,
      estimatedTimes: estimatedTimes,
    );
  }

  static TrackingUpdateModel locationUpdate({
    required TrackingLocationModel location,
    TrackingDistancesModel? distances,
  }) {
    return TrackingUpdateModel(
      timestamp: DateTime.now(),
      status: 'on_delivery',
      message: 'Update lokasi driver',
      location: location,
      distances: distances,
    );
  }

  static TrackingUpdateModel orderDelivered({
    TrackingLocationModel? finalLocation,
  }) {
    return TrackingUpdateModel(
      timestamp: DateTime.now(),
      status: 'delivered',
      message: 'Pesanan telah sampai di tujuan',
      location: finalLocation,
    );
  }

  static TrackingUpdateModel orderCancelled({
    required String reason,
  }) {
    return TrackingUpdateModel(
      timestamp: DateTime.now(),
      status: 'cancelled',
      message: 'Pesanan dibatalkan: $reason',
    );
  }

  // Parse tracking updates from JSON array (from backend)
  static List<TrackingUpdateModel> parseTrackingUpdates(dynamic trackingUpdatesData) {
    try {
      if (trackingUpdatesData == null) return [];

      List<dynamic> updatesList = [];

      if (trackingUpdatesData is String) {
        // Parse JSON string
        final parsed = jsonDecode(trackingUpdatesData);
        if (parsed is List) {
          updatesList = parsed;
        }
      } else if (trackingUpdatesData is List) {
        updatesList = trackingUpdatesData;
      }

      return updatesList
          .map((update) => TrackingUpdateModel.fromJson(Map<String, dynamic>.from(update)))
          .toList();
    } catch (e) {
      print('Error parsing tracking updates: $e');
      return [];
    }
  }

  // Sort tracking updates by timestamp (newest first)
  static List<TrackingUpdateModel> sortByTimestamp(List<TrackingUpdateModel> updates) {
    final sortedUpdates = [...updates];
    sortedUpdates.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sortedUpdates;
  }

  // Get the latest update from a list
  static TrackingUpdateModel? getLatestUpdate(List<TrackingUpdateModel> updates) {
    if (updates.isEmpty) return null;
    return sortByTimestamp(updates).first;
  }

  // Get timeline of updates for UI display (chronological order)
  static List<TrackingUpdateModel> getTimelineUpdates(List<TrackingUpdateModel> updates) {
    final sortedUpdates = [...updates];
    sortedUpdates.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return sortedUpdates;
  }
}