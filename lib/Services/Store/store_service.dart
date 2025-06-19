// lib/services/store/store_service.dart
import '../../Models/Base/api_response.dart';
import '../../Models/Entities/store.dart';
import '../../Models/Utils/model_utils.dart';
import '../Base/api_client.dart';

class StoreService {
  static const String _baseEndpoint = '/stores';

  // Get All Stores
  static Future<ApiResponse<List<Store>>> getAllStores({
    int page = 1,
    int limit = 10,
    String? search,
    Map<String, String>? filters,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }

    if (filters != null) {
      queryParams.addAll(filters);
    }

    return await ApiClient.get<List<Store>>(
      _baseEndpoint,
      queryParams: queryParams,
      fromJsonT: (data) {
        if (data is Map<String, dynamic> && data.containsKey('stores')) {
          return ModelUtils.parseList(data['stores'], (json) => Store.fromJson(json));
        } else if (data is List) {
          return ModelUtils.parseList(data, (json) => Store.fromJson(json));
        }
        return <Store>[];
      },
    );
  }

  // Get Store by ID
  static Future<ApiResponse<Store>> getStoreById(int storeId) async {
    return await ApiClient.get<Store>(
      '$_baseEndpoint/$storeId',
      fromJsonT: (data) => Store.fromJson(data),
    );
  }

  // Get Nearby Stores
  static Future<ApiResponse<List<Store>>> getNearbyStores({
    required double latitude,
    required double longitude,
    double radius = 10.0, // km
    int page = 1,
    int limit = 10,
  }) async {
    final queryParams = <String, String>{
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'radius': radius.toString(),
      'page': page.toString(),
      'limit': limit.toString(),
    };

    return await ApiClient.get<List<Store>>(
      '$_baseEndpoint/nearby',
      queryParams: queryParams,
      fromJsonT: (data) {
        if (data is Map<String, dynamic> && data.containsKey('stores')) {
          return ModelUtils.parseList(data['stores'], (json) => Store.fromJson(json));
        } else if (data is List) {
          return ModelUtils.parseList(data, (json) => Store.fromJson(json));
        }
        return <Store>[];
      },
    );
  }
}
