// lib/services/order_service.dart
import 'package:flutter/foundation.dart';
import 'core/base_service.dart';
import 'image_service.dart';

class OrderService extends BaseService {

  // Place a new order
  static Future<Map<String, dynamic>> placeOrder(Map<String, dynamic> orderData) async {
    try {
      // Validate required fields
      if (!orderData.containsKey('store_id') || !orderData.containsKey('items')) {
        throw ApiException('store_id and items are required');
      }

      // Prepare request body
      final requestBody = {
        'store_id': orderData['store_id'],
        'items': _prepareOrderItems(orderData['items']),
      };

      // Add optional fields
      if (orderData['notes'] != null) {
        requestBody['notes'] = orderData['notes'];
      }
      if (orderData['delivery_address'] != null) {
        requestBody['delivery_address'] = orderData['delivery_address'];
      }

      final response = await BaseService.post('/orders', requestBody);

      if (response['data'] != null) {
        _processOrderData(response['data']);
      }

      return response['data'] ?? {};
    } catch (e) {
      debugPrint('Place order error: $e');
      rethrow;
    }
  }

  // Get all orders (with pagination and filtering)
  static Future<Map<String, dynamic>> getAllOrders({
    int page = 1,
    int limit = 10,
    String? status,
    String? userId,
    String? storeId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (status != null) queryParams['status'] = status;
      if (userId != null) queryParams['userId'] = userId;
      if (storeId != null) queryParams['storeId'] = storeId;
      if (startDate != null) queryParams['startDate'] = startDate.toIso8601String();
      if (endDate != null) queryParams['endDate'] = endDate.toIso8601String();

      final response = await BaseService.get('/orders', queryParams: queryParams);

      if (response['data'] != null) {
        _processOrdersList(response['data']);
      }

      return response;
    } catch (e) {
      debugPrint('Get all orders error: $e');
      rethrow;
    }
  }

  // Get order by ID
  static Future<Map<String, dynamic>> getOrderById(String orderId) async {
    try {
      final response = await BaseService.get('/orders/$orderId');

      if (response['data'] != null) {
        _processOrderData(response['data']);
      }

      return response['data'] ?? {};
    } catch (e) {
      debugPrint('Get order by ID error: $e');
      rethrow;
    }
  }

  // Update order status
  static Future<Map<String, dynamic>> updateOrderStatus(String orderId, String status) async {
    try {
      final validStatuses = ['pending', 'confirmed', 'preparing', 'ready', 'delivered', 'cancelled'];
      if (!validStatuses.contains(status)) {
        throw ApiException('Invalid order status');
      }

      final response = await BaseService.put('/orders/$orderId/status', {'status': status});

      if (response['data'] != null) {
        _processOrderData(response['data']);
      }

      return response['data'] ?? {};
    } catch (e) {
      debugPrint('Update order status error: $e');
      rethrow;
    }
  }

  // Cancel order
  static Future<Map<String, dynamic>> cancelOrder(String orderId, {String? reason}) async {
    try {
      final requestBody = <String, dynamic>{'status': 'cancelled'};
      if (reason != null) {
        requestBody['cancellation_reason'] = reason;
      }

      final response = await BaseService.put('/orders/$orderId/cancel', requestBody);

      if (response['data'] != null) {
        _processOrderData(response['data']);
      }

      return response['data'] ?? {};
    } catch (e) {
      debugPrint('Cancel order error: $e');
      rethrow;
    }
  }

  // Get user orders (customer's own orders)
  static Future<Map<String, dynamic>> getUserOrders({
    int page = 1,
    int limit = 10,
    String? status,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (status != null) queryParams['status'] = status;

      final response = await BaseService.get('/orders/user', queryParams: queryParams);

      if (response['data'] != null) {
        _processOrdersList(response['data']);
      }

      return response;
    } catch (e) {
      debugPrint('Get user orders error: $e');
      rethrow;
    }
  }

  // Get store orders (store owner's orders)
  static Future<Map<String, dynamic>> getStoreOrders({
    int page = 1,
    int limit = 10,
    String? status,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (status != null) queryParams['status'] = status;

      final response = await BaseService.get('/orders/store', queryParams: queryParams);

      if (response['data'] != null) {
        _processOrdersList(response['data']);
      }

      return response;
    } catch (e) {
      debugPrint('Get store orders error: $e');
      rethrow;
    }
  }

