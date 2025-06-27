// lib/Services/auth_service.dart
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

        print('✅ Login successful for user: ${user['name']} (${user['role']})');
        return loginData;
      }

      throw Exception('Invalid login response format');
    } catch (e) {
      print('❌ Login error: $e');
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
        print('⚠️ Server-side logout failed: $e');
        // Continue with local cleanup even if server call fails
      }

      // Clear all local authentication data
      await TokenService.clearAll();
      print('✅ Logout completed successfully');
      return true;
    } catch (e) {
      print('❌ Logout error: $e');
      // Still try to clear local data on error
      try {
        await TokenService.clearAll();
      } catch (clearError) {
        print('❌ Failed to clear local data: $clearError');
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
      print('❌ Get profile error: $e');
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
      print('❌ Update profile error: $e');
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
      print('❌ Registration error: $e');
      throw Exception('Registration failed: $e');
    }
  }

  /// Get cached user data with enhanced error handling
  static Future<Map<String, dynamic>?> getUserData() async {
    try {
      final userData = await TokenService.getUserData();
      print(
          '🔍 AuthService: Retrieved user data: ${userData != null ? userData.keys.toList() : 'null'}');
      return userData;
    } catch (e) {
      print('❌ Error getting user data: $e');
      return null;
    }
  }

  /// Get user role from cache with validation
  static Future<String?> getUserRole() async {
    try {
      final role = await TokenService.getUserRole();
      print('🔍 AuthService: Retrieved user role: $role');
      return role;
    } catch (e) {
      print('❌ Error getting user role: $e');
      return null;
    }
  }

  /// Get user ID from cache
  static Future<String?> getUserId() async {
    try {
      final userId = await TokenService.getUserId();
      print('🔍 AuthService: Retrieved user ID: $userId');
      return userId;
    } catch (e) {
      print('❌ Error getting user ID: $e');
      return null;
    }
  }

  /// Check if user is authenticated with comprehensive validation
  static Future<bool> isAuthenticated() async {
    try {
      // Check if token exists
      final hasToken = await TokenService.isAuthenticated();
      if (!hasToken) {
        print('⚠️ AuthService: No authentication token found');
        return false;
      }

      // Check if user role exists
      final userRole = await getUserRole();
      if (userRole == null || userRole.isEmpty) {
        print('⚠️ AuthService: No user role found');
        return false;
      }

      // Check if user ID exists
      final userId = await getUserId();
      if (userId == null || userId.isEmpty) {
        print('⚠️ AuthService: No user ID found');
        return false;
      }

      print(
          '✅ AuthService: User is authenticated - Role: $userRole, ID: $userId');
      return true;
    } catch (e) {
      print('❌ AuthService: Error checking authentication: $e');
      return false;
    }
  }

  /// Refresh user data from server
  static Future<Map<String, dynamic>?> refreshUserData() async {
    try {
      print('🔄 AuthService: Refreshing user data from server...');
      final profile = await getProfile();
      print('✅ AuthService: User data refreshed successfully');
      return profile;
    } catch (e) {
      print('❌ Error refreshing user data: $e');
      return null;
    }
  }

  /// Enhanced method to get role-specific user data structure with better customer handling
  static Future<Map<String, dynamic>?> getRoleSpecificData() async {
    try {
      print('🔍 AuthService: Getting role-specific data...');

      // First, check authentication
      final isAuth = await isAuthenticated();
      if (!isAuth) {
        print('❌ AuthService: User not authenticated');
        return null;
      }

      // Get the user role
      final userRole = await getUserRole();
      print('🔍 AuthService: User role: $userRole');

      if (userRole == null) {
        print('❌ AuthService: No user role found');
        return null;
      }

      // Get cached user data
      final userData = await getUserData();
      print(
          '🔍 AuthService: Cached user data structure: ${userData?.keys.toList()}');

      if (userData == null) {
        print('⚠️ AuthService: No cached user data, fetching from server...');
        // If no cached data, try to get fresh data from server
        final freshData = await refreshUserData();
        if (freshData != null) {
          // Process the fresh data based on role
          final processedData =
              await _processRoleSpecificData(freshData, userRole);
          return processedData;
        }
        return null;
      }

      // Process existing data based on role
      final processedData = await _processRoleSpecificData(userData, userRole);
      return processedData;
    } catch (e) {
      print('❌ AuthService: Error getting role-specific data: $e');
      return null;
    }
  }

  /// Process data based on user role and ensure proper structure with enhanced customer handling
  static Future<Map<String, dynamic>?> _processRoleSpecificData(
      Map<String, dynamic> data, String role) async {
    try {
      print('🔍 AuthService: Processing role-specific data for role: $role');
      print('🔍 AuthService: Input data structure: ${data.keys.toList()}');

      switch (role.toLowerCase()) {
        case 'customer':
          return await _processCustomerSpecificData(data);
        case 'store':
          return await _processStoreSpecificData(data);
        case 'driver':
          return await _processDriverSpecificData(data);
        default:
          print('⚠️ AuthService: Unknown role: $role, returning data as-is');
          return data;
      }
    } catch (e) {
      print('❌ AuthService: Error processing role-specific data: $e');
      return data;
    }
  }

  /// Enhanced customer-specific data processing with proper structure validation
  static Future<Map<String, dynamic>> _processCustomerSpecificData(
      Map<String, dynamic> data) async {
    try {
      print('🔍 AuthService: Processing customer-specific data...');

      // Customer data structure is usually straightforward
      // The user data should be in the 'user' key or at the root level
      Map<String, dynamic> customerData;

      if (data.containsKey('user')) {
        customerData = Map<String, dynamic>.from(data['user']);
        print('✅ AuthService: Customer data found in user object');
      } else {
        // If the data is already at root level, use it directly
        customerData = Map<String, dynamic>.from(data);
        print('✅ AuthService: Customer data found at root level');
      }

      // Ensure required customer fields with defaults
      customerData['id'] = customerData['id'] ?? 0;
      customerData['name'] = customerData['name'] ?? 'Unknown Customer';
      customerData['email'] = customerData['email'] ?? '';
      customerData['phone'] = customerData['phone'] ?? '';
      customerData['role'] = customerData['role'] ?? 'customer';

      // Process customer avatar
      if (customerData['avatar'] != null &&
          customerData['avatar'].toString().isNotEmpty) {
        customerData['avatar'] =
            ImageService.getImageUrl(customerData['avatar']);
      }

      print('✅ AuthService: Customer data processed successfully');
      print('   - Customer ID: ${customerData['id']}');
      print('   - Customer Name: ${customerData['name']}');
      print('   - Customer Email: ${customerData['email']}');

      return {
        'user': customerData,
        'role': 'customer',
      };
    } catch (e) {
      print('❌ AuthService: Error processing customer-specific data: $e');
      return {
        'user': data['user'] ?? data,
        'role': 'customer',
      };
    }
  }

  /// Process store-specific data and ensure store info is available
  static Future<Map<String, dynamic>> _processStoreSpecificData(
      Map<String, dynamic> data) async {
    try {
      print('🔍 AuthService: Processing store-specific data...');

      // If store data is already at the root level
      if (data['store'] != null) {
        print('✅ AuthService: Store data found at root level');
        await _processStoreData(data);
        return data;
      }

      // If user data contains store info
      if (data['user'] != null && data['user']['store'] != null) {
        print('✅ AuthService: Store data found in user object');
        final storeData = data['user']['store'];
        await _processStoreData({'store': storeData});
        return {
          'user': data['user'],
          'store': storeData,
        };
      }

      // If we need to fetch store data from server
      print(
          '⚠️ AuthService: No store data found, attempting to fetch from server...');
      final freshProfile = await getProfile();
      if (freshProfile != null && freshProfile['store'] != null) {
        print('✅ AuthService: Store data fetched from server');
        await _processStoreData({'store': freshProfile['store']});
        return {
          'user': freshProfile,
          'store': freshProfile['store'],
        };
      }

      print('❌ AuthService: No store data available');
      return data;
    } catch (e) {
      print('❌ AuthService: Error processing store-specific data: $e');
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
      print('❌ AuthService: Error processing driver-specific data: $e');
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
      print('❌ Email verification error: $e');
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
      print('❌ Resend verification error: $e');
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
      print('❌ Forgot password error: $e');
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
      print('❌ Reset password error: $e');
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
        // Customer data processing is handled in _processCustomerSpecificData
        print('✅ AuthService: Customer login data processed');
        break;
    }
  }

  /// Enhanced driver-specific login data processing
  static Future<void> _processDriverData(Map<String, dynamic> loginData) async {
    print('🔍 AuthService: Processing driver data...');

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

      print('✅ AuthService: Driver data processed');
    }
  }

  /// Enhanced store-specific login data processing
  static Future<void> _processStoreData(Map<String, dynamic> loginData) async {
    print('🔍 AuthService: Processing store data...');

    if (loginData['store'] != null) {
      final store = loginData['store'];

      // Process store image
      if (store['image_url'] != null &&
          store['image_url'].toString().isNotEmpty) {
        store['image_url'] = ImageService.getImageUrl(store['image_url']);
      }

      // Ensure all required store fields with defaults
      store['rating'] = store['rating'] ?? 0.0;
      store['review_count'] = store['review_count'] ?? 0;
      store['total_products'] = store['total_products'] ?? 0;
      store['status'] = store['status'] ?? 'active';

      // Ensure store ID is available
      if (store['id'] == null) {
        print('⚠️ AuthService: Store ID is null!');
      } else {
        print('✅ AuthService: Store ID found: ${store['id']}');
      }

      print('✅ AuthService: Store data processed');
    } else {
      print('⚠️ AuthService: No store data found in loginData');
    }
  }

  /// Process images in profile data based on role
  static Future<void> _processProfileImages(
      Map<String, dynamic> profileData) async {
    // Process user avatar
    if (profileData['avatar'] != null &&
        profileData['avatar'].toString().isNotEmpty) {
      profileData['avatar'] = ImageService.getImageUrl(profileData['avatar']);
    }

    // Process driver data if present
    if (profileData['driver'] != null) {
      final driver = profileData['driver'];
      if (driver['user'] != null && driver['user']['avatar'] != null) {
        driver['user']['avatar'] =
            ImageService.getImageUrl(driver['user']['avatar']);
      }
    }

    // Process store data if present
    if (profileData['store'] != null) {
      final store = profileData['store'];
      if (store['image_url'] != null &&
          store['image_url'].toString().isNotEmpty) {
        store['image_url'] = ImageService.getImageUrl(store['image_url']);
      }
      if (store['owner'] != null && store['owner']['avatar'] != null) {
        store['owner']['avatar'] =
            ImageService.getImageUrl(store['owner']['avatar']);
      }
    }
  }

  /// Validate customer access for store and menu operations
  static Future<bool> validateCustomerAccess() async {
    try {
      print('🔍 AuthService: Validating customer access...');

      // Check authentication
      final isAuth = await isAuthenticated();
      if (!isAuth) {
        print('❌ AuthService: User not authenticated');
        return false;
      }

      // Check role
      final userRole = await getUserRole();
      if (userRole?.toLowerCase() != 'customer') {
        print('❌ AuthService: Invalid role for customer operation: $userRole');
        return false;
      }

      // Get user data to ensure it's valid
      final userData = await getRoleSpecificData();
      if (userData == null) {
        print('❌ AuthService: No valid user data found');
        return false;
      }

      print('✅ AuthService: Customer access validated');
      return true;
    } catch (e) {
      print('❌ AuthService: Error validating customer access: $e');
      return false;
    }
  }

  /// Enhanced method for customer-specific operations
  static Future<Map<String, dynamic>?> getCustomerData() async {
    try {
      print('🔍 AuthService: Getting customer data...');

      // Validate customer access first
      final hasAccess = await validateCustomerAccess();
      if (!hasAccess) {
        return null;
      }

      // Get role-specific data
      final roleData = await getRoleSpecificData();
      if (roleData == null) {
        print('❌ AuthService: No role-specific data found');
        return null;
      }

      // Extract customer data
      final customerData = roleData['user'];
      if (customerData == null) {
        print('❌ AuthService: No customer user data found');
        return null;
      }

      print('✅ AuthService: Customer data retrieved successfully');
      return customerData;
    } catch (e) {
      print('❌ AuthService: Error getting customer data: $e');
      return null;
    }
  }

  /// Debug method to print current user data structure
  static Future<void> debugUserData() async {
    try {
      print('🔍 ====== DEBUG USER DATA ======');

      final isAuth = await isAuthenticated();
      print('🔍 Is Authenticated: $isAuth');

      final role = await getUserRole();
      print('🔍 User role: $role');

      final userId = await getUserId();
      print('🔍 User ID: $userId');

      final userData = await getUserData();
      print('🔍 User data keys: ${userData?.keys.toList()}');

      final roleSpecificData = await getRoleSpecificData();
      print('🔍 Role-specific data keys: ${roleSpecificData?.keys.toList()}');

      if (role?.toLowerCase() == 'customer') {
        final customerData = await getCustomerData();
        print('🔍 Customer data: ${customerData?.keys.toList()}');
      }

      print('🔍 ====== END DEBUG ======');
    } catch (e) {
      print('❌ Debug error: $e');
    }
  }

  /// Check if current user has specific role
  static Future<bool> hasRole(String requiredRole) async {
    try {
      final userRole = await getUserRole();
      return userRole?.toLowerCase() == requiredRole.toLowerCase();
    } catch (e) {
      print('❌ Error checking user role: $e');
      return false;
    }
  }

  /// Ensure user data is fresh and valid
  static Future<bool> ensureValidUserData() async {
    try {
      print('🔄 AuthService: Ensuring valid user data...');

      // Check if authenticated
      final isAuth = await isAuthenticated();
      if (!isAuth) {
        print('❌ AuthService: User not authenticated');
        return false;
      }

      // Check if we have cached data
      final cachedData = await getUserData();
      if (cachedData == null) {
        print('⚠️ AuthService: No cached data, refreshing...');
        final freshData = await refreshUserData();
        return freshData != null;
      }

      // Validate cached data structure
      final role = await getUserRole();
      if (role == null) {
        print('⚠️ AuthService: No role found, refreshing...');
        final freshData = await refreshUserData();
        return freshData != null;
      }

      print('✅ AuthService: User data is valid');
      return true;
    } catch (e) {
      print('❌ AuthService: Error ensuring valid user data: $e');
      return false;
    }
  }
}
