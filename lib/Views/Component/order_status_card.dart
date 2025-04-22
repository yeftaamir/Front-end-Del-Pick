import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Models/order.dart';
import 'package:del_pick/Models/tracking.dart';
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
  final AudioPlayer _audioPlayer = AudioPlayer();
  OrderStatus? _previousStatus;

  Tracking? _tracking;
  bool _isLoading = true;
  String? _errorMessage;

  // Status definitions
  final List<Map<String, dynamic>> _statusSteps = [
    {
      'status': OrderStatus.driverHeadingToStore,
      'label': 'Di Proses',
      'icon': Icons.store_outlined,
      'color': Colors.blue,
      'animation': 'assets/animations/diproses.json',
    },
    {
      'status': OrderStatus.driverAtStore,
      'label': 'Di Ambil',
      'icon': Icons.delivery_dining_outlined,
      'color': Colors.orange,
      'animation': 'assets/animations/diambil.json',
    },
    {
      'status': OrderStatus.driverHeadingToCustomer,
      'label': 'Di Antar',
      'icon': Icons.directions_bike_outlined,
      'color': Colors.purple,
      'animation': 'assets/animations/diantar.json',
    },
    {
      'status': OrderStatus.completed,
      'label': 'Selesai',
      'icon': Icons.check_circle_outline,
      'color': Colors.green,
      'animation': 'assets/animations/pesanan_selesai.json',
    },
  ];

  @override
  void initState() {
    super.initState();
    _previousStatus = widget.order.status;
    _fetchTracking();

    // Play cancel sound if order is already cancelled
    if (widget.order.status == OrderStatus.cancelled) {
      _audioPlayer.play(AssetSource('audio/found.wav'));
    }
  }

  @override
  void didUpdateWidget(OrderStatusCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Fetch new tracking if order ID changes
    if (oldWidget.order.id != widget.order.id) {
      _fetchTracking();
    }

    // Handle status changes
    if (_previousStatus != widget.order.status) {
      if (widget.order.status == OrderStatus.cancelled) {
        _audioPlayer.play(AssetSource('audio/found.wav'));
      } else {
        _audioPlayer.play(AssetSource('audio/kring.mp3'));
      }
      _previousStatus = widget.order.status;
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  // Fetch tracking data
  Future<void> _fetchTracking() async {
    if (widget.order.id.isEmpty) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final trackingData = await TrackingService.getOrderTracking(widget.order.id);

      setState(() {
        _tracking = Tracking.fromJson(trackingData);
        _isLoading = false;
      });

      if (widget.onStatusUpdate != null) {
        widget.onStatusUpdate!();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal memuat data tracking: $e';
        _isLoading = false;
      });
    }
  }

  // Get current status text
  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.cancelled:
        return 'Pesanan Dibatalkan';
      case OrderStatus.completed:
      case OrderStatus.delivered:
        return 'Pesanan Selesai';
      case OrderStatus.pending:
        return 'Menunggu Konfirmasi';
      case OrderStatus.approved:
        return 'Pesanan Disetujui';
      case OrderStatus.preparing:
        return 'Sedang Dipersiapkan';
      case OrderStatus.driverAssigned:
        return 'Driver Ditugaskan';
      case OrderStatus.driverHeadingToStore:
        return 'Driver Menuju Toko';
      case OrderStatus.driverAtStore:
        return 'Driver di Toko';
      case OrderStatus.driverHeadingToCustomer:
      case OrderStatus.on_delivery:
        return 'Driver Menuju Anda';
      case OrderStatus.driverArrived:
        return 'Driver Tiba';
      default:
        return 'Pesanan Diproses';
    }
  }

  // Get status description
  String _getStatusDescription(OrderStatus status) {
    switch (status) {
      case OrderStatus.cancelled:
        return 'Pesanan Anda telah dibatalkan';
      case OrderStatus.completed:
      case OrderStatus.delivered:
        return 'Pesanan Anda telah diterima dan selesai';
      case OrderStatus.pending:
        return 'Pesanan Anda sedang menunggu konfirmasi';
      case OrderStatus.approved:
        return 'Pesanan Anda telah disetujui oleh toko';
      case OrderStatus.preparing:
        return 'Toko sedang mempersiapkan pesanan Anda';
      case OrderStatus.driverAssigned:
        return 'Driver telah ditugaskan untuk pesanan Anda';
      case OrderStatus.driverHeadingToStore:
        return 'Driver sedang menuju ke toko untuk mengambil pesanan Anda';
      case OrderStatus.driverAtStore:
        return 'Driver telah tiba di toko dan sedang mengambil pesanan Anda';
      case OrderStatus.driverHeadingToCustomer:
      case OrderStatus.on_delivery:
        return 'Driver sedang dalam perjalanan mengantarkan pesanan ke lokasi Anda';
      case OrderStatus.driverArrived:
        return 'Driver telah tiba di lokasi Anda. Silahkan terima pesanan Anda';
      default:
        return 'Pesanan Anda sedang diproses';
    }
  }

  // Get status color
  Color _getStatusColor(OrderStatus status) {
    if (status == OrderStatus.cancelled) return Colors.red;
    if (status == OrderStatus.completed || status == OrderStatus.delivered) return Colors.green;
    if (status == OrderStatus.driverHeadingToCustomer || status == OrderStatus.on_delivery) return Colors.purple;
    if (status == OrderStatus.driverAtStore) return Colors.orange;
    return Colors.blue;
  }

  // Get animation path for status
  String _getAnimationPath(OrderStatus status) {
    if (status == OrderStatus.cancelled) return 'assets/animations/cancel.json';
    if (status == OrderStatus.completed || status == OrderStatus.delivered) return 'assets/animations/pesanan_selesai.json';
    if (status == OrderStatus.driverHeadingToCustomer || status == OrderStatus.on_delivery) return 'assets/animations/diantar.json';
    if (status == OrderStatus.driverAtStore) return 'assets/animations/diambil.json';
    return 'assets/animations/diproses.json';
  }

  // Get current progress index (0-3)
  int _getCurrentStepIndex(OrderStatus status) {
    if (status == OrderStatus.completed || status == OrderStatus.delivered) return 3;
    if (status == OrderStatus.driverHeadingToCustomer || status == OrderStatus.on_delivery) return 2;
    if (status == OrderStatus.driverAtStore) return 1;
    return 0;
  }

  // Main card wrapper
  Widget _buildCardWrapper({required Widget child}) {
    final content = Container(
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
            // Card header
            Row(
              children: [
                Icon(Icons.delivery_dining, color: GlobalStyle.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Status Pesanan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Card content
            child,
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

  @override
  Widget build(BuildContext context) {
    // Loading state
    if (_isLoading) {
      return _buildCardWrapper(
        child: const Center(
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Memuat status pesanan...'),
            ],
          ),
        ),
      );
    }

    // Error state
    if (_errorMessage != null) {
      return _buildCardWrapper(
        child: Column(
          children: [
            Icon(Icons.error_outline, color: Colors.orange),
            const SizedBox(height: 8),
            Text(
              'Gagal memuat data tracking',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: GlobalStyle.fontFamily,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _errorMessage!,
              style: TextStyle(
                fontSize: 12,
                fontFamily: GlobalStyle.fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _fetchTracking,
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlobalStyle.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Coba Lagi'),
              ),
            ),
          ],
        ),
      );
    }

    // Get current status
    final currentStatus = _tracking?.status ?? widget.order.status;

    // Special case for cancelled orders
    if (currentStatus == OrderStatus.cancelled) {
      return _buildCardWrapper(
        child: Column(
          children: [
            Lottie.asset(
              'assets/animations/cancel.json',
              height: 150,
              repeat: true,
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    'Pesanan Dibatalkan',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                      fontFamily: GlobalStyle.fontFamily,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _tracking?.statusMessage ?? _getStatusDescription(currentStatus),
                    style: TextStyle(
                      color: Colors.red[700],
                      fontFamily: GlobalStyle.fontFamily,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Regular order status with timeline
    final currentStepIndex = _getCurrentStepIndex(currentStatus);

    return _buildCardWrapper(
      child: Column(
        children: [
          // Animation
          Center(
            child: Lottie.asset(
              _getAnimationPath(currentStatus),
              height: 150,
              repeat: true,
            ),
          ),

          // Progress steps
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: List.generate(_statusSteps.length, (index) {
                // Step circle
                final isActive = index <= currentStepIndex;
                final statusStep = _statusSteps[index];

                return Expanded(
                  child: Row(
                    children: [
                      // Step icon
                      Column(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: isActive ? statusStep['color'] : Colors.grey[300],
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              statusStep['icon'],
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            statusStep['label'],
                            style: TextStyle(
                              fontSize: 10,
                              color: isActive ? statusStep['color'] : Colors.grey,
                              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                              fontFamily: GlobalStyle.fontFamily,
                            ),
                          ),
                        ],
                      ),

                      // Connecting line (not for last item)
                      if (index < _statusSteps.length - 1)
                        Expanded(
                          child: Container(
                            height: 2,
                            color: index < currentStepIndex ? statusStep['color'] : Colors.grey[300],
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ),
          ),

          // Status description
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getStatusColor(currentStatus).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  _getStatusText(currentStatus),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(currentStatus),
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _tracking?.statusMessage ?? _getStatusDescription(currentStatus),
                  style: TextStyle(
                    color: _getStatusColor(currentStatus).withOpacity(0.8),
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Driver info (if available)
          if (_tracking != null && _tracking!.driverName.isNotEmpty && currentStatus != OrderStatus.completed)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Icon(Icons.person, size: 16, color: GlobalStyle.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    'Driver: ${_tracking!.driverName}',
                    style: TextStyle(
                      fontFamily: GlobalStyle.fontFamily,
                      fontSize: 14,
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
                          const Icon(Icons.access_time, color: Colors.blue, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            'ETA: ${_tracking!.formattedETA}',
                            style: const TextStyle(
                              color: Colors.blue,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
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
  }
}