// customer_order_status_card.dart
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Models/order.dart';
import 'package:del_pick/Models/order_enum.dart';
import 'package:audioplayers/audioplayers.dart';

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
  late Animation<double> _pulseAnimation;

  // Customer-specific color theme
  final Color _primaryColor = const Color(0xFF4A90E2);
  final Color _secondaryColor = const Color(0xFF7BB3F0);

  // Status timeline for customer
  final List<Map<String, dynamic>> _statusTimeline = [
    {
      'status': OrderStatus.pending,
      'label': 'Menunggu',
      'description': 'Menunggu konfirmasi toko',
      'icon': Icons.hourglass_empty,
      'color': Colors.orange,
      'animation': 'assets/animations/loading_animation.json'
    },
    {
      'status': OrderStatus.approved,
      'label': 'Dikonfirmasi',
      'description': 'Pesanan dikonfirmasi toko',
      'icon': Icons.check_circle_outline,
      'color': Colors.blue,
      'animation': 'assets/animations/diproses.json'
    },
    {
      'status': OrderStatus.preparing,
      'label': 'Disiapkan',
      'description': 'Pesanan sedang disiapkan',
      'icon': Icons.restaurant,
      'color': Colors.purple,
      'animation': 'assets/animations/diambil.json'
    },
    {
      'status': OrderStatus.on_delivery,
      'label': 'Dikirim',
      'description': 'Pesanan dalam perjalanan',
      'icon': Icons.delivery_dining,
      'color': Colors.indigo,
      'animation': 'assets/animations/diantar.json'
    },
    {
      'status': OrderStatus.delivered,
      'label': 'Selesai',
      'description': 'Pesanan telah diterima',
      'icon': Icons.celebration,
      'color': Colors.green,
      'animation': 'assets/animations/pesanan_selesai.json'
    },
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    final currentStatus = _getCurrentOrderStatus();
    _previousStatus = currentStatus;

    if (currentStatus == OrderStatus.cancelled) {
      _playCancelSound();
    }

    // Start pulse animation for pending status
    if (currentStatus == OrderStatus.pending) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(CustomerOrderStatusCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    final currentStatus = _getCurrentOrderStatus();
    if (_previousStatus != currentStatus) {
      if (currentStatus == OrderStatus.cancelled) {
        _playCancelSound();
        _pulseController.stop();
      } else {
        _playStatusChangeSound();
        if (currentStatus == OrderStatus.pending) {
          _pulseController.repeat(reverse: true);
        } else {
          _pulseController.stop();
        }
      }
      _previousStatus = currentStatus;
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _pulseController.dispose();
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
        'color': Colors.red,
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

    Widget content = Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            _primaryColor.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_primaryColor, _secondaryColor],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.track_changes,
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
                          'Status Pesanan',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                        Text(
                          'Order #${widget.orderData['id']}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Animation
                  if (currentStatus == OrderStatus.pending)
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            height: 180,
                            child: Lottie.asset(
                              currentStatusInfo['animation'],
                              repeat: true,
                            ),
                          ),
                        );
                      },
                    )
                  else
                    Container(
                      height: 180,
                      child: Lottie.asset(
                        currentStatusInfo['animation'],
                        repeat: currentStatus != OrderStatus.delivered,
                      ),
                    ),

                  const SizedBox(height: 20),

                  // Status Timeline (only for non-cancelled orders)
                  if (currentStatus != OrderStatus.cancelled)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: List.generate(_statusTimeline.length, (index) {
                          final isActive = index <= currentIndex;
                          final isCurrent = index == currentIndex;
                          final isLast = index == _statusTimeline.length - 1;
                          final statusItem = _statusTimeline[index];

                          return Expanded(
                            child: Row(
                              children: [
                                Column(
                                  children: [
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 300),
                                      width: isCurrent ? 32 : 24,
                                      height: isCurrent ? 32 : 24,
                                      decoration: BoxDecoration(
                                        color: isActive
                                            ? statusItem['color']
                                            : Colors.grey[300],
                                        shape: BoxShape.circle,
                                        boxShadow: isCurrent ? [
                                          BoxShadow(
                                            color: statusItem['color'].withOpacity(0.4),
                                            blurRadius: 8,
                                            spreadRadius: 2,
                                          ),
                                        ] : [],
                                      ),
                                      child: Icon(
                                        statusItem['icon'],
                                        color: Colors.white,
                                        size: isCurrent ? 16 : 12,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      statusItem['label'],
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isActive
                                            ? statusItem['color']
                                            : Colors.grey,
                                        fontWeight: isCurrent
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        fontFamily: GlobalStyle.fontFamily,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                                if (!isLast)
                                  Expanded(
                                    child: Container(
                                      height: 2,
                                      margin: const EdgeInsets.only(bottom: 20),
                                      decoration: BoxDecoration(
                                        color: index < currentIndex
                                            ? _statusTimeline[index]['color']
                                            : Colors.grey[300],
                                        borderRadius: BorderRadius.circular(1),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),

                  const SizedBox(height: 20),

                  // Status Message
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          currentStatusInfo['color'].withOpacity(0.1),
                          currentStatusInfo['color'].withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: currentStatusInfo['color'].withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          currentStatusInfo['label'],
                          style: TextStyle(
                            color: currentStatusInfo['color'],
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentStatusInfo['description'],
                          style: TextStyle(
                            color: currentStatusInfo['color'].withOpacity(0.8),
                            fontSize: 14,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  // Estimated delivery time (if available)
                  if (widget.orderData['estimatedDeliveryTime'] != null &&
                      currentStatus != OrderStatus.delivered &&
                      currentStatus != OrderStatus.cancelled)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.access_time,
                                size: 16, color: Colors.blue),
                            const SizedBox(width: 6),
                            Text(
                              'Estimasi: ${_formatEstimatedTime()}',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
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
    );

    if (widget.animation != null) {
      return SlideTransition(
        position: widget.animation!,
        child: content,
      );
    }

    return content;
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
        return '${difference.inHours}j ${difference.inMinutes % 60}m';
      } else {
        return '${difference.inMinutes}m';
      }
    } catch (e) {
      return 'Segera';
    }
  }
}