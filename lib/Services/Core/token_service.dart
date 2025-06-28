// lib/Services/core/token_service.dart
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_constants.dart';

class TokenService {
  static const FlutterSecureStorage _storage = ApiConstants.storage;
  static const int _tokenValidityDays = 7; // Mengikuti backend (7 hari)

  /// Save authentication token with timestamp
  static Future<void> saveToken(String token) async {
    try {
      final tokenData = {
        'token': token,
        'savedAt': DateTime.now().millisecondsSinceEpoch,
        'expiresAt': DateTime.now()
            .add(Duration(days: _tokenValidityDays))
            .millisecondsSinceEpoch,
      };
      await _storage.write(
          key: ApiConstants.tokenKey, value: jsonEncode(tokenData));
    } catch (e) {
      throw Exception('Failed to save token: $e');
    }
  }

  /// Get authentication token (with automatic expiry check)
  static Future<String?> getToken() async {
    try {
      final tokenDataJson = await _storage.read(key: ApiConstants.tokenKey);
      if (tokenDataJson == null) return null;

      final tokenData = jsonDecode(tokenDataJson);
      final token = tokenData['token'] as String?;
      final expiresAt = tokenData['expiresAt'] as int?;

      if (token == null || expiresAt == null) return null;

      // Check if token is expired (7 days have passed)
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now >= expiresAt) {
        print('Token expired after 7 days, clearing...');
        await clearToken();
        return null;
      }

      return token;
    } catch (e) {
      print('Error reading token: $e');
      return null;
    }
  }

  /// Check if token is still valid (not expired after 7 days)
  static Future<bool> isTokenValid() async {
    try {
      final tokenDataJson = await _storage.read(key: ApiConstants.tokenKey);
      if (tokenDataJson == null) return false;

      final tokenData = jsonDecode(tokenDataJson);
      final expiresAt = tokenData['expiresAt'] as int?;

      if (expiresAt == null) return false;

      final now = DateTime.now().millisecondsSinceEpoch;
      return now < expiresAt;
    } catch (e) {
      print('Error checking token validity: $e');
      return false;
    }
  }

  /// Get remaining time before token expires (in days)
  static Future<int> getTokenRemainingDays() async {
    try {
      final tokenDataJson = await _storage.read(key: ApiConstants.tokenKey);
      if (tokenDataJson == null) return 0;

      final tokenData = jsonDecode(tokenDataJson);
      final expiresAt = tokenData['expiresAt'] as int?;

      if (expiresAt == null) return 0;

      final now = DateTime.now().millisecondsSinceEpoch;
      final remainingMs = expiresAt - now;

      if (remainingMs <= 0) return 0;

      return (remainingMs / (1000 * 60 * 60 * 24)).ceil(); // Convert to days
    } catch (e) {
      print('Error getting token remaining time: $e');
      return 0;
    }
  }

  /// Get token saved date
  static Future<DateTime?> getTokenSavedDate() async {
    try {
      final tokenDataJson = await _storage.read(key: ApiConstants.tokenKey);
      if (tokenDataJson == null) return null;

      final tokenData = jsonDecode(tokenDataJson);
      final savedAt = tokenData['savedAt'] as int?;

      if (savedAt == null) return null;

      return DateTime.fromMillisecondsSinceEpoch(savedAt);
    } catch (e) {
      print('Error getting token saved date: $e');
      return null;
    }
  }

  /// Get token expiry date
  static Future<DateTime?> getTokenExpiryDate() async {
    try {
      final tokenDataJson = await _storage.read(key: ApiConstants.tokenKey);
      if (tokenDataJson == null) return null;

      final tokenData = jsonDecode(tokenDataJson);
      final expiresAt = tokenData['expiresAt'] as int?;

      if (expiresAt == null) return null;

      return DateTime.fromMillisecondsSinceEpoch(expiresAt);
    } catch (e) {
      print('Error getting token expiry date: $e');
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

  /// Save user data with timestamp
  static Future<void> saveUserData(Map<String, dynamic> userData) async {
    try {
      final userDataWithTimestamp = {
        ...userData,
        'savedAt': DateTime.now().millisecondsSinceEpoch,
      };
      final userDataJson = jsonEncode(userDataWithTimestamp);
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

  /// Check if user is authenticated (token exists and is valid)
  static Future<bool> isAuthenticated() async {
    try {
      final token = await getToken();
      final isValid = await isTokenValid();
      return token != null && token.isNotEmpty && isValid;
    } catch (e) {
      return false;
    }
  }

  /// Get token info for debugging
  static Future<Map<String, dynamic>> getTokenInfo() async {
    try {
      final tokenDataJson = await _storage.read(key: ApiConstants.tokenKey);
      if (tokenDataJson == null) {
        return {'hasToken': false, 'message': 'No token found'};
      }

      final tokenData = jsonDecode(tokenDataJson);
      final savedAt = tokenData['savedAt'] as int?;
      final expiresAt = tokenData['expiresAt'] as int?;

      if (savedAt == null || expiresAt == null) {
        return {
          'hasToken': true,
          'isValid': false,
          'message': 'Invalid token format'
        };
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final isValid = now < expiresAt;
      final remainingDays = ((expiresAt - now) / (1000 * 60 * 60 * 24)).ceil();

      return {
        'hasToken': true,
        'isValid': isValid,
        'savedAt': DateTime.fromMillisecondsSinceEpoch(savedAt).toString(),
        'expiresAt': DateTime.fromMillisecondsSinceEpoch(expiresAt).toString(),
        'remainingDays': remainingDays > 0 ? remainingDays : 0,
        'message':
            isValid ? 'Token valid for $remainingDays days' : 'Token expired'
      };
    } catch (e) {
      return {'hasToken': false, 'error': e.toString()};
    }
  }
}
