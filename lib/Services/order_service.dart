// lib/services/order_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'core/api_constants.dart';
import 'core/token_service.dart';
import 'image_service.dart';
import 'dart:async';

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
        final orderDetail = await getOrderDetail(orderId);

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
        if (orderDetail['estimatedDeliveryTime'] != null) {
          statusData['estimatedDeliveryTime'] = orderDetail['estimatedDeliveryTime'];
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
  /// Get orders for customer (user)
  static Future<Map<String, dynamic>> getOrdersByUser({
    int page = 1,
    int limit = 10,
    String? sortBy,
    String? sortOrder,
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

      if (sortBy != null) {
        queryParams['sortBy'] = sortBy;
      }

      if (sortOrder != null) {
        queryParams['sortOrder'] = sortOrder;
      }

      final uri = Uri.parse('${ApiConstants.baseUrl}/orders/user')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);

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

  /// Place a new order - simplified implementation
  static Future<Map<String, dynamic>> placeOrder(Map<String, dynamic> orderData) async {
    // Get token
    final token = await TokenService.getToken();

    // Prepare request body with basic required fields
    final requestBody = {
      'storeId': orderData['storeId'],
      'items': _prepareOrderItems(orderData['items']),
      'deliveryAddress': orderData['deliveryAddress'],
      'latitude': orderData['latitude'],
      'longitude': orderData['longitude'],
      'serviceCharge': orderData['serviceCharge'],
      'notes': orderData['notes'] ?? '',
    };

    // Log the request for debugging
    print('Sending order request: ${jsonEncode(requestBody)}');

    // Make API call
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/orders'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(requestBody),
    );

    // Parse and return response
    final jsonData = json.decode(response.body);
    return jsonData['data'] ?? {};
  }

  /// Helper method to transform cart items into the expected API format
  static List<Map<String, dynamic>> _prepareOrderItems(List<dynamic> items) {
    return items.map((item) => {
      'itemId': item['id'] ?? item['itemId'],
      'quantity': item['quantity'] ?? 1,
    }).toList();
  }
  /// Cancel an order (customer)
  static Future<Map<String, dynamic>> cancelOrderRequest(String orderId) async {
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
        final Map<String, dynamic> jsonData = json.decode(response.body);
        return jsonData['data'] ?? {};
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error cancelling order: $e');
      throw Exception('Failed to cancel order: $e');
    }
    return {};
  }

  /// Create a review
  static Future<Map<String, dynamic>> createReview(Map<String, dynamic> reviewData) async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      // Validate required fields according to backend validator
      if (!reviewData.containsKey('orderId')) {
        throw Exception('orderId is required');
      }

      if (!reviewData.containsKey('rating')) {
        throw Exception('rating is required');
      }

      // Transform to match backend expectation
      final requestBody = {
        'orderId': reviewData['orderId'],
        'rating': reviewData['rating'],
        'comment': reviewData['comment'],
      };

      // Add store or driver specific review if provided
      if (reviewData.containsKey('store')) {
        requestBody['store'] = reviewData['store'];
      }

      if (reviewData.containsKey('driver')) {
        requestBody['driver'] = reviewData['driver'];
      }

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/orders/review'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 201) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
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

  /// Get orders for store
  static Future<Map<String, dynamic>> getOrdersByStore({
    int page = 1,
    int limit = 10,
    String? sortBy,
    String? sortOrder,
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

      if (sortBy != null) {
        queryParams['sortBy'] = sortBy;
      }

      if (sortOrder != null) {
        queryParams['sortOrder'] = sortOrder;
      }

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
        final Map<String, dynamic> jsonData = json.decode(response.body);

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

  /// Process order by store (approve/reject)
  static Future<Map<String, dynamic>> processOrderByStore(String orderId, String action) async {
    try {
      if (action != 'approve' && action != 'reject') {
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
        final Map<String, dynamic> jsonData = json.decode(response.body);

        // Process images in the response
        if (jsonData['data'] != null) {
          _processOrderImages(jsonData['data']);
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

  /// Get orders for driver
  static Future<Map<String, dynamic>> getDriverOrders({
    int page = 1,
    int limit = 10,
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

      final uri = Uri.parse('${ApiConstants.baseUrl}/drivers/orders')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);

        // Process and format data consistently
        if (jsonData['data'] != null) {
          final data = jsonData['data'];

          // Handle both list and paginated response
          List<dynamic> orders = [];
          if (data is List) {
            orders = data;
          } else if (data['orders'] != null && data['orders'] is List) {
            orders = data['orders'];
          }

          // Process each order with complete data processing
          for (var order in orders) {
            _processCompleteOrderData(order);
          }

          // Return consistent structure
          if (data is List) {
            return {
              'orders': orders,
              'totalItems': orders.length,
              'totalPages': 1,
              'currentPage': 1,
            };
          } else {
            return data;
          }
        }

        return {
          'orders': [],
          'totalItems': 0,
          'totalPages': 0,
          'currentPage': 1,
        };
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error fetching driver orders: $e');
      throw Exception('Failed to load driver orders: $e');
    }
    return {
      'orders': [],
      'totalItems': 0,
      'totalPages': 0,
      'currentPage': 1,
    };
  }

  /// Enhanced helper method to process complete order data including all nested objects
  static void _processCompleteOrderData(Map<String, dynamic> order) {
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

    // Ensure all date fields are properly formatted
    if (order['orderDate'] != null && order['orderDate'] is String) {
      try {
        // Validate date format
        DateTime.parse(order['orderDate']);
      } catch (e) {
        // If date parsing fails, set to current time
        order['orderDate'] = DateTime.now().toIso8601String();
      }
    }

    if (order['estimatedDeliveryTime'] != null && order['estimatedDeliveryTime'] is String) {
      try {
        // Validate date format
        DateTime.parse(order['estimatedDeliveryTime']);
      } catch (e) {
        // If date parsing fails, remove the field
        order.remove('estimatedDeliveryTime');
      }
    }

    // Ensure numeric fields are properly typed
    if (order['subtotal'] != null) {
      order['subtotal'] = (order['subtotal'] as num).toDouble();
    }
    if (order['serviceCharge'] != null) {
      order['serviceCharge'] = (order['serviceCharge'] as num).toDouble();
    }
    if (order['total'] != null) {
      order['total'] = (order['total'] as num).toDouble();
    }

    // Ensure status fields have default values
    order['order_status'] = order['order_status'] ?? 'pending';
    order['delivery_status'] = order['delivery_status'] ?? 'waiting';
  }

  /// Get order detail
  static Future<Map<String, dynamic>> getOrderDetail(String orderId) async {
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
        final Map<String, dynamic> jsonData = json.decode(response.body);

        // Process images in the response
        if (jsonData['data'] != null) {
          _processOrderImages(jsonData['data']);
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

  /// Update order status
  static Future<Map<String, dynamic>> updateOrderStatus(String orderId, String status) async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      // Validate status
      final validStatuses = [
        'pending', 'approved', 'preparing',
        'on_delivery', 'delivered', 'cancelled'
      ];

      if (!validStatuses.contains(status)) {
        throw Exception('Invalid status. Valid statuses are: ${validStatuses.join(', ')}');
      }

      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/orders/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'id': orderId,
          'status': status
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);

        // Process images in the response
        if (jsonData['data'] != null) {
          _processOrderImages(jsonData['data']);
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

  /// Get driver requests
  static Future<Map<String, dynamic>> getDriverRequests({
    int page = 1,
    int limit = 10,
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
        final Map<String, dynamic> jsonData = json.decode(response.body);

        // Process images and data
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
      throw Exception('Failed to load driver requests: $e');
    }
    return {};
  }

  /// Get driver request detail
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
        final Map<String, dynamic> jsonData = json.decode(response.body);

        // Process images in order data
        if (jsonData['data'] != null && jsonData['data']['order'] != null) {
          _processOrderImages(jsonData['data']['order']);
        }

        return jsonData['data'] ?? {};
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error fetching driver request detail: $e');
      throw Exception('Failed to load driver request detail: $e');
    }
    return {};
  }

  /// Respond to driver request (accept/reject)
  static Future<Map<String, dynamic>> respondToDriverRequest(String requestId, String action) async {
    try {
      if (action != 'accept' && action != 'reject') {
        throw Exception('Action must be "accept" or "reject"');
      }

      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/driver-requests/$requestId/respond'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'action': action}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);

        // Process images in the response
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

  /// Helper method to process images in order data
  static void _processOrderImages(Map<String, dynamic> order) {
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

    // Process driver avatar if present
    if (order['driver'] != null && order['driver']['avatar'] != null) {
      order['driver']['avatar'] = ImageService.getImageUrl(order['driver']['avatar']);
    }

    // Process order items if present
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
  }

  /// Helper method to handle error responses
  static void _handleErrorResponse(http.Response response) {
    try {
      final errorData = json.decode(response.body);
      throw Exception(errorData['message'] ?? 'Request failed with status ${response.statusCode}');
    } catch (e) {
      if (e is Exception && e.toString().contains('message')) {
        rethrow;
      }
      throw Exception('Request failed with status ${response.statusCode}: ${response.body}');
    }
  }
}