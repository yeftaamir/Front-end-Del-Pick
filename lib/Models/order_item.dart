import 'package:del_pick/Services/image_service.dart';
import 'order.dart';
import 'menu_item.dart';

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
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Relationship data
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
    this.createdAt,
    this.updatedAt,
    this.order,
    this.menuItem,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    String? processedImageUrl;
    if (json['image_url'] != null && json['image_url'].toString().isNotEmpty) {
      processedImageUrl = ImageService.getImageUrl(json['image_url']);
    }

    return OrderItem(
      id: json['id'] ?? 0,
      orderId: json['order_id'] ?? 0,
      menuItemId: json['menu_item_id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'],
      imageUrl: processedImageUrl,
      category: json['category'] ?? '',
      quantity: json['quantity'] ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
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
      if (description != null) 'description': description,
      if (imageUrl != null) 'image_url': imageUrl,
      'category': category,
      'quantity': quantity,
      'price': price,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      if (order != null) 'order': order!.toJson(),
      if (menuItem != null) 'menuItem': menuItem!.toJson(),
    };
  }

  OrderItem copyWith({
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
    DateTime? createdAt,
    DateTime? updatedAt,
    Order? order,
    MenuItem? menuItem,
  }) {
    return OrderItem(
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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      order: order ?? this.order,
      menuItem: menuItem ?? this.menuItem,
    );
  }

  double get totalPrice => price * quantity;

  String formatPrice() {
    return 'Rp${price.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  String formatTotalPrice() {
    return 'Rp${totalPrice.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }
}