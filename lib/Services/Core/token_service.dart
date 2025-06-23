// lib/Services/core/token_service.dart
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_constants.dart';

class TokenService {
  static const FlutterSecureStorage _storage = ApiConstants.storage;

  /// Save authentication token
  static Future<void> saveToken(String token) async {
    try {
      await _storage.write(key: ApiConstants.tokenKey, value: token);
    } catch (e) {
      throw Exception('Failed to save token: $e');
    }
  }

  /// Get authentication token
  static Future<String?> getToken() async {
    try {
      return await _storage.read(key: ApiConstants.tokenKey);
    } catch (e) {
      print('Error reading token: $e');
      return null;
    }
  }

  /// Save user role
  static Future<void> saveUserRole(String role) async {
    try {
      await _storage.write(key: ApiConstants.userRoleKey, value: role);
    } catch (e) {
      throw Exception('Failed to save user role: $e');
    }
  }

  /// Get user role
  static Future<String?> getUserRole() async {
    try {
      return await _storage.read(key: ApiConstants.userRoleKey);
    } catch (e) {
      print('Error reading user role: $e');
      return null;
    }
  }

  /// Save user ID
  static Future<void> saveUserId(String userId) async {
    try {
      await _storage.write(key: ApiConstants.userIdKey, value: userId);
    } catch (e) {
      throw Exception('Failed to save user ID: $e');
    }
  }

  /// Get user ID
  static Future<String?> getUserId() async {
    try {
      return await _storage.read(key: ApiConstants.userIdKey);
    } catch (e) {
      print('Error reading user ID: $e');
      return null;
    }
  }

  /// Save user data
  static Future<void> saveUserData(Map<String, dynamic> userData) async {
    try {
      final userDataJson = jsonEncode(userData);
      await _storage.write(key: ApiConstants.userDataKey, value: userDataJson);
    } catch (e) {
      throw Exception('Failed to save user data: $e');
    }
  }

  /// Get user data
  static Future<Map<String, dynamic>?> getUserData() async {
    try {
      final userDataJson = await _storage.read(key: ApiConstants.userDataKey);
      if (userDataJson != null) {
        return jsonDecode(userDataJson);
      }
      return null;
    } catch (e) {
      print('Error reading user data: $e');
      return null;
    }
  }

  /// Save FCM token
  static Future<void> saveFcmToken(String fcmToken) async {
    try {
      await _storage.write(key: ApiConstants.fcmTokenKey, value: fcmToken);
    } catch (e) {
      throw Exception('Failed to save FCM token: $e');
    }
  }

  /// Get FCM token
  static Future<String?> getFcmToken() async {
    try {
      return await _storage.read(key: ApiConstants.fcmTokenKey);
    } catch (e) {
      print('Error reading FCM token: $e');
      return null;
    }
  }

  /// Clear specific token
  static Future<void> clearToken() async {
    try {
      await _storage.delete(key: ApiConstants.tokenKey);
    } catch (e) {
      throw Exception('Failed to clear token: $e');
    }
  }

  /// Clear all authentication data
  static Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      throw Exception('Failed to clear all data: $e');
    }
  }

  /// Check if user is authenticated
  static Future<bool> isAuthenticated() async {
    try {
      final token = await getToken();
      return token != null && token.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}