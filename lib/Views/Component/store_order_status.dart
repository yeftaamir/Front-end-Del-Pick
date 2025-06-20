// store_order_status_card.dart
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Models/order.dart';
import 'package:del_pick/Models/order_enum.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:ui';
import 'dart:math' as math;

class StoreOrderStatusCard extends StatefulWidget {
  final Map<String, dynamic> orderData;
  final Animation<Offset>? animation;

  const StoreOrderStatusCard({
    Key? key,
    required this.orderData,
    this.animation,
  }) : super(key: key);

  @override
  State<StoreOrderStatusCard> createState() => _StoreOrderStatusCardState();
}

class _StoreOrderStatusCardState extends State<StoreOrderStatusCard>
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

  // Store status configuration with new color scheme
  final List<Map<String, dynamic>> _statusConfig = [
    {
      'status': OrderStatus.pending,
      'label': 'Pesanan Baru',
      'description': 'Menunggu konfirmasi toko',
      'icon': Icons.notification_important_rounded,
      'color': const Color(0xFFFF9800),
      'animation': 'assets/animations/loading_animation.json'
    },
    {
      'status': OrderStatus.approved,
      'label': 'Dikonfirmasi',
      'description': 'Pesanan diterima toko',
      'icon': Icons.thumb_up_rounded,
      'color': primaryColor,
      'animation': 'assets/animations/diproses.json'
    },
    {
      'status': OrderStatus.preparing,
      'label': 'Disiapkan',
      'description': 'Sedang mempersiapkan pesanan',
      'icon': Icons.restaurant_menu_rounded,
      'color': const Color(0xFF9C27B0),
      'animation': 'assets/animations/diambil.json'
    },
    {
      'status': OrderStatus.on_delivery,
      'label': 'Dikirim',
      'description': 'Pesanan dalam perjalanan',
      'icon': Icons.local_shipping_rounded,
      'color': const Color(0xFF2196F3),
      'animation': 'assets/animations/diantar.json'
    },
    {
      'status': OrderStatus.delivered,
      'label': 'Terkirim',
      'description': 'Pesanan berhasil diterima',
      'icon': Icons.done_all_rounded,
      'color': const Color(0xFF4CAF50),
      'animation': 'assets/animations/pesanan_selesai.json'
    },
  ];

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _checkStatusChange();
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
  void didUpdateWidget(StoreOrderStatusCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkStatusChange();
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
    final statusString = widget.orderData['order_status'] ?? 'pending';
    return OrderStatus.fromString(statusString);
  }

  void _playStatusChangeSound() async {
    await _audioPlayer.play(AssetSource('audio/kring.mp3'));
  }

  void _playCancelSound() async {
    await _audioPlayer.play(AssetSource('audio/found.wav'));
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
    return widget.orderData['customer']?['name'] ?? 'Customer';
  }

  String _getOrderId() {
    return widget.orderData['id']?.toString() ?? '';
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
          // Store icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: whiteColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.store_rounded,
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

// Perbaikan untuk CustomerOrderStatusCard, DriverOrderStatusCard, dan StoreOrderStatusCard
// Ganti method _buildStatusAnimation dengan kode berikut:

  // Widget _buildStatusAnimation(Map<String, dynamic> statusInfo) {
  //   return Stack(
  //     alignment: Alignment.center,
  //     children: [
  //       // Background glow effect (opsional untuk efek visual)
  //       AnimatedBuilder(
  //         animation: _pulseAnimation,
  //         builder: (context, child) {
  //           return Container(
  //             width: 180,
  //             height: 180,
  //             decoration: BoxDecoration(
  //               shape: BoxShape.circle,
  //               gradient: RadialGradient(
  //                 colors: [
  //                   statusInfo['color'].withOpacity(0.1),
  //                   statusInfo['color'].withOpacity(0.05),
  //                   Colors.transparent,
  //                 ],
  //                 stops: const [0.0, 0.6, 1.0],
  //               ),
  //             ),
  //           );
  //         },
  //       ),
  //
  //       // Clean animation without container
  //       Container(
  //         width: 140,
  //         height: 140,
  //         child: Lottie.asset(
  //           statusInfo['animation'],
  //           fit: BoxFit.contain,
  //           repeat: _getCurrentOrderStatus() != OrderStatus.delivered,
  //         ),
  //       ),
  //     ],
  //   );
  // }

// ATAU jika ingin benar-benar tanpa efek circle sama sekali:

  Widget _buildStatusAnimation(Map<String, dynamic> statusInfo) {
    return Container(
      width: 140,
      height: 140,
      child: Lottie.asset(
        statusInfo['animation'],
        fit: BoxFit.contain,
        repeat: _getCurrentOrderStatus() != OrderStatus.delivered,
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
              Text(
                statusInfo['label'],
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: statusInfo['color'],
                  fontFamily: GlobalStyle.fontFamily,
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