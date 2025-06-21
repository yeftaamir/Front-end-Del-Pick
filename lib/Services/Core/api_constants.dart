// lib/services/core/api_constants.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiConstants {
  static const bool isEmulator = false;
  static const bool isLocalDevelopment = false; // Change to true for local development

  // API URLs
  static const String localApiUrl = 'http://10.0.2.2:6100/api/v1';
  static const String productionApiUrl = 'https://delpick.horas-code.my.id/api/v1';

  // Image URLs
  static const String dbServerUrl = 'http://157.66.56.13';
  static const String productionImageUrl = 'https://delpick.horas-code.my.id';

  // Dynamic URL selection
  static String get baseUrl {
    if (isEmulator && isLocalDevelopment) {
      return 'http://10.0.2.2:6100/api/v1'; // Android Emulator
    } else if (isLocalDevelopment) {
      return 'http://127.0.0.1:6100/api/v1'; // iOS Simulator/Local
    } else {
      return productionApiUrl; // Production
    }
  }

  static String get imageBaseUrl {
    return isLocalDevelopment ? dbServerUrl : productionImageUrl;
  }

  // Secure storage instance
  static final FlutterSecureStorage storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  // Common headers
  static Map<String, String> get defaultHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // Request timeout
  static const Duration requestTimeout = Duration(seconds: 30);
}