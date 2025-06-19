// lib/models/entities/order_item.dart
import 'menu_item.dart';
import 'order.dart';

class OrderItem {
  final int id;
  final int orderId;
  final int menuItemId;
  final String name;
  final String? description;
  final String? imageUrl;
  final String category;
  final int quantity;
  final double price;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Relations
  final Order? order;
  final MenuItem? menuItem;

  OrderItem({
    required this.id,
    required this.orderId,
    required this.menuItemId,
    required this.name,
    this.description,
    this.imageUrl,
    required this.category,
    required this.quantity,
    required this.price,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.order,
    this.menuItem,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] as int,
      orderId: json['order_id'] as int,
      menuItemId: json['menu_item_id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      category: json['category'] as String,
      quantity: json['quantity'] as int,
      price: double.parse(json['price'].toString()),
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      order: json['order'] != null ? Order.fromJson(json['order']) : null,
      menuItem: json['menuItem'] != null ? MenuItem.fromJson(json['menuItem']) : null,
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
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (order != null) 'order': order!.toJson(),
      if (menuItem != null) 'menuItem': menuItem!.toJson(),
    };
  }

  double get totalPrice => price * quantity;
}