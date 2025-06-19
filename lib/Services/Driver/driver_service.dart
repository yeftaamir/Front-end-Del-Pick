// lib/services/driver/driver_service.dart
import '../../Models/Base/api_response.dart';
import '../../Models/Entities/driver.dart';
import '../../Models/Entities/order.dart';
import '../../Models/Enums/driver_status.dart';
import '../../Models/Utils/model_utils.dart';
import '../Base/api_client.dart';

class DriverService {
  static const String _baseEndpoint = '/drivers';

  // Get All Drivers
  static Future<ApiResponse<List<Driver>>> getAllDrivers({
    int page = 1,
    int limit = 10,
    DriverStatus? status,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (status != null) {
      queryParams['status'] = status.value;
    }

    return await ApiClient.get<List<Driver>>(
      _baseEndpoint,
      queryParams: queryParams,
      fromJsonT: (data) => ModelUtils.parseList(data, (json) => Driver.fromJson(json)),
    );
  }

  // Get Driver by ID
  static Future<ApiResponse<Driver>> getDriverById(int driverId) async {
    return await ApiClient.get<Driver>(
      '$_baseEndpoint/$driverId',
      fromJsonT: (data) => Driver.fromJson(data),
    );
  }

  // Get Driver Location
  static Future<ApiResponse<Map<String, dynamic>>> getDriverLocation(int driverId) async {
    return await ApiClient.get<Map<String, dynamic>>(
      '$_baseEndpoint/$driverId/location',
      fromJsonT: (data) => data as Map<String, dynamic>,
    );
  }

  // Update Driver Status
  static Future<ApiResponse<Driver>> updateDriverStatus(
      int driverId,
      DriverStatus status,
      ) async {
    return await ApiClient.patch<Driver>(
      '$_baseEndpoint/$driverId/status',
      body: {'status': status.value},
      fromJsonT: (data) => Driver.fromJson(data),
    );
  }

  // Update Driver Profile
  static Future<ApiResponse<Driver>> updateProfileDriver(
      int driverId,
      Map<String, dynamic> profileData,
      ) async {
    return await ApiClient.put<Driver>(
      '$_baseEndpoint/$driverId/profile',
      body: profileData,
      fromJsonT: (data) => Driver.fromJson(data),
    );
  }

  // Get Driver Orders
  static Future<ApiResponse<List<Order>>> getDriverOrders(
      int driverId, {
        int page = 1,
        int limit = 10,
      }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    return await ApiClient.get<List<Order>>(
      '$_baseEndpoint/$driverId/orders',
      queryParams: queryParams,
      fromJsonT: (data) => ModelUtils.parseList(data, (json) => Order.fromJson(json)),
    );
  }

  // Update Driver Location
  static Future<ApiResponse<Map<String, dynamic>>> updateDriverLocation(
      int driverId, {
        required double latitude,
        required double longitude,
      }) async {
    return await ApiClient.patch<Map<String, dynamic>>(
      '$_baseEndpoint/$driverId/location',
      body: {
        'latitude': latitude,
        'longitude': longitude,
      },
      fromJsonT: (data) => data as Map<String, dynamic>,
    );
  }

  // Get Available Drivers Near Location
  static Future<ApiResponse<List<Driver>>> getNearbyDrivers({
    required double latitude,
    required double longitude,
    double radius = 5.0, // km
  }) async {
    final queryParams = <String, String>{
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'radius': radius.toString(),
    };

    return await ApiClient.get<List<Driver>>(
      '$_baseEndpoint/nearby',
      queryParams: queryParams,
      fromJsonT: (data) => ModelUtils.parseList(data, (json) => Driver.fromJson(json)),
    );
  }
}