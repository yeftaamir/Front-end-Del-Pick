// lib/Services/service_order_service.dart
import 'dart:convert';
import 'core/base_service.dart';
import 'image_service.dart';
import 'auth_service.dart';

class ServiceOrderService {
  static const String _baseEndpoint = '/service-orders';

  /// Create a new service order (customer only) - Destinasi tetap ke IT Del
  static Future<Map<String, dynamic>> createServiceOrder({
    required String pickupAddress,
    required double pickupLatitude,
    required double pickupLongitude,
    required String customerPhone,
    String? description,
  }) async {
    try {
      print('🚀 ServiceOrderService: Creating service order...');

      // Validate customer access
      final hasAccess = await AuthService.validateCustomerAccess();
      if (!hasAccess) {
        throw Exception('Access denied: Customer authentication required');
      }

      // Prepare request body
      final body = {
        'pickup_address': pickupAddress,
        'pickup_latitude': pickupLatitude,
        'pickup_longitude': pickupLongitude,
        'customer_phone': customerPhone,
        if (description != null && description.isNotEmpty) 'description': description,
      };

      print('📋 ServiceOrderService: Service order payload prepared');
      print('   - Pickup: $pickupAddress');
      print('   - Destination: IT Del (Fixed)');

      final response = await BaseService.apiCall(
        method: 'POST',
        endpoint: _baseEndpoint,
        body: body,
        requiresAuth: true,
      );

      if (response['data'] != null) {
        _processServiceOrderImages(response['data']);
        print('✅ ServiceOrderService: Service order created successfully');
        print('   - Service Order ID: ${response['data']['id']}');
        print('   - Auto driver search started');
        return response['data'];
      }

      throw Exception('Invalid response: No service order data returned');
    } catch (e) {
      print('❌ ServiceOrderService: Create service order error: $e');
      throw Exception('Failed to create service order: $e');
    }
  }

