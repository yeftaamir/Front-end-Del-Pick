// lib/Services/auth_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'Core/token_service.dart';
import 'core/base_service.dart';
import 'image_service.dart';

class AuthService {
  static const String _baseEndpoint = '/auth';

  /// Login user with email and password
  /// Returns role-specific user data with nested structures for driver/store
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await BaseService.apiCall(
        method: 'POST',
        endpoint: '$_baseEndpoint/login',
        body: {
          'email': email,
          'password': password,
        },
        requiresAuth: false,
      );

      if (response['data'] != null) {
        final loginData = response['data'];
        final user = loginData['user'];
        final token = loginData['token'];

        if (user == null || token == null) {
          throw Exception('Invalid login response: missing user or token');
        }

        // Save authentication data
        await TokenService.saveToken(token);
        await TokenService.saveUserRole(user['role']);
        await TokenService.saveUserId(user['id'].toString());

        // Process role-specific data and images
        await _processLoginData(loginData);

        // Save complete user data
        await TokenService.saveUserData(loginData);

        print('Login successful for user: ${user['name']} (${user['role']})');
        return loginData;
      }

      throw Exception('Invalid login response format');
    } catch (e) {
      print('Login error: $e');
      throw Exception('Login failed: $e');
    }
  }

  /// Logout user - clears all local data and calls server logout
  static Future<bool> logout() async {
    try {
      // Try to call server-side logout
      try {
        await BaseService.apiCall(
          method: 'POST',
          endpoint: '$_baseEndpoint/logout',
          requiresAuth: true,
        );
      } catch (e) {
        print('Server-side logout failed: $e');
        // Continue with local cleanup even if server call fails
      }

      // Clear all local authentication data
      await TokenService.clearAll();
      print('Logout completed successfully');
      return true;
    } catch (e) {
      print('Logout error: $e');
      // Still try to clear local data on error
      try {
        await TokenService.clearAll();
      } catch (clearError) {
        print('Failed to clear local data: $clearError');
      }
      return false;
    }
  }

  /// Get current user profile based on role
  /// Returns different data structure for customer/driver/store
  static Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/profile',
        requiresAuth: true,
      );

      if (response['data'] != null) {
        final profileData = response['data'];

        // Process images based on role
        await _processProfileImages(profileData);

        // Update cached user data
        await TokenService.saveUserData({'user': profileData});

        return profileData;
      }

      throw Exception('Invalid profile response format');
    } catch (e) {
      print('Get profile error: $e');
      throw Exception('Failed to get profile: $e');
    }
  }

  /// Update user profile - handles role-specific updates
  static Future<Map<String, dynamic>> updateProfile({
    required Map<String, dynamic> updateData,
  }) async {
    try {
      final response = await BaseService.apiCall(
        method: 'PUT',
        endpoint: '$_baseEndpoint/profile',
        body: updateData,
        requiresAuth: true,
      );

      if (response['data'] != null) {
        final updatedProfile = response['data'];

        // Process images
        await _processProfileImages(updatedProfile);

        // Update cached data
        await TokenService.saveUserData({'user': updatedProfile});

        return updatedProfile;
      }

      throw Exception('Invalid update profile response format');
    } catch (e) {
      print('Update profile error: $e');
      throw Exception('Failed to update profile: $e');
    }
  }

  /// Register new user
  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String role, // customer, driver, store
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final registerData = {
        'name': name,
        'email': email,
        'password': password,
        'phone': phone,
        'role': role,
        ...?additionalData,
      };

      final response = await BaseService.apiCall(
        method: 'POST',
        endpoint: '$_baseEndpoint/register',
        body: registerData,
        requiresAuth: false,
      );

      return response['data'] ?? {};
    } catch (e) {
      print('Registration error: $e');
      throw Exception('Registration failed: $e');
    }
  }

  /// Get cached user data
  static Future<Map<String, dynamic>?> getUserData() async {
    try {
      return await TokenService.getUserData();
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  /// Get user role from cache
  static Future<String?> getUserRole() async {
    try {
      return await TokenService.getUserRole();
    } catch (e) {
      print('Error getting user role: $e');
      return null;
    }
  }

  /// Get user ID from cache
  static Future<String?> getUserId() async {
    try {
      return await TokenService.getUserId();
    } catch (e) {
      print('Error getting user ID: $e');
      return null;
    }
  }

  /// Check if user is authenticated
  static Future<bool> isAuthenticated() async {
    try {
      return await TokenService.isAuthenticated();
    } catch (e) {
      return false;
    }
  }

  /// Refresh user data from server
  static Future<Map<String, dynamic>?> refreshUserData() async {
    try {
      final profile = await getProfile();
      return profile;
    } catch (e) {
      print('Error refreshing user data: $e');
      return null;
    }
  }

  /// Get role-specific user data structure
  static Future<Map<String, dynamic>?> getRoleSpecificData() async {
    try {
      final userData = await getUserData();
      if (userData == null) return null;

      final role = await getUserRole();
      if (role == null) return userData;

      // Return appropriate structure based on role
      switch (role.toLowerCase()) {
        case 'driver':
          return {
            'user': userData['user'] ?? userData,
            'driver': userData['driver'],
          };
        case 'store':
          return {
            'user': userData['user'] ?? userData,
            'store': userData['store'],
          };
        case 'customer':
          return {
            'user': userData['user'] ?? userData,
          };
        default:
          return userData;
      }
    } catch (e) {
      print('Error getting role-specific data: $e');
      return null;
    }
  }

  /// Verify email with token
  static Future<bool> verifyEmail(String token) async {
    try {
      await BaseService.apiCall(
        method: 'POST',
        endpoint: '$_baseEndpoint/verify-email/$token',
        requiresAuth: false,
      );
      return true;
    } catch (e) {
      print('Email verification error: $e');
      return false;
    }
  }

  /// Resend verification email
  static Future<bool> resendVerification(String email) async {
    try {
      await BaseService.apiCall(
        method: 'POST',
        endpoint: '$_baseEndpoint/resend-verification',
        body: {'email': email},
        requiresAuth: true,
      );
      return true;
    } catch (e) {
      print('Resend verification error: $e');
      return false;
    }
  }

  /// Forgot password
  static Future<bool> forgotPassword(String email) async {
    try {
      await BaseService.apiCall(
        method: 'POST',
        endpoint: '$_baseEndpoint/forgot-password',
        body: {'email': email},
        requiresAuth: false,
      );
      return true;
    } catch (e) {
      print('Forgot password error: $e');
      return false;
    }
  }

  /// Reset password with token
  static Future<bool> resetPassword({
    required String token,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      await BaseService.apiCall(
        method: 'POST',
        endpoint: '$_baseEndpoint/reset-password/$token',
        body: {
          'password': newPassword,
          'confirmPassword': confirmPassword,
        },
        requiresAuth: false,
      );
      return true;
    } catch (e) {
      print('Reset password error: $e');
      return false;
    }
  }

  // PRIVATE HELPER METHODS

  /// Process login data based on user role
  static Future<void> _processLoginData(Map<String, dynamic> loginData) async {
    final user = loginData['user'];
    if (user == null) return;

    final role = user['role']?.toString().toLowerCase();

    // Process user avatar
    if (user['avatar'] != null && user['avatar'].toString().isNotEmpty) {
      user['avatar'] = ImageService.getImageUrl(user['avatar']);
    }

    switch (role) {
      case 'driver':
        await _processDriverData(loginData);
        break;
      case 'store':
        await _processStoreData(loginData);
        break;
      case 'customer':
      // Customer data is already in user object
        break;
    }
  }

  /// Process driver-specific login data
  static Future<void> _processDriverData(Map<String, dynamic> loginData) async {
    if (loginData['driver'] != null) {
      final driver = loginData['driver'];

      // Ensure all required driver fields with defaults
      driver['rating'] = driver['rating'] ?? 5.0;
      driver['reviews_count'] = driver['reviews_count'] ?? 0;
      driver['status'] = driver['status'] ?? 'inactive';
      driver['license_number'] = driver['license_number'] ?? '';
      driver['vehicle_plate'] = driver['vehicle_plate'] ?? '';
      driver['latitude'] = driver['latitude'];
      driver['longitude'] = driver['longitude'];
    }
  }

  /// Process store-specific login data
  static Future<void> _processStoreData(Map<String, dynamic> loginData) async {
    if (loginData['store'] != null) {
      final store = loginData['store'];

      // Process store image
      if (store['image_url'] != null && store['image_url'].toString().isNotEmpty) {
        store['image_url'] = ImageService.getImageUrl(store['image_url']);
      }

      // Ensure all required store fields with defaults
      store['rating'] = store['rating'] ?? 0.0;
      store['review_count'] = store['review_count'] ?? 0;
      store['total_products'] = store['total_products'] ?? 0;
      store['status'] = store['status'] ?? 'active';
    }
  }

  /// Process images in profile data based on role
  static Future<void> _processProfileImages(Map<String, dynamic> profileData) async {
    // Process user avatar
    if (profileData['avatar'] != null && profileData['avatar'].toString().isNotEmpty) {
      profileData['avatar'] = ImageService.getImageUrl(profileData['avatar']);
    }

    // Process driver data if present
    if (profileData['driver'] != null) {
      final driver = profileData['driver'];
      if (driver['user'] != null && driver['user']['avatar'] != null) {
        driver['user']['avatar'] = ImageService.getImageUrl(driver['user']['avatar']);
      }
    }

    // Process store data if present
    if (profileData['store'] != null) {
      final store = profileData['store'];
      if (store['image_url'] != null && store['image_url'].toString().isNotEmpty) {
        store['image_url'] = ImageService.getImageUrl(store['image_url']);
      }
      if (store['owner'] != null && store['owner']['avatar'] != null) {
        store['owner']['avatar'] = ImageService.getImageUrl(store['owner']['avatar']);
      }
    }
  }
}