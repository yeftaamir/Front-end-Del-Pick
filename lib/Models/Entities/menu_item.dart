// lib/models/entities/menu_item.dart
import 'package:del_pick/Models/Entities/store.dart';

class MenuItem {
  final int id;
  final String name;
  final double price;
  final String? description;
  final String? imageUrl;
  final int storeId;
  final String category;
  final bool isAvailable;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Relations
  final Store? store;

  MenuItem({
    required this.id,
    required this.name,
    required this.price,
    this.description,
    this.imageUrl,
    required this.storeId,
    required this.category,
    required this.isAvailable,
    required this.createdAt,
    required this.updatedAt,
    this.store,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'] as int,
      name: json['name'] as String,
      price: double.parse(json['price'].toString()),
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      storeId: json['store_id'] as int,
      category: json['category'] as String,
      isAvailable: json['is_available'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      store: json['store'] != null ? Store.fromJson(json['store']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'description': description,
      'image_url': imageUrl,
      'store_id': storeId,
      'category': category,
      'is_available': isAvailable,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (store != null) 'store': store!.toJson(),
    };
  }
}