  /// Get available drivers for service order (customer only)
  static Future<Map<String, dynamic>> getAvailableDrivers({
    required double pickupLatitude,
    required double pickupLongitude,
    required String destinationAddress,
  }) async {
    try {
      print('🔍 ServiceOrderService: Getting available drivers...');

      final hasAccess = await AuthService.validateCustomerAccess();
      if (!hasAccess) {
        throw Exception('Access denied: Customer authentication required');
      }

      final queryParams = {
        'pickup_latitude': pickupLatitude.toString(),
        'pickup_longitude': pickupLongitude.toString(),
        'destination_address': destinationAddress,
      };

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/available-drivers',
        queryParams: queryParams,
        requiresAuth: true,
      );

      if (response['data'] != null) {
        // Process driver images
        if (response['data']['available_drivers'] != null) {
          final drivers = response['data']['available_drivers'] as List;
          for (var driver in drivers) {
            _processDriverImages(driver);
          }
        }
        print('✅ ServiceOrderService: Found ${response['data']['available_drivers']?.length ?? 0} available drivers');
        return response['data'];
      }

      return {
        'service_fee': 20000.0,
        'destination_address': destinationAddress,
        'available_drivers': [],
      };
    } catch (e) {
      print('❌ ServiceOrderService: Get available drivers error: $e');
      throw Exception('Failed to get available drivers: $e');
    }
  }

  /// Accept service order (driver only) - Manual acceptance via WhatsApp coordination
  static Future<Map<String, dynamic>> acceptServiceOrder({
    required int customerId,
    required String pickupAddress,
    required double pickupLatitude,
    required double pickupLongitude,
    required String destinationAddress,
    required double destinationLatitude,
    required double destinationLongitude,
    required String customerPhone,
    String? description,
  }) async {
    try {
      print('🤝 ServiceOrderService: Accepting service order...');

      // Validate driver access
      final hasDriverAccess = await AuthService.hasRole('driver');
      if (!hasDriverAccess) {
        throw Exception('Access denied: Driver authentication required');
      }

      final body = {
        'customer_id': customerId,
        'pickup_address': pickupAddress,
        'pickup_latitude': pickupLatitude,
        'pickup_longitude': pickupLongitude,
        'destination_address': destinationAddress,
        'destination_latitude': destinationLatitude,
        'destination_longitude': destinationLongitude,
        'customer_phone': customerPhone,
        if (description != null) 'description': description,
      };

      final response = await BaseService.apiCall(
        method: 'POST',
        endpoint: '$_baseEndpoint/accept',
        body: body,
        requiresAuth: true,
      );

      if (response['data'] != null) {
        _processServiceOrderImages(response['data']);
        print('✅ ServiceOrderService: Service order accepted successfully');
        return response['data'];
      }

      return {};
    } catch (e) {
      print('❌ ServiceOrderService: Accept service order error: $e');
      throw Exception('Failed to accept service order: $e');
    }
  }

  /// Get service orders by customer
  static Future<Map<String, dynamic>> getServiceOrdersByCustomer({
    int page = 1,
    int limit = 10,
    String? status,
  }) async {
    try {
      print('🔍 ServiceOrderService: Getting customer service orders...');

      final hasAccess = await AuthService.validateCustomerAccess();
      if (!hasAccess) {
        throw Exception('Access denied: Customer authentication required');
      }

      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (status != null) 'status': status,
      };

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/customer',
        queryParams: queryParams,
        requiresAuth: true,
      );

      if (response['data'] != null && response['data']['serviceOrders'] != null) {
        final serviceOrders = response['data']['serviceOrders'] as List;
        for (var serviceOrder in serviceOrders) {
          _processServiceOrderImages(serviceOrder);
        }
        print('✅ ServiceOrderService: Retrieved ${serviceOrders.length} customer service orders');
      }

      return response['data'] ?? {
        'serviceOrders': [],
        'totalItems': 0,
        'totalPages': 0,
        'currentPage': 1,
      };
    } catch (e) {
      print('❌ ServiceOrderService: Get customer service orders error: $e');
      throw Exception('Failed to get customer service orders: $e');
    }
  }

  /// Get service orders by driver
  static Future<Map<String, dynamic>> getServiceOrdersByDriver({
    int page = 1,
    int limit = 10,
    String? status,
  }) async {
    try {
      print('🔍 ServiceOrderService: Getting driver service orders...');

      final hasDriverAccess = await AuthService.hasRole('driver');
      if (!hasDriverAccess) {
        throw Exception('Access denied: Driver authentication required');
      }

      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (status != null) 'status': status,
      };

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/driver',
        queryParams: queryParams,
        requiresAuth: true,
      );

      if (response['data'] != null && response['data']['serviceOrders'] != null) {
        final serviceOrders = response['data']['serviceOrders'] as List;
        for (var serviceOrder in serviceOrders) {
          _processServiceOrderImages(serviceOrder);
        }
        print('✅ ServiceOrderService: Retrieved ${serviceOrders.length} driver service orders');
      }

      return response['data'] ?? {
        'serviceOrders': [],
        'totalItems': 0,
        'totalPages': 0,
        'currentPage': 1,
      };
    } catch (e) {
      print('❌ ServiceOrderService: Get driver service orders error: $e');
      throw Exception('Failed to get driver service orders: $e');
    }
  }

  /// Get service order by ID
  static Future<Map<String, dynamic>> getServiceOrderById(String serviceOrderId) async {
    try {
      print('🔍 ServiceOrderService: Getting service order by ID: $serviceOrderId');

      final isAuth = await AuthService.isAuthenticated();
      if (!isAuth) {
        throw Exception('Authentication required');
      }

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/$serviceOrderId',
        requiresAuth: true,
      );

      if (response['data'] != null) {
        _processServiceOrderImages(response['data']);
        print('✅ ServiceOrderService: Service order details retrieved successfully');
        return response['data'];
      }

      throw Exception('Service order not found');
    } catch (e) {
      print('❌ ServiceOrderService: Get service order by ID error: $e');
      throw Exception('Failed to get service order: $e');
    }
  }

  /// Update service order status (driver only)
  static Future<Map<String, dynamic>> updateServiceOrderStatus({
    required String serviceOrderId,
    required String status, // in_progress, completed, cancelled
    String? notes,
  }) async {
    try {
      print('📝 ServiceOrderService: Updating service order status: $serviceOrderId to $status');

      final hasDriverAccess = await AuthService.hasRole('driver');
      if (!hasDriverAccess) {
        throw Exception('Access denied: Driver authentication required');
      }

      if (!['in_progress', 'completed', 'cancelled'].contains(status.toLowerCase())) {
        throw Exception('Invalid status. Must be: in_progress, completed, or cancelled');
      }

      final body = {
        'status': status.toLowerCase(),
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      };

      final response = await BaseService.apiCall(
        method: 'PUT',
        endpoint: '$_baseEndpoint/$serviceOrderId/status',
        body: body,
        requiresAuth: true,
      );

      if (response['data'] != null) {
        _processServiceOrderImages(response['data']);
      }

      print('✅ ServiceOrderService: Service order status updated successfully');
      return response['data'] ?? {};
    } catch (e) {
      print('❌ ServiceOrderService: Update service order status error: $e');
      throw Exception('Failed to update service order status: $e');
    }
  }

  /// Cancel service order (customer only)
  static Future<Map<String, dynamic>> cancelServiceOrder({
    required String serviceOrderId,
    String? reason,
  }) async {
    try {
      print('❌ ServiceOrderService: Cancelling service order: $serviceOrderId');

      final hasAccess = await AuthService.validateCustomerAccess();
      if (!hasAccess) {
        throw Exception('Access denied: Customer authentication required');
      }

      final body = <String, dynamic>{};
      if (reason != null && reason.isNotEmpty) {
        body['reason'] = reason;
      }

      final response = await BaseService.apiCall(
        method: 'POST',
        endpoint: '$_baseEndpoint/$serviceOrderId/cancel',
        body: body.isNotEmpty ? body : null,
        requiresAuth: true,
      );

      if (response['data'] != null) {
        _processServiceOrderImages(response['data']);
      }

      print('✅ ServiceOrderService: Service order cancelled successfully');
      return response['data'] ?? {};
    } catch (e) {
      print('❌ ServiceOrderService: Cancel service order error: $e');
      throw Exception('Failed to cancel service order: $e');
    }
  }

  /// Create review for completed service order (customer only)
  static Future<Map<String, dynamic>> createServiceOrderReview({
    required String serviceOrderId,
    required int rating,
    String? comment,
    int? serviceQuality,
    int? punctuality,
    int? communication,
  }) async {
    try {
      print('⭐ ServiceOrderService: Creating review for service order: $serviceOrderId');

      final hasAccess = await AuthService.validateCustomerAccess();
      if (!hasAccess) {
        throw Exception('Access denied: Customer authentication required');
      }

      final body = {
        'rating': rating,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
        if (serviceQuality != null) 'service_quality': serviceQuality,
        if (punctuality != null) 'punctuality': punctuality,
        if (communication != null) 'communication': communication,
      };

      final response = await BaseService.apiCall(
        method: 'POST',
        endpoint: '$_baseEndpoint/$serviceOrderId/review',
        body: body,
        requiresAuth: true,
      );

      print('✅ ServiceOrderService: Review created successfully');
      return response['data'] ?? {};
    } catch (e) {
      print('❌ ServiceOrderService: Create review error: $e');
      throw Exception('Failed to create review: $e');
    }
  }

  /// Generate WhatsApp link for communication
  static String generateWhatsAppLink({
    required String phoneNumber,
    required String pickupAddress,
    required String destinationAddress,
    required double serviceFee,
    String? description,
  }) {
    try {
      // Clean phone number (remove non-digits)
      final cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');

      // Create message
      final message = '''Halo, saya dari aplikasi DelPick.

Saya membutuhkan jasa titip dengan detail:
📍 Lokasi Pickup: $pickupAddress
📍 Lokasi Tujuan: $destinationAddress
💰 Biaya Pengiriman: Rp ${serviceFee.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}
${description != null && description.isNotEmpty ? '📝 Notes: $description' : ''}

Apakah Anda bisa menangani jasa titip ini? Terima kasih!''';

      return 'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}';
    } catch (e) {
      print('❌ ServiceOrderService: Generate WhatsApp link error: $e');
      return 'https://wa.me/$phoneNumber';
    }
  }

  /// Get service order status display text
  static String getStatusDisplayText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Mencari Driver';
      case 'driver_found':
        return 'Driver Ditemukan';
      case 'in_progress':
        return 'Sedang Dikerjakan';
      case 'completed':
        return 'Selesai';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return 'Status Tidak Diketahui';
    }
  }

  /// Get service order urgency level
  static String getServiceOrderUrgency(Map<String, dynamic> serviceOrder) {
    try {
      final createdAt = DateTime.tryParse(serviceOrder['created_at'] ?? '');
      if (createdAt == null) return 'normal';

      final now = DateTime.now();
      final difference = now.difference(createdAt).inMinutes;

      if (difference > 60) return 'urgent';
      if (difference > 30) return 'high';
      return 'normal';
    } catch (e) {
      return 'normal';
    }
  }

  /// Check if service order can be cancelled
  static bool canBeCancelled(String status) {
    return ['pending', 'driver_found'].contains(status.toLowerCase());
  }

  /// Check if service order can be reviewed
  static bool canBeReviewed(String status) {
    return status.toLowerCase() == 'completed';
  }

  // PRIVATE HELPER METHODS

  /// Process service order images
  static void _processServiceOrderImages(Map<String, dynamic> serviceOrder) {
    try {
      // Process customer avatar
      if (serviceOrder['customer'] != null && serviceOrder['customer']['avatar'] != null) {
        serviceOrder['customer']['avatar'] = ImageService.getImageUrl(serviceOrder['customer']['avatar']);
      }

      // Process driver avatar
      if (serviceOrder['driver'] != null) {
        if (serviceOrder['driver']['user'] != null && serviceOrder['driver']['user']['avatar'] != null) {
          serviceOrder['driver']['user']['avatar'] = ImageService.getImageUrl(serviceOrder['driver']['user']['avatar']);
        } else if (serviceOrder['driver']['avatar'] != null) {
          serviceOrder['driver']['avatar'] = ImageService.getImageUrl(serviceOrder['driver']['avatar']);
        }
      }

      // Process pickup location image (if any)
      if (serviceOrder['pickup_location'] != null && serviceOrder['pickup_location']['image_url'] != null) {
        serviceOrder['pickup_location']['image_url'] = ImageService.getImageUrl(serviceOrder['pickup_location']['image_url']);
      }

      // Process destination location image (if any)
      if (serviceOrder['destination_location'] != null && serviceOrder['destination_location']['image_url'] != null) {
        serviceOrder['destination_location']['image_url'] = ImageService.getImageUrl(serviceOrder['destination_location']['image_url']);
      }
    } catch (e) {
      print('❌ ServiceOrderService: Error processing service order images: $e');
    }
  }

  /// Process driver images for available drivers list
  static void _processDriverImages(Map<String, dynamic> driver) {
    try {
      if (driver['avatar'] != null && driver['avatar'].toString().isNotEmpty) {
        driver['avatar'] = ImageService.getImageUrl(driver['avatar']);
      }
    } catch (e) {
      print('❌ ServiceOrderService: Error processing driver images: $e');
    }
  }
}