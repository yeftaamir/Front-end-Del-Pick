// lib/services/core/api_constants.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiConstants {
  static const bool isEmulator = false;
  static const bool isLocalDevelopment = true;

  // URL API untuk server local
  static const String localApiUrl = 'http://10.0.2.2:6100/api/v1';

  // URL untuk server produksi
  static const String productionApiUrl = 'https://delpick.horas-code.my.id/api/v1';

  static const String prodBaseUrl = 'https://delpick.horas-code.my.id';

  static const String devBaseUrl = 'http://10.0.2.2:6100/api/v1';
  // static const String baseUrl = 'http://127.0.0.1:6100/api/v1';

  // URL untuk mengakses gambar (database server)
  static const String dbServerUrl = 'http://157.66.56.13';
  // URL untuk akses gambar produksi
  static const String productionImageUrl = 'https://delpick.horas-code.my.id';

  // URL untuk mengakses gambar
  static const String imageBaseUrl = 'https://delpick.horas-code.my.id';

  // URL yang digunakan untuk API berdasarkan mode
  // static String get baseUrl => isLocalDevelopment ? localApiUrl : productionApiUrl;

  // URL yang digunakan untuk akses gambar
  // static String get imageBaseUrl => isLocalDevelopment ? dbServerUrl : productionImageUrl;

  // Choose which one to use
  // static final String baseUrl = prodBaseUrl;

  static String get baseUrl {
    if (isEmulator) {
      return 'http://10.0.2.2:6100/api/v1'; // Untuk Android Emulator
      // return 'http://localhost:6100'; // Untuk iOS Simulator
    } else {
      return 'https://delpick.horas-code.my.id/api/v1'; // URL produksi
    }
  }

  // static final String imageBaseUrl = dbServerUrl;



  static final FlutterSecureStorage storage = FlutterSecureStorage();
}