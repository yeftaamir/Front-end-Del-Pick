class Item {
  final String id;
  final String name;
  final double price;
  final int quantity;
  final String imageUrl;
  final bool isAvailable;

  Item({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    required this.imageUrl,
    this.isAvailable = true,
  });

  Item copyWith({
    String? id,
    String? name,
    double? price,
    int? quantity,
    String? imageUrl,
    bool? isAvailable,
  }) {
    return Item(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      imageUrl: imageUrl ?? this.imageUrl,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }
}