
// lib/Models/improved_store.dart
import 'package:del_pick/Services/image_service.dart';

class StoreModel {
  final int id;
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
  final String status;
  final double? distance;

  // Owner info (from user table)
  final String? ownerName;
  final String? ownerEmail;
  final String? ownerPhone;
  final String? ownerAvatar;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  StoreModel({
    required this.id,
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
    this.status = 'active',
    this.distance,
    this.ownerName,
    this.ownerEmail,
    this.ownerPhone,
    this.ownerAvatar,
    this.createdAt,
    this.updatedAt,
  });

  factory StoreModel.fromJson(Map<String, dynamic> json) {
    // Handle nested structure from backend
    final Map<String, dynamic> storeData = json['store'] ?? json;
    final Map<String, dynamic> ownerData = storeData['owner'] ?? json['user'] ??
        {};

    // Process image URLs
    String? imageUrl = storeData['image_url'];
    if (imageUrl != null && imageUrl.isNotEmpty) {
      imageUrl = ImageService.getImageUrl(imageUrl);
    }

    String? ownerAvatar = ownerData['avatar'];
    if (ownerAvatar != null && ownerAvatar.isNotEmpty) {
      ownerAvatar = ImageService.getImageUrl(ownerAvatar);
    }

    return StoreModel(
      id: storeData['id'] ?? 0,
      name: storeData['name'] ?? '',
      address: storeData['address'] ?? '',
      description: storeData['description'] ?? '',
      phone: storeData['phone'] ?? '',
      openTime: storeData['open_time'] ?? '',
      closeTime: storeData['close_time'] ?? '',
      imageUrl: imageUrl,
      latitude: storeData['latitude'] != null ?
      double.tryParse(storeData['latitude'].toString()) : null,
      longitude: storeData['longitude'] != null ?
      double.tryParse(storeData['longitude'].toString()) : null,
      rating: (storeData['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: storeData['review_count'] ?? 0,
      totalProducts: storeData['total_products'] ?? 0,
      status: storeData['status'] ?? 'active',
      distance: storeData['distance'] != null ?
      double.tryParse(storeData['distance'].toString()) : null,
      ownerName: ownerData['name'],
      ownerEmail: ownerData['email'],
      ownerPhone: ownerData['phone'],
      ownerAvatar: ownerAvatar,
      createdAt: storeData['created_at'] != null ?
      DateTime.parse(storeData['created_at']) : null,
      updatedAt: storeData['updated_at'] != null ?
      DateTime.parse(storeData['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
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
      'status': status,
      'distance': distance,
      if (ownerName != null) 'owner': {
        'name': ownerName,
        'email': ownerEmail,
        'phone': ownerPhone,
        'avatar': ownerAvatar,
      },
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  StoreModel copyWith({
    int? id,
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
    String? status,
    double? distance,
    String? ownerName,
    String? ownerEmail,
    String? ownerPhone,
    String? ownerAvatar,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StoreModel(
      id: id ?? this.id,
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
      ownerName: ownerName ?? this.ownerName,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      ownerPhone: ownerPhone ?? this.ownerPhone,
      ownerAvatar: ownerAvatar ?? this.ownerAvatar,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Helper getters
  String get formattedRating => '$rating dari 5 ($reviewCount reviews)';

  String get formattedProductCount => '$totalProducts Produk';

  String get openHours => '$openTime - $closeTime';

  bool get isOpen => status == 'active';

  // Get processed image URL
  String? getProcessedImageUrl() {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return null;
    }
    return ImageService.getImageUrl(imageUrl!);
  }

  // Get processed owner avatar URL
  String? getProcessedOwnerAvatarUrl() {
    if (ownerAvatar == null || ownerAvatar!.isEmpty) {
      return null;
    }
    return ImageService.getImageUrl(ownerAvatar!);
  }
}