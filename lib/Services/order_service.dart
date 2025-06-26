// lib/Services/order_service.dart
import 'dart:convert';
import 'dart:math' as math;
import 'core/base_service.dart';
import 'image_service.dart';
import 'auth_service.dart';

class OrderService {
  static const String _baseEndpoint = '/orders';

  /// Place a new order (customer only) - FIXED to match backend structure
  static Future<Map<String, dynamic>> placeOrder({
    required String storeId,
    required List<Map<String, dynamic>> items,
    String? notes,
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

      // ✅ PERBAIKAN: Prepare order body sesuai struktur backend
      final body = {
        'store_id': int.parse(storeId), // Backend expect 'store_id', bukan 'storeId'
        'items': items.map((item) => {
          'menu_item_id': item['id'] ?? item['menu_item_id'] ?? item['itemId'], // Backend expect 'menu_item_id'
          'quantity': item['quantity'] ?? 1,
          'notes': item['notes'] ?? '',
        }).toList(),
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      };

      print('📋 OrderService: Order payload prepared');
      print('   - Store ID: ${body['store_id']}');
      print('   - Items count: ${(body['items'] as List).length}');

      // ✅ PERBAIKAN: Make API call dengan endpoint yang benar
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
        print('   - Auto driver search started in background');
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

  /// Get orders by user (customer) dengan struktur response yang benar
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

      // ✅ PERBAIKAN: Process response sesuai struktur backend
      if (response['data'] != null && response['data']['orders'] != null) {
        final orders = response['data']['orders'] as List;
        for (var order in orders) {
          _processOrderImages(order);
          _processTrackingUpdates(order); // Process tracking updates
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

  /// Get orders by store (store owner) dengan struktur response yang benar
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

      // ✅ PERBAIKAN: Process response sesuai struktur backend
      if (response['data'] != null && response['data']['orders'] != null) {
        final orders = response['data']['orders'] as List;
        for (var order in orders) {
          _processOrderImages(order);
          _processTrackingUpdates(order); // Process tracking updates
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

  /// Get order by ID dengan enhanced data processing
  static Future<Map<String, dynamic>> getOrderById(String orderId) async {
    try {
      print('🔍 OrderService: Getting order by ID: $orderId');

      // ✅ PERBAIKAN: Validate authentication
      final isAuth = await AuthService.isAuthenticated();
      if (!isAuth) {
        throw Exception('Authentication required');
      }

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/$orderId',
        requiresAuth: true,
      );

      if (response['data'] != null) {
        _processOrderImages(response['data']);
        _processTrackingUpdates(response['data']);
        print('✅ OrderService: Order details retrieved successfully');
        return response['data'];
      }

      throw Exception('Order not found or invalid response');
    } catch (e) {
      print('❌ OrderService: Get order by ID error: $e');
      throw Exception('Failed to get order: $e');
    }
  }

  /// ✅ BARU: Process order by store (approve/reject) - sesuai dengan backend
  static Future<Map<String, dynamic>> processOrderByStore({
    required String orderId,
    required String action, // 'approve' atau 'reject'
    String? rejectionReason,
  }) async {
    try {
      print('⚙️ OrderService: Processing order: $orderId, action: $action');

      // Validate store access
      final hasStoreAccess = await AuthService.hasRole('store');
      if (!hasStoreAccess) {
        throw Exception('Access denied: Store authentication required');
      }

      if (!['approve', 'reject'].contains(action.toLowerCase())) {
        throw Exception('Invalid action. Must be "approve" or "reject"');
      }

      final body = {
        'action': action.toLowerCase(),
        if (rejectionReason != null && rejectionReason.isNotEmpty)
          'rejection_reason': rejectionReason,
      };

      final response = await BaseService.apiCall(
        method: 'POST', // Backend menggunakan POST
        endpoint: '$_baseEndpoint/$orderId/process',
        body: body,
        requiresAuth: true,
      );

      print('✅ OrderService: Order processed successfully');
      if (response['data'] != null) {
        _processOrderImages(response['data']);
        _processTrackingUpdates(response['data']);
      }
      return response['data'] ?? {};
    } catch (e) {
      print('❌ OrderService: Process order by store error: $e');
      throw Exception('Failed to process order: $e');
    }
  }

  /// Update order status dengan role-based validation
  static Future<Map<String, dynamic>> updateOrderStatus({
    required String orderId,
    required String orderStatus,
    String? deliveryStatus,
    String? notes,
  }) async {
    try {
      print('📝 OrderService: Updating order status: $orderId to $orderStatus');

      // Validate authentication and role
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
        'order_status': orderStatus,
        if (deliveryStatus != null) 'delivery_status': deliveryStatus,
        if (notes != null) 'notes': notes,
      };

      final response = await BaseService.apiCall(
        method: 'PATCH',
        endpoint: '$_baseEndpoint/$orderId/status',
        body: body,
        requiresAuth: true,
      );

      print('✅ OrderService: Order status updated successfully');
      if (response['data'] != null) {
        _processOrderImages(response['data']);
        _processTrackingUpdates(response['data']);
      }
      return response['data'] ?? {};
    } catch (e) {
      print('❌ OrderService: Update order status error: $e');
      throw Exception('Failed to update order status: $e');
    }
  }

  /// Create review for completed order dengan customer validation
  static Future<Map<String, dynamic>> createReview({
    required String orderId,
    required Map<String, dynamic> orderReview,
    required Map<String, dynamic> driverReview,
  }) async {
    try {
      print('⭐ OrderService: Creating review for order: $orderId');

      // Validate customer access
      final hasAccess = await AuthService.validateCustomerAccess();
      if (!hasAccess) {
        throw Exception('Access denied: Customer authentication required');
      }

      final body = {
        'order_review': orderReview,
        'driver_review.dart': driverReview,
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

  /// ✅ BARU: Get order delivery fee calculation
  static Future<Map<String, dynamic>> calculateDeliveryFee({
    required String storeId,
    required double destinationLatitude,
    required double destinationLongitude,
  }) async {
    try {
      print('💰 OrderService: Calculating delivery fee...');

      final isAuth = await AuthService.isAuthenticated();
      if (!isAuth) {
        throw Exception('Authentication required');
      }

      final queryParams = {
        'store_id': storeId,
        'destination_latitude': destinationLatitude.toString(),
        'destination_longitude': destinationLongitude.toString(),
      };

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/calculate-delivery-fee',
        queryParams: queryParams,
        requiresAuth: true,
      );

      print('✅ OrderService: Delivery fee calculated successfully');
      return response['data'] ?? {};
    } catch (e) {
      print('❌ OrderService: Calculate delivery fee error: $e');
      return {
        'delivery_fee': 5000.0, // Default fallback fee
        'distance_km': 0.0,
      };
    }
  }

  /// ✅ BARU: Get order statistics dengan role-based validation
  static Future<Map<String, dynamic>> getOrderStatistics({
    DateTime? startDate,
    DateTime? endDate,
    String? groupBy, // day, week, month
  }) async {
    try {
      print('📈 OrderService: Getting order statistics...');

      // Validate store or admin access
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

  // PRIVATE HELPER METHODS

  /// ✅ BARU: Process tracking updates yang berupa JSON string
  static void _processTrackingUpdates(Map<String, dynamic> order) {
    try {
      if (order['tracking_updates'] != null) {
        final trackingUpdatesRaw = order['tracking_updates'];

        if (trackingUpdatesRaw is String) {
          // Parse JSON string menjadi List
          try {
            final parsed = jsonDecode(trackingUpdatesRaw);
            if (parsed is List) {
              order['tracking_updates'] = parsed;
            }
          } catch (e) {
            print('⚠️ Failed to parse tracking_updates JSON: $e');
            order['tracking_updates'] = [];
          }
        } else if (trackingUpdatesRaw is List) {
          // Already a List, keep as is
          order['tracking_updates'] = trackingUpdatesRaw;
        } else {
          order['tracking_updates'] = [];
        }
      }
    } catch (e) {
      print('❌ OrderService: Error processing tracking updates: $e');
      order['tracking_updates'] = [];
    }
  }

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

      // Process driver avatar (bisa di nested user atau langsung)
      if (order['driver'] != null) {
        if (order['driver']['user'] != null && order['driver']['user']['avatar'] != null) {
          order['driver']['user']['avatar'] = ImageService.getImageUrl(order['driver']['user']['avatar']);
        } else if (order['driver']['avatar'] != null) {
          order['driver']['avatar'] = ImageService.getImageUrl(order['driver']['avatar']);
        }
      }

      // Process order items images (backend structure: items atau order_items)
      if (order['items'] != null) {
        final items = order['items'] as List;
        for (var item in items) {
          if (item['image_url'] != null) {
            item['image_url'] = ImageService.getImageUrl(item['image_url']);
          }
        }
      }

      // Alternative structure for order items
      if (order['order_items'] != null) {
        final orderItems = order['order_items'] as List;
        for (var item in orderItems) {
          if (item['image_url'] != null) {
            item['image_url'] = ImageService.getImageUrl(item['image_url']);
          }
          if (item['menu_item'] != null && item['menu_item']['image_url'] != null) {
            item['menu_item']['image_url'] = ImageService.getImageUrl(item['menu_item']['image_url']);
          }
        }
      }
    } catch (e) {
      print('❌ OrderService: Error processing order images: $e');
    }
  }
}