// lib/services/driver_request_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'core/api_constants.dart';
import 'core/token_service.dart';
import 'image_service.dart';

class DriverRequestService {
  /// Get driver requests for current driver
  static Future<Map<String, dynamic>> getDriverRequests({
    int page = 1,
    int limit = 10,
    String? status,
  }) async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (status != null) queryParams['status'] = status;

      final uri = Uri.parse('${ApiConstants.baseUrl}/driver-requests')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = _parseResponseBody(response.body);

        // Process request data and images
        if (jsonData['data'] != null) {
          final data = jsonData['data'];

          List<dynamic> requests = [];
          if (data['requests'] != null && data['requests'] is List) {
            requests = data['requests'];
          }

          for (var request in requests) {
            // Process order details if present
            if (request['order'] != null) {
              _processOrderImages(request['order']);
            }
          }

          return data;
        }

        return {
          'requests': [],
          'totalItems': 0,
          'totalPages': 0,
          'currentPage': 1,
        };
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error fetching driver requests: $e');
      throw Exception('Failed to get driver requests: $e');
    }
    return {};
  }

  /// Get detailed driver request by ID
  static Future<Map<String, dynamic>> getDriverRequestDetail(String requestId) async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/driver-requests/$requestId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = _parseResponseBody(response.body);

        // Process images in order data if present
        if (jsonData['data'] != null && jsonData['data']['order'] != null) {
          _processCompleteOrderData(jsonData['data']['order']);
        }

        return jsonData['data'] ?? {};
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error fetching driver request detail: $e');
      throw Exception('Failed to get driver request detail: $e');
    }
    return {};
  }

  /// Respond to driver request (accept/reject)
  static Future<Map<String, dynamic>> respondToDriverRequest(
      String requestId,
      String action, {
        DateTime? estimatedPickupTime,
        DateTime? estimatedDeliveryTime,
      }) async {
    try {
      if (!['accept', 'reject'].contains(action)) {
        throw Exception('Action must be "accept" or "reject"');
      }

      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final requestBody = {'action': action};

      if (action == 'accept') {
        if (estimatedPickupTime != null) {
          requestBody['estimatedPickupTime'] = estimatedPickupTime.toIso8601String();
        }
        if (estimatedDeliveryTime != null) {
          requestBody['estimatedDeliveryTime'] = estimatedDeliveryTime.toIso8601String();
        }
      }

      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/driver-requests/$requestId/respond'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = _parseResponseBody(response.body);

        // Process images in the response if order data is present
        if (jsonData['data'] != null && jsonData['data']['order'] != null) {
          _processOrderImages(jsonData['data']['order']);
        }

        return jsonData['data'] ?? {};
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error responding to driver request: $e');
      throw Exception('Failed to respond to driver request: $e');
    }
    return {};
  }

  /// Get driver request history - NEW METHOD
  static Future<Map<String, dynamic>> getDriverRequestHistory({
    int page = 1,
    int limit = 10,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (status != null) queryParams['status'] = status;
      if (startDate != null) queryParams['startDate'] = startDate.toIso8601String();
      if (endDate != null) queryParams['endDate'] = endDate.toIso8601String();

      final uri = Uri.parse('${ApiConstants.baseUrl}/driver-requests/history')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = _parseResponseBody(response.body);

        // Process request data and images
        if (jsonData['data'] != null) {
          final data = jsonData['data'];

          List<dynamic> requests = [];
          if (data['requests'] != null && data['requests'] is List) {
            requests = data['requests'];
          }

          for (var request in requests) {
            if (request['order'] != null) {
              _processOrderImages(request['order']);
            }
          }

          return data;
        }

        return {
          'requests': [],
          'totalItems': 0,
          'totalPages': 0,
          'currentPage': 1,
        };
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error fetching driver request history: $e');
      throw Exception('Failed to get driver request history: $e');
    }
    return {};
  }

  /// Get pending driver requests count - NEW METHOD
  static Future<int> getPendingRequestsCount() async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/driver-requests/pending/count'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = _parseResponseBody(response.body);
        return jsonData['data']['count'] ?? 0;
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error fetching pending requests count: $e');
      throw Exception('Failed to get pending requests count: $e');
    }
    return 0;
  }

  /// Cancel driver request (if still pending) - NEW METHOD
  static Future<Map<String, dynamic>> cancelDriverRequest(String requestId) async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/driver-requests/$requestId/cancel'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = _parseResponseBody(response.body);
        return jsonData['data'] ?? {};
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error cancelling driver request: $e');
      throw Exception('Failed to cancel driver request: $e');
    }
    return {};
  }

  // PRIVATE HELPER METHODS

  /// Process order images in request data
  static void _processOrderImages(Map<String, dynamic> order) {
    try {
      // Process store image if present
      if (order['store'] != null) {
        if (order['store']['imageUrl'] != null) {
          order['store']['imageUrl'] = ImageService.getImageUrl(order['store']['imageUrl']);
        }
        if (order['store']['image'] != null) {
          order['store']['image'] = ImageService.getImageUrl(order['store']['image']);
        }
      }

      // Process customer avatar if present
      if (order['customer'] != null && order['customer']['avatar'] != null) {
        order['customer']['avatar'] = ImageService.getImageUrl(order['customer']['avatar']);
      }

      // Process order items if present
      if (order['items'] != null && order['items'] is List) {
        for (var item in order['items']) {
          if (item['imageUrl'] != null) {
            item['imageUrl'] = ImageService.getImageUrl(item['imageUrl']);
          }
        }
      }
    } catch (e) {
      print('Error processing order images: $e');
    }
  }

  /// Process complete order data including all nested objects
  static void _processCompleteOrderData(Map<String, dynamic> order) {
    try {
      // Process store data and its nested user
      if (order['store'] != null) {
        final store = order['store'];

        // Process store image
        if (store['imageUrl'] != null) {
          store['imageUrl'] = ImageService.getImageUrl(store['imageUrl']);
        }
        if (store['image'] != null) {
          store['image'] = ImageService.getImageUrl(store['image']);
        }

        // Process store owner/user data
        if (store['user'] != null && store['user']['avatar'] != null) {
          store['user']['avatar'] = ImageService.getImageUrl(store['user']['avatar']);
        }
      }

      // Process customer data
      if (order['customer'] != null && order['customer']['avatar'] != null) {
        order['customer']['avatar'] = ImageService.getImageUrl(order['customer']['avatar']);
      }

      // Process driver data
      if (order['driver'] != null && order['driver']['avatar'] != null) {
        order['driver']['avatar'] = ImageService.getImageUrl(order['driver']['avatar']);
      }

      // Process order items
      if (order['items'] != null && order['items'] is List) {
        for (var item in order['items']) {
          if (item['imageUrl'] != null) {
            item['imageUrl'] = ImageService.getImageUrl(item['imageUrl']);
          }
        }
      }

      // Process order reviews if present
      if (order['orderReviews'] != null && order['orderReviews'] is List) {
        for (var review in order['orderReviews']) {
          if (review['user'] != null && review['user']['avatar'] != null) {
            review['user']['avatar'] = ImageService.getImageUrl(review['user']['avatar']);
          }
        }
      }

      // Process driver reviews if present
      if (order['driverReviews'] != null && order['driverReviews'] is List) {
        for (var review in order['driverReviews']) {
          if (review['user'] != null && review['user']['avatar'] != null) {
            review['user']['avatar'] = ImageService.getImageUrl(review['user']['avatar']);
          }
        }
      }
    } catch (e) {
      print('Error processing complete order data: $e');
    }
  }

  /// Parse response body with better error handling
  static Map<String, dynamic> _parseResponseBody(String body) {
    try {
      return json.decode(body);
    } catch (e) {
      print('Error parsing response body: $e');
      String cleanedBody = body.trim();
      if (cleanedBody.startsWith('\uFEFF')) {
        cleanedBody = cleanedBody.substring(1);
      }
      try {
        return json.decode(cleanedBody);
      } catch (e) {
        throw Exception('Invalid response format: $body');
      }
    }
  }

  /// Handle error responses consistently
  static void _handleErrorResponse(http.Response response) {
    try {
      final errorData = _parseResponseBody(response.body);
      final message = errorData['message'] ?? 'Request failed';
      throw Exception(message);
    } catch (e) {
      if (e is Exception && e.toString().contains('Request failed')) {
        rethrow;
      }
      throw Exception('Request failed with status ${response.statusCode}: ${response.body}');
    }
  }
}