// lib/services/user_service.dart
import 'package:flutter/foundation.dart';
import 'core/base_service.dart';
import 'image_service.dart';

class UserService extends BaseService {

  // Get user profile (same as auth profile but different endpoint)
  static Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await BaseService.get('/users/profile');

      if (response['data'] != null) {
        final profileData = response['data'];
        _processUserImages(profileData);
        return profileData;
      }

      return {};
    } catch (e) {
      debugPrint('Get user profile error: $e');
      rethrow;
    }
  }

  // Update user profile
  static Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> profileData) async {
    try {
      final response = await BaseService.put('/users/profile', profileData);

      if (response['data'] != null) {
        final updatedData = response['data'];
        _processUserImages(updatedData);
        return updatedData;
      }

      return {};
    } catch (e) {
      debugPrint('Update user profile error: $e');
      rethrow;
    }
  }

  // Get all users (admin only)
  static Future<Map<String, dynamic>> getAllUsers({
    int page = 1,
    int limit = 10,
    String? role,
    String? search,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (role != null) queryParams['role'] = role;
      if (search != null) queryParams['search'] = search;

      final response = await BaseService.get('/users', queryParams: queryParams);

      if (response['data'] != null && response['data'] is List) {
        for (var user in response['data']) {
          _processUserImages(user);
        }
      }

      return response;
    } catch (e) {
      debugPrint('Get all users error: $e');
      rethrow;
    }
  }

  // Get user by ID (admin only)
  static Future<Map<String, dynamic>> getUserById(String userId) async {
    try {
      final response = await BaseService.get('/users/$userId');

      if (response['data'] != null) {
        _processUserImages(response['data']);
      }

      return response['data'] ?? {};
    } catch (e) {
      debugPrint('Get user by ID error: $e');
      rethrow;
    }
  }

  // Update user by ID (admin only)
  static Future<Map<String, dynamic>> updateUserById(String userId, Map<String, dynamic> userData) async {
    try {
      final response = await BaseService.put('/users/$userId', userData);

      if (response['data'] != null) {
        _processUserImages(response['data']);
      }

      return response['data'] ?? {};
    } catch (e) {
      debugPrint('Update user by ID error: $e');
      rethrow;
    }
  }

  // Delete user by ID (admin only)
  static Future<bool> deleteUserById(String userId) async {
    try {
      await BaseService.delete('/users/$userId');
      return true;
    } catch (e) {
      debugPrint('Delete user by ID error: $e');
      rethrow;
    }
  }

  // PRIVATE HELPER METHODS

  static void _processUserImages(Map<String, dynamic> userData) {
    try {
      if (userData['avatar'] != null) {
        userData['avatar'] = ImageService.getImageUrl(userData['avatar']);
      }

      if (userData['profileImage'] != null) {
        userData['profileImage'] = ImageService.getImageUrl(userData['profileImage']);
      }
    } catch (e) {
      debugPrint('Process user images error: $e');
    }
  }
}