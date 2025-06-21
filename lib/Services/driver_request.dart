// lib/services/driver_request_service.dart
import 'package:flutter/foundation.dart';
import 'core/base_service.dart';
import 'image_service.dart';

class DriverRequestService extends BaseService {

  // Get all driver requests (for drivers)
  static Future<Map<String, dynamic>> getDriverRequests({
    int page = 1,
    int limit = 10,
    String? status,
    String? sortBy,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (status != null) queryParams['status'] = status;
      if (sortBy != null) queryParams['sortBy'] = sortBy;

      final response = await BaseService.get('/driver-requests', queryParams: queryParams);

      if (response['data'] != null) {
        _processDriverRequestsList(response['data']);
      }

      return response;
    } catch (e) {
      debugPrint('Get driver requests error: $e');
      rethrow;
    }
  }

  // Get driver request detail by ID
  static Future<Map<String, dynamic>> getDriverRequestDetail(String requestId) async {
    try {
      final response = await BaseService.get('/driver-requests/$requestId');

      if (response['data'] != null) {
        _processDriverRequestData(response['data']);
      }

      return response['data'] ?? {};
    } catch (e) {
      debugPrint('Get driver request detail error: $e');
      rethrow;
    }
  }

  // Respond to driver request (accept/reject)
  static Future<Map<String, dynamic>> respondToDriverRequest(
      String requestId,
      String action, {
        DateTime? estimatedPickupTime,
        DateTime? estimatedDeliveryTime,
        String? notes,
      }) async {
    try {
      if (!['accept', 'reject'].contains(action)) {
        throw ApiException('Action must be either "accept" or "reject"');
      }

      final requestBody = <String, dynamic>{
        'action': action,
      };

      // Add optional fields for acceptance
      if (action == 'accept') {
        if (estimatedPickupTime != null) {
          requestBody['estimatedPickupTime'] = estimatedPickupTime.toIso8601String();
        }
        if (estimatedDeliveryTime != null) {
          requestBody['estimatedDeliveryTime'] = estimatedDeliveryTime.toIso8601String();
        }
      }

      if (notes != null) {
        requestBody['notes'] = notes;
      }

      final response = await BaseService.post('/driver-requests/$requestId/respond', requestBody);

      if (response['data'] != null) {
        _processDriverRequestData(response['data']);
      }

      return response['data'] ?? {};
    } catch (e) {
      debugPrint('Respond to driver request error: $e');
      rethrow;
    }
  }

  // Accept driver request (convenience method)
  static Future<Map<String, dynamic>> acceptDriverRequest(
      String requestId, {
        DateTime? estimatedPickupTime,
        DateTime? estimatedDeliveryTime,
        String? notes,
      }) async {
    return await respondToDriverRequest(
      requestId,
      'accept',
      estimatedPickupTime: estimatedPickupTime,
      estimatedDeliveryTime: estimatedDeliveryTime,
      notes: notes,
    );
  }

  // Reject driver request (convenience method)
  static Future<Map<String, dynamic>> rejectDriverRequest(
      String requestId, {
        String? reason,
      }) async {
    return await respondToDriverRequest(
      requestId,
      'reject',
      notes: reason,
    );
  }

  // Get available driver requests for current driver
  static Future<List<Map<String, dynamic>>> getAvailableRequests({
    double? maxDistance,
    String? priority,
    int limit = 10,
  }) async {
    try {
      final queryParams = {
        'status': 'available',
        'limit': limit.toString(),
      };

      if (maxDistance != null) queryParams['maxDistance'] = maxDistance.toString();
      if (priority != null) queryParams['priority'] = priority;

      final response = await BaseService.get('/driver-requests', queryParams: queryParams);

      if (response['data'] != null && response['data'] is List) {
        for (var request in response['data']) {
          _processDriverRequestData(request);
        }
        return List<Map<String, dynamic>>.from(response['data']);
      }

      return [];
    } catch (e) {
      debugPrint('Get available requests error: $e');
      rethrow;
    }
  }

  // Get driver request history
  static Future<Map<String, dynamic>> getDriverRequestHistory({
    int page = 1,
    int limit = 10,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        'history': 'true',
      };

      if (startDate != null) queryParams['startDate'] = startDate.toIso8601String();
      if (endDate != null) queryParams['endDate'] = endDate.toIso8601String();
      if (status != null) queryParams['status'] = status;

      final response = await BaseService.get('/driver-requests', queryParams: queryParams);

      if (response['data'] != null) {
        _processDriverRequestsList(response['data']);
      }

      return response;
    } catch (e) {
      debugPrint('Get driver request history error: $e');
      rethrow;
    }
  }

  // Get driver earnings from requests
  static Future<Map<String, dynamic>> getDriverEarnings({
    DateTime? startDate,
    DateTime? endDate,
    String? period, // 'today', 'week', 'month'
  }) async {
    try {
      final queryParams = <String, String>{};

      if (startDate != null) queryParams['startDate'] = startDate.toIso8601String();
      if (endDate != null) queryParams['endDate'] = endDate.toIso8601String();
      if (period != null) queryParams['period'] = period;

      final response = await BaseService.get('/driver-requests/earnings', queryParams: queryParams);
      return response['data'] ?? {};
    } catch (e) {
      debugPrint('Get driver earnings error: $e');
      rethrow;
    }
  }

  // Update driver availability for requests
  static Future<Map<String, dynamic>> updateDriverAvailability(bool isAvailable) async {
    try {
      final response = await BaseService.put('/drivers/availability', {
        'is_available': isAvailable,
      });

      return response['data'] ?? {};
    } catch (e) {
      debugPrint('Update driver availability error: $e');
      rethrow;
    }
  }

  // PRIVATE HELPER METHODS

  static void _processDriverRequestsList(dynamic data) {
    try {
      List<dynamic> requests = [];

      if (data is List) {
        requests = data;
      } else if (data is Map && data['requests'] is List) {
        requests = data['requests'];
      }

      for (var request in requests) {
        _processDriverRequestData(request);
      }
    } catch (e) {
      debugPrint('Process driver requests list error: $e');
    }
  }

  static void _processDriverRequestData(Map<String, dynamic> requestData) {
    try {
      // Process order data if present
      if (requestData['order'] != null) {
        _processOrderImages(requestData['order']);
      }

      // Process store data if present
      if (requestData['store'] != null && requestData['store']['imageUrl'] != null) {
        requestData['store']['imageUrl'] = ImageService.getImageUrl(requestData['store']['imageUrl']);
      }

      // Process customer data if present
      if (requestData['customer'] != null && requestData['customer']['avatar'] != null) {
        requestData['customer']['avatar'] = ImageService.getImageUrl(requestData['customer']['avatar']);
      }
    } catch (e) {
      debugPrint('Process driver request data error: $e');
    }
  }

  static void _processOrderImages(Map<String, dynamic> orderData) {
    try {
      // Process store images
      if (orderData['store'] != null && orderData['store']['imageUrl'] != null) {
        orderData['store']['imageUrl'] = ImageService.getImageUrl(orderData['store']['imageUrl']);
      }

      // Process menu item images
      if (orderData['items'] != null && orderData['items'] is List) {
        for (var item in orderData['items']) {
          if (item['menuItem'] != null && item['menuItem']['imageUrl'] != null) {
            item['menuItem']['imageUrl'] = ImageService.getImageUrl(item['menuItem']['imageUrl']);
          }
        }
      }
    } catch (e) {
      debugPrint('Process order images error: $e');
    }
  }
}