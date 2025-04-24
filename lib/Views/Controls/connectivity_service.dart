import 'dart:async';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Kelas untuk mengelola konektivitas di seluruh aplikasi
class ConnectivityService extends ChangeNotifier {
  bool _isConnected = true;
  late StreamSubscription<List<ConnectivityResult>> _subscription;

  bool get isConnected => _isConnected;

  ConnectivityService() {
    // Periksa konektivitas saat inisialisasi
    checkConnectivity();

    // Mendengarkan perubahan konektivitas
    _subscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> result) {
      _updateConnectionStatus(result);
    });
  }

  // Periksa status konektivitas saat ini
  Future<void> checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    _updateConnectionStatus(result);
  }

  // Perbarui status konektivitas dan beri tahu listener
  void _updateConnectionStatus(List<ConnectivityResult> result) {
    final wasConnected = _isConnected;
    _isConnected = result.isNotEmpty && result.any((element) => element != ConnectivityResult.none);

    // Notifikasi listener hanya jika status berubah
    if (wasConnected != _isConnected) {
      notifyListeners();
    }
  }

  Future<void> _testHttpRequest() async {
    try {
      final response = await http.get(Uri.parse('https://delpick.horas-code.my.id/'));
      print('HTTP response status: ${response.statusCode}');
      print('HTTP response body (first 100 chars): ${response.body.substring(0, min(100, response.body.length))}');
    } catch (e) {
      print('HTTP request error: $e');
    }
  }



  // Pastikan subscription dibatalkan saat service tidak digunakan
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}