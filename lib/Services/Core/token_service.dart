// lib/services/core/token_service.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_constants.dart';

class TokenService {
  static final FlutterSecureStorage _storage = ApiConstants.storage;

  static Future<void> saveToken(String token) async {
    await _storage.write(key: 'auth_token', value: token);
  }

  static Future<void> saveUserRole(String role) async {
    await _storage.write(key: 'user_role', value: role);
  }

  static Future<void> saveUserId(int id) async {
    await _storage.write(key: 'user_id', value: id.toString());
  }

  static Future<String?> getUserData() async {
    return await _storage.read(key: 'user_data');
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: 'auth_token');
  }

  static Future<String?> getUserRole() async {
    return await _storage.read(key: 'user_role');
  }

  static Future<String?> getUserId() async {
    return await _storage.read(key: 'user_id');
  }

  static Future<void> clearToken() async {
    await _storage.delete(key: 'auth_token');
  }

  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}