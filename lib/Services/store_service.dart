import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:del_pick/Models/store.dart';
import 'core/api_constants.dart';
import 'core/token_service.dart';
import 'image_service.dart';

class StoreService {
  static Future<List<StoreModel>> fetchStores() async {
    try {
      final String? token = await TokenService.getToken();
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/stores'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        List<dynamic> storesJson = jsonData['data']['stores'];

        // Process each store, ensuring proper handling of images
        return storesJson.map((json) {
          // Ensure image URLs are properly formatted
          if (json['image'] != null) {
            json['image'] = ImageService.getImageUrl(json['image']);
          }
          return StoreModel.fromJson(json);
        }).toList();
      } else {
        throw Exception('Failed to load stores: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching stores: $e');
      throw Exception('Failed to load stores: $e');
    }
  }

  static Future<Store> fetchStoreById(int storeId) async {
    try {
      final String? token = await TokenService.getToken();
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/stores/$storeId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);

        // Format image URL if present
        if (jsonData['data']['image'] != null) {
          jsonData['data']['image'] = ImageService.getImageUrl(jsonData['data']['image']);
        }

        // Parse the store data
        final Store store = Store.fromJson(jsonData['data']);
        return store;
      } else {
        throw Exception('Failed to load store: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching store #$storeId: $e');
      throw Exception('Failed to load store: $e');
    }
  }

  static Future<Map<String, dynamic>> updateStoreProfile(Map<String, dynamic> storeData) async {
    try {
      final String? token = await TokenService.getToken();
      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/stores/update'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(storeData),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        return jsonData['data'];
      } else {
        throw Exception('Failed to update store profile: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating store profile: $e');
      throw Exception('Failed to update store profile: $e');
    }
  }

  static Future<bool> uploadStoreImage(int storeId, String base64Image) async {
    return ImageService.uploadStoreImage(storeId, base64Image);
  }

  // New method to update store status (active/inactive)
  static Future<Map<String, dynamic>> updateStoreStatus(int storeId, String status) async {
    try {
      // Validate status input
      if (status != 'active' && status != 'inactive') {
        throw Exception('Status tidak valid. Harus active atau inactive');
      }

      final String? token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/stores/$storeId/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'status': status,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        return jsonData['data'];
      } else if (response.statusCode == 403) {
        throw Exception('Tidak memiliki akses untuk mengubah status store');
      } else if (response.statusCode == 404) {
        throw Exception('Store tidak ditemukan');
      } else {
        throw Exception('Gagal mengupdate status store: ${response.body}');
      }
    } catch (e) {
      print('Error updating store status: $e');
      throw Exception('Gagal mengupdate status store: $e');
    }
  }
}