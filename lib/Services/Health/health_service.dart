// lib/services/health/health_service.dart
import '../../Models/Base/api_response.dart';
import '../Base/api_client.dart';

class HealthService {
  static const String _baseEndpoint = '/health';

  // Check Health
  static Future<ApiResponse<Map<String, dynamic>>> checkHealth() async {
    return await ApiClient.get<Map<String, dynamic>>(
      _baseEndpoint,
      requiresAuth: false,
      fromJsonT: (data) => data as Map<String, dynamic>,
    );
  }

  // Check Database
  static Future<ApiResponse<Map<String, dynamic>>> checkDatabase() async {
    return await ApiClient.get<Map<String, dynamic>>(
      '$_baseEndpoint/db',
      requiresAuth: false,
      fromJsonT: (data) => data as Map<String, dynamic>,
    );
  }

  // Check Cache
  static Future<ApiResponse<Map<String, dynamic>>> checkCache() async {
    return await ApiClient.get<Map<String, dynamic>>(
      '$_baseEndpoint/cache',
      requiresAuth: false,
      fromJsonT: (data) => data as Map<String, dynamic>,
    );
  }

  // Check Storage
  static Future<ApiResponse<Map<String, dynamic>>> checkStorage() async {
    return await ApiClient.get<Map<String, dynamic>>(
      '$_baseEndpoint/storage',
      requiresAuth: false,
      fromJsonT: (data) => data as Map<String, dynamic>,
    );
  }

  // Get System Status
  static Future<Map<String, bool>> getSystemStatus() async {
    try {
      final results = await Future.wait([
        checkHealth(),
        checkDatabase(),
        checkCache(),
        checkStorage(),
      ]);

      return {
        'health': results[0].isSuccess,
        'database': results[1].isSuccess,
        'cache': results[2].isSuccess,
        'storage': results[3].isSuccess,
      };
    } catch (e) {
      return {
        'health': false,
        'database': false,
        'cache': false,
        'storage': false,
      };
    }
  }
}