// lib/Services/driver_request_service.dart
import 'dart:convert';
import 'core/base_service.dart';
import 'image_service.dart';
import 'auth_service.dart';

class DriverRequestService {
  static const String _baseEndpoint = '/driver-requests';
  static const bool _debugMode = false; // Toggle for development debugging

  static void _log(String message) {
    if (_debugMode) print(message);
  }

  /// Get driver requests - Optimized version
  static Future<Map<String, dynamic>> getDriverRequests({
    int page = 1,
    int limit = 20,
    String? status,
    String? sortBy,
    String? sortOrder,
  }) async {
    try {
      _log('Getting driver requests...');

      // Validate driver authentication and role
      final isValid = await _validateDriverAccess();
      if (!isValid) {
        throw Exception('Invalid driver access');
      }

      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (status != null) 'status': status,
        if (sortBy != null) 'sortBy': sortBy,
        if (sortOrder != null) 'sortOrder': sortOrder,
      };

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: _baseEndpoint,
        queryParams: queryParams,
        requiresAuth: true,
      );

      // Process response structure
      Map<String, dynamic> result = {
        'requests': [],
        'totalItems': 0,
        'totalPages': 0,
        'currentPage': 1,
      };

      if (response['data'] != null && response['data']['requests'] != null) {
        final requests = response['data']['requests'] as List;

        // Batch process all requests
        for (var request in requests) {
          _processRequestData(request);
        }

        result = {
          'requests': requests,
          'totalItems': response['data']['totalItems'] ?? 0,
          'totalPages': response['data']['totalPages'] ?? 0,
          'currentPage': response['data']['currentPage'] ?? 1,
        };
      }

