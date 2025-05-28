import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Models/order.dart';
import 'package:del_pick/Services/order_service.dart';
import '../../Models/order_enum.dart';

class OrderStatusCard extends StatefulWidget {
  final String orderId;
  final String userRole; // 'store', 'driver', or 'admin'
  final Animation<Offset>? animation;
  final Function()? onStatusUpdate;

  const OrderStatusCard({
    Key? key,
    required this.orderId,
    required this.userRole,
    this.animation,
    this.onStatusUpdate,
  }) : super(key: key);

  @override
  State<OrderStatusCard> createState() => _OrderStatusCardState();
}

class _OrderStatusCardState extends State<OrderStatusCard> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _previousStatus;

  Map<String, dynamic>? _orderDetail;
  bool _isLoading = true;
  String? _errorMessage;
  int _retryCount = 0;
  final int _maxRetries = 3;

  // Map of allowed status transitions based on user role
  final Map<String, Map<String, dynamic>> _allowedTransitions = {
    'store': {
      'from': 'pending',
      'to': ['approved', 'preparing', 'cancelled']
    },
    'driver': {
      'from': 'preparing',
      'to': ['on_delivery', 'delivered']
    },
    'admin': {
      'from': '*',
      'to': [
        'pending', 'approved', 'preparing', 'cancelled',
        'on_delivery', 'delivered', 'completed',
        'driverAssigned', 'driverHeadingToStore', 'driverAtStore',
        'driverHeadingToCustomer', 'driverArrived'
      ]
    }
  };

  // Status definitions for UI representation
  final List<Map<String, dynamic>> _statusSteps = [
    {
      'status': 'preparing',
      'label': 'Di Proses',
      'icon': Icons.store_outlined,
      'color': Colors.blue,
      'animation': 'assets/animations/diproses.json',
    },
    {
      'status': 'on_delivery',
      'label': 'Di Antar',
      'icon': Icons.directions_bike_outlined,
      'color': Colors.purple,
      'animation': 'assets/animations/diantar.json',
    },
    {
      'status': 'delivered',
      'label': 'Selesai',
      'icon': Icons.check_circle_outline,
      'color': Colors.green,
      'animation': 'assets/animations/pesanan_selesai.json',
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchOrderDetail();
  }

  @override
  void didUpdateWidget(OrderStatusCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Fetch new order details if order ID changes
    if (oldWidget.orderId != widget.orderId) {
      _fetchOrderDetail();
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  // Fetch order details using OrderService
  Future<void> _fetchOrderDetail() async {
    if (widget.orderId.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Order ID tidak valid';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Use OrderService to get order details
      final orderDetailData = await OrderService.getOrderDetail(widget.orderId);

      setState(() {
        _orderDetail = orderDetailData;
        _isLoading = false;
        _retryCount = 0; // Reset retry count on success

        // Play sound if status has changed
        String currentStatus = _orderDetail?['order_status'] ?? '';
        if (_previousStatus != null && _previousStatus != currentStatus) {
          if (currentStatus == 'cancelled') {
            _audioPlayer.play(AssetSource('audio/found.wav'));
          } else {
            _audioPlayer.play(AssetSource('audio/kring.mp3'));
          }
        }
        _previousStatus = currentStatus;
      });

      if (widget.onStatusUpdate != null) {
        widget.onStatusUpdate!();
      }
    } catch (e) {
      print('Error fetching order detail: $e');

      // Check if we should retry
      if (_retryCount < _maxRetries) {
        _retryCount++;
        setState(() {
          _errorMessage = 'Mencoba lagi... (${_retryCount}/${_maxRetries})';
          _isLoading = false;
        });

        // Wait 2 seconds before retrying
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            _fetchOrderDetail();
          }
        });
      } else {
        // Format a more user-friendly error message
        String errorMsg = 'Gagal memuat detail pesanan';

        // Check for specific error types to give better messages
        if (e.toString().contains('<!DOCTYPE html>') ||
            e.toString().contains('FormatException')) {
          errorMsg = 'Server sedang dalam pemeliharaan. Coba lagi nanti.';
        } else if (e.toString().contains('SocketException') ||
            e.toString().contains('Connection refused')) {
          errorMsg = 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.';
        }

        setState(() {
          _errorMessage = errorMsg;
          _isLoading = false;
        });
      }
    }
  }

  // Update order status
  Future<void> _updateOrderStatus(String newStatus) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await OrderService.updateOrderStatus(widget.orderId, newStatus);
      // Refetch order details after update
      await _fetchOrderDetail();

      if (widget.onStatusUpdate != null) {
        widget.onStatusUpdate!();
      }

      // Show success snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status pesanan berhasil diubah ke $newStatus'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error updating order status: $e');
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengubah status pesanan: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Check if current user role can update to a specific status
  bool _canUpdateToStatus(String currentStatus, String targetStatus) {
    final roleRules = _allowedTransitions[widget.userRole];
    if (roleRules == null) return false;

    // Admin can update to any valid status
    if (widget.userRole == 'admin') return true;

    // Check if current status matches the 'from' condition
    if (roleRules['from'] == '*' || roleRules['from'] == currentStatus) {
      // Check if target status is in the allowed 'to' list
      return (roleRules['to'] as List).contains(targetStatus);
    }

    return false;
  }

  // Get current status text
  String _getStatusText(String status) {
    switch (status) {
      case 'cancelled':
        return 'Pesanan Dibatalkan';
      case 'completed':
      case 'delivered':
        return 'Pesanan Selesai';
      case 'pending':
        return 'Menunggu Konfirmasi';
      case 'approved':
        return 'Pesanan Disetujui';
      case 'preparing':
        return 'Sedang Dipersiapkan';
      case 'driverAssigned':
        return 'Driver Ditugaskan';
      case 'driverHeadingToStore':
        return 'Driver Menuju Toko';
      case 'driverAtStore':
        return 'Driver di Toko';
      case 'driverHeadingToCustomer':
      case 'on_delivery':
        return 'Driver Menuju Anda';
      case 'driverArrived':
        return 'Driver Tiba';
      default:
        return 'Pesanan Diproses';
    }
  }

  // Get status description
  String _getStatusDescription(String status) {
    switch (status) {
      case 'cancelled':
        return 'Pesanan Anda telah dibatalkan';
      case 'completed':
      case 'delivered':
        return 'Pesanan Anda telah diterima dan selesai';
      case 'pending':
        return 'Pesanan Anda sedang menunggu konfirmasi';
      case 'approved':
        return 'Pesanan Anda telah disetujui oleh toko';
      case 'preparing':
        return 'Toko sedang mempersiapkan pesanan Anda';
      case 'driverAssigned':
        return 'Driver telah ditugaskan untuk pesanan Anda';
      case 'driverHeadingToStore':
        return 'Driver sedang menuju ke toko untuk mengambil pesanan Anda';
      case 'driverAtStore':
        return 'Driver telah tiba di toko dan sedang mengambil pesanan Anda';
      case 'driverHeadingToCustomer':
      case 'on_delivery':
        return 'Driver sedang dalam perjalanan mengantarkan pesanan ke lokasi Anda';
      case 'driverArrived':
        return 'Driver telah tiba di lokasi Anda. Silahkan terima pesanan Anda';
      default:
        return 'Pesanan Anda sedang diproses';
    }
  }

  // Get status color
  Color _getStatusColor(String status) {
    if (status == 'cancelled') return Colors.red;
    if (status == 'completed' || status == 'delivered') return Colors.green;
    if (status == 'driverHeadingToCustomer' || status == 'on_delivery') return Colors.purple;
    if (status == 'driverAtStore') return Colors.orange;
    if (status == 'preparing') return Colors.blue;
    return Colors.blue;
  }

  // Get animation path for status
  String _getAnimationPath(String status) {
    if (status == 'cancelled') {
      return 'assets/animations/cancel.json';
    } else if (status == 'completed' || status == 'delivered') {
      return 'assets/animations/pesanan_selesai.json';
    } else if (status == 'driverHeadingToCustomer' || status == 'on_delivery') {
      return 'assets/animations/diantar.json';
    } else if (status == 'driverAtStore') {
      return 'assets/animations/diambil.json';
    } else {
      return 'assets/animations/diproses.json';
    }
  }

  // Get current progress index (0-2)
  int _getCurrentStepIndex(String status) {
    if (status == 'completed' || status == 'delivered') {
      return 2;
    } else if (status == 'driverHeadingToCustomer' || status == 'on_delivery') {
      return 1;
    } else if (status == 'driverAtStore' || status == 'preparing' || status == 'approved') {
      return 0;
    } else {
      return -1; // Not started yet
    }
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

  // Build action buttons for status updates based on role
  Widget _buildActionButtons(String currentStatus) {
    final roleRules = _allowedTransitions[widget.userRole];
    if (roleRules == null) return const SizedBox.shrink(); // No actions for this role

    // Check if current status matches the 'from' condition
    if (roleRules['from'] != '*' && roleRules['from'] != currentStatus) {
      return const SizedBox.shrink(); // Cannot update from this status
    }

    // Get list of possible target statuses
    final List<String> allowedStatuses = List<String>.from(roleRules['to']);

    // Don't show action buttons if already canceled or completed
    if (currentStatus == 'cancelled' || currentStatus == 'delivered' || currentStatus == 'completed') {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'Ubah Status:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: allowedStatuses.map((status) {
            // Skip current status
            if (status == currentStatus) return const SizedBox.shrink();

            Color buttonColor;
            if (status == 'cancelled') {
              buttonColor = Colors.red;
            } else if (status == 'delivered' || status == 'completed') {
              buttonColor = Colors.green;
            } else {
              buttonColor = GlobalStyle.primaryColor;
            }

            return ElevatedButton(
              onPressed: () => _updateOrderStatus(status),
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontSize: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: Text(_getStatusText(status)),
            );
          }).toList()
            ..removeWhere((widget) => widget is SizedBox && widget.width == 0), // Remove empty widgets
        ),
      ],
    );
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

    // Error state with improved display and retry button
    if (_errorMessage != null) {
      return _buildCardWrapper(
        child: Column(
          children: [
            Lottie.asset(
              'assets/animations/error.json',
              height: 120,
              width: 120,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 8),
            Text(
              'Gagal memuat data pesanan',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: GlobalStyle.fontFamily,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _errorMessage!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontFamily: GlobalStyle.fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _retryCount = 0; // Reset retry count when manually retrying
                  });
                  _fetchOrderDetail();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlobalStyle.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'Coba Lagi',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Get current status from order details
    final currentStatus = _orderDetail?['order_status'] ?? 'pending';

    // Special case for cancelled orders
    if (currentStatus == 'cancelled') {
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
                    _getStatusDescription(currentStatus),
                    style: TextStyle(
                      color: Colors.red[700],
                      fontFamily: GlobalStyle.fontFamily,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Show order items if available
            if (_orderDetail != null && _orderDetail!['items'] != null)
              _buildOrderItems(_orderDetail!['items']),

            // Show action buttons based on role
            _buildActionButtons(currentStatus),
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
          if (currentStepIndex >= 0)
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
                  _getStatusDescription(currentStatus),
                  style: TextStyle(
                    color: _getStatusColor(currentStatus).withOpacity(0.8),
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Show order items if available
          if (_orderDetail != null && _orderDetail!['items'] != null)
            _buildOrderItems(_orderDetail!['items']),

          // Show total price
          if (_orderDetail != null && _orderDetail!['total'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Total:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: GlobalStyle.fontFamily,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Rp ${_orderDetail!['total']}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: GlobalStyle.primaryColor,
                      fontFamily: GlobalStyle.fontFamily,
                    ),
                  ),
                ],
              ),
            ),

          // Show action buttons based on role
          _buildActionButtons(currentStatus),
        ],
      ),
    );
  }

  // Build order items list
  Widget _buildOrderItems(List<dynamic> items) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detail Pesanan:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      '${item['quantity']}x',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: GlobalStyle.primaryColor,
                        fontFamily: GlobalStyle.fontFamily,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item['name'],
                        style: TextStyle(
                          fontFamily: GlobalStyle.fontFamily,
                        ),
                      ),
                    ),
                    Text(
                      'Rp ${item['price']}',
                      style: TextStyle(
                        fontFamily: GlobalStyle.fontFamily,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}