// lib/services/order_service.dart
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'core/api_constants.dart';
import 'core/token_service.dart';
import 'image_service.dart';
import 'dart:math' as Math;


class OrderService {
  /// Find and monitor driver assignment for an order in background
  /// Returns a Stream that emits updates about the driver search process
  static Stream<Map<String, dynamic>> findDriverInBackground(
      String orderId, {
        Duration checkInterval = const Duration(seconds: 5),
        Duration timeout = const Duration(minutes: 15),
      }) async* {
    bool keepChecking = true;
    final stopwatch = Stopwatch()..start();

    try {
      while (keepChecking && stopwatch.elapsed < timeout) {
        // Get current order details
        final orderDetail = await getOrderById(orderId);

        // Extract relevant information
        final String orderStatus = orderDetail['order_status'] ?? 'unknown';
        final bool driverAssigned = orderDetail['driver'] != null;

        // Prepare response data
        final Map<String, dynamic> statusData = {
          'orderId': orderId,
          'orderStatus': orderStatus,
          'driverAssigned': driverAssigned,
          'driverInfo': orderDetail['driver'],
          'store': orderDetail['store'],
          'elapsedTime': stopwatch.elapsed.inSeconds,
          'remainingTime': (timeout - stopwatch.elapsed).inSeconds,
        };

        // Add estimated delivery time if available
        if (orderDetail['estimated_delivery_time'] != null) {
          statusData['estimatedDeliveryTime'] = orderDetail['estimated_delivery_time'];
        }

        // Yield current status
        yield statusData;

        // Stop checking if:
        // 1. Order is cancelled or delivered
        // 2. A driver is assigned
        if (['cancelled', 'delivered', 'rejected'].contains(orderStatus) || driverAssigned) {
          keepChecking = false;
        } else {
          // Wait for the specified interval before checking again
          await Future.delayed(checkInterval);
        }
      }

      // If we reached timeout without assignment or cancellation
      if (stopwatch.elapsed >= timeout && keepChecking) {
        yield {
          'orderId': orderId,
          'orderStatus': 'timeout',
          'driverAssigned': false,
          'message': 'Driver search timed out after ${timeout.inMinutes} minutes',
        };
      }
    } catch (e) {
      // Yield error status
      yield {
        'orderId': orderId,
        'error': e.toString(),
        'isError': true
      };
    }
  }

  /// Get orders for current user (customer)
  static Future<Map<String, dynamic>> getOrdersByUser({
    int page = 1,
    int limit = 10,
    String? sortBy,
    String? sortOrder,
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

      if (sortBy != null) queryParams['sortBy'] = sortBy;
      if (sortOrder != null) queryParams['sortOrder'] = sortOrder;
      if (status != null) queryParams['status'] = status;

      final uri = Uri.parse('${ApiConstants.baseUrl}/orders/customer')
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

        // Process the response according to backend structure
        if (jsonData['data'] != null) {
          final data = jsonData['data'];

          // Process orders list if it exists
          if (data['orders'] != null && data['orders'] is List) {
            for (var order in data['orders']) {
              _processCompleteOrderData(order);
            }
          }

          return data;
        }
        return {'orders': [], 'totalItems': 0, 'totalPages': 0, 'currentPage': 1};
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error fetching customer orders: $e');
      throw Exception('Failed to load customer orders: $e');
    }
    return {'orders': [], 'totalItems': 0, 'totalPages': 0, 'currentPage': 1};
  }

  /// Get orders for current store
  static Future<Map<String, dynamic>> getOrdersByStore({
    int page = 1,
    int limit = 10,
    String? sortBy,
    String? sortOrder,
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

      if (sortBy != null) queryParams['sortBy'] = sortBy;
      if (sortOrder != null) queryParams['sortOrder'] = sortOrder;
      if (status != null) queryParams['status'] = status;

      final uri = Uri.parse('${ApiConstants.baseUrl}/orders/store')
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

        if (jsonData['data'] != null) {
          final data = jsonData['data'];

          // Process orders list if it exists
          if (data['orders'] != null && data['orders'] is List) {
            for (var order in data['orders']) {
              _processCompleteOrderData(order);
            }
          }

          return data;
        }
        return {'orders': [], 'totalItems': 0, 'totalPages': 0, 'currentPage': 1};
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error fetching store orders: $e');
      throw Exception('Failed to load store orders: $e');
    }
    return {'orders': [], 'totalItems': 0, 'totalPages': 0, 'currentPage': 1};
  }

  /// Place a new order
  static Future<Map<String, dynamic>> placeOrder(Map<String, dynamic> orderData) async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      // Validate required fields
      if (!orderData.containsKey('store_id') || !orderData.containsKey('items')) {
        throw Exception('store_id and items are required');
      }

      // Prepare request body according to backend schema
      final requestBody = {
        'store_id': orderData['store_id'],
        'items': _prepareOrderItems(orderData['items']),
      };

