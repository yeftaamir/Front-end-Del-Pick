// lib/models/entities/store.dart
import 'package:del_pick/Models/Entities/user.dart';

import '../Enums/store_status.dart';
import 'menu_item.dart';

class Store {
  final int id;
  final int userId;
  final String name;
  final String address;
  final String? description;
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
  final StoreStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Relations
  final User? owner;
  final List<MenuItem>? menuItems;

  Store({
    required this.id,
    required this.userId,
    required this.name,
    required this.address,
    this.description,
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
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.owner,
    this.menuItems,
  });

  factory Store.fromJson(Map<String, dynamic> json) {
    return Store(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      name: json['name'] as String,
      address: json['address'] as String,
      description: json['description'] as String?,
      openTime: json['open_time'] as String?,
      closeTime: json['close_time'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      totalProducts: json['total_products'] as int?,
      imageUrl: json['image_url'] as String?,
      phone: json['phone'] as String,
      reviewCount: json['review_count'] as int?,
      latitude: double.parse(json['latitude'].toString()),
      longitude: double.parse(json['longitude'].toString()),
      distance: (json['distance'] as num?)?.toDouble(),
      status: StoreStatus.fromString(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      owner: json['owner'] != null ? User.fromJson(json['owner']) : null,
      menuItems: json['menu_items'] != null
          ? (json['menu_items'] as List)
          .map((item) => MenuItem.fromJson(item))
          .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'address': address,
      'description': description,
      'open_time': openTime,
      'close_time': closeTime,
      'rating': rating,
      'total_products': totalProducts,
      'image_url': imageUrl,
      'phone': phone,
      'review_count': reviewCount,
      'latitude': latitude,
      'longitude': longitude,
      'distance': distance,
      'status': status.value,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (owner != null) 'owner': owner!.toJson(),
      if (menuItems != null)
        'menu_items': menuItems!.map((item) => item.toJson()).toList(),
    };
  }
}