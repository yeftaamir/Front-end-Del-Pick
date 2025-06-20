// driver_order_status_card.dart
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Models/order.dart';
import 'package:del_pick/Models/order_enum.dart';
import 'package:del_pick/Services/order_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:ui';
import 'dart:math' as math;

class DriverOrderStatusCard extends StatefulWidget {
  final Map<String, dynamic> orderData;
  final Animation<Offset>? animation;
  final Function(Map<String, dynamic>)? onOrderUpdate;

  const DriverOrderStatusCard({
    Key? key,
    required this.orderData,
    this.animation,
    this.onOrderUpdate,
  }) : super(key: key);

  @override
  State<DriverOrderStatusCard> createState() => _DriverOrderStatusCardState();
}

class _DriverOrderStatusCardState extends State<DriverOrderStatusCard>
    with TickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  OrderStatus? _previousStatus;
  late AnimationController _pulseController;
  late AnimationController _floatController;
  late AnimationController _shimmerController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _floatAnimation;
  late Animation<double> _shimmerAnimation;

  // Updated color theme
  static const Color primaryColor = Color(0xff3E90E9);
  static const Color whiteColor = Colors.white;

  // State management for real-time updates
  Map<String, dynamic> _currentOrderData = {};
  bool _isRefreshing = false;

  // Driver status configuration updated to match backend enum
  final List<Map<String, dynamic>> _statusConfig = [
    {
      'status': OrderStatus.pending,
      'label': 'Menunggu',
      'description': 'Menunggu konfirmasi driver',
      'icon': Icons.schedule_rounded,
      'color': const Color(0xFFFF9800),
      'animation': 'assets/animations/loading_animation.json'
    },
    {
      'status': OrderStatus.confirmed,  // Updated from 'approved' to match backend
      'label': 'Diterima',
      'description': 'Pesanan diterima driver',
      'icon': Icons.assignment_turned_in_rounded,
      'color': primaryColor,
      'animation': 'assets/animations/diproses.json'
    },
    {
      'status': OrderStatus.preparing,
      'label': 'Ambil Pesanan',
      'description': 'Sedang mengambil pesanan',
      'icon': Icons.shopping_bag_rounded,
      'color': const Color(0xFF9C27B0),
      'animation': 'assets/animations/diambil.json'
    },
    {
      'status': OrderStatus.ready_for_pickup,  // Added new status from backend
      'label': 'Siap Diambil',
      'description': 'Pesanan siap untuk diambil',
      'icon': Icons.takeout_dining_rounded,
      'color': const Color(0xFF673AB7),
      'animation': 'assets/animations/siap_diambil.json'
    },
    {
      'status': OrderStatus.on_delivery,
      'label': 'Antar Pesanan',
      'description': 'Dalam perjalanan ke customer',
      'icon': Icons.directions_bike_rounded,
      'color': const Color(0xFF2196F3),
      'animation': 'assets/animations/diantar.json'
    },
    {
      'status': OrderStatus.delivered,
      'label': 'Terkirim',
      'description': 'Pesanan berhasil diantar',
      'icon': Icons.check_circle_rounded,
      'color': const Color(0xFF4CAF50),
      'animation': 'assets/animations/pesanan_selesai.json'
    },
  ];

  @override
  void initState() {
    super.initState();
    _currentOrderData = Map.from(widget.orderData);
    _initAnimations();
    _checkStatusChange();

    // Start periodic refresh for real-time updates
    _startPeriodicRefresh();
  }

  void _initAnimations() {
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

    final currentStatus = _getCurrentOrderStatus();
    _previousStatus = currentStatus;

    if (currentStatus == OrderStatus.cancelled) {
      _playCancelSound();
    } else {
      _startAnimations(currentStatus);
    }
  }

  void _startPeriodicRefresh() {
    // Refresh order status every 10 seconds for real-time updates
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        _refreshOrderStatus();
        _startPeriodicRefresh();
      }
    });
  }

  Future<void> _refreshOrderStatus() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      final orderId = _getOrderId();
      if (orderId.isNotEmpty) {
        final updatedOrderData = await OrderService.getOrderById(orderId);

        if (updatedOrderData.isNotEmpty && mounted) {
          final oldStatus = _getCurrentOrderStatus();

          setState(() {
            _currentOrderData = updatedOrderData;
          });

          final newStatus = _getCurrentOrderStatus();

          // Check for status change and trigger animations/sounds
          if (oldStatus != newStatus) {
            _checkStatusChange();

            // Notify parent component of order update
            if (widget.onOrderUpdate != null) {
              widget.onOrderUpdate!(_currentOrderData);
            }
          }
        }
      }
    } catch (e) {
      print('Error refreshing order status: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  void _startAnimations(OrderStatus status) {
    if (status == OrderStatus.pending) {
      _pulseController.repeat(reverse: true);
    }
    _floatController.repeat(reverse: true);
    _shimmerController.repeat();
  }

  void _checkStatusChange() {
    final currentStatus = _getCurrentOrderStatus();
    if (_previousStatus != currentStatus) {
      if (currentStatus == OrderStatus.cancelled) {
        _playCancelSound();
        _stopAnimations();
      } else {
        _playStatusChangeSound();
        _startAnimations(currentStatus);
      }
      _previousStatus = currentStatus;
    }
  }

  void _stopAnimations() {
    _pulseController.stop();
    _floatController.stop();
    _shimmerController.stop();
  }

  @override
  void didUpdateWidget(DriverOrderStatusCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderData != widget.orderData) {
      _currentOrderData = Map.from(widget.orderData);
      _checkStatusChange();
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _pulseController.dispose();
    _floatController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  OrderStatus _getCurrentOrderStatus() {
    final statusString = _currentOrderData['order_status'] ?? 'pending';
    return OrderStatus.fromString(statusString);
  }

  void _playStatusChangeSound() async {
    try {
      await _audioPlayer.play(AssetSource('audio/kring.mp3'));
    } catch (e) {
      print('Error playing status change sound: $e');
    }
  }

  void _playCancelSound() async {
    try {
      await _audioPlayer.play(AssetSource('audio/found.wav'));
    } catch (e) {
      print('Error playing cancel sound: $e');
    }
  }

  Map<String, dynamic> _getCurrentStatusInfo() {
    final currentStatus = _getCurrentOrderStatus();

    if (currentStatus == OrderStatus.cancelled) {
      return {
        'status': OrderStatus.cancelled,
        'label': 'Dibatalkan',
        'description': 'Pesanan telah dibatalkan',
        'icon': Icons.cancel_rounded,
        'color': const Color(0xFFE53E3E),
        'animation': 'assets/animations/cancel.json'
      };
    }

    return _statusConfig.firstWhere(
          (item) => item['status'] == currentStatus,
      orElse: () => _statusConfig[0],
    );
  }

  String _getCustomerName() {
    return _currentOrderData['customer']?['name'] ?? 'Customer';
  }

  String _getOrderId() {
    return _currentOrderData['id']?.toString() ?? '';
  }

  String _getStoreName() {
    return _currentOrderData['store']?['name'] ?? 'Store';
  }

  @override
  Widget build(BuildContext context) {
    final currentStatusInfo = _getCurrentStatusInfo();

    Widget content = AnimatedBuilder(
      animation: _floatAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _floatAnimation.value),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Stack(
              children: [
                // Background glow effect
                _buildBackgroundGlow(currentStatusInfo['color']),

                // Main glassmorphism card
                _buildMainCard(currentStatusInfo),

                // Refresh indicator
                if (_isRefreshing)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (widget.animation != null) {
      return SlideTransition(
        position: widget.animation!,
        child: content,
      );
    }

    return content;
  }

  Widget _buildBackgroundGlow(Color statusColor) {
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
              color: primaryColor.withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: -5,
              offset: const Offset(0, 4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainCard(Map<String, dynamic> statusInfo) {
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
                whiteColor.withOpacity(0.25),
                whiteColor.withOpacity(0.1),
                whiteColor.withOpacity(0.15),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: whiteColor.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with order info
                _buildHeader(),

                const SizedBox(height: 24),

                // Status animation and info
                _buildStatusSection(statusInfo),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor.withOpacity(0.8),
            primaryColor.withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Driver icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: whiteColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.delivery_dining_rounded,
              color: whiteColor,
              size: 24,
            ),
          ),

          const SizedBox(width: 16),

          // Order and customer info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedBuilder(
                  animation: _shimmerAnimation,
                  builder: (context, child) {
                    return ShaderMask(
                      shaderCallback: (bounds) {
                        return LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            whiteColor,
                            whiteColor.withOpacity(0.8),
                            whiteColor,
                          ],
                          stops: [
                            _shimmerAnimation.value - 1,
                            _shimmerAnimation.value,
                            _shimmerAnimation.value + 1,
                          ],
                        ).createShader(bounds);
                      },
                      child: Text(
                        'Order #${_getOrderId()}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: whiteColor,
                          fontFamily: GlobalStyle.fontFamily,
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 4),

                Text(
                  'Customer: ${_getCustomerName()}',
                  style: TextStyle(
                    fontSize: 14,
                    color: whiteColor.withOpacity(0.9),
                    fontFamily: GlobalStyle.fontFamily,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  'From: ${_getStoreName()}',
                  style: TextStyle(
                    fontSize: 12,
                    color: whiteColor.withOpacity(0.8),
                    fontFamily: GlobalStyle.fontFamily,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection(Map<String, dynamic> statusInfo) {
    return Column(
      children: [
        // Status animation
        _buildStatusAnimation(statusInfo),

        const SizedBox(height: 24),

        // Status info
        _buildStatusInfo(statusInfo),
      ],
    );
  }

  Widget _buildStatusAnimation(Map<String, dynamic> statusInfo) {
    return Container(
      width: 140,
      height: 140,
      child: Lottie.asset(
        statusInfo['animation'],
        fit: BoxFit.contain,
        repeat: _getCurrentOrderStatus() != OrderStatus.delivered,
        errorBuilder: (context, error, stackTrace) {
          // Fallback if animation fails to load
          return Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: statusInfo['color'].withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              statusInfo['icon'],
              color: statusInfo['color'],
              size: 60,
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusInfo(Map<String, dynamic> statusInfo) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            statusInfo['color'].withOpacity(0.1),
            statusInfo['color'].withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: statusInfo['color'].withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Status icon and label
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                statusInfo['icon'],
                color: statusInfo['color'],
                size: 28,
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  statusInfo['label'],
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: statusInfo['color'],
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Status description
          Text(
            statusInfo['description'],
            style: TextStyle(
              fontSize: 16,
              color: statusInfo['color'].withOpacity(0.8),
              fontFamily: GlobalStyle.fontFamily,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}