      // Add optional fields if present
      if (orderData['notes'] != null) {
        requestBody['notes'] = orderData['notes'];
      }

      print('Placing order with data: ${jsonEncode(requestBody)}');

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/orders'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 201) {
        final Map<String, dynamic> jsonData = _parseResponseBody(response.body);

        // Process complete order data
        if (jsonData['data'] != null) {
          _processCompleteOrderData(jsonData['data']);
        }

        return jsonData['data'] ?? {};
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error placing order: $e');
      throw Exception('Failed to place order: $e');
    }
    return {};
  }

  /// Helper method to transform cart items into the expected API format
  static List<Map<String, dynamic>> _prepareOrderItems(List<dynamic> items) {
    return items.map((item) => {
      'menu_item_id': item['menu_item_id'] ?? item['id'] ?? item['itemId'],
      'quantity': item['quantity'] ?? 1,
      'notes': item['notes'] ?? '',
    }).toList();
  }

  /// Cancel order
  static Future<bool> cancelOrder(String orderId) async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/orders/$orderId/cancel'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error cancelling order: $e');
      throw Exception('Failed to cancel order: $e');
    }
    return false;
  }

  /// Process order by store (approve/reject)
  static Future<Map<String, dynamic>> processOrderByStore(String orderId, String action) async {
    try {
      if (!['approve', 'reject'].contains(action)) {
        throw Exception('Action must be "approve" or "reject"');
      }

      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/orders/$orderId/process'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'action': action}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = _parseResponseBody(response.body);

        // Process images in the response
        if (jsonData['data'] != null) {
          _processCompleteOrderData(jsonData['data']);
        }

        return jsonData['data'] ?? {};
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error processing order: $e');
      throw Exception('Failed to process order: $e');
    }
    return {};
  }

  /// Update order status
  static Future<Map<String, dynamic>> updateOrderStatus(String orderId, Map<String, dynamic> statusData) async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.patch(
        Uri.parse('${ApiConstants.baseUrl}/orders/$orderId/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(statusData),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = _parseResponseBody(response.body);

        // Process images in the response
        if (jsonData['data'] != null) {
          _processCompleteOrderData(jsonData['data']);
        }

        return jsonData['data'] ?? {};
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error updating order status: $e');
      throw Exception('Failed to update order status: $e');
    }
    return {};
  }

  /// Cancel order request (alias for cancelOrder for backward compatibility)
  static Future<bool> cancelOrderRequest(String orderId) async {
    return await cancelOrder(orderId);
  }

  /// Create review for order
  static Future<Map<String, dynamic>> createReview(String orderId, Map<String, dynamic> reviewData) async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      // Validate required fields according to backend schema
      if (!reviewData.containsKey('order_review') && !reviewData.containsKey('driver_review')) {
        throw Exception('Either order_review or driver_review is required');
      }

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/orders/$orderId/review'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(reviewData),
      );

      if (response.statusCode == 201) {
        final Map<String, dynamic> jsonData = _parseResponseBody(response.body);
        return jsonData['data'] ?? {};
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error creating review: $e');
      throw Exception('Failed to create review: $e');
    }
    return {};
  }

  /// Get order by ID
  static Future<Map<String, dynamic>> getOrderById(String orderId) async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/orders/$orderId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = _parseResponseBody(response.body);

        // Process images in the response
        if (jsonData['data'] != null) {
          _processCompleteOrderData(jsonData['data']);
        }

        return jsonData['data'] ?? {};
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error fetching order detail: $e');
      throw Exception('Failed to get order detail: $e');
    }
    return {};
  }

  /// Calculate estimated times (utility function)
  static Map<String, DateTime> calculateEstimatedTimes({
    required double driverLatitude,
    required double driverLongitude,
    required double storeLatitude,
    required double storeLongitude,
    double averageSpeedKmh = 30.0,
    int preparationTimeMinutes = 10,
    int deliveryDistanceKm = 5,
  }) {
    try {
      // Calculate distance from driver to store (simplified)
      final distanceToStore = _calculateDistance(
        driverLatitude, driverLongitude,
        storeLatitude, storeLongitude,
      );

      // Calculate time to store
      final timeToStoreMinutes = (distanceToStore / averageSpeedKmh) * 60;
      final totalPickupTime = (timeToStoreMinutes + preparationTimeMinutes).ceil();

      // Calculate delivery time
      final deliveryTimeMinutes = (deliveryDistanceKm / averageSpeedKmh * 60).ceil();

      final now = DateTime.now();
      final estimatedPickupTime = now.add(Duration(minutes: totalPickupTime));
      final estimatedDeliveryTime = estimatedPickupTime.add(Duration(minutes: deliveryTimeMinutes));

      return {
        'estimated_pickup_time': estimatedPickupTime,
        'estimated_delivery_time': estimatedDeliveryTime,
      };
    } catch (e) {
      print('Error calculating estimated times: $e');
      // Return default times
      final now = DateTime.now();
      return {
        'estimated_pickup_time': now.add(const Duration(minutes: 15)),
        'estimated_delivery_time': now.add(const Duration(minutes: 30)),
      };
    }
  }

  /// Simple distance calculation (Haversine formula simplified)
  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadiusKm = 6371;
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(_toRadians(lat1)) * Math.cos(_toRadians(lat2)) *
            Math.sin(dLon / 2) * Math.sin(dLon / 2);

    final double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _toRadians(double degrees) => degrees * (Math.pi / 180);

  /// Get order statistics
  static Future<Map<String, dynamic>> getOrderStatistics({
    DateTime? startDate,
    DateTime? endDate,
    String? status,
  }) async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final queryParams = <String, String>{};
      if (startDate != null) queryParams['startDate'] = startDate.toIso8601String();
      if (endDate != null) queryParams['endDate'] = endDate.toIso8601String();
      if (status != null) queryParams['status'] = status;

      final uri = Uri.parse('${ApiConstants.baseUrl}/orders/statistics')
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
        return jsonData['data'] ?? {};
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error fetching order statistics: $e');
      throw Exception('Failed to get order statistics: $e');
    }
    return {};
  }

  // PRIVATE HELPER METHODS

  /// Enhanced helper method to process complete order data including all nested objects
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
        if (store['owner'] != null && store['owner']['avatar'] != null) {
          store['owner']['avatar'] = ImageService.getImageUrl(store['owner']['avatar']);
        }
      }

      // Process customer data
      if (order['customer'] != null && order['customer']['avatar'] != null) {
        order['customer']['avatar'] = ImageService.getImageUrl(order['customer']['avatar']);
      }

      // Process driver data
      if (order['driver'] != null) {
        final driver = order['driver'];
        if (driver['avatar'] != null) {
          driver['avatar'] = ImageService.getImageUrl(driver['avatar']);
        }
        // Process nested user data in driver
        if (driver['user'] != null && driver['user']['avatar'] != null) {
          driver['user']['avatar'] = ImageService.getImageUrl(driver['user']['avatar']);
        }
      }

      // Process order items
      if (order['items'] != null && order['items'] is List) {
        for (var item in order['items']) {
          if (item['imageUrl'] != null) {
            item['imageUrl'] = ImageService.getImageUrl(item['imageUrl']);
          }
          if (item['image_url'] != null) {
            item['image_url'] = ImageService.getImageUrl(item['image_url']);
          }
        }
      }

      // Process order reviews if present
      if (order['orderReviews'] != null && order['orderReviews'] is List) {
        for (var review in order['orderReviews']) {
          if (review['user'] != null && review['user']['avatar'] != null) {
            review['user']['avatar'] = ImageService.getImageUrl(review['user']['avatar']);
          }
          if (review['customer'] != null && review['customer']['avatar'] != null) {
            review['customer']['avatar'] = ImageService.getImageUrl(review['customer']['avatar']);
          }
        }
      }

      // Process driver reviews if present
      if (order['driverReviews'] != null && order['driverReviews'] is List) {
        for (var review in order['driverReviews']) {
          if (review['user'] != null && review['user']['avatar'] != null) {
            review['user']['avatar'] = ImageService.getImageUrl(review['user']['avatar']);
          }
          if (review['customer'] != null && review['customer']['avatar'] != null) {
            review['customer']['avatar'] = ImageService.getImageUrl(review['customer']['avatar']);
          }
        }
      }

      // Ensure all date fields are properly formatted
      _validateAndFormatDates(order);

      // Ensure numeric fields are properly typed
      _validateAndFormatNumbers(order);

      // Ensure status fields have default values
      order['order_status'] = order['order_status'] ?? 'pending';
      order['delivery_status'] = order['delivery_status'] ?? 'pending';
    } catch (e) {
      print('Error processing complete order data: $e');
    }
  }

  /// Validate and format date fields
  static void _validateAndFormatDates(Map<String, dynamic> order) {
    final dateFields = [
      'created_at', 'updated_at', 'estimated_pickup_time',
      'actual_pickup_time', 'estimated_delivery_time', 'actual_delivery_time'
    ];

    for (final field in dateFields) {
      if (order[field] != null && order[field] is String) {
        try {
          DateTime.parse(order[field]);
        } catch (e) {
          if (field.contains('estimated') || field.contains('actual')) {
            order.remove(field);
          } else {
            order[field] = DateTime.now().toIso8601String();
          }
        }
      }
    }
  }

  /// Validate and format numeric fields
  static void _validateAndFormatNumbers(Map<String, dynamic> order) {
    final numericFields = ['total_amount', 'delivery_fee'];

    for (final field in numericFields) {
      if (order[field] != null) {
        order[field] = (order[field] as num).toDouble();
      }
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