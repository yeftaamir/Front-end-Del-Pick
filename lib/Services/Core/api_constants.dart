// lib/Services/core/api_constants.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiConstants {
  // Base URL configuration
  static const String baseUrl = 'https://delpick.horas-code.my.id/api/v1';
  static const String imageBaseUrl = 'https://delpick.horas-code.my.id';
  static const String localApiUrl = 'http://10.0.2.2:6100/api/v1';

  // Secure storage instance with proper configuration
  static const FlutterSecureStorage storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  // Storage keys
  static const String tokenKey = 'auth_token';
  static const String userRoleKey = 'user_role';
  static const String userIdKey = 'user_id';
  static const String userDataKey = 'user_data';
  static const String fcmTokenKey = 'fcm_token';

  // Headers
  static const Map<String, String> headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // Request timeouts
  static const Duration requestTimeout = Duration(seconds: 30);
  static const Duration connectionTimeout = Duration(seconds: 15);
}