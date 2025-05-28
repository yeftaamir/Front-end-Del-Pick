// lib/services/auth_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'core/api_constants.dart';
import 'core/token_service.dart';
import 'image_service.dart';

class AuthService {
  /// Login user and return user data with token
  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = _parseResponseBody(response.body);

        if (jsonData['data'] == null) {
          throw Exception('Invalid login response: missing data');
        }

        final data = jsonData['data'];
        final user = data['user'];
        final token = data['token'];

        if (user == null || token == null) {
          throw Exception('Invalid login response: missing user or token');
        }

        // Process user avatar URL if exists
        if (user['avatar'] != null && user['avatar'].toString().isNotEmpty) {
          user['avatar'] = ImageService.getImageUrl(user['avatar']);
        }

        // Process driver data if present
        if (data['driver'] != null) {
          final driver = data['driver'];
          // Process driver profile image if present
          if (driver['profileImage'] != null && driver['profileImage'].toString().isNotEmpty) {
            driver['profileImage'] = ImageService.getImageUrl(driver['profileImage']);
          }
          // Handle legacy 'image' field
          if (driver['image'] != null && driver['image'].toString().isNotEmpty) {
            driver['image'] = ImageService.getImageUrl(driver['image']);
            // Set profileImage for consistency
            if (driver['profileImage'] == null) {
              driver['profileImage'] = driver['image'];
            }
          }
        }

        // Process store data if present
        if (data['store'] != null) {
          final store = data['store'];
          // Process store image if present
          if (store['imageUrl'] != null && store['imageUrl'].toString().isNotEmpty) {
            store['imageUrl'] = ImageService.getImageUrl(store['imageUrl']);
          }
          if (store['image'] != null && store['image'].toString().isNotEmpty) {
            store['image'] = ImageService.getImageUrl(store['image']);
            // For consistency, set imageUrl too if not present
            if (store['imageUrl'] == null) {
              store['imageUrl'] = store['image'];
            }
          }
        }

        // Save authentication data
        await TokenService.saveToken(token);
        await TokenService.saveUserRole(user['role'] ?? 'customer');
        await TokenService.saveUserId(user['id']);
        await _saveUserData(data);

