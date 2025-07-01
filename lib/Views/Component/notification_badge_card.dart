// lib/Views/Components/notification_badge_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:del_pick/Common/global_style.dart';

class NotificationBadgeCard extends StatefulWidget {
  final Map<String, dynamic> orderData;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;
  final bool isVisible;
  final Duration autoHideDuration;

  const NotificationBadgeCard({
    Key? key,
    required this.orderData,
    this.onTap,
    this.onDismiss,
    this.isVisible = true,
    this.autoHideDuration = const Duration(seconds: 8),
  }) : super(key: key);

  @override
  State<NotificationBadgeCard> createState() => _NotificationBadgeCardState();
}

class _NotificationBadgeCardState extends State<NotificationBadgeCard>
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

    final orderId = widget.orderData['id']?.toString() ?? '';
    final customerName = widget.orderData['customer']?['name'] ?? 'Customer';
    final totalAmount = _parseDouble(widget.orderData['total_amount']);
    final itemCount = widget.orderData['items']?.length ?? 0;
    final createdAt = widget.orderData['created_at'];

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
                      shadowColor: Colors.orange.withOpacity(0.3),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.orange.shade400,
                              Colors.orange.shade600,
                              Colors.deepOrange.shade500,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withOpacity(0.4),
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
                                        // New order badge dengan animasi
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            borderRadius: BorderRadius.circular(20),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.red.withOpacity(0.4),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.new_releases,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'PESANAN BARU!',
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

                                    // Order info
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            Icons.shopping_bag,
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
                                                customerName,
                                                style: TextStyle(
                                                  color: Colors.white.withOpacity(0.9),
                                                  fontSize: 14,
                                                  fontFamily: GlobalStyle.fontFamily,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Amount badge
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
                                          child: Text(
                                            GlobalStyle.formatRupiah(totalAmount),
                                            style: TextStyle(
                                              color: Colors.orange.shade700,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: GlobalStyle.fontFamily,
                                            ),
                                          ),
                                        ),
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
                                            '$itemCount item pesanan',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.9),
                                              fontSize: 13,
                                              fontFamily: GlobalStyle.fontFamily,
                                            ),
                                          ),

                                          const Spacer(),

                                          Icon(
                                            Icons.access_time,
                                            color: Colors.white.withOpacity(0.9),
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),

                                          Text(
                                            createdAt != null
                                                ? DateFormat('HH:mm').format(
                                                DateTime.parse(createdAt))
                                                : 'Baru saja',
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
                                              color: Colors.orange.shade700,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),

                                            Text(
                                              'Lihat Pesanan',
                                              style: TextStyle(
                                                color: Colors.orange.shade700,
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