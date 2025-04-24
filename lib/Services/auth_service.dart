// lib/services/auth_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'core/api_constants.dart';
import 'core/token_service.dart';
import 'image_service.dart';

class AuthService {
  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = _parseResponseBody(response.body);
        final user = data['data']?['user'];
        final token = data['data']?['token'];

        if (user == null || token == null) {
          throw Exception('Invalid login response: missing user or token');
        }

        // Process avatar URL if exists
        if (user['avatar'] != null && user['avatar'].toString().isNotEmpty) {
          user['avatar'] = _processImageUrl(user['avatar']);
        }

        // Process driver or store data if present
        if (data['data']?['driver'] != null) {
          final driver = data['data']['driver'];
          // Process driver profile image if present
          if (driver['profileImage'] != null) {
            driver['profileImage'] = _processImageUrl(driver['profileImage']);
          }
        }

        // In AuthService._saveUserData or when processing store data
        if (data['data']?['store'] != null) {
          final store = data['data']['store'];
          // Process store image if present
          if (store['imageUrl'] != null) {
            store['imageUrl'] = _processImageUrl(store['imageUrl']);
          } else if (store['image'] != null) {
            store['image'] = _processImageUrl(store['image']);
            // For consistency, set imageUrl too
            store['imageUrl'] = store['image'];
          }
        }

        await TokenService.saveToken(token);
        await _saveUserData(user, token);

