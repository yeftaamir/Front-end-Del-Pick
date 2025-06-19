// lib/pages/drivers/widgets/driver_order_status_card.dart
import 'package:flutter/material.dart';
import 'dart:async';

import '../../../../Models/Entities/order.dart';
import '../../../../Models/Enums/order_status.dart';
import '../../../../Models/Enums/user_role.dart';
import '../../../../Services/Order/order_status_service.dart';
import '../../../../Services/Utils/error_handler.dart';
import '../../Shared/order_status_widgets.dart';

class DriverOrderStatusCard extends StatefulWidget {
  final int orderId;
  final Animation<Offset>? slideAnimation;
  final VoidCallback? onTap;
  final Function(OrderAction)? onActionPressed;

  const DriverOrderStatusCard({
    super.key,
    required this.orderId,
    this.slideAnimation,
    this.onTap,
    this.onActionPressed,
  });

  @override
  State<DriverOrderStatusCard> createState() => _DriverOrderStatusCardState();
}

class _DriverOrderStatusCardState extends State<DriverOrderStatusCard>
    with TickerProviderStateMixin {

  // Data state
  Order? _order;
  bool _isLoading = true;
  bool _isUpdatingStatus = false;
  String? _errorMessage;
  OrderStatus? _previousStatus;

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _floatController;
  late AnimationController _shimmerController;

  // Animations
  late Animation<double> _pulseAnimation;
  late Animation<double> _floatAnimation;
  late Animation<double> _shimmerAnimation;

  // Auto-refresh timer
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadOrder();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _disposeResources();
    super.dispose();
  }

  // Initialize animations
  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _floatController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _shimmerController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _floatAnimation = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _shimmerAnimation = Tween<double>(begin: -1, end: 2).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
  }

  // Dispose resources
  void _disposeResources() {
    _refreshTimer?.cancel();
    _pulseController.dispose();
    _floatController.dispose();
    _shimmerController.dispose();
  }

  // Load order data
  Future<void> _loadOrder() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final order = await OrderStatusService.getOrderById(widget.orderId);

      if (mounted) {
        setState(() {
          _order = order;
          _isLoading = false;
        });

        _checkStatusChange();
        _startAnimations();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = ErrorHandler.handleError(e);
          _isLoading = false;
        });
      }
    }
  }

  // Start auto refresh for real-time updates
  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      if (mounted && _order != null && !_isUpdatingStatus) {
        _loadOrder();
      }
    });
  }

  // Check if order status changed
  void _checkStatusChange() {
    if (_order == null) return;

    final currentStatus = _order!.orderStatus;

    if (OrderStatusService.hasStatusChanged(_previousStatus, currentStatus)) {
      if (currentStatus == OrderStatus.cancelled) {
        OrderStatusWidgets.playCancelSound();
        _stopAnimations();
      } else {
        OrderStatusWidgets.playStatusChangeSound();
        _startAnimations();
      }
      _previousStatus = currentStatus;
    }
  }

  // Start animations based on order status
  void _startAnimations() {
    if (_order == null) return;

    final currentStatus = _order!.orderStatus;

    if (currentStatus == OrderStatus.pending) {
      _pulseController.repeat(reverse: true);
    }

    _floatController.repeat(reverse: true);
    _shimmerController.repeat();
  }

  // Stop all animations
  void _stopAnimations() {
    _pulseController.stop();
    _floatController.stop();
    _shimmerController.stop();
  }

  // Handle action pressed
  Future<void> _handleActionPressed(OrderAction action) async {
    if (_order == null || _isUpdatingStatus) return;

    // Call external handler if provided
    if (widget.onActionPressed != null) {
      widget.onActionPressed!(action);
      return;
    }

    // Handle action internally
    setState(() {
      _isUpdatingStatus = true;
    });

    try {
      OrderStatus newStatus;

      switch (action) {
        case OrderAction.confirm:
          newStatus = OrderStatus.confirmed;
          break;
        case OrderAction.startPreparing:
          newStatus = OrderStatus.preparing;
          break;
        case OrderAction.readyForPickup:
          newStatus = OrderStatus.readyForPickup;
          break;
        case OrderAction.pickup:
          newStatus = OrderStatus.onDelivery;
          break;
        case OrderAction.deliver:
          newStatus = OrderStatus.delivered;
          break;
        case OrderAction.cancel:
          await OrderStatusService.cancelOrder(_order!.id);
          await _loadOrder();
          return;
      }

      await OrderStatusService.updateOrderStatus(_order!.id, newStatus);
      await _loadOrder();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status pesanan berhasil diperbarui'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memperbarui status: ${ErrorHandler.handleError(e)}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingStatus = false;
        });
      }
    }
  }

  // Handle tap
  void _handleTap() {
    if (widget.onTap != null) {
      widget.onTap!();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Loading state
    if (_isLoading) {
      return OrderStatusWidgets.buildLoadingState();
    }

    // Error state
    if (_errorMessage != null) {
      return OrderStatusWidgets.buildErrorState(
        message: _errorMessage!,
        onRetry: _loadOrder,
      );
    }

    // No order state
    if (_order == null) {
      return OrderStatusWidgets.buildErrorState(
        message: 'Order tidak ditemukan',
        onRetry: _loadOrder,
      );
    }

    return Column(
      children: [
        // Main order status card
        Stack(
          children: [
            OrderStatusWidgets.buildOrderStatusCard(
              order: _order!,
              userRole: UserRole.driver,
              slideAnimation: widget.slideAnimation,
              pulseAnimation: _pulseAnimation,
              floatAnimation: _floatAnimation,
              shimmerAnimation: _shimmerAnimation,
              onTap: _handleTap,
            ),

            // Loading overlay when updating status
            if (_isUpdatingStatus)
              Positioned.fill(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),

        // Action buttons
        if (!_isUpdatingStatus)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: OrderStatusWidgets.buildOrderActions(
              order: _order!,
              userRole: UserRole.driver,
              onActionPressed: _handleActionPressed,
            ),
          ),
      ],
    );
  }
}