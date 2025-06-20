// lib/services/menu_item_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'core/api_constants.dart';
import 'core/token_service.dart';
import 'image_service.dart';

class MenuItemService {
  /// Get all menu items
  static Future<Map<String, dynamic>> getAllMenuItems({
    int page = 1,
    int limit = 10,
    String? category,
    String? search,
  }) async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (category != null) queryParams['category'] = category;
      if (search != null) queryParams['search'] = search;

      final uri = Uri.parse('${ApiConstants.baseUrl}/menu')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = _parseResponseBody(response.body);

        // Process menu item images
        if (jsonData['data'] != null) {
          _processMenuItemList(jsonData['data']);
        }

        return jsonData['data'] ?? {};
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error fetching menu items: $e');
      throw Exception('Failed to get menu items: $e');
    }
    return {};
  }

  /// Get menu items by store ID
  static Future<Map<String, dynamic>> getMenuItemsByStore(String storeId, {
    int page = 1,
    int limit = 10,
    String? category,
    bool? isAvailable,
  }) async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (category != null) queryParams['category'] = category;
      if (isAvailable != null) queryParams['isAvailable'] = isAvailable.toString();

      final uri = Uri.parse('${ApiConstants.baseUrl}/menu/store/$storeId')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = _parseResponseBody(response.body);

        // Process menu item images
        if (jsonData['data'] != null) {
          _processMenuItemList(jsonData['data']);
        }

        return jsonData['data'] ?? {};
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error fetching menu items by store: $e');
      throw Exception('Failed to get menu items: $e');
    }
    return {};
  }

  /// Get menu item by ID
  static Future<Map<String, dynamic>> getMenuItemById(String itemId) async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/menu/$itemId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = _parseResponseBody(response.body);

        // Process menu item image
        if (jsonData['data'] != null) {
          _processMenuItemImage(jsonData['data']);
        }

        return jsonData['data'] ?? {};
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error fetching menu item: $e');
      throw Exception('Failed to get menu item: $e');
    }
    return {};
  }

  /// Create menu item (for store owners)
  static Future<Map<String, dynamic>> createMenuItem(Map<String, dynamic> menuItemData) async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/menu'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(menuItemData),
      );

      if (response.statusCode == 201) {
        final Map<String, dynamic> jsonData = _parseResponseBody(response.body);

        // Process menu item image
        if (jsonData['data'] != null) {
          _processMenuItemImage(jsonData['data']);
        }

        return jsonData['data'] ?? {};
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error creating menu item: $e');
      throw Exception('Failed to create menu item: $e');
    }
    return {};
  }

  /// Update menu item
  static Future<Map<String, dynamic>> updateMenuItem(String itemId, Map<String, dynamic> menuItemData) async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/menu/$itemId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(menuItemData),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = _parseResponseBody(response.body);

        // Process menu item image
        if (jsonData['data'] != null) {
          _processMenuItemImage(jsonData['data']);
        }

        return jsonData['data'] ?? {};
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error updating menu item: $e');
      throw Exception('Failed to update menu item: $e');
    }
    return {};
  }

  /// Delete menu item
  static Future<bool> deleteMenuItem(String itemId) async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.delete(
        Uri.parse('${ApiConstants.baseUrl}/menu/$itemId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error deleting menu item: $e');
      throw Exception('Failed to delete menu item: $e');
    }
    return false;
  }

  /// Update menu item status
  static Future<Map<String, dynamic>> updateMenuItemStatus(String itemId, bool isAvailable) async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.patch(
        Uri.parse('${ApiConstants.baseUrl}/menu/$itemId/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'isAvailable': isAvailable}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = _parseResponseBody(response.body);

        // Process menu item image
        if (jsonData['data'] != null) {
          _processMenuItemImage(jsonData['data']);
        }

        return jsonData['data'] ?? {};
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error updating menu item status: $e');
      throw Exception('Failed to update menu item status: $e');
    }
    return {};
  }

  // Helper methods
  static void _processMenuItemList(dynamic data) {
    List<dynamic> menuItems = [];

    if (data is List) {
      menuItems = data;
    } else if (data is Map && data['menuItems'] != null) {
      menuItems = data['menuItems'];
    }

    for (var item in menuItems) {
      _processMenuItemImage(item);
    }
  }

  static void _processMenuItemImage(Map<String, dynamic> menuItem) {
    if (menuItem['imageUrl'] != null && menuItem['imageUrl'].toString().isNotEmpty) {
      menuItem['imageUrl'] = ImageService.getImageUrl(menuItem['imageUrl']);
    }
    if (menuItem['image'] != null && menuItem['image'].toString().isNotEmpty) {
      menuItem['image'] = ImageService.getImageUrl(menuItem['image']);
    }
  }

  static Map<String, dynamic> _parseResponseBody(String body) {
    try {
      return json.decode(body);
    } catch (e) {
      throw Exception('Invalid response format: $body');
    }
  }

  static void _handleErrorResponse(http.Response response) {
    try {
      final errorData = _parseResponseBody(response.body);
      final message = errorData['message'] ?? 'Request failed';
      throw Exception(message);
    } catch (e) {
      throw Exception('Request failed with status ${response.statusCode}: ${response.body}');
    }
  }
}