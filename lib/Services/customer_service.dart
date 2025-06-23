// lib/Services/customer_service.dart
import 'dart:convert';
import 'core/base_service.dart';
import 'image_service.dart';

class CustomerService {
  static const String _baseEndpoint = '/customers';

  /// Get all customers (admin only - but excluding per instruction)
  static Future<Map<String, dynamic>> getAllCustomers({
    int page = 1,
    int limit = 10,
    String? sortBy,
    String? sortOrder,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (sortBy != null) 'sortBy': sortBy,
        if (sortOrder != null) 'sortOrder': sortOrder,
      };

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: _baseEndpoint,
        queryParams: queryParams,
        requiresAuth: true,
      );

      // Process customer images
      if (response['data'] != null && response['data'] is List) {
        for (var customer in response['data']) {
          _processCustomerImages(customer);
        }
      }

      return response;
    } catch (e) {
      print('Get all customers error: $e');
      throw Exception('Failed to get customers: $e');
    }
  }

  /// Get customer by ID
  static Future<Map<String, dynamic>> getCustomerById(String customerId) async {
    try {
      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/$customerId',
        requiresAuth: true,
      );

      if (response['data'] != null) {
        _processCustomerImages(response['data']);
      }

      return response['data'] ?? {};
    } catch (e) {
      print('Get customer by ID error: $e');
      throw Exception('Failed to get customer: $e');
    }
  }

  /// Helper method to process customer images
  static void _processCustomerImages(Map<String, dynamic> customer) {
    if (customer['avatar'] != null && customer['avatar'].toString().isNotEmpty) {
      customer['avatar'] = ImageService.getImageUrl(customer['avatar']);
    }
  }
}