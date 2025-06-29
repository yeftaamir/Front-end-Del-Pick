// lib/Services/core/token_service.dart
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_constants.dart';

class TokenService {
  static const FlutterSecureStorage _storage = ApiConstants.storage;
  static const int _tokenValidityDays = 7; // ✅ Sesuai backend (7 hari)
  static const bool _debugMode = false; // Toggle for debugging

  static void _log(String message) {
    if (_debugMode) print('🔑 TokenService: $message');
  }

  /// Save authentication token with timestamp and 7-day expiry
  static Future<void> saveToken(String token) async {
    try {
      final now = DateTime.now();
      final expiryDate = now.add(Duration(days: _tokenValidityDays));

      final tokenData = {
        'token': token,
        'savedAt': now.millisecondsSinceEpoch,
        'expiresAt': expiryDate.millisecondsSinceEpoch,
        'validityDays': _tokenValidityDays,
      };

      await _storage.write(
          key: ApiConstants.tokenKey, value: jsonEncode(tokenData));

      _log(
          'Token saved successfully - expires in $_tokenValidityDays days (${expiryDate.toLocal()})');
    } catch (e) {
      _log('Error saving token: $e');
      throw Exception('Failed to save token: $e');
    }
  }

  /// Get authentication token with automatic expiry validation
  static Future<String?> getToken() async {
    try {
      final tokenDataJson = await _storage.read(key: ApiConstants.tokenKey);
      if (tokenDataJson == null) {
        _log('No token found in storage');
        return null;
      }

      final tokenData = jsonDecode(tokenDataJson);
      final token = tokenData['token'] as String?;
      final expiresAt = tokenData['expiresAt'] as int?;

      if (token == null || token.isEmpty) {
        _log('Invalid token format - token is null or empty');
        await clearToken();
        return null;
      }

      if (expiresAt == null) {
        _log('Invalid token format - no expiry timestamp');
        await clearToken();
        return null;
      }

      // Check if token is expired (7 days have passed)
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now >= expiresAt) {
        final expiredDate = DateTime.fromMillisecondsSinceEpoch(expiresAt);
        _log(
            'Token expired on ${expiredDate.toLocal()} ($_tokenValidityDays days), clearing...');
        await clearToken();
        return null;
      }

      final remainingDays = ((expiresAt - now) / (1000 * 60 * 60 * 24)).ceil();
      _log('Token valid - expires in $remainingDays day(s)');

      return token;
    } catch (e) {
      _log('Error reading token: $e');
      // Clear potentially corrupted token data
      try {
        await clearToken();
      } catch (clearError) {
        _log('Error clearing corrupted token: $clearError');
      }
      return null;
    }
  }

  /// Check if token is still valid (not expired after 7 days)
  static Future<bool> isTokenValid() async {
    try {
      final tokenDataJson = await _storage.read(key: ApiConstants.tokenKey);
      if (tokenDataJson == null) {
        _log('No token to validate');
        return false;
      }

      final tokenData = jsonDecode(tokenDataJson);
      final expiresAt = tokenData['expiresAt'] as int?;

      if (expiresAt == null) {
        _log('Token has no expiry date - invalid format');
        await clearToken();
        return false;
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final isValid = now < expiresAt;

      if (!isValid) {
        final expiredDate = DateTime.fromMillisecondsSinceEpoch(expiresAt);
        _log('Token validation failed - expired on ${expiredDate.toLocal()}');
        await clearToken();
      } else {
        final remainingDays =
            ((expiresAt - now) / (1000 * 60 * 60 * 24)).ceil();
        _log('Token validation passed - $remainingDays day(s) remaining');
      }

      return isValid;
    } catch (e) {
      _log('Error checking token validity: $e');
      // Clear potentially corrupted data
      try {
        await clearToken();
      } catch (clearError) {
        _log('Error clearing token after validation error: $clearError');
      }
      return false;
    }
  }

  /// Get remaining time before token expires (in days)
  static Future<int> getTokenRemainingDays() async {
    try {
      final tokenDataJson = await _storage.read(key: ApiConstants.tokenKey);
      if (tokenDataJson == null) {
        _log('No token for remaining days calculation');
        return 0;
      }

      final tokenData = jsonDecode(tokenDataJson);
      final expiresAt = tokenData['expiresAt'] as int?;

      if (expiresAt == null) {
        _log('No expiry date in token data');
        return 0;
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final remainingMs = expiresAt - now;

      if (remainingMs <= 0) {
        _log('Token has already expired');
        await clearToken();
        return 0;
      }

      final remainingDays = (remainingMs / (1000 * 60 * 60 * 24)).ceil();
      _log('Token remaining days: $remainingDays');

      return remainingDays;
    } catch (e) {
      _log('Error getting token remaining days: $e');
      return 0;
    }
  }

  /// Get remaining time before token expires (in hours)
  static Future<int> getTokenRemainingHours() async {
    try {
      final tokenDataJson = await _storage.read(key: ApiConstants.tokenKey);
      if (tokenDataJson == null) return 0;

      final tokenData = jsonDecode(tokenDataJson);
      final expiresAt = tokenData['expiresAt'] as int?;

      if (expiresAt == null) return 0;

      final now = DateTime.now().millisecondsSinceEpoch;
      final remainingMs = expiresAt - now;

      if (remainingMs <= 0) {
        await clearToken();
        return 0;
      }

      final remainingHours = (remainingMs / (1000 * 60 * 60)).ceil();
      _log('Token remaining hours: $remainingHours');

      return remainingHours;
    } catch (e) {
      _log('Error getting token remaining hours: $e');
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
      _log('Error getting token saved date: $e');
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
      _log('Error getting token expiry date: $e');
      return null;
    }
  }

  /// Check if token is about to expire (within specified hours)
  static Future<bool> isTokenExpiringWithin({int hours = 24}) async {
    try {
      final remainingHours = await getTokenRemainingHours();
      final isExpiring = remainingHours <= hours && remainingHours > 0;

      if (isExpiring) {
        _log(
            'Token is expiring within $hours hours (remaining: $remainingHours hours)');
      }

      return isExpiring;
    } catch (e) {
      _log('Error checking if token is expiring: $e');
      return false;
    }
  }

  /// Save user role with validation
  static Future<void> saveUserRole(String role) async {
    try {
      final validRoles = [
        'customer',
        'store',
        'driver'
      ]; // ✅ Only 3 supported roles

      if (!validRoles.contains(role.toLowerCase())) {
        throw Exception(
            'Invalid role: $role. Only customer, store, and driver are supported.');
      }

      await _storage.write(key: ApiConstants.userRoleKey, value: role);
      _log('User role saved: $role');
    } catch (e) {
      _log('Error saving user role: $e');
      throw Exception('Failed to save user role: $e');
    }
  }

  /// Get user role with validation
  static Future<String?> getUserRole() async {
    try {
      final role = await _storage.read(key: ApiConstants.userRoleKey);

      if (role != null) {
        final validRoles = ['customer', 'store', 'driver'];
        if (!validRoles.contains(role.toLowerCase())) {
          _log('Invalid role found in storage: $role, clearing...');
          await _storage.delete(key: ApiConstants.userRoleKey);
          return null;
        }
      }

      _log('Retrieved user role: $role');
      return role;
    } catch (e) {
      _log('Error reading user role: $e');
      return null;
    }
  }

  /// Save user ID
  static Future<void> saveUserId(String userId) async {
    try {
      // Validate user ID is not empty
      if (userId.trim().isEmpty) {
        throw Exception('User ID cannot be empty');
      }

      await _storage.write(key: ApiConstants.userIdKey, value: userId);
      _log('User ID saved: $userId');
    } catch (e) {
      _log('Error saving user ID: $e');
      throw Exception('Failed to save user ID: $e');
    }
  }

  /// Get user ID
  static Future<String?> getUserId() async {
    try {
      final userId = await _storage.read(key: ApiConstants.userIdKey);
      _log('Retrieved user ID: $userId');
      return userId;
    } catch (e) {
      _log('Error reading user ID: $e');
      return null;
    }
  }

  /// Save user data with timestamp and validation
  static Future<void> saveUserData(Map<String, dynamic> userData) async {
    try {
      // Validate user data structure
      if (userData.isEmpty) {
        throw Exception('User data cannot be empty');
      }

      // Add metadata
      final userDataWithTimestamp = {
        ...userData,
        'savedAt': DateTime.now().millisecondsSinceEpoch,
        'cacheValidityDays': _tokenValidityDays,
      };

      final userDataJson = jsonEncode(userDataWithTimestamp);
      await _storage.write(key: ApiConstants.userDataKey, value: userDataJson);
      _log('User data saved with ${userData.keys.length} keys');
    } catch (e) {
      _log('Error saving user data: $e');
      throw Exception('Failed to save user data: $e');
    }
  }

  /// Get user data with automatic validation
  static Future<Map<String, dynamic>?> getUserData() async {
    try {
      final userDataJson = await _storage.read(key: ApiConstants.userDataKey);
      if (userDataJson == null) {
        _log('No user data found');
        return null;
      }

      final userData = jsonDecode(userDataJson);

      // Check if cached user data is still valid (aligned with token expiry)
      final savedAt = userData['savedAt'] as int?;
      if (savedAt != null) {
        final savedDate = DateTime.fromMillisecondsSinceEpoch(savedAt);
        final now = DateTime.now();
        final daysSinceSaved = now.difference(savedDate).inDays;

        if (daysSinceSaved >= _tokenValidityDays) {
          _log(
              'Cached user data expired after $_tokenValidityDays days, clearing...');
          await _storage.delete(key: ApiConstants.userDataKey);
          return null;
        }

        _log(
            'Retrieved valid cached user data (saved ${daysSinceSaved} days ago)');
      }

      return userData;
    } catch (e) {
      _log('Error reading user data: $e');
      // Clear potentially corrupted data
      try {
        await _storage.delete(key: ApiConstants.userDataKey);
      } catch (clearError) {
        _log('Error clearing corrupted user data: $clearError');
      }
      return null;
    }
  }

  /// Save FCM token
  static Future<void> saveFcmToken(String fcmToken) async {
    try {
      if (fcmToken.trim().isEmpty) {
        throw Exception('FCM token cannot be empty');
      }

      await _storage.write(key: ApiConstants.fcmTokenKey, value: fcmToken);
      _log('FCM token saved');
    } catch (e) {
      _log('Error saving FCM token: $e');
      throw Exception('Failed to save FCM token: $e');
    }
  }

  /// Get FCM token
  static Future<String?> getFcmToken() async {
    try {
      final fcmToken = await _storage.read(key: ApiConstants.fcmTokenKey);
      _log('Retrieved FCM token: ${fcmToken != null ? 'present' : 'null'}');
      return fcmToken;
    } catch (e) {
      _log('Error reading FCM token: $e');
      return null;
    }
  }

  /// Clear specific token only
  static Future<void> clearToken() async {
    try {
      await _storage.delete(key: ApiConstants.tokenKey);
      _log('Token cleared successfully');
    } catch (e) {
      _log('Error clearing token: $e');
      throw Exception('Failed to clear token: $e');
    }
  }

  /// Clear specific user data only
  static Future<void> clearUserData() async {
    try {
      await _storage.delete(key: ApiConstants.userDataKey);
      _log('User data cleared successfully');
    } catch (e) {
      _log('Error clearing user data: $e');
      throw Exception('Failed to clear user data: $e');
    }
  }

  /// Clear all authentication data
  static Future<void> clearAll() async {
    try {
      _log('Clearing all authentication data...');

      // Clear each key individually for better error tracking
      final clearTasks = [
        _storage.delete(key: ApiConstants.tokenKey),
        _storage.delete(key: ApiConstants.userRoleKey),
        _storage.delete(key: ApiConstants.userIdKey),
        _storage.delete(key: ApiConstants.userDataKey),
        _storage.delete(key: ApiConstants.fcmTokenKey),
      ];

      await Future.wait(clearTasks);
      _log('All authentication data cleared successfully');
    } catch (e) {
      _log('Error clearing authentication data: $e');

      // Fallback: try to clear everything with deleteAll
      try {
        await _storage.deleteAll();
        _log('Fallback: Used deleteAll() to clear storage');
      } catch (fallbackError) {
        _log('Fallback clearAll also failed: $fallbackError');
        throw Exception('Failed to clear authentication data: $e');
      }
    }
  }

  /// Check if user is authenticated (token exists and is valid)
  static Future<bool> isAuthenticated() async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) {
        _log('Authentication check failed: no valid token');
        return false;
      }

      final isValid = await isTokenValid();
      if (!isValid) {
        _log('Authentication check failed: token expired');
        return false;
      }

      _log('Authentication check passed: user has valid 7-day session');
      return true;
    } catch (e) {
      _log('Error checking authentication: $e');
      return false;
    }
  }

  /// Get comprehensive token information for debugging
  static Future<Map<String, dynamic>> getTokenInfo() async {
    try {
      final tokenDataJson = await _storage.read(key: ApiConstants.tokenKey);

      if (tokenDataJson == null) {
        return {
          'hasToken': false,
          'message': 'No token found in storage',
          'validityDays': _tokenValidityDays,
        };
      }

      final tokenData = jsonDecode(tokenDataJson);
      final savedAt = tokenData['savedAt'] as int?;
      final expiresAt = tokenData['expiresAt'] as int?;
      final validityDays =
          tokenData['validityDays'] as int? ?? _tokenValidityDays;

      if (savedAt == null || expiresAt == null) {
        return {
          'hasToken': true,
          'isValid': false,
          'message': 'Invalid token format - missing timestamps',
          'validityDays': validityDays,
        };
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final isValid = now < expiresAt;
      final remainingMs = expiresAt - now;
      final remainingDays =
          remainingMs > 0 ? (remainingMs / (1000 * 60 * 60 * 24)).ceil() : 0;
      final remainingHours =
          remainingMs > 0 ? (remainingMs / (1000 * 60 * 60)).ceil() : 0;

      final savedDate = DateTime.fromMillisecondsSinceEpoch(savedAt);
      final expiryDate = DateTime.fromMillisecondsSinceEpoch(expiresAt);

      return {
        'hasToken': true,
        'isValid': isValid,
        'savedAt': savedDate.toLocal().toString(),
        'expiresAt': expiryDate.toLocal().toString(),
        'validityDays': validityDays,
        'remainingDays': remainingDays,
        'remainingHours': remainingHours,
        'isExpiringSoon': remainingHours <= 24 && remainingHours > 0,
        'message': isValid
            ? 'Token valid for $remainingDays day(s) ($remainingHours hour(s))'
            : 'Token expired ${-remainingDays} day(s) ago',
      };
    } catch (e) {
      _log('Error getting token info: $e');
      return {
        'hasToken': false,
        'error': e.toString(),
        'validityDays': _tokenValidityDays,
      };
    }
  }

  /// Get storage statistics for debugging
  static Future<Map<String, dynamic>> getStorageStats() async {
    try {
      final keys = [
        ApiConstants.tokenKey,
        ApiConstants.userRoleKey,
        ApiConstants.userIdKey,
        ApiConstants.userDataKey,
        ApiConstants.fcmTokenKey,
      ];

      final stats = <String, dynamic>{
        'totalKeys': keys.length,
        'existingKeys': 0,
        'missingKeys': 0,
        'keyStatus': <String, bool>{},
      };

      for (final key in keys) {
        final value = await _storage.read(key: key);
        final exists = value != null;
        stats['keyStatus'][key] = exists;

        if (exists) {
          stats['existingKeys']++;
        } else {
          stats['missingKeys']++;
        }
      }

      _log(
          'Storage stats: ${stats['existingKeys']}/${stats['totalKeys']} keys present');
      return stats;
    } catch (e) {
      _log('Error getting storage stats: $e');
      return {'error': e.toString()};
    }
  }

  /// Force token refresh (useful for testing)
  static Future<bool> forceTokenRefresh() async {
    try {
      _log('Forcing token refresh...');

      final currentToken = await getToken();
      if (currentToken == null) {
        _log('No token to refresh');
        return false;
      }

      // Save the same token with new timestamps (extends for another 7 days)
      await saveToken(currentToken);
      _log(
          'Token refreshed successfully - extended for another $_tokenValidityDays days');

      return true;
    } catch (e) {
      _log('Error forcing token refresh: $e');
      return false;
    }
  }

  /// Validate all stored data integrity
  static Future<Map<String, dynamic>> validateDataIntegrity() async {
    try {
      _log('Validating data integrity...');

      final results = {
        'token': await _validateTokenIntegrity(),
        'userRole': await _validateUserRoleIntegrity(),
        'userId': await _validateUserIdIntegrity(),
        'userData': await _validateUserDataIntegrity(),
        'fcmToken': await _validateFcmTokenIntegrity(),
      };

      final issues =
          results.values.where((result) => !(result['valid'] as bool)).length;
      _log(
          'Data integrity check: ${results.length - issues}/${results.length} components valid');

      return {
        'overall': issues == 0,
        'issues': issues,
        'details': results,
      };
    } catch (e) {
      _log('Error validating data integrity: $e');
      return {'error': e.toString()};
    }
  }

  // Private validation methods
  static Future<Map<String, dynamic>> _validateTokenIntegrity() async {
    try {
      final tokenInfo = await getTokenInfo();
      return {
        'valid': tokenInfo['hasToken'] == true && tokenInfo['isValid'] == true,
        'details': tokenInfo,
      };
    } catch (e) {
      return {'valid': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> _validateUserRoleIntegrity() async {
    try {
      final role = await getUserRole();
      final validRoles = ['customer', 'store', 'driver'];
      final isValid = role != null && validRoles.contains(role.toLowerCase());

      return {
        'valid': isValid,
        'value': role,
        'supportedRoles': validRoles,
      };
    } catch (e) {
      return {'valid': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> _validateUserIdIntegrity() async {
    try {
      final userId = await getUserId();
      final isValid = userId != null && userId.trim().isNotEmpty;

      return {
        'valid': isValid,
        'value': userId,
      };
    } catch (e) {
      return {'valid': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> _validateUserDataIntegrity() async {
    try {
      final userData = await getUserData();
      final isValid = userData != null && userData.isNotEmpty;

      return {
        'valid': isValid,
        'keyCount': userData?.keys.length ?? 0,
        'hasUser': userData?['user'] != null,
      };
    } catch (e) {
      return {'valid': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> _validateFcmTokenIntegrity() async {
    try {
      final fcmToken = await getFcmToken();
      final isValid = fcmToken != null && fcmToken.trim().isNotEmpty;

      return {
        'valid': isValid,
        'present': fcmToken != null,
      };
    } catch (e) {
      return {'valid': false, 'error': e.toString()};
    }
  }
}
