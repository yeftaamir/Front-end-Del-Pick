// lib/pages/shared/widgets/order_status_widgets.dart
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:ui';

import '../../../Common/global_style.dart';
import '../../../Models/Entities/order.dart';
import '../../../Models/Enums/order_status.dart';
import '../../../Models/Enums/user_role.dart';
import '../../../Services/Order/order_status_service.dart';

class OrderStatusWidgets {
  // Build main order status card
  static Widget buildOrderStatusCard({
    required Order order,
    required UserRole userRole,
    required Animation<Offset>? slideAnimation,
    required Animation<double> pulseAnimation,
    required Animation<double> floatAnimation,
    required Animation<double> shimmerAnimation,
    VoidCallback? onTap,
  }) {
    final statusInfo = OrderStatusService.getCurrentStatusInfo(order, userRole);

    Widget content = AnimatedBuilder(
      animation: floatAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, floatAnimation.value),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Stack(
              children: [
                _buildBackgroundGlow(Color(statusInfo['color'])),
                _buildMainCard(
                  order: order,
                  userRole: userRole,
                  statusInfo: statusInfo,
                  pulseAnimation: pulseAnimation,
                  shimmerAnimation: shimmerAnimation,
                  onTap: onTap,
                ),
              ],
            ),
          ),
        );
      },
    );

    if (slideAnimation != null) {
      return SlideTransition(
        position: slideAnimation,
        child: content,
      );
    }

    return content;
  }

  // Build background glow effect
  static Widget _buildBackgroundGlow(Color statusColor) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: statusColor.withOpacity(0.15),
              blurRadius: 30,
              spreadRadius: 5,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: GlobalStyle.primaryColor.withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: -5,
              offset: const Offset(0, 4),
            ),
          ],
        ),
      ),
    );
  }

  // Build main glassmorphism card
  static Widget _buildMainCard({
    required Order order,
    required UserRole userRole,
    required Map<String, dynamic> statusInfo,
    required Animation<double> pulseAnimation,
    required Animation<double> shimmerAnimation,
    VoidCallback? onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.25),
                Colors.white.withOpacity(0.1),
                Colors.white.withOpacity(0.15),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(32),
              child: Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(
                      order: order,
                      userRole: userRole,
                      shimmerAnimation: shimmerAnimation,
                    ),
                    const SizedBox(height: 24),
                    _buildStatusSection(
                      order: order,
                      statusInfo: statusInfo,
                      pulseAnimation: pulseAnimation,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Build header with order info
  static Widget _buildHeader({
    required Order order,
    required UserRole userRole,
    required Animation<double> shimmerAnimation,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            GlobalStyle.primaryColor.withOpacity(0.8),
            GlobalStyle.primaryColor.withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: GlobalStyle.primaryColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildHeaderIcon(userRole),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOrderIdWithShimmer(order, shimmerAnimation),
                const SizedBox(height: 4),
                _buildSubtitle(order, userRole),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Build header icon based on user role
  static Widget _buildHeaderIcon(UserRole userRole) {
    IconData iconData;
    switch (userRole) {
      case UserRole.customer:
        iconData = Icons.receipt_long_rounded;
        break;
      case UserRole.driver:
        iconData = Icons.delivery_dining_rounded;
        break;
      case UserRole.store:
        iconData = Icons.store_rounded;
        break;
      default:
        iconData = Icons.receipt_long_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        iconData,
        color: Colors.white,
        size: 24,
      ),
    );
  }

  // Build order ID with shimmer effect
  static Widget _buildOrderIdWithShimmer(Order order, Animation<double> shimmerAnimation) {
    return AnimatedBuilder(
      animation: shimmerAnimation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.white.withOpacity(0.8),
                Colors.white,
              ],
              stops: [
                shimmerAnimation.value - 1,
                shimmerAnimation.value,
                shimmerAnimation.value + 1,
              ],
            ).createShader(bounds);
          },
          child: Text(
            'Order #${OrderStatusService.getOrderIdString(order)}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
        );
      },
    );
  }

  // Build subtitle based on user role
  static Widget _buildSubtitle(Order order, UserRole userRole) {
    String subtitleText;

    switch (userRole) {
      case UserRole.customer:
        subtitleText = OrderStatusService.getCustomerName(order);
        break;
      case UserRole.driver:
      case UserRole.store:
        subtitleText = 'Customer: ${OrderStatusService.getCustomerName(order)}';
        break;
      default:
        subtitleText = OrderStatusService.getCustomerName(order);
    }

    return Text(
      subtitleText,
      style: TextStyle(
        fontSize: 14,
        color: Colors.white.withOpacity(0.9),
        fontFamily: GlobalStyle.fontFamily,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  // Build status section
  static Widget _buildStatusSection({
    required Order order,
    required Map<String, dynamic> statusInfo,
    required Animation<double> pulseAnimation,
  }) {
    return Column(
      children: [
        _buildStatusAnimation(statusInfo, order.orderStatus, pulseAnimation),
        const SizedBox(height: 24),
        _buildStatusInfo(statusInfo),
      ],
    );
  }

  // Build status animation
  static Widget _buildStatusAnimation(
      Map<String, dynamic> statusInfo,
      OrderStatus orderStatus,
      Animation<double> pulseAnimation,
      ) {
    return Container(
      width: 140,
      height: 140,
      child: Lottie.asset(
        statusInfo['animation'],
        fit: BoxFit.contain,
        repeat: OrderStatusService.shouldShowAnimations(orderStatus),
      ),
    );
  }

  // Build status information
  static Widget _buildStatusInfo(Map<String, dynamic> statusInfo) {
    final statusColor = Color(statusInfo['color']);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            statusColor.withOpacity(0.1),
            statusColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: statusColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getIconData(statusInfo['icon']),
                color: statusColor,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                statusInfo['label'],
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                  fontFamily: GlobalStyle.fontFamily,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            statusInfo['description'],
            style: TextStyle(
              fontSize: 16,
              color: statusColor.withOpacity(0.8),
              fontFamily: GlobalStyle.fontFamily,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Build order actions (for store/driver)
  static Widget buildOrderActions({
    required Order order,
    required UserRole userRole,
    required Function(OrderAction) onActionPressed,
  }) {
    final actions = OrderStatusService.getAvailableActions(order, userRole);

    if (actions.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: actions.map((action) => _buildActionButton(action, onActionPressed)).toList(),
      ),
    );
  }

  // Build individual action button
  static Widget _buildActionButton(OrderAction action, Function(OrderAction) onPressed) {
    return ElevatedButton(
      onPressed: () => onPressed(action),
      style: ElevatedButton.styleFrom(
        backgroundColor: _getActionColor(action),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
        elevation: 2,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getActionIcon(action), size: 18),
          const SizedBox(width: 8),
          Text(
            _getActionLabel(action),
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // Build loading state
  static Widget buildLoadingState() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(GlobalStyle.primaryColor),
              ),
              const SizedBox(height: 16),
              Text(
                'Memuat status pesanan...',
                style: TextStyle(
                  fontFamily: GlobalStyle.fontFamily,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build error state
  static Widget buildErrorState({
    required String message,
    required VoidCallback onRetry,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.error_outline, size: 60, color: Colors.red[400]),
              const SizedBox(height: 16),
              Text(
                'Gagal memuat status pesanan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: GlobalStyle.fontFamily,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontFamily: GlobalStyle.fontFamily,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlobalStyle.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Play status change sound
  static void playStatusChangeSound() {
    final audioPlayer = AudioPlayer();
    audioPlayer.play(AssetSource('audio/kring.mp3'));

    // Dispose after playing
    Future.delayed(const Duration(seconds: 3), () {
      audioPlayer.dispose();
    });
  }

  // Play cancel sound
  static void playCancelSound() {
    final audioPlayer = AudioPlayer();
    audioPlayer.play(AssetSource('audio/found.wav'));

    // Dispose after playing
    Future.delayed(const Duration(seconds: 3), () {
      audioPlayer.dispose();
    });
  }

  // Helper methods
  static IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'hourglass_empty_rounded':
        return Icons.hourglass_empty_rounded;
      case 'check_circle_rounded':
        return Icons.check_circle_rounded;
      case 'restaurant_rounded':
        return Icons.restaurant_rounded;
      case 'delivery_dining_rounded':
        return Icons.delivery_dining_rounded;
      case 'celebration_rounded':
        return Icons.celebration_rounded;
      case 'schedule_rounded':
        return Icons.schedule_rounded;
      case 'assignment_turned_in_rounded':
        return Icons.assignment_turned_in_rounded;
      case 'shopping_bag_rounded':
        return Icons.shopping_bag_rounded;
      case 'directions_bike_rounded':
        return Icons.directions_bike_rounded;
      case 'notification_important_rounded':
        return Icons.notification_important_rounded;
      case 'thumb_up_rounded':
        return Icons.thumb_up_rounded;
      case 'restaurant_menu_rounded':
        return Icons.restaurant_menu_rounded;
      case 'local_shipping_rounded':
        return Icons.local_shipping_rounded;
      case 'done_all_rounded':
        return Icons.done_all_rounded;
      case 'cancel_rounded':
        return Icons.cancel_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  static Color _getActionColor(OrderAction action) {
    switch (action) {
      case OrderAction.confirm:
        return Colors.green;
      case OrderAction.cancel:
        return Colors.red;
      case OrderAction.startPreparing:
        return Colors.orange;
      case OrderAction.readyForPickup:
        return Colors.blue;
      case OrderAction.pickup:
        return Colors.purple;
      case OrderAction.deliver:
        return Colors.green;
    }
  }

  static IconData _getActionIcon(OrderAction action) {
    switch (action) {
      case OrderAction.confirm:
        return Icons.check;
      case OrderAction.cancel:
        return Icons.cancel;
      case OrderAction.startPreparing:
        return Icons.restaurant;
      case OrderAction.readyForPickup:
        return Icons.inventory;
      case OrderAction.pickup:
        return Icons.local_shipping;
      case OrderAction.deliver:
        return Icons.done;
    }
  }

  static String _getActionLabel(OrderAction action) {
    switch (action) {
      case OrderAction.confirm:
        return 'Konfirmasi';
      case OrderAction.cancel:
        return 'Batalkan';
      case OrderAction.startPreparing:
        return 'Mulai Siapkan';
      case OrderAction.readyForPickup:
        return 'Siap Diambil';
      case OrderAction.pickup:
        return 'Ambil Pesanan';
      case OrderAction.deliver:
        return 'Selesai Antar';
    }
  }
}