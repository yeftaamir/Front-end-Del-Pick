// lib/services/menu_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../Models/menu_item.dart';
import 'core/api_constants.dart';
import 'core/token_service.dart';
import 'image_service.dart';

class MenuService {
  /// Fetch all menu items (for store owner)
  static Future<Map<String, dynamic>> getAllMenuItems() async {
    try {
      final String? token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/menu-items'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);

        // Process images in menu items
        if (jsonData['data']['menuItems'] != null && jsonData['data']['menuItems'] is List) {
          for (var item in jsonData['data']['menuItems']) {
            if (item['imageUrl'] != null) {
              item['imageUrl'] = ImageService.getImageUrl(item['imageUrl']);
            }
          }
        }

        return jsonData['data'];
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to load menu items');
      }
    } catch (e) {
      print('Error fetching menu items: $e');
      throw Exception('Failed to load menu items: $e');
    }
  }

  /// Fetch menu items by store ID
  static Future<Map<String, dynamic>> getMenuItemsByStoreId(String storeId) async {
    try {
      final String? token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/menu-items/store/$storeId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);

        // Process images in menu items
        if (jsonData['data']['menuItems'] != null && jsonData['data']['menuItems'] is List) {
          for (var item in jsonData['data']['menuItems']) {
            if (item['imageUrl'] != null) {
              item['imageUrl'] = ImageService.getImageUrl(item['imageUrl']);
            }
          }
        }

        return jsonData['data'];
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to load menu items');
      }
    } catch (e) {
      print('Error fetching menu items for store: $e');
      throw Exception('Failed to load menu items: $e');
    }
  }

  /// Get menu item by ID
  static Future<Map<String, dynamic>> getMenuItemById(String itemId) async {
    try {
      final String? token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/menu-items/$itemId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);

        // Process image if present
        if (jsonData['data'] != null && jsonData['data']['imageUrl'] != null) {
          jsonData['data']['imageUrl'] = ImageService.getImageUrl(jsonData['data']['imageUrl']);
        }

        return jsonData['data'];
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to load menu item');
      }
    } catch (e) {
      print('Error fetching menu item: $e');
      throw Exception('Failed to load menu item: $e');
    }
  }

  /// Create new menu item (for store owner)
  static Future<Map<String, dynamic>> createMenuItem(Map<String, dynamic> menuItemData) async {
    try {
      final String? token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/menu-items'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(menuItemData),
      );

      if (response.statusCode == 201) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        return jsonData['data'];
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to create menu item');
      }
    } catch (e) {
      print('Error creating menu item: $e');
      throw Exception('Failed to create menu item: $e');
    }
  }

  /// Update menu item (for store owner)
  static Future<Map<String, dynamic>> updateMenuItem(String itemId, Map<String, dynamic> menuItemData) async {
    try {
      final String? token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/menu-items/$itemId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(menuItemData),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        return jsonData['data'];
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to update menu item');
      }
    } catch (e) {
      print('Error updating menu item: $e');
      throw Exception('Failed to update menu item: $e');
    }
  }

  /// Delete menu item (for store owner)
  static Future<bool> deleteMenuItem(String itemId) async {
    try {
      final String? token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.delete(
        Uri.parse('${ApiConstants.baseUrl}/menu-items/$itemId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to delete menu item');
      }
    } catch (e) {
      print('Error deleting menu item: $e');
      throw Exception('Failed to delete menu item: $e');
    }
  }
}