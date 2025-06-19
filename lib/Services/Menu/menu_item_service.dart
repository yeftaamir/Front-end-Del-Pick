// lib/services/menu/menu_item_service.dart
import '../../Models/Base/api_response.dart';
import '../../Models/Entities/menu_item.dart';
import '../../Models/Utils/model_utils.dart';
import '../Base/api_client.dart';

class MenuItemService {
  static const String _baseEndpoint = '/menu';

  // Get All Menu Items
  static Future<ApiResponse<List<MenuItem>>> getAllMenuItems({
    int page = 1,
    int limit = 10,
    String? search,
    String? category,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }

    if (category != null && category.isNotEmpty) {
      queryParams['category'] = category;
    }

    return await ApiClient.get<List<MenuItem>>(
      _baseEndpoint,
      queryParams: queryParams,
      fromJsonT: (data) => ModelUtils.parseList(data, (json) => MenuItem.fromJson(json)),
    );
  }

  // Get Menu Items by Store
  static Future<ApiResponse<List<MenuItem>>> getMenuItemsByStore(
      int storeId, {
        int page = 1,
        int limit = 20,
        String? category,
      }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (category != null && category.isNotEmpty) {
      queryParams['category'] = category;
    }

    return await ApiClient.get<List<MenuItem>>(
      '$_baseEndpoint/store/$storeId',
      queryParams: queryParams,
      fromJsonT: (data) => ModelUtils.parseList(data, (json) => MenuItem.fromJson(json)),
    );
  }

  // Get Menu Item by ID
  static Future<ApiResponse<MenuItem>> getMenuItemById(int menuItemId) async {
    return await ApiClient.get<MenuItem>(
      '$_baseEndpoint/$menuItemId',
      fromJsonT: (data) => MenuItem.fromJson(data),
    );
  }

  // Create Menu Item (Store Owner)
  static Future<ApiResponse<MenuItem>> createMenuItem(Map<String, dynamic> menuItemData) async {
    return await ApiClient.post<MenuItem>(
      _baseEndpoint,
      body: menuItemData,
      fromJsonT: (data) => MenuItem.fromJson(data),
    );
  }

  // Update Menu Item (Store Owner)
  static Future<ApiResponse<MenuItem>> updateMenuItem(
      int menuItemId,
      Map<String, dynamic> menuItemData,
      ) async {
    return await ApiClient.put<MenuItem>(
      '$_baseEndpoint/$menuItemId',
      body: menuItemData,
      fromJsonT: (data) => MenuItem.fromJson(data),
    );
  }

  // Delete Menu Item (Store Owner)
  static Future<ApiResponse<Map<String, dynamic>>> deleteMenuItem(int menuItemId) async {
    return await ApiClient.delete<Map<String, dynamic>>(
      '$_baseEndpoint/$menuItemId',
      fromJsonT: (data) => data as Map<String, dynamic>,
    );
  }

  // Update Menu Item Status (Store Owner)
  static Future<ApiResponse<MenuItem>> updateMenuItemStatus(
      int menuItemId,
      bool isAvailable,
      ) async {
    return await ApiClient.patch<MenuItem>(
      '$_baseEndpoint/$menuItemId/status',
      body: {'is_available': isAvailable},
      fromJsonT: (data) => MenuItem.fromJson(data),
    );
  }

  // Get Menu Categories by Store
  static Future<ApiResponse<List<String>>> getMenuCategories(int storeId) async {
    return await ApiClient.get<List<String>>(
      '$_baseEndpoint/store/$storeId/categories',
      fromJsonT: (data) => List<String>.from(data as List),
    );
  }
}