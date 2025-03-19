class Item {
  final String id;
  final String name;
  final String? description;
  final double price;
  final int quantity;
  final String imageUrl;
  final bool isAvailable;
  final String status;
  final String? notes; // Added notes field

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
}