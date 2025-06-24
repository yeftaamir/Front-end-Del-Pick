// File: Helper class untuk navigasi ke Store Detail
// lib/Utils/navigation_helper.dart

import 'package:flutter/material.dart';
import 'package:del_pick/Views/Customers/store_detail.dart';
import 'package:del_pick/Models/store.dart';

class NavigationHelper {
  /// Navigate to store detail dengan berbagai jenis input
  static void navigateToStoreDetail(BuildContext context, dynamic storeData) {
    int? storeId;

    try {
      // Handle berbagai tipe input
      if (storeData is int) {
        storeId = storeData;
      } else if (storeData is String) {
        storeId = int.tryParse(storeData);
      } else if (storeData is StoreModel) {
        storeId = storeData.storeId;
      } else if (storeData is Map<String, dynamic>) {
        // Handle jika data berupa Map
        storeId = storeData['id'] ?? storeData['store_id'] ?? storeData['storeId'];
        if (storeId is String) {
          storeId = int.tryParse(storeId as String);
        } else if (storeId is! int) {
          storeId = null;
        }
      }

      if (storeId != null && storeId > 0) {
        Navigator.pushNamed(
          context,
          StoreDetail.route,
          arguments: storeId, // Selalu kirim sebagai integer
        );
      } else {
        _showErrorDialog(context, 'Invalid store ID: $storeData');
      }
    } catch (e) {
      print('❌ Navigation error: $e');
      _showErrorDialog(context, 'Failed to navigate to store detail');
    }
  }

  /// Navigate dengan route name untuk konsistensi
  static void navigateToStoreDetailById(BuildContext context, int storeId) {
    if (storeId > 0) {
      Navigator.pushNamed(
        context,
        StoreDetail.route,
        arguments: storeId,
      );
    } else {
      _showErrorDialog(context, 'Invalid store ID: $storeId');
    }
  }

  /// Navigate menggunakan MaterialPageRoute untuk fleksibilitas
  static void pushStoreDetail(BuildContext context, int storeId) {
    if (storeId > 0) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const StoreDetail(),
          settings: RouteSettings(
            name: StoreDetail.route,
            arguments: storeId,
          ),
        ),
      );
    } else {
      _showErrorDialog(context, 'Invalid store ID: $storeId');
    }
  }

  static void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}