// lib/Services/driver_request_service.dart
import 'dart:convert';
import 'core/base_service.dart';
import 'image_service.dart';
import 'auth_service.dart';

class DriverRequestService {
  static const String _baseEndpoint = '/driver-requests';

  /// Get driver requests for current driver - FIXED struktur response
  static Future<Map<String, dynamic>> getDriverRequests({
    int page = 1,
    int limit = 20,
    String? status, // pending, accepted, rejected, expired
    String? sortBy,
    String? sortOrder,
  }) async {
    try {
      print('🔄 DriverRequestService: Getting driver requests...');

      // ✅ PERBAIKAN: Validate driver authentication and role
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

      // ✅ PERBAIKAN: Process response sesuai struktur backend
      Map<String, dynamic> result = {
        'requests': [],
        'totalItems': 0,
        'totalPages': 0,
        'currentPage': 1,
      };

      if (response['data'] != null) {
        // Backend mengembalikan struktur dengan 'requests' array
        if (response['data']['requests'] != null) {
          final requests = response['data']['requests'] as List;
          for (var request in requests) {
            _processRequestImages(request);
            _processOrderData(request); // Process nested order data
          }
          result['requests'] = requests;
          result['totalItems'] = response['data']['totalItems'] ?? 0;
          result['totalPages'] = response['data']['totalPages'] ?? 0;
          result['currentPage'] = response['data']['currentPage'] ?? 1;
        }
      }

      print(
          '✅ DriverRequestService: Retrieved ${result['requests']?.length ?? 0} requests');
      return result;
    } catch (e) {
      print('❌ DriverRequestService: Error getting driver requests: $e');
      throw Exception('Failed to get driver requests: $e');
    }
  }

