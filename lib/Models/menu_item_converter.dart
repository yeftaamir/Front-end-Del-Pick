import 'package:del_pick/Models/item_model.dart';

class MenuItemConverter {
  // Convert from Item to MenuItem
  static List<MenuItem> fromItems(List<Item> items) {
    return items.map((item) => MenuItem(
        id: item.id,
        name: item.name,
        price: item.price,
        description: item.description,
        imageUrl: item.imageUrl,
        quantity: item.quantity
    )).toList();
  }
}

// Define MenuItem class for consistency
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