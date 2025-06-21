// lib/services/auth_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'core/base_service.dart';
import 'core/token_service.dart';
import 'image_service.dart';

class AuthService extends BaseService {

  // Login with email and password
  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await BaseService.post('/auth/login', {
        'email': email,
        'password': password,
      }, requiresAuth: false);

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];

        // Save authentication data
        if (data['token'] != null) {
          await TokenService.saveToken(data['token']);
        }

        if (data['user'] != null) {
          final user = data['user'];
          await TokenService.saveUserRole(user['role'] ?? 'customer');
          await TokenService.saveUserId(user['id']);
          await _saveUserData(data);
        }

        debugPrint('Login successful for user: ${data['user']?['name']}');
        return data;
      }

      throw ApiException('Login failed: Invalid response format');
    } catch (e) {
      debugPrint('Login error: $e');
      rethrow;
    }
  }

  // Register new user
  static Future<Map<String, dynamic>> register(Map<String, dynamic> userData) async {
    try {
      final response = await BaseService.post('/auth/register', userData, requiresAuth: false);

      if (response['statusCode'] == 201) {
        return response['data'] ?? {};
      }

      throw ApiException('Registration failed');
    } catch (e) {
      debugPrint('Registration error: $e');
      rethrow;
    }
  }

  // Logout user
  static Future<bool> logout() async {
    try {
      // Try server-side logout first
      try {
        await BaseService.post('/auth/logout', {});
      } catch (e) {
        debugPrint('Server logout error (continuing with local cleanup): $e');
      }

      // Clear all local data
      await TokenService.clearAll();
      debugPrint('Logout completed successfully');
      return true;
    } catch (e) {
      debugPrint('Logout error: $e');
      // Still clear local data even if server logout fails
      await TokenService.clearAll();
      return false;
    }
  }

  // Get user profile
  static Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await BaseService.get('/auth/profile');

      if (response['statusCode'] == 200 && response['data'] != null) {
        final profileData = response['data'];
        _processProfileImages(profileData);

        // Update cached user data
        await TokenService.saveUserData(json.encode(profileData));

        return profileData;
      }

      return {};
    } catch (e) {
      debugPrint('Get profile error: $e');
      rethrow;
    }
  }

  // Update user profile
  static Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> profileData) async {
    try {
      final response = await BaseService.put('/auth/profile', profileData);

      if (response['statusCode'] == 200 && response['data'] != null) {
        final updatedData = response['data'];
        _processProfileImages(updatedData);

        // Update cached user data
        await TokenService.saveUserData(json.encode(updatedData));

        return updatedData;
      }

      return {};
    } catch (e) {
      debugPrint('Update profile error: $e');
      rethrow;
    }
  }

  // Forgot password
  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      return await BaseService.post('/auth/forgot-password', {'email': email}, requiresAuth: false);
    } catch (e) {
      debugPrint('Forgot password error: $e');
      rethrow;
    }
  }

  // Reset password
  static Future<Map<String, dynamic>> resetPassword(String token, String password) async {
    try {
      return await BaseService.post('/auth/reset-password', {
        'token': token,
        'password': password,
      }, requiresAuth: false);
    } catch (e) {
      debugPrint('Reset password error: $e');
      rethrow;
    }
  }

  // Verify email
  static Future<Map<String, dynamic>> verifyEmail(String token) async {
    try {
      return await BaseService.post('/auth/verify-email/$token', {}, requiresAuth: false);
    } catch (e) {
      debugPrint('Email verification error: $e');
      rethrow;
    }
  }

  // Resend verification email
  static Future<Map<String, dynamic>> resendVerification(String email) async {
    try {
      return await BaseService.post('/auth/resend-verification', {'email': email});
    } catch (e) {
      debugPrint('Resend verification error: $e');
      rethrow;
    }
  }

  // Check authentication status
  static Future<bool> isAuthenticated() async {
    return await TokenService.isAuthenticated();
  }

  // Get cached user data
  static Future<Map<String, dynamic>?> getUserData() async {
    try {
      final userData = await TokenService.getUserData();
      if (userData != null) {
        final parsedData = json.decode(userData) as Map<String, dynamic>;
        _processProfileImages(parsedData);
        return parsedData;
      }
      return null;
    } catch (e) {
      debugPrint('Get cached user data error: $e');
      return null;
    }
  }

  // Get user role
  static Future<String?> getUserRole() async {
    return await TokenService.getUserRole();
  }

  // Get user ID
  static Future<String?> getUserId() async {
    return await TokenService.getUserId();
  }

  // Refresh user data from server
  static Future<Map<String, dynamic>?> refreshUserData() async {
    try {
      final profile = await getProfile();
      return profile.isNotEmpty ? profile : null;
    } catch (e) {
      debugPrint('Refresh user data error: $e');
      return null;
    }
  }

  // Check if user has specific role
  static Future<bool> hasRole(List<String> roles) async {
    return await TokenService.hasRole(roles);
  }

  // PRIVATE HELPER METHODS

  static Future<void> _saveUserData(Map<String, dynamic> data) async {
    try {
      final user = data['user'] ?? data;

      // Save complete user profile
      await TokenService.saveUserData(json.encode(user));

      // Save role and ID separately for easy access
      if (user['role'] != null) {
        await TokenService.saveUserRole(user['role']);
      }

      if (user['id'] != null) {
        await TokenService.saveUserId(user['id']);
      }

      debugPrint('User data saved successfully');
    } catch (e) {
      debugPrint('Save user data error: $e');
    }
  }

  static void _processProfileImages(Map<String, dynamic> profileData) {
    try {
      if (profileData['avatar'] != null) {
        profileData['avatar'] = ImageService.getImageUrl(profileData['avatar']);
      }

      // Process additional profile images if present
      if (profileData['profileImage'] != null) {
        profileData['profileImage'] = ImageService.getImageUrl(profileData['profileImage']);
      }
    } catch (e) {
      debugPrint('Process profile images error: $e');
    }
  }
}