  /// Get detailed information about a specific driver request - FIXED
  static Future<Map<String, dynamic>> getDriverRequestDetail(
      String requestId) async {
    try {
      print(
          '🔍 DriverRequestService: Getting request detail for ID: $requestId');

      // Validate driver authentication
      final isValid = await _validateDriverAccess();
      if (!isValid) {
        throw Exception('Invalid driver access');
      }

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/$requestId', // GET /driver-requests/{id}
        requiresAuth: true,
      );

      if (response['data'] != null) {
        final requestDetail = response['data'];

        // ✅ ENHANCED: Process all nested data
        _processRequestImages(requestDetail);
        _processOrderData(requestDetail);

        // ✅ TAMBAHAN: Process numeric fields
        _processNumericFields(requestDetail);

        // ✅ TAMBAHAN: Process order items if present
        if (requestDetail['order'] != null &&
            requestDetail['order']['items'] != null) {
          final items = requestDetail['order']['items'] as List;
          for (var item in items) {
            _processNumericFields(item);
          }
        }

        print(
            '✅ DriverRequestService: Request detail retrieved and processed successfully');
        return requestDetail;
      }

      throw Exception('Driver request not found');
    } catch (e) {
      print('❌ DriverRequestService: Error getting request detail: $e');
      throw Exception('Failed to get request detail: $e');
    }
  }

  // static Future<Map<String, dynamic>> getDriverRequestDetail(String requestId) async {
  //   try {
  //     print('🔄 DriverRequestService: Getting request detail for ID: $requestId');
  //
  //     // Validate driver authentication
  //     final isValid = await _validateDriverAccess();
  //     if (!isValid) {
  //       throw Exception('Invalid driver access');
  //     }
  //
  //     final response = await BaseService.apiCall(
  //       method: 'GET',
  //       endpoint: '$_baseEndpoint/$requestId',
  //       requiresAuth: true,
  //     );
  //
  //     if (response['data'] != null) {
  //       _processRequestImages(response['data']);
  //       _processOrderData(response['data']);
  //       print('✅ DriverRequestService: Request detail retrieved successfully');
  //       return response['data'];
  //     }
  //
  //     throw Exception('Driver request not found');
  //   } catch (e) {
  //     print('❌ DriverRequestService: Error getting request detail: $e');
  //     throw Exception('Failed to get request detail: $e');
  //   }
  // }

  /// Respond to driver request (accept or reject) - FIXED sesuai backend
  static Future<Map<String, dynamic>> respondToDriverRequest({
    required String requestId,
    required String action, // 'accept' atau 'reject'
    String? estimatedPickupTime,
    String? estimatedDeliveryTime,
    String? notes,
  }) async {
    try {
      print(
          '🔄 DriverRequestService: Responding to request $requestId with action: $action');

      // Validate driver authentication and role
      final isValid = await _validateDriverAccess();
      if (!isValid) {
        throw Exception('Invalid driver access');
      }

      if (!['accept', 'reject'].contains(action.toLowerCase())) {
        throw Exception('Invalid action. Must be "accept" or "reject"');
      }

      // ✅ PERBAIKAN: Body sesuai struktur backend
      final body = {
        'action': action.toLowerCase(),
        if (estimatedPickupTime != null)
          'estimatedPickupTime': estimatedPickupTime,
        if (estimatedDeliveryTime != null)
          'estimatedDeliveryTime': estimatedDeliveryTime,
        if (notes != null) 'notes': notes,
      };

      final response = await BaseService.apiCall(
        method: 'POST',
        endpoint: '$_baseEndpoint/$requestId/respond',
        body: body,
        requiresAuth: true,
      );

      if (response['data'] != null) {
        _processRequestImages(response['data']);
        _processOrderData(response['data']);
      }

      print('✅ DriverRequestService: Response submitted successfully');
      return response['data'] ?? {};
    } catch (e) {
      print('❌ DriverRequestService: Error responding to request: $e');
      throw Exception('Failed to respond to request: $e');
    }
  }

  /// Accept driver request (convenience method) dengan auto-generated times
  static Future<Map<String, dynamic>> acceptDriverRequest({
    required String requestId,
    String? notes,
  }) async {
    // Auto-generate estimated times
    final now = DateTime.now();
    final estimatedPickupTime =
        now.add(const Duration(minutes: 15)).toIso8601String();
    final estimatedDeliveryTime =
        now.add(const Duration(minutes: 45)).toIso8601String();

    return await respondToDriverRequest(
      requestId: requestId,
      action: 'accept',
      estimatedPickupTime: estimatedPickupTime,
      estimatedDeliveryTime: estimatedDeliveryTime,
      notes: notes ??
          'Driver telah menerima permintaan dan akan segera menghubungi Anda',
    );
  }

  /// Reject driver request (convenience method)
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

  /// Get pending requests count for current driver
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
      print('❌ DriverRequestService: Error getting pending count: $e');
      return 0;
    }
  }

  /// ✅ BARU: Get driver earnings from completed requests
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
      if (startDate != null)
        queryParams['start_date'] = startDate.toIso8601String();
      if (endDate != null) queryParams['end_date'] = endDate.toIso8601String();

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/earnings',
        queryParams: queryParams.isNotEmpty ? queryParams : null,
        requiresAuth: true,
      );

      return response['data'] ?? _getDefaultEarnings();
    } catch (e) {
      print('❌ DriverRequestService: Error getting earnings: $e');
      return _getDefaultEarnings();
    }
  }

  /// ✅ BARU: Get driver request statistics
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
      if (startDate != null)
        queryParams['start_date'] = startDate.toIso8601String();
      if (endDate != null) queryParams['end_date'] = endDate.toIso8601String();

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/stats',
        queryParams: queryParams.isNotEmpty ? queryParams : null,
        requiresAuth: true,
      );

      return response['data'] ?? _getDefaultStats();
    } catch (e) {
      print('❌ DriverRequestService: Error getting stats: $e');
      return _getDefaultStats();
    }
  }

  /// Get request urgency level based on order details
  static String getRequestUrgency(Map<String, dynamic> request) {
    try {
      final order = request['order'];
      if (order == null) return 'normal';

      final createdAt = DateTime.tryParse(order['created_at'] ?? '');
      if (createdAt == null) return 'normal';

      final now = DateTime.now();
      final difference = now.difference(createdAt).inMinutes;

      if (difference > 30) return 'urgent';
      if (difference > 15) return 'high';
      return 'normal';
    } catch (e) {
      return 'normal';
    }
  }

  /// ✅ BARU: Calculate potential earnings for a request
  static double calculatePotentialEarnings(Map<String, dynamic> request) {
    try {
      final order = request['order'];
      if (order == null) return 0.0;

      final deliveryFee =
          double.tryParse(order['delivery_fee']?.toString() ?? '0') ?? 0.0;
      final totalAmount =
          double.tryParse(order['total_amount']?.toString() ?? '0') ?? 0.0;

      // Driver gets delivery fee + small percentage of order total
      final baseEarning = deliveryFee;
      final commissionRate = 0.05; // 5% dari total order
      final commission = totalAmount * commissionRate;

      return baseEarning + commission;
    } catch (e) {
      return 0.0;
    }
  }

  /// Check if driver is eligible to receive requests
  static Future<bool> isDriverEligible() async {
    try {
      final isValid = await _validateDriverAccess();
      if (!isValid) return false;

      final driverData = await AuthService.getRoleSpecificData();
      final driverStatus =
          driverData?['driver']?['status']?.toString().toLowerCase();

      return driverStatus == 'active';
    } catch (e) {
      print('❌ DriverRequestService: Error checking eligibility: $e');
      return false;
    }
  }

  /// ✅ BARU: Get driver current status
  static Future<String> getDriverCurrentStatus() async {
    try {
      final isValid = await _validateDriverAccess();
      if (!isValid) return 'unknown';

      final driverData = await AuthService.getRoleSpecificData();
      return driverData?['driver']?['status']?.toString().toLowerCase() ??
          'unknown';
    } catch (e) {
      print('❌ DriverRequestService: Error getting driver status: $e');
      return 'unknown';
    }
  }

  /// ✅ BARU: Format request status text untuk UI
  static String getRequestStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Menunggu Respon';
      case 'accepted':
        return 'Diterima';
      case 'rejected':
        return 'Ditolak';
      case 'expired':
        return 'Kedaluwarsa';
      case 'completed':
        return 'Selesai';
      default:
        return 'Status Tidak Diketahui';
    }
  }

  // PRIVATE HELPER METHODS

  /// Validate driver access for receiving/responding to requests
  static Future<bool> _validateDriverAccess() async {
    try {
      // Check authentication
      final isAuth = await AuthService.isAuthenticated();
      if (!isAuth) {
        print('❌ DriverRequestService: Driver not authenticated');
        return false;
      }

      // Check role
      final userRole = await AuthService.getUserRole();
      if (userRole?.toLowerCase() != 'driver') {
        print(
            '❌ DriverRequestService: Invalid role for driver access: $userRole');
        return false;
      }

      // Ensure valid user data
      final isValidData = await AuthService.ensureValidUserData();
      if (!isValidData) {
        print('❌ DriverRequestService: Invalid driver data');
        return false;
      }

      return true;
    } catch (e) {
      print('❌ DriverRequestService: Error validating driver access: $e');
      return false;
    }
  }

  /// Get default statistics
  static Map<String, dynamic> _getDefaultStats() {
    return {
      'total_requests': 0,
      'accepted_requests': 0,
      'rejected_requests': 0,
      'pending_requests': 0,
      'acceptance_rate': 0.0,
      'average_response_time': 0,
    };
  }

  /// Get default earnings
  static Map<String, dynamic> _getDefaultEarnings() {
    return {
      'total_earnings': 0.0,
      'today_earnings': 0.0,
      'this_week_earnings': 0.0,
      'this_month_earnings': 0.0,
      'completed_orders': 0,
    };
  }

  /// ✅ BARU: Process nested order data dalam driver request
  static void _processOrderData(Map<String, dynamic> request) {
    try {
      if (request['order'] != null) {
        final order = request['order'];

        // Process order images
        if (order['store'] != null && order['store']['image_url'] != null) {
          order['store']['image_url'] =
              ImageService.getImageUrl(order['store']['image_url']);
        }

        // Process customer avatar
        if (order['customer'] != null && order['customer']['avatar'] != null) {
          order['customer']['avatar'] =
              ImageService.getImageUrl(order['customer']['avatar']);
        }

        // Process order items
        if (order['items'] != null) {
          final items = order['items'] as List;
          for (var item in items) {
            if (item['image_url'] != null) {
              item['image_url'] = ImageService.getImageUrl(item['image_url']);
            }
          }
        }

        // Process tracking updates if exist
        if (order['tracking_updates'] != null &&
            order['tracking_updates'] is String) {
          try {
            final parsed = jsonDecode(order['tracking_updates']);
            if (parsed is List) {
              order['tracking_updates'] = parsed;
            }
          } catch (e) {
            print('⚠️ Failed to parse tracking_updates in driver request: $e');
            order['tracking_updates'] = [];
          }
        }
      }
    } catch (e) {
      print('❌ DriverRequestService: Error processing order data: $e');
    }
  }

  /// Process images in request data
  static void _processRequestImages(Map<String, dynamic> request) {
    try {
      // Process customer avatar through order
      if (request['order'] != null &&
          request['order']['customer'] != null &&
          request['order']['customer']['avatar'] != null) {
        request['order']['customer']['avatar'] =
            ImageService.getImageUrl(request['order']['customer']['avatar']);
      }

      // Process store image through order
      if (request['order'] != null &&
          request['order']['store'] != null &&
          request['order']['store']['image_url'] != null) {
        request['order']['store']['image_url'] =
            ImageService.getImageUrl(request['order']['store']['image_url']);
      }

      // Process driver avatar if present
      if (request['driver'] != null &&
          request['driver']['user'] != null &&
          request['driver']['user']['avatar'] != null) {
        request['driver']['user']['avatar'] =
            ImageService.getImageUrl(request['driver']['user']['avatar']);
      }
    } catch (e) {
      print('❌ DriverRequestService: Error processing request images: $e');
    }
  }

  ///Process Numeric Field
  static void _processNumericFields(Map<String, dynamic> data) {
    try {
      // List of fields that should be converted from String to double
      final doubleFields = [
        'total_amount',
        'delivery_fee',
        'service_fee',
        'price',
        'rating',
        'latitude',
        'longitude',
        'distance'
      ];

      // List of fields that should be converted from String to int
      final intFields = [
        'id',
        'customer_id',
        'driver_id',
        'store_id',
        'menu_item_id',
        'quantity',
        'reviews_count',
        'review_count'
      ];

      // Convert double fields
      for (final field in doubleFields) {
        if (data[field] != null) {
          if (data[field] is String) {
            data[field] = double.tryParse(data[field]) ?? 0.0;
          } else if (data[field] is int) {
            data[field] = data[field].toDouble();
          }
        }
      }

      // Convert int fields
      for (final field in intFields) {
        if (data[field] != null) {
          if (data[field] is String) {
            data[field] = int.tryParse(data[field]) ?? 0;
          } else if (data[field] is double) {
            data[field] = data[field].toInt();
          }
        }
      }
    } catch (e) {
      print('❌ DriverRequestService: Error processing numeric fields: $e');
    }
  }
}
