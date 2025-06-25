// lib/Services/order_service.dart
import 'dart:convert';
import 'dart:math' as math;
import 'core/base_service.dart';
import 'image_service.dart';
import 'auth_service.dart';

class OrderService {
  static const String _baseEndpoint = '/orders';

  /// Place a new order (customer only) with enhanced auth validation
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
      print('🚀 OrderService: Starting placeOrder...');

      // ✅ PERBAIKAN: Validate customer access first
      final hasAccess = await AuthService.validateCustomerAccess();
      if (!hasAccess) {
        throw Exception('Access denied: Customer authentication required');
      }

      // ✅ PERBAIKAN: Get validated customer data
      final customerData = await AuthService.getCustomerData();
      if (customerData == null) {
        throw Exception('Unable to retrieve customer data');
      }

      print('✅ OrderService: Customer access validated');
      print('   - Customer ID: ${customerData['id']}');
      print('   - Customer Name: ${customerData['name']}');

      // ✅ PERBAIKAN: Prepare order body with validated data
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

      print('📋 OrderService: Order payload prepared');
      print('   - Store ID: ${body['storeId']}');
      print('   - Items count: ${(body['items'] as List).length}');
      print('   - Delivery address: $deliveryAddress');
      print('   - Service charge: $serviceCharge');

      // ✅ PERBAIKAN: Make API call with enhanced error handling
      final response = await BaseService.apiCall(
        method: 'POST',
        endpoint: _baseEndpoint,
        body: body,
        requiresAuth: true,
      );

      print('📡 OrderService: API response received');

      if (response['data'] != null) {
        _processOrderImages(response['data']);
        print('✅ OrderService: Order created successfully');
        print('   - Order ID: ${response['data']['id']}');
        return response['data'];
      }

