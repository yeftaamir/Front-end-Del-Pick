// lib/Services/order_service.dart
import 'dart:convert';
import 'dart:math' as math;
import 'core/base_service.dart';
import 'image_service.dart';
import 'auth_service.dart';

class OrderService {
  static const String _baseEndpoint = '/orders';
  static const bool _debugMode = false;

  // Optimized const field mappings for ultra-fast processing
  static const _doubleFields = {
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
  };

  static const _intFields = {
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
  };

  static const _imageFields = {
    'image_url': true,
    'avatar': true,
  };

  static void _log(String message) {
    if (_debugMode) print(message);
  }

  /// Place a new order - Ultra optimized
  static Future<Map<String, dynamic>> placeOrder({
    required String storeId,
    required List<Map<String, dynamic>> items,
    String? notes,
  }) async {
    try {
      // Parallel authentication validation
      final authResults = await Future.wait([
        AuthService.getUserData(),
        AuthService.getRoleSpecificData(),
        AuthService.getUserRole(),
      ]);

      final userData = authResults[0] as Map<String, dynamic>?;
      final roleData = authResults[1] as Map<String, dynamic>?;
      final userRole = authResults[2] as String?;

      if (userData == null || roleData == null) {
        throw Exception('Authentication required: Please login as customer');
      }

      if (userRole?.toLowerCase() != 'customer') {
        throw Exception('Access denied: Customer authentication required');
      }

      final customerData = await AuthService.getCustomerData();
      if (customerData == null) {
        throw Exception('Unable to retrieve customer data');
      }

      // Optimized body preparation
      final body = _createOrderBody(storeId, items, notes);

      final response = await BaseService.apiCall(
        method: 'POST',
        endpoint: _baseEndpoint,
        body: body,
        requiresAuth: true,
      );

      if (response['data'] != null) {
        _fastProcessOrderData(response['data']);
        _log('Order created successfully: ${response['data']['id']}');
        return response['data'];
      }

      throw Exception('Invalid response: No order data returned');
    } catch (e) {
      _log('Place order error: $e');
      throw _createOptimizedError(e);
    }
  }

