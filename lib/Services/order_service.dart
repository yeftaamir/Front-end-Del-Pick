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

      // ✅ Enhanced authentication validation using new methods
      final userData = await AuthService.getUserData();
      final roleData = await AuthService.getRoleSpecificData();

      if (userData == null || roleData == null) {
        throw Exception('Authentication required: Please login as customer');
      }

      // Validate customer role
      final userRole = await AuthService.getUserRole();
      if (userRole?.toLowerCase() != 'customer') {
        throw Exception('Access denied: Customer authentication required');
      }

      final customerData = await AuthService.getCustomerData();
      if (customerData == null) {
        throw Exception('Unable to retrieve customer data');
      }

      print('✅ OrderService: Customer access validated');
      print('   - Customer ID: ${customerData['id']}');
      print('   - Customer Name: ${customerData['name']}');

      // ✅ Prepare order body sesuai struktur backend
      final body = {
        'store_id':
            int.parse(storeId), // Backend expect 'store_id', bukan 'storeId'
        'items': items
            .map((item) => {
                  'menu_item_id': item['id'] ??
                      item['menu_item_id'] ??
                      item['itemId'], // Backend expect 'menu_item_id'
                  'quantity': item['quantity'] ?? 1,
                  'notes': item['notes'] ?? '',
                })
            .toList(),
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      };

      print('📋 OrderService: Order payload prepared');
      print('   - Store ID: ${body['store_id']}');
      print('   - Items count: ${(body['items'] as List).length}');

      // ✅ Make API call dengan endpoint yang benar
      final response = await BaseService.apiCall(
        method: 'POST',
        endpoint: _baseEndpoint,
        body: body,
        requiresAuth: true,
      );

      print('📡 OrderService: API response received');

      if (response['data'] != null) {
        _processOrderData(response['data']);
        print('✅ OrderService: Order created successfully');
        print('   - Order ID: ${response['data']['id']}');
        print('   - Auto driver search started in background');
        return response['data'];
      }

      throw Exception('Invalid response: No order data returned');
    } catch (e) {
      print('❌ OrderService: Place order error: $e');

      // ✅ Enhanced error handling with specific messages
      if (e.toString().contains('authentication') ||
          e.toString().contains('Access denied')) {
        throw Exception('Authentication required. Please login as customer.');
      } else if (e.toString().contains('validation')) {
        throw Exception(
            'Order validation failed. Please check your order details.');
      } else if (e.toString().contains('network') ||
          e.toString().contains('connection')) {
        throw Exception(
            'Network error. Please check your internet connection.');
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

      // ✅ Enhanced validation using new auth methods
      final userData = await AuthService.getUserData();
      final roleData = await AuthService.getRoleSpecificData();

      if (userData == null || roleData == null) {
        throw Exception('Authentication required: Please login');
      }

      // Validate customer access
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

      // ✅ Process response sesuai struktur backend
      if (response['data'] != null && response['data']['orders'] != null) {
        final orders = response['data']['orders'] as List;
        for (var order in orders) {
          _processOrderData(order);
        }
        print('✅ OrderService: Retrieved ${orders.length} orders');
      }

      return response['data'] ??
          {
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
    int? timestamp,
  }) async {
    try {
      print('🔍 OrderService: Getting orders by store...');

      // ✅ Enhanced validation using new auth methods
      final userData = await AuthService.getUserData();
      final roleData = await AuthService.getRoleSpecificData();

      if (userData == null || roleData == null) {
        throw Exception('Authentication required: Please login');
      }

      // Validate store access
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
        if (timestamp != null) '_t': timestamp.toString(),
      };
      if (timestamp != null) {
        print('🕒 OrderService: Force refresh with timestamp: $timestamp');
      }
      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/store',
        queryParams: queryParams,
        requiresAuth: true,
      );

      // ✅ Process response sesuai struktur backend
      if (response['data'] != null && response['data']['orders'] != null) {
        final orders = response['data']['orders'] as List;
        for (var order in orders) {
          _processOrderData(order);
        }
        print('✅ OrderService: Retrieved ${orders.length} store orders');

        if (timestamp != null) {
          print('🔄 OrderService: Force refresh completed');
        }
      }

      return response['data'] ??
          {
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

  ///Method khusus untuk force refresh
  static Future<Map<String, dynamic>> forceRefreshOrdersByStore({
    int page = 1,
    int limit = 10,
    String? status,
    String? sortBy,
    String? sortOrder,
  }) async {
    print('🔄 OrderService: Force refreshing orders by store...');

    return await getOrdersByStore(
      page: page,
      limit: limit,
      status: status,
      sortBy: sortBy,
      sortOrder: sortOrder,
      timestamp: DateTime.now().millisecondsSinceEpoch, // Auto timestamp
    );
  }

  /// Get order by ID dengan enhanced data processing dan numeric conversion
  static Future<Map<String, dynamic>> getOrderById(String orderId) async {
    try {
      print('🔍 OrderService: Getting order by ID: $orderId');

      // ✅ Enhanced validation using new auth methods
      final userData = await AuthService.getUserData();
      final roleData = await AuthService.getRoleSpecificData();

      if (userData == null || roleData == null) {
        throw Exception('Authentication required: Please login');
      }

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
        // ✅ Process all order data including numeric fields
        _processOrderData(response['data']);
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

      // ✅ Enhanced validation using new auth methods
      final userData = await AuthService.getUserData();
      final roleData = await AuthService.getRoleSpecificData();

      if (userData == null || roleData == null) {
        throw Exception('Authentication required: Please login');
      }

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
        _processOrderData(response['data']);
      }
      return response['data'] ?? {};
    } catch (e) {
      print('❌ OrderService: Process order by store error: $e');
      throw Exception('Failed to process order: $e');
    }
  }

  /// ✅ FIXED: Update order status dengan customer cancellation permission
  static Future<Map<String, dynamic>> updateOrderStatus({
    required String orderId,
    required String orderStatus,
    String? deliveryStatus,
    String? notes,
  }) async {
    try {
      print('📝 OrderService: Updating order status: $orderId to $orderStatus');

      // ✅ Enhanced validation using new auth methods
      final userData = await AuthService.getUserData();
      final roleData = await AuthService.getRoleSpecificData();

      if (userData == null || roleData == null) {
        throw Exception('Authentication required: Please login');
      }

      // Validate authentication and role
      final isAuth = await AuthService.isAuthenticated();
      if (!isAuth) {
        throw Exception('Authentication required');
      }

      final userRole = await AuthService.getUserRole();
      if (userRole == null) {
        throw Exception('Unable to determine user role');
      }

      // ✅ FIXED: Allow customers to cancel their own orders
      bool hasPermission = false;

      if (['store', 'driver', 'admin'].contains(userRole.toLowerCase())) {
        // Store, driver, admin can update any status
        hasPermission = true;
      } else if (userRole.toLowerCase() == 'customer' &&
          orderStatus.toLowerCase() == 'cancelled') {
        // Customers can only cancel their own orders
        hasPermission = true;
        print('✅ OrderService: Customer cancellation permission granted');
      }

      if (!hasPermission) {
        throw Exception(
            'Access denied: Insufficient permissions to update order status to $orderStatus');
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
        _processOrderData(response['data']);
      }
      return response['data'] ?? {};
    } catch (e) {
      print('❌ OrderService: Update order status error: $e');
      throw Exception('Failed to update order status: $e');
    }
  }

  /// ✅ BARU: Cancel order specifically for customers
  static Future<Map<String, dynamic>> cancelOrderByCustomer({
    required String orderId,
    String? cancellationReason,
  }) async {
    try {
      print('🚫 OrderService: Customer cancelling order: $orderId');

      // ✅ Enhanced validation using new auth methods
      final userData = await AuthService.getUserData();
      final roleData = await AuthService.getRoleSpecificData();

      if (userData == null || roleData == null) {
        throw Exception('Authentication required: Please login');
      }

      // Validate customer access
      final hasAccess = await AuthService.validateCustomerAccess();
      if (!hasAccess) {
        throw Exception('Access denied: Customer authentication required');
      }

      final body = {
        'cancellation_reason': cancellationReason ?? 'Cancelled by customer',
      };

      final response = await BaseService.apiCall(
        method: 'POST',
        endpoint: '$_baseEndpoint/$orderId/cancel',
        body: body,
        requiresAuth: true,
      );

      print('✅ OrderService: Order cancelled successfully by customer');
      if (response['data'] != null) {
        _processOrderData(response['data']);
      }
      return response['data'] ?? {};
    } catch (e) {
      print('❌ OrderService: Cancel order by customer error: $e');
      // Fallback to updateOrderStatus if specific cancel endpoint doesn't exist
      try {
        return await updateOrderStatus(
          orderId: orderId,
          orderStatus: 'cancelled',
          notes: cancellationReason,
        );
      } catch (fallbackError) {
        throw Exception('Failed to cancel order: $e');
      }
    }
  }

  /// Create review for completed order dengan enhanced customer validation
  static Future<Map<String, dynamic>> createReview({
    required String orderId,
    required Map<String, dynamic> orderReview,
    required Map<String, dynamic> driverReview,
  }) async {
    try {
      print('⭐ OrderService: Creating review for order: $orderId');
      print('   - Order review: $orderReview');
      print('   - Driver review: $driverReview');

      // ✅ FIXED: Enhanced validation using getUserData() and getRoleSpecificData()
      final userData = await AuthService.getUserData();
      final roleData = await AuthService.getRoleSpecificData();

      if (userData == null) {
        throw Exception('Authentication required: Please login');
      }

      if (roleData == null) {
        throw Exception('Role data not found: Please login as customer');
      }

      // Validate customer access with specific role check
      final userRole = await AuthService.getUserRole();
      if (userRole?.toLowerCase() != 'customer') {
        throw Exception('Access denied: Only customers can create reviews');
      }

      final hasAccess = await AuthService.validateCustomerAccess();
      if (!hasAccess) {
        throw Exception('Access denied: Customer authentication required');
      }

      // ✅ FIXED: Validate review data before sending
      final orderRating = orderReview['rating'];
      final driverRating = driverReview['rating'];

      if (orderRating != null && (orderRating < 1 || orderRating > 5)) {
        throw Exception('Order rating must be between 1 and 5');
      }

      if (driverRating != null && (driverRating < 1 || driverRating > 5)) {
        throw Exception('Driver rating must be between 1 and 5');
      }

      // ✅ FIXED: Ensure at least one rating is provided and > 0
      if ((orderRating == null || orderRating <= 0) &&
          (driverRating == null || driverRating <= 0)) {
        throw Exception('At least one rating (store or driver) must be provided');
      }

      // ✅ FIXED: Clean the review data - remove null/empty ratings
      final cleanOrderReview = <String, dynamic>{};
      final cleanDriverReview = <String, dynamic>{};

      // Only include order review if rating is provided and > 0
      if (orderRating != null && orderRating > 0) {
        cleanOrderReview['rating'] = orderRating;
        final orderComment = orderReview['comment']?.toString().trim();
        if (orderComment != null && orderComment.isNotEmpty) {
          cleanOrderReview['comment'] = orderComment;
        }
      }

      // Only include driver review if rating is provided and > 0
      if (driverRating != null && driverRating > 0) {
        cleanDriverReview['rating'] = driverRating;
        final driverComment = driverReview['comment']?.toString().trim();
        if (driverComment != null && driverComment.isNotEmpty) {
          cleanDriverReview['comment'] = driverComment;
        }
      }

      final body = <String, dynamic>{};

      // Only include reviews that have valid ratings
      if (cleanOrderReview.isNotEmpty) {
        body['order_review'] = cleanOrderReview;
      }

      if (cleanDriverReview.isNotEmpty) {
        body['driver_review'] = cleanDriverReview;
      }

      if (body.isEmpty) {
        throw Exception('No valid reviews to submit');
      }

      print('📋 OrderService: Sending review body: $body');

      final response = await BaseService.apiCall(
        method: 'POST',
        endpoint: '$_baseEndpoint/$orderId/review',
        body: body,
        requiresAuth: true,
      );

      if (response['data'] != null) {
        _processOrderData(response['data']);
        print('✅ OrderService: Review created successfully');
        return response['data'];
      }

      print('✅ OrderService: Review submitted successfully (no data returned)');
      return {'success': true, 'message': 'Review submitted successfully'};

    } catch (e) {
      print('❌ OrderService: Create review error: $e');

      // Enhanced error handling with specific messages
      String errorMessage = 'Failed to submit review';

      if (e.toString().contains('authentication') || e.toString().contains('Access denied')) {
        errorMessage = 'Authentication required. Please login as customer.';
      } else if (e.toString().contains('rating must be between')) {
        errorMessage = 'Invalid rating. Please provide ratings between 1-5 stars.';
      } else if (e.toString().contains('At least one rating')) {
        errorMessage = 'Please provide at least one rating (store or driver).';
      } else if (e.toString().contains('Bad request')) {
        errorMessage = 'Invalid review data. Please check your ratings and try again.';
      } else if (e.toString().contains('network') || e.toString().contains('connection')) {
        errorMessage = 'Network error. Please check your internet connection.';
      }

      throw Exception(errorMessage);
    }
  }

  /// ✅ FIXED: Calculate delivery fee using distance * 2500 and round up
  static Future<Map<String, dynamic>> calculateDeliveryFee({
    required String storeId,
    required double destinationLatitude,
    required double destinationLongitude,
  }) async {
    try {
      print('💰 OrderService: Calculating delivery fee...');

      // ✅ Enhanced validation using new auth methods
      final userData = await AuthService.getUserData();
      final roleData = await AuthService.getRoleSpecificData();

      if (userData == null || roleData == null) {
        throw Exception('Authentication required: Please login');
      }

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

      // ✅ Process numeric fields
      if (response['data'] != null) {
        _processNumericFields(response['data']);

        // ✅ BARU: Apply custom delivery fee calculation
        final data = response['data'];
        final distance = (data['distance_km'] as double?) ?? 0.0;

        // Calculate delivery fee: distance * 2500, rounded up to nearest 1000
        final baseFee = distance * 2500;
        final roundedFee = _roundUpToNearestThousand(baseFee);

        data['delivery_fee'] = roundedFee;
        data['base_fee'] = baseFee;
        data['distance_km'] = distance;

        print('💰 OrderService: Custom delivery fee calculation:');
        print('   - Distance: ${distance.toStringAsFixed(2)} km');
        print('   - Base fee: Rp ${baseFee.toStringAsFixed(0)}');
        print('   - Rounded fee: Rp ${roundedFee.toStringAsFixed(0)}');
      }

      return response['data'] ?? {};
    } catch (e) {
      print('❌ OrderService: Calculate delivery fee error: $e');

      // ✅ BARU: Fallback with default distance calculation
      return {
        'delivery_fee': 5000.0, // Default minimum fee
        'distance_km': 2.0, // Default distance
        'base_fee': 5000.0,
      };
    }
  }

  /// ✅ BARU: Round up to nearest 1000 (Rp227 -> Rp1000)
  static double _roundUpToNearestThousand(double amount) {
    if (amount <= 1000) {
      return 1000.0; // Minimum fee Rp1000
    }

    // Round up to nearest 1000
    return (amount / 1000).ceil() * 1000.0;
  }

  /// ✅ Get order statistics dengan role-based validation
  static Future<Map<String, dynamic>> getOrderStatistics({
    DateTime? startDate,
    DateTime? endDate,
    String? groupBy, // day, week, month
  }) async {
    try {
      print('📈 OrderService: Getting order statistics...');

      // ✅ Enhanced validation using new auth methods
      final userData = await AuthService.getUserData();
      final roleData = await AuthService.getRoleSpecificData();

      if (userData == null || roleData == null) {
        throw Exception('Authentication required: Please login');
      }

      // Validate store or admin access
      final userRole = await AuthService.getUserRole();
      if (!['store', 'admin'].contains(userRole?.toLowerCase())) {
        throw Exception(
            'Access denied: Only store or admin can view statistics');
      }

      final queryParams = <String, String>{};
      if (startDate != null)
        queryParams['startDate'] = startDate.toIso8601String();
      if (endDate != null) queryParams['endDate'] = endDate.toIso8601String();
      if (groupBy != null) queryParams['groupBy'] = groupBy;

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/statistics',
        queryParams: queryParams.isNotEmpty ? queryParams : null,
        requiresAuth: true,
      );

      print('✅ OrderService: Order statistics retrieved successfully');

      // ✅ Process numeric fields in statistics
      if (response['data'] != null) {
        _processStatisticsData(response['data']);
      }

      return response['data'] ?? {};
    } catch (e) {
      print('❌ OrderService: Get order statistics error: $e');
      return {};
    }
  }

  // PRIVATE HELPER METHODS

  /// ✅ Comprehensive order data processing including numeric conversion
  static void _processOrderData(Map<String, dynamic> order) {
    try {
      print('🔄 OrderService: Processing order data...');

      // Process numeric fields first (this fixes the toDouble() error)
      _processNumericFields(order);

      // Process tracking updates
      _processTrackingUpdates(order);

      // Process images
      _processOrderImages(order);

      // Process nested order items if present
      if (order['items'] != null) {
        final items = order['items'] as List;
        for (var item in items) {
          _processNumericFields(item);
        }
      }

      if (order['order_items'] != null) {
        final orderItems = order['order_items'] as List;
        for (var item in orderItems) {
          _processNumericFields(item);
          if (item['menu_item'] != null) {
            _processNumericFields(item['menu_item']);
          }
        }
      }

      // Process store data
      if (order['store'] != null) {
        _processNumericFields(order['store']);
      }

      // Process driver data
      if (order['driver'] != null) {
        _processNumericFields(order['driver']);
        if (order['driver']['user'] != null) {
          _processNumericFields(order['driver']['user']);
        }
      }

      print('✅ OrderService: Order data processed successfully');
    } catch (e) {
      print('❌ OrderService: Error processing order data: $e');
    }
  }

  /// ✅ Convert string numeric values to proper numeric types
  static void _processNumericFields(Map<String, dynamic> data) {
    try {
      // List of fields that should be converted from String to double
      final doubleFields = [
        'total_amount',
        'total_price',
        'total',
        'subtotal',
        'delivery_fee',
        'service_fee',
        'price',
        'rating',
        'latitude',
        'longitude',
        'distance',
        'pickup_latitude',
        'pickup_longitude',
        'destination_latitude',
        'destination_longitude',
        'distance_km',
        'distance_meters',
        'base_fee'
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
        'review_count',
        'total_products',
        'estimated_duration',
        'duration_minutes'
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
      print('❌ OrderService: Error processing numeric fields: $e');
    }
  }

  /// ✅ Process statistics data with numeric conversion
  static void _processStatisticsData(Map<String, dynamic> statistics) {
    try {
      // Process main statistics
      _processNumericFields(statistics);

      // Process nested data if present
      if (statistics['daily_stats'] != null &&
          statistics['daily_stats'] is List) {
        final dailyStats = statistics['daily_stats'] as List;
        for (var stat in dailyStats) {
          if (stat is Map<String, dynamic>) {
            _processNumericFields(stat);
          }
        }
      }

      if (statistics['monthly_stats'] != null &&
          statistics['monthly_stats'] is List) {
        final monthlyStats = statistics['monthly_stats'] as List;
        for (var stat in monthlyStats) {
          if (stat is Map<String, dynamic>) {
            _processNumericFields(stat);
          }
        }
      }
    } catch (e) {
      print('❌ OrderService: Error processing statistics data: $e');
    }
  }

  /// ✅ Process tracking updates yang berupa JSON string
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
              // Process numeric fields in tracking updates
              for (var update in parsed) {
                if (update is Map<String, dynamic>) {
                  _processNumericFields(update);
                }
              }
            }
          } catch (e) {
            print('⚠️ Failed to parse tracking_updates JSON: $e');
            order['tracking_updates'] = [];
          }
        } else if (trackingUpdatesRaw is List) {
          // Already a List, process numeric fields
          for (var update in trackingUpdatesRaw) {
            if (update is Map<String, dynamic>) {
              _processNumericFields(update);
            }
          }
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
        order['store']['image_url'] =
            ImageService.getImageUrl(order['store']['image_url']);
      }

      // Process customer avatar
      if (order['customer'] != null && order['customer']['avatar'] != null) {
        order['customer']['avatar'] =
            ImageService.getImageUrl(order['customer']['avatar']);
      }

      // Process driver avatar (bisa di nested user atau langsung)
      if (order['driver'] != null) {
        if (order['driver']['user'] != null &&
            order['driver']['user']['avatar'] != null) {
          order['driver']['user']['avatar'] =
              ImageService.getImageUrl(order['driver']['user']['avatar']);
        } else if (order['driver']['avatar'] != null) {
          order['driver']['avatar'] =
              ImageService.getImageUrl(order['driver']['avatar']);
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
          if (item['menu_item'] != null &&
              item['menu_item']['image_url'] != null) {
            item['menu_item']['image_url'] =
                ImageService.getImageUrl(item['menu_item']['image_url']);
          }
        }
      }
    } catch (e) {
      print('❌ OrderService: Error processing order images: $e');
    }
  }
}
