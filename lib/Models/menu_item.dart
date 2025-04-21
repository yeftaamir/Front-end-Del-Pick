import 'package:del_pick/Services/image_service.dart';

class MenuItem {
  final int id;
  final String name;
  final double price;
  String? description;
  String? imageUrl;
  int quantity;
  final bool isAvailable;
  final String status;
  final int? storeId;  // Added to match backend

  MenuItem({
    required this.id,
    required this.name,
    required this.price,
    this.description,
    this.imageUrl,
    this.quantity = 0,
    this.isAvailable = true,
    this.status = 'available',
    this.storeId,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    // Process image URL if present
    String? imageUrl = json['imageUrl'] ?? json['image_url'];
    if (imageUrl != null && imageUrl.isNotEmpty) {
      imageUrl = ImageService.getImageUrl(imageUrl);
    } else {
      imageUrl = ''; // Empty string instead of hardcoded asset
    }

    return MenuItem(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      description: json['description'] ?? '',
      imageUrl: imageUrl,
      isAvailable: json['is_available'] ?? true,
      status: json['status'] ?? 'available',
      quantity: json['quantity'] ?? 0,
      storeId: json['storeId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'description': description,
      'image_url': imageUrl,
      'quantity': quantity,
      'is_available': isAvailable,
      'status': status,
      'storeId': storeId,
    };
  }

  MenuItem copyWith({
    int? id,
    String? name,
    double? price,
    String? description,
    String? imageUrl,
    int? quantity,
    bool? isAvailable,
    String? status,
    int? storeId,
  }) {
    return MenuItem(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      quantity: quantity ?? this.quantity,
      isAvailable: isAvailable ?? this.isAvailable,
      status: status ?? this.status,
      storeId: storeId ?? this.storeId,
    );
  }

  // Get processed image URL
  String getProcessedImageUrl() {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return '';
    }
    return ImageService.getImageUrl(imageUrl!);
  }
}