// lib/pages/stores/widgets/store_order_status_card.dart
import 'package:flutter/material.dart';
import 'dart:async';

import '../../../../Common/global_style.dart';
import '../../../../Models/Entities/order.dart';
import '../../../../Models/Enums/order_status.dart';
import '../../../../Models/Enums/user_role.dart';
import '../../../../Services/Order/order_status_service.dart';
import '../../../../Services/Utils/error_handler.dart';
import '../../Shared/order_status_widgets.dart';

class StoreOrderStatusCard extends StatefulWidget {
  final int orderId;
  final Animation<Offset>? slideAnimation;
  final VoidCallback? onTap;
  final Function(OrderAction)? onActionPressed;

  const StoreOrderStatusCard({
    super.key,
    required this.orderId,
    this.slideAnimation,
    this.onTap,
    this.onActionPressed,
  });

  @override
  State<StoreOrderStatusCard> createState() => _StoreOrderStatusCardState();
}

class _StoreOrderStatusCardState extends State<StoreOrderStatusCard>
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
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
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

  // Show confirmation dialog for critical actions
  Future<bool> _showConfirmationDialog(OrderAction action) async {
    String title;
    String message;
    Color actionColor;

    switch (action) {
      case OrderAction.confirm:
        title = 'Konfirmasi Pesanan';
        message = 'Apakah Anda yakin ingin mengkonfirmasi pesanan ini?';
        actionColor = Colors.green;
        break;
      case OrderAction.cancel:
        title = 'Batalkan Pesanan';
        message = 'Apakah Anda yakin ingin membatalkan pesanan ini? Tindakan ini tidak dapat dibatalkan.';
        actionColor = Colors.red;
        break;
      default:
        return true; // No confirmation needed for other actions
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          content: Text(
            message,
            style: TextStyle(
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Batal',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontFamily: GlobalStyle.fontFamily,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: actionColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                action == OrderAction.confirm ? 'Konfirmasi' : 'Batalkan',
                style: TextStyle(
                  fontFamily: GlobalStyle.fontFamily,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  // Handle action pressed
  Future<void> _handleActionPressed(OrderAction action) async {
    if (_order == null || _isUpdatingStatus) return;

    // Show confirmation for critical actions
    if (action == OrderAction.confirm || action == OrderAction.cancel) {
      final confirmed = await _showConfirmationDialog(action);
      if (!confirmed) return;
    }

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
      if (action == OrderAction.cancel) {
        await OrderStatusService.cancelOrder(_order!.id);
        await _loadOrder();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.cancel, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Pesanan berhasil dibatalkan'),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
        return;
      }

      OrderStatus newStatus;
      String successMessage;

      switch (action) {
        case OrderAction.confirm:
          newStatus = OrderStatus.confirmed;
          successMessage = 'Pesanan berhasil dikonfirmasi';
          break;
        case OrderAction.startPreparing:
          newStatus = OrderStatus.preparing;
          successMessage = 'Mulai mempersiapkan pesanan';
          break;
        case OrderAction.readyForPickup:
          newStatus = OrderStatus.readyForPickup;
          successMessage = 'Pesanan siap untuk diambil';
          break;
        default:
          throw Exception('Invalid action for store');
      }

      await OrderStatusService.updateOrderStatus(_order!.id, newStatus);
      await _loadOrder();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text(successMessage),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Gagal memperbarui status: ${ErrorHandler.handleError(e)}'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: Duration(seconds: 4),
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
              userRole: UserRole.store,
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
              userRole: UserRole.store,
              onActionPressed: _handleActionPressed,
            ),
          ),

        // Order details preview (for store management)
        if (_order != null && _order!.items != null && _order!.items!.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8, left: 16, right: 16, bottom: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detail Pesanan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
                const SizedBox(height: 12),
                ...(_order!.items!.take(3)).map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                      ),
                      Text(
                        '${item.quantity}x',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: GlobalStyle.primaryColor,
                          fontFamily: GlobalStyle.fontFamily,
                        ),
                      ),
                    ],
                  ),
                )),
                if (_order!.items!.length > 3)
                  Text(
                    '+${_order!.items!.length - 3} item lainnya',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                      fontFamily: GlobalStyle.fontFamily,
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: GlobalStyle.fontFamily,
                      ),
                    ),
                    Text(
                      GlobalStyle.formatRupiah(_order!.totalAmount),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: GlobalStyle.primaryColor,
                        fontFamily: GlobalStyle.fontFamily,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}