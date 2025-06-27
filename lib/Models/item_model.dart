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
      name: json['name']?.toString() ?? 'Unknown Name',
      description: json['description']?.toString() ?? '',
      price: _parsePrice(json['price']),
      quantity: _parseQuantity(json['quantity']),
      imageUrl: imageUrl,
      isAvailable: _parseBool(json['isAvailable'] ?? json['is_available']),
      status: json['status']?.toString() ?? 'available',
      notes: json['notes']?.toString(),
      orderId: _parseId(json['orderId']),
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
            .trim();

        if (cleanPrice.isEmpty) return 0.0;

        // Handle decimal format like "15000.00"
        if (price.contains('.') && price.split('.').length == 2) {
          final parts = price
              .replaceAll('Rp', '')
              .replaceAll(' ', '')
              .replaceAll(',', '')
              .split('.');
          if (parts.length == 2 && parts[1].length <= 2) {
            // This is likely a decimal format
            return double.parse(price
                .replaceAll('Rp', '')
                .replaceAll(' ', '')
                .replaceAll(',', ''));
          }
        }

        // Remove dots that are thousands separators
        cleanPrice = cleanPrice.replaceAll('.', '');
        return double.parse(cleanPrice);
      }

      return 0.0;
    } catch (e) {
      print('Error parsing price "$price": $e');
      return 0.0;
    }
  }

  /// Parse quantity from various formats
  static int _parseQuantity(dynamic quantity) {
    try {
      if (quantity == null) return 0;
      if (quantity is int) return quantity;
      if (quantity is String) return int.tryParse(quantity) ?? 0;
      if (quantity is double) return quantity.toInt();
      return 0;
    } catch (e) {
      print('Error parsing quantity "$quantity": $e');
      return 0;
    }
  }

  /// Parse ID from various formats
  static int? _parseId(dynamic id) {
    try {
      if (id == null) return null;
      if (id is int) return id;
      if (id is String) return int.tryParse(id);
      if (id is double) return id.toInt();
      return null;
    } catch (e) {
      print('Error parsing ID "$id": $e');
      return null;
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
}
