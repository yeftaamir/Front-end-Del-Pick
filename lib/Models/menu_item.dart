class MenuItem {
  final String id;
  final String name;
  final double price;
  String? description;
  String? imageUrl;
  int quantity;

  MenuItem({
    required this.id,
    required this.name,
    required this.price,
    this.description,
    this.imageUrl = 'assets/images/menu_item.jpg',
    this.quantity = 0
  });
}