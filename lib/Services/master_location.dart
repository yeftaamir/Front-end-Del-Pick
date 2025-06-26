// lib/Services/master_location_service.dart
import 'dart:math' show sin, cos, atan2, sqrt, pi;
import 'core/base_service.dart';
import 'image_service.dart';
import 'auth_service.dart';

class MasterLocationService {
  static const String _baseEndpoint = '/locations';

  /// Get all active locations with pagination and filtering
  static Future<Map<String, dynamic>> getAllLocations({
    int page = 1,
    int limit = 20,
    bool popularOnly = false,
    String? serviceType,
    String? region,
    String? city,
  }) async {
    try {
      print('🔍 MasterLocationService: Getting all locations...');

      final isAuth = await AuthService.isAuthenticated();
      if (!isAuth) {
        throw Exception('Authentication required');
      }

      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (popularOnly) 'popular_only': 'true',
        if (serviceType != null) 'service_type': serviceType,
        if (region != null) 'region': region,
        if (city != null) 'city': city,
      };

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: _baseEndpoint,
        queryParams: queryParams,
        requiresAuth: true,
      );

      if (response['data'] != null && response['data']['locations'] != null) {
        final locations = response['data']['locations'] as List;
        for (var location in locations) {
          _processLocationImages(location);
        }
        print('✅ MasterLocationService: Retrieved ${locations.length} locations');
      }

