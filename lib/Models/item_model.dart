// lib/Models/item_model.dart
class Item {
  final String id;
  final String name;
  final double price;
  final int quantity;
  final String imageUrl;

  Item({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    required this.imageUrl,
  });
}