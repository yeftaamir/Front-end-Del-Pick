// lib/Services/order_service.dart
import 'dart:convert';
import 'dart:math' as math;
import 'core/base_service.dart';
import 'image_service.dart';

class OrderService {
  static const String _baseEndpoint = '/orders';

  /// Place a new order (customer only)
  static Future<Map<String, dynamic>> placeOrder({
    required String storeId,
    required List<Map<String, dynamic>> items,
    required String deliveryAddress,
    required double latitude,
    required double longitude,
    required double serviceCharge,
    String? notes,
    String? paymentMethod,
  }) async {
    try {
      final body = {
        'storeId': int.parse(storeId),
        'items': items.map((item) => {
          'itemId': item['id'] ?? item['itemId'],
          'quantity': item['quantity'] ?? 1,
          'notes': item['notes'] ?? '',
        }).toList(),
        'deliveryAddress': deliveryAddress,
        'latitude': latitude,
        'longitude': longitude,
        'serviceCharge': serviceCharge,
        'notes': notes ?? '',
        if (paymentMethod != null) 'paymentMethod': paymentMethod,
      };

      final response = await BaseService.apiCall(
        method: 'POST',
        endpoint: _baseEndpoint,
        body: body,
        requiresAuth: true,
      );

      if (response['data'] != null) {
        _processOrderImages(response['data']);
      }

      return response['data'] ?? {};
    } catch (e) {
      print('Place order error: $e');
      throw Exception('Failed to place order: $e');
    }
  }

