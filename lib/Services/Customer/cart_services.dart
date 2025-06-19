// lib/Services/Customer/cart_service.dart
import 'package:url_launcher/url_launcher.dart';
import 'package:del_pick/Models/Base/api_response.dart';
import 'package:del_pick/Models/Entities/order.dart';
import 'package:del_pick/Models/Entities/driver.dart';
import 'package:del_pick/Models/Requests/order_requests.dart';
import 'package:del_pick/Models/Responses/order_responses.dart';
import 'package:del_pick/Models/Exceptions/api_exception.dart';
import 'package:del_pick/Services/Order/order_service.dart';
import 'package:del_pick/Services/Driver/driver_service.dart';
import 'package:del_pick/Services/Driver/driver_request_service.dart';
import 'package:del_pick/Services/Utils/error_handler.dart';
import 'package:del_pick/Services/Utils/location_service.dart';

class CartService {
  // Create order from cart items
  static Future<Order> createOrderFromCart({
    required int storeId,
    required List<CartItem> cartItems,
    required String deliveryAddress,
  }) async {
    try {
      // Convert cart items to order items
      final orderItems = cartItems.map((cartItem) => OrderItemRequest(
        menuItemId: cartItem.menuItem.id,
        quantity: cartItem.quantity,
      )).toList();

      // Create order request
      final orderRequest = CreateOrderRequest(
        storeId: storeId,
        items: orderItems,
      );

      // Place order
      final response = await OrderService.placeOrder(orderRequest);

      if (response.isSuccess && response.data != null) {
        return response.data!;
      } else {
        throw ApiException(
          message: response.message,
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      ErrorHandler.logError(e, context: 'CartService.createOrderFromCart');
      rethrow;
    }
  }

  // Get order status
  static Future<Order> getOrderStatus(int orderId) async {
    try {
      final response = await OrderService.getOrderById(orderId);

      if (response.isSuccess && response.data != null) {
        return response.data!;
      } else {
        throw ApiException(
          message: response.message,
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      ErrorHandler.logError(e, context: 'CartService.getOrderStatus');
      rethrow;
    }
  }

  // Cancel order
  static Future<Order> cancelOrder(int orderId) async {
    try {
      final response = await OrderService.cancelOrder(orderId);

      if (response.isSuccess && response.data != null) {
        return response.data!;
      } else {
        throw ApiException(
          message: response.message,
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      ErrorHandler.logError(e, context: 'CartService.cancelOrder');
      rethrow;
    }
  }

  // Get driver information
  static Future<Driver> getDriverInfo(int driverId) async {
    try {
      final response = await DriverService.getDriverById(driverId);

      if (response.isSuccess && response.data != null) {
        return response.data!;
      } else {
        throw ApiException(
          message: response.message,
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      ErrorHandler.logError(e, context: 'CartService.getDriverInfo');
      rethrow;
    }
  }

  // Get nearby drivers
  static Future<List<Driver>> getNearbyDrivers({
    required double latitude,
    required double longitude,
    double radius = 5.0,
  }) async {
    try {
      final response = await DriverService.getNearbyDrivers(
        latitude: latitude,
        longitude: longitude,
        radius: radius,
      );

      if (response.isSuccess && response.data != null) {
        return response.data!;
      } else {
        throw ApiException(
          message: response.message,
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      ErrorHandler.logError(e, context: 'CartService.getNearbyDrivers');
      rethrow;
    }
  }

  // Get driver location
  static Future<Map<String, dynamic>> getDriverLocation(int driverId) async {
    try {
      final response = await DriverService.getDriverLocation(driverId);

      if (response.isSuccess && response.data != null) {
        return response.data!;
      } else {
        throw ApiException(
          message: response.message,
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      ErrorHandler.logError(e, context: 'CartService.getDriverLocation');
      rethrow;
    }
  }

  // Submit review
  static Future<bool> submitReview(
      int orderId,
      Map<String, dynamic> reviewData,
      ) async {
    try {
      final response = await OrderService.createReview(orderId, reviewData);

      if (response.isSuccess) {
        return true;
      } else {
        throw ApiException(
          message: response.message,
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      ErrorHandler.logError(e, context: 'CartService.submitReview');
      rethrow;
    }
  }

  // Calculate delivery fee
  static double calculateDeliveryFee(List<CartItem> cartItems) {
    // Basic delivery fee calculation
    // You can enhance this based on distance, weight, etc.
    const double baseFee = 5000;
    const double perItemFee = 1000;

    final totalItems = cartItems.fold(0, (sum, item) => sum + item.quantity);
    return baseFee + (totalItems * perItemFee);
  }

  // Calculate estimated delivery time
  static Duration estimateDeliveryTime(double? distance) {
    if (distance == null) return const Duration(minutes: 30);
    return LocationService.estimateDeliveryTime(distance);
  }

  // Contact store via WhatsApp
  static Future<void> contactStoreWhatsApp(
      String storePhone,
      String storeName,
      List<CartItem> cartItems,
      ) async {
    try {
      // Create order summary message
      String message = "Halo $storeName,\n\n";
      message += "Saya ingin memesan:\n";

      for (var item in cartItems) {
        message += "• ${item.menuItem.name} x${item.quantity}\n";
      }

      message += "\nApakah semua item tersedia?\nTerima kasih.";

      // Clean phone number (remove non-numeric characters except +)
      String cleanPhone = storePhone.replaceAll(RegExp(r'[^\d+]'), '');
      if (cleanPhone.startsWith('0')) {
        cleanPhone = '+62${cleanPhone.substring(1)}';
      } else if (!cleanPhone.startsWith('+')) {
        cleanPhone = '+62$cleanPhone';
      }

      // Encode message for URL
      final encodedMessage = Uri.encodeComponent(message);

      // Create WhatsApp URL
      final whatsappUrl = 'https://wa.me/$cleanPhone?text=$encodedMessage';

      if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
        await launchUrl(Uri.parse(whatsappUrl), mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Could not launch WhatsApp');
      }
    } catch (e) {
      ErrorHandler.logError(e, context: 'CartService.contactStoreWhatsApp');
      rethrow;
    }
  }

  // Call driver
  static Future<void> callDriver(String driverPhone) async {
    try {
      final phoneUrl = 'tel:$driverPhone';
      if (await canLaunchUrl(Uri.parse(phoneUrl))) {
        await launchUrl(Uri.parse(phoneUrl));
      } else {
        throw Exception('Could not make phone call');
      }
    } catch (e) {
      ErrorHandler.logError(e, context: 'CartService.callDriver');
      rethrow;
    }
  }

  // Message driver via WhatsApp
  static Future<void> messageDriver(String driverPhone, String orderId) async {
    try {
      String message = "Halo, saya customer dengan pesanan #$orderId. ";
      message += "Bagaimana status pesanan saya?";

      // Clean phone number
      String cleanPhone = driverPhone.replaceAll(RegExp(r'[^\d+]'), '');
      if (cleanPhone.startsWith('0')) {
        cleanPhone = '+62${cleanPhone.substring(1)}';
      } else if (!cleanPhone.startsWith('+')) {
        cleanPhone = '+62$cleanPhone';
      }

      final encodedMessage = Uri.encodeComponent(message);
      final whatsappUrl = 'https://wa.me/$cleanPhone?text=$encodedMessage';

      if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
        await launchUrl(Uri.parse(whatsappUrl), mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Could not launch WhatsApp');
      }
    } catch (e) {
      ErrorHandler.logError(e, context: 'CartService.messageDriver');
      rethrow;
    }
  }

  // Calculate distance between two points
  static double calculateDistance(
      double startLatitude,
      double startLongitude,
      double endLatitude,
      double endLongitude,
      ) {
    return LocationService.calculateDistance(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  // Format order time for display
  static String formatOrderTime(DateTime orderTime) {
    final now = DateTime.now();
    final difference = now.difference(orderTime);

    if (difference.inMinutes < 1) {
      return 'Baru saja';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} menit yang lalu';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} jam yang lalu';
    } else {
      return '${difference.inDays} hari yang lalu';
    }
  }

  // Validate cart before order creation
  static bool validateCartForOrder(List<CartItem> cartItems) {
    if (cartItems.isEmpty) return false;

    // Check if all items are available
    for (var item in cartItems) {
      if (!item.menuItem.isAvailable) return false;
      if (item.quantity <= 0) return false;
    }

    return true;
  }

  // Get order summary for display
  static Map<String, dynamic> getOrderSummary(List<CartItem> cartItems) {
    final subtotal = cartItems.fold(0.0, (sum, item) => sum + item.totalPrice);
    final deliveryFee = calculateDeliveryFee(cartItems);
    final total = subtotal + deliveryFee;
    final totalItems = cartItems.fold(0, (sum, item) => sum + item.quantity);

    return {
      'subtotal': subtotal,
      'deliveryFee': deliveryFee,
      'total': total,
      'totalItems': totalItems,
    };
  }
}