        // Return comprehensive data including any driver/store info
        return data['data'];
      } else {
        try {
          final error = _parseResponseBody(response.body);
          throw Exception(error['message'] ?? 'Login failed');
        } catch (_) {
          throw Exception('Login failed: ${response.body}');
        }
      }
    } catch (e) {
      print('Error during login: $e');
      throw Exception('Login failed: $e');
    }
  }

  // Helper method to process image URL with proper formatting
  static String _processImageUrl(String imageUrl) {
    if (imageUrl.startsWith('data:image/')) {
      // Already a base64 image, return as is
      return imageUrl;
    } else if (imageUrl.startsWith('http')) {
      // Already a full URL, return as is
      return imageUrl;
    } else if (imageUrl.startsWith('/')) {
      // Server-relative path, join with base URL
      return '${ApiConstants.baseUrl}${imageUrl}';
    } else {
      // Other format, let ImageService handle it
      return ImageService.getImageUrl(imageUrl);
    }
  }

  static Future<void> _saveUserData(Map<String, dynamic> user, String token) async {
    try {
      final role = user['role'] ?? 'customer';

      // Ensure data is properly encoded
      final userJson = jsonEncode(user);

      // Save user profile with cleaned JSON
      await ApiConstants.storage.write(key: 'user_profile', value: userJson);
      await ApiConstants.storage.write(key: 'user_role', value: role);

      // Save complete data
      final completeData = jsonEncode({
        'user': user,
        'token': token
      });

      await ApiConstants.storage.write(
        key: 'user_data',
        value: completeData,
      );

      print('User data saved successfully');
    } catch (e) {
      print('Error saving user data: $e');
      // Continue without throwing to prevent login failure
    }
  }

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
        final Map<String, dynamic> data = _parseResponseBody(response.body);

        // Process avatar/profile image if present
        if (data['data'] != null) {
          // Process user avatar
          if (data['data']['avatar'] != null && data['data']['avatar'].toString().isNotEmpty) {
            data['data']['avatar'] = _processImageUrl(data['data']['avatar']);
          }

          // Process driver data if present
          if (data['data']['driver'] != null) {
            final driver = data['data']['driver'];

            // Check for profileImage first
            if (driver['profileImage'] != null && driver['profileImage'].toString().isNotEmpty) {
              driver['profileImage'] = _processImageUrl(driver['profileImage']);
            }
            // For backward compatibility - some APIs might use image instead
            else if (driver['image'] != null && driver['image'].toString().isNotEmpty) {
              driver['image'] = _processImageUrl(driver['image']);
              // Add profileImage field for consistency
              driver['profileImage'] = driver['image'];
            }
          }

          // Process store data if present
          if (data['data']['store'] != null) {
            final store = data['data']['store'];
            if (store['image'] != null && store['image'].toString().isNotEmpty) {
              store['image'] = _processImageUrl(store['image']);
            }
          }
        }

        // Save the updated profile data to cache
        if (data['data'] != null) {
          await ApiConstants.storage.write(
            key: 'user_profile',
            value: jsonEncode(data['data']),
          );
        }

        return data['data'] ?? {};
      } else if (response.statusCode == 401) {
        // Handle unauthorized access - token might be expired
        await TokenService.clearToken(); // Clear the invalid token
        throw Exception('Session expired, please login again');
      } else {
        throw Exception('Failed to get profile: ${response.body}');
      }
    } catch (e) {
      print('Error fetching profile: $e');
      throw Exception('Failed to get profile: $e');
    }
  }

  static Future<Map<String, dynamic>?> getUserData() async {
    try {
      final userData = await ApiConstants.storage.read(key: 'user_profile');

      if (userData == null || userData.isEmpty) {
        return null;
      }

      // Pastikan data valid dengan mencoba parse terlebih dahulu
      try {
        return _parseJson(userData);
      } catch (e) {
        print('Error parsing user data: $e');

        // Jika parsing gagal, coba bersihkan karakter yang tidak diinginkan
        String cleanedData = userData.trim();

        // Jika ada BOM atau karakter khusus di awal, hapus
        if (cleanedData.startsWith('\uFEFF')) {
          cleanedData = cleanedData.substring(1);
        }

        // Coba replace karakter yang tidak valid
        cleanedData = cleanedData
            .replaceAll('\n', '')
            .replaceAll('\r', '')
            .replaceAll('\t', '');

        // Jika masih ada karakter pembuka/penutup di awal/akhir, pastikan format JSON benar
        if (!cleanedData.startsWith('{') && cleanedData.contains('{')) {
          cleanedData = cleanedData.substring(cleanedData.indexOf('{'));
        }

        // Jika JSON tidak lengkap di akhir, coba tambahkan penutup
        if (cleanedData.startsWith('{') && !cleanedData.endsWith('}')) {
          int openBraces = 0;
          int closeBraces = 0;

          for (int i = 0; i < cleanedData.length; i++) {
            if (cleanedData[i] == '{') openBraces++;
            if (cleanedData[i] == '}') closeBraces++;
          }

          while (closeBraces < openBraces) {
            cleanedData += '}';
            closeBraces++;
          }
        }

        // Coba parse lagi setelah dibersihkan
        try {
          return _parseJson(cleanedData);
        } catch (e) {
          print('Error parsing cleaned user data: $e');

          // Jika masih gagal, hapus data yang rusak dan kembalikan null
          await ApiConstants.storage.delete(key: 'user_profile');
          return null;
        }
      }
    } catch (e) {
      print('Error in getUserData: $e');
      return null;
    }
  }

  // Helper method untuk parse JSON dengan handling error yang lebih baik
  static Map<String, dynamic> _parseJson(String jsonString) {
    try {
      return json.decode(jsonString);
    } catch (e) {
      // Jika masih error, coba parsing dengan pendekatan manual
      print('Trying alternative JSON parsing approach');

      // Coba menggunakan custom JSON parser (tidak disarankan, hanya untuk fallback)
      // Ini hanya untuk menangani kasus ekstrim dan sebaiknya dihindari
      try {
        // Fallback to default empty object
        return {};
      } catch (e) {
        print('All JSON parsing attempts failed: $e');
        throw FormatException('Invalid JSON format: $e');
      }
    }
  }

  // Helper untuk parsing response body dengan error handling
  static Map<String, dynamic> _parseResponseBody(String body) {
    try {
      return json.decode(body);
    } catch (e) {
      print('Error parsing response body: $e');
      // Coba bersihkan string sebelum parsing
      String cleanedBody = body.trim();
      // Hapus BOM atau karakter khusus di awal jika ada
      if (cleanedBody.startsWith('\uFEFF')) {
        cleanedBody = cleanedBody.substring(1);
      }
      try {
        return json.decode(cleanedBody);
      } catch (e) {
        throw FormatException('Invalid response format: $e');
      }
    }
  }

  static Future<String?> getUserRole() async {
    try {
      return await ApiConstants.storage.read(key: 'user_role');
    } catch (e) {
      print('Error getting user role: $e');
      return null;
    }
  }

  // Improved logout function based on backend implementation
  static Future<bool> logout() async {
    try {
      final token = await TokenService.getToken();

      // Only try to call logout endpoint if we have a token
      if (token != null) {
        try {
          // Call server-side logout endpoint (just for token verification)
          final response = await http.post(
            Uri.parse('${ApiConstants.baseUrl}/auth/logout'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          );

          // Log response for debugging
          print('Logout server response: ${response.statusCode}');
        } catch (e) {
          // Server-side logout failed, but we should still clear local data
          print('Server-side logout failed, continuing with local logout: $e');
        }
      }

      // Local cleanup - MOST IMPORTANT PART
      print('Performing local logout cleanup');

      // Clear all tokens and storage data
      await TokenService.clearToken();
      await ApiConstants.storage.deleteAll();

      return true; // Local logout is considered successful regardless of server response
    } catch (e) {
      print('Critical error during logout: $e');

      // Even if there's an error, still try to clear token as last resort
      try {
        await TokenService.clearToken();
      } catch (clearError) {
        print('Failed to clear token: $clearError');
      }

      return false;
    }


  }
}