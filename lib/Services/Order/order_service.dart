// lib/services/order/order_service.dart
import '../../Models/Base/api_response.dart';
import '../../Models/Entities/order.dart';
import '../../Models/Enums/order_status.dart';
import '../../Models/Requests/order_requests.dart';
import '../../Models/Utils/model_utils.dart';
import '../Base/api_client.dart';

class OrderService {
  static const String _baseEndpoint = '/orders';

  // Place Order
  static Future<ApiResponse<Order>> placeOrder(CreateOrderRequest request) async {
    return await ApiClient.post<Order>(
      _baseEndpoint,
      body: request.toJson(),
      fromJsonT: (data) => Order.fromJson(data),
    );
  }

  // Get Orders by User (Customers)
  static Future<ApiResponse<List<Order>>> getOrdersByUser({
    int page = 1,
    int limit = 10,
    OrderStatus? status,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (status != null) {
      queryParams['status'] = status.value;
    }

    return await ApiClient.get<List<Order>>(
      '$_baseEndpoint/customer',
      queryParams: queryParams,
      fromJsonT: (data) {
        if (data is Map<String, dynamic> && data.containsKey('orders')) {
          return ModelUtils.parseList(data['orders'], (json) => Order.fromJson(json));
        } else if (data is List) {
          return ModelUtils.parseList(data, (json) => Order.fromJson(json));
        }
        return <Order>[];
      },
    );
  }

  // Get Orders by Store (Store Owner)
  static Future<ApiResponse<List<Order>>> getOrdersByStore({
    int page = 1,
    int limit = 10,
    OrderStatus? status,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (status != null) {
      queryParams['status'] = status.value;
    }

    return await ApiClient.get<List<Order>>(
      '$_baseEndpoint/store',
      queryParams: queryParams,
      fromJsonT: (data) {
        if (data is Map<String, dynamic> && data.containsKey('orders')) {
          return ModelUtils.parseList(data['orders'], (json) => Order.fromJson(json));
        } else if (data is List) {
          return ModelUtils.parseList(data, (json) => Order.fromJson(json));
        }
        return <Order>[];
      },
    );
  }

  // Get Order by ID
  static Future<ApiResponse<Order>> getOrderById(int orderId) async {
    return await ApiClient.get<Order>(
      '$_baseEndpoint/$orderId',
      fromJsonT: (data) => Order.fromJson(data),
    );
  }

  // Update Order Status (Store Owner)
  static Future<ApiResponse<Order>> updateOrderStatus(
      int orderId,
      OrderStatus status,
      ) async {
    return await ApiClient.patch<Order>(
      '$_baseEndpoint/$orderId/status',
      body: {'order_status': status.value},
      fromJsonT: (data) => Order.fromJson(data),
    );
  }

  // Process Order by Store (Accept/Reject)
  static Future<ApiResponse<Order>> processOrderByStore(
      int orderId,
      String action, // 'approve' or 'reject'
      ) async {
    return await ApiClient.post<Order>(
      '$_baseEndpoint/$orderId/process',
      body: {'action': action},
      fromJsonT: (data) => Order.fromJson(data),
    );
  }

  // Cancel Order
  static Future<ApiResponse<Order>> cancelOrder(int orderId) async {
    return await ApiClient.patch<Order>(
      '$_baseEndpoint/$orderId/cancel',
      fromJsonT: (data) => Order.fromJson(data),
    );
  }

  // Create Review
  static Future<ApiResponse<Map<String, dynamic>>> createReview(
      int orderId,
      Map<String, dynamic> reviewData,
      ) async {
    return await ApiClient.post<Map<String, dynamic>>(
      '$_baseEndpoint/$orderId/review',
      body: reviewData,
      fromJsonT: (data) => data as Map<String, dynamic>,
    );
  }

  // Get Order History
  static Future<ApiResponse<List<Order>>> getOrderHistory({
    int page = 1,
    int limit = 10,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (startDate != null) {
      queryParams['startDate'] = startDate.toIso8601String();
    }

    if (endDate != null) {
      queryParams['endDate'] = endDate.toIso8601String();
    }

    return await ApiClient.get<List<Order>>(
      '$_baseEndpoint/history',
      queryParams: queryParams,
      fromJsonT: (data) => ModelUtils.parseList(data, (json) => Order.fromJson(json)),
    );
  }
}