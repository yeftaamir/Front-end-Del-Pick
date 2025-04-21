// lib/services/order_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'core/api_constants.dart';
import 'core/token_service.dart';
import 'image_service.dart';

class OrderService {
  static Future<Map<String, dynamic>> placeOrder(Map<String, dynamic> orderData) async {
    final token = await TokenService.getToken();
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/orders'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(orderData),
    );

    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception('Order placement failed: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> getOrderById(String orderId) async {
    final String? token = await TokenService.getToken();
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
      throw Exception('Failed to load order: ${response.statusCode}');
    }
  }

  static Future<Map<String, dynamic>> getCustomerOrders() async {
    final String? token = await TokenService.getToken();
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
      throw Exception('Failed to load customer orders: ${response.statusCode}');
    }
  }

  static Future<Map<String, dynamic>> getStoreOrders() async {
    final String? token = await TokenService.getToken();
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
      throw Exception('Failed to load store orders: ${response.statusCode}');
    }
  }

  static Future<Map<String, dynamic>> processOrderByStore(String orderId, String action) async {
    final String? token = await TokenService.getToken();
    final response = await http.put(
      Uri.parse('${ApiConstants.baseUrl}/orders/$orderId/process'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'action': action, // 'approve' or 'reject'
      }),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = json.decode(response.body);
      return jsonData['data'];
    } else {
      throw Exception('Failed to process order: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> getDriverOrders() async {
    final String? token = await TokenService.getToken();
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/orders/driver'),
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
      throw Exception('Failed to load driver orders: ${response.statusCode}');
    }
  }

  static Future<bool> cancelOrder(String orderId, String reason) async {
    final String? token = await TokenService.getToken();
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

    return response.statusCode == 200;
  }

  static Future<bool> reviewOrder(String orderId, {int? storeRating, String? storeComment, int? driverRating, String? driverComment}) async {
    final String? token = await TokenService.getToken();

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

    return response.statusCode == 201;
  }
}