  /// Get orders by user (customer)
  static Future<Map<String, dynamic>> getOrdersByUser({
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
        endpoint: '$_baseEndpoint/customer',
        queryParams: queryParams,
        requiresAuth: true,
      );

      // Process images in orders
      if (response['data'] != null && response['data']['orders'] != null) {
        final orders = response['data']['orders'] as List;
        for (var order in orders) {
          _processOrderImages(order);
        }
      }

      return response['data'] ?? {
        'orders': [],
        'totalItems': 0,
        'totalPages': 0,
        'currentPage': 1,
      };
    } catch (e) {
      print('Get orders by user error: $e');
      throw Exception('Failed to get user orders: $e');
    }
  }

  /// Get orders by store (store owner)
  static Future<Map<String, dynamic>> getOrdersByStore({
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
        endpoint: '$_baseEndpoint/store',
        queryParams: queryParams,
        requiresAuth: true,
      );

      // Process images in orders
      if (response['data'] != null && response['data']['orders'] != null) {
        final orders = response['data']['orders'] as List;
        for (var order in orders) {
          _processOrderImages(order);
        }
      }

      return response['data'] ?? {
        'orders': [],
        'totalItems': 0,
        'totalPages': 0,
        'currentPage': 1,
      };
    } catch (e) {
      print('Get orders by store error: $e');
      throw Exception('Failed to get store orders: $e');
    }
  }

  /// Get order by ID
  static Future<Map<String, dynamic>> getOrderById(String orderId) async {
    try {
      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/$orderId',
        requiresAuth: true,
      );

      if (response['data'] != null) {
        _processOrderImages(response['data']);
      }

      return response['data'] ?? {};
    } catch (e) {
      print('Get order by ID error: $e');
      throw Exception('Failed to get order: $e');
    }
  }

  /// Cancel order (customer)
  static Future<Map<String, dynamic>> cancelOrder(String orderId) async {
    try {
      final response = await BaseService.apiCall(
        method: 'PUT',
        endpoint: '$_baseEndpoint/$orderId/cancel',
        requiresAuth: true,
      );

      return response['data'] ?? {};
    } catch (e) {
      print('Cancel order error: $e');
      throw Exception('Failed to cancel order: $e');
    }
  }

  /// Process order by store (accept/reject)
  static Future<Map<String, dynamic>> processOrderByStore({
    required String orderId,
    required String action, // accept, reject
    String? estimatedPreparationTime,
    String? rejectionReason,
  }) async {
    try {
      final body = {
        'action': action,
        if (estimatedPreparationTime != null) 'estimatedPreparationTime': estimatedPreparationTime,
        if (rejectionReason != null) 'rejectionReason': rejectionReason,
      };

      final response = await BaseService.apiCall(
        method: 'PUT',
        endpoint: '$_baseEndpoint/$orderId/process',
        body: body,
        requiresAuth: true,
      );

      return response['data'] ?? {};
    } catch (e) {
      print('Process order by store error: $e');
      throw Exception('Failed to process order: $e');
    }
  }

  /// Update order status
  static Future<Map<String, dynamic>> updateOrderStatus({
    required String orderId,
    required String status,
    String? notes,
  }) async {
    try {
      final body = {
        'status': status,
        if (notes != null) 'notes': notes,
      };

      final response = await BaseService.apiCall(
        method: 'PATCH',
        endpoint: '$_baseEndpoint/$orderId/status',
        body: body,
        requiresAuth: true,
      );

      return response['data'] ?? {};
    } catch (e) {
      print('Update order status error: $e');
      throw Exception('Failed to update order status: $e');
    }
  }

  /// Find driver in background (automatic driver assignment)
  static Future<Map<String, dynamic>> findDriverInBackground(String orderId) async {
    try {
      final response = await BaseService.apiCall(
        method: 'POST',
        endpoint: '$_baseEndpoint/$orderId/find-driver',
        requiresAuth: true,
      );

      return response['data'] ?? {};
    } catch (e) {
      print('Find driver in background error: $e');
      throw Exception('Failed to find driver: $e');
    }
  }

  /// Cancel order request (for various scenarios)
  static Future<Map<String, dynamic>> cancelOrderRequest(String orderId) async {
    try {
      final response = await BaseService.apiCall(
        method: 'POST',
        endpoint: '$_baseEndpoint/$orderId/cancel-request',
        requiresAuth: true,
      );

      return response['data'] ?? {};
    } catch (e) {
      print('Cancel order request error: $e');
      throw Exception('Failed to cancel order request: $e');
    }
  }

  /// Create review for completed order
  static Future<Map<String, dynamic>> createReview({
    required String orderId,
    required Map<String, dynamic> orderReview,
    required Map<String, dynamic> driverReview,
  }) async {
    try {
      final body = {
        'order_review': orderReview,
        'driver_review': driverReview,
      };

      final response = await BaseService.apiCall(
        method: 'POST',
        endpoint: '$_baseEndpoint/$orderId/review',
        body: body,
        requiresAuth: true,
      );

      return response['data'] ?? {};
    } catch (e) {
      print('Create review error: $e');
      throw Exception('Failed to create review: $e');
    }
  }

  /// Calculate estimated times for order
  static Future<Map<String, dynamic>> calculateEstimatedTimes({
    required String storeId,
    required double customerLatitude,
    required double customerLongitude,
  }) async {
    try {
      final body = {
        'storeId': storeId,
        'customerLatitude': customerLatitude,
        'customerLongitude': customerLongitude,
      };

      final response = await BaseService.apiCall(
        method: 'POST',
        endpoint: '$_baseEndpoint/estimate-times',
        body: body,
        requiresAuth: true,
      );

      return response['data'] ?? {};
    } catch (e) {
      print('Calculate estimated times error: $e');
      throw Exception('Failed to calculate estimated times: $e');
    }
  }

  /// Get order statistics
  static Future<Map<String, dynamic>> getOrderStatistics({
    DateTime? startDate,
    DateTime? endDate,
    String? groupBy, // day, week, month
  }) async {
    try {
      final queryParams = <String, String>{};
      if (startDate != null) queryParams['startDate'] = startDate.toIso8601String();
      if (endDate != null) queryParams['endDate'] = endDate.toIso8601String();
      if (groupBy != null) queryParams['groupBy'] = groupBy;

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/statistics',
        queryParams: queryParams.isNotEmpty ? queryParams : null,
        requiresAuth: true,
      );

      return response['data'] ?? {};
    } catch (e) {
      print('Get order statistics error: $e');
      return {};
    }
  }

  // PRIVATE HELPER METHODS

  /// Process images in order data
  static void _processOrderImages(Map<String, dynamic> order) {
    try {
      // Process store image
      if (order['store'] != null && order['store']['image_url'] != null) {
        order['store']['image_url'] = ImageService.getImageUrl(order['store']['image_url']);
      }

      // Process customer avatar
      if (order['customer'] != null && order['customer']['avatar'] != null) {
        order['customer']['avatar'] = ImageService.getImageUrl(order['customer']['avatar']);
      }

      // Process driver avatar
      if (order['driver'] != null && order['driver']['avatar'] != null) {
        order['driver']['avatar'] = ImageService.getImageUrl(order['driver']['avatar']);
      }

      // Process order items images
      if (order['order_items'] != null) {
        final orderItems = order['order_items'] as List;
        for (var item in orderItems) {
          if (item['menu_item'] != null && item['menu_item']['image_url'] != null) {
            item['menu_item']['image_url'] =
                ImageService.getImageUrl(item['menu_item']['image_url']);
          }
        }
      }
    } catch (e) {
      print('Error processing order images: $e');
    }
  }
}