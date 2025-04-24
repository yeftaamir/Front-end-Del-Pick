// lib/Services/customer_service.dart
import 'dart:convert';
import 'dart:math' as math; // Tambahkan import untuk math
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../Models/customer.dart';
import 'core/api_constants.dart';
import 'core/token_service.dart';
import 'image_service.dart';

class CustomerService {
  // Get customer profile data from server
  static Future<Customer> getCustomerProfile() async {
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

        // Check if we have user data
        if (data['data'] != null) {
          final userData = data['data'];

          // Check if role is customer
          if (userData['role'] == 'customer') {
            // Process avatar URL if present
            if (userData['avatar'] != null && userData['avatar'].toString().isNotEmpty) {
              // Simpan path asli, akan diproses oleh ImageService saat dibutuhkan
              userData['avatar'] = userData['avatar'].toString();
            }

            // Save updated profile data to local storage
            await _saveProfileToLocalStorage(userData);

            // Create customer object from response data
            return Customer.fromJson(userData);
          } else {
            throw Exception('User is not a customer');
          }
        } else {
          throw Exception('Profile data is missing');
        }
      } else if (response.statusCode == 401) {
        // Handle unauthorized access - token might be expired
        await TokenService.clearToken(); // Clear the invalid token
        throw Exception('Session expired, please login again');
      } else {
        throw Exception('Failed to get profile: ${response.body}');
      }
    } catch (e) {
      print('Error fetching customer profile: $e');
      throw Exception('Failed to get customer profile: $e');
    }
  }

  // Save profile data to local storage
  static Future<void> _saveProfileToLocalStorage(Map<String, dynamic> userData) async {
    try {
      final userJson = jsonEncode(userData);
      await ApiConstants.storage.write(key: 'user_profile', value: userJson);
    } catch (e) {
      print('Error saving profile to local storage: $e');
    }
  }

  // Get customer profile from local storage
  static Future<Customer?> getLocalCustomerProfile() async {
    try {
      final userData = await ApiConstants.storage.read(key: 'user_profile');

      if (userData == null || userData.isEmpty) {
        return null;
      }

      try {
        final Map<String, dynamic> parsedData = _parseJson(userData);

        // Only return if the role is customer
        if (parsedData['role'] == 'customer') {
          return Customer.fromStoredData(parsedData);
        } else {
          return null;
        }
      } catch (e) {
        print('Error parsing customer data: $e');
        // Clear invalid data
        await ApiConstants.storage.delete(key: 'user_profile');
        return null;
      }
    } catch (e) {
      print('Error getting local customer profile: $e');
      return null;
    }
  }

  // Update customer profile image
  static Future<bool> updateProfileImage(Customer customer, String base64Image) async {
    try {
      // Pastikan base64Image memiliki format yang tepat
      String formattedBase64 = base64Image;

      // Jika sudah dalam format data URL, gunakan langsung
      if (!base64Image.startsWith('data:')) {
        // Menggunakan pendekatan yang lebih sederhana dan aman
        String mimeType = 'image/jpeg'; // Default ke JPEG

        // Jika base64 string dimulai dengan byte signature tertentu, kita bisa mendeteksi formatnya
        try {
          List<int> decodedBytes = base64Decode(base64Image.substring(0, math.min(10, base64Image.length)));

          if (decodedBytes.length >= 4) {
            if (decodedBytes[0] == 0x89 && decodedBytes[1] == 0x50) {
              mimeType = 'image/png';
            } else if (decodedBytes[0] == 0xFF && decodedBytes[1] == 0xD8) {
              mimeType = 'image/jpeg';
            } else if (decodedBytes[0] == 0x47 && decodedBytes[1] == 0x49) {
              mimeType = 'image/gif';
            } else if (decodedBytes[0] == 0x42 && decodedBytes[1] == 0x4D) {
              mimeType = 'image/bmp';
            }
          }
        } catch (e) {
          print("Error detecting MIME type: $e");
          // Tetap gunakan default JPEG
        }

        formattedBase64 = 'data:$mimeType;base64,$base64Image';
      }

      final String? token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/users/${customer.id}/image'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'image': formattedBase64,
        }),
      );

      if (response.statusCode == 200) {
        // Update local storage with new image path from server response
        try {
          final responseData = _parseResponseBody(response.body);
          final userData = await ApiConstants.storage.read(key: 'user_profile');

          if (userData != null && userData.isNotEmpty) {
            final Map<String, dynamic> parsedData = _parseJson(userData);

            // Update dengan path yang dikembalikan server (bukan base64)
            if (responseData['data'] != null && responseData['data']['avatar'] != null) {
              parsedData['avatar'] = responseData['data']['avatar'];
            }

            await ApiConstants.storage.write(
              key: 'user_profile',
              value: jsonEncode(parsedData),
            );
          }
        } catch (e) {
          print('Error updating local profile image: $e');
        }
        return true;
      } else {
        print('Failed to update profile image: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error updating profile image: $e');
      return false;
    }
  }

  // Display customer profile image widget
  static Widget displayCustomerImage({
    required Customer customer,
    double width = 100,
    double height = 100,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
  }) {
    String? imageSource = customer.avatar;

    return ImageService.displayImage(
      imageSource: imageSource ?? '',
      width: width,
      height: height,
      fit: fit,
      borderRadius: borderRadius,
      placeholder: CircleAvatar(
        radius: width / 2,
        backgroundColor: Colors.grey[300],
        child: Text(
          customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: width * 0.4,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
      ),
    );
  }

  // Helper for parsing response body with error handling
  static Map<String, dynamic> _parseResponseBody(String body) {
    try {
      return json.decode(body);
    } catch (e) {
      print('Error parsing response body: $e');
      // Try to clean the string before parsing
      String cleanedBody = body.trim();
      // Remove BOM or special characters at the beginning if present
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

  // Helper method for parsing JSON with better error handling
  static Map<String, dynamic> _parseJson(String jsonString) {
    try {
      return json.decode(jsonString);
    } catch (e) {
      // If still error, try with manual approach
      print('Trying alternative JSON parsing approach');

      try {
        // Fallback to default empty object
        return {};
      } catch (e) {
        print('All JSON parsing attempts failed: $e');
        throw FormatException('Invalid JSON format: $e');
      }
    }
  }
}
// // lib/Services/customer_service.dart
// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'package:flutter/material.dart';
// import '../Models/customer.dart';
// import 'core/api_constants.dart';
// import 'core/token_service.dart';
// import 'image_service.dart';
//
// class CustomerService {
//   // Constants
//   static const String baseUrl = 'https://delpick.horas-code.my.id';
//
//   // Get customer profile data from server
//   static Future<Customer> getCustomerProfile() async {
//     try {
//       final token = await TokenService.getToken();
//       if (token == null) {
//         throw Exception('Authentication token not found');
//       }
//
//       final response = await http.get(
//         Uri.parse('${ApiConstants.baseUrl}/auth/profile'),
//         headers: {
//           'Content-Type': 'application/json',
//           'Authorization': 'Bearer $token',
//         },
//       );
//
//       if (response.statusCode == 200) {
//         final Map<String, dynamic> data = _parseResponseBody(response.body);
//
//         // Check if we have user data
//         if (data['data'] != null) {
//           final userData = data['data'];
//
//           // Check if role is customer
//           if (userData['role'] == 'customer') {
//             // Process avatar URL if present
//             if (userData['avatar'] != null && userData['avatar'].toString().isNotEmpty) {
//               userData['avatar'] = _processImageUrl(userData['avatar']);
//             }
//
//             // Save updated profile data to local storage
//             await _saveProfileToLocalStorage(userData);
//
//             // Create customer object from response data
//             return Customer.fromJson(userData);
//           } else {
//             throw Exception('User is not a customer');
//           }
//         } else {
//           throw Exception('Profile data is missing');
//         }
//       } else if (response.statusCode == 401) {
//         // Handle unauthorized access - token might be expired
//         await TokenService.clearToken(); // Clear the invalid token
//         throw Exception('Session expired, please login again');
//       } else {
//         throw Exception('Failed to get profile: ${response.body}');
//       }
//     } catch (e) {
//       print('Error fetching customer profile: $e');
//       throw Exception('Failed to get customer profile: $e');
//     }
//   }
//
//   // Save profile data to local storage
//   static Future<void> _saveProfileToLocalStorage(Map<String, dynamic> userData) async {
//     try {
//       final userJson = jsonEncode(userData);
//       await ApiConstants.storage.write(key: 'user_profile', value: userJson);
//     } catch (e) {
//       print('Error saving profile to local storage: $e');
//     }
//   }
//
//   // Get customer profile from local storage
//   static Future<Customer?> getLocalCustomerProfile() async {
//     try {
//       final userData = await ApiConstants.storage.read(key: 'user_profile');
//
//       if (userData == null || userData.isEmpty) {
//         return null;
//       }
//
//       try {
//         final Map<String, dynamic> parsedData = _parseJson(userData);
//
//         // Only return if the role is customer
//         if (parsedData['role'] == 'customer') {
//           return Customer.fromStoredData(parsedData);
//         } else {
//           return null;
//         }
//       } catch (e) {
//         print('Error parsing customer data: $e');
//         // Clear invalid data
//         await ApiConstants.storage.delete(key: 'user_profile');
//         return null;
//       }
//     } catch (e) {
//       print('Error getting local customer profile: $e');
//       return null;
//     }
//   }
//
//   // Update customer profile image
//   // static Future<bool> updateProfileImage(Customer customer, String base64Image) async {
//   //   try {
//   //     // Ensure base64Image has proper format
//   //     String formattedBase64 = base64Image;
//   //     if (!base64Image.startsWith('data:image/')) {
//   //       formattedBase64 = 'data:image/jpeg;base64,$base64Image';
//   //     }
//   //
//   //     final String? token = await TokenService.getToken();
//   //     if (token == null) {
//   //       throw Exception('Authentication token not found');
//   //     }
//   //
//   //     final response = await http.post(
//   //       Uri.parse('${ApiConstants.baseUrl}/users/${customer.id}/image'),
//   //       headers: {
//   //         'Content-Type': 'application/json',
//   //         'Authorization': 'Bearer $token',
//   //       },
//   //       body: jsonEncode({
//   //         'image': formattedBase64,
//   //       }),
//   //     );
//   //
//   //     if (response.statusCode == 200) {
//   //       // Update local storage with new image
//   //       try {
//   //         final userData = await ApiConstants.storage.read(key: 'user_profile');
//   //         if (userData != null && userData.isNotEmpty) {
//   //           final Map<String, dynamic> parsedData = _parseJson(userData);
//   //           parsedData['avatar'] = formattedBase64;
//   //           await ApiConstants.storage.write(
//   //             key: 'user_profile',
//   //             value: jsonEncode(parsedData),
//   //           );
//   //         }
//   //       } catch (e) {
//   //         print('Error updating local profile image: $e');
//   //       }
//   //       return true;
//   //     } else {
//   //       print('Failed to update profile image: ${response.body}');
//   //       return false;
//   //     }
//   //   } catch (e) {
//   //     print('Error updating profile image: $e');
//   //     return false;
//   //   }
//   // }
//
//   // Pick and update profile image in one step
//   static Future<bool> updateProfileImage(Customer customer, String base64Image) async {
//     try {
//       // Pastikan base64Image memiliki format yang tepat
//       String formattedBase64 = base64Image;
//
//       // Jika sudah dalam format data URL, gunakan langsung
//       if (!base64Image.startsWith('data:')) {
//         // Deteksi mimeType jika tidak ada prefix
//         String mimeType = _detectMimeTypeFromBase64(base64Image);
//         formattedBase64 = 'data:$mimeType;base64,$base64Image';
//       }
//
//       final String? token = await TokenService.getToken();
//       if (token == null) {
//         throw Exception('Authentication token not found');
//       }
//
//       final response = await http.post(
//         Uri.parse('${ApiConstants.baseUrl}/users/${customer.id}/image'),
//         headers: {
//           'Content-Type': 'application/json',
//           'Authorization': 'Bearer $token',
//         },
//         body: jsonEncode({
//           'image': formattedBase64,
//         }),
//       );
//
//       // Rest of the code remains the same...
//     } catch (e) {
//       print('Error updating profile image: $e');
//       return false;
//     }
//   }
//
// // Helper method to try to detect MIME type from base64 data
//   static String _detectMimeTypeFromBase64(String base64String) {
//     try {
//       // Mencoba mendeteksi format dari beberapa byte pertama setelah decode
//       final bytes = base64Decode(base64String.substring(0, Math.min(30, base64String.length)));
//
//       // Cek signature bytes untuk menentukan format
//       if (bytes.length >= 4) {
//         // PNG: 89 50 4E 47
//         if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
//           return 'image/png';
//         }
//         // JPEG: FF D8 FF
//         else if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
//           return 'image/jpeg';
//         }
//         // GIF: 47 49 46 38
//         else if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x38) {
//           return 'image/gif';
//         }
//         // BMP: 42 4D
//         else if (bytes[0] == 0x42 && bytes[1] == 0x4D) {
//           return 'image/bmp';
//         }
//       }
//     } catch (e) {
//       print('Error detecting MIME type: $e');
//     }
//
//     // Default ke image/jpeg jika tidak bisa mendeteksi
//     return 'image/jpeg';
//   }
//
//   // Display customer profile image widget
//   static Widget displayCustomerImage({
//     required Customer customer,
//     double width = 100,
//     double height = 100,
//     BoxFit fit = BoxFit.cover,
//     BorderRadius? borderRadius,
//   }) {
//     String? imageSource = customer.avatar;
//
//     return ImageService.displayImage(
//       imageSource: imageSource ?? '',
//       width: width,
//       height: height,
//       fit: fit,
//       borderRadius: borderRadius,
//       placeholder: CircleAvatar(
//         radius: width / 2,
//         backgroundColor: Colors.grey[300],
//         child: Text(
//           customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
//           style: TextStyle(
//             fontSize: width * 0.4,
//             fontWeight: FontWeight.bold,
//             color: Colors.grey[700],
//           ),
//         ),
//       ),
//     );
//   }
//
//   // Helper method to process image URL with proper formatting
//   static String _processImageUrl(String imageUrl) {
//     if (imageUrl.startsWith('data:image/')) {
//       // Already a base64 image, return as is
//       return imageUrl;
//     } else if (imageUrl.startsWith('http')) {
//       // Already a full URL, return as is
//       return imageUrl;
//     } else if (imageUrl.startsWith('/')) {
//       // Server-relative path, join with base URL
//       return '${baseUrl}${imageUrl}';
//     } else {
//       // Other format, let ImageService handle it
//       return ImageService.getImageUrl(imageUrl);
//     }
//   }
//
//   // Helper for parsing response body with error handling
//   static Map<String, dynamic> _parseResponseBody(String body) {
//     try {
//       return json.decode(body);
//     } catch (e) {
//       print('Error parsing response body: $e');
//       // Try to clean the string before parsing
//       String cleanedBody = body.trim();
//       // Remove BOM or special characters at the beginning if present
//       if (cleanedBody.startsWith('\uFEFF')) {
//         cleanedBody = cleanedBody.substring(1);
//       }
//       try {
//         return json.decode(cleanedBody);
//       } catch (e) {
//         throw FormatException('Invalid response format: $e');
//       }
//     }
//   }
//
//   // Helper method for parsing JSON with better error handling
//   static Map<String, dynamic> _parseJson(String jsonString) {
//     try {
//       return json.decode(jsonString);
//     } catch (e) {
//       // If still error, try with manual approach
//       print('Trying alternative JSON parsing approach');
//
//       try {
//         // Fallback to default empty object
//         return {};
//       } catch (e) {
//         print('All JSON parsing attempts failed: $e');
//         throw FormatException('Invalid JSON format: $e');
//       }
//     }
//   }
// }