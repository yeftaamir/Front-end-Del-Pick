// ========================================
// 7. lib/models/order_item_model.dart - FIXED VERSION
// ========================================

import 'package:del_pick/services/image_service.dart';

import 'menu_item.dart';

class OrderItemModel {
  final int id;
  final int orderId;
  final int menuItemId;
  final String name;
  final String description;
  final String? imageUrl;
  final String category;
  final int quantity;
  final double price;
  final String? notes;
  final MenuItemModel? menuItem;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const OrderItemModel({
    required this.id,
    required this.orderId,
    required this.menuItemId,
    required this.name,
    required this.quantity,
    required this.price,
    this.description = '',
    this.imageUrl,
    this.category = '',
    this.notes,
    this.menuItem,
    this.createdAt,
    this.updatedAt,
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

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    String? processedImageUrl;
    if (json['image_url'] != null && json['image_url'].toString().isNotEmpty) {
      processedImageUrl = ImageService.getImageUrl(json['image_url']);
    }

    MenuItemModel? menuItem;
    if (json['menuItem'] != null) {
      menuItem = MenuItemModel.fromJson(json['menuItem']);
    }

    return OrderItemModel(
      id: json['id'] ?? 0,
      orderId: json['order_id'] ?? 0,
      menuItemId: json['menu_item_id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      imageUrl: processedImageUrl,
      category: json['category'] ?? '',
      quantity: json['quantity'] ?? 1,
      // ✅ PERBAIKAN: Safe parsing untuk price field
      price: _parseDouble(json['price']),
      notes: json['notes'],
      menuItem: menuItem,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'menu_item_id': menuItemId,
      'name': name,
      'description': description,
      'image_url': imageUrl,
      'category': category,
      'quantity': quantity,
      'price': price,
      'notes': notes,
      if (menuItem != null) 'menuItem': menuItem!.toJson(),
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  OrderItemModel copyWith({
    int? id,
    int? orderId,
    int? menuItemId,
    String? name,
    String? description,
    String? imageUrl,
    String? category,
    int? quantity,
    double? price,
    String? notes,
    MenuItemModel? menuItem,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OrderItemModel(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      menuItemId: menuItemId ?? this.menuItemId,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      notes: notes ?? this.notes,
      menuItem: menuItem ?? this.menuItem,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Utility methods
  double get totalPrice => price * quantity;

  String formatPrice() {
    return 'Rp ${price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
    )}';
  }

  String formatTotalPrice() {
    return 'Rp ${totalPrice.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
    )}';
  }

  String? get processedImageUrl => imageUrl != null ? ImageService.getImageUrl(imageUrl!) : null;
}