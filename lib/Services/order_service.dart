// lib/services/order_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'core/api_constants.dart';
import 'core/token_service.dart';
import 'image_service.dart';

class OrderService {
  // Place a new order
  static Future<Map<String, dynamic>> placeOrder(Map<String, dynamic> orderData) async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/orders'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(orderData),
      );

      if (response.statusCode == 201) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        return jsonData['data'];
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Order placement failed');
      }
    } catch (e) {
      print('Error placing order: $e');
      throw Exception('Failed to place order: $e');
    }
  }

  // Get order details by order ID
  static Future<Map<String, dynamic>> getOrderById(String orderId) async {
    try {
      final String? token = await TokenService.getToken();
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

        // Process images in order data
        if (jsonData['data'] != null) {
          // Process store image if present
          if (jsonData['data']['store'] != null && jsonData['data']['store']['image'] != null) {
            jsonData['data']['store']['image'] = ImageService.getImageUrl(jsonData['data']['store']['image']);
          }

          // Process images in order items if present
          if (jsonData['data']['items'] != null && jsonData['data']['items'] is List) {
            for (var item in jsonData['data']['items']) {
              if (item['imageUrl'] != null) {
                item['imageUrl'] = ImageService.getImageUrl(item['imageUrl']);
              }
            }
          }
        }

        return jsonData['data'];
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to load order');
      }
    } catch (e) {
      print('Error fetching order: $e');
      throw Exception('Failed to load order: $e');
    }
  }

  // Get all orders for the logged-in customer
  static Future<Map<String, dynamic>> getCustomerOrders() async {
    try {
      final String? token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/orders/user'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);

        // Process images in order data
        if (jsonData['data'] != null && jsonData['data']['orders'] is List) {
          for (var order in jsonData['data']['orders']) {
            // Process store image if present
            if (order['store'] != null && order['store']['image'] != null) {
              order['store']['image'] = ImageService.getImageUrl(order['store']['image']);
            }

            // Process images in order items if present
            if (order['items'] != null && order['items'] is List) {
              for (var item in order['items']) {
                if (item['imageUrl'] != null) {
                  item['imageUrl'] = ImageService.getImageUrl(item['imageUrl']);
                }
              }
            }
          }
        }

        return jsonData['data'];
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to load customer orders');
      }
    } catch (e) {
      print('Error fetching customer orders: $e');
      throw Exception('Failed to load customer orders: $e');
    }
  }

  // Get all orders for the store owned by the logged-in user
  static Future<Map<String, dynamic>> getStoreOrders() async {
    try {
      final String? token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/orders/store'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);

        // Process images in order data as needed
        if (jsonData['data'] != null && jsonData['data']['orders'] is List) {
          for (var order in jsonData['data']['orders']) {
            // Process store image if present
            if (order['store'] != null && order['store']['image'] != null) {
              order['store']['image'] = ImageService.getImageUrl(order['store']['image']);
            }

            // Process images in order items if present
            if (order['items'] != null && order['items'] is List) {
              for (var item in order['items']) {
                if (item['imageUrl'] != null) {
                  item['imageUrl'] = ImageService.getImageUrl(item['imageUrl']);
                }
              }
            }
          }
        }

        return jsonData['data'];
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to load store orders');
      }
    } catch (e) {
      print('Error fetching store orders: $e');
      throw Exception('Failed to load store orders: $e');
    }
  }

  // Process order by store (approve or reject)
  static Future<Map<String, dynamic>> processOrderByStore(String orderId, String action) async {
    try {
      final String? token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      if (action != 'approve' && action != 'reject') {
        throw Exception('Invalid action. Must be "approve" or "reject"');
      }

      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/orders/$orderId/process'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'action': action,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        return jsonData['data'];
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to process order');
      }
    } catch (e) {
      print('Error processing order: $e');
      throw Exception('Failed to process order: $e');
    }
  }

  // Cancel an order
  static Future<bool> cancelOrder(String orderId, String reason) async {
    try {
      final String? token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/orders/$orderId/cancel'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'reason': reason,
        }),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to cancel order');
      }
    } catch (e) {
      print('Error cancelling order: $e');
      throw Exception('Failed to cancel order: $e');
    }
  }

  // Create a review for store and/or driver
  static Future<bool> reviewOrder(String orderId, {int? storeRating, String? storeComment, int? driverRating, String? driverComment}) async {
    try {
      final String? token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final Map<String, dynamic> requestBody = {
        'orderId': orderId,
      };

      if (storeRating != null) {
        requestBody['store'] = {
          'rating': storeRating,
          'comment': storeComment
        };
      }

      if (driverRating != null) {
        requestBody['driver'] = {
          'rating': driverRating,
          'comment': driverComment
        };
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
        return true;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to submit review');
      }
    } catch (e) {
      print('Error submitting review: $e');
      throw Exception('Failed to submit review: $e');
    }
  }

  // Update order status
  static Future<Map<String, dynamic>> updateOrderStatus(String orderId, String status) async {
    try {
      final String? token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/orders/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'id': orderId,
          'status': status,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        return jsonData['data'];
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to update order status');
      }
    } catch (e) {
      print('Error updating order status: $e');
      throw Exception('Failed to update order status: $e');
    }
  }

  // Calculate estimated delivery time based on distance
  static int calculateEstimatedDeliveryTime(double distanceInKm) {
    // Using the same logic as the backend
    final double averageSpeed = 30; // km/h
    final double estimatedTime = (distanceInKm / averageSpeed) * 60; // Convert to minutes
    return estimatedTime.round();
  }

  // Get store by user ID (can be useful for frontend validation)
  static Future<Map<String, dynamic>> getStoreByUserId(String userId) async {
    try {
      final String? token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/stores/user/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);

        // Process store image if present
        if (jsonData['data'] != null && jsonData['data']['image'] != null) {
          jsonData['data']['image'] = ImageService.getImageUrl(jsonData['data']['image']);
        }

        return jsonData['data'];
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to get store information');
      }
    } catch (e) {
      print('Error getting store by user ID: $e');
      throw Exception('Failed to get store information: $e');
    }
  }
}