        print('Login successful for user: ${user['name']} (${user['role']})');
        return data;
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error during login: $e');
      if (e.toString().contains('Invalid login response') ||
          e.toString().contains('Failed to login')) {
        rethrow;
      }
      throw Exception('Login failed: $e');
    }
    return {};
  }

  /// Get user profile data
  static Future<Map<String, dynamic>> getProfile() async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/auth/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = _parseResponseBody(response.body);

        if (jsonData['data'] != null) {
          final profileData = jsonData['data'];
          _processProfileImages(profileData);

          // Update cached user data
          await _saveUserData({'user': profileData});

          return profileData;
        }
        return {};
      } else if (response.statusCode == 401) {
        // Handle unauthorized access - token might be expired
        await _clearAllUserData();
        throw Exception('Session expired, please login again');
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error fetching profile: $e');
      if (e.toString().contains('Session expired')) {
        rethrow;
      }
      throw Exception('Failed to get profile: $e');
    }
    return {};
  }

    /// Logout user - removes token and calls logout API
  static Future<bool> logout() async {
    try {
      final token = await TokenService.getToken();

      // Call server-side logout if token exists
      if (token != null) {
        try {
          final response = await http.post(
            Uri.parse('${ApiConstants.baseUrl}/auth/logout'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          );

          print('Server logout response: ${response.statusCode}');
          // Continue with local cleanup regardless of server response
        } catch (e) {
          print('Server-side logout failed, continuing with local cleanup: $e');
        }
      }

      // Perform local cleanup (most important part)
      await _clearAllUserData();

      print('Logout completed successfully');
      return true;
    } catch (e) {
      print('Error during logout: $e');

      // Even if there's an error, still try to clear local data
      try {
        await _clearAllUserData();
      } catch (clearError) {
        print('Failed to clear local data: $clearError');
      }

      return false;
    }
  }

  /// Get cached user data
  static Future<Map<String, dynamic>?> getUserData() async {
    try {
      final userData = await ApiConstants.storage.read(key: 'user_profile');

      if (userData == null || userData.isEmpty) {
        return null;
      }

      try {
        final parsedData = _parseJson(userData);

        // Ensure image URLs are processed
        if (parsedData.isNotEmpty) {
          _processProfileImages(parsedData);
        }

        return parsedData;
      } catch (e) {
        print('Error parsing cached user data: $e');

        // Clean up corrupted data
        await ApiConstants.storage.delete(key: 'user_profile');
        return null;
      }
    } catch (e) {
      print('Error retrieving cached user data: $e');
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
      final token = await TokenService.getToken();
      return token != null && token.isNotEmpty;
    } catch (e) {
      print('Error checking authentication status: $e');
      return false;
    }
  }

  /// Refresh user data from server
  static Future<Map<String, dynamic>?> refreshUserData() async {
    try {
      final profile = await getProfile();
      return profile.isNotEmpty ? profile : null;
    } catch (e) {
      print('Error refreshing user data: $e');
      return null;
    }
  }

  // PRIVATE HELPER METHODS

  /// Save user data to local storage
  static Future<void> _saveUserData(Map<String, dynamic> data) async {
    try {
      // Extract user data
      final user = data['user'] ?? data;

      // Save user profile
      final userJson = jsonEncode(user);
      await ApiConstants.storage.write(key: 'user_profile', value: userJson);

      // Save role if available
      if (user['role'] != null) {
        await TokenService.saveUserRole(user['role']);
      }

      // Save user ID if available
      if (user['id'] != null) {
        await TokenService.saveUserId(user['id']);
      }

      // Save complete data including driver/store info
      final completeDataJson = jsonEncode(data);
      await ApiConstants.storage.write(key: 'user_data', value: completeDataJson);

      print('User data saved successfully');
    } catch (e) {
      print('Error saving user data: $e');
      // Don't throw error to prevent login failure
    }
  }

  /// Clear all user data from local storage
  static Future<void> _clearAllUserData() async {
    try {
      await TokenService.clearAll();
      print('All user data cleared successfully');
    } catch (e) {
      print('Error clearing user data: $e');
      throw Exception('Failed to clear user data');
    }
  }

  /// Process images in profile data
  static void _processProfileImages(Map<String, dynamic> profileData) {
    try {
      // Process user avatar
      if (profileData['avatar'] != null && profileData['avatar'].toString().isNotEmpty) {
        profileData['avatar'] = ImageService.getImageUrl(profileData['avatar']);
      }

      // Process driver data if present
      if (profileData['driver'] != null) {
        final driver = profileData['driver'];

        if (driver['profileImage'] != null && driver['profileImage'].toString().isNotEmpty) {
          driver['profileImage'] = ImageService.getImageUrl(driver['profileImage']);
        }

        if (driver['image'] != null && driver['image'].toString().isNotEmpty) {
          driver['image'] = ImageService.getImageUrl(driver['image']);
          // Set profileImage for consistency if not present
          if (driver['profileImage'] == null) {
            driver['profileImage'] = driver['image'];
          }
        }
      }

      // Process store data if present
      if (profileData['store'] != null) {
        final store = profileData['store'];

        if (store['imageUrl'] != null && store['imageUrl'].toString().isNotEmpty) {
          store['imageUrl'] = ImageService.getImageUrl(store['imageUrl']);
        }

        if (store['image'] != null && store['image'].toString().isNotEmpty) {
          store['image'] = ImageService.getImageUrl(store['image']);
          // Set imageUrl for consistency if not present
          if (store['imageUrl'] == null) {
            store['imageUrl'] = store['image'];
          }
        }
      }
    } catch (e) {
      print('Error processing profile images: $e');
    }
  }

  /// Parse response body with better error handling
  static Map<String, dynamic> _parseResponseBody(String body) {
    try {
      return json.decode(body);
    } catch (e) {
      print('Error parsing response body: $e');

      // Try to clean the string before parsing
      String cleanedBody = body.trim();

      // Remove BOM if present
      if (cleanedBody.startsWith('\uFEFF')) {
        cleanedBody = cleanedBody.substring(1);
      }

      try {
        return json.decode(cleanedBody);
      } catch (e) {
        throw Exception('Invalid response format: $body');
      }
    }
  }

  /// Parse JSON string with better error handling
  static Map<String, dynamic> _parseJson(String jsonString) {
    try {
      final decoded = json.decode(jsonString);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      } else {
        throw Exception('Parsed JSON is not a Map');
      }
    } catch (e) {
      print('Error parsing JSON: $e');
      throw Exception('Invalid JSON format: $jsonString');
    }
  }

  /// Handle error responses consistently
  static void _handleErrorResponse(http.Response response) {
    try {
      final errorData = _parseResponseBody(response.body);
      final message = errorData['message'] ?? 'Request failed';
      throw Exception(message);
    } catch (e) {
      if (e is Exception && e.toString().contains('Request failed')) {
        rethrow;
      }
      throw Exception('Request failed with status ${response.statusCode}: ${response.body}');
    }
  }
}