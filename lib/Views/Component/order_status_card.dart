import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Models/order.dart';
import 'package:del_pick/Models/tracking.dart';
import 'package:audioplayers/audioplayers.dart';

class OrderStatusCard extends StatefulWidget {
  final Order order;
  final Animation<Offset>? animation;

  const OrderStatusCard({
    Key? key,
    required this.order,
    this.animation,
  }) : super(key: key);

  @override
  State<OrderStatusCard> createState() => _OrderStatusCardState();
}

class _OrderStatusCardState extends State<OrderStatusCard> {
  // Audio player
  final AudioPlayer _audioPlayer = AudioPlayer();
  OrderStatus? _previousStatus;

  // Status timeline definition
  final List<Map<String, dynamic>> _statusTimeline = [
    {'status': OrderStatus.driverHeadingToStore, 'label': 'Di Proses', 'icon': Icons.store_outlined, 'color': Colors.blue, 'animation': 'assets/animations/diproses.json'},
    {'status': OrderStatus.driverAtStore, 'label': 'Di Ambil', 'icon': Icons.delivery_dining_outlined, 'color': Colors.orange, 'animation': 'assets/animations/diambil.json'},
    {'status': OrderStatus.driverHeadingToCustomer, 'label': 'Di Antar', 'icon': Icons.directions_bike_outlined, 'color': Colors.purple, 'animation': 'assets/animations/diantar.json'},
    {'status': OrderStatus.completed, 'label': 'Selesai', 'icon': Icons.check_circle_outline, 'color': Colors.green, 'animation': 'assets/animations/pesanan_selesai.json'},
  ];

  @override
  void initState() {
    super.initState();
    _previousStatus = widget.order.tracking?.status;

    // Check if the status is already set to canceled in initState
    if (widget.order.tracking?.status == OrderStatus.cancelled) {
      _playCancelSound();
    }
  }

  @override
  void didUpdateWidget(OrderStatusCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if status has changed
    if (widget.order.tracking != null &&
        _previousStatus != widget.order.tracking!.status) {

      // Play sound for status change
      if (widget.order.tracking!.status == OrderStatus.cancelled) {
        _playCancelSound();
      } else {
        _playStatusChangeSound();
      }

      // Update previous status
      _previousStatus = widget.order.tracking!.status;
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  // Play normal status change sound
  void _playStatusChangeSound() async {
    await _audioPlayer.play(AssetSource('audio/kring.mp3'));
  }

  // Play cancel sound
  void _playCancelSound() async {
    await _audioPlayer.play(AssetSource('audio/found.wav'));
  }

  // Get status text from first implementation
  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.completed:
        return 'Pesanan Selesai';
      case OrderStatus.cancelled:
        return 'Pesanan Dibatalkan';
      case OrderStatus.pending:
        return 'Menunggu Konfirmasi';
      case OrderStatus.driverAssigned:
        return 'Driver Ditugaskan';
      case OrderStatus.driverHeadingToStore:
        return 'Driver Menuju Toko';
      case OrderStatus.driverAtStore:
        return 'Driver di Toko';
      case OrderStatus.driverHeadingToCustomer:
        return 'Driver Menuju Lokasi Anda';
      case OrderStatus.driverArrived:
        return 'Driver Tiba di Lokasi';
      default:
        return 'Pesanan Diproses';
    }
  }

  // Get status description from first implementation
  String _getStatusDescription(OrderStatus status) {
    switch (status) {
      case OrderStatus.completed:
        return 'Pesanan Anda telah diterima dan selesai';
      case OrderStatus.cancelled:
        return 'Pesanan Anda telah dibatalkan';
      case OrderStatus.pending:
        return 'Pesanan Anda sedang menunggu konfirmasi';
      case OrderStatus.driverAssigned:
        return 'Driver telah ditugaskan untuk pesanan Anda';
      case OrderStatus.driverHeadingToStore:
        return 'Driver sedang menuju ke toko untuk mengambil pesanan Anda';
      case OrderStatus.driverAtStore:
        return 'Driver telah tiba di toko dan sedang mengambil pesanan Anda';
      case OrderStatus.driverHeadingToCustomer:
        return 'Driver sedang dalam perjalanan mengantarkan pesanan ke lokasi Anda';
      case OrderStatus.driverArrived:
        return 'Driver telah tiba di lokasi Anda. Silahkan terima pesanan Anda';
      default:
        return 'Pesanan Anda sedang diproses';
    }
  }

