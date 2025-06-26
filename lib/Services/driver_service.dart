// lib/Services/driver_service.dart
import 'dart:convert';
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

  // Tambahkan method baru di Services/driver_service.dart

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

      // Tambahkan di bagian atas method _calculateDriverStatisticsFromRequests untuk debug:

      print('📊 Sample request data structure:');
      if (allRequests.isNotEmpty) {
        final sample = allRequests.first;
        print('   - Request ID: ${sample['id']}');
        print('   - Request Status: ${sample['status']}');
        print('   - Has Order: ${sample['order'] != null}');
        if (sample['order'] != null) {
          final order = sample['order'];
          print('   - Order ID: ${order['id']}');
          print('   - Order Status: ${order['order_status']}');
          print('   - Delivery Fee: ${order['delivery_fee']}');
          print('   - Total Amount: ${order['total_amount']}');
        }
      }

// Tambahkan logging detail untuk setiap kategori:
      print('📊 Categorizing ${allRequests.length} requests...');
      Map<String, int> statusCount = {};
      for (var request in allRequests) {
        final status = request['status']?.toString().toLowerCase() ?? 'unknown';
        statusCount[status] = (statusCount[status] ?? 0) + 1;
      }
      print('📊 Status breakdown: $statusCount');

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

  /// Calculate driver statistics from driver requests data only
  static Map<String, dynamic> _calculateDriverStatisticsFromRequests(
      List<dynamic> allRequests) {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      print('📊 Processing ${allRequests.length} driver requests...');

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

            print(
                '📦 Delivered order: ID ${order['id']}, Fee: Rp $deliveryFee');
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

      final result = {
        'total_requests': totalRequests,
        'accepted_requests': acceptedRequests,
        'cancelled_by_driver': rejectedByDriver,
        'pending_requests': pendingRequests,
        'acceptance_rate': double.parse(acceptanceRate.toStringAsFixed(2)),
        'total_earnings': totalEarnings,
        'today_earnings': todayEarnings,
        'completed_today': completedToday,
        'raw_data': {
          'total_requests_found': allRequests.length,
          'handled_requests': totalRequests,
          'delivered_orders_found': deliveredOrders.length,
          'pending_found': pendingRequests,
          'rejected_found': rejectedByDriver,
        }
      };

      print('📊 Statistics Summary:');
      print('   - Total Handled: $totalRequests');
      print('   - Delivered: $acceptedRequests');
      print('   - Rejected: $rejectedByDriver');
      print('   - Pending: $pendingRequests');
      print('   - Success Rate: ${acceptanceRate.toStringAsFixed(1)}%');
      print('   - Total Earnings: Rp $totalEarnings');
      print('   - Today Earnings: Rp $todayEarnings');

      return result;
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