      _log('Retrieved ${result['requests']?.length ?? 0} requests');
      return result;
    } catch (e) {
      _log('Error getting driver requests: $e');
      throw Exception('Failed to get driver requests: $e');
    }
  }

  /// Get detailed driver request - Optimized
  static Future<Map<String, dynamic>> getDriverRequestDetail(String requestId) async {
    try {
      _log('Getting request detail for ID: $requestId');

      // Validate driver authentication
      final isValid = await _validateDriverAccess();
      if (!isValid) {
        throw Exception('Invalid driver access');
      }

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/$requestId',
        requiresAuth: true,
      );

      if (response['data'] != null) {
        final requestDetail = response['data'];

        // Process all data in batch
        _processRequestData(requestDetail);

        _log('Request detail retrieved and processed successfully');
        return requestDetail;
      }

      throw Exception('Driver request not found');
    } catch (e) {
      _log('Error getting request detail: $e');
      throw Exception('Failed to get request detail: $e');
    }
  }

  /// Respond to driver request - Optimized
  static Future<Map<String, dynamic>> respondToDriverRequest({
    required String requestId,
    required String action,
    String? estimatedPickupTime,
    String? estimatedDeliveryTime,
    String? notes,
  }) async {
    try {
      _log('Responding to request $requestId with action: $action');

      // Validate driver authentication and role
      final isValid = await _validateDriverAccess();
      if (!isValid) {
        throw Exception('Invalid driver access');
      }

      if (!['accept', 'reject'].contains(action.toLowerCase())) {
        throw Exception('Invalid action. Must be "accept" or "reject"');
      }

      final body = {
        'action': action.toLowerCase(),
        if (estimatedPickupTime != null) 'estimatedPickupTime': estimatedPickupTime,
        if (estimatedDeliveryTime != null) 'estimatedDeliveryTime': estimatedDeliveryTime,
        if (notes != null) 'notes': notes,
      };

      final response = await BaseService.apiCall(
        method: 'POST',
        endpoint: '$_baseEndpoint/$requestId/respond',
        body: body,
        requiresAuth: true,
      );

      if (response['data'] != null) {
        _processRequestData(response['data']);
      }

      _log('Response submitted successfully');
      return response['data'] ?? {};
    } catch (e) {
      _log('Error responding to request: $e');
      throw Exception('Failed to respond to request: $e');
    }
  }

  /// Accept driver request - Optimized convenience method
  static Future<Map<String, dynamic>> acceptDriverRequest({
    required String requestId,
    String? notes,
  }) async {
    // Pre-calculate estimated times
    final now = DateTime.now();
    final estimatedPickupTime = now.add(const Duration(minutes: 15)).toIso8601String();
    final estimatedDeliveryTime = now.add(const Duration(minutes: 45)).toIso8601String();

    return await respondToDriverRequest(
      requestId: requestId,
      action: 'accept',
      estimatedPickupTime: estimatedPickupTime,
      estimatedDeliveryTime: estimatedDeliveryTime,
      notes: notes ?? 'Driver telah menerima permintaan dan akan segera menghubungi Anda',
    );
  }

  /// Reject driver request - Optimized convenience method
  static Future<Map<String, dynamic>> rejectDriverRequest({
    required String requestId,
    String? reason,
  }) async {
    return await respondToDriverRequest(
      requestId: requestId,
      action: 'reject',
      notes: reason ?? 'Driver tidak dapat memenuhi permintaan saat ini',
    );
  }

  /// Get pending requests count - Optimized
  static Future<int> getPendingRequestsCount() async {
    try {
      final isValid = await _validateDriverAccess();
      if (!isValid) return 0;

      final response = await getDriverRequests(
        status: 'pending',
        limit: 1,
      );

      return response['totalItems'] ?? 0;
    } catch (e) {
      _log('Error getting pending count: $e');
      return 0;
    }
  }

  /// Get driver earnings - Optimized
  static Future<Map<String, dynamic>> getDriverEarnings({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final isValid = await _validateDriverAccess();
      if (!isValid) {
        return _getDefaultEarnings();
      }

      final queryParams = <String, String>{};
      if (startDate != null) queryParams['start_date'] = startDate.toIso8601String();
      if (endDate != null) queryParams['end_date'] = endDate.toIso8601String();

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/earnings',
        queryParams: queryParams.isNotEmpty ? queryParams : null,
        requiresAuth: true,
      );

      return response['data'] ?? _getDefaultEarnings();
    } catch (e) {
      _log('Error getting earnings: $e');
      return _getDefaultEarnings();
    }
  }

  /// Get driver request statistics - Optimized
  static Future<Map<String, dynamic>> getDriverRequestStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final isValid = await _validateDriverAccess();
      if (!isValid) {
        return _getDefaultStats();
      }

      final queryParams = <String, String>{};
      if (startDate != null) queryParams['start_date'] = startDate.toIso8601String();
      if (endDate != null) queryParams['end_date'] = endDate.toIso8601String();

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/stats',
        queryParams: queryParams.isNotEmpty ? queryParams : null,
        requiresAuth: true,
      );

      return response['data'] ?? _getDefaultStats();
    } catch (e) {
      _log('Error getting stats: $e');
      return _getDefaultStats();
    }
  }

  /// Get request urgency level - Optimized
  static String getRequestUrgency(Map<String, dynamic> request) {
    try {
      final order = request['order'];
      if (order == null) return 'normal';

      final createdAt = DateTime.tryParse(order['created_at'] ?? '');
      if (createdAt == null) return 'normal';

      final difference = DateTime.now().difference(createdAt).inMinutes;

      if (difference > 30) return 'urgent';
      if (difference > 15) return 'high';
      return 'normal';
    } catch (e) {
      return 'normal';
    }
  }

  /// Calculate potential earnings - Optimized
  static double calculatePotentialEarnings(Map<String, dynamic> request) {
    try {
      final order = request['order'];
      if (order == null) return 0.0;

      final deliveryFee = double.tryParse(order['delivery_fee']?.toString() ?? '0') ?? 0.0;
      final totalAmount = double.tryParse(order['total_amount']?.toString() ?? '0') ?? 0.0;

      // Driver gets delivery fee + 5% commission
      const commissionRate = 0.05;
      return deliveryFee + (totalAmount * commissionRate);
    } catch (e) {
      return 0.0;
    }
  }

  /// Check driver eligibility - Optimized
  static Future<bool> isDriverEligible() async {
    try {
      final isValid = await _validateDriverAccess();
      if (!isValid) return false;

      final driverData = await AuthService.getRoleSpecificData();
      final driverStatus = driverData?['driver']?['status']?.toString().toLowerCase();

      return driverStatus == 'active';
    } catch (e) {
      _log('Error checking eligibility: $e');
      return false;
    }
  }

  /// Get driver current status - Optimized
  static Future<String> getDriverCurrentStatus() async {
    try {
      final isValid = await _validateDriverAccess();
      if (!isValid) return 'unknown';

      final driverData = await AuthService.getRoleSpecificData();
      return driverData?['driver']?['status']?.toString().toLowerCase() ?? 'unknown';
    } catch (e) {
      _log('Error getting driver status: $e');
      return 'unknown';
    }
  }

  /// Format request status text - Optimized with map lookup
  static String getRequestStatusText(String status) {
    const statusMap = {
      'pending': 'Menunggu Respon',
      'accepted': 'Diterima',
      'rejected': 'Ditolak',
      'expired': 'Kedaluwarsa',
      'completed': 'Selesai',
    };

    return statusMap[status.toLowerCase()] ?? 'Status Tidak Diketahui';
  }

  // PRIVATE HELPER METHODS - OPTIMIZED

  /// Validate driver access - Optimized with batch operations
  static Future<bool> _validateDriverAccess() async {
    try {
      // Batch check authentication, role, and data validity
      final results = await Future.wait([
        AuthService.isAuthenticated(),
        AuthService.getUserRole(),
        AuthService.ensureValidUserData(),
      ]);

      final isAuth = results[0] as bool;
      final userRole = results[1] as String?;
      final isValidData = results[2] as bool;

      if (!isAuth) {
        _log('Driver not authenticated');
        return false;
      }

      if (userRole?.toLowerCase() != 'driver') {
        _log('Invalid role for driver access: $userRole');
        return false;
      }

      if (!isValidData) {
        _log('Invalid driver data');
        return false;
      }

      return true;
    } catch (e) {
      _log('Error validating driver access: $e');
      return false;
    }
  }

  /// Get default statistics - Optimized as const
  static Map<String, dynamic> _getDefaultStats() {
    return const {
      'total_requests': 0,
      'accepted_requests': 0,
      'rejected_requests': 0,
      'pending_requests': 0,
      'acceptance_rate': 0.0,
      'average_response_time': 0,
    };
  }

  /// Get default earnings - Optimized as const
  static Map<String, dynamic> _getDefaultEarnings() {
    return const {
      'total_earnings': 0.0,
      'today_earnings': 0.0,
      'this_week_earnings': 0.0,
      'this_month_earnings': 0.0,
      'completed_orders': 0,
    };
  }

  /// Process request data - Optimized unified processing
  static void _processRequestData(Map<String, dynamic> request) {
    try {
      // Process all data types in sequence for efficiency
      _processRequestImages(request);
      _processOrderData(request);
      _processNumericFields(request);

      // Process order items if present
      final order = request['order'];
      if (order != null && order['items'] != null) {
        final items = order['items'] as List;
        for (var item in items) {
          _processNumericFields(item);
        }
      }
    } catch (e) {
      _log('Error processing request data: $e');
    }
  }

  /// Process nested order data - Optimized
  static void _processOrderData(Map<String, dynamic> request) {
    try {
      final order = request['order'];
      if (order == null) return;

      // Process store image
      final store = order['store'];
      if (store is Map<String, dynamic> && store['image_url'] != null) {
        store['image_url'] = ImageService.getImageUrl(store['image_url']);
      }

      // Process customer avatar
      final customer = order['customer'];
      if (customer is Map<String, dynamic> && customer['avatar'] != null) {
        customer['avatar'] = ImageService.getImageUrl(customer['avatar']);
      }

      // Process order items images
      final items = order['items'];
      if (items is List) {
        for (var item in items) {
          if (item is Map<String, dynamic> && item['image_url'] != null) {
            item['image_url'] = ImageService.getImageUrl(item['image_url']);
          }
        }
      }

      // Process tracking updates
      final trackingUpdates = order['tracking_updates'];
      if (trackingUpdates is String) {
        try {
          final parsed = jsonDecode(trackingUpdates);
          if (parsed is List) {
            order['tracking_updates'] = parsed;
          }
        } catch (e) {
          _log('Failed to parse tracking_updates: $e');
          order['tracking_updates'] = [];
        }
      }
    } catch (e) {
      _log('Error processing order data: $e');
    }
  }

  /// Process images in request data - Optimized
  static void _processRequestImages(Map<String, dynamic> request) {
    try {
      final order = request['order'];
      if (order is Map<String, dynamic>) {
        // Process customer avatar
        final customer = order['customer'];
        if (customer is Map<String, dynamic> && customer['avatar'] != null) {
          customer['avatar'] = ImageService.getImageUrl(customer['avatar']);
        }

        // Process store image
        final store = order['store'];
        if (store is Map<String, dynamic> && store['image_url'] != null) {
          store['image_url'] = ImageService.getImageUrl(store['image_url']);
        }
      }

      // Process driver avatar
      final driver = request['driver'];
      if (driver is Map<String, dynamic>) {
        final driverUser = driver['user'];
        if (driverUser is Map<String, dynamic> && driverUser['avatar'] != null) {
          driverUser['avatar'] = ImageService.getImageUrl(driverUser['avatar']);
        }
      }
    } catch (e) {
      _log('Error processing request images: $e');
    }
  }

  /// Process numeric fields - Optimized with const arrays
  static void _processNumericFields(Map<String, dynamic> data) {
    try {
      // Optimized field lists
      const doubleFields = [
        'total_amount', 'delivery_fee', 'service_fee', 'price', 'rating',
        'latitude', 'longitude', 'distance'
      ];

      const intFields = [
        'id', 'customer_id', 'driver_id', 'store_id', 'menu_item_id',
        'quantity', 'reviews_count', 'review_count'
      ];

      // Batch convert double fields
      for (final field in doubleFields) {
        final value = data[field];
        if (value != null) {
          if (value is String) {
            data[field] = double.tryParse(value) ?? 0.0;
          } else if (value is int) {
            data[field] = value.toDouble();
          }
        }
      }

      // Batch convert int fields
      for (final field in intFields) {
        final value = data[field];
        if (value != null) {
          if (value is String) {
            data[field] = int.tryParse(value) ?? 0;
          } else if (value is double) {
            data[field] = value.toInt();
          }
        }
      }
    } catch (e) {
      _log('Error processing numeric fields: $e');
    }
  }
}