  // Get color based on order status (combining both implementations)
  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.completed:
        return Colors.green;
      case OrderStatus.cancelled:
        return Colors.red;
      case OrderStatus.pending:
      case OrderStatus.driverAssigned:
      case OrderStatus.driverHeadingToStore:
        return Colors.blue;
      case OrderStatus.driverAtStore:
        return Colors.orange;
      case OrderStatus.driverHeadingToCustomer:
      case OrderStatus.driverArrived:
        return Colors.purple;
      default:
        return GlobalStyle.primaryColor;
    }
  }

  // Get icon based on status from first implementation
  IconData _getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.completed:
        return Icons.check_circle;
      case OrderStatus.cancelled:
        return Icons.cancel;
      case OrderStatus.pending:
        return Icons.hourglass_empty;
      case OrderStatus.driverAssigned:
        return Icons.person_add;
      case OrderStatus.driverHeadingToStore:
        return Icons.store;
      case OrderStatus.driverAtStore:
        return Icons.store;
      case OrderStatus.driverHeadingToCustomer:
        return Icons.delivery_dining;
      case OrderStatus.driverArrived:
        return Icons.location_on;
      default:
        return Icons.local_shipping;
    }
  }

  // Get current status index for timeline visualization
  int _getCurrentStatusIndex(OrderStatus currentStatus) {
    int currentStatusIndex = 0;

    for (int i = 0; i < _statusTimeline.length; i++) {
      if (_statusTimeline[i]['status'] == currentStatus) {
        currentStatusIndex = i;
        break;
      }
    }

    // Handle special cases
    if (currentStatus == OrderStatus.driverArrived) {
      currentStatusIndex = 2; // Same as driverHeadingToCustomer but complete
    } else if (currentStatus == OrderStatus.pending ||
        currentStatus == OrderStatus.driverAssigned) {
      currentStatusIndex = 0; // At the beginning
    }

    return currentStatusIndex;
  }

  // Build the original status indicator from first implementation
  Widget _buildSimpleStatusIndicator() {
    final status = widget.order.tracking?.status ?? widget.order.status;
    final statusText = _getStatusText(status);
    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);
    final statusDescription = widget.order.tracking?.statusMessage ?? _getStatusDescription(status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                    fontSize: 16,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusDescription,
                  style: TextStyle(
                    color: GlobalStyle.fontColor,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // If no tracking data is available, use simple version from first implementation
    if (widget.order.tracking == null) {
      Widget content = Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.delivery_dining, color: GlobalStyle.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    'Status Pesanan',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: GlobalStyle.fontColor,
                      fontFamily: GlobalStyle.fontFamily,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSimpleStatusIndicator(),
            ],
          ),
        ),
      );

      // Apply animation if provided
      if (widget.animation != null) {
        return SlideTransition(
          position: widget.animation!,
          child: content,
        );
      }

      return content;
    }

    // Get current status
    final currentStatus = widget.order.tracking!.status;

    // Handle cancelled status specially
    if (currentStatus == OrderStatus.cancelled) {
      return _buildCancelledCard();
    }

    // Get current status index for normal flow
    final int currentStatusIndex = _getCurrentStatusIndex(currentStatus);

    // Get current animation based on status
    String currentAnimation = 'assets/animations/diproses.json';
    for (var status in _statusTimeline) {
      if (status['status'] == currentStatus) {
        currentAnimation = status['animation'];
        break;
      }
    }

    Widget content = Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                'Status Pesanan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: GlobalStyle.fontColor,
                  fontFamily: GlobalStyle.fontFamily,
                ),
              ),
            ],
          ),
          // Status animation
          Center(
            child: SizedBox(
              height: 200,
              child: Lottie.asset(
                currentAnimation,
                repeat: true,
              ),
            ),
          ),
          // Add padding to shift the status icons row to the right
          Padding(
            padding: const EdgeInsets.only(left: 50),
            child: Row(
              children: List.generate(_statusTimeline.length, (index) {
                final isActive = index <= currentStatusIndex;
                final isLast = index == _statusTimeline.length - 1;

                return Expanded(
                  child: Row(
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: isActive ? _statusTimeline[index]['color'] : Colors.grey[300],
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _statusTimeline[index]['icon'],
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _statusTimeline[index]['label'],
                            style: TextStyle(
                              fontSize: 10,
                              color: isActive ? _statusTimeline[index]['color'] : Colors.grey,
                              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                              fontFamily: GlobalStyle.fontFamily,
                            ),
                          ),
                        ],
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            height: 2,
                            color: index < currentStatusIndex ? _statusTimeline[index]['color'] : Colors.grey[300],
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: _getStatusColor(currentStatus).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.order.tracking!.statusMessage,
              style: TextStyle(
                color: _getStatusColor(currentStatus),
                fontWeight: FontWeight.w600,
                fontFamily: GlobalStyle.fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );

    // Apply animation if provided
    if (widget.animation != null) {
      return SlideTransition(
        position: widget.animation!,
        child: content,
      );
    }

    return content;
  }

  // Special widget for cancelled status
  Widget _buildCancelledCard() {
    Widget content = Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              const SizedBox(width: 8),
              Text(
                'Pesanan Dibatalkan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                  fontFamily: GlobalStyle.fontFamily,
                ),
              ),
            ],
          ),
          // Cancelled animation
          Center(
            child: SizedBox(
              height: 200,
              child: Lottie.asset(
                'assets/animations/cancel.json',
                repeat: true,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.order.tracking!.statusMessage,
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w600,
                fontFamily: GlobalStyle.fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );

    // Apply animation if provided
    if (widget.animation != null) {
      return SlideTransition(
        position: widget.animation!,
        child: content,
      );
    }

    return content;
  }
}