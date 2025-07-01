// lib/Services/driver_service.dart
import 'dart:convert';
import 'dart:math' as math;
import 'package:del_pick/Services/driver_request_service.dart';

import 'core/base_service.dart';
import 'image_service.dart';

class DriverService {
  static const String _baseEndpoint = '/drivers';

  /// Get all drivers (admin only)
  static Future<Map<String, dynamic>> getAllDrivers({
    int page = 1,
    int limit = 10,
    String? sortBy,
    String? sortOrder,
    String? status,
    String? search,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (sortBy != null) 'sortBy': sortBy,
        if (sortOrder != null) 'sortOrder': sortOrder,
        if (status != null) 'status': status,
        if (search != null) 'search': search,
      };

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: _baseEndpoint,
        queryParams: queryParams,
        requiresAuth: true,
      );

      // Process driver images from the correct data structure
      if (response['data'] != null && response['data'] is List) {
        for (var driver in response['data']) {
          _processDriverImages(driver);
        }
      }

      return {
        'drivers': response['data'] ?? [],
        'totalItems': response['totalItems'] ?? 0,
        'totalPages': response['totalPages'] ?? 0,
        'currentPage': response['currentPage'] ?? 1,
      };
    } catch (e) {
      print('Get all drivers error: $e');
      throw Exception('Failed to get drivers: $e');
    }
  }

  /// Get driver by ID
  static Future<Map<String, dynamic>> getDriverById(String driverId) async {
    try {
      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/$driverId',
        requiresAuth: true,
      );

      if (response['data'] != null) {
        final driverData = response['data'];
        _processDriverImages(driverData);
        return driverData;
      }

      return {};
    } catch (e) {
      print('Get driver by ID error: $e');
      throw Exception('Failed to get driver: $e');
    }
  }

  // ============================================================================
  // 🚗 ACTIVE DRIVER MANAGEMENT - NEW SERVICES
  // ============================================================================

  /// Get all active drivers with full details
  static Future<Map<String, dynamic>> getActiveDrivers({
    int page = 1,
    int limit = 50,
    String? sortBy = 'name',
    String? sortOrder = 'asc',
  }) async {
    try {
      print('🚗 DriverService: Getting active drivers...');

      // Use existing getAllDrivers with status filter
      final response = await getAllDrivers(
        page: page,
        limit: limit,
        sortBy: sortBy,
        sortOrder: sortOrder,
        status: 'active', // Filter hanya driver aktif
      );

      final List<dynamic> allDrivers = response['drivers'] ?? [];

      // Additional filtering untuk memastikan driver benar-benar aktif
      final activeDrivers = allDrivers.where((driver) {
        final status = driver['status']?.toString().toLowerCase();
        return status == 'active';
      }).toList();

      print('✅ Found ${activeDrivers.length} active drivers');

      return {
        'drivers': activeDrivers,
        'totalItems': activeDrivers.length,
        'totalPages': (activeDrivers.length / limit).ceil(),
        'currentPage': page,
      };
    } catch (e) {
      print('❌ DriverService: Error getting active drivers: $e');
      throw Exception('Failed to get active drivers: $e');
    }
  }

  /// Get active drivers with comprehensive details including location and statistics
  static Future<List<Map<String, dynamic>>> getActiveDriversWithDetails({
    double? userLatitude,
    double? userLongitude,
    int maxRadius = 20, // km
  }) async {
    try {
      print('🚗 DriverService: Getting active drivers with full details...');

      // Get all active drivers (without pagination limit)
      final activeResponse = await getActiveDrivers(limit: 100);
      final List<dynamic> activeDrivers = activeResponse['drivers'] ?? [];

      List<Map<String, dynamic>> driversWithDetails = [];

      for (var driver in activeDrivers) {
        try {
          // Get driver details
          final driverId = driver['id']?.toString();
          if (driverId == null) continue;

          final driverDetails = await getDriverById(driverId);
          if (driverDetails.isEmpty) continue;

          // Calculate distance if user location provided
          double? distance;
          if (userLatitude != null && userLongitude != null) {
            final driverLat = _parseDouble(driverDetails['latitude']);
            final driverLng = _parseDouble(driverDetails['longitude']);

            if (driverLat != null && driverLng != null) {
              distance = _calculateDistance(
                userLatitude, userLongitude,
                driverLat, driverLng,
              );

              // Skip driver if too far
              if (distance > maxRadius) continue;
            }
          }

          // Get driver statistics
          final driverStats = await _getDriverStatistics(driverId);

          // Compile comprehensive driver data
          final driverWithDetails = {
            ...driverDetails,
            'distance_km': distance,
            'statistics': driverStats,
            'availability_score': _calculateAvailabilityScore(driverDetails, driverStats),
            'last_active': driverDetails['updated_at'],
          };

          driversWithDetails.add(driverWithDetails);

        } catch (e) {
          print('⚠️ Error processing driver ${driver['id']}: $e');
          continue;
        }
      }

      // Sort by availability score and distance
      driversWithDetails.sort((a, b) {
        // Primary sort: availability score (higher is better)
        final scoreA = a['availability_score'] ?? 0.0;
        final scoreB = b['availability_score'] ?? 0.0;

        if (scoreA != scoreB) {
          return scoreB.compareTo(scoreA);
        }

        // Secondary sort: distance (closer is better)
        final distanceA = a['distance_km'] ?? double.infinity;
        final distanceB = b['distance_km'] ?? double.infinity;

        return distanceA.compareTo(distanceB);
      });

      print('✅ Found ${driversWithDetails.length} active drivers with details');

      return driversWithDetails;

    } catch (e) {
      print('❌ DriverService: Error getting active drivers with details: $e');
      throw Exception('Failed to get active drivers with details: $e');
    }
  }

  /// Find nearest active driver based on location
  static Future<Map<String, dynamic>?> findNearestActiveDriver({
    required double userLatitude,
    required double userLongitude,
    int maxRadius = 10, // km
    int minRating = 3, // minimum rating
  }) async {
    try {
      print('🎯 DriverService: Finding nearest active driver...');
      print('   📍 User location: $userLatitude, $userLongitude');
      print('   📏 Max radius: ${maxRadius}km');

      final driversWithDetails = await getActiveDriversWithDetails(
        userLatitude: userLatitude,
        userLongitude: userLongitude,
        maxRadius: maxRadius,
      );

      // Filter by minimum rating
      final qualifiedDrivers = driversWithDetails.where((driver) {
        final rating = _parseDouble(driver['rating']) ?? 0.0;
        return rating >= minRating;
      }).toList();

      if (qualifiedDrivers.isEmpty) {
        print('⚠️ No qualified drivers found within radius');
        return null;
      }

      // Return the best driver (already sorted by availability score and distance)
      final bestDriver = qualifiedDrivers.first;

      print('✅ Found nearest driver: ${bestDriver['name']}');
      print('   📏 Distance: ${bestDriver['distance_km']?.toStringAsFixed(2)}km');
      print('   ⭐ Rating: ${bestDriver['rating']}');
      print('   📊 Availability Score: ${bestDriver['availability_score']}');

      return bestDriver;

    } catch (e) {
      print('❌ DriverService: Error finding nearest active driver: $e');
      return null;
    }
  }

  /// Get available drivers for order assignment
  static Future<List<Map<String, dynamic>>> getAvailableDriversForOrder({
    required Map<String, dynamic> orderData,
    int maxDrivers = 5,
  }) async {
    try {
      print('📦 DriverService: Getting available drivers for order...');

      // Extract store location from order
      final store = orderData['store'];
      final storeLat = _parseDouble(store?['latitude']);
      final storeLng = _parseDouble(store?['longitude']);

      if (storeLat == null || storeLng == null) {
        print('⚠️ Store location not available');
        return [];
      }

      // Get drivers near store location
      final availableDrivers = await getActiveDriversWithDetails(
        userLatitude: storeLat,
        userLongitude: storeLng,
        maxRadius: 15, // 15km radius from store
      );

      // Additional filtering for order assignment
      final suitableDrivers = availableDrivers.where((driver) {
        // Check if driver is not currently busy
        final status = driver['status']?.toString().toLowerCase();
        if (status != 'active') return false;

        // Check minimum rating (3.0)
        final rating = _parseDouble(driver['rating']) ?? 0.0;
        if (rating < 3.0) return false;

        // Check if driver has been active recently (within 30 minutes)
        final lastActive = driver['updated_at'];
        if (lastActive != null) {
          final lastActiveTime = DateTime.tryParse(lastActive);
          if (lastActiveTime != null) {
            final timeDiff = DateTime.now().difference(lastActiveTime);
            if (timeDiff.inMinutes > 30) return false;
          }
        }

        return true;
      }).take(maxDrivers).toList();

      print('✅ Found ${suitableDrivers.length} suitable drivers for order');

      return suitableDrivers;

    } catch (e) {
      print('❌ DriverService: Error getting available drivers for order: $e');
      return [];
    }
  }

  /// Check driver availability status
  static Future<Map<String, dynamic>> checkDriverAvailability(String driverId) async {
    try {
      print('🔍 DriverService: Checking driver availability: $driverId');

      final driver = await getDriverById(driverId);
      if (driver.isEmpty) {
        return {
          'available': false,
          'reason': 'Driver not found',
        };
      }

      final status = driver['status']?.toString().toLowerCase();
      final latitude = _parseDouble(driver['latitude']);
      final longitude = _parseDouble(driver['longitude']);
      final lastUpdate = driver['updated_at'];

      // Check if driver is active
      if (status != 'active') {
        return {
          'available': false,
          'reason': 'Driver status is not active',
          'current_status': status,
        };
      }

      // Check if location is available
      if (latitude == null || longitude == null) {
        return {
          'available': false,
          'reason': 'Driver location not available',
        };
      }

      // Check if driver has been active recently
      bool isRecentlyActive = false;
      if (lastUpdate != null) {
        final lastUpdateTime = DateTime.tryParse(lastUpdate);
        if (lastUpdateTime != null) {
          final timeDiff = DateTime.now().difference(lastUpdateTime);
          isRecentlyActive = timeDiff.inMinutes <= 30;
        }
      }

      if (!isRecentlyActive) {
        return {
          'available': false,
          'reason': 'Driver has not been active recently',
          'last_update': lastUpdate,
        };
      }

      return {
        'available': true,
        'driver_data': driver,
        'last_update': lastUpdate,
        'location': {
          'latitude': latitude,
          'longitude': longitude,
        },
      };

    } catch (e) {
      print('❌ DriverService: Error checking driver availability: $e');
      return {
        'available': false,
        'reason': 'Error checking availability: $e',
      };
    }
  }

  // ============================================================================
  // 📊 EXISTING METHODS (unchanged)
  // ============================================================================

  /// Create new driver (admin only)
  static Future<Map<String, dynamic>> createDriver({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String licenseNumber,
    required String vehiclePlate,
    String? avatar,
    String status = 'active',
  }) async {
    try {
      final body = {
        'name': name,
        'email': email,
        'password': password,
        'phone': phone,
        'license_number': licenseNumber,
        'vehicle_plate': vehiclePlate,
        'status': status,
        if (avatar != null) 'avatar': avatar,
      };

      final response = await BaseService.apiCall(
        method: 'POST',
        endpoint: _baseEndpoint,
        body: body,
        requiresAuth: true,
      );

      if (response['data'] != null) {
        final createdData = response['data'];
        if (createdData['driver'] != null) {
          _processDriverImages(createdData['driver']);
        }
        return createdData;
      }

      return {};
    } catch (e) {
      print('Create driver error: $e');
      throw Exception('Failed to create driver: $e');
    }
  }

  /// Update driver profile (admin only)
  static Future<Map<String, dynamic>> updateDriverProfile({
    required String driverId,
    required Map<String, dynamic> updateData,
  }) async {
    try {
      final response = await BaseService.apiCall(
        method: 'PUT',
        endpoint: '$_baseEndpoint/$driverId',
        body: updateData,
        requiresAuth: true,
      );

      if (response['data'] != null) {
        final updatedData = response['data'];
        if (updatedData['driver'] != null) {
          _processDriverImages(updatedData['driver']);
        }
        return updatedData;
      }

      return {};
    } catch (e) {
      print('Update driver profile error: $e');
      throw Exception('Failed to update driver profile: $e');
    }
  }

  /// Delete driver (admin only)
  static Future<bool> deleteDriver(String driverId) async {
    try {
      await BaseService.apiCall(
        method: 'DELETE',
        endpoint: '$_baseEndpoint/$driverId',
        requiresAuth: true,
      );
      return true;
    } catch (e) {
      print('Delete driver error: $e');
      return false;
    }
  }

  /// Update driver status (admin only) - FIXED LOGIC
  static Future<Map<String, dynamic>> updateDriverStatus({
    required String driverId,
    required String status, // active, inactive, busy
  }) async {
    try {
      if (!['active', 'inactive', 'busy'].contains(status)) {
        throw Exception('Invalid status. Must be: active, inactive, or busy');
      }

      final response = await BaseService.apiCall(
        method: 'PATCH',
        endpoint: '$_baseEndpoint/$driverId/status',
        body: {'status': status},
        requiresAuth: true,
      );

      return response['data'] ?? {};
    } catch (e) {
      print('Update driver status error: $e');
      throw Exception('Failed to update driver status: $e');
    }
  }

  /// Update driver location (driver only)
  static Future<Map<String, dynamic>> updateDriverLocation({
    required String driverId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      // Validate coordinates
      if (latitude < -90 || latitude > 90) {
        throw Exception('Invalid latitude. Must be between -90 and 90');
      }
      if (longitude < -180 || longitude > 180) {
        throw Exception('Invalid longitude. Must be between -180 and 180');
      }

      final response = await BaseService.apiCall(
        method: 'PATCH',
        endpoint: '$_baseEndpoint/$driverId/location',
        body: {
          'latitude': latitude,
          'longitude': longitude,
        },
        requiresAuth: true,
      );

      return response['data'] ?? {};
    } catch (e) {
      print('Update driver location error: $e');
      throw Exception('Failed to update driver location: $e');
    }
  }

  /// Get driver location by ID
  static Future<Map<String, dynamic>> getDriverLocation(String driverId) async {
    try {
      final driver = await getDriverById(driverId);

      return {
        'latitude': driver['latitude'],
        'longitude': driver['longitude'],
        'status': driver['status'],
        'last_updated': driver['updated_at'],
      };
    } catch (e) {
      print('Get driver location error: $e');
      throw Exception('Failed to get driver location: $e');
    }
  }

  /// Get driver orders
  static Future<Map<String, dynamic>> getDriverOrders({
    int page = 1,
    int limit = 10,
    String? status,
    String? sortBy,
    String? sortOrder,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (status != null) 'status': status,
        if (sortBy != null) 'sortBy': sortBy,
        if (sortOrder != null) 'sortOrder': sortOrder,
      };

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '/orders/driver',
        queryParams: queryParams,
        requiresAuth: true,
      );

      return response['data'] ??
          {
            'orders': [],
            'totalItems': 0,
            'totalPages': 0,
            'currentPage': 1,
          };
    } catch (e) {
      print('Get driver orders error: $e');
      throw Exception('Failed to get driver orders: $e');
    }
  }

  /// Get comprehensive driver statistics using driver-requests endpoint
  static Future<Map<String, dynamic>> getComprehensiveDriverStats() async {
    try {
      print('📊 DriverService: Calculating comprehensive driver statistics...');

      // Get ALL driver requests dengan limit besar untuk mengambil semua data
      final driverRequestsData = await DriverRequestService.getDriverRequests(
        page: 1,
        limit: 1000, // Ambil semua data
        sortBy: 'created_at',
        sortOrder: 'desc',
      );

      final List<dynamic> allRequests = driverRequestsData['requests'] ?? [];

      print('📊 Found ${allRequests.length} driver requests');

      // Calculate statistics from driver requests data
      final stats = _calculateDriverStatisticsFromRequests(allRequests);

      print('✅ DriverService: Comprehensive stats calculated');
      print('   - Total Requests: ${stats['total_requests']}');
      print('   - Delivered Orders: ${stats['accepted_requests']}');
      print('   - Total Earnings: ${stats['total_earnings']}');
      print('   - Success Rate: ${stats['acceptance_rate']}%');

      return stats;
    } catch (e) {
      print('❌ DriverService: Error calculating comprehensive stats: $e');

      // Return default stats
      return {
        'total_requests': 0,
        'accepted_requests': 0,
        'cancelled_by_driver': 0,
        'pending_requests': 0,
        'acceptance_rate': 0.0,
        'total_earnings': 0.0,
        'today_earnings': 0.0,
        'completed_today': 0,
      };
    }
  }

  // ============================================================================
  // 🔧 HELPER METHODS
  // ============================================================================

  /// Helper method to process driver images
  static void _processDriverImages(Map<String, dynamic> driver) {
    try {
      // Process user avatar if nested in user object
      if (driver['user'] != null &&
          driver['user']['avatar'] != null &&
          driver['user']['avatar'].toString().isNotEmpty) {
        driver['user']['avatar'] =
            ImageService.getImageUrl(driver['user']['avatar']);
      }

      // Process direct avatar if present
      if (driver['avatar'] != null && driver['avatar'].toString().isNotEmpty) {
        driver['avatar'] = ImageService.getImageUrl(driver['avatar']);
      }
    } catch (e) {
      print('Error processing driver images: $e');
    }
  }

  /// Calculate distance between two coordinates (Haversine formula)
  static double _calculateDistance(
      double lat1, double lon1,
      double lat2, double lon2
      ) {
    const double earthRadius = 6371; // Earth radius in kilometers

    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) * math.sin(dLon / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  /// Convert degrees to radians
  static double _toRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  /// Calculate driver availability score based on multiple factors
  static double _calculateAvailabilityScore(
      Map<String, dynamic> driver,
      Map<String, dynamic> stats
      ) {
    double score = 0.0;

    try {
      // Base score for being active
      final status = driver['status']?.toString().toLowerCase();
      if (status == 'active') score += 40.0;

      // Rating factor (0-30 points)
      final rating = _parseDouble(driver['rating']) ?? 0.0;
      score += (rating / 5.0) * 30.0;

      // Success rate factor (0-20 points)
      final successRate = _parseDouble(stats['acceptance_rate']) ?? 0.0;
      score += (successRate / 100.0) * 20.0;

      // Recent activity factor (0-10 points)
      final lastUpdate = driver['updated_at'];
      if (lastUpdate != null) {
        final lastUpdateTime = DateTime.tryParse(lastUpdate);
        if (lastUpdateTime != null) {
          final timeDiff = DateTime.now().difference(lastUpdateTime);
          if (timeDiff.inMinutes <= 10) {
            score += 10.0;
          } else if (timeDiff.inMinutes <= 30) {
            score += 5.0;
          }
        }
      }

    } catch (e) {
      print('Error calculating availability score: $e');
    }

    return math.min(score, 100.0); // Cap at 100
  }

  /// Get driver statistics (simplified version for individual drivers)
  static Future<Map<String, dynamic>> _getDriverStatistics(String driverId) async {
    try {
      // Get driver requests for this specific driver
      final driverRequestsData = await DriverRequestService.getDriverRequests(
        page: 1,
        limit: 100,
      );

      final List<dynamic> requests = driverRequestsData['requests'] ?? [];

      return _calculateDriverStatisticsFromRequests(requests);
    } catch (e) {
      print('Error getting driver statistics for $driverId: $e');
      return {
        'total_requests': 0,
        'accepted_requests': 0,
        'cancelled_by_driver': 0,
        'acceptance_rate': 0.0,
        'total_earnings': 0.0,
      };
    }
  }

  /// Calculate driver statistics from driver requests data only
  static Map<String, dynamic> _calculateDriverStatisticsFromRequests(
      List<dynamic> allRequests) {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // 1. Total Requests yang pernah ditangani driver (accepted + rejected + completed + expired)
      final handledRequests = allRequests.where((request) {
        final status = request['status']?.toString().toLowerCase() ?? '';
        return ['accepted', 'rejected', 'completed', 'expired']
            .contains(status);
      }).toList();

      final totalRequests = handledRequests.length;

      // 2. Requests yang di-reject oleh driver
      final rejectedByDriver = allRequests.where((request) {
        final status = request['status']?.toString().toLowerCase() ?? '';
        return status == 'rejected';
      }).length;

      // 3. Pending requests (masih menunggu)
      final pendingRequests = allRequests.where((request) {
        final status = request['status']?.toString().toLowerCase() ?? '';
        return status == 'pending';
      }).length;

      // 4. Delivered orders dan earnings calculation
      final deliveredOrders = <Map<String, dynamic>>[];
      double totalEarnings = 0.0;
      double todayEarnings = 0.0;
      int completedToday = 0;

      for (var request in allRequests) {
        try {
          final requestStatus =
              request['status']?.toString().toLowerCase() ?? '';
          final order = request['order'];

          if (order == null) continue;

          final orderStatus =
              order['order_status']?.toString().toLowerCase() ?? '';

          // Hanya hitung yang benar-benar delivered
          if (requestStatus == 'accepted' && orderStatus == 'delivered') {
            deliveredOrders.add(order);

            // Calculate earnings dari delivery fee
            final deliveryFee = _parseDouble(order['delivery_fee'] ?? 0);
            totalEarnings += deliveryFee;

            // Check if delivered today
            final deliveredAt = _parseDateTime(
                order['actual_delivery_time'] ?? order['updated_at']);

            if (deliveredAt != null) {
              final deliveredDate = DateTime(
                  deliveredAt.year, deliveredAt.month, deliveredAt.day);
              if (deliveredDate.isAtSameMomentAs(today)) {
                todayEarnings += deliveryFee;
                completedToday++;
              }
            }
          }
        } catch (e) {
          print('⚠️ Error processing request: $e');
          continue;
        }
      }

      final acceptedRequests = deliveredOrders.length;

      // 5. Success Rate (delivered orders / total handled requests)
      final acceptanceRate =
      totalRequests > 0 ? (acceptedRequests / totalRequests) * 100 : 0.0;

      return {
        'total_requests': totalRequests,
        'accepted_requests': acceptedRequests,
        'cancelled_by_driver': rejectedByDriver,
        'pending_requests': pendingRequests,
        'acceptance_rate': double.parse(acceptanceRate.toStringAsFixed(2)),
        'total_earnings': totalEarnings,
        'today_earnings': todayEarnings,
        'completed_today': completedToday,
      };
    } catch (e) {
      print('❌ Error in _calculateDriverStatisticsFromRequests: $e');
      return {
        'total_requests': 0,
        'accepted_requests': 0,
        'cancelled_by_driver': 0,
        'pending_requests': 0,
        'acceptance_rate': 0.0,
        'total_earnings': 0.0,
        'today_earnings': 0.0,
        'completed_today': 0,
      };
    }
  }

  /// Safe parse double from various formats
  static double _parseDouble(dynamic value) {
    try {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        String cleanValue = value
            .replaceAll('Rp', '')
            .replaceAll(' ', '')
            .replaceAll(',', '')
            .trim();
        if (cleanValue.isEmpty) return 0.0;
        return double.tryParse(cleanValue) ?? 0.0;
      }
      return 0.0;
    } catch (e) {
      print('Error parsing double value "$value": $e');
      return 0.0;
    }
  }

  /// Safe parse DateTime
  static DateTime? _parseDateTime(dynamic value) {
    try {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String) {
        return DateTime.tryParse(value);
      }
      return null;
    } catch (e) {
      print('Error parsing DateTime value "$value": $e');
      return null;
    }
  }
}