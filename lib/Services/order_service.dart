// lib/Services/order_service.dart
import 'dart:convert';
import 'dart:math' as math;
import 'core/base_service.dart';
import 'image_service.dart';
import 'auth_service.dart';

class OrderService {
  static const String _baseEndpoint = '/orders';
  static const bool _debugMode = false; // Toggle for development debugging

  static void _log(String message) {
    if (_debugMode) print(message);
  }

  /// Place a new order (customer only) - Optimized version
  static Future<Map<String, dynamic>> placeOrder({
    required String storeId,
    required List<Map<String, dynamic>> items,
    String? notes,
  }) async {
    try {
      // Enhanced authentication validation
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

      // Prepare order body
      final body = {
        'store_id': int.parse(storeId),
        'items': items
            .map((item) => {
          'menu_item_id': item['id'] ??
              item['menu_item_id'] ??
              item['itemId'],
          'quantity': item['quantity'] ?? 1,
          'notes': item['notes'] ?? '',
        })
            .toList(),
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      };

      // Make API call
      final response = await BaseService.apiCall(
        method: 'POST',
        endpoint: _baseEndpoint,
        body: body,
        requiresAuth: true,
      );

      if (response['data'] != null) {
        _processOrderData(response['data']);
        return response['data'];
      }

      throw Exception('Invalid response: No order data returned');
    } catch (e) {
      // Enhanced error handling with specific messages
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

  /// Get orders by user (customer)
  static Future<Map<String, dynamic>> getOrdersByUser({
    int page = 1,
    int limit = 10,
    String? status,
    String? sortBy,
    String? sortOrder,
  }) async {
    try {
      // Enhanced validation
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

      // Process response
      if (response['data'] != null && response['data']['orders'] != null) {
        final orders = response['data']['orders'] as List;
        for (var order in orders) {
          _processOrderData(order);
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
    int? timestamp,
  }) async {
    try {
      // Enhanced validation
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

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/store',
        queryParams: queryParams,
        requiresAuth: true,
      );

      // Process response
      if (response['data'] != null && response['data']['orders'] != null) {
        final orders = response['data']['orders'] as List;
        for (var order in orders) {
          _processOrderData(order);
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
      throw Exception('Failed to get store orders: $e');
    }
  }

  /// Force refresh orders by store
  static Future<Map<String, dynamic>> forceRefreshOrdersByStore({
    int page = 1,
    int limit = 10,
    String? status,
    String? sortBy,
    String? sortOrder,
  }) async {
    return await getOrdersByStore(
      page: page,
      limit: limit,
      status: status,
      sortBy: sortBy,
      sortOrder: sortOrder,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Get order by ID
  static Future<Map<String, dynamic>> getOrderById(String orderId) async {
    try {
      // Enhanced validation
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
        _processOrderData(response['data']);
        return response['data'];
      }

      throw Exception('Order not found or invalid response');
    } catch (e) {
      throw Exception('Failed to get order: $e');
    }
  }

  /// Process order by store (approve/reject)
  static Future<Map<String, dynamic>> processOrderByStore({
    required String orderId,
    required String action,
    String? rejectionReason,
  }) async {
    try {
      // Enhanced validation
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
        method: 'POST',
        endpoint: '$_baseEndpoint/$orderId/process',
        body: body,
        requiresAuth: true,
      );

      if (response['data'] != null) {
        _processOrderData(response['data']);
      }
      return response['data'] ?? {};
    } catch (e) {
      throw Exception('Failed to process order: $e');
    }
  }

  /// Update order status with customer cancellation permission
  static Future<Map<String, dynamic>> updateOrderStatus({
    required String orderId,
    required String orderStatus,
    String? deliveryStatus,
    String? notes,
  }) async {
    try {
      // Enhanced validation
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

      // Check permissions
      bool hasPermission = false;

      if (['store', 'driver', 'admin'].contains(userRole.toLowerCase())) {
        hasPermission = true;
      } else if (userRole.toLowerCase() == 'customer' &&
          orderStatus.toLowerCase() == 'cancelled') {
        hasPermission = true;
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

      if (response['data'] != null) {
        _processOrderData(response['data']);
      }
      return response['data'] ?? {};
    } catch (e) {
      throw Exception('Failed to update order status: $e');
    }
  }

  /// Cancel order specifically for customers
  static Future<Map<String, dynamic>> cancelOrderByCustomer({
    required String orderId,
    String? cancellationReason,
  }) async {
    try {
      // Enhanced validation
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

      if (response['data'] != null) {
        _processOrderData(response['data']);
      }
      return response['data'] ?? {};
    } catch (e) {
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

  /// Create review for completed order
  static Future<Map<String, dynamic>> createReview({
    required String orderId,
    required Map<String, dynamic> orderReview,
    required Map<String, dynamic> driverReview,
  }) async {
    try {
      // Enhanced validation
      final userData = await AuthService.getUserData();
      final roleData = await AuthService.getRoleSpecificData();

      if (userData == null) {
        throw Exception('Authentication required: Please login');
      }

      if (roleData == null) {
        throw Exception('Role data not found: Please login as customer');
      }

      // Validate customer access
      final userRole = await AuthService.getUserRole();
      if (userRole?.toLowerCase() != 'customer') {
        throw Exception('Access denied: Only customers can create reviews');
      }

      final hasAccess = await AuthService.validateCustomerAccess();
      if (!hasAccess) {
        throw Exception('Access denied: Customer authentication required');
      }

      // Validate review data
      final orderRating = orderReview['rating'];
      final driverRating = driverReview['rating'];

      if (orderRating != null && (orderRating < 1 || orderRating > 5)) {
        throw Exception('Order rating must be between 1 and 5');
      }

      if (driverRating != null && (driverRating < 1 || driverRating > 5)) {
        throw Exception('Driver rating must be between 1 and 5');
      }

      // Ensure at least one rating is provided
      if ((orderRating == null || orderRating <= 0) &&
          (driverRating == null || driverRating <= 0)) {
        throw Exception('At least one rating (store or driver) must be provided');
      }

      // Clean the review data
      final cleanOrderReview = <String, dynamic>{};
      final cleanDriverReview = <String, dynamic>{};

      // Order review
      if (orderRating != null && orderRating > 0) {
        cleanOrderReview['rating'] = orderRating;
        final orderComment = orderReview['comment']?.toString().trim();
        if (orderComment != null && orderComment.isNotEmpty) {
          cleanOrderReview['comment'] = orderComment;
        }
      }

      // Driver review
      if (driverRating != null && driverRating > 0) {
        cleanDriverReview['rating'] = driverRating;
        final driverComment = driverReview['comment']?.toString().trim();
        if (driverComment != null && driverComment.isNotEmpty) {
          cleanDriverReview['comment'] = driverComment;
        }
      }

      final body = <String, dynamic>{};

      if (cleanOrderReview.isNotEmpty) {
        body['order_review'] = cleanOrderReview;
      }

      if (cleanDriverReview.isNotEmpty) {
        body['driver_review'] = cleanDriverReview;
      }

      if (body.isEmpty) {
        throw Exception('No valid reviews to submit');
      }

      final response = await BaseService.apiCall(
        method: 'POST',
        endpoint: '$_baseEndpoint/$orderId/review',
        body: body,
        requiresAuth: true,
      );

      if (response['data'] != null) {
        _processOrderData(response['data']);
        return response['data'];
      }

      return {'success': true, 'message': 'Review submitted successfully'};

    } catch (e) {
      // Enhanced error handling
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

  /// Calculate delivery fee using distance * 2500 and round up
  static Future<Map<String, dynamic>> calculateDeliveryFee({
    required String storeId,
    required double destinationLatitude,
    required double destinationLongitude,
  }) async {
    try {
      // Enhanced validation
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

      // Process numeric fields
      if (response['data'] != null) {
        _processNumericFields(response['data']);

        // Apply custom delivery fee calculation
        final data = response['data'];
        final distance = (data['distance_km'] as double?) ?? 0.0;

        // Calculate delivery fee: distance * 2500, rounded up to nearest 1000
        final baseFee = distance * 2500;
        final roundedFee = _roundUpToNearestThousand(baseFee);

        data['delivery_fee'] = roundedFee;
        data['base_fee'] = baseFee;
        data['distance_km'] = distance;

        _log('Custom delivery fee calculation: Distance: ${distance.toStringAsFixed(2)} km, Base fee: Rp ${baseFee.toStringAsFixed(0)}, Rounded fee: Rp ${roundedFee.toStringAsFixed(0)}');
      }

      return response['data'] ?? {};
    } catch (e) {
      // Fallback with default distance calculation
      return {
        'delivery_fee': 5000.0,
        'distance_km': 2.0,
        'base_fee': 5000.0,
      };
    }
  }

  /// Round up to nearest 1000
  static double _roundUpToNearestThousand(double amount) {
    if (amount <= 1000) {
      return 1000.0;
    }
    return (amount / 1000).ceil() * 1000.0;
  }

  /// Get order statistics
  static Future<Map<String, dynamic>> getOrderStatistics({
    DateTime? startDate,
    DateTime? endDate,
    String? groupBy,
  }) async {
    try {
      // Enhanced validation
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

      // Process numeric fields in statistics
      if (response['data'] != null) {
        _processStatisticsData(response['data']);
      }

      return response['data'] ?? {};
    } catch (e) {
      return {};
    }
  }

  // PRIVATE HELPER METHODS - OPTIMIZED

  /// Comprehensive order data processing (optimized)
  static void _processOrderData(Map<String, dynamic> order) {
    try {
      // Process numeric fields
      _processNumericFields(order);

      // Process tracking updates
      _processTrackingUpdates(order);

      // Process images
      _processOrderImages(order);

      // Process nested order items
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
    } catch (e) {
      _log('Error processing order data: $e');
    }
  }

  /// Convert string numeric values to proper numeric types (optimized)
  static void _processNumericFields(Map<String, dynamic> data) {
    try {
      // Optimized field lists - grouped for better performance
      const doubleFields = [
        'total_amount', 'total_price', 'total', 'subtotal', 'delivery_fee',
        'service_fee', 'price', 'rating', 'latitude', 'longitude', 'distance',
        'pickup_latitude', 'pickup_longitude', 'destination_latitude',
        'destination_longitude', 'distance_km', 'distance_meters', 'base_fee'
      ];

      const intFields = [
        'id', 'customer_id', 'driver_id', 'store_id', 'menu_item_id',
        'quantity', 'reviews_count', 'review_count', 'total_products',
        'estimated_duration', 'duration_minutes'
      ];

      // Batch convert double fields
      for (final field in doubleFields) {
        final value = data[field];
        if (value != null) {
          if (value is String) {
            data[field] = double.tryParse(value) ?? 0.0;
          } else if (value is int) {
            data[field] = value.toDouble();
          }
        }
      }

      // Batch convert int fields
      for (final field in intFields) {
        final value = data[field];
        if (value != null) {
          if (value is String) {
            data[field] = int.tryParse(value) ?? 0;
          } else if (value is double) {
            data[field] = value.toInt();
          }
        }
      }
    } catch (e) {
      _log('Error processing numeric fields: $e');
    }
  }

  /// Process statistics data (optimized)
  static void _processStatisticsData(Map<String, dynamic> statistics) {
    try {
      _processNumericFields(statistics);

      // Process nested arrays efficiently
      final nestedArrays = ['daily_stats', 'monthly_stats'];
      for (final arrayKey in nestedArrays) {
        final array = statistics[arrayKey];
        if (array is List) {
          for (var stat in array) {
            if (stat is Map<String, dynamic>) {
              _processNumericFields(stat);
            }
          }
        }
      }
    } catch (e) {
      _log('Error processing statistics data: $e');
    }
  }

  /// Process tracking updates (optimized)
  static void _processTrackingUpdates(Map<String, dynamic> order) {
    try {
      final trackingUpdatesRaw = order['tracking_updates'];

      if (trackingUpdatesRaw is String) {
        try {
          final parsed = jsonDecode(trackingUpdatesRaw);
          if (parsed is List) {
            // Process all updates in batch
            for (var update in parsed) {
              if (update is Map<String, dynamic>) {
                _processNumericFields(update);
              }
            }
            order['tracking_updates'] = parsed;
          }
        } catch (e) {
          order['tracking_updates'] = [];
        }
      } else if (trackingUpdatesRaw is List) {
        // Process existing list
        for (var update in trackingUpdatesRaw) {
          if (update is Map<String, dynamic>) {
            _processNumericFields(update);
          }
        }
        order['tracking_updates'] = trackingUpdatesRaw;
      } else {
        order['tracking_updates'] = [];
      }
    } catch (e) {
      order['tracking_updates'] = [];
    }
  }

  /// Process images in order data (optimized)
  static void _processOrderImages(Map<String, dynamic> order) {
    try {
      // Process store image
      final store = order['store'];
      if (store is Map<String, dynamic> && store['image_url'] != null) {
        store['image_url'] = ImageService.getImageUrl(store['image_url']);
      }

      // Process customer avatar
      final customer = order['customer'];
      if (customer is Map<String, dynamic> && customer['avatar'] != null) {
        customer['avatar'] = ImageService.getImageUrl(customer['avatar']);
      }

      // Process driver avatar
      final driver = order['driver'];
      if (driver is Map<String, dynamic>) {
        final driverUser = driver['user'];
        if (driverUser is Map<String, dynamic> && driverUser['avatar'] != null) {
          driverUser['avatar'] = ImageService.getImageUrl(driverUser['avatar']);
        } else if (driver['avatar'] != null) {
          driver['avatar'] = ImageService.getImageUrl(driver['avatar']);
        }
      }

      // Process order items images efficiently
      final itemsArrays = ['items', 'order_items'];
      for (final arrayKey in itemsArrays) {
        final items = order[arrayKey];
        if (items is List) {
          for (var item in items) {
            if (item is Map<String, dynamic>) {
              if (item['image_url'] != null) {
                item['image_url'] = ImageService.getImageUrl(item['image_url']);
              }
              final menuItem = item['menu_item'];
              if (menuItem is Map<String, dynamic> && menuItem['image_url'] != null) {
                menuItem['image_url'] = ImageService.getImageUrl(menuItem['image_url']);
              }
            }
          }
        }
      }
    } catch (e) {
      _log('Error processing order images: $e');
    }
  }
}