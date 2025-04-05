import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // static const String baseUrl = 'http://localhost:3000/api/v1';
  // static final FlutterSecureStorage _storage = FlutterSecureStorage();

  // Update baseUrl to use the hosted API URL
  static final String baseUrl = dotenv.env['BASE_URL'] ?? 'https://delpick.fun/api/v1'; // Menggunakan dotenv untuk load base URL
  // static const String baseUrl = 'https://delpick.fun/api/v1';  // Update to hosted backend URL
  static final FlutterSecureStorage _storage = FlutterSecureStorage();

  // Authentication Methods
  // Authentication method to login
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    print("API Response Status Code: ${response.statusCode}");
    print("API Response Body: ${response.body}");

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);

      // Pastikan respons mengandung 'data' dan 'token'
      if (data['data'] != null && data['data']['token'] != null) {
        final String token = data['data']['token'];  // Ambil token dari dalam data
        await _saveToken(token);  // Menyimpan token ke secure storage
        return {'token': token};  // Kembalikan token yang ada dalam data
      } else {
        throw Exception('Token not found in the response');
      }
    } else {
      throw Exception('Login failed: ${response.body}');
    }
  }

  // static Future<Map<String, dynamic>> login(String email, String password) async {
  //   final response = await http.post(
  //     // Uri.parse('https://delpick.fun/api/v1/auth/login'),
  //     Uri.parse('$baseUrl/auth/login'),
  //     headers: {'Content-Type': 'application/json'},
  //     body: jsonEncode({'email': email, 'password': password}),
  //   );
  //
  //   print("API Response Status Code: ${response.statusCode}");  // Debugging status code
  //   print("API Response Body: ${response.body}");
  //
  //   if (response.body == 200) {
  //     final Map<String, dynamic> data = json.decode(response.body);
  //     print("Response Body: $data");
  //     // final  token = data['data']['token'];
  //     // final String token = data['token'];
  //     // final String token = data['data']['token'];  // Token received from API
  //     // print("Token: $token");  // Print token to verify
  //
  //     // Pastikan response memiliki key 'data' dan token
  //     if (data['data'] != null && data['data']['token'] != null) {
  //       // final token = data['data']['token'];
  //       final String token = data['data']['token'];
  //       await _saveToken(token);
  //       return {'token': token};  // Return only the token
  //     } else {
  //       throw Exception('Token not found in the response');
  //     }
  //
  //     // await _saveToken(token);
  //     // return {'token': token};  // Return only the token
  //   } else {
  //     throw Exception('Login failed: ${response.body}');
  //   }
  //
  // }
  // static Future<Map<String, dynamic>> login(String email, String password) async {
  //   final response = await http.post(
  //     Uri.parse('$baseUrl/auth/login'),
  //     headers: {'Content-Type': 'application/json'},
  //     body: jsonEncode({
  //       'email': email,
  //       'password': password,
  //     }),
  //   );
  //
  //   if (response.statusCode == 200) {
  //     final Map<String, dynamic> data = json.decode(response.body);
  //     final token = data['token'];
  //     final role = data['role']; // Assuming role is returned here
  //
  //     await _saveToken(token);
  //
  //     return {'role': role, 'token': token};  // Return role with token
  //   } else {
  //     throw Exception('Login failed: ${response.body}');
  //   }
  // }

  // static Future<Map<String, dynamic>> login(String email, String password) async {
  //   final response = await http.post(
  //     Uri.parse('$baseUrl/auth/login'),
  //     headers: {'Content-Type': 'application/json'},
  //     body: jsonEncode({
  //       'email': email,
  //       'password': password,
  //     }),
  //   );
  //
  //   if (response.statusCode == 200) {
  //     final token = json.decode(response.body)['token'];
  //     await _saveToken(token);
  //     return json.decode(response.body);
  //   } else {
  //     throw Exception('Login failed: ${response.body}');
  //   }
  // }

  static Future<Map<String, dynamic>> register(Map<String, dynamic> userData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(userData),
    );

    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception('Registration failed: ${response.body}');
    }
  }

  static Future<void> forgotPassword(String email) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    if (response.statusCode != 200) {
      throw Exception('Forgot password request failed: ${response.body}');
    }
  }

  // Token Management Methods
  static Future<void> _saveToken(String token) async {
    await _storage.write(key: 'auth_token', value: token);
  }

  // Fungsi untuk mengambil token dari secure storage
  static Future<String?> getToken() async {
    return await _storage.read(key: 'auth_token');
  }

  // Fungsi untuk logout dengan menghapus token
  static Future<void> logout() async {
    await _storage.delete(key: 'auth_token');
  }

  static Future<String?> _getToken() async {
    return await _storage.read(key: 'auth_token');
  }

  static Future<void> _removeToken() async {
    await _storage.delete(key: 'auth_token');
  }

  // Customer Methods
  static Future<List<dynamic>> getAllCustomers() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/customers'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to fetch customers: ${response.body}');
    }
  }

  // Driver Methods
  static Future<void> updateDriverLocation(Map<String, dynamic> locationData) async {
    final token = await _getToken();
    final response = await http.put(
      Uri.parse('$baseUrl/drivers/location'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(locationData),
    );

    if (response.statusCode != 200) {
      throw Exception('Location update failed: ${response.body}');
    }
  }

  // Store Methods
  static Future<List<dynamic>> getAllStores() async {
    final response = await http.get(Uri.parse('$baseUrl/stores'));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to fetch stores: ${response.body}');
    }
  }

  // Menu Item Methods
  static Future<List<dynamic>> getAllMenuItems() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/menu-items'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to fetch menu items: ${response.body}');
    }
  }

  // Order Methods
  static Future<dynamic> placeOrder(Map<String, dynamic> orderData) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/orders'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(orderData),
    );

    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception('Order placement failed: ${response.body}');
    }
  }

  // Tracking Methods
  static Future<dynamic> getRealtimeTracking(String orderId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/tracking/tracking/$orderId'),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to fetch order tracking: ${response.body}');
    }
  }
}