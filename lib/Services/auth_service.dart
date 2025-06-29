// lib/Services/auth_service.dart
import 'package:http/http.dart' as http;
import 'Core/token_service.dart';
import 'core/base_service.dart';
import 'image_service.dart';

class AuthService {
  static const String _baseEndpoint = '/auth';
  static const bool _debugMode = false; // Toggle for development debugging

  // ✅ SUPPORTED ROLES (HANYA 3 ROLE)
  static const List<String> _supportedRoles = ['customer', 'store', 'driver'];

  static void _log(String message) {
    if (_debugMode) print(message);
  }

  /// Login user with email and password - Optimized untuk 3 role dengan 7 hari token
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

        // ✅ VALIDASI ROLE (HANYA 3 ROLE YANG DIDUKUNG)
        final userRole = user['role']?.toString().toLowerCase();
        if (!_supportedRoles.contains(userRole)) {
          throw Exception(
              'Unsupported user role: $userRole. Only customer, store, and driver are supported.');
        }

        // Batch save authentication data (token akan expired setelah 7 hari)
        await Future.wait([
          TokenService.saveToken(
              token), // ✅ Automatically saves with 7 days expiry
          TokenService.saveUserRole(user['role']),
          TokenService.saveUserId(user['id'].toString()),
        ]);

        // Process role-specific data and images
        await _processLoginData(loginData);

        // Save complete user data
        await TokenService.saveUserData(loginData);