      return response['data'] ?? {
        'locations': [],
        'totalItems': 0,
        'totalPages': 0,
        'currentPage': 1,
      };
    } catch (e) {
      print('❌ MasterLocationService: Get all locations error: $e');
      throw Exception('Failed to get locations: $e');
    }
  }

  /// Get popular locations (frequently used)
  static Future<List<Map<String, dynamic>>> getPopularLocations() async {
    try {
      print('🔥 MasterLocationService: Getting popular locations...');

      final isAuth = await AuthService.isAuthenticated();
      if (!isAuth) {
        throw Exception('Authentication required');
      }

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/popular',
        requiresAuth: true,
      );

      if (response['data'] != null && response['data']['locations'] != null) {
        final locations = response['data']['locations'] as List;
        for (var location in locations) {
          _processLocationImages(location);
        }
        print('✅ MasterLocationService: Retrieved ${locations.length} popular locations');
        return List<Map<String, dynamic>>.from(locations);
      }

      return [];
    } catch (e) {
      print('❌ MasterLocationService: Get popular locations error: $e');
      return [];
    }
  }

  /// Search locations by name or address
  static Future<List<Map<String, dynamic>>> searchLocations({
    required String query,
    String? serviceType,
  }) async {
    try {
      print('🔍 MasterLocationService: Searching locations with query: $query');

      if (query.length < 2) {
        throw Exception('Query must be at least 2 characters');
      }

      final isAuth = await AuthService.isAuthenticated();
      if (!isAuth) {
        throw Exception('Authentication required');
      }

      final queryParams = {
        'q': query,
        if (serviceType != null) 'service_type': serviceType,
      };

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/search',
        queryParams: queryParams,
        requiresAuth: true,
      );

      if (response['data'] != null && response['data']['locations'] != null) {
        final locations = response['data']['locations'] as List;
        for (var location in locations) {
          _processLocationImages(location);
        }
        print('✅ MasterLocationService: Found ${locations.length} locations for query: $query');
        return List<Map<String, dynamic>>.from(locations);
      }

      return [];
    } catch (e) {
      print('❌ MasterLocationService: Search locations error: $e');
      throw Exception('Failed to search locations: $e');
    }
  }

  /// Get service fee for pickup location (destinasi tetap ke IT Del)
  static Future<Map<String, dynamic>> getServiceFee({
    required int pickupLocationId,
  }) async {
    try {
      print('💰 MasterLocationService: Getting service fee for location ID: $pickupLocationId');

      final isAuth = await AuthService.isAuthenticated();
      if (!isAuth) {
        throw Exception('Authentication required');
      }

      final queryParams = {
        'pickup_location_id': pickupLocationId.toString(),
      };

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/service-fee',
        queryParams: queryParams,
        requiresAuth: true,
      );

      if (response['data'] != null) {
        print('✅ MasterLocationService: Service fee retrieved successfully');
        print('   - Service Fee: Rp ${response['data']['service_fee']}');
        print('   - Estimated Duration: ${response['data']['estimated_duration']} minutes');
        return response['data'];
      }

      // Return default fee if no specific data found
      return {
        'pickup_location': {'id': pickupLocationId, 'name': 'Unknown Location'},
        'destination': 'IT Del',
        'service_fee': 20000.0,
        'estimated_duration': 30,
        'estimated_duration_text': '30 menit',
      };
    } catch (e) {
      print('❌ MasterLocationService: Get service fee error: $e');

      // Return fallback fee on error
      return {
        'pickup_location': {'id': pickupLocationId, 'name': 'Unknown Location'},
        'destination': 'IT Del',
        'service_fee': 20000.0,
        'estimated_duration': 30,
        'estimated_duration_text': '30 menit',
      };
    }
  }

  /// Get location details by ID
  static Future<Map<String, dynamic>> getLocationById(String locationId) async {
    try {
      print('🔍 MasterLocationService: Getting location by ID: $locationId');

      final isAuth = await AuthService.isAuthenticated();
      if (!isAuth) {
        throw Exception('Authentication required');
      }

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/$locationId',
        requiresAuth: true,
      );

      if (response['data'] != null && response['data']['location'] != null) {
        final location = response['data']['location'];
        _processLocationImages(location);
        print('✅ MasterLocationService: Location details retrieved successfully');
        return location;
      }

      throw Exception('Location not found');
    } catch (e) {
      print('❌ MasterLocationService: Get location by ID error: $e');
      throw Exception('Failed to get location details: $e');
    }
  }

  /// Get service fee by pickup location name (alternative method)
  static Future<Map<String, dynamic>> getServiceFeeByName({
    required String pickupLocationName,
  }) async {
    try {
      print('💰 MasterLocationService: Getting service fee by location name: $pickupLocationName');

      // First search for the location
      final searchResults = await searchLocations(query: pickupLocationName);

      if (searchResults.isNotEmpty) {
        // Use the first matching location
        final firstMatch = searchResults.first;
        final locationId = firstMatch['id'];

        if (locationId != null) {
          return await getServiceFee(pickupLocationId: locationId);
        }
      }

      // Fallback to default fee
      print('⚠️ MasterLocationService: Location not found, using default fee');
      return {
        'pickup_location': {'name': pickupLocationName},
        'destination': 'IT Del',
        'service_fee': 20000.0,
        'estimated_duration': 30,
        'estimated_duration_text': '30 menit',
      };
    } catch (e) {
      print('❌ MasterLocationService: Get service fee by name error: $e');

      // Return fallback fee on error
      return {
        'pickup_location': {'name': pickupLocationName},
        'destination': 'IT Del',
        'service_fee': 20000.0,
        'estimated_duration': 30,
        'estimated_duration_text': '30 menit',
      };
    }
  }

  /// Get nearby locations based on coordinates
  static Future<List<Map<String, dynamic>>> getNearbyLocations({
    required double latitude,
    required double longitude,
    double radiusKm = 10.0,
    int limit = 10,
  }) async {
    try {
      print('📍 MasterLocationService: Getting nearby locations...');

      // Since backend doesn't have specific nearby endpoint,
      // we'll get all locations and filter client-side
      final allLocationsResponse = await getAllLocations(limit: 100);
      final allLocations = allLocationsResponse['locations'] as List? ?? [];

      final nearbyLocations = <Map<String, dynamic>>[];

      for (var location in allLocations) {
        final locLat = double.tryParse(location['latitude']?.toString() ?? '0') ?? 0.0;
        final locLng = double.tryParse(location['longitude']?.toString() ?? '0') ?? 0.0;

        if (locLat != 0.0 && locLng != 0.0) {
          final distance = _calculateDistance(latitude, longitude, locLat, locLng);

          if (distance <= radiusKm) {
            location['distance_km'] = distance;
            nearbyLocations.add(location);
          }
        }
      }

      // Sort by distance and limit results
      nearbyLocations.sort((a, b) =>
          (a['distance_km'] ?? 0.0).compareTo(b['distance_km'] ?? 0.0));

      final limitedResults = nearbyLocations.take(limit).toList();

      print('✅ MasterLocationService: Found ${limitedResults.length} nearby locations');
      return limitedResults;
    } catch (e) {
      print('❌ MasterLocationService: Get nearby locations error: $e');
      return [];
    }
  }

  /// Get location suggestions for autocomplete
  static Future<List<Map<String, dynamic>>> getLocationSuggestions({
    required String partialQuery,
    int limit = 5,
  }) async {
    try {
      if (partialQuery.length < 2) return [];

      final searchResults = await searchLocations(query: partialQuery);

      // Format for autocomplete suggestions
      final suggestions = searchResults.take(limit).map((location) => {
        'id': location['id'],
        'name': location['name'],
        'display_text': location['name'],
        'latitude': location['latitude'],
        'longitude': location['longitude'],
        'service_fee': location['service_fee'],
        'estimated_duration': location['estimated_duration_minutes'],
      }).toList();

      return suggestions;
    } catch (e) {
      print('❌ MasterLocationService: Get location suggestions error: $e');
      return [];
    }
  }

  /// Format service fee for display
  static String formatServiceFee(double serviceFee) {
    try {
      return 'Rp ${serviceFee.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]}.',
      )}';
    } catch (e) {
      return 'Rp 0';
    }
  }

  /// Format estimated duration for display
  static String formatEstimatedDuration(int minutes) {
    try {
      if (minutes >= 60) {
        final hours = minutes ~/ 60;
        final remainingMinutes = minutes % 60;
        if (remainingMinutes > 0) {
          return '${hours}j ${remainingMinutes}m';
        } else {
          return '${hours}j';
        }
      } else {
        return '${minutes}m';
      }
    } catch (e) {
      return '0m';
    }
  }

  /// Check if location is active and available
  static bool isLocationAvailable(Map<String, dynamic> location) {
    try {
      final isActive = location['is_active'] ?? true;
      return isActive == true;
    } catch (e) {
      return false;
    }
  }

  /// Get default IT Del destination data
  static Map<String, dynamic> getITDelDestination() {
    return {
      'id': 'itdel',
      'name': 'IT Del',
      'latitude': 2.3834831864787818,
      'longitude': 99.14857915147614,
      'is_destination': true,
    };
  }

  // PRIVATE HELPER METHODS

  /// Process location images
  static void _processLocationImages(Map<String, dynamic> location) {
    try {
      if (location['image_url'] != null && location['image_url'].toString().isNotEmpty) {
        location['image_url'] = ImageService.getImageUrl(location['image_url']);
      }

      // Process any thumbnail images
      if (location['thumbnail_url'] != null && location['thumbnail_url'].toString().isNotEmpty) {
        location['thumbnail_url'] = ImageService.getImageUrl(location['thumbnail_url']);
      }
    } catch (e) {
      print('❌ MasterLocationService: Error processing location images: $e');
    }
  }

  /// Calculate distance between two coordinates using Haversine formula
  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    try {
      const double earthRadius = 6371; // Earth radius in kilometers

      final double dLat = _degreesToRadians(lat2 - lat1);
      final double dLon = _degreesToRadians(lon2 - lon1);

      final double a =
          (sin(dLat / 2) * sin(dLat / 2)) +
              cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) *
                  (sin(dLon / 2) * sin(dLon / 2));

      final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

      return earthRadius * c;
    } catch (e) {
      return 0.0;
    }
  }

  /// Convert degrees to radians
  static double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }
}
