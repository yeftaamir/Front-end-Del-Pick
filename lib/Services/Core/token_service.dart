// lib/services/core/token_service.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_constants.dart';

class TokenService {
  static final FlutterSecureStorage _storage = ApiConstants.storage;

  // Token Management
  static Future<void> saveToken(String token) async {
    await _storage.write(key: 'auth_token', value: token);
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: 'auth_token');
  }

  static Future<void> clearToken() async {
    await _storage.delete(key: 'auth_token');
  }

  // User Data Management
  static Future<void> saveUserRole(String role) async {
    await _storage.write(key: 'user_role', value: role);
  }

  static Future<String?> getUserRole() async {
    return await _storage.read(key: 'user_role');
  }

  static Future<void> saveUserId(dynamic id) async {
    await _storage.write(key: 'user_id', value: id.toString());
  }

  static Future<String?> getUserId() async {
    return await _storage.read(key: 'user_id');
  }

  static Future<void> saveUserData(String userData) async {
    await _storage.write(key: 'user_data', value: userData);
  }

  static Future<String?> getUserData() async {
    return await _storage.read(key: 'user_data');
  }

  // Complete cleanup
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  // Check authentication status
  static Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // Check user role
  static Future<bool> hasRole(List<String> roles) async {
    final userRole = await getUserRole();
    return userRole != null && roles.contains(userRole);
  }

  // Get authentication headers
  static Future<Map<String, String>> getAuthHeaders() async {
    final token = await getToken();
    final headers = Map<String, String>.from(ApiConstants.defaultHeaders);

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }
}