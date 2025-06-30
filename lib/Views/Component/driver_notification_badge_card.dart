// lib/Views/Components/driver_notification_badge_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:del_pick/Common/global_style.dart';

class DriverNotificationBadgeCard extends StatefulWidget {
  final Map<String, dynamic> requestData;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;
  final bool isVisible;
  final Duration autoHideDuration;

  const DriverNotificationBadgeCard({
    Key? key,
    required this.requestData,
    this.onTap,
    this.onDismiss,
    this.isVisible = true,
    this.autoHideDuration = const Duration(seconds: 8),
  }) : super(key: key);

  @override
  State<DriverNotificationBadgeCard> createState() => _DriverNotificationBadgeCardState();
}

class _DriverNotificationBadgeCardState extends State<DriverNotificationBadgeCard>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late AnimationController _shakeController;

  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();

    if (widget.isVisible) {
      _showNotification();
    }
  }

  void _initializeAnimations() {
    // Slide animation untuk masuk dari atas
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));

    // Pulse animation untuk efek berdenyut
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Shake animation untuk menarik perhatian
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _shakeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticInOut,
    ));
  }

  void _showNotification() {
    _slideController.forward();

    // Start pulse animation setelah slide selesai
    _slideController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _pulseController.repeat(reverse: true);

        // Shake animation untuk menarik perhatian
        Future.delayed(const Duration(milliseconds: 300), () {
          _shakeController.forward().then((_) {
            _shakeController.reverse();
          });
        });
      }
    });

    // Auto hide setelah duration
    Future.delayed(widget.autoHideDuration, () {
      if (mounted) {
        _hideNotification();
      }
    });
  }

  void _hideNotification() {
    _pulseController.stop();
    _slideController.reverse().then((_) {
      if (widget.onDismiss != null) {
        widget.onDismiss!();
      }
    });
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  void dispose() {
    _slideController.dispose();
    _pulseController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return const SizedBox.shrink();

    // Parse request data
    final requestId = widget.requestData['id']?.toString() ?? '';
    final order = widget.requestData['order'] ?? {};
    final orderId = order['id']?.toString() ?? '';
    final customerName = order['customer']?['name'] ?? order['user']?['name'] ?? 'Customer';
    final storeName = order['store']?['name'] ?? 'Store';
    final totalAmount = _parseDouble(order['total_amount'] ?? order['totalAmount'] ?? order['total']);
    final deliveryFee = _parseDouble(order['delivery_fee'] ?? order['deliveryFee']);
    final orderStatus = order['order_status'] ?? '';
    final deliveryStatus = order['delivery_status'] ?? '';
    final createdAt = widget.requestData['created_at'];

    // Calculate potential earnings (delivery fee + 5% commission)
    final potentialEarnings = deliveryFee + (totalAmount * 0.05);

    return SlideTransition(
      position: _slideAnimation,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(
                    15 * _shakeAnimation.value *
                        (0.5 - ((_shakeAnimation.value * 4) % 1 - 0.5).abs()),
                    0,
                  ),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Material(
                      elevation: 12,
                      borderRadius: BorderRadius.circular(20),
                      shadowColor: Colors.blue.withOpacity(0.3),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.blue.shade500,
                              Colors.blue.shade600,
                              Colors.indigo.shade500,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.4),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                            BoxShadow(
                              color: Colors.white.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(-5, -5),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Stack(
                            children: [
                              // Background pattern
                              Positioned(
                                right: -20,
                                top: -20,
                                child: Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(0.1),
                                  ),
                                ),
                              ),

                              // Main content
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Header dengan badge dan close button
                                    Row(
                                      children: [
                                        // New delivery request badge dengan animasi
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green,
                                            borderRadius: BorderRadius.circular(20),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.green.withOpacity(0.4),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.local_shipping,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'ORDER BARU!',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        const Spacer(),

                                        // Close button
                                        GestureDetector(
                                          onTap: _hideNotification,
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.2),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.close,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 12),

                                    // Delivery request info
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            Icons.delivery_dining,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                        ),

                                        const SizedBox(width: 12),

                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Order #$orderId',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  fontFamily: GlobalStyle.fontFamily,
                                                ),
                                              ),

                                              const SizedBox(height: 2),

                                              Text(
                                                'Customer: $customerName',
                                                style: TextStyle(
                                                  color: Colors.white.withOpacity(0.9),
                                                  fontSize: 13,
                                                  fontFamily: GlobalStyle.fontFamily,
                                                ),
                                              ),

                                              Text(
                                                'Store: $storeName',
                                                style: TextStyle(
                                                  color: Colors.white.withOpacity(0.9),
                                                  fontSize: 13,
                                                  fontFamily: GlobalStyle.fontFamily,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Potential earnings badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(12),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.1),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            children: [
                                              Text(
                                                'Est. Earning',
                                                style: TextStyle(
                                                  color: Colors.blue.shade600,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w500,
                                                  fontFamily: GlobalStyle.fontFamily,
                                                ),
                                              ),
                                              Text(
                                                GlobalStyle.formatRupiah(potentialEarnings),
                                                style: TextStyle(
                                                  color: Colors.blue.shade700,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  fontFamily: GlobalStyle.fontFamily,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 12),

                                    // Order status indicators
                                    Row(
                                      children: [
                                        // Order Status Badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: orderStatus == 'preparing'
                                                ? Colors.orange
                                                : Colors.grey[600],
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            orderStatus == 'preparing' ? 'Preparing' : 'Pending',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        // Delivery Status Badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            'Delivery: ${deliveryStatus.toUpperCase()}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),

                                        const Spacer(),

                                        // Time info
                                        if (createdAt != null) ...[
                                          Icon(
                                            Icons.access_time,
                                            color: Colors.white.withOpacity(0.9),
                                            size: 14,
                                          ),
                                          const SizedBox(width: 4),

                                          Text(
                                            DateFormat('HH:mm').format(
                                                DateTime.parse(createdAt)),
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.9),
                                              fontSize: 12,
                                              fontFamily: GlobalStyle.fontFamily,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),

                                    const SizedBox(height: 12),

                                    // Order details
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.shopping_cart,
                                            color: Colors.white.withOpacity(0.9),
                                            size: 16,
                                          ),
                                          const SizedBox(width: 6),

                                          Text(
                                            'Total: ${GlobalStyle.formatRupiah(totalAmount)}',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.9),
                                              fontSize: 13,
                                              fontFamily: GlobalStyle.fontFamily,
                                            ),
                                          ),

                                          const Spacer(),

                                          Icon(
                                            Icons.local_shipping,
                                            color: Colors.white.withOpacity(0.9),
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),

                                          Text(
                                            'Fee: ${GlobalStyle.formatRupiah(deliveryFee)}',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.9),
                                              fontSize: 13,
                                              fontFamily: GlobalStyle.fontFamily,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 12),

                                    // Action button
                                    GestureDetector(
                                      onTap: () {
                                        _hideNotification();
                                        if (widget.onTap != null) {
                                          widget.onTap!();
                                        }
                                      },
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.1),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.visibility,
                                              color: Colors.blue.shade700,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),

                                            Text(
                                              'Lihat Permintaan',
                                              style: TextStyle(
                                                color: Colors.blue.shade700,
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                fontFamily: GlobalStyle.fontFamily,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}