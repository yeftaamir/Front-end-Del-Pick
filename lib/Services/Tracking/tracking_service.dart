// lib/services/tracking/tracking_service.dart
import '../../Models/Base/api_response.dart';
import '../Base/api_client.dart';

class TrackingService {
  static const String _baseEndpoint = '/orders';

  // Get Tracking Data
  static Future<ApiResponse<Map<String, dynamic>>> getTrackingData(int orderId) async {
    return await ApiClient.get<Map<String, dynamic>>(
      '$_baseEndpoint/$orderId/tracking',
      fromJsonT: (data) => data as Map<String, dynamic>,
    );
  }

  // Start Delivery
  static Future<ApiResponse<Map<String, dynamic>>> startDelivery(int orderId) async {
    return await ApiClient.post<Map<String, dynamic>>(
      '$_baseEndpoint/$orderId/tracking/start',
      fromJsonT: (data) => data as Map<String, dynamic>,
    );
  }

  // Complete Delivery
  static Future<ApiResponse<Map<String, dynamic>>> completeDelivery(int orderId) async {
    return await ApiClient.post<Map<String, dynamic>>(
      '$_baseEndpoint/$orderId/tracking/complete',
      fromJsonT: (data) => data as Map<String, dynamic>,
    );
  }

  // Update Driver Location
  static Future<ApiResponse<Map<String, dynamic>>> updateDriverLocation(
      int orderId, {
        required double latitude,
        required double longitude,
      }) async {
    return await ApiClient.put<Map<String, dynamic>>(
      '$_baseEndpoint/$orderId/tracking/location',
      body: {
        'latitude': latitude,
        'longitude': longitude,
      },
      fromJsonT: (data) => data as Map<String, dynamic>,
    );
  }

  // Get Tracking History
  static Future<ApiResponse<Map<String, dynamic>>> getTrackingHistory(int orderId) async {
    return await ApiClient.get<Map<String, dynamic>>(
      '$_baseEndpoint/$orderId/tracking/history',
      fromJsonT: (data) => data as Map<String, dynamic>,
    );
  }

  // Real-time Location Updates (for WebSocket or Server-Sent Events)
  static Future<ApiResponse<Map<String, dynamic>>> subscribeToOrderUpdates(int orderId) async {
    return await ApiClient.get<Map<String, dynamic>>(
      '$_baseEndpoint/$orderId/tracking/subscribe',
      fromJsonT: (data) => data as Map<String, dynamic>,
    );
  }
}