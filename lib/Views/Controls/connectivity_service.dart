import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

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

  // Pastikan subscription dibatalkan saat service tidak digunakan
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}