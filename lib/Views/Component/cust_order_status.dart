// customer_order_status_card.dart
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Models/order.dart';
import 'package:del_pick/Models/order_enum.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:ui';
import 'dart:math' as math;

class CustomerOrderStatusCard extends StatefulWidget {
  final Map<String, dynamic> orderData;
  final Animation<Offset>? animation;

  const CustomerOrderStatusCard({
    Key? key,
    required this.orderData,
    this.animation,
  }) : super(key: key);

  @override
  State<CustomerOrderStatusCard> createState() => _CustomerOrderStatusCardState();
}

class _CustomerOrderStatusCardState extends State<CustomerOrderStatusCard>
    with TickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  OrderStatus? _previousStatus;
  late AnimationController _pulseController;
  late AnimationController _floatController;
  late AnimationController _rotateController;
  late AnimationController _shimmerController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _floatAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _shimmerAnimation;

  // Enhanced color palette
  final List<Color> _gradientColors = [
    const Color(0xFF667EEA),
    const Color(0xFF764BA2),
    const Color(0xFFF093FB),
  ];

  // Status timeline for customer with enhanced visuals
  final List<Map<String, dynamic>> _statusTimeline = [
    {
      'status': OrderStatus.pending,
      'label': 'Menunggu',
      'description': 'Menunggu konfirmasi toko',
      'icon': Icons.hourglass_empty,
      'color': const Color(0xFFFF6B6B),
      'gradient': [const Color(0xFFFF6B6B), const Color(0xFFFFE66D)],
      'animation': 'assets/animations/loading_animation.json'
    },
    {
      'status': OrderStatus.approved,
      'label': 'Dikonfirmasi',
      'description': 'Pesanan dikonfirmasi toko',
      'icon': Icons.check_circle_outline,
      'color': const Color(0xFF4ECDC4),
      'gradient': [const Color(0xFF4ECDC4), const Color(0xFF44A3AA)],
      'animation': 'assets/animations/diproses.json'
    },
    {
      'status': OrderStatus.preparing,
      'label': 'Disiapkan',
      'description': 'Pesanan sedang disiapkan',
      'icon': Icons.restaurant,
      'color': const Color(0xFF9B59B6),
      'gradient': [const Color(0xFF9B59B6), const Color(0xFF8E44AD)],
      'animation': 'assets/animations/diambil.json'
    },
    {
      'status': OrderStatus.on_delivery,
      'label': 'Dikirim',
      'description': 'Pesanan dalam perjalanan',
      'icon': Icons.delivery_dining,
      'color': const Color(0xFF3498DB),
      'gradient': [const Color(0xFF3498DB), const Color(0xFF2980B9)],
      'animation': 'assets/animations/diantar.json'
    },
    {
      'status': OrderStatus.delivered,
      'label': 'Selesai',
      'description': 'Pesanan telah diterima',
      'icon': Icons.celebration,
      'color': const Color(0xFF27AE60),
      'gradient': [const Color(0xFF27AE60), const Color(0xFF229954)],
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
    _rotateController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    );
    _shimmerController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _floatAnimation = Tween<double>(begin: -10, end: 10).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
    _rotateAnimation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.linear),
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
    _rotateController.repeat();
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
    _rotateController.stop();
    _shimmerController.stop();
  }

  @override
  void didUpdateWidget(CustomerOrderStatusCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkStatusChange();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _pulseController.dispose();
    _floatController.dispose();
    _rotateController.dispose();
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
        'icon': Icons.cancel_outlined,
        'color': const Color(0xFFE74C3C),
        'gradient': [const Color(0xFFE74C3C), const Color(0xFFC0392B)],
        'animation': 'assets/animations/cancel.json'
      };
    }

    return _statusTimeline.firstWhere(
          (item) => item['status'] == currentStatus,
      orElse: () => _statusTimeline[0],
    );
  }

  int _getCurrentStatusIndex() {
    final currentStatus = _getCurrentOrderStatus();
    return _statusTimeline.indexWhere((item) => item['status'] == currentStatus);
  }

  @override
  Widget build(BuildContext context) {
    final currentStatusInfo = _getCurrentStatusInfo();
    final currentStatus = _getCurrentOrderStatus();
    final currentIndex = _getCurrentStatusIndex();

    Widget content = AnimatedBuilder(
      animation: _floatAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _floatAnimation.value),
          child: Container(
            margin: const EdgeInsets.all(16),
            child: Stack(
              children: [
                // Animated background shapes
                _buildBackgroundShapes(),

                // Main card with glassmorphism
                ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.2),
                            Colors.white.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: currentStatusInfo['color'].withOpacity(0.3),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Modern header with gradient mesh
                          _buildModernHeader(currentStatusInfo),

                          // Content with enhanced visuals
                          _buildContent(currentStatusInfo, currentStatus, currentIndex),
                        ],
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

  Widget _buildBackgroundShapes() {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _rotateAnimation,
        builder: (context, child) {
          return Stack(
            children: [
              // Floating circles
              Positioned(
                top: -50,
                right: -50,
                child: Transform.rotate(
                  angle: _rotateAnimation.value,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _gradientColors[0].withOpacity(0.3),
                          _gradientColors[0].withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -30,
                left: -30,
                child: Transform.rotate(
                  angle: -_rotateAnimation.value,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _gradientColors[1].withOpacity(0.3),
                          _gradientColors[1].withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildModernHeader(Map<String, dynamic> statusInfo) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: statusInfo['gradient'],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Animated icon container
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Icon(
                        statusInfo['icon'],
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 16),
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
                                Colors.white,
                                Colors.white.withOpacity(0.8),
                                Colors.white,
                              ],
                              stops: [
                                _shimmerAnimation.value - 1,
                                _shimmerAnimation.value,
                                _shimmerAnimation.value + 1,
                              ],
                            ).createShader(bounds);
                          },
                          child: Text(
                            statusInfo['label'],
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontFamily: GlobalStyle.fontFamily,
                              letterSpacing: 1.2,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Order #${widget.orderData['id']}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.95),
                          fontFamily: GlobalStyle.fontFamily,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Order time indicator
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(Icons.access_time, color: Colors.white, size: 20),
                    const SizedBox(height: 4),
                    Text(
                      _getOrderTime(),
                      style: TextStyle(
                        color: Colors.white,
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
        ],
      ),
    );
  }

  Widget _buildContent(Map<String, dynamic> statusInfo, OrderStatus currentStatus, int currentIndex) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Enhanced Lottie animation with effects
          Stack(
            alignment: Alignment.center,
            children: [
              // Glow effect
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: statusInfo['color'].withOpacity(0.4),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
              ),
              // Animation container
              Container(
                height: 180,
                width: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.1),
                      Colors.white.withOpacity(0.05),
                    ],
                  ),
                  border: Border.all(
                    color: statusInfo['color'].withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(90),
                  child: Lottie.asset(
                    statusInfo['animation'],
                    repeat: currentStatus != OrderStatus.delivered,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Modern status timeline
          if (currentStatus != OrderStatus.cancelled)
            _buildModernTimeline(currentIndex),

          const SizedBox(height: 32),

          // Status description with glassmorphism
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  statusInfo['color'].withOpacity(0.1),
                  statusInfo['color'].withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: statusInfo['color'].withOpacity(0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: statusInfo['color'].withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      statusInfo['icon'],
                      color: statusInfo['color'],
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      statusInfo['description'],
                      style: TextStyle(
                        color: statusInfo['color'],
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: GlobalStyle.fontFamily,
                      ),
                    ),
                  ],
                ),
                if (widget.orderData['estimatedDeliveryTime'] != null &&
                    currentStatus != OrderStatus.delivered &&
                    currentStatus != OrderStatus.cancelled)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _buildEstimatedTime(),
                  ),
              ],
            ),
          ),

          // Additional info cards
          const SizedBox(height: 16),
          _buildInfoCards(currentStatus),
        ],
      ),
    );
  }

  Widget _buildModernTimeline(int currentIndex) {
    return Container(
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Progress line background
          Positioned(
            top: 20,
            left: 40,
            right: 40,
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Animated progress line
          Positioned(
            top: 20,
            left: 40,
            right: 40,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final progressWidth = (width / (_statusTimeline.length - 1)) * currentIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 800),
                  height: 4,
                  width: progressWidth,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _statusTimeline[0]['color'],
                        _statusTimeline[currentIndex]['color'],
                      ],
                    ),
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: _statusTimeline[currentIndex]['color'].withOpacity(0.5),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Timeline items
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_statusTimeline.length, (index) {
              final isActive = index <= currentIndex;
              final isCurrent = index == currentIndex;
              final item = _statusTimeline[index];

              return _buildTimelineItem(item, isActive, isCurrent);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(Map<String, dynamic> item, bool isActive, bool isCurrent) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: isCurrent ? 44 : 36,
          height: isCurrent ? 44 : 36,
          decoration: BoxDecoration(
            gradient: isActive
                ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: item['gradient'],
            )
                : null,
            color: !isActive ? Colors.grey[300] : null,
            shape: BoxShape.circle,
            boxShadow: isCurrent
                ? [
              BoxShadow(
                color: item['color'].withOpacity(0.4),
                blurRadius: 15,
                spreadRadius: 3,
              ),
            ]
                : [],
          ),
          child: Icon(
            item['icon'],
            color: Colors.white,
            size: isCurrent ? 24 : 18,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          item['label'],
          style: TextStyle(
            fontSize: 11,
            color: isActive ? item['color'] : Colors.grey,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            fontFamily: GlobalStyle.fontFamily,
          ),
        ),
      ],
    );
  }

  Widget _buildEstimatedTime() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.withOpacity(0.1),
            Colors.blue.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.blue.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule, size: 18, color: Colors.blue),
          const SizedBox(width: 8),
          Text(
            'Estimasi tiba: ${_formatEstimatedTime()}',
            style: TextStyle(
              color: Colors.blue,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCards(OrderStatus status) {
    return Row(
      children: [
        if (status == OrderStatus.on_delivery)
          Expanded(
            child: _buildInfoCard(
              icon: Icons.phone,
              title: 'Hubungi Driver',
              color: Colors.green,
              onTap: () {
                // Handle contact driver
              },
            ),
          ),
        if (status == OrderStatus.on_delivery) const SizedBox(width: 12),
        Expanded(
          child: _buildInfoCard(
            icon: Icons.help_outline,
            title: 'Bantuan',
            color: Colors.orange,
            onTap: () {
              // Handle help
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontFamily: GlobalStyle.fontFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatEstimatedTime() {
    try {
      final estimatedTime = DateTime.parse(widget.orderData['estimatedDeliveryTime']);
      final now = DateTime.now();
      final difference = estimatedTime.difference(now);

      if (difference.isNegative) {
        return 'Segera tiba';
      }

      if (difference.inHours > 0) {
        return '${difference.inHours} jam ${difference.inMinutes % 60} menit';
      } else {
        return '${difference.inMinutes} menit';
      }
    } catch (e) {
      return 'Segera';
    }
  }

  String _getOrderTime() {
    try {
      final orderTime = DateTime.parse(widget.orderData['created_at'] ?? DateTime.now().toString());
      final now = DateTime.now();
      final difference = now.difference(orderTime);

      if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}j';
      } else {
        return '${difference.inDays}h';
      }
    } catch (e) {
      return 'Baru';
    }
  }
}