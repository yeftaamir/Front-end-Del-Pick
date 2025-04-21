// lib/services/menu_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:del_pick/Models/menu_item.dart';
import 'package:del_pick/Models/item_model.dart';
import 'core/api_constants.dart';
import 'core/token_service.dart';
import 'image_service.dart';

class MenuService {
  static Future<List<MenuItem>> fetchMenuItemsByStoreId(String storeId) async {
    final String? token = await TokenService.getToken();
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/menu-items/store/$storeId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = json.decode(response.body);
      List<dynamic> menuItemsJson = jsonData['data']['menuItems'];

      // Process images in menu items
      menuItemsJson.forEach((item) {
        if (item['imageUrl'] != null) {
          item['imageUrl'] = ImageService.getImageUrl(item['imageUrl']);
        }
      });

      return menuItemsJson.map((json) => MenuItem.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load menu items');
    }
  }

  static Future<List<Item>> fetchItemsByStoreId(String storeId) async {
    final String? token = await TokenService.getToken();
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/menu-items/store/$storeId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = json.decode(response.body);
      List<dynamic> itemsJson = jsonData['data']['menuItems'];

      // Process images in items
      itemsJson.forEach((item) {
        if (item['imageUrl'] != null) {
          item['imageUrl'] = ImageService.getImageUrl(item['imageUrl']);
        }
      });

      return itemsJson.map((json) => Item.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load items');
    }
  }

  static Future<Item> getMenuItemById(int itemId) async {
    final String? token = await TokenService.getToken();
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/menu-items/$itemId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = json.decode(response.body);
      final data = jsonData['data'];

      // Process image if present
      if (data['imageUrl'] != null) {
        data['imageUrl'] = ImageService.getImageUrl(data['imageUrl']);
      }

      return Item.fromJson(data);
    } else {
      throw Exception('Failed to load menu item');
    }
  }

  static Future<List<Item>> getOwnMenuItems() async {
    final String? token = await TokenService.getToken();
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/menu-items'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = json.decode(response.body);
      List<dynamic> itemsJson = jsonData['data']['menuItems'];

      // Process images in items
      itemsJson.forEach((item) {
        if (item['imageUrl'] != null) {
          item['imageUrl'] = ImageService.getImageUrl(item['imageUrl']);
        }
      });

      return itemsJson.map((json) => Item.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load own menu items');
    }
  }

  static Future<Item> addItem(String name, int price, String description,
      int quantity, String imageUrl, bool isAvailable) async {
    try {
      final String? token = await TokenService.getToken();

      // First create the item without image
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/menu-items'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': name,
          'price': price,
          'description': description,
          'quantity': quantity,
          'isAvailable': isAvailable,
          'image': imageUrl.isNotEmpty ? imageUrl : null
        }),
      );

      if (response.statusCode == 201) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        final Item item = Item.fromJson(jsonData['data']);
        return item;
      } else {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        throw Exception('Failed to add item: ${jsonData['message']}');
      }
    } catch (e) {
      throw Exception('Failed to add item: $e');
    }
  }

  static Future<bool> updateItem(int itemId, Map<String, dynamic> itemData) async {
    final String? token = await TokenService.getToken();
    final response = await http.put(
      Uri.parse('${ApiConstants.baseUrl}/menu-items/$itemId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(itemData),
    );

    return response.statusCode == 200;
  }

  static Future<bool> deleteItem(int itemId) async {
    final String? token = await TokenService.getToken();
    final response = await http.delete(
      Uri.parse('${ApiConstants.baseUrl}/menu-items/$itemId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    return response.statusCode == 200;
  }

  static Future<bool> uploadItemImage(int itemId, String base64Image) async {
    return ImageService.uploadMenuItemImage(itemId, base64Image);
  }
}