        _log(
            'Login successful for user: ${user['name']} (${user['role']}) - Token valid for 7 days');
        return loginData;
      }

      throw Exception('Invalid login response format');
    } catch (e) {
      _log('Login error: $e');
      throw Exception('Login failed: $e');
    }
  }

  /// Logout user - Enhanced cleanup for 7 days token
  static Future<bool> logout() async {
    try {
      // Try server-side logout with timeout
      try {
        await BaseService.apiCall(
          method: 'POST',
          endpoint: '$_baseEndpoint/logout',
          requiresAuth: true,
        ).timeout(Duration(seconds: 5));
        _log('Server-side logout successful');
      } catch (e) {
        _log('Server-side logout failed: $e (continuing with local cleanup)');
        // Continue with local cleanup even if server logout fails
      }

      // Clear all local authentication data (termasuk token 7 hari)
      await TokenService.clearAll();
      _log('Logout completed successfully - all 7-day session data cleared');
      return true;
    } catch (e) {
      _log('Logout error: $e');
      // Still try to clear local data on error
      try {
        await TokenService.clearAll();
        _log('Local session data cleared despite logout error');
      } catch (clearError) {
        _log('Failed to clear local data: $clearError');
      }
      return false;
    }
  }

  /// Get current user profile - Enhanced untuk 3 role
  static Future<Map<String, dynamic>> getProfile() async {
    try {
      // Validate session sebelum request
      final sessionValid = await isSessionValid();
      if (!sessionValid) {
        throw Exception('Session expired after 7 days. Please login again.');
      }

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/profile',
        requiresAuth: true,
      );

      if (response['data'] != null) {
        final profileData = response['data'];

        // ✅ VALIDASI ROLE pada profile data
        final userRole = profileData['role']?.toString().toLowerCase();
        if (!_supportedRoles.contains(userRole)) {
          throw Exception('Profile contains unsupported role: $userRole');
        }

        // Process images based on role
        await _processProfileImages(profileData);

        // Update cached user data (maintain 7-day session)
        await TokenService.saveUserData({'user': profileData});

        return profileData;
      }

      throw Exception('Invalid profile response format');
    } catch (e) {
      _log('Get profile error: $e');
      throw Exception('Failed to get profile: $e');
    }
  }

  /// Update user profile - Enhanced untuk 3 role
  static Future<Map<String, dynamic>> updateProfile({
    required Map<String, dynamic> updateData,
  }) async {
    try {
      // Validate session before update
      final sessionValid = await isSessionValid();
      if (!sessionValid) {
        throw Exception('Session expired after 7 days. Please login again.');
      }

      final response = await BaseService.apiCall(
        method: 'PUT',
        endpoint: '$_baseEndpoint/profile',
        body: updateData,
        requiresAuth: true,
      );

      if (response['data'] != null) {
        final updatedProfile = response['data'];

        // Process images and update cache in parallel
        await Future.wait([
          _processProfileImages(updatedProfile),
          TokenService.saveUserData({'user': updatedProfile}),
        ]);

        _log('Profile updated successfully for 7-day session user');
        return updatedProfile;
      }

      throw Exception('Invalid update profile response format');
    } catch (e) {
      _log('Update profile error: $e');
      throw Exception('Failed to update profile: $e');
    }
  }

  /// Register new user - Enhanced validation untuk 3 role saja
  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String role,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // ✅ VALIDASI ROLE saat register
      if (!_supportedRoles.contains(role.toLowerCase())) {
        throw Exception(
            'Invalid role: $role. Only customer, store, and driver are supported.');
      }

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

      _log('Registration successful for role: $role');
      return response['data'] ?? {};
    } catch (e) {
      _log('Registration error: $e');
      throw Exception('Registration failed: $e');
    }
  }

  /// Get cached user data - Enhanced untuk 7 hari session
  static Future<Map<String, dynamic>?> getUserData() async {
    try {
      final userData = await TokenService.getUserData();

      if (userData != null) {
        // Check if cached data is still valid (within 7 days)
        final sessionValid = await isSessionValid();
        if (!sessionValid) {
          _log('Cached user data invalid - 7 day session expired');
          await TokenService.clearAll();
          return null;
        }
      }

      _log(
          'Retrieved user data: ${userData != null ? userData.keys.toList() : 'null'}');
      return userData;
    } catch (e) {
      _log('Error getting user data: $e');
      return null;
    }
  }

  /// Get user role from cache - Enhanced validation
  static Future<String?> getUserRole() async {
    try {
      final role = await TokenService.getUserRole();

      // ✅ VALIDASI ROLE dari cache
      if (role != null && !_supportedRoles.contains(role.toLowerCase())) {
        _log('Invalid cached role: $role, clearing session');
        await TokenService.clearAll();
        return null;
      }

      _log('Retrieved user role: $role');
      return role;
    } catch (e) {
      _log('Error getting user role: $e');
      return null;
    }
  }

  /// Get user ID from cache - Enhanced
  static Future<String?> getUserId() async {
    try {
      final userId = await TokenService.getUserId();
      _log('Retrieved user ID: $userId');
      return userId;
    } catch (e) {
      _log('Error getting user ID: $e');
      return null;
    }
  }

  /// Refresh user data from server - Enhanced untuk 7 hari session
  static Future<Map<String, dynamic>?> refreshUserData() async {
    try {
      _log('Refreshing user data from server (validating 7-day session)...');
      final profile = await getProfile();
      _log('User data refreshed successfully with valid 7-day session');
      return profile;
    } catch (e) {
      _log('Error refreshing user data: $e');

      // If refresh fails due to expired session, clear all data
      if (e.toString().contains('expired') || e.toString().contains('7 days')) {
        await TokenService.clearAll();
      }

      return null;
    }
  }

  /// Get role-specific data - Enhanced untuk 3 role saja
  static Future<Map<String, dynamic>?> getRoleSpecificData() async {
    try {
      _log('Getting role-specific data for supported roles...');

      // Batch check authentication and get role
      final authCheck = await Future.wait([
        isAuthenticated(),
        getUserRole(),
      ]);

      final isAuth = authCheck[0] as bool;
      final userRole = authCheck[1] as String?;

      if (!isAuth) {
        _log('User not authenticated or 7-day session expired');
        return null;
      }

      if (userRole == null ||
          !_supportedRoles.contains(userRole.toLowerCase())) {
        _log('Invalid or unsupported user role: $userRole');
        await TokenService.clearAll(); // Clear invalid session
        return null;
      }

      _log('User role: $userRole (supported)');

      // Get cached user data
      final userData = await getUserData();
      _log('Cached user data structure: ${userData?.keys.toList()}');

      if (userData == null) {
        _log('No cached user data, fetching from server...');
        final freshData = await refreshUserData();
        if (freshData != null) {
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
      _log('Error getting role-specific data: $e');
      return null;
    }
  }

  /// Process data based on user role - Updated untuk 3 role saja
  static Future<Map<String, dynamic>?> _processRoleSpecificData(
      Map<String, dynamic> data, String role) async {
    try {
      _log('Processing role-specific data for role: $role');
      _log('Input data structure: ${data.keys.toList()}');

      // ✅ HANYA PROSES 3 ROLE YANG DIDUKUNG
      switch (role.toLowerCase()) {
        case 'customer':
          return await _processCustomerSpecificData(data);
        case 'store':
          return await _processStoreSpecificData(data);
        case 'driver':
          return await _processDriverSpecificData(data);
        default:
          _log('Unsupported role: $role, clearing session');
          await TokenService.clearAll();
          return null;
      }
    } catch (e) {
      _log('Error processing role-specific data: $e');
      return data;
    }
  }

  /// Process customer data - Enhanced
  static Future<Map<String, dynamic>> _processCustomerSpecificData(
      Map<String, dynamic> data) async {
    try {
      _log('Processing customer-specific data...');

      Map<String, dynamic> customerData;

      if (data.containsKey('user')) {
        customerData = Map<String, dynamic>.from(data['user']);
        _log('Customer data found in user object');
      } else {
        customerData = Map<String, dynamic>.from(data);
        _log('Customer data found at root level');
      }

      // Batch set required customer fields with defaults
      final defaults = {
        'id': 0,
        'name': 'Unknown Customer',
        'email': '',
        'phone': '',
        'role': 'customer',
      };

      for (final entry in defaults.entries) {
        customerData[entry.key] ??= entry.value;
      }

      // Process customer avatar
      if (customerData['avatar'] != null &&
          customerData['avatar'].toString().isNotEmpty) {
        customerData['avatar'] =
            ImageService.getImageUrl(customerData['avatar']);
      }

      _log('Customer data processed successfully');
      _log('Customer ID: ${customerData['id']}, Name: ${customerData['name']}');

      return {
        'user': customerData,
        'role': 'customer',
      };
    } catch (e) {
      _log('Error processing customer-specific data: $e');
      return {
        'user': data['user'] ?? data,
        'role': 'customer',
      };
    }
  }

  /// Process store data - Enhanced
  static Future<Map<String, dynamic>> _processStoreSpecificData(
      Map<String, dynamic> data) async {
    try {
      _log('Processing store-specific data...');

      // Check store data locations in order of priority
      if (data['store'] != null) {
        _log('Store data found at root level');
        await _processStoreData(data);
        return data;
      }

      if (data['user'] != null && data['user']['store'] != null) {
        _log('Store data found in user object');
        final storeData = data['user']['store'];
        await _processStoreData({'store': storeData});
        return {
          'user': data['user'],
          'store': storeData,
        };
      }

      // Fetch store data from server if not found (dengan validasi 7 hari)
      _log('No store data found, attempting to fetch from server...');
      final freshProfile = await getProfile();
      if (freshProfile != null && freshProfile['store'] != null) {
        _log('Store data fetched from server');
        await _processStoreData({'store': freshProfile['store']});
        return {
          'user': freshProfile,
          'store': freshProfile['store'],
        };
      }

      _log('No store data available');
      return data;
    } catch (e) {
      _log('Error processing store-specific data: $e');
      return data;
    }
  }

  /// Process driver data - Enhanced
  static Future<Map<String, dynamic>> _processDriverSpecificData(
      Map<String, dynamic> data) async {
    try {
      _log('Processing driver-specific data...');

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

      // Try to fetch driver data from server
      _log('No driver data found, attempting to fetch from server...');
      final freshProfile = await getProfile();
      if (freshProfile != null && freshProfile['driver'] != null) {
        await _processDriverData({'driver': freshProfile['driver']});
        return {
          'user': freshProfile,
          'driver': freshProfile['driver'],
        };
      }

      return data;
    } catch (e) {
      _log('Error processing driver-specific data: $e');
      return data;
    }
  }

  /// Email verification - Enhanced
  static Future<bool> verifyEmail(String token) async {
    try {
      await BaseService.apiCall(
        method: 'POST',
        endpoint: '$_baseEndpoint/verify-email/$token',
        requiresAuth: false,
      );
      return true;
    } catch (e) {
      _log('Email verification error: $e');
      return false;
    }
  }

  /// Resend verification email - Enhanced
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
      _log('Resend verification error: $e');
      return false;
    }
  }

  /// Forgot password - Enhanced
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
      _log('Forgot password error: $e');
      return false;
    }
  }

  /// Reset password - Enhanced
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
      _log('Reset password error: $e');
      return false;
    }
  }

  // ==============================
  // PRIVATE HELPER METHODS
  // ==============================

  /// Process login data - Enhanced untuk 3 role
  static Future<void> _processLoginData(Map<String, dynamic> loginData) async {
    final user = loginData['user'];
    if (user == null) return;

    final role = user['role']?.toString().toLowerCase();

    // Process user avatar
    if (user['avatar'] != null && user['avatar'].toString().isNotEmpty) {
      user['avatar'] = ImageService.getImageUrl(user['avatar']);
    }

    // ✅ PROSES BERDASARKAN 3 ROLE YANG DIDUKUNG
    switch (role) {
      case 'driver':
        await _processDriverData(loginData);
        break;
      case 'store':
        await _processStoreData(loginData);
        break;
      case 'customer':
        _log('Customer login data processed');
        break;
      default:
        _log('Unsupported role in login data: $role');
        break;
    }
  }

  /// Process driver data - Enhanced
  static Future<void> _processDriverData(Map<String, dynamic> loginData) async {
    _log('Processing driver data...');

    final driver = loginData['driver'];
    if (driver != null) {
      // Batch set driver defaults
      final driverDefaults = {
        'rating': 5.0,
        'reviews_count': 0,
        'status': 'inactive',
        'license_number': '',
        'vehicle_plate': '',
      };

      for (final entry in driverDefaults.entries) {
        driver[entry.key] ??= entry.value;
      }

      // Keep nullable location fields as they are
      // driver['latitude'] and driver['longitude'] can be null

      _log('Driver data processed successfully');
    }
  }

  /// Process store data - Enhanced
  static Future<void> _processStoreData(Map<String, dynamic> loginData) async {
    _log('Processing store data...');

    final store = loginData['store'];
    if (store != null) {
      // Process store image
      if (store['image_url'] != null &&
          store['image_url'].toString().isNotEmpty) {
        store['image_url'] = ImageService.getImageUrl(store['image_url']);
      }

      // Batch set store defaults
      final storeDefaults = {
        'rating': 0.0,
        'review_count': 0,
        'total_products': 0,
        'status': 'active',
      };

      for (final entry in storeDefaults.entries) {
        store[entry.key] ??= entry.value;
      }

      if (store['id'] == null) {
        _log('Store ID is null!');
      } else {
        _log('Store ID found: ${store['id']}');
      }

      _log('Store data processed successfully');
    } else {
      _log('No store data found in loginData');
    }
  }

  /// Process profile images - Enhanced
  static Future<void> _processProfileImages(
      Map<String, dynamic> profileData) async {
    // Process user avatar
    if (profileData['avatar'] != null &&
        profileData['avatar'].toString().isNotEmpty) {
      profileData['avatar'] = ImageService.getImageUrl(profileData['avatar']);
    }

    // Process driver data if present
    final driver = profileData['driver'];
    if (driver != null) {
      final driverUser = driver['user'];
      if (driverUser != null && driverUser['avatar'] != null) {
        driverUser['avatar'] = ImageService.getImageUrl(driverUser['avatar']);
      }
    }

    // Process store data if present
    final store = profileData['store'];
    if (store != null) {
      if (store['image_url'] != null &&
          store['image_url'].toString().isNotEmpty) {
        store['image_url'] = ImageService.getImageUrl(store['image_url']);
      }
      final storeOwner = store['owner'];
      if (storeOwner != null && storeOwner['avatar'] != null) {
        storeOwner['avatar'] = ImageService.getImageUrl(storeOwner['avatar']);
      }
    }
  }

  /// Validate customer access - Enhanced dengan 7 hari validation
  static Future<bool> validateCustomerAccess() async {
    try {
      _log('Validating customer access with 7-day session...');

      // Batch check authentication and role
      final checks = await Future.wait([
        isAuthenticated(),
        getUserRole(),
      ]);

      final isAuth = checks[0] as bool;
      final userRole = checks[1] as String?;

      if (!isAuth) {
        _log('User not authenticated or 7-day session expired');
        return false;
      }

      if (userRole?.toLowerCase() != 'customer') {
        _log('Invalid role for customer operation: $userRole');
        return false;
      }

      // Get user data to ensure it's valid
      final userData = await getRoleSpecificData();
      if (userData == null) {
        _log('No valid user data found');
        return false;
      }

      _log('Customer access validated with valid 7-day session');
      return true;
    } catch (e) {
      _log('Error validating customer access: $e');
      return false;
    }
  }

  /// Get customer data - Enhanced
  static Future<Map<String, dynamic>?> getCustomerData() async {
    try {
      _log('Getting customer data...');

      // Validate customer access first
      final hasAccess = await validateCustomerAccess();
      if (!hasAccess) {
        return null;
      }

      // Get role-specific data
      final roleData = await getRoleSpecificData();
      if (roleData == null) {
        _log('No role-specific data found');
        return null;
      }

      // Extract customer data
      final customerData = roleData['user'];
      if (customerData == null) {
        _log('No customer user data found');
        return null;
      }

      _log('Customer data retrieved successfully');
      return customerData;
    } catch (e) {
      _log('Error getting customer data: $e');
      return null;
    }
  }

  /// Debug user data - Only active when debug mode is on
  static Future<void> debugUserData() async {
    if (!_debugMode) return;

    try {
      print('🔍 ====== DEBUG USER DATA (3 ROLES + 7 DAYS SESSION) ======');

      final isAuth = await isAuthenticated();
      print('🔍 Is Authenticated: $isAuth');

      final sessionValid = await isSessionValid();
      print('🔍 Session Valid (7 days): $sessionValid');

      final remainingDays = await getSessionRemainingDays();
      print('🔍 Remaining Days: $remainingDays');

      final role = await getUserRole();
      print(
          '🔍 User role: $role (supported: ${_supportedRoles.contains(role?.toLowerCase())})');

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

  /// Check if user has specific role - Enhanced validation
  static Future<bool> hasRole(String requiredRole) async {
    try {
      // ✅ VALIDASI ROLE YANG DIDUKUNG
      if (!_supportedRoles.contains(requiredRole.toLowerCase())) {
        _log('Checking for unsupported role: $requiredRole');
        return false;
      }

      final userRole = await getUserRole();
      return userRole?.toLowerCase() == requiredRole.toLowerCase();
    } catch (e) {
      _log('Error checking user role: $e');
      return false;
    }
  }

  /// Ensure user data is valid - Enhanced dengan 7 hari validation
  static Future<bool> ensureValidUserData() async {
    try {
      _log('Ensuring valid user data with 7-day session...');

      // Batch check authentication and cached data
      final checks = await Future.wait([
        isAuthenticated(),
        getUserData(),
        getUserRole(),
      ]);

      final isAuth = checks[0] as bool;
      final cachedData = checks[1] as Map<String, dynamic>?;
      final role = checks[2] as String?;

      if (!isAuth) {
        _log('User not authenticated or 7-day session expired');
        return false;
      }

      // ✅ VALIDASI ROLE
      if (role == null || !_supportedRoles.contains(role.toLowerCase())) {
        _log('Invalid or unsupported role: $role');
        await TokenService.clearAll();
        return false;
      }

      if (cachedData == null) {
        _log('No cached data, refreshing with 7-day session validation...');
        final freshData = await refreshUserData();
        return freshData != null;
      }

      _log('User data is valid with valid 7-day session');
      return true;
    } catch (e) {
      _log('Error ensuring valid user data: $e');
      return false;
    }
  }

  /// Check if user session is still valid (token not expired after 7 days)
  static Future<bool> isSessionValid() async {
    try {
      final isAuthenticated = await TokenService.isAuthenticated();
      if (!isAuthenticated) {
        _log('Session invalid: not authenticated');
        return false;
      }

      final isTokenValid = await TokenService.isTokenValid();
      if (!isTokenValid) {
        _log('Session invalid: token expired after 7 days');
        await TokenService.clearAll();
        return false;
      }

      _log('Session is valid (within 7 days)');
      return true;
    } catch (e) {
      _log('Error checking session validity: $e');
      return false;
    }
  }

  /// Get remaining session time in days
  static Future<int> getSessionRemainingDays() async {
    try {
      return await TokenService.getTokenRemainingDays();
    } catch (e) {
      _log('Error getting session remaining days: $e');
      return 0;
    }
  }

  /// Get token information for debugging
  static Future<Map<String, dynamic>> getTokenInfo() async {
    try {
      return await TokenService.getTokenInfo();
    } catch (e) {
      _log('Error getting token info: $e');
      return {'error': e.toString()};
    }
  }

  /// Validate session and refresh if needed
  static Future<bool> validateAndRefreshSession() async {
    try {
      _log('Validating and refreshing 7-day session...');

      // Check if session is still valid
      final sessionValid = await isSessionValid();
      if (!sessionValid) {
        _log('7-day session invalid, need to re-authenticate');
        return false;
      }

      // Check remaining days and warn if less than 1 day
      final remainingDays = await getSessionRemainingDays();
      if (remainingDays <= 1) {
        _log('Warning: Token will expire in $remainingDays day(s)');
        // You could trigger a notification or automatic refresh here

        // Optionally refresh user data from server to ensure token is still valid
        try {
          await refreshUserData();
          _log('7-day session refreshed successfully');
        } catch (e) {
          _log('Failed to refresh 7-day session: $e');
          return false;
        }
      }

      return true;
    } catch (e) {
      _log('Error validating and refreshing 7-day session: $e');
      return false;
    }
  }

  /// Check authentication with enhanced validation for 7 days session
  static Future<bool> isAuthenticated() async {
    try {
      // First check basic authentication
      final basicAuth = await _checkBasicAuthentication();
      if (!basicAuth) {
        return false;
      }

      // Then validate session (7 days)
      final sessionValid = await isSessionValid();
      if (!sessionValid) {
        _log('Authentication failed: 7-day session invalid');
        return false;
      }

      // ✅ VALIDASI ROLE
      final userRole = await getUserRole();
      if (userRole == null ||
          !_supportedRoles.contains(userRole.toLowerCase())) {
        _log('Authentication failed: unsupported role $userRole');
        await TokenService.clearAll();
        return false;
      }

      _log(
          'User is authenticated with valid 7-day session and supported role: $userRole');
      return true;
    } catch (e) {
      _log('Error checking authentication: $e');
      return false;
    }
  }

  /// Basic authentication check (existing logic) - Enhanced
  static Future<bool> _checkBasicAuthentication() async {
    try {
      // Batch check all required authentication data
      final results = await Future.wait([
        TokenService.getToken(),
        getUserRole(),
        getUserId(),
      ]);

      final token = results[0] as String?;
      final userRole = results[1] as String?;
      final userId = results[2] as String?;

      if (token == null || token.isEmpty) {
        _log('No authentication token found');
        return false;
      }

      if (userRole == null || userRole.isEmpty) {
        _log('No user role found');
        return false;
      }

      if (userId == null || userId.isEmpty) {
        _log('No user ID found');
        return false;
      }

      _log('Basic authentication check passed - Role: $userRole, ID: $userId');
      return true;
    } catch (e) {
      _log('Error in basic authentication check: $e');
      return false;
    }
  }

  /// Get supported roles list
  static List<String> getSupportedRoles() {
    return List.from(_supportedRoles);
  }

  /// Check if role is supported
  static bool isRoleSupported(String role) {
    return _supportedRoles.contains(role.toLowerCase());
  }
}
