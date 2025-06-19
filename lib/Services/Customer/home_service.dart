// lib/services/customer/home_service.dart
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../Models/Base/api_response.dart';
import '../../Models/Entities/store.dart';
import '../../Models/Entities/user.dart';
import '../../Models/Exceptions/api_exception.dart';
import '../../Services/Store/store_service.dart';
import '../../Services/Utils/location_service.dart';
import '../../Services/Utils/auth_manager.dart';
import '../../Services/Utils/error_handler.dart';
import '../../Services/Auth/auth_service.dart';
import '../../Services/User/user_service.dart';

class HomeService {
  // Get all stores
  static Future<List<Store>> getAllStores() async {
    try {
      final response = await StoreService.getAllStores();

      if (response.isSuccess && response.data != null) {
        return response.data!;
      } else {
        throw ApiException(
          message: response.message,
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      ErrorHandler.logError(e, context: 'HomeService.getAllStores');
      rethrow;
    }
  }

  // Get nearby stores based on location
  static Future<List<Store>> getNearbyStores({
    required double latitude,
    required double longitude,
    double radius = 10.0,
    int limit = 10,
  }) async {
    try {
      final response = await StoreService.getNearbyStores(
        latitude: latitude,
        longitude: longitude,
        radius: radius,
        limit: limit,
      );

      if (response.isSuccess && response.data != null) {
        return response.data!;
      } else {
        throw ApiException(
          message: response.message,
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      ErrorHandler.logError(e, context: 'HomeService.getNearbyStores');
      rethrow;
    }
  }

  // Get featured stores (highest rating)
  static Future<List<Store>> getFeaturedStores({int limit = 5}) async {
    try {
      final allStores = await getAllStores();

      // Filter and sort stores by rating
      final featuredStores = allStores
          .where((store) => store.rating != null && store.rating! >= 4.0)
          .toList();

      // Sort by rating descending
      featuredStores.sort((a, b) {
        final ratingA = a.rating ?? 0.0;
        final ratingB = b.rating ?? 0.0;
        return ratingB.compareTo(ratingA);
      });

      // Return limited number of featured stores
      return featuredStores.take(limit).toList();
    } catch (e) {
      ErrorHandler.logError(e, context: 'HomeService.getFeaturedStores');
      rethrow;
    }
  }

  // Get user current location
  static Future<Position?> getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      // Check location permission
      var status = await Permission.location.status;
      if (!status.isGranted) {
        status = await Permission.location.request();
        if (!status.isGranted) {
          throw Exception('Location permission denied');
        }
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      return position;
    } catch (e) {
      ErrorHandler.logError(e, context: 'HomeService.getCurrentLocation');
      return null;
    }
  }

  // Calculate distances for stores
  static Map<int, double> calculateStoreDistances(
      List<Store> stores,
      Position userPosition,
      ) {
    Map<int, double> distances = {};

    for (var store in stores) {
      final distance = LocationService.calculateDistance(
        userPosition.latitude,
        userPosition.longitude,
        store.latitude,
        store.longitude,
      );
      distances[store.id] = distance;
    }

    return distances;
  }

  // Get stores with calculated distances
  static Future<StoresWithDistanceResult> getStoresWithDistance({
    Position? userPosition,
  }) async {
    try {
      final stores = await getAllStores();
      Map<int, double> distances = {};

      if (userPosition != null) {
        distances = calculateStoreDistances(stores, userPosition);

        // Sort stores by distance
        stores.sort((a, b) {
          final distanceA = distances[a.id] ?? double.infinity;
          final distanceB = distances[b.id] ?? double.infinity;
          return distanceA.compareTo(distanceB);
        });
      }

      return StoresWithDistanceResult(
        stores: stores,
        distances: distances,
      );
    } catch (e) {
      ErrorHandler.logError(e, context: 'HomeService.getStoresWithDistance');
      rethrow;
    }
  }

  // Get user profile information
  static Future<User?> getUserProfile() async {
    try {
      // Try to get from AuthManager first
      final currentUser = AuthManager.currentUser;
      if (currentUser != null) {
        return currentUser;
      }

      // If not available, fetch from API
      final response = await UserService.getProfile();
      if (response.isSuccess && response.data != null) {
        await AuthManager.updateCurrentUser(response.data!);
        return response.data;
      }

      return null;
    } catch (e) {
      ErrorHandler.logError(e, context: 'HomeService.getUserProfile');
      return null;
    }
  }

  // Search stores by query
  static List<Store> searchStores(List<Store> stores, String query) {
    if (query.isEmpty) return stores;

    final lowercaseQuery = query.toLowerCase();
    return stores.where((store) {
      return store.name.toLowerCase().contains(lowercaseQuery) ||
          (store.description?.toLowerCase().contains(lowercaseQuery) ?? false) ||
          store.address.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  // Get promotional messages
  static List<String> getPromotionalMessages() {
    return [
      "Lapar? Pilih makanan favoritmu sekarang!",
      "Cek toko langganan mu, mungkin ada menu baru!",
      "Yuk, pesan makanan kesukaanmu dalam sekali klik!",
      "Hayo, lagi cari apa? Del Pick siap layani pesanan mu",
      "Waktu makan siang! Pesan sekarang",
      "Kelaparan? Del Pick siap mengantar!",
      "Ingin makan enak tanpa ribet? Del Pick solusinya!",
    ];
  }

  // Get random promotional message
  static String getRandomPromotionalMessage() {
    final messages = getPromotionalMessages();
    final randomIndex = DateTime.now().millisecondsSinceEpoch % messages.length;
    return messages[randomIndex];
  }

  // Format distance for display
  static String formatDistance(double distanceKm) {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).toInt()} m';
    } else {
      return '${distanceKm.toStringAsFixed(1)} km';
    }
  }

  // Check if store is currently open
  static bool isStoreOpen(Store store) {
    if (store.openTime == null || store.closeTime == null) {
      return true; // Assume open if no time specified
    }

    final now = DateTime.now();
    final currentTime = now.hour * 60 + now.minute;

    try {
      final openParts = store.openTime!.split(':');
      final closeParts = store.closeTime!.split(':');

      final openTime = int.parse(openParts[0]) * 60 + int.parse(openParts[1]);
      final closeTime = int.parse(closeParts[0]) * 60 + int.parse(closeParts[1]);

      if (openTime <= closeTime) {
        // Same day (e.g., 9:00 - 17:00)
        return currentTime >= openTime && currentTime <= closeTime;
      } else {
        // Crosses midnight (e.g., 22:00 - 06:00)
        return currentTime >= openTime || currentTime <= closeTime;
      }
    } catch (e) {
      return true; // Default to open if parsing fails
    }
  }
}

// Result class for stores with distance information
class StoresWithDistanceResult {
  final List<Store> stores;
  final Map<int, double> distances;

  StoresWithDistanceResult({
    required this.stores,
    required this.distances,
  });
}