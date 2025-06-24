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
      id: _parseId(json['id']),
      name: json['name']?.toString() ?? '',
      price: _parsePrice(json['price']),
      description: json['description']?.toString() ?? '',
      imageUrl: processedImageUrl,
      storeId: _parseId(json['store_id']),
      category: json['category']?.toString() ?? '',
      isAvailable: _parseBool(json['is_available'] ?? json['isAvailable']),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
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

  // HELPER METHODS

  /// Parse price from various formats (string, int, double)
  static double _parsePrice(dynamic price) {
    try {
      if (price == null) return 0.0;

      if (price is double) return price;
      if (price is int) return price.toDouble();
      if (price is String) {
        // Remove any currency symbols and clean the string
        String cleanPrice = price
            .replaceAll('Rp', '')
            .replaceAll(' ', '')
            .replaceAll(',', '')
            .replaceAll('.', '') // Remove thousands separator
            .trim();

        if (cleanPrice.isEmpty) return 0.0;

        // If the original string had decimal places, handle differently
        if (price.contains('.') && price.split('.').length == 2) {
          // Check if it's a decimal format like "15000.00"
          final parts = price.replaceAll('Rp', '').replaceAll(' ', '').replaceAll(',', '').split('.');
          if (parts.length == 2 && parts[1].length <= 2) {
            // This is likely a decimal format
            return double.parse(price.replaceAll('Rp', '').replaceAll(' ', '').replaceAll(',', ''));
          }
        }

        return double.parse(cleanPrice);
      }

      return 0.0;
    } catch (e) {
      print('Error parsing price "$price": $e');
      return 0.0;
    }
  }

  /// Parse ID from various formats
  static int _parseId(dynamic id) {
    try {
      if (id == null) return 0;
      if (id is int) return id;
      if (id is String) return int.tryParse(id) ?? 0;
      if (id is double) return id.toInt();
      return 0;
    } catch (e) {
      print('Error parsing ID "$id": $e');
      return 0;
    }
  }

  /// Parse boolean from various formats
  static bool _parseBool(dynamic value) {
    try {
      if (value == null) return true; // Default to available
      if (value is bool) return value;
      if (value is String) {
        return value.toLowerCase() == 'true' || value == '1';
      }
      if (value is int) return value == 1;
      return true;
    } catch (e) {
      print('Error parsing boolean "$value": $e');
      return true;
    }
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