import 'package:del_pick/Services/image_service.dart';

class Item {
  final String id;
  final String name;
  final String? description;
  final double price;
  final int quantity;
  final String imageUrl;
  final bool isAvailable;
  final String status;
  final String? notes;
  final int? orderId; // Added to match backend OrderItem model

  Item({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.quantity,
    required this.imageUrl,
    required this.isAvailable,
    required this.status,
    this.notes,
    this.orderId,
  });

  Item copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    int? quantity,
    String? imageUrl,
    bool? isAvailable,
    String? status,
    String? notes,
    int? orderId,
  }) {
    return Item(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      imageUrl: imageUrl ?? this.imageUrl,
      isAvailable: isAvailable ?? this.isAvailable,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      orderId: orderId ?? this.orderId,
    );
  }

  // Format price (single item price)
  String formatPrice() {
    return 'Rp ${price.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  // Format total price (price × quantity)
  String formatTotalPrice() {
    double totalPrice = price * quantity;
    return 'Rp ${totalPrice.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  // From backend OrderItem model
  factory Item.fromJson(Map<String, dynamic> json) {
    // Process image URL if present
    String imageUrl = json['imageUrl'] ?? json['image_url'] ?? '';
    if (imageUrl.isNotEmpty) {
      imageUrl = ImageService.getImageUrl(imageUrl);
    }

    return Item(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? 'Unknown Name',
      description: json['description'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      quantity: json['quantity'] ?? 0,
      imageUrl: imageUrl,
      isAvailable: json['isAvailable'] ?? json['is_available'] ?? true,
      status: json['status'] ?? 'available',
      notes: json['notes'],
      orderId: json['orderId'],
    );
  }

  // Convert to match the backend's OrderItem model format
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'quantity': quantity,
      'imageUrl': imageUrl,
      'isAvailable': isAvailable,
      'status': status,
      'notes': notes,
      if (orderId != null) 'orderId': orderId,
    };
  }

  factory Item.fromMenuItem(Item menuItem) {
    // Process menu item's image URL
    String imageUrl = menuItem.imageUrl ?? '';
    if (imageUrl.isEmpty) {
      // No hardcoded fallback - the UI should handle missing images
      imageUrl = '';
    } else {
      imageUrl = ImageService.getImageUrl(imageUrl);
    }

    return Item(
      id: menuItem.id.toString(),
      name: menuItem.name,
      description: menuItem.description,
      price: menuItem.price,
      quantity: menuItem.quantity,
      imageUrl: imageUrl,
      isAvailable: menuItem.isAvailable,
      status: menuItem.status,
      orderId: null,
    );
  }

  // Get processed image URL
  String getProcessedImageUrl() {
    if (imageUrl.isEmpty) {
      return '';
    }
    return ImageService.getImageUrl(imageUrl);
  }
}
