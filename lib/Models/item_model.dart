class Item {
  final String id;
  final String name;
  final String? description;
  final double price;
  final int quantity;
  final String imageUrl;
  final bool isAvailable;
  final String status;

  Item({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.quantity,
    required this.imageUrl,
    required this.isAvailable,
    required this.status,
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
    );
  }
}