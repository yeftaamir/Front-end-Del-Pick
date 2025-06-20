import 'package:del_pick/Services/image_service.dart';
import 'user.dart';

class Store {
  final int id;
  final int userId;
  final String name;
  final String address;
  final String description;
  final String? openTime;
  final String? closeTime;
  final double? rating;
  final int? totalProducts;
  final String? imageUrl;
  final String phone;
  final int? reviewCount;
  final double latitude;
  final double longitude;
  final double? distance;
  final String status; // 'active', 'inactive', 'closed'
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // User relationship data
  final User? owner;

  Store({
    required this.id,
    required this.userId,
    required this.name,
    required this.address,
    this.description = '',
    this.openTime,
    this.closeTime,
    this.rating,
    this.totalProducts,
    this.imageUrl,
    required this.phone,
    this.reviewCount,
    required this.latitude,
    required this.longitude,
    this.distance,
    this.status = 'active',
    this.createdAt,
    this.updatedAt,
    this.owner,
  });

  factory Store.fromJson(Map<String, dynamic> json) {
    String? processedImageUrl;
    if (json['image_url'] != null && json['image_url'].toString().isNotEmpty) {
      processedImageUrl = ImageService.getImageUrl(json['image_url']);
    }

    return Store(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      description: json['description'] ?? '',
      openTime: json['open_time'],
      closeTime: json['close_time'],
      rating: json['rating'] != null ? double.tryParse(json['rating'].toString()) : null,
      totalProducts: json['total_products'],
      imageUrl: processedImageUrl,
      phone: json['phone'] ?? '',
      reviewCount: json['review_count'],
      latitude: double.tryParse(json['latitude']?.toString() ?? '0') ?? 0.0,
      longitude: double.tryParse(json['longitude']?.toString() ?? '0') ?? 0.0,
      distance: json['distance'] != null ? double.tryParse(json['distance'].toString()) : null,
      status: json['status'] ?? 'active',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      owner: json['owner'] != null ? User.fromJson(json['owner']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'address': address,
      'description': description,
      if (openTime != null) 'open_time': openTime,
      if (closeTime != null) 'close_time': closeTime,
      if (rating != null) 'rating': rating,
      if (totalProducts != null) 'total_products': totalProducts,
      if (imageUrl != null) 'image_url': imageUrl,
      'phone': phone,
      if (reviewCount != null) 'review_count': reviewCount,
      'latitude': latitude,
      'longitude': longitude,
      if (distance != null) 'distance': distance,
      'status': status,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      if (owner != null) 'owner': owner!.toJson(),
    };
  }

  Store copyWith({
    int? id,
    int? userId,
    String? name,
    String? address,
    String? description,
    String? openTime,
    String? closeTime,
    double? rating,
    int? totalProducts,
    String? imageUrl,
    String? phone,
    int? reviewCount,
    double? latitude,
    double? longitude,
    double? distance,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    User? owner,
  }) {
    return Store(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      address: address ?? this.address,
      description: description ?? this.description,
      openTime: openTime ?? this.openTime,
      closeTime: closeTime ?? this.closeTime,
      rating: rating ?? this.rating,
      totalProducts: totalProducts ?? this.totalProducts,
      imageUrl: imageUrl ?? this.imageUrl,
      phone: phone ?? this.phone,
      reviewCount: reviewCount ?? this.reviewCount,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      distance: distance ?? this.distance,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      owner: owner ?? this.owner,
    );
  }

  // Convenience getters
  String get openHours {
    if (openTime != null && closeTime != null) {
      return '$openTime - $closeTime';
    }
    return '';
  }

  String get formattedRating => '${rating ?? 0} dari 5';
  String get formattedProductCount => '${totalProducts ?? 0} Produk';
}