      throw Exception('Invalid response: No order data returned');
    } catch (e) {
      print('❌ OrderService: Place order error: $e');

      // ✅ PERBAIKAN: Enhanced error handling with specific messages
      if (e.toString().contains('authentication') || e.toString().contains('Access denied')) {
        throw Exception('Authentication required. Please login as customer.');
      } else if (e.toString().contains('validation')) {
        throw Exception('Order validation failed. Please check your order details.');
      } else if (e.toString().contains('network') || e.toString().contains('connection')) {
        throw Exception('Network error. Please check your internet connection.');
      } else {
        throw Exception('Failed to place order: ${e.toString()}');
      }
    }
  }

  /// Get orders by user (customer) with enhanced auth validation
  static Future<Map<String, dynamic>> getOrdersByUser({
    int page = 1,
    int limit = 10,
    String? status,
    String? sortBy,
    String? sortOrder,
  }) async {
    try {
      print('🔍 OrderService: Getting orders by user...');

      // ✅ PERBAIKAN: Validate customer access
      final hasAccess = await AuthService.validateCustomerAccess();
      if (!hasAccess) {
        throw Exception('Access denied: Customer authentication required');
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
        print('✅ OrderService: Retrieved ${orders.length} orders');
      }

      return response['data'] ?? {
        'orders': [],
        'totalItems': 0,
        'totalPages': 0,
        'currentPage': 1,
      };
    } catch (e) {
      print('❌ OrderService: Get orders by user error: $e');
      throw Exception('Failed to get user orders: $e');
    }
  }

  /// Get orders by store (store owner) with enhanced auth validation
  static Future<Map<String, dynamic>> getOrdersByStore({
    int page = 1,
    int limit = 10,
    String? status,
    String? sortBy,
    String? sortOrder,
  }) async {
    try {
      print('🔍 OrderService: Getting orders by store...');

      // ✅ PERBAIKAN: Validate store access
      final hasStoreAccess = await AuthService.hasRole('store');
      if (!hasStoreAccess) {
        throw Exception('Access denied: Store authentication required');
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
        print('✅ OrderService: Retrieved ${orders.length} store orders');
      }

      return response['data'] ?? {
        'orders': [],
        'totalItems': 0,
        'totalPages': 0,
        'currentPage': 1,
      };
    } catch (e) {
      print('❌ OrderService: Get orders by store error: $e');
      throw Exception('Failed to get store orders: $e');
    }
  }

  /// Get order by ID with enhanced auth validation
  static Future<Map<String, dynamic>> getOrderById(String orderId) async {
    try {
      print('🔍 OrderService: Getting order by ID: $orderId');

      // ✅ PERBAIKAN: Validate authentication
      final isAuth = await AuthService.isAuthenticated();
      if (!isAuth) {
        throw Exception('Authentication required');
      }

      // ✅ PERBAIKAN: Ensure valid user data
      final hasValidData = await AuthService.ensureValidUserData();
      if (!hasValidData) {
        throw Exception('Invalid user data. Please login again.');
      }

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/$orderId',
        requiresAuth: true,
      );

      if (response['data'] != null) {
        _processOrderImages(response['data']);
        print('✅ OrderService: Order details retrieved successfully');
        return response['data'];
      }

      throw Exception('Order not found or invalid response');
    } catch (e) {
      print('❌ OrderService: Get order by ID error: $e');
      throw Exception('Failed to get order: $e');
    }
  }

  /// Cancel order (customer) with enhanced validation
  static Future<Map<String, dynamic>> cancelOrder(String orderId) async {
    try {
      print('🚫 OrderService: Cancelling order: $orderId');

      // ✅ PERBAIKAN: Validate customer access
      final hasAccess = await AuthService.validateCustomerAccess();
      if (!hasAccess) {
        throw Exception('Access denied: Customer authentication required');
      }

      final response = await BaseService.apiCall(
        method: 'PUT',
        endpoint: '$_baseEndpoint/$orderId/cancel',
        requiresAuth: true,
      );

      print('✅ OrderService: Order cancelled successfully');
      return response['data'] ?? {};
    } catch (e) {
      print('❌ OrderService: Cancel order error: $e');
      throw Exception('Failed to cancel order: $e');
    }
  }

  /// Process order by store (accept/reject) with enhanced validation
  static Future<Map<String, dynamic>> processOrderByStore({
    required String orderId,
    required String action, // accept, reject
    String? estimatedPreparationTime,
    String? rejectionReason,
  }) async {
    try {
      print('⚙️ OrderService: Processing order: $orderId, action: $action');

      // ✅ PERBAIKAN: Validate store access
      final hasStoreAccess = await AuthService.hasRole('store');
      if (!hasStoreAccess) {
        throw Exception('Access denied: Store authentication required');
      }

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

      print('✅ OrderService: Order processed successfully');
      return response['data'] ?? {};
    } catch (e) {
      print('❌ OrderService: Process order by store error: $e');
      throw Exception('Failed to process order: $e');
    }
  }

  /// Update order status with role-based validation
  static Future<Map<String, dynamic>> updateOrderStatus({
    required String orderId,
    required String status,
    String? notes,
  }) async {
    try {
      print('📝 OrderService: Updating order status: $orderId to $status');

      // ✅ PERBAIKAN: Validate authentication and role
      final isAuth = await AuthService.isAuthenticated();
      if (!isAuth) {
        throw Exception('Authentication required');
      }

      final userRole = await AuthService.getUserRole();
      if (userRole == null) {
        throw Exception('Unable to determine user role');
      }

      // Check if user has permission to update order status
      if (!['store', 'driver', 'admin'].contains(userRole.toLowerCase())) {
        throw Exception('Access denied: Insufficient permissions to update order status');
      }

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

      print('✅ OrderService: Order status updated successfully');
      return response['data'] ?? {};
    } catch (e) {
      print('❌ OrderService: Update order status error: $e');
      throw Exception('Failed to update order status: $e');
    }
  }

  /// Find driver in background (automatic driver assignment) with validation
  static Future<Map<String, dynamic>> findDriverInBackground(String orderId) async {
    try {
      print('🚗 OrderService: Finding driver for order: $orderId');

      // ✅ PERBAIKAN: Validate store or admin access
      final userRole = await AuthService.getUserRole();
      if (!['store', 'admin', 'system'].contains(userRole?.toLowerCase())) {
        throw Exception('Access denied: Only store or admin can trigger driver search');
      }

      final response = await BaseService.apiCall(
        method: 'POST',
        endpoint: '$_baseEndpoint/$orderId/find-driver',
        requiresAuth: true,
      );

      print('✅ OrderService: Driver search initiated successfully');
      return response['data'] ?? {};
    } catch (e) {
      print('❌ OrderService: Find driver in background error: $e');
      throw Exception('Failed to find driver: $e');
    }
  }

  /// Cancel order request (for various scenarios) with validation
  static Future<Map<String, dynamic>> cancelOrderRequest(String orderId) async {
    try {
      print('🚫 OrderService: Cancelling order request: $orderId');

      // ✅ PERBAIKAN: Validate authentication
      final isAuth = await AuthService.isAuthenticated();
      if (!isAuth) {
        throw Exception('Authentication required');
      }

      final response = await BaseService.apiCall(
        method: 'POST',
        endpoint: '$_baseEndpoint/$orderId/cancel-request',
        requiresAuth: true,
      );

      print('✅ OrderService: Order request cancelled successfully');
      return response['data'] ?? {};
    } catch (e) {
      print('❌ OrderService: Cancel order request error: $e');
      throw Exception('Failed to cancel order request: $e');
    }
  }

  /// Create review for completed order with customer validation
  static Future<Map<String, dynamic>> createReview({
    required String orderId,
    required Map<String, dynamic> orderReview,
    required Map<String, dynamic> driverReview,
  }) async {
    try {
      print('⭐ OrderService: Creating review for order: $orderId');

      // ✅ PERBAIKAN: Validate customer access
      final hasAccess = await AuthService.validateCustomerAccess();
      if (!hasAccess) {
        throw Exception('Access denied: Customer authentication required');
      }

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

      print('✅ OrderService: Review created successfully');
      return response['data'] ?? {};
    } catch (e) {
      print('❌ OrderService: Create review error: $e');
      throw Exception('Failed to create review: $e');
    }
  }

  /// Calculate estimated times for order with validation
  static Future<Map<String, dynamic>> calculateEstimatedTimes({
    required String storeId,
    required double customerLatitude,
    required double customerLongitude,
  }) async {
    try {
      print('📊 OrderService: Calculating estimated times...');

      // ✅ PERBAIKAN: Validate authentication
      final isAuth = await AuthService.isAuthenticated();
      if (!isAuth) {
        throw Exception('Authentication required');
      }

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

      print('✅ OrderService: Estimated times calculated successfully');
      return response['data'] ?? {};
    } catch (e) {
      print('❌ OrderService: Calculate estimated times error: $e');
      throw Exception('Failed to calculate estimated times: $e');
    }
  }

  /// Get order statistics with role-based validation
  static Future<Map<String, dynamic>> getOrderStatistics({
    DateTime? startDate,
    DateTime? endDate,
    String? groupBy, // day, week, month
  }) async {
    try {
      print('📈 OrderService: Getting order statistics...');

      // ✅ PERBAIKAN: Validate store or admin access
      final userRole = await AuthService.getUserRole();
      if (!['store', 'admin'].contains(userRole?.toLowerCase())) {
        throw Exception('Access denied: Only store or admin can view statistics');
      }

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

      print('✅ OrderService: Order statistics retrieved successfully');
      return response['data'] ?? {};
    } catch (e) {
      print('❌ OrderService: Get order statistics error: $e');
      return {};
    }
  }

  // ✅ PERBAIKAN: Enhanced helper method untuk validasi customer data
  static Future<Map<String, dynamic>?> _validateCustomerForOrder() async {
    try {
      // Check if authenticated as customer
      final hasAccess = await AuthService.validateCustomerAccess();
      if (!hasAccess) {
        return null;
      }

      // Get customer data
      final customerData = await AuthService.getCustomerData();
      if (customerData == null) {
        return null;
      }

      // Validate required customer fields
      if (customerData['id'] == null || customerData['name'] == null) {
        print('⚠️ OrderService: Incomplete customer data');
        return null;
      }

      return customerData;
    } catch (e) {
      print('❌ OrderService: Customer validation error: $e');
      return null;
    }
  }

  // ✅ PERBAIKAN: Enhanced method untuk refresh user data jika diperlukan
  static Future<bool> _ensureValidUserSession() async {
    try {
      // Check if user data is valid
      final hasValidData = await AuthService.ensureValidUserData();
      if (!hasValidData) {
        print('⚠️ OrderService: Invalid user session, attempting refresh...');

        // Try to refresh user data
        final refreshedData = await AuthService.refreshUserData();
        if (refreshedData == null) {
          print('❌ OrderService: Failed to refresh user data');
          return false;
        }
      }

      return true;
    } catch (e) {
      print('❌ OrderService: User session validation error: $e');
      return false;
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

      // ✅ PERBAIKAN: Process items array (alternative structure)
      if (order['items'] != null) {
        final items = order['items'] as List;
        for (var item in items) {
          if (item['image_url'] != null) {
            item['image_url'] = ImageService.getImageUrl(item['image_url']);
          }
        }
      }
    } catch (e) {
      print('❌ OrderService: Error processing order images: $e');
    }
  }
}