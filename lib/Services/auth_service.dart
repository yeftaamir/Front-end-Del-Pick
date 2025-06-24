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

  /// Enhanced method to get role-specific user data structure
  static Future<Map<String, dynamic>?> getRoleSpecificData() async {
    try {
      print('Getting role-specific data...');

      // First, get the user role
      final userRole = await getUserRole();
      print('User role: $userRole');

      if (userRole == null) {
        print('No user role found');
        return null;
      }

      // Get cached user data
      final userData = await getUserData();
      print('Cached user data: $userData');

      if (userData == null) {
        print('No cached user data, fetching from server...');
        // If no cached data, try to get fresh data from server
        final freshData = await refreshUserData();
        if (freshData != null) {
          // Process the fresh data based on role
          final processedData = await _processRoleSpecificData(freshData, userRole);
          return processedData;
        }
        return null;
      }

      // Process existing data based on role
      final processedData = await _processRoleSpecificData(userData, userRole);
      return processedData;

    } catch (e) {
      print('Error getting role-specific data: $e');
      return null;
    }
  }

  /// Process data based on user role and ensure proper structure
  static Future<Map<String, dynamic>?> _processRoleSpecificData(
      Map<String, dynamic> data, String role) async {
    try {
      print('Processing role-specific data for role: $role');
      print('Input data: $data');

      switch (role.toLowerCase()) {
        case 'store':
          return await _processStoreSpecificData(data);
        case 'driver':
          return await _processDriverSpecificData(data);
        case 'customer':
          return await _processCustomerSpecificData(data);
        default:
          print('Unknown role: $role, returning data as-is');
          return data;
      }
    } catch (e) {
      print('Error processing role-specific data: $e');
      return data;
    }
  }

  /// Process store-specific data and ensure store info is available
  static Future<Map<String, dynamic>> _processStoreSpecificData(
      Map<String, dynamic> data) async {
    try {
      print('Processing store-specific data...');

      // If store data is already at the root level
      if (data['store'] != null) {
        print('Store data found at root level');
        await _processStoreData(data);
        return data;
      }

      // If user data contains store info
      if (data['user'] != null && data['user']['store'] != null) {
        print('Store data found in user object');
        final storeData = data['user']['store'];
        await _processStoreData({'store': storeData});
        return {
          'user': data['user'],
          'store': storeData,
        };
      }

      // If we need to fetch store data from server
      print('No store data found, attempting to fetch from server...');
      final freshProfile = await getProfile();
      if (freshProfile != null && freshProfile['store'] != null) {
        print('Store data fetched from server');
        await _processStoreData({'store': freshProfile['store']});
        return {
          'user': freshProfile,
          'store': freshProfile['store'],
        };
      }

      print('No store data available');
      return data;
    } catch (e) {
      print('Error processing store-specific data: $e');
      return data;
    }
  }

  /// Process driver-specific data
  static Future<Map<String, dynamic>> _processDriverSpecificData(
      Map<String, dynamic> data) async {
    try {
      if (data['driver'] != null) {
        await _processDriverData(data);
        return data;
      }

      if (data['user'] != null && data['user']['driver'] != null) {
        return {
          'user': data['user'],
          'driver': data['user']['driver'],
        };
      }

      return data;
    } catch (e) {
      print('Error processing driver-specific data: $e');
      return data;
    }
  }

  /// Process customer-specific data
  static Future<Map<String, dynamic>> _processCustomerSpecificData(
      Map<String, dynamic> data) async {
    try {
      // For customers, the user data is usually sufficient
      return {
        'user': data['user'] ?? data,
      };
    } catch (e) {
      print('Error processing customer-specific data: $e');
      return data;
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

  /// Enhanced driver-specific login data processing
  static Future<void> _processDriverData(Map<String, dynamic> loginData) async {
    print('Processing driver data...');

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

      print('Driver data processed: $driver');
    }
  }

  /// Enhanced store-specific login data processing
  static Future<void> _processStoreData(Map<String, dynamic> loginData) async {
    print('Processing store data...');

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

      // Ensure store ID is available
      if (store['id'] == null) {
        print('WARNING: Store ID is null!');
      } else {
        print('Store ID found: ${store['id']}');
      }

      print('Store data processed: $store');
    } else {
      print('WARNING: No store data found in loginData');
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

  /// Debug method to print current user data structure
  static Future<void> debugUserData() async {
    try {
      print('=== DEBUG USER DATA ===');

      final role = await getUserRole();
      print('User role: $role');

      final userData = await getUserData();
      print('User data: $userData');

      final roleSpecificData = await getRoleSpecificData();
      print('Role-specific data: $roleSpecificData');

      print('=== END DEBUG ===');
    } catch (e) {
      print('Debug error: $e');
    }
  }
}