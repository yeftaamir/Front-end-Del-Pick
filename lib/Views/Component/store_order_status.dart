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
  late AnimationController _rotateController;
  late AnimationController _shimmerController;
  late AnimationController _scaleController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _floatAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _shimmerAnimation;
  late Animation<double> _scaleAnimation;

  // Enhanced store color palette
  final List<Color> _gradientColors = [
    const Color(0xFF7B1FA2),
    const Color(0xFF9C27B0),
    const Color(0xFFBA68C8),
  ];

  // Status timeline for store perspective with enhanced visuals
  final List<Map<String, dynamic>> _statusTimeline = [
    {
      'status': OrderStatus.pending,
      'label': 'Pesanan Baru',
      'description': 'Menunggu konfirmasi toko',
      'icon': Icons.notification_important,
      'color': const Color(0xFFFF6F00),
      'gradient': [const Color(0xFFFF6F00), const Color(0xFFFFB300)],
      'animation': 'assets/animations/loading_animation.json'
    },
    {
      'status': OrderStatus.approved,
      'label': 'Dikonfirmasi',
      'description': 'Pesanan diterima, mulai persiapan',
      'icon': Icons.thumb_up,
      'color': const Color(0xFF00ACC1),
      'gradient': [const Color(0xFF00ACC1), const Color(0xFF00BCD4)],
      'animation': 'assets/animations/diproses.json'
    },
    {
      'status': OrderStatus.preparing,
      'label': 'Disiapkan',
      'description': 'Sedang mempersiapkan pesanan',
      'icon': Icons.restaurant_menu,
      'color': const Color(0xFF7B1FA2),
      'gradient': [const Color(0xFF7B1FA2), const Color(0xFF9C27B0)],
      'animation': 'assets/animations/diambil.json'
    },
    {
      'status': OrderStatus.on_delivery,
      'label': 'Dikirim',
      'description': 'Pesanan dalam perjalanan',
      'icon': Icons.local_shipping,
      'color': const Color(0xFF3949AB),
      'gradient': [const Color(0xFF3949AB), const Color(0xFF5C6BC0)],
      'animation': 'assets/animations/diantar.json'
    },
    {
      'status': OrderStatus.delivered,
      'label': 'Terkirim',
      'description': 'Pesanan berhasil diterima customer',
      'icon': Icons.done_all,
      'color': const Color(0xFF43A047),
      'gradient': [const Color(0xFF43A047), const Color(0xFF66BB6A)],
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
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
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
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    final currentStatus = _getCurrentOrderStatus();
    _previousStatus = currentStatus;

    if (currentStatus == OrderStatus.cancelled) {
      _playCancelSound();
    } else {
      _startAnimations(currentStatus);
    }

    _scaleController.forward();
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
  void didUpdateWidget(StoreOrderStatusCard oldWidget) {
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
    _scaleController.dispose();
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
      animation: Listenable.merge([_floatAnimation, _scaleAnimation]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Transform.translate(
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
              // Store-themed floating shapes
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
              // Store icon shape
              Positioned(
                top: 120,
                left: -40,
                child: Transform.rotate(
                  angle: _rotateAnimation.value * 0.5,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _gradientColors[2].withOpacity(0.2),
                          _gradientColors[2].withOpacity(0.0),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Icon(
                      Icons.store,
                      color: _gradientColors[2].withOpacity(0.4),
                      size: 50,
                    ),
                  ),
                ),
              ),
              // Additional decorative elements
              Positioned(
                bottom: 100,
                right: -20,
                child: Transform.rotate(
                  angle: -_rotateAnimation.value * 0.7,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: _gradientColors[0].withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
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
          colors: _gradientColors,
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
                        Icons.store,
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
                            'Status Pesanan',
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
              // Order value with animation
              AnimatedBuilder(
                animation: _scaleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 0.8 + (_scaleAnimation.value * 0.2),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.3),
                            Colors.white.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.payments, color: Colors.white, size: 20),
                          const SizedBox(height: 4),
                          Text(
                            _formatCurrency(widget.orderData['total'] ?? 0),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: GlobalStyle.fontFamily,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Order time and items count
          Row(
            children: [
              _buildHeaderInfoChip(
                Icons.access_time,
                _getOrderTime(),
                Colors.white.withOpacity(0.9),
              ),
              const SizedBox(width: 12),
              if (widget.orderData['items'] != null)
                _buildHeaderInfoChip(
                  Icons.shopping_basket,
                  '${widget.orderData['items'].length} items',
                  Colors.white.withOpacity(0.9),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              fontFamily: GlobalStyle.fontFamily,
            ),
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
              ],
            ),
          ),

          // Customer info card with modern design
          if (widget.orderData['customer'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _gradientColors[0].withOpacity(0.1),
                      _gradientColors[0].withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _gradientColors[0].withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [_gradientColors[0], _gradientColors[1]],
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 24,
                        backgroundImage: widget.orderData['customer']['avatar'] != null
                            ? NetworkImage(widget.orderData['customer']['avatar'])
                            : null,
                        backgroundColor: Colors.white,
                        child: widget.orderData['customer']['avatar'] == null
                            ? Icon(Icons.person, size: 24, color: _gradientColors[0])
                            : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.orderData['customer']['name'] ?? 'Customer',
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              fontFamily: GlobalStyle.fontFamily,
                            ),
                          ),
                          if (widget.orderData['customer']['phone'] != null)
                            const SizedBox(height: 4),
                          if (widget.orderData['customer']['phone'] != null)
                            Row(
                              children: [
                                Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  widget.orderData['customer']['phone'],
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                    fontFamily: GlobalStyle.fontFamily,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    // Contact button
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_gradientColors[0], _gradientColors[1]],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: _gradientColors[0].withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            // Handle contact customer
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Icon(Icons.phone, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Order items with modern design
          if (widget.orderData['items'] != null &&
              widget.orderData['items'] is List &&
              widget.orderData['items'].isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.deepPurple.withOpacity(0.05),
                      Colors.deepPurple.withOpacity(0.02),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.deepPurple.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _gradientColors[0].withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.restaurant_menu,
                            size: 20,
                            color: _gradientColors[0],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Detail Pesanan',
                          style: TextStyle(
                            color: Colors.grey[800],
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _gradientColors[0].withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${widget.orderData['items'].length} items',
                            style: TextStyle(
                              color: _gradientColors[0],
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              fontFamily: GlobalStyle.fontFamily,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      height: 1,
                      color: Colors.grey.withOpacity(0.2),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Pesanan',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 14,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                        Text(
                          _formatCurrency(widget.orderData['total'] ?? 0),
                          style: TextStyle(
                            color: _gradientColors[0],
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Action buttons based on status
          const SizedBox(height: 16),
          _buildActionButtons(currentStatus),

          // Success message for delivered orders
          if (currentStatus == OrderStatus.delivered)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.green.withOpacity(0.1),
                      Colors.green.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.green.withOpacity(0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.celebration,
                      color: Colors.green,
                      size: 36,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pesanan Selesai!',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: GlobalStyle.fontFamily,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Customer telah menerima pesanan',
                      style: TextStyle(
                        color: Colors.green.withOpacity(0.8),
                        fontSize: 14,
                        fontFamily: GlobalStyle.fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
        Container(
          width: 60,
          child: Text(
            item['label'],
            style: TextStyle(
              fontSize: 10,
              color: isActive ? item['color'] : Colors.grey,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              fontFamily: GlobalStyle.fontFamily,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(OrderStatus status) {
    return Row(
      children: [
        if (status == OrderStatus.pending) ...[
          Expanded(
            child: _buildActionButton(
              icon: Icons.check_circle,
              title: 'Terima',
              gradient: [Colors.green, Colors.green[700]!],
              onTap: () {
                // Handle accept order
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionButton(
              icon: Icons.cancel,
              title: 'Tolak',
              gradient: [Colors.red, Colors.red[700]!],
              onTap: () {
                // Handle reject order
              },
            ),
          ),
        ],
        if (status == OrderStatus.approved)
          Expanded(
            child: _buildActionButton(
              icon: Icons.restaurant,
              title: 'Mulai Persiapan',
              gradient: [_gradientColors[0], _gradientColors[1]],
              onTap: () {
                // Handle start preparation
              },
            ),
          ),
        if (status == OrderStatus.preparing)
          Expanded(
            child: _buildActionButton(
              icon: Icons.check,
              title: 'Siap Dikirim',
              gradient: [Colors.blue, Colors.blue[700]!],
              onTap: () {
                // Handle ready for delivery
              },
            ),
          ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatCurrency(dynamic amount) {
    try {
      final value = amount is String ? double.parse(amount) : amount.toDouble();
      return 'Rp ${value.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
              (Match m) => '${m[1]}.'
      )}';
    } catch (e) {
      return 'Rp 0';
    }
  }

  String _getOrderTime() {
    try {
      final orderTime = DateTime.parse(widget.orderData['created_at'] ?? DateTime.now().toString());
      final now = DateTime.now();
      final difference = now.difference(orderTime);

      if (difference.inMinutes < 60) {
        return '${difference.inMinutes} menit';
      } else if (difference.inHours < 24) {
        return '${difference.inHours} jam';
      } else {
        return '${difference.inDays} hari';
      }
    } catch (e) {
      return 'Baru';
    }
  }
}