// driver_order_status.dart - FIXED VERSION
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Models/order.dart';
import 'package:del_pick/Models/order_enum.dart';
import 'package:del_pick/Services/order_service.dart';
import 'package:del_pick/Services/image_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';

import '../../Services/auth_service.dart';

class DriverOrderStatusCard extends StatefulWidget {
  final String? orderId;
  final Map<String, dynamic>? initialOrderData;
  final Animation<Offset>? animation;

  const DriverOrderStatusCard({
    Key? key,
    this.orderId,
    this.initialOrderData,
    this.animation,
  }) : super(key: key);

  @override
  State<DriverOrderStatusCard> createState() => _DriverOrderStatusCardState();
}

class _DriverOrderStatusCardState extends State<DriverOrderStatusCard>
    with TickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  OrderModel? _currentOrder;
  OrderStatus? _previousStatus;
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _statusUpdateTimer;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Driver-specific color theme
  final Color _primaryColor = const Color(0xFF2E7D32);
  final Color _secondaryColor = const Color(0xFF66BB6A);

  // Standardized status timeline with updated animations
  final List<Map<String, dynamic>> _statusTimeline = [
    {
      'status': OrderStatus.pending,
      'label': 'Menunggu',
      'description': 'Pesanan baru masuk',
      'icon': Icons.schedule,
      'color': Colors.orange,
      'animation': 'assets/animations/diambil.json'
    },
    {
      'status': OrderStatus.confirmed,
      'label': 'Dikonfirmasi',
      'description': 'Pesanan diterima toko',
      'icon': Icons.assignment_turned_in,
      'color': Colors.blue,
      'animation': 'assets/animations/diambil.json'
    },
    {
      'status': OrderStatus.preparing,
      'label': 'Disiapkan',
      'description': 'Toko sedang menyiapkan',
      'icon': Icons.restaurant,
      'color': Colors.purple,
      'animation': 'assets/animations/diproses.json'
    },
    {
      'status': OrderStatus.readyForPickup,
      'label': 'Siap Diambil',
      'description': 'Pesanan siap diambil',
      'icon': Icons.shopping_bag,
      'color': Colors.indigo,
      'animation': 'assets/animations/diproses.json'
    },
    {
      'status': OrderStatus.onDelivery,
      'label': 'Diantar',
      'description': 'Dalam perjalanan',
      'icon': Icons.directions_bike,
      'color': Colors.teal,
      'animation': 'assets/animations/diantar.json'
    },
    {
      'status': OrderStatus.delivered,
      'label': 'Selesai',
      'description': 'Pesanan terkirim',
      'icon': Icons.check_circle,
      'color': Colors.green,
      'animation': 'assets/animations/pesanan_selesai.json'
    },
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadOrderData();
    _startStatusPolling();
  }

  /// ✅ ENHANCED: Comprehensive safe type conversion for deeply nested maps
  static Map<String, dynamic> _safeMapConversion(dynamic data) {
    if (data == null) return {};

    if (data is Map<String, dynamic>) {
      return Map<String, dynamic>.from(data);
    } else if (data is Map) {
      // Convert Map<dynamic, dynamic> to Map<String, dynamic> recursively
      return Map<String, dynamic>.from(data.map((key, value) {
        // Recursively convert nested maps
        if (value is Map && value is! Map<String, dynamic>) {
          value = _safeMapConversion(value);
        } else if (value is List) {
          value = _safeListConversion(value);
        }
        return MapEntry(key.toString(), value);
      }));
    }

    return {};
  }

  /// ✅ ENHANCED: Safe type conversion for lists containing maps
  static List<dynamic> _safeListConversion(List<dynamic> list) {
    return list.map((item) {
      if (item is Map && item is! Map<String, dynamic>) {
        return _safeMapConversion(item);
      }
      return item;
    }).toList();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _loadOrderData() async {
    if (widget.initialOrderData != null) {
      // ✅ FIXED: Safe conversion for initial data
      final safeInitialData = _safeMapConversion(widget.initialOrderData!);
      print(
          '🔄 DriverOrderStatusCard: Using initial data, converting safely...');
      _processOrderData(safeInitialData);
      return;
    }

    if (widget.orderId == null) {
      setState(() {
        _errorMessage = 'Order ID tidak tersedia';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print(
          '🔍 DriverOrderStatusCard: Starting data loading for order: ${widget.orderId}');

      // ✅ UPDATED: Enhanced authentication using new methods
      final userData = await AuthService.getUserData();
      final roleSpecificData = await AuthService.getRoleSpecificData();

      if (userData == null || roleSpecificData == null) {
        throw Exception('Authentication required: Please login as driver');
      }

      print('✅ DriverOrderStatusCard: User data obtained');
      print('   - User ID: ${userData['id']}');
      print('   - Role: ${roleSpecificData['role']}');

      // ✅ Additional validation for driver role
      final hasDriverRole = await AuthService.hasRole('driver');
      if (!hasDriverRole) {
        throw Exception('Access denied: Driver authentication required');
      }

      print('✅ DriverOrderStatusCard: Driver access validated');

      // ✅ CHANGED: Use getOrderById instead of getDriverOrders for more accurate data
      print('📡 DriverOrderStatusCard: Fetching order directly by ID...');
      final rawOrderData = await OrderService.getOrderById(widget.orderId!);

      if (rawOrderData == null) {
        throw Exception('Order not found');
      }

      // ✅ CRITICAL: Safe conversion before processing
      final safeOrderData = _safeMapConversion(rawOrderData);
      print(
          '✅ DriverOrderStatusCard: Order data retrieved and converted safely');
      print('   - Order ID: ${safeOrderData['id']}');
      print('   - Status: ${safeOrderData['order_status']}');
      print('   - Driver ID: ${safeOrderData['driver_id']}');

      _processOrderData(safeOrderData);
    } catch (e) {
      print('❌ DriverOrderStatusCard: Error loading data: $e');
      setState(() {
        _errorMessage = 'Gagal memuat data pesanan: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _processOrderData(Map<String, dynamic> orderData) {
    try {
      print('🔄 DriverOrderStatusCard: Processing order data...');
      print('   - Input data type: ${orderData.runtimeType}');
      print('   - Input data keys: ${orderData.keys.toList()}');

      // ✅ CRITICAL: Ensure data is safely converted before creating OrderModel
      final safeOrderData = _safeMapConversion(orderData);

      // Additional safety check for required fields
      if (safeOrderData['id'] == null) {
        throw Exception('Invalid order data: missing ID');
      }

      final newOrder = OrderModel.fromJson(safeOrderData);
      final previousStatus = _currentOrder?.orderStatus;

      setState(() {
        _currentOrder = newOrder;
      });

      print('✅ DriverOrderStatusCard: Order processed successfully');
      print('   - Order ID: ${newOrder.id}');
      print('   - Status: ${newOrder.orderStatus.name}');
      print('   - Customer: ${newOrder.customer?.name ?? "N/A"}');
      print('   - Driver: ${newOrder.driver?.name ?? "N/A"}');

      if (previousStatus != null && previousStatus != newOrder.orderStatus) {
        _handleStatusChange(newOrder.orderStatus);
      } else if (_previousStatus == null) {
        _handleInitialStatus(newOrder.orderStatus);
      }

      _previousStatus = newOrder.orderStatus;
    } catch (e) {
      print('❌ DriverOrderStatusCard: Error processing order data: $e');
      print('   - Data type: ${orderData.runtimeType}');
      print('   - Stack trace: ${StackTrace.current}');
      setState(() {
        _errorMessage = 'Error memproses data pesanan: $e';
      });
    }
  }

  void _handleInitialStatus(OrderStatus status) {
    if ([OrderStatus.cancelled, OrderStatus.rejected].contains(status)) {
      _playCancelSound();
    } else if (status == OrderStatus.pending) {
      _pulseController.repeat(reverse: true);
    }
  }

  void _handleStatusChange(OrderStatus newStatus) {
    if ([OrderStatus.cancelled, OrderStatus.rejected].contains(newStatus)) {
      _playCancelSound();
      _pulseController.stop();
    } else {
      _playStatusChangeSound();
      if (newStatus == OrderStatus.pending) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
      }
    }
  }

  void _startStatusPolling() {
    _statusUpdateTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted && widget.orderId != null) {
        print('🔄 DriverOrderStatusCard: Polling status update...');
        _loadOrderData();
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _pulseController.dispose();
    _statusUpdateTimer?.cancel();
    super.dispose();
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
      await _audioPlayer.play(AssetSource('audio/wrong.mp3'));
    } catch (e) {
      print('Error playing cancel sound: $e');
    }
  }

  Map<String, dynamic> _getCurrentStatusInfo() {
    if (_currentOrder == null) {
      return _statusTimeline[0];
    }

    final currentStatus = _currentOrder!.orderStatus;

    // Handle cancelled/rejected status
    if (currentStatus == OrderStatus.cancelled) {
      return {
        'status': OrderStatus.cancelled,
        'label': 'Dibatalkan',
        'description': 'Pesanan dibatalkan',
        'icon': Icons.cancel_outlined,
        'color': Colors.red,
        'animation': 'assets/animations/cancel.json'
      };
    }

    if (currentStatus == OrderStatus.rejected) {
      return {
        'status': OrderStatus.rejected,
        'label': 'Ditolak',
        'description': 'Pesanan ditolak toko',
        'icon': Icons.block,
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
    if (_currentOrder == null) return 0;
    final currentStatus = _currentOrder!.orderStatus;
    return _statusTimeline
        .indexWhere((item) => item['status'] == currentStatus);
  }

  double _calculateEstimatedEarnings() {
    if (_currentOrder == null) return 0.0;
    const double baseDeliveryFee = 5000.0;
    const double commissionRate = 0.8;
    return baseDeliveryFee + (_currentOrder!.deliveryFee * commissionRate);
  }

  // ✅ FIXED: Helper method to get delivery location info
  String _getDeliveryLocationInfo() {
    if (_currentOrder == null) return 'Lokasi tidak tersedia';

    // Check if we have store information
    if (_currentOrder!.store != null) {
      return _currentOrder!.store!.address;
    }

    // Check if we have destination coordinates
    if (_currentOrder!.destinationLatitude != null &&
        _currentOrder!.destinationLongitude != null) {
      return 'Lat: ${_currentOrder!.destinationLatitude!.toStringAsFixed(4)}, '
          'Lng: ${_currentOrder!.destinationLongitude!.toStringAsFixed(4)}';
    }

    return 'Lokasi tujuan belum tersedia';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingCard();
    }

    if (_errorMessage != null) {
      return _buildErrorCard();
    }

    if (_currentOrder == null) {
      return _buildNoDataCard();
    }

    final currentStatusInfo = _getCurrentStatusInfo();
    final currentStatus = _currentOrder!.orderStatus;
    final currentIndex = _getCurrentStatusIndex();

    Widget content = Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
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
                      Icons.delivery_dining,
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
                          'Status Pengiriman',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                        Text(
                          'Order #${_currentOrder!.id}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_currentOrder!.customer != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 12,
                            child: ImageService.displayProfileImage(
                              imageSource:
                                  _currentOrder!.customer!.avatar ?? '',
                              radius: 12,
                              placeholder: Icon(Icons.person,
                                  size: 16, color: Colors.white),
                              errorWidget: Icon(Icons.person,
                                  size: 16, color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _currentOrder!.customer!.name,
                            style: TextStyle(
                              color: Colors.white,
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

            // Content
            Container(
              color: Colors.white,
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
                        repeat: ![
                          OrderStatus.delivered,
                          OrderStatus.cancelled,
                          OrderStatus.rejected
                        ].contains(currentStatus),
                      ),
                    ),

                  const SizedBox(height: 20),

                  // Status Timeline (only for active orders)
                  if (![OrderStatus.cancelled, OrderStatus.rejected]
                      .contains(currentStatus))
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children:
                            List.generate(_statusTimeline.length, (index) {
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
                                      duration:
                                          const Duration(milliseconds: 300),
                                      width: isCurrent ? 32 : 24,
                                      height: isCurrent ? 32 : 24,
                                      decoration: BoxDecoration(
                                        color: isActive
                                            ? statusItem['color']
                                            : Colors.grey[300],
                                        shape: BoxShape.circle,
                                        boxShadow: isCurrent
                                            ? [
                                                BoxShadow(
                                                  color: statusItem['color']
                                                      .withOpacity(0.4),
                                                  blurRadius: 8,
                                                  spreadRadius: 2,
                                                ),
                                              ]
                                            : [],
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

                  // ✅ FIXED: Delivery location info using helper method
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.grey.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.location_on,
                              size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _getDeliveryLocationInfo(),
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 12,
                                fontFamily: GlobalStyle.fontFamily,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Earnings info
                  if (currentStatus == OrderStatus.delivered)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.monetization_on,
                                size: 16, color: Colors.green),
                            const SizedBox(width: 6),
                            Text(
                              'Pendapatan: ${GlobalStyle.formatRupiah(_calculateEstimatedEarnings())}',
                              style: TextStyle(
                                color: Colors.green,
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

  Widget _buildLoadingCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Center(
        child: Column(
          children: [
            Lottie.asset(
              'assets/animations/diambil.json',
              height: 100,
              width: 100,
            ),
            const SizedBox(height: 16),
            Text(
              'Memuat status pengiriman...',
              style: TextStyle(
                color: Colors.grey[600],
                fontFamily: GlobalStyle.fontFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 60),
          const SizedBox(height: 16),
          Text(
            'Error',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, color: Colors.grey, size: 60),
          const SizedBox(height: 16),
          Text(
            'Tidak ada data pengiriman',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}
