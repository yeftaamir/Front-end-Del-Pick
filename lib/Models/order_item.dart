class OrderItem {
  final int id;
  final int orderId;
  final String name;
  final int price;
  final int quantity;
  final String? imageUrl;

  OrderItem({
    required this.id,
    required this.orderId,
    required this.name,
    required this.price,
    required this.quantity,
    this.imageUrl,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] ?? 0,
      orderId: json['orderId'] ?? 0,
      name: json['name'] ?? '',
      price: json['price'] ?? 0,
      quantity: json['quantity'] ?? 0,
      imageUrl: json['imageUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orderId': orderId,
      'name': name,
      'price': price,
      'quantity': quantity,
      'imageUrl': imageUrl,
    };
  }

  OrderItem copyWith({
    int? id,
    int? orderId,
    String? name,
    int? price,
    int? quantity,
    String? imageUrl,
  }) {
    return OrderItem(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  // Format price for display
  String formatPrice() {
    return 'Rp${price.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  // Calculate total price for this item
  int get totalPrice => price * quantity;

  // Format total price for display
  String formatTotalPrice() {
    return 'Rp${totalPrice.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }
}