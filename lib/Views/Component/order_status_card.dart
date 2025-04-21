import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Models/order.dart';
import 'package:del_pick/Models/tracking.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:del_pick/Services/tracking_service.dart';
import '../../Models/order_enum.dart';

class OrderStatusCard extends StatefulWidget {
  final Order order;
  final Animation<Offset>? animation;
  final Function()? onStatusUpdate;

  const OrderStatusCard({
    Key? key,
    required this.order,
    this.animation,
    this.onStatusUpdate,
  }) : super(key: key);

  @override
  State<OrderStatusCard> createState() => _OrderStatusCardState();
}

class _OrderStatusCardState extends State<OrderStatusCard> {
  // Audio player
  final AudioPlayer _audioPlayer = AudioPlayer();
  OrderStatus? _previousStatus;

  // Tracking data
  Tracking? _tracking;
  bool _isLoadingTracking = false;
  String? _trackingError;

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
    _previousStatus = widget.order.status;
    _fetchTrackingData();

    // Check if the status is already set to canceled
    if (widget.order.status == OrderStatus.cancelled) {
      _playCancelSound();
    }
  }

  @override
  void didUpdateWidget(OrderStatusCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Refresh tracking data if order ID changes
    if (oldWidget.order.id != widget.order.id) {
      _fetchTrackingData();
    }

    // Check if status has changed
    if (_previousStatus != widget.order.status) {
      // Play sound for status change
      if (widget.order.status == OrderStatus.cancelled) {
        _playCancelSound();
      } else {
        _playStatusChangeSound();
      }

      // Update previous status
      _previousStatus = widget.order.status;
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  // Fetch tracking data from TrackingService
  Future<void> _fetchTrackingData() async {
    if (widget.order.id.isEmpty) return;

    setState(() {
      _isLoadingTracking = true;
      _trackingError = null;
    });

    try {
      // Use the tracking service to get real-time tracking data
      final trackingData = await TrackingService.getOrderTracking(widget.order.id);

      // If we have valid tracking data, update the state
      if (trackingData != null) {
        setState(() {
          _tracking = Tracking.fromJson(trackingData);
          _isLoadingTracking = false;
        });

        // Call the onStatusUpdate callback if provided
        if (widget.onStatusUpdate != null) {
          widget.onStatusUpdate!();
        }
      } else {
        setState(() {
          _tracking = widget.order.tracking; // Fall back to order's tracking if any
          _isLoadingTracking = false;
        });
      }
    } catch (e) {
      setState(() {
        _trackingError = 'Gagal memuat data tracking: $e';
        _isLoadingTracking = false;
        _tracking = widget.order.tracking; // Fall back to order's tracking if any
      });
    }
  }

  // Play normal status change sound
  void _playStatusChangeSound() async {
    await _audioPlayer.play(AssetSource('audio/kring.mp3'));
  }

  // Play cancel sound
  void _playCancelSound() async {
    await _audioPlayer.play(AssetSource('audio/found.wav'));
  }

  // Get status text
  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.completed:
        return 'Pesanan Selesai';
      case OrderStatus.cancelled:
        return 'Pesanan Dibatalkan';
      case OrderStatus.pending:
        return 'Menunggu Konfirmasi';
      case OrderStatus.approved:
        return 'Pesanan Disetujui';
      case OrderStatus.preparing:
        return 'Pesanan Sedang Dipersiapkan';
      case OrderStatus.on_delivery:
        return 'Pesanan Dalam Pengiriman';
      case OrderStatus.delivered:
        return 'Pesanan Telah Diterima';
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

  // Get status description
  String _getStatusDescription(OrderStatus status) {
    switch (status) {
      case OrderStatus.completed:
        return 'Pesanan Anda telah diterima dan selesai';
      case OrderStatus.cancelled:
        return 'Pesanan Anda telah dibatalkan';
      case OrderStatus.pending:
        return 'Pesanan Anda sedang menunggu konfirmasi';
      case OrderStatus.approved:
        return 'Pesanan Anda telah disetujui oleh toko';
      case OrderStatus.preparing:
        return 'Toko sedang mempersiapkan pesanan Anda';
      case OrderStatus.on_delivery:
        return 'Pesanan Anda sedang dalam perjalanan';
      case OrderStatus.delivered:
        return 'Pesanan Anda telah diterima';
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

  // Get color based on order status
  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.completed:
      case OrderStatus.delivered:
        return Colors.green;
      case OrderStatus.cancelled:
        return Colors.red;
      case OrderStatus.pending:
      case OrderStatus.approved:
      case OrderStatus.driverAssigned:
      case OrderStatus.driverHeadingToStore:
      case OrderStatus.preparing:
        return Colors.blue;
      case OrderStatus.driverAtStore:
        return Colors.orange;
      case OrderStatus.on_delivery:
      case OrderStatus.driverHeadingToCustomer:
      case OrderStatus.driverArrived:
        return Colors.purple;
      default:
        return GlobalStyle.primaryColor;
    }
  }

  // Get icon based on status
  IconData _getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.completed:
      case OrderStatus.delivered:
        return Icons.check_circle;
      case OrderStatus.cancelled:
        return Icons.cancel;
      case OrderStatus.pending:
        return Icons.hourglass_empty;
      case OrderStatus.approved:
        return Icons.thumb_up;
      case OrderStatus.preparing:
        return Icons.restaurant;
      case OrderStatus.on_delivery:
        return Icons.delivery_dining;
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
    // Map both old and new status types to the timeline positions
    if (currentStatus == OrderStatus.completed ||
        currentStatus == OrderStatus.delivered) {
      return 3; // Completed status
    } else if (currentStatus == OrderStatus.driverHeadingToCustomer ||
        currentStatus == OrderStatus.driverArrived ||
        currentStatus == OrderStatus.on_delivery) {
      return 2; // On the way to customer
    } else if (currentStatus == OrderStatus.driverAtStore) {
      return 1; // At store
    } else if (currentStatus == OrderStatus.pending ||
        currentStatus == OrderStatus.approved ||
        currentStatus == OrderStatus.driverAssigned ||
        currentStatus == OrderStatus.driverHeadingToStore ||
        currentStatus == OrderStatus.preparing) {
      return 0; // Processing
    }

    return 0; // Default to processing
  }

  // Build the simple status indicator when no tracking is available
  Widget _buildSimpleStatusIndicator() {
    final status = _tracking?.status ?? widget.order.status;
    final statusText = _getStatusText(status);
    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);
    final statusDescription = _tracking?.statusMessage ??
        widget.order.tracking?.statusMessage ??
        _getStatusDescription(status);

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

  // Build error widget if tracking data fails to load
  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: Colors.orange),
          const SizedBox(height: 8),
          Text(
            'Gagal memuat data tracking',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: GlobalStyle.fontColor,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _trackingError ?? 'Silahkan coba lagi nanti',
            style: TextStyle(
              color: GlobalStyle.fontColor,
              fontFamily: GlobalStyle.fontFamily,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _fetchTrackingData,
            style: ElevatedButton.styleFrom(
              backgroundColor: GlobalStyle.primaryColor,
            ),
            child: Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get current status, prioritizing tracking data if available
    final currentStatus = _tracking?.status ?? widget.order.status;

    // Handle loading state
    if (_isLoadingTracking) {
      Widget loadingContent = Container(
        padding: const EdgeInsets.all(16),
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
        child: Column(
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
            const Center(
              child: CircularProgressIndicator(),
            ),
            const SizedBox(height: 16),
            Text(
              'Memuat status pesanan...',
              style: TextStyle(
                color: GlobalStyle.fontColor,
                fontFamily: GlobalStyle.fontFamily,
              ),
            ),
          ],
        ),
      );

      // Apply animation if provided
      if (widget.animation != null) {
        return SlideTransition(
          position: widget.animation!,
          child: loadingContent,
        );
      }
      return loadingContent;
    }

    // Handle error state
    if (_trackingError != null && _tracking == null) {
      Widget errorContent = Container(
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
              _buildErrorWidget(),
            ],
          ),
        ),
      );

      // Apply animation if provided
      if (widget.animation != null) {
        return SlideTransition(
          position: widget.animation!,
          child: errorContent,
        );
      }
      return errorContent;
    }

    // If no tracking data is available or it's a simple status, use simple version
    if (_tracking == null) {
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

    // For statuses not in the timeline, map to the closest one
    if (currentStatus == OrderStatus.on_delivery) {
      currentAnimation = 'assets/animations/diantar.json';
    } else if (currentStatus == OrderStatus.delivered ||
        currentStatus == OrderStatus.completed) {
      currentAnimation = 'assets/animations/pesanan_selesai.json';
    } else if (currentStatus == OrderStatus.preparing ||
        currentStatus == OrderStatus.approved) {
      currentAnimation = 'assets/animations/diproses.json';
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
              _tracking?.statusMessage ?? _getStatusDescription(currentStatus),
              style: TextStyle(
                color: _getStatusColor(currentStatus),
                fontWeight: FontWeight.w600,
                fontFamily: GlobalStyle.fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Show driver info if available
          if (_tracking != null && currentStatus != OrderStatus.completed &&
              currentStatus != OrderStatus.cancelled)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.delivery_dining,
                    color: GlobalStyle.primaryColor,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Driver: ${_tracking!.driverName}',
                    style: TextStyle(
                      fontFamily: GlobalStyle.fontFamily,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  if (_tracking!.formattedETA.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            color: Colors.blue,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'ETA: ${_tracking!.formattedETA}',
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
                ],
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
              _tracking?.statusMessage ??
                  widget.order.tracking?.statusMessage ??
                  _getStatusDescription(OrderStatus.cancelled),
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