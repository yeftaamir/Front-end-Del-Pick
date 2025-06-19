// lib/services/order/order_status_service.dart
import 'package:del_pick/Models/Extensions/menu_item_extensions.dart';

import '../../Models/Base/api_response.dart';
import '../../Models/Entities/order.dart';
import '../../Models/Enums/order_status.dart';
import '../../Models/Enums/delivery_status.dart';
import '../../Models/Enums/user_role.dart';
import '../../Models/Exceptions/api_exception.dart';
import '../../Services/Order/order_service.dart';
import '../../Services/Utils/error_handler.dart';
import '../../Services/Utils/auth_manager.dart';

class OrderStatusService {
  // Get order by ID with real-time updates
  static Future<Order> getOrderById(int orderId) async {
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
      ErrorHandler.logError(e, context: 'OrderStatusService.getOrderById');
      rethrow;
    }
  }

  // Get status configuration for different user roles
  static List<Map<String, dynamic>> getStatusConfig(UserRole userRole) {
    switch (userRole) {
      case UserRole.customer:
        return _getCustomerStatusConfig();
      case UserRole.driver:
        return _getDriverStatusConfig();
      case UserRole.store:
        return _getStoreStatusConfig();
      default:
        return _getCustomerStatusConfig();
    }
  }

  // Customer status configuration
  static List<Map<String, dynamic>> _getCustomerStatusConfig() {
    return [
      {
        'status': OrderStatus.pending,
        'label': 'Menunggu',
        'description': 'Menunggu konfirmasi toko',
        'icon': 'hourglass_empty_rounded',
        'color': 0xFFFF9800,
        'animation': 'assets/animations/loading_animation.json'
      },
      {
        'status': OrderStatus.confirmed,
        'label': 'Dikonfirmasi',
        'description': 'Pesanan dikonfirmasi toko',
        'icon': 'check_circle_rounded',
        'color': 0xFF3E90E9,
        'animation': 'assets/animations/diproses.json'
      },
      {
        'status': OrderStatus.preparing,
        'label': 'Disiapkan',
        'description': 'Pesanan sedang disiapkan',
        'icon': 'restaurant_rounded',
        'color': 0xFF9C27B0,
        'animation': 'assets/animations/diambil.json'
      },
      {
        'status': OrderStatus.onDelivery,
        'label': 'Dikirim',
        'description': 'Pesanan dalam perjalanan',
        'icon': 'delivery_dining_rounded',
        'color': 0xFF2196F3,
        'animation': 'assets/animations/diantar.json'
      },
      {
        'status': OrderStatus.delivered,
        'label': 'Selesai',
        'description': 'Pesanan telah diterima',
        'icon': 'celebration_rounded',
        'color': 0xFF4CAF50,
        'animation': 'assets/animations/pesanan_selesai.json'
      },
    ];
  }

  // Driver status configuration
  static List<Map<String, dynamic>> _getDriverStatusConfig() {
    return [
      {
        'status': OrderStatus.pending,
        'label': 'Menunggu',
        'description': 'Menunggu konfirmasi driver',
        'icon': 'schedule_rounded',
        'color': 0xFFFF9800,
        'animation': 'assets/animations/loading_animation.json'
      },
      {
        'status': OrderStatus.confirmed,
        'label': 'Diterima',
        'description': 'Pesanan diterima driver',
        'icon': 'assignment_turned_in_rounded',
        'color': 0xFF3E90E9,
        'animation': 'assets/animations/diproses.json'
      },
      {
        'status': OrderStatus.preparing,
        'label': 'Ambil Pesanan',
        'description': 'Sedang mengambil pesanan',
        'icon': 'shopping_bag_rounded',
        'color': 0xFF9C27B0,
        'animation': 'assets/animations/diambil.json'
      },
      {
        'status': OrderStatus.onDelivery,
        'label': 'Antar Pesanan',
        'description': 'Dalam perjalanan ke customer',
        'icon': 'directions_bike_rounded',
        'color': 0xFF2196F3,
        'animation': 'assets/animations/diantar.json'
      },
      {
        'status': OrderStatus.delivered,
        'label': 'Terkirim',
        'description': 'Pesanan berhasil diantar',
        'icon': 'check_circle_rounded',
        'color': 0xFF4CAF50,
        'animation': 'assets/animations/pesanan_selesai.json'
      },
    ];
  }

  // Store status configuration
  static List<Map<String, dynamic>> _getStoreStatusConfig() {
    return [
      {
        'status': OrderStatus.pending,
        'label': 'Pesanan Baru',
        'description': 'Menunggu konfirmasi toko',
        'icon': 'notification_important_rounded',
        'color': 0xFFFF9800,
        'animation': 'assets/animations/loading_animation.json'
      },
      {
        'status': OrderStatus.confirmed,
        'label': 'Dikonfirmasi',
        'description': 'Pesanan diterima toko',
        'icon': 'thumb_up_rounded',
        'color': 0xFF3E90E9,
        'animation': 'assets/animations/diproses.json'
      },
      {
        'status': OrderStatus.preparing,
        'label': 'Disiapkan',
        'description': 'Sedang mempersiapkan pesanan',
        'icon': 'restaurant_menu_rounded',
        'color': 0xFF9C27B0,
        'animation': 'assets/animations/diambil.json'
      },
      {
        'status': OrderStatus.onDelivery,
        'label': 'Dikirim',
        'description': 'Pesanan dalam perjalanan',
        'icon': 'local_shipping_rounded',
        'color': 0xFF2196F3,
        'animation': 'assets/animations/diantar.json'
      },
      {
        'status': OrderStatus.delivered,
        'label': 'Terkirim',
        'description': 'Pesanan berhasil diterima',
        'icon': 'done_all_rounded',
        'color': 0xFF4CAF50,
        'animation': 'assets/animations/pesanan_selesai.json'
      },
    ];
  }

  // Get cancelled status info
  static Map<String, dynamic> getCancelledStatusInfo() {
    return {
      'status': OrderStatus.cancelled,
      'label': 'Dibatalkan',
      'description': 'Pesanan telah dibatalkan',
      'icon': 'cancel_rounded',
      'color': 0xFFE53E3E,
      'animation': 'assets/animations/cancel.json'
    };
  }

  // Get current status information
  static Map<String, dynamic> getCurrentStatusInfo(Order order, UserRole userRole) {
    if (order.orderStatus == OrderStatus.cancelled) {
      return getCancelledStatusInfo();
    }

    final statusConfig = getStatusConfig(userRole);
    return statusConfig.firstWhere(
          (item) => item['status'] == order.orderStatus,
      orElse: () => statusConfig.first,
    );
  }

  // Check if status changed
  static bool hasStatusChanged(OrderStatus? previousStatus, OrderStatus currentStatus) {
    return previousStatus != null && previousStatus != currentStatus;
  }

  // Get customer name from order
  static String getCustomerName(Order order) {
    return order.customer?.displayName ?? 'Customer';
  }

  // Get order ID string
  static String getOrderIdString(Order order) {
    return order.id.toString();
  }

  // Check if order should show animations
  static bool shouldShowAnimations(OrderStatus status) {
    return status != OrderStatus.delivered && status != OrderStatus.cancelled;
  }

  // Get order progress percentage
  static double getOrderProgress(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 0.2;
      case OrderStatus.confirmed:
        return 0.4;
      case OrderStatus.preparing:
        return 0.6;
      case OrderStatus.readyForPickup:
        return 0.7;
      case OrderStatus.onDelivery:
        return 0.8;
      case OrderStatus.delivered:
        return 1.0;
      case OrderStatus.cancelled:
        return 0.0;
    }
  }

  // Format order time
  static String formatOrderTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

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

  // Get estimated delivery time
  static String? getEstimatedDeliveryTime(Order order) {
    if (order.estimatedDeliveryTime == null) return null;

    final now = DateTime.now();
    final estimatedTime = order.estimatedDeliveryTime!;

    if (estimatedTime.isBefore(now)) {
      return 'Terlambat ${formatOrderTime(estimatedTime)}';
    } else {
      final difference = estimatedTime.difference(now);
      if (difference.inMinutes < 60) {
        return '${difference.inMinutes} menit lagi';
      } else {
        return '${difference.inHours} jam ${difference.inMinutes % 60} menit lagi';
      }
    }
  }

  // Update order status (for store/driver actions)
  static Future<Order> updateOrderStatus(int orderId, OrderStatus newStatus) async {
    try {
      final response = await OrderService.updateOrderStatus(orderId, newStatus);

      if (response.isSuccess && response.data != null) {
        return response.data!;
      } else {
        throw ApiException(
          message: response.message,
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      ErrorHandler.logError(e, context: 'OrderStatusService.updateOrderStatus');
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
      ErrorHandler.logError(e, context: 'OrderStatusService.cancelOrder');
      rethrow;
    }
  }

  // Get current user role
  static UserRole getCurrentUserRole() {
    final currentUser = AuthManager.currentUser;
    return currentUser?.role ?? UserRole.customer;
  }

  // Check if user can update order status
  static bool canUpdateOrderStatus(Order order, UserRole userRole) {
    switch (userRole) {
      case UserRole.store:
        return order.orderStatus == OrderStatus.pending ||
            order.orderStatus == OrderStatus.confirmed;
      case UserRole.driver:
        return order.orderStatus == OrderStatus.preparing ||
            order.orderStatus == OrderStatus.onDelivery;
      case UserRole.customer:
        return order.orderStatus == OrderStatus.pending;
      default:
        return false;
    }
  }

  // Get available actions for current status
  static List<OrderAction> getAvailableActions(Order order, UserRole userRole) {
    final List<OrderAction> actions = [];

    switch (userRole) {
      case UserRole.store:
        if (order.orderStatus == OrderStatus.pending) {
          actions.add(OrderAction.confirm);
          actions.add(OrderAction.cancel);
        } else if (order.orderStatus == OrderStatus.confirmed) {
          actions.add(OrderAction.startPreparing);
        } else if (order.orderStatus == OrderStatus.preparing) {
          actions.add(OrderAction.readyForPickup);
        }
        break;

      case UserRole.driver:
        if (order.orderStatus == OrderStatus.readyForPickup) {
          actions.add(OrderAction.pickup);
        } else if (order.orderStatus == OrderStatus.onDelivery) {
          actions.add(OrderAction.deliver);
        }
        break;

      case UserRole.customer:
        if (order.orderStatus == OrderStatus.pending) {
          actions.add(OrderAction.cancel);
        }
        break;

      default:
        break;
    }

    return actions;
  }
}

// Order actions enum
enum OrderAction {
  confirm,
  cancel,
  startPreparing,
  readyForPickup,
  pickup,
  deliver,
}