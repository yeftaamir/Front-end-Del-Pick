// lib/Features/Pages/Customers/cart_screen.dart
import 'package:del_pick/Features/Pages/Customers/track_cust_order.dart';
import 'package:del_pick/Models/Extensions/cart_extensions.dart';
import 'package:flutter/material.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Models/Entities/order.dart';
import 'package:del_pick/Models/Entities/store.dart';
import 'package:del_pick/Models/Entities/menu_item.dart';
import 'package:del_pick/Models/Entities/driver.dart';
import 'package:del_pick/Models/Responses/order_responses.dart';
import 'package:del_pick/Services/Utils/error_handler.dart';
import 'package:del_pick/Services/Utils/cart_manager.dart';

import '../../../Services/Customer/cart_services.dart';
import 'Widgets/card_confirmation_modal.dart';
import 'Widgets/cart_widgets.dart';
import 'Widgets/rating_modal.dart';
import 'Widgets/customer_order_status_card.dart';
import 'location_access.dart';

class CartScreen extends StatefulWidget {
  static const String route = "/Customers/Cart";
  final Store store;
  final List<CartItem> cartItems;
  final Order? completedOrder;

  const CartScreen({
    Key? key,
    required this.store,
    required this.cartItems,
    this.completedOrder,
  }) : super(key: key);

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> with TickerProviderStateMixin {
  // Data state
  Order? _currentOrder;
  Driver? _assignedDriver;
  String? _deliveryAddress;
  bool _isLoading = false;
  bool _hasGivenRating = false;
  String? _errorMessage;

  // Animation controllers
  late AnimationController _slideController;
  late List<AnimationController> _cardControllers;
  late List<Animation<Offset>> _cardAnimations;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeData();
  }

  @override
  void dispose() {
    _slideController.dispose();
    for (var controller in _cardControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _cardControllers = List.generate(
      4,
          (index) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 600 + (index * 200)),
      ),
    );

