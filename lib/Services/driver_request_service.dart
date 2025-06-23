// lib/Services/driver_request_service.dart
import 'dart:convert';
import 'core/base_service.dart';
import 'image_service.dart';

class DriverRequestService {
  static const String _baseEndpoint = '/driver-requests';

  /// Get driver requests for current driver
  /// Returns list of pending delivery requests
  static Future<Map<String, dynamic>> getDriverRequests({
    int page = 1,
    int limit = 10,
    String? status, // pending, accepted, rejected
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
        endpoint: _baseEndpoint,
        queryParams: queryParams,
        requiresAuth: true,
      );

      // Process images in request data
      if (response['data'] != null && response['data']['requests'] != null) {
        final requests = response['data']['requests'] as List;
        for (var request in requests) {
          _processRequestImages(request);
        }
      }

      return response['data'] ?? {
        'requests': [],
        'totalItems': 0,
        'totalPages': 0,
        'currentPage': 1,
      };
    } catch (e) {
      print('Get driver requests error: $e');
      throw Exception('Failed to get driver requests: $e');
    }
  }

  /// Get detailed information about a specific driver request
  static Future<Map<String, dynamic>> getDriverRequestDetail(String requestId) async {
    try {
      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/$requestId',
        requiresAuth: true,
      );

      if (response['data'] != null) {
        _processRequestImages(response['data']);
      }

      return response['data'] ?? {};
    } catch (e) {
      print('Get driver request detail error: $e');
      throw Exception('Failed to get request detail: $e');
    }
  }

  /// Respond to driver request (accept or reject)
  static Future<Map<String, dynamic>> respondToDriverRequest({
    required String requestId,
    required String action, // accept, reject
    String? estimatedPickupTime,
    String? estimatedDeliveryTime,
    String? notes,
  }) async {
    try {
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

      return response['data'] ?? {};
    } catch (e) {
      print('Respond to driver request error: $e');
      throw Exception('Failed to respond to request: $e');
    }
  }

  /// Accept driver request (convenience method)
  static Future<Map<String, dynamic>> acceptDriverRequest({
    required String requestId,
    String? estimatedPickupTime,
    String? estimatedDeliveryTime,
    String? notes,
  }) async {
    return await respondToDriverRequest(
      requestId: requestId,
      action: 'accept',
      estimatedPickupTime: estimatedPickupTime,
      estimatedDeliveryTime: estimatedDeliveryTime,
      notes: notes,
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
      notes: reason,
    );
  }

  /// Get pending requests count for current driver
  static Future<int> getPendingRequestsCount() async {
    try {
      final response = await getDriverRequests(
        status: 'pending',
        limit: 1,
      );

      return response['totalItems'] ?? 0;
    } catch (e) {
      print('Get pending requests count error: $e');
      return 0;
    }
  }

  /// Get driver request history
  static Future<Map<String, dynamic>> getDriverRequestHistory({
    int page = 1,
    int limit = 10,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (status != null) 'status': status,
        if (startDate != null) 'startDate': startDate.toIso8601String(),
        if (endDate != null) 'endDate': endDate.toIso8601String(),
        'sortBy': 'created_at',
        'sortOrder': 'desc',
      };

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: _baseEndpoint,
        queryParams: queryParams,
        requiresAuth: true,
      );

      // Process images in request data
      if (response['data'] != null && response['data']['requests'] != null) {
        final requests = response['data']['requests'] as List;
        for (var request in requests) {
          _processRequestImages(request);
        }
      }

      return response['data'] ?? {
        'requests': [],
        'totalItems': 0,
        'totalPages': 0,
        'currentPage': 1,
      };
    } catch (e) {
      print('Get driver request history error: $e');
      throw Exception('Failed to get request history: $e');
    }
  }

  /// Get request statistics for current driver
  static Future<Map<String, dynamic>> getDriverRequestStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (startDate != null) queryParams['startDate'] = startDate.toIso8601String();
      if (endDate != null) queryParams['endDate'] = endDate.toIso8601String();

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/stats',
        queryParams: queryParams.isNotEmpty ? queryParams : null,
        requiresAuth: true,
      );

      return response['data'] ?? {
        'totalRequests': 0,
        'acceptedRequests': 0,
        'rejectedRequests': 0,
        'pendingRequests': 0,
        'acceptanceRate': 0.0,
        'averageResponseTime': 0,
      };
    } catch (e) {
      print('Get driver request stats error: $e');
      // Return default stats on error
      return {
        'totalRequests': 0,
        'acceptedRequests': 0,
        'rejectedRequests': 0,
        'pendingRequests': 0,
        'acceptanceRate': 0.0,
        'averageResponseTime': 0,
      };
    }
  }

  /// Mark request as viewed (optional feature)
  static Future<bool> markRequestAsViewed(String requestId) async {
    try {
      await BaseService.apiCall(
        method: 'PATCH',
        endpoint: '$_baseEndpoint/$requestId/viewed',
        requiresAuth: true,
      );
      return true;
    } catch (e) {
      print('Mark request as viewed error: $e');
      return false;
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

  /// Calculate estimated earnings for a request
  static double calculateEstimatedEarnings(Map<String, dynamic> request) {
    try {
      final order = request['order'];
      if (order == null) return 0.0;

      final totalAmount = (order['total_amount'] ?? 0.0) as num;
      final serviceCharge = (order['service_charge'] ?? 0.0) as num;

      // Assume driver gets a percentage of service charge + base delivery fee
      final baseDeliveryFee = 5000.0; // Base fee in IDR
      final commissionRate = 0.8; // 80% of service charge

      return baseDeliveryFee + (serviceCharge * commissionRate);
    } catch (e) {
      return 0.0;
    }
  }

  // PRIVATE HELPER METHODS

  /// Process images in request data
  static void _processRequestImages(Map<String, dynamic> request) {
    try {
      // Process customer avatar
      if (request['order'] != null &&
          request['order']['customer'] != null &&
          request['order']['customer']['avatar'] != null) {
        request['order']['customer']['avatar'] =
            ImageService.getImageUrl(request['order']['customer']['avatar']);
      }

      // Process store image
      if (request['order'] != null &&
          request['order']['store'] != null &&
          request['order']['store']['image_url'] != null) {
        request['order']['store']['image_url'] =
            ImageService.getImageUrl(request['order']['store']['image_url']);
      }

      // Process menu item images
      if (request['order'] != null &&
          request['order']['order_items'] != null) {
        final orderItems = request['order']['order_items'] as List;
        for (var item in orderItems) {
          if (item['menu_item'] != null &&
              item['menu_item']['image_url'] != null) {
            item['menu_item']['image_url'] =
                ImageService.getImageUrl(item['menu_item']['image_url']);
          }
        }
      }
    } catch (e) {
      print('Error processing request images: $e');
    }
  }
}