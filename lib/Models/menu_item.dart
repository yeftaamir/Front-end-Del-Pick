import 'package:del_pick/Services/image_service.dart';
import 'store.dart';

class MenuItem {
  final int id;
  final String name;
  final double price;
  final String? description;
  final String? imageUrl;
  final int storeId;
  final String category;
  final bool isAvailable;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Store relationship data
  final Store? store;

  // For cart functionality
  int quantity;

  MenuItem({
    required this.id,
    required this.name,
    required this.price,
    this.description,
    this.imageUrl,
    required this.storeId,
    required this.category,
    this.isAvailable = true,
    this.createdAt,
    this.updatedAt,
    this.store,
    this.quantity = 0,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    String? processedImageUrl;
    if (json['image_url'] != null && json['image_url'].toString().isNotEmpty) {
      processedImageUrl = ImageService.getImageUrl(json['image_url']);
    }

    return MenuItem(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      description: json['description'],
      imageUrl: processedImageUrl,
      storeId: json['store_id'] ?? 0,
      category: json['category'] ?? '',
      isAvailable: json['is_available'] ?? true,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      store: json['store'] != null ? Store.fromJson(json['store']) : null,
      quantity: json['quantity'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      if (description != null) 'description': description,
      if (imageUrl != null) 'image_url': imageUrl,
      'store_id': storeId,
      'category': category,
      'is_available': isAvailable,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      if (store != null) 'store': store!.toJson(),
      'quantity': quantity,
    };
  }

  MenuItem copyWith({
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
    Store? store,
    int? quantity,
  }) {
    return MenuItem(
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
      store: store ?? this.store,
      quantity: quantity ?? this.quantity,
    );
  }

  String getProcessedImageUrl() {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return '';
    }
    return ImageService.getImageUrl(imageUrl!);
  }

  String formatPrice() {
    return 'Rp ${price.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }
}