// driver_order_status_card.dart
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Models/order.dart';
import 'package:del_pick/Models/order_enum.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:ui';
import 'dart:math' as math;

class DriverOrderStatusCard extends StatefulWidget {
  final Map<String, dynamic> orderData;
  final Animation<Offset>? animation;

  const DriverOrderStatusCard({
    Key? key,
    required this.orderData,
    this.animation,
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
  late AnimationController _rotateController;
  late AnimationController _shimmerController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _floatAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _shimmerAnimation;

  // Enhanced driver color palette
  final List<Color> _gradientColors = [
    const Color(0xFF2E7D32),
    const Color(0xFF43A047),
    const Color(0xFF66BB6A),
  ];

  // Status timeline for driver perspective with enhanced visuals
  final List<Map<String, dynamic>> _statusTimeline = [
    {
      'status': OrderStatus.pending,
      'label': 'Menunggu',
      'description': 'Menunggu tindakan driver',
      'icon': Icons.schedule,
      'color': const Color(0xFFFF9800),
      'gradient': [const Color(0xFFFF9800), const Color(0xFFFFC947)],
      'animation': 'assets/animations/loading_animation.json'
    },
    {
      'status': OrderStatus.approved,
      'label': 'Diterima',
      'description': 'Pesanan diterima, siap diproses',
      'icon': Icons.assignment_turned_in,
      'color': const Color(0xFF00BCD4),
      'gradient': [const Color(0xFF00BCD4), const Color(0xFF00E5FF)],
      'animation': 'assets/animations/diproses.json'
    },
    {
      'status': OrderStatus.preparing,
      'label': 'Ambil Pesanan',
      'description': 'Sedang mengambil pesanan',
      'icon': Icons.shopping_bag,
      'color': const Color(0xFF7C4DFF),
      'gradient': [const Color(0xFF7C4DFF), const Color(0xFF651FFF)],
      'animation': 'assets/animations/diambil.json'
    },
    {
      'status': OrderStatus.on_delivery,
      'label': 'Antar Pesanan',
      'description': 'Dalam perjalanan ke customer',
      'icon': Icons.directions_bike,
      'color': const Color(0xFF2196F3),
      'gradient': [const Color(0xFF2196F3), const Color(0xFF1976D2)],
      'animation': 'assets/animations/diantar.json'
    },
    {
      'status': OrderStatus.delivered,
      'label': 'Terkirim',
      'description': 'Pesanan berhasil diantar',
      'icon': Icons.check_circle,
      'color': const Color(0xFF4CAF50),
      'gradient': [const Color(0xFF4CAF50), const Color(0xFF388E3C)],
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
  void didUpdateWidget(DriverOrderStatusCard oldWidget) {
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
              // Driver-themed floating shapes
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
              // Additional driver icon shape
              Positioned(
                top: 100,
                left: -20,
                child: Transform.rotate(
                  angle: _rotateAnimation.value * 0.5,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: _gradientColors[2].withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.delivery_dining,
                      color: _gradientColors[2].withOpacity(0.3),
                      size: 40,
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
                        Icons.delivery_dining,
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
                            'Status Pengiriman',
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
            ],
          ),
          const SizedBox(height: 16),
          // Customer info card with glassmorphism
          if (widget.orderData['customer'] != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
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
                        colors: [Colors.white, Colors.white.withOpacity(0.8)],
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundImage: widget.orderData['customer']['avatar'] != null
                          ? NetworkImage(widget.orderData['customer']['avatar'])
                          : null,
                      backgroundColor: _gradientColors[1],
                      child: widget.orderData['customer']['avatar'] == null
                          ? Icon(Icons.person, size: 20, color: Colors.white)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.orderData['customer']['name'] ?? 'Customer',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                        if (widget.orderData['customer']['phone'] != null)
                          Text(
                            widget.orderData['customer']['phone'],
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                              fontFamily: GlobalStyle.fontFamily,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.phone,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
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

          // Delivery address with modern design
          if (widget.orderData['deliveryAddress'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.grey.withOpacity(0.1),
                      Colors.grey.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.grey.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.location_on,
                        size: 20,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Alamat Pengiriman',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              fontFamily: GlobalStyle.fontFamily,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.orderData['deliveryAddress'],
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontSize: 14,
                              fontFamily: GlobalStyle.fontFamily,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Action buttons based on status
          const SizedBox(height: 16),
          _buildActionButtons(currentStatus),

          // Earnings info for delivered orders
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
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pengiriman Selesai!',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: GlobalStyle.fontFamily,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Terima kasih atas kerja kerasnya!',
                      style: TextStyle(
                        color: Colors.green.withOpacity(0.8),
                        fontSize: 14,
                        fontFamily: GlobalStyle.fontFamily,
                      ),
                    ),
                    if (widget.orderData['earnings'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.monetization_on,
                                size: 20,
                                color: Colors.green[700],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Pendapatan: ${_formatCurrency(widget.orderData['earnings'])}',
                                style: TextStyle(
                                  color: Colors.green[700],
                                  fontSize: 16,
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

  Widget _buildActionButtons(OrderStatus status) {
    return Row(
      children: [
        if (status == OrderStatus.pending)
          Expanded(
            child: _buildActionButton(
              icon: Icons.check_circle,
              title: 'Terima Order',
              color: Colors.green,
              gradient: [Colors.green, Colors.green[700]!],
              onTap: () {
                // Handle accept order
              },
            ),
          ),
        if (status == OrderStatus.pending) const SizedBox(width: 12),
        if (status == OrderStatus.approved || status == OrderStatus.preparing)
          Expanded(
            child: _buildActionButton(
              icon: Icons.navigation,
              title: 'Navigasi',
              color: Colors.blue,
              gradient: [Colors.blue, Colors.blue[700]!],
              onTap: () {
                // Handle navigation
              },
            ),
          ),
        if (status == OrderStatus.approved ||
            status == OrderStatus.preparing ||
            status == OrderStatus.on_delivery)
          const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            icon: Icons.phone,
            title: 'Hubungi',
            color: Colors.orange,
            gradient: [Colors.orange, Colors.orange[700]!],
            onTap: () {
              // Handle contact
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required Color color,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient.map((c) => c.withOpacity(0.9)).toList(),
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
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
    );
  }

  String _formatCurrency(dynamic amount) {
    try {
      final value = amount is String ? double.parse(amount) : amount.toDouble();
      return 'Rp ${value.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (match) => '${match[1]}.')}';
    } catch (e) {
      return 'Rp -';
    }
  }
}