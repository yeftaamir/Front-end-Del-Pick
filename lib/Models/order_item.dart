// order_item_model.dart - Enhanced version
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

  // ✅ Safe parsing untuk numeric values
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    try {
      String? processedImageUrl;
      if (json['image_url'] != null &&
          json['image_url'].toString().isNotEmpty) {
        processedImageUrl = ImageService.getImageUrl(json['image_url']);
      }

      MenuItemModel? menuItem;
      if (json['menuItem'] != null) {
        try {
          menuItem = MenuItemModel.fromJson(json['menuItem']);
        } catch (e) {
          print('❌ Error parsing menuItem: $e');
        }
      }

      return OrderItemModel(
        id: _parseInt(json['id']),
        orderId: _parseInt(json['order_id']),
        menuItemId: _parseInt(json['menu_item_id']),
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        imageUrl: processedImageUrl,
        category: json['category']?.toString() ?? '',
        quantity: _parseInt(json['quantity']),
        price: _parseDouble(json['price']), // ✅ FIXED: Safe parsing
        notes: json['notes']?.toString(),
        menuItem: menuItem,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString())
            : null,
        updatedAt: json['updated_at'] != null
            ? DateTime.tryParse(json['updated_at'].toString())
            : null,
      );
    } catch (e) {
      print('❌ Error parsing OrderItemModel: $e');
      print('❌ JSON data: $json');
      rethrow;
    }
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

  // ✅ BACKEND ALIGNED: Total price calculation
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

  String? get processedImageUrl =>
      imageUrl != null ? ImageService.getImageUrl(imageUrl!) : null;

  // ✅ Additional helper methods
  bool get hasNotes => notes != null && notes!.isNotEmpty;
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
  bool get isValid => id > 0 && quantity > 0 && price > 0;

  @override
  String toString() {
    return 'OrderItemModel(id: $id, name: $name, quantity: $quantity, price: $price)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OrderItemModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