  /// Get orders by user - Ultra optimized
  static Future<Map<String, dynamic>> getOrdersByUser({
    int page = 1,
    int limit = 10,
    String? status,
    String? sortBy,
    String? sortOrder,
  }) async {
    try {
      // Fast validation
      final isValid = await _fastValidateCustomer();
      if (!isValid) throw Exception('Authentication required: Please login');

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/customer',
        queryParams: _buildQueryParams(page, limit, status, sortBy, sortOrder),
        requiresAuth: true,
      );

      return _fastProcessOrdersResponse(response);
    } catch (e) {
      _log('Get orders by user error: $e');
      throw Exception('Failed to get user orders: $e');
    }
  }

  /// Get orders by store - Ultra optimized
  static Future<Map<String, dynamic>> getOrdersByStore({
    int page = 1,
    int limit = 10,
    String? status,
    String? sortBy,
    String? sortOrder,
    int? timestamp,
  }) async {
    try {
      // Fast store validation
      final isValid = await _fastValidateStore();
      if (!isValid)
        throw Exception('Access denied: Store authentication required');

      final queryParams =
          _buildQueryParams(page, limit, status, sortBy, sortOrder);
      if (timestamp != null) {
        queryParams['_t'] = timestamp.toString();
        _log('Force refresh with timestamp: $timestamp');
      }

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/store',
        queryParams: queryParams,
        requiresAuth: true,
      );

      return _fastProcessOrdersResponse(response);
    } catch (e) {
      _log('Get orders by store error: $e');
      throw Exception('Failed to get store orders: $e');
    }
  }

  /// Force refresh orders - Optimized
  static Future<Map<String, dynamic>> forceRefreshOrdersByStore({
    int page = 1,
    int limit = 10,
    String? status,
    String? sortBy,
    String? sortOrder,
  }) async {
    return getOrdersByStore(
      page: page,
      limit: limit,
      status: status,
      sortBy: sortBy,
      sortOrder: sortOrder,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Get order by ID - Ultra optimized
  static Future<Map<String, dynamic>> getOrderById(String orderId) async {
    try {
      final isValid = await _fastValidateAuth();
      if (!isValid) throw Exception('Authentication required');

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/$orderId',
        requiresAuth: true,
      );

      if (response['data'] != null) {
        _fastProcessOrderData(response['data']);
        _log('Order details retrieved successfully');
        return response['data'];
      }

      throw Exception('Order not found or invalid response');
    } catch (e) {
      _log('Get order by ID error: $e');
      throw Exception('Failed to get order: $e');
    }
  }

// GANTI getOrderByIdWithRefresh dengan smart refresh
  static Future<Map<String, dynamic>> getOrderByIdSmart(String orderId,
      {bool forceRefresh = false}) async {
    try {
      final isValid = await _fastValidateAuth();
      if (!isValid) throw Exception('Authentication required');

      final queryParams = <String, String>{};

      // ✅ Hanya force refresh jika diminta explicitly
      if (forceRefresh) {
        queryParams['_t'] = DateTime.now().millisecondsSinceEpoch.toString();
        queryParams['refresh'] = 'true';
        _log('🔄 Smart refresh: Force refresh requested');
      }

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/$orderId',
        queryParams: queryParams.isNotEmpty ? queryParams : null,
        requiresAuth: true,
      );

      if (response['data'] != null) {
        _fastProcessOrderData(response['data']);
        _log(
            'Order details retrieved ${forceRefresh ? 'with force refresh' : 'from cache'}');
        return response['data'];
      }

      throw Exception('Order not found or invalid response');
    } catch (e) {
      _log('Get order by ID smart error: $e');
      throw Exception('Failed to get order: $e');
    }
  }

  /// Process order by store - Optimized
  static Future<Map<String, dynamic>> processOrderByStore({
    required String orderId,
    required String action,
    String? rejectionReason,
  }) async {
    try {
      final isValid = await _fastValidateStore();
      if (!isValid)
        throw Exception('Access denied: Store authentication required');

      if (!{'approve', 'reject'}.contains(action.toLowerCase())) {
        throw Exception('Invalid action. Must be "approve" or "reject"');
      }

      final body = {
        'action': action.toLowerCase(),
        if (rejectionReason?.isNotEmpty == true)
          'rejection_reason': rejectionReason,
      };

      final response = await BaseService.apiCall(
        method: 'POST',
        endpoint: '$_baseEndpoint/$orderId/process',
        body: body,
        requiresAuth: true,
      );

      if (response['data'] != null) {
        _fastProcessOrderData(response['data']);
      }
      return response['data'] ?? {};
    } catch (e) {
      _log('Process order by store error: $e');
      throw Exception('Failed to process order: $e');
    }
  }

  /// Update order status - Ultra optimized
  static Future<Map<String, dynamic>> updateOrderStatus({
    required String orderId,
    required String orderStatus,
    String? deliveryStatus,
    String? notes,
  }) async {
    try {
      _log('🔄 OrderService: Updating order $orderId to $orderStatus');

      // ✅ PERBAIKAN: Comprehensive authentication validation
      final authResults = await Future.wait([
        AuthService.isAuthenticated(),
        AuthService.ensureValidUserData(),
        AuthService.getUserRole(),
        AuthService.getUserData(),
        AuthService.isSessionValid(),
      ]);

      final isAuthenticated = authResults[0] as bool;
      final hasValidSession = authResults[1] as bool;
      final userRole = authResults[2] as String?;
      final userData = authResults[3] as Map<String, dynamic>?;
      final sessionValid = authResults[4] as bool;

      if (!isAuthenticated ||
          !hasValidSession ||
          !sessionValid ||
          userData == null) {
        throw Exception('Session expired: Please login again');
      }

      if (userRole == null) {
        throw Exception('Invalid user role: Please login again');
      }

      _log('✅ OrderService: Authentication validated');
      _log('   - User ID: ${userData['id']}');
      _log('   - User Role: $userRole');
      _log('   - Session Valid: $sessionValid');

      // ✅ PERBAIKAN: Permission validation
      final hasPermission = await _fastCheckStatusPermission(orderStatus);
      if (!hasPermission) {
        throw Exception('Access denied: You cannot perform this action');
      }

      _log('✅ Permission validated for $userRole to set status: $orderStatus');

      // ✅ Request body sesuai backend expectation
      final body = <String, dynamic>{
        'order_status': orderStatus,
      };

      if (deliveryStatus != null) body['delivery_status'] = deliveryStatus;
      if (notes != null) body['notes'] = notes;

      _log('📤 Request body: $body');
      _log('📍 Endpoint: $_baseEndpoint/$orderId/status');

      final response = await BaseService.apiCall(
        method: 'PATCH',
        endpoint: '$_baseEndpoint/$orderId/status',
        body: body,
        requiresAuth: true,
      );

      _log('📥 Response received: ${response.keys.toList()}');

      if (response['data'] != null) {
        _fastProcessOrderData(response['data']);
        _log('✅ Order status updated successfully');
        return response['data'];
      }

      if (response['message'] != null) {
        _log('✅ Update successful with message: ${response['message']}');
        return {'success': true, 'message': response['message']};
      }

      return response;
    } catch (e) {
      _log('❌ Update order status error: $e');

      // ✅ Enhanced error handling
      final errorStr = e.toString().toLowerCase();

      if (errorStr.contains('401') || errorStr.contains('unauthorized')) {
        // Force logout on authentication error
        await AuthService.logout();
        throw Exception('Session expired: Please login again');
      } else if (errorStr.contains('403') ||
          errorStr.contains('forbidden') ||
          errorStr.contains('access denied')) {
        throw Exception('Access denied: You cannot perform this action');
      } else if (errorStr.contains('404') || errorStr.contains('not found')) {
        throw Exception('Order not found');
      } else if (errorStr.contains('400') || errorStr.contains('bad request')) {
        throw Exception('Invalid order status or request data');
      } else if (errorStr.contains('network') ||
          errorStr.contains('connection')) {
        throw Exception('Network error: Please check your internet connection');
      }

      rethrow;
    }
  }

  /// Cancel order by customer - Optimized
  static Future<Map<String, dynamic>> cancelOrderByCustomer({
    required String orderId,
    String? cancellationReason,
  }) async {
    try {
      _log('🚫 OrderService: Cancelling order $orderId by customer');

      // ✅ Enhanced authentication validation
      final authResults = await Future.wait([
        AuthService.isAuthenticated(),
        AuthService.ensureValidUserData(),
        AuthService.getUserRole(),
        AuthService.getUserData(),
      ]);

      final isAuthenticated = authResults[0] as bool;
      final hasValidSession = authResults[1] as bool;
      final userRole = authResults[2] as String?;
      final userData = authResults[3] as Map<String, dynamic>?;

      if (!isAuthenticated || !hasValidSession || userData == null) {
        throw Exception('Authentication required: Please login again');
      }

      if (userRole?.toLowerCase() != 'customer') {
        throw Exception('Access denied: Only customers can cancel orders');
      }

      _log('✅ Authentication validated for customer cancellation');
      _log('   - User ID: ${userData['id']}');
      _log('   - User Role: $userRole');

      // ✅ Directly use updateOrderStatus since /cancel endpoint might not exist
      return await updateOrderStatus(
        orderId: orderId,
        orderStatus: 'cancelled',
        notes: cancellationReason ?? 'Cancelled by customer',
      );
    } catch (e) {
      _log('❌ Cancel order by customer error: $e');
      rethrow;
    }
  }

  /// Create review - Ultra optimized
  static Future<Map<String, dynamic>> createReview({
    required String orderId,
    required Map<String, dynamic> orderReview,
    required Map<String, dynamic> driverReview,
  }) async {
    try {
      // Fast customer validation
      final isValid = await _fastValidateCustomer();
      if (!isValid)
        throw Exception('Access denied: Only customers can create reviews');

      // Fast review validation and cleaning
      final cleanedBody = _fastCleanReviewData(orderReview, driverReview);

      final response = await BaseService.apiCall(
        method: 'POST',
        endpoint: '$_baseEndpoint/$orderId/review',
        body: cleanedBody,
        requiresAuth: true,
      );

      if (response['data'] != null) {
        _fastProcessOrderData(response['data']);
        return response['data'];
      }

      return {'success': true, 'message': 'Review submitted successfully'};
    } catch (e) {
      _log('Create review error: $e');
      throw _createReviewError(e);
    }
  }

  /// Calculate delivery fee - Ultra optimized
  static Future<Map<String, dynamic>> calculateDeliveryFee({
    required String storeId,
    required double destinationLatitude,
    required double destinationLongitude,
  }) async {
    try {
      final isValid = await _fastValidateAuth();
      if (!isValid) throw Exception('Authentication required');

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/calculate-delivery-fee',
        queryParams: {
          'store_id': storeId,
          'destination_latitude': destinationLatitude.toString(),
          'destination_longitude': destinationLongitude.toString(),
        },
        requiresAuth: true,
      );

      if (response['data'] != null) {
        final data = response['data'];
        _fastProcessNumericFields(data);

        // Fast delivery fee calculation
        final distance = (data['distance_km'] as double?) ?? 0.0;
        final baseFee = distance * 2500;
        final roundedFee = _fastRoundUpToThousand(baseFee);

        data.addAll({
          'delivery_fee': roundedFee,
          'base_fee': baseFee,
          'distance_km': distance,
        });

        _log(
            'Delivery fee: Distance ${distance.toStringAsFixed(2)}km, Fee Rp${roundedFee.toStringAsFixed(0)}');
      }

      return response['data'] ?? {};
    } catch (e) {
      _log('Calculate delivery fee error: $e');
      return {'delivery_fee': 5000.0, 'distance_km': 2.0, 'base_fee': 5000.0};
    }
  }

  /// Get order statistics - Optimized
  static Future<Map<String, dynamic>> getOrderStatistics({
    DateTime? startDate,
    DateTime? endDate,
    String? groupBy,
  }) async {
    try {
      final isValid = await _fastValidateStoreOrAdmin();
      if (!isValid)
        throw Exception(
            'Access denied: Only store or admin can view statistics');

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

      if (response['data'] != null) {
        _fastProcessStatisticsData(response['data']);
      }

      return response['data'] ?? {};
    } catch (e) {
      _log('Get order statistics error: $e');
      return {};
    }
  }

  // ULTRA-OPTIMIZED PRIVATE HELPER METHODS

  /// Ultra-fast order data processing
  static void _fastProcessOrderData(Map<String, dynamic> order) {
    // Single-pass processing untuk semua data
    _fastProcessNumericFields(order);
    _fastProcessTrackingUpdates(order);
    _fastProcessAllImages(order);
    _fastProcessNestedItems(order);
    _fastProcessNestedEntities(order);
  }

  /// Lightning-fast numeric field processing
  static void _fastProcessNumericFields(Map<String, dynamic> data) {
    // Ultra-optimized dengan direct field access
    for (final field in _doubleFields) {
      final value = data[field];
      if (value != null) {
        if (value is String) {
          data[field] = double.tryParse(value) ?? 0.0;
        } else if (value is int) {
          data[field] = value.toDouble();
        }
      }
    }

    for (final field in _intFields) {
      final value = data[field];
      if (value != null) {
        if (value is String) {
          data[field] = int.tryParse(value) ?? 0;
        } else if (value is double) {
          data[field] = value.toInt();
        }
      }
    }
  }

  /// Ultra-fast tracking updates processing
  static void _fastProcessTrackingUpdates(Map<String, dynamic> order) {
    final trackingUpdates = order['tracking_updates'];
    if (trackingUpdates is String) {
      try {
        final parsed = jsonDecode(trackingUpdates);
        if (parsed is List) {
          // Batch process all updates
          for (var update in parsed) {
            if (update is Map<String, dynamic>) {
              _fastProcessNumericFields(update);
            }
          }
          order['tracking_updates'] = parsed;
        }
      } catch (e) {
        order['tracking_updates'] = [];
      }
    } else if (trackingUpdates is List) {
      // Direct processing
      for (var update in trackingUpdates) {
        if (update is Map<String, dynamic>) {
          _fastProcessNumericFields(update);
        }
      }
    } else {
      order['tracking_updates'] = [];
    }
  }

  /// Ultra-fast image processing untuk semua entities
  static void _fastProcessAllImages(Map<String, dynamic> order) {
    // Batch process store images
    final store = order['store'];
    if (store is Map<String, dynamic>) {
      _fastProcessEntityImages(store);
    }

    // Batch process customer images
    final customer = order['customer'];
    if (customer is Map<String, dynamic>) {
      _fastProcessEntityImages(customer);
    }

    // Batch process driver images
    final driver = order['driver'];
    if (driver is Map<String, dynamic>) {
      _fastProcessEntityImages(driver);
      final driverUser = driver['user'];
      if (driverUser is Map<String, dynamic>) {
        _fastProcessEntityImages(driverUser);
      }
    }
  }

  /// Ultra-fast entity image processing
  static void _fastProcessEntityImages(Map<String, dynamic> entity) {
    for (final field in _imageFields.keys) {
      final imageUrl = entity[field];
      if (imageUrl != null && imageUrl.toString().isNotEmpty) {
        entity[field] = ImageService.getImageUrl(imageUrl.toString());
      }
    }
  }

  /// Ultra-fast nested items processing
  static void _fastProcessNestedItems(Map<String, dynamic> order) {
    // Process items array
    final items = order['items'];
    if (items is List) {
      for (var item in items) {
        if (item is Map<String, dynamic>) {
          _fastProcessNumericFields(item);
          _fastProcessEntityImages(item);
        }
      }
    }

    // Process order_items array
    final orderItems = order['order_items'];
    if (orderItems is List) {
      for (var item in orderItems) {
        if (item is Map<String, dynamic>) {
          _fastProcessNumericFields(item);
          _fastProcessEntityImages(item);
          final menuItem = item['menu_item'];
          if (menuItem is Map<String, dynamic>) {
            _fastProcessNumericFields(menuItem);
            _fastProcessEntityImages(menuItem);
          }
        }
      }
    }
  }

  /// Ultra-fast nested entities processing
  static void _fastProcessNestedEntities(Map<String, dynamic> order) {
    final entities = ['store', 'driver'];
    for (final entityKey in entities) {
      final entity = order[entityKey];
      if (entity is Map<String, dynamic>) {
        _fastProcessNumericFields(entity);
      }
    }
  }

  /// Lightning-fast statistics processing
  static void _fastProcessStatisticsData(Map<String, dynamic> statistics) {
    _fastProcessNumericFields(statistics);

    // Process nested arrays in parallel concept
    const nestedArrays = ['daily_stats', 'monthly_stats'];
    for (final arrayKey in nestedArrays) {
      final array = statistics[arrayKey];
      if (array is List) {
        for (var stat in array) {
          if (stat is Map<String, dynamic>) {
            _fastProcessNumericFields(stat);
          }
        }
      }
    }
  }

  /// Ultra-fast orders response processing
  static Map<String, dynamic> _fastProcessOrdersResponse(
      Map<String, dynamic> response) {
    if (response['data'] != null && response['data']['orders'] != null) {
      final orders = response['data']['orders'] as List;
      for (var order in orders) {
        _fastProcessOrderData(order);
      }
      _log('Retrieved ${orders.length} orders');
    }

    return response['data'] ??
        {
          'orders': [],
          'totalItems': 0,
          'totalPages': 0,
          'currentPage': 1,
        };
  }

  /// Ultra-fast query params builder
  static Map<String, String> _buildQueryParams(
      int page, int limit, String? status, String? sortBy, String? sortOrder) {
    final params = {
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (status != null) params['status'] = status;
    if (sortBy != null) params['sortBy'] = sortBy;
    if (sortOrder != null) params['sortOrder'] = sortOrder;

    return params;
  }

  /// Ultra-fast order body creation
  static Map<String, dynamic> _createOrderBody(
      String storeId, List<Map<String, dynamic>> items, String? notes) {
    final body = {
      'store_id': int.parse(storeId),
      'items': items
          .map((item) => {
                'menu_item_id':
                    item['id'] ?? item['menu_item_id'] ?? item['itemId'],
                'quantity': item['quantity'] ?? 1,
                'notes': item['notes'] ?? '',
              })
          .toList(),
    };
    return body;
  }

  /// Lightning-fast review data cleaning
  static Map<String, dynamic> _fastCleanReviewData(
      Map<String, dynamic> orderReview, Map<String, dynamic> driverReview) {
    final orderRating = orderReview['rating'];
    final driverRating = driverReview['rating'];

    // Fast validation
    if ((orderRating == null || orderRating <= 0) &&
        (driverRating == null || driverRating <= 0)) {
      throw Exception('At least one rating (store or driver) must be provided');
    }

    final body = <String, dynamic>{};

    // Fast order review processing
    if (orderRating != null && orderRating > 0 && orderRating <= 5) {
      final cleanOrderReview = {'rating': orderRating};
      final orderComment = orderReview['comment']?.toString().trim();
      if (orderComment?.isNotEmpty == true) {
        cleanOrderReview['comment'] = orderComment;
      }
      body['order_review'] = cleanOrderReview;
    }

    // Fast driver review processing
    if (driverRating != null && driverRating > 0 && driverRating <= 5) {
      final cleanDriverReview = {'rating': driverRating};
      final driverComment = driverReview['comment']?.toString().trim();
      if (driverComment?.isNotEmpty == true) {
        cleanDriverReview['comment'] = driverComment;
      }
      body['driver_review'] = cleanDriverReview;
    }

    if (body.isEmpty) {
      throw Exception('No valid reviews to submit');
    }

    return body;
  }

  /// Ultra-fast validation methods
  static Future<bool> _fastValidateAuth() async {
    return AuthService.isAuthenticated();
  }

  static Future<bool> _fastValidateCustomer() async {
    final results = await Future.wait([
      AuthService.isAuthenticated(),
      AuthService.getUserRole(),
    ]);
    return results[0] as bool &&
        (results[1] as String?)?.toLowerCase() == 'customer';
  }

  static Future<bool> _fastValidateStore() async {
    final results = await Future.wait([
      AuthService.isAuthenticated(),
      AuthService.hasRole('store'),
    ]);
    return results[0] as bool && results[1] as bool;
  }

  static Future<bool> _fastValidateStoreOrAdmin() async {
    final userRole = await AuthService.getUserRole();
    return {'store', 'admin'}.contains(userRole?.toLowerCase());
  }

  static Future<bool> _fastCheckStatusPermission(String orderStatus) async {
    try {
      final userRole = await AuthService.getUserRole();
      _log('🔍 Checking permission: role=$userRole, status=$orderStatus');

      // ✅ PERBAIKAN: Customer permissions
      if (userRole?.toLowerCase() == 'customer') {
        // Customer hanya bisa cancel order (set status to 'cancelled')
        return orderStatus.toLowerCase() == 'cancelled';
      }

      // Store bisa update order_status sesuai alur:
      if (userRole?.toLowerCase() == 'store') {
        final allowedStatuses = [
          'preparing', // approve order
          'ready_for_pickup', // ready to pickup
          'rejected', // reject order
          'cancelled' // cancel order if needed
        ];
        return allowedStatuses.contains(orderStatus.toLowerCase());
      }

      // Driver bisa update delivery-related status
      if (userRole?.toLowerCase() == 'driver') {
        return true; // Let backend validate specific driver permissions
      }

      _log('❌ Permission denied for role: $userRole');
      return false;
    } catch (e) {
      _log('❌ Permission check error: $e');
      return false;
    }
  }

  /// Ultra-fast utility methods
  static double _fastRoundUpToThousand(double amount) {
    return amount <= 1000 ? 1000.0 : (amount / 1000).ceil() * 1000.0;
  }

  static Exception _createOptimizedError(dynamic e) {
    final errorStr = e.toString();
    if (errorStr.contains('authentication') ||
        errorStr.contains('Access denied')) {
      return Exception('Authentication required. Please login as customer.');
    } else if (errorStr.contains('validation')) {
      return Exception(
          'Order validation failed. Please check your order details.');
    } else if (errorStr.contains('network') ||
        errorStr.contains('connection')) {
      return Exception('Network error. Please check your internet connection.');
    } else {
      return Exception('Failed to place order: $errorStr');
    }
  }

  static Exception _createReviewError(dynamic e) {
    final errorStr = e.toString();
    if (errorStr.contains('authentication') ||
        errorStr.contains('Access denied')) {
      return Exception('Authentication required. Please login as customer.');
    } else if (errorStr.contains('rating must be between')) {
      return Exception(
          'Invalid rating. Please provide ratings between 1-5 stars.');
    } else if (errorStr.contains('At least one rating')) {
      return Exception('Please provide at least one rating (store or driver).');
    } else if (errorStr.contains('Bad request')) {
      return Exception(
          'Invalid review data. Please check your ratings and try again.');
    } else if (errorStr.contains('network') ||
        errorStr.contains('connection')) {
      return Exception('Network error. Please check your internet connection.');
    } else {
      return Exception('Failed to submit review');
    }
  }
}
