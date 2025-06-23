// ========================================
// 6. lib/models/menu_item_model.dart
// ========================================

import 'package:del_pick/services/image_service.dart';

class MenuItemModel {
  final int id;
  final String name;
  final double price;
  final String description;
  final String? imageUrl;
  final int storeId;
  final String category;
  final bool isAvailable;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const MenuItemModel({
    required this.id,
    required this.name,
    required this.price,
    required this.storeId,
    required this.category,
    this.description = '',
    this.imageUrl,
    this.isAvailable = true,
    this.createdAt,
    this.updatedAt,
  });

  factory MenuItemModel.fromJson(Map<String, dynamic> json) {
    String? processedImageUrl;
    if (json['image_url'] != null && json['image_url'].toString().isNotEmpty) {
      processedImageUrl = ImageService.getImageUrl(json['image_url']);
    }

    return MenuItemModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      description: json['description'] ?? '',
      imageUrl: processedImageUrl,
      storeId: json['store_id'] ?? 0,
      category: json['category'] ?? '',
      isAvailable: json['is_available'] ?? true,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
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
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  MenuItemModel copyWith({
    int? id,
    String? name,
    double? price,
    String? description,
    String? imageUrl,
    int? storeId,
    String? category,
    bool? isAvailable,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MenuItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      storeId: storeId ?? this.storeId,
      category: category ?? this.category,
      isAvailable: isAvailable ?? this.isAvailable,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Utility methods
  String formatPrice() {
    return 'Rp ${price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
    )}';
  }

  String? get processedImageUrl => imageUrl != null ? ImageService.getImageUrl(imageUrl!) : null;

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
}