    _cardAnimations = _cardControllers.map((controller) {
      return Tween<Offset>(
        begin: const Offset(0, -0.5),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeOutCubic,
      ));
    }).toList();

    // Start animations
    Future.delayed(const Duration(milliseconds: 100), () {
      for (var controller in _cardControllers) {
        controller.forward();
      }
    });
  }

  void _initializeData() {
    if (widget.completedOrder != null) {
      _currentOrder = widget.completedOrder;
      _deliveryAddress = widget.completedOrder!.store?.address;
      _loadDriverInfo();
    }
  }

  Future<void> _loadDriverInfo() async {
    if (_currentOrder?.driverId != null) {
      try {
        final driver = await CartService.getDriverInfo(_currentOrder!.driverId!);
        if (mounted) {
          setState(() {
            _assignedDriver = driver;
          });
        }
      } catch (e) {
        print('Error loading driver info: $e');
      }
    }
  }

  Future<void> _handleLocationAccess() async {
    final result = await Navigator.pushNamed(
      context,
      LocationAccessScreen.route,
    );

    if (result is Map<String, dynamic>) {
      setState(() {
        _deliveryAddress = result['address'];
        _errorMessage = null;
      });
    }
  }

  Future<void> _showOrderConfirmation() async {
    if (_deliveryAddress == null) {
      CartWidgets.showNoAddressDialog(context, _handleLocationAccess);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => OrderConfirmationModal(
        store: widget.store,
        cartItems: widget.cartItems,
        deliveryAddress: _deliveryAddress!,
        onConfirm: () => Navigator.of(context).pop(true),
        onCancel: () => Navigator.of(context).pop(false),
        onContactStore: () => _contactStore(),
      ),
    );

    if (confirmed == true) {
      await _createOrder();
    }
  }

  Future<void> _createOrder() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Show creating order dialog
      CartWidgets.showCreatingOrderDialog(context);

      // Create order using CartService
      final order = await CartService.createOrderFromCart(
        storeId: widget.store.id,
        cartItems: widget.cartItems,
        deliveryAddress: _deliveryAddress!,
      );

      // Close creating order dialog
      if (mounted) Navigator.of(context).pop();

      // Show order success
      await CartWidgets.showOrderSuccessDialog(context);

      // Clear cart and update state
      await CartManager.clearCart();

      setState(() {
        _currentOrder = order;
        _isLoading = false;
      });

      // Start monitoring order status
      _startOrderMonitoring();

    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close creating order dialog
        setState(() {
          _errorMessage = ErrorHandler.handleError(e);
          _isLoading = false;
        });
        CartWidgets.showErrorDialog(context, _errorMessage!);
      }
    }
  }

  void _startOrderMonitoring() {
    if (_currentOrder == null) return;

    // Monitor order status every 30 seconds
    Future.delayed(const Duration(seconds: 30), () {
      _checkOrderStatus();
    });
  }

  Future<void> _checkOrderStatus() async {
    if (_currentOrder == null || !mounted) return;

    try {
      final updatedOrder = await CartService.getOrderStatus(_currentOrder!.id);

      if (mounted && updatedOrder.id == _currentOrder!.id) {
        final previousStatus = _currentOrder!.orderStatus;
        setState(() {
          _currentOrder = updatedOrder;
        });

        // Check if driver was assigned
        if (updatedOrder.driverId != null && _assignedDriver == null) {
          _loadDriverInfo();
        }

        // Play sound for status changes
        if (previousStatus != updatedOrder.orderStatus) {
          CartWidgets.playStatusChangeSound();
        }

        // Continue monitoring if order is still active
        if (updatedOrder.isActive) {
          _startOrderMonitoring();
        }
      }
    } catch (e) {
      print('Error checking order status: $e');
      if (mounted) {
        _startOrderMonitoring(); // Continue monitoring despite error
      }
    }
  }

  Future<void> _cancelOrder() async {
    if (_currentOrder == null) return;

    final confirmed = await CartWidgets.showCancelConfirmationDialog(context);
    if (!confirmed) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final cancelledOrder = await CartService.cancelOrder(_currentOrder!.id);

      setState(() {
        _currentOrder = cancelledOrder;
        _isLoading = false;
      });

      CartWidgets.showOrderCancelledDialog(context);

    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      CartWidgets.showErrorDialog(context, ErrorHandler.handleError(e));
    }
  }

  Future<void> _showRatingModal() async {
    if (_currentOrder == null || _assignedDriver == null) return;

    final ratingResult = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => RatingModal(
        storeName: widget.store.name,
        driverName: _assignedDriver!.user?.name ?? 'Driver',
        orderId: _currentOrder!.id,
      ),
    );

    if (ratingResult != null) {
      try {
        await CartService.submitReview(
          _currentOrder!.id,
          ratingResult,
        );

        setState(() {
          _hasGivenRating = true;
        });

        CartWidgets.showRatingSuccessDialog(context);

      } catch (e) {
        CartWidgets.showErrorDialog(context, ErrorHandler.handleError(e));
      }
    }
  }

  Future<void> _buyAgain() async {
    try {
      // Add items back to cart
      for (var cartItem in widget.cartItems) {
        await CartManager.addItem(cartItem);
      }

      // Navigate back to store detail or menu
      Navigator.of(context).pop();

    } catch (e) {
      CartWidgets.showErrorDialog(context, ErrorHandler.handleError(e));
    }
  }

  void _contactStore() {
    CartService.contactStoreWhatsApp(
      widget.store.phone,
      widget.store.name,
      widget.cartItems,
    );
  }

  void _navigateToTracking() {
    if (_currentOrder == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TrackCustOrderScreen(
          order: _currentOrder!,
        ),
      ),
    );
  }

  void _callDriver() {
    if (_assignedDriver?.user?.phone != null) {
      CartService.callDriver(_assignedDriver!.user!.phone!);
    }
  }

  void _messageDriver() {
    if (_assignedDriver?.user?.phone != null) {
      CartService.messageDriver(
        _assignedDriver!.user!.phone!,
        _currentOrder!.id.toString(),
      );
    }
  }

  // Calculate totals
  double get subtotal {
    if (widget.completedOrder != null) {
      return widget.completedOrder!.totalAmount - widget.completedOrder!.deliveryFee;
    }
    return widget.cartItems.fold(0, (sum, item) => sum + item.totalPrice);
  }

  double get deliveryFee {
    if (widget.completedOrder != null) {
      return widget.completedOrder!.deliveryFee;
    }
    return CartService.calculateDeliveryFee(widget.cartItems);
  }

  double get total {
    return subtotal + deliveryFee;
  }

  bool get isCompletedOrder {
    return widget.completedOrder != null;
  }

  bool get isActiveBranch {
    return _currentOrder != null && _currentOrder!.isActive;
  }

  bool get canCancelOrder {
    return _currentOrder != null && _currentOrder!.canBeCancelled;
  }

  bool get canTrackOrder {
    return _currentOrder != null &&
        _currentOrder!.isActive &&
        _assignedDriver != null;
  }

  bool get canShowRating {
    return _currentOrder != null &&
        _currentOrder!.isCompleted &&
        !_hasGivenRating;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffD6E6F2),
      appBar: CartWidgets.buildAppBar(
        context: context,
        isCompletedOrder: isCompletedOrder,
        orderStatus: _currentOrder?.orderStatus,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (widget.cartItems.isEmpty && !isCompletedOrder) {
      return CartWidgets.buildEmptyCart();
    }

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Order status card (for active orders)
            if (_currentOrder != null && !isCompletedOrder)
              CustomerOrderStatusCard(
                orderId: _currentOrder!.id,
                slideAnimation: _cardAnimations[0],
                onTap: canTrackOrder ? _navigateToTracking : null,
              ),

            // Driver information
            if (_assignedDriver != null)
              CartWidgets.buildDriverCard(
                driver: _assignedDriver!,
                animation: _cardAnimations[1],
                onCall: _callDriver,
                onMessage: _messageDriver,
                onTrack: canTrackOrder ? _navigateToTracking : null,
              ),

            // Order date (for completed orders)
            if (isCompletedOrder)
              CartWidgets.buildOrderDateCard(
                orderDate: widget.completedOrder!.createdAt,
                animation: _cardAnimations[0],
              ),

            // Order items
            CartWidgets.buildOrderItemsCard(
              store: widget.store,
              cartItems: widget.cartItems,
              orderStatus: _currentOrder?.orderStatus,
              animation: _cardAnimations[isCompletedOrder ? 1 : 2],
            ),

            // Delivery address
            CartWidgets.buildDeliveryAddressCard(
              deliveryAddress: _deliveryAddress,
              isCompletedOrder: isCompletedOrder,
              onLocationAccess: _handleLocationAccess,
              errorMessage: _errorMessage,
              animation: _cardAnimations[isCompletedOrder ? 2 : 3],
            ),

            // Payment details
            CartWidgets.buildPaymentDetailsCard(
              subtotal: subtotal,
              deliveryFee: deliveryFee,
              total: total,
              animation: _cardAnimations[isCompletedOrder ? 3 : 4],
            ),

            // Action buttons for completed orders
            if (isCompletedOrder)
              CartWidgets.buildCompletedOrderActions(
                canShowRating: canShowRating,
                orderStatus: _currentOrder?.orderStatus,
                onRating: _showRatingModal,
                onBuyAgain: _buyAgain,
                animation: _cardAnimations[4],
              ),

            // Cancel button for active orders
            if (canCancelOrder)
              CartWidgets.buildCancelOrderButton(
                onCancel: _cancelOrder,
                isLoading: _isLoading,
                animation: _cardAnimations[5],
              ),

            // Bottom spacing
            if (!isCompletedOrder && _currentOrder == null)
              const SizedBox(height: 100),
          ],
        ),

        // Create order button (for new orders)
        if (!isCompletedOrder && _currentOrder == null)
          CartWidgets.buildCreateOrderButton(
            total: total,
            isLoading: _isLoading,
            onCreateOrder: _showOrderConfirmation,
          ),

        // Loading overlay
        if (_isLoading)
          CartWidgets.buildLoadingOverlay(),
      ],
    );
  }
}