  // Assign driver to order
  static Future<Map<String, dynamic>> assignDriver(String orderId, String driverId) async {
    try {
      final response = await BaseService.put('/orders/$orderId/assign-driver', {'driver_id': driverId});

      if (response['data'] != null) {
        _processOrderData(response['data']);
      }

      return response['data'] ?? {};
    } catch (e) {
      debugPrint('Assign driver error: $e');
      rethrow;
    }
  }

  // Get order tracking information
  static Future<Map<String, dynamic>> getOrderTracking(String orderId) async {
    try {
      final response = await BaseService.get('/orders/$orderId/tracking');

      if (response['data'] != null) {
        _processTrackingData(response['data']);
      }

      return response['data'] ?? {};
    } catch (e) {
      debugPrint('Get order tracking error: $e');
      rethrow;
    }
  }

  // PRIVATE HELPER METHODS

  static List<Map<String, dynamic>> _prepareOrderItems(List<dynamic> items) {
    return items.map((item) => {
      'menu_item_id': item['menu_item_id'] ?? item['id'] ?? item['itemId'],
      'quantity': item['quantity'] ?? 1,
      'notes': item['notes'] ?? '',
    }).toList();
  }

  static void _processOrdersList(dynamic data) {
    try {
      List<dynamic> orders = [];

      if (data is List) {
        orders = data;
      } else if (data is Map) {
        if (data['orders'] is List) {
          orders = data['orders'];
        } else if (data['data'] is List) {
          orders = data['data'];
        }
      }

      for (var order in orders) {
        _processOrderData(order);
      }
    } catch (e) {
      debugPrint('Process orders list error: $e');
    }
  }

  static void _processOrderData(Map<String, dynamic> orderData) {
    try {
      // Process store images
      if (orderData['store'] != null) {
        if (orderData['store']['imageUrl'] != null) {
          orderData['store']['imageUrl'] = ImageService.getImageUrl(orderData['store']['imageUrl']);
        }
        if (orderData['store']['logoUrl'] != null) {
          orderData['store']['logoUrl'] = ImageService.getImageUrl(orderData['store']['logoUrl']);
        }
      }

      // Process menu item images
      if (orderData['items'] != null && orderData['items'] is List) {
        for (var item in orderData['items']) {
          if (item['menuItem'] != null && item['menuItem']['imageUrl'] != null) {
            item['menuItem']['imageUrl'] = ImageService.getImageUrl(item['menuItem']['imageUrl']);
          }
          if (item['menu_item'] != null && item['menu_item']['imageUrl'] != null) {
            item['menu_item']['imageUrl'] = ImageService.getImageUrl(item['menu_item']['imageUrl']);
          }
        }
      }

      // Process driver images
      if (orderData['driver'] != null) {
        if (orderData['driver']['user'] != null && orderData['driver']['user']['avatar'] != null) {
          orderData['driver']['user']['avatar'] = ImageService.getImageUrl(orderData['driver']['user']['avatar']);
        }
        if (orderData['driver']['profileImage'] != null) {
          orderData['driver']['profileImage'] = ImageService.getImageUrl(orderData['driver']['profileImage']);
        }
      }

      // Process customer avatar
      if (orderData['customer'] != null && orderData['customer']['avatar'] != null) {
        orderData['customer']['avatar'] = ImageService.getImageUrl(orderData['customer']['avatar']);
      }
    } catch (e) {
      debugPrint('Process order data error: $e');
    }
  }

  static void _processTrackingData(Map<String, dynamic> trackingData) {
    try {
      // Process driver image if present
      if (trackingData['driver'] != null) {
        if (trackingData['driver']['user'] != null && trackingData['driver']['user']['avatar'] != null) {
          trackingData['driver']['user']['avatar'] = ImageService.getImageUrl(trackingData['driver']['user']['avatar']);
        }
        if (trackingData['driver']['profileImage'] != null) {
          trackingData['driver']['profileImage'] = ImageService.getImageUrl(trackingData['driver']['profileImage']);
        }
      }
    } catch (e) {
      debugPrint('Process tracking data error: $e');
    }
  }
}