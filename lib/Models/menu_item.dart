class MenuItem {
  final String name;
  final double price;
  int quantity;

  MenuItem({
    required this.name,
    required this.price,
    this.quantity = 0,
  });
}