// lib/services/tracking_service.dart
import 'package:flutter/foundation.dart';
import 'core/base_service.dart';
import 'image_service.dart';

class TrackingService extends BaseService {

  // Get tracking data for an order
  static Future<Map<String, dynamic>> getTrackingData(String orderId) async {
    try {
      final response = await BaseService.get('/orders/$orderId/tracking');

      if (response['data'] != null) {
        _processTrackingData(response['data']);
      }

      return response['data'] ?? {};
    } catch (e) {
      debugPrint('Get tracking data error: $e');
      rethrow;
    }
  }

  // Start delivery (by driver)
  static Future<Map<String, dynamic>> startDelivery(String orderId) async {
    try {
      final response = await BaseService.post('/orders/$orderId/tracking/start', {});
      return response['data'] ?? {};
    } catch (e) {
      debugPrint('Start delivery error: $e');
      rethrow;
    }
  }

  // Complete delivery (by driver)
  static Future<Map<String, dynamic>> completeDelivery(String orderId) async {
    try {
      final response = await BaseService.post('/orders/$orderId/tracking/complete', {});
      return response['data'] ?? {};
    } catch (e) {
      debugPrint('Complete delivery error: $e');
      rethrow;
    }
  }

  // Update delivery location (by driver)
  static Future<Map<String, dynamic>> updateDeliveryLocation(
      String orderId,
      double latitude,
      double longitude,
      ) async {
    try {
      final response = await BaseService.put('/orders/$orderId/tracking/location', {
        'latitude': latitude,
        'longitude': longitude,
      });

      return response['data'] ?? {};
    } catch (e) {
      debugPrint('Update delivery location error: $e');
      rethrow;
    }
  }

  // Get real-time tracking updates
  static Future<Map<String, dynamic>> getRealtimeTracking(String orderId) async {
    try {
      final response = await BaseService.get('/orders/$orderId/tracking/realtime');

      if (response['data'] != null) {
        _processTrackingData(response['data']);
      }

      return response['data'] ?? {};
    } catch (e) {
      debugPrint('Get realtime tracking error: $e');
      rethrow;
    }
  }

  // PRIVATE HELPER METHODS

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

      // Process order images if tracking includes order data
      if (trackingData['order'] != null) {
        _processOrderTrackingImages(trackingData['order']);
      }
    } catch (e) {
      debugPrint('Process tracking data error: $e');
    }
  }

  static void _processOrderTrackingImages(Map<String, dynamic> orderData) {
    try {
      // Process store images
      if (orderData['store'] != null && orderData['store']['imageUrl'] != null) {
        orderData['store']['imageUrl'] = ImageService.getImageUrl(orderData['store']['imageUrl']);
      }

      // Process menu item images
      if (orderData['items'] != null && orderData['items'] is List) {
        for (var item in orderData['items']) {
          if (item['menuItem'] != null && item['menuItem']['imageUrl'] != null) {
            item['menuItem']['imageUrl'] = ImageService.getImageUrl(item['menuItem']['imageUrl']);
          }
        }
      }
    } catch (e) {
      debugPrint('Process order tracking images error: $e');
    }
  }
}