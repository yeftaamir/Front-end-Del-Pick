// ========================================
// 5. lib/models/store_model.dart
// ========================================

import 'package:del_pick/Models/user.dart';
import 'package:del_pick/services/image_service.dart';

import 'order_enum.dart';

class StoreModel {
  final UserModel owner;
  final int storeId;
  final String name;
  final String address;
  final String description;
  final String phone;
  final String openTime;
  final String closeTime;
  final String? imageUrl;
  final double? latitude;
  final double? longitude;
  final double rating;
  final int reviewCount;
  final int totalProducts;
  final StoreStatus status;
  final double? distance;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const StoreModel({
    required this.owner,
    required this.storeId,
    required this.name,
    required this.address,
    required this.phone,
    required this.openTime,
    required this.closeTime,
    this.description = '',
    this.imageUrl,
    this.latitude,
    this.longitude,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.totalProducts = 0,
    this.status = StoreStatus.active,
    this.distance,
    this.createdAt,
    this.updatedAt,
  });

  factory StoreModel.fromJson(Map<String, dynamic> json) {
    final storeData = json['store'] ?? json;
    final ownerData = storeData['owner'] ?? json['user'] ?? {};

    String? processedImageUrl;
    if (storeData['image_url'] != null && storeData['image_url'].toString().isNotEmpty) {
      processedImageUrl = ImageService.getImageUrl(storeData['image_url']);
    }

    return StoreModel(
      owner: UserModel.fromJson(ownerData),
      storeId: storeData['id'] ?? 0,
      name: storeData['name'] ?? '',
      address: storeData['address'] ?? '',
      description: storeData['description'] ?? '',
      phone: storeData['phone'] ?? '',
      openTime: storeData['open_time'] ?? '',
      closeTime: storeData['close_time'] ?? '',
      imageUrl: processedImageUrl,
      latitude: storeData['latitude']?.toDouble(),
      longitude: storeData['longitude']?.toDouble(),
      rating: (storeData['rating'] ?? 0.0).toDouble(),
      reviewCount: storeData['review_count'] ?? 0,
      totalProducts: storeData['total_products'] ?? 0,
      status: _parseStoreStatus(storeData['status']),
      distance: storeData['distance']?.toDouble(),
      createdAt: storeData['created_at'] != null
          ? DateTime.parse(storeData['created_at'])
          : null,
      updatedAt: storeData['updated_at'] != null
          ? DateTime.parse(storeData['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'store': {
        'id': storeId,
        'name': name,
        'address': address,
        'description': description,
        'phone': phone,
        'open_time': openTime,
        'close_time': closeTime,
        'image_url': imageUrl,
        'latitude': latitude,
        'longitude': longitude,
        'rating': rating,
        'review_count': reviewCount,
        'total_products': totalProducts,
        'status': status.name,
        'distance': distance,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      },
      'owner': owner.toJson(),
    };
  }

  StoreModel copyWith({
    UserModel? owner,
    int? storeId,
    String? name,
    String? address,
    String? description,
    String? phone,
    String? openTime,
    String? closeTime,
    String? imageUrl,
    double? latitude,
    double? longitude,
    double? rating,
    int? reviewCount,
    int? totalProducts,
    StoreStatus? status,
    double? distance,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StoreModel(
      owner: owner ?? this.owner,
      storeId: storeId ?? this.storeId,
      name: name ?? this.name,
      address: address ?? this.address,
      description: description ?? this.description,
      phone: phone ?? this.phone,
      openTime: openTime ?? this.openTime,
      closeTime: closeTime ?? this.closeTime,
      imageUrl: imageUrl ?? this.imageUrl,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      totalProducts: totalProducts ?? this.totalProducts,
      status: status ?? this.status,
      distance: distance ?? this.distance,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static StoreStatus _parseStoreStatus(dynamic status) {
    if (status == null) return StoreStatus.active;
    final statusString = status.toString().toLowerCase();
    return StoreStatus.values.firstWhere(
          (e) => e.name == statusString,
      orElse: () => StoreStatus.active,
    );
  }

  // Convenience getters
  int get ownerId => owner.id;
  String get ownerName => owner.name;
  String get ownerEmail => owner.email;

  // Utility methods
  bool get isOpen => status == StoreStatus.active;
  bool get hasLocation => latitude != null && longitude != null;

  String get formattedRating => '${rating.toStringAsFixed(1)} (${reviewCount} reviews)';
  String get formattedProductCount => '$totalProducts Products';
  String get openHours => '$openTime - $closeTime';

  String? get processedImageUrl => imageUrl != null ? ImageService.getImageUrl(imageUrl!) : null;

  String get statusDisplayName {
    switch (status) {
      case StoreStatus.active:
        return 'Open';
      case StoreStatus.inactive:
        return 'Temporarily Closed';
      case StoreStatus.closed:
        return 'Closed';
    }
  }

  String? get formattedDistance {
    if (distance == null) return null;
    if (distance! < 1) {
      return '${(distance! * 1000).round()}m';
    }
    return '${distance!.toStringAsFixed(1)}km';
  }
}
