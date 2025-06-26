// ========================================
// STORE ORDER STATUS CARD - COMPLETE FIXED VERSION
// ========================================

// store_order_status.dart - COMPLETE FIXED VERSION
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

class StoreOrderStatusCard extends StatefulWidget {
  final String? orderId;
  final Map<String, dynamic>? initialOrderData;
  final Animation<Offset>? animation;

  const StoreOrderStatusCard({
    Key? key,
    this.orderId,
    this.initialOrderData,
    this.animation,
  }) : super(key: key);

  @override
  State<StoreOrderStatusCard> createState() => _StoreOrderStatusCardState();
}

class _StoreOrderStatusCardState extends State<StoreOrderStatusCard>
    with TickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  OrderModel? _currentOrder;
  OrderStatus? _previousStatus;
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _statusUpdateTimer;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Store-specific color theme
  final Color _primaryColor = const Color(0xFF7B1FA2);
  final Color _secondaryColor = const Color(0xFF9C27B0);

  // Status timeline (same as customer)
  final List<Map<String, dynamic>> _statusTimeline = [
    {
      'status': OrderStatus.pending,
      'label': 'Menunggu',
      'description': 'Pesanan baru masuk',
      'icon': Icons.notification_important,
      'color': Colors.orange,
      'animation': 'assets/animations/diambil.json'
    },
    {
      'status': OrderStatus.confirmed,
      'label': 'Dikonfirmasi',
      'description': 'Pesanan diterima',
      'icon': Icons.thumb_up,
      'color': Colors.blue,
      'animation': 'assets/animations/diambil.json'
    },
    {
      'status': OrderStatus.preparing,
      'label': 'Disiapkan',
      'description': 'Mempersiapkan pesanan',
      'icon': Icons.restaurant_menu,
      'color': Colors.purple,
      'animation': 'assets/animations/diproses.json'
    },
    {
      'status': OrderStatus.readyForPickup,
      'label': 'Siap Diambil',
      'description': 'Siap diambil driver',
      'icon': Icons.shopping_bag,
      'color': Colors.indigo,
      'animation': 'assets/animations/diproses.json'
    },
    {
      'status': OrderStatus.onDelivery,
      'label': 'Diantar',
      'description': 'Dalam perjalanan',
      'icon': Icons.local_shipping,
      'color': Colors.teal,
      'animation': 'assets/animations/diantar.json'
    },
    {
      'status': OrderStatus.delivered,
      'label': 'Selesai',
      'description': 'Pesanan terkirim',
      'icon': Icons.done_all,
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

  /// ✅ COPY EXACT SAME CONVERSION METHODS FROM CustomerOrderStatusCard
  static Map<String, dynamic> _ultraSafeMapConversion(dynamic data, {String context = ''}) {
    if (data == null) {
      print('⚠️ Store _ultraSafeMapConversion: null data in context: $context');
      return {};
    }

    try {
      if (data is Map<String, dynamic>) {
        final result = <String, dynamic>{};
        for (final entry in data.entries) {
          result[entry.key] = _convertValue(entry.value, '${context}.${entry.key}');
        }
        return result;
      }

      if (data is Map) {
        final result = <String, dynamic>{};
        for (final entry in data.entries) {
          final key = entry.key.toString();
          result[key] = _convertValue(entry.value, '${context}.$key');
        }
        return result;
      }

      print('❌ Store _ultraSafeMapConversion: Unexpected data type: ${data.runtimeType} in context: $context');
      return {};

    } catch (e) {
      print('❌ Store _ultraSafeMapConversion error in context $context: $e');
      return {};
    }
  }

  static dynamic _convertValue(dynamic value, String context) {
    if (value == null) return null;

    if (value is Map && value is! Map<String, dynamic>) {
      return _ultraSafeMapConversion(value, context: context);
    } else if (value is Map<String, dynamic>) {
      return _ultraSafeMapConversion(value, context: context);
    } else if (value is List) {
      return _convertList(value, context);
    }

    return value;
  }

  static List<dynamic> _convertList(List<dynamic> list, String context) {
    return list.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      return _convertValue(item, '$context[$index]');
    }).toList();
  }

  static Map<String, dynamic> _fixKnownNestedObjects(Map<String, dynamic> data) {
    final nestedObjects = ['store', 'customer', 'driver', 'user'];
    final nestedLists = ['items', 'order_items', 'tracking_updates'];

    for (final key in nestedObjects) {
      if (data[key] != null && data[key] is Map && data[key] is! Map<String, dynamic>) {
        print('🔧 Store: Fixing nested object: $key');
        data[key] = _ultraSafeMapConversion(data[key], context: key);
      }
    }

    for (final key in nestedLists) {
      if (data[key] != null && data[key] is List) {
        print('🔧 Store: Fixing nested list: $key');
        data[key] = _convertList(data[key] as List, key);
      }
    }

    if (data['driver'] != null &&
        data['driver'] is Map<String, dynamic> &&
        data['driver']['user'] != null &&
        data['driver']['user'] is Map &&
        data['driver']['user'] is! Map<String, dynamic>) {
      print('🔧 Store: Fixing driver.user nested object');
      data['driver']['user'] = _ultraSafeMapConversion(data['driver']['user'], context: 'driver.user');
    }

    return data;
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
      print('🔄 StoreOrderStatusCard: Processing initial data...');

      try {
        final step1 = _ultraSafeMapConversion(widget.initialOrderData!, context: 'store_initial_step1');
        final step2 = _fixKnownNestedObjects(step1);
        final finalData = _ultraSafeMapConversion(step2, context: 'store_initial_final');

        _processOrderData(finalData);
        return;
      } catch (e) {
        print('❌ Store: Error in initial data conversion: $e');
        setState(() {
          _errorMessage = 'Error converting initial data: $e';
        });
        return;
      }
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
      print('🔍 StoreOrderStatusCard: Starting data loading for order: ${widget.orderId}');

      final userData = await AuthService.getUserData();
      final roleSpecificData = await AuthService.getRoleSpecificData();

      if (userData == null || roleSpecificData == null) {
        throw Exception('Authentication required: Please login as store');
      }

      final hasStoreRole = await AuthService.hasRole('store');
      if (!hasStoreRole) {
        throw Exception('Access denied: Store authentication required');
      }

      print('✅ StoreOrderStatusCard: Store access validated');

      final rawOrderData = await OrderService.getOrderById(widget.orderId!);

      if (rawOrderData == null) {
        throw Exception('Order not found');
      }

      try {
        final step1 = _ultraSafeMapConversion(rawOrderData, context: 'store_api_step1');
        final step2 = _fixKnownNestedObjects(step1);
        final finalData = _ultraSafeMapConversion(step2, context: 'store_api_final');

        _processOrderData(finalData);
      } catch (e) {
        print('❌ Store: Error in API data conversion: $e');
        throw Exception('Error converting API data: $e');
      }

    } catch (e) {
      print('❌ StoreOrderStatusCard: Error loading data: $e');
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
      print('🔄 StoreOrderStatusCard: Processing order data...');

      final ultraSafeData = _ultraSafeMapConversion(orderData, context: 'store_final_process');
      final finalSafeData = _fixKnownNestedObjects(ultraSafeData);

      if (finalSafeData['id'] == null) {
        throw Exception('Invalid order data: missing ID');
      }

      final newOrder = OrderModel.fromJson(finalSafeData);
      final previousStatus = _currentOrder?.orderStatus;

      setState(() {
        _currentOrder = newOrder;
      });

      print('✅ StoreOrderStatusCard: Order processed successfully');
      print('   - Order ID: ${newOrder.id}');
      print('   - Status: ${newOrder.orderStatus.name}');

      if (previousStatus != null && previousStatus != newOrder.orderStatus) {
        _handleStatusChange(newOrder.orderStatus);
      } else if (_previousStatus == null) {
        _handleInitialStatus(newOrder.orderStatus);
      }

      _previousStatus = newOrder.orderStatus;

    } catch (e, stackTrace) {
      print('❌ StoreOrderStatusCard: Error processing order data: $e');
      print('   - Stack trace: $stackTrace');

      setState(() {
        _errorMessage = 'Error memproses data pesanan: $e';
      });
    }
  }

  // ... rest of the methods same as customer (handleInitialStatus, etc.)

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
        print('🔄 StoreOrderStatusCard: Polling status update...');
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
        'description': 'Pesanan ditolak',
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
    return _statusTimeline.indexWhere((item) => item['status'] == currentStatus);
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
                      Icons.store,
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
                          'Status Pesanan Toko',
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _currentOrder!.formatTotalAmount(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: GlobalStyle.fontFamily,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content (same structure as customer but with store-specific info)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Animation (same as customer)
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
                        repeat: ![OrderStatus.delivered, OrderStatus.cancelled, OrderStatus.rejected].contains(currentStatus),
                      ),
                    ),

                  const SizedBox(height: 20),

                  // Status Timeline (same as customer)
                  if (![OrderStatus.cancelled, OrderStatus.rejected].contains(currentStatus))
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
                                        fontSize: 9,
                                        color: isActive
                                            ? statusItem['color']
                                            : Colors.grey,
                                        fontWeight: isCurrent
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        fontFamily: GlobalStyle.fontFamily,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
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

                  // Status Message (same structure as customer)
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

                  // Customer info (different from customer card - shows customer instead of store)
                  if (_currentOrder!.customer != null)
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
                            CircleAvatar(
                              radius: 16,
                              child: ImageService.displayProfileImage(
                                imageSource: _currentOrder!.customer!.avatar ?? '',
                                radius: 16,
                                placeholder: Icon(Icons.person, size: 18, color: Colors.grey[600]),
                                errorWidget: Icon(Icons.person, size: 18, color: Colors.grey[600]),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _currentOrder!.customer!.name,
                                    style: TextStyle(
                                      color: Colors.grey[800],
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: GlobalStyle.fontFamily,
                                    ),
                                  ),
                                  Text(
                                    _currentOrder!.customer!.phone,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                      fontFamily: GlobalStyle.fontFamily,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.phone, size: 16, color: Colors.grey[600]),
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
              'Memuat status pesanan toko...',
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
            'Tidak ada data pesanan',
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