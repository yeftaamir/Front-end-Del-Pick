// cust_order_status.dart - COMPLETE FIXED VERSION
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

class CustomerOrderStatusCard extends StatefulWidget {
  final String? orderId;
  final Map<String, dynamic>? initialOrderData;
  final Animation<Offset>? animation;

  const CustomerOrderStatusCard({
    Key? key,
    this.orderId,
    this.initialOrderData,
    this.animation,
  }) : super(key: key);

  @override
  State<CustomerOrderStatusCard> createState() => _CustomerOrderStatusCardState();
}

class _CustomerOrderStatusCardState extends State<CustomerOrderStatusCard>
    with TickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  OrderModel? _currentOrder;
  OrderStatus? _previousStatus;
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _statusUpdateTimer;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Customer-specific color theme
  final Color _primaryColor = const Color(0xFF4A90E2);
  final Color _secondaryColor = const Color(0xFF7BB3F0);

  // Standardized status timeline
  final List<Map<String, dynamic>> _statusTimeline = [
    {
      'status': OrderStatus.pending,
      'label': 'Menunggu',
      'description': 'Menunggu konfirmasi toko',
      'icon': Icons.hourglass_empty,
      'color': Colors.orange,
      'animation': 'assets/animations/diambil.json'
    },
    {
      'status': OrderStatus.confirmed,
      'label': 'Dikonfirmasi',
      'description': 'Pesanan dikonfirmasi toko',
      'icon': Icons.check_circle_outline,
      'color': Colors.blue,
      'animation': 'assets/animations/diambil.json'
    },
    {
      'status': OrderStatus.preparing,
      'label': 'Disiapkan',
      'description': 'Pesanan sedang disiapkan',
      'icon': Icons.restaurant,
      'color': Colors.purple,
      'animation': 'assets/animations/diproses.json'
    },
    {
      'status': OrderStatus.readyForPickup,
      'label': 'Siap Diambil',
      'description': 'Pesanan siap diambil driver',
      'icon': Icons.shopping_bag,
      'color': Colors.indigo,
      'animation': 'assets/animations/diproses.json'
    },
    {
      'status': OrderStatus.onDelivery,
      'label': 'Diantar',
      'description': 'Pesanan dalam perjalanan',
      'icon': Icons.delivery_dining,
      'color': Colors.teal,
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
    _initializeAnimations();
    _loadOrderData();
    _startStatusPolling();
  }

  /// ✅ ULTIMATE FIX: Deep recursive type conversion dengan nested object handling
  static Map<String, dynamic> _ultraSafeMapConversion(dynamic data, {String context = ''}) {
    if (data == null) {
      print('⚠️ _ultraSafeMapConversion: null data in context: $context');
      return {};
    }

    try {
      // Case 1: Already Map<String, dynamic> - still need to check nested
      if (data is Map<String, dynamic>) {
        final result = <String, dynamic>{};
        for (final entry in data.entries) {
          result[entry.key] = _convertValue(entry.value, '${context}.${entry.key}');
        }
        return result;
      }

      // Case 2: Map<dynamic, dynamic> - convert keys and values
      if (data is Map) {
        final result = <String, dynamic>{};
        for (final entry in data.entries) {
          final key = entry.key.toString();
          result[key] = _convertValue(entry.value, '${context}.$key');
        }
        return result;
      }

      // Case 3: Not a map
      print('❌ _ultraSafeMapConversion: Unexpected data type: ${data.runtimeType} in context: $context');
      return {};

    } catch (e) {
      print('❌ _ultraSafeMapConversion error in context $context: $e');
      return {};
    }
  }

  /// ✅ Helper: Convert individual values recursively
  static dynamic _convertValue(dynamic value, String context) {
    if (value == null) return null;

    if (value is Map && value is! Map<String, dynamic>) {
      // Recursively convert nested maps
      return _ultraSafeMapConversion(value, context: context);
    } else if (value is Map<String, dynamic>) {
      // Still process to ensure nested maps are converted
      return _ultraSafeMapConversion(value, context: context);
    } else if (value is List) {
      // Process lists that might contain maps
      return _convertList(value, context);
    }

    return value;
  }

  /// ✅ Helper: Convert lists containing maps
  static List<dynamic> _convertList(List<dynamic> list, String context) {
    return list.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      return _convertValue(item, '$context[$index]');
    }).toList();
  }

  /// ✅ Helper: Validate and fix known nested objects
  static Map<String, dynamic> _fixKnownNestedObjects(Map<String, dynamic> data) {
    // Known problematic nested objects in OrderModel
    final nestedObjects = ['store', 'customer', 'driver', 'user'];
    final nestedLists = ['items', 'order_items', 'tracking_updates'];

    // Fix nested objects
    for (final key in nestedObjects) {
      if (data[key] != null && data[key] is Map && data[key] is! Map<String, dynamic>) {
        print('🔧 Fixing nested object: $key');
        data[key] = _ultraSafeMapConversion(data[key], context: key);
      }
    }

    // Fix nested lists
    for (final key in nestedLists) {
      if (data[key] != null && data[key] is List) {
        print('🔧 Fixing nested list: $key');
        data[key] = _convertList(data[key] as List, key);
      }
    }

    // Special handling for driver.user nested structure
    if (data['driver'] != null &&
        data['driver'] is Map<String, dynamic> &&
        data['driver']['user'] != null &&
        data['driver']['user'] is Map &&
        data['driver']['user'] is! Map<String, dynamic>) {
      print('🔧 Fixing driver.user nested object');
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
      print('🔄 CustomerOrderStatusCard: Processing initial data...');
      print('   - Initial data type: ${widget.initialOrderData.runtimeType}');
      print('   - Initial data keys: ${widget.initialOrderData!.keys.toList()}');

      // ✅ ULTIMATE FIX: Triple-layer safety conversion
      try {
        // Layer 1: Basic conversion
        final step1 = _ultraSafeMapConversion(widget.initialOrderData!, context: 'initial_step1');
        print('✅ Step 1 completed: ${step1.runtimeType}');

        // Layer 2: Fix known nested objects
        final step2 = _fixKnownNestedObjects(step1);
        print('✅ Step 2 completed: ${step2.runtimeType}');

        // Layer 3: Final validation and conversion
        final finalData = _ultraSafeMapConversion(step2, context: 'initial_final');
        print('✅ Final conversion completed: ${finalData.runtimeType}');

        _processOrderData(finalData);
        return;
      } catch (e) {
        print('❌ Error in initial data conversion: $e');
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
      print('🔍 CustomerOrderStatusCard: Starting data loading for order: ${widget.orderId}');

      // Authentication validation
      final userData = await AuthService.getUserData();
      final roleSpecificData = await AuthService.getRoleSpecificData();

      if (userData == null || roleSpecificData == null) {
        throw Exception('Authentication required: Please login as customer');
      }

      final hasAccess = await AuthService.validateCustomerAccess();
      if (!hasAccess) {
        throw Exception('Access denied: Customer authentication required');
      }

      print('✅ CustomerOrderStatusCard: Customer access validated');

      // API call
      print('📡 CustomerOrderStatusCard: Fetching order directly by ID...');
      final rawOrderData = await OrderService.getOrderById(widget.orderId!);

      if (rawOrderData == null) {
        throw Exception('Order not found');
      }

      print('📡 CustomerOrderStatusCard: Raw API response received');
      print('   - Raw data type: ${rawOrderData.runtimeType}');

      // ✅ ULTIMATE FIX: Triple-layer safety conversion for API data
      try {
        // Layer 1: Basic conversion
        final step1 = _ultraSafeMapConversion(rawOrderData, context: 'api_step1');
        print('✅ API Step 1 completed: ${step1.runtimeType}');

        // Layer 2: Fix known nested objects
        final step2 = _fixKnownNestedObjects(step1);
        print('✅ API Step 2 completed: ${step2.runtimeType}');

        // Layer 3: Final validation and conversion
        final finalData = _ultraSafeMapConversion(step2, context: 'api_final');
        print('✅ API Final conversion completed: ${finalData.runtimeType}');

        _processOrderData(finalData);
      } catch (e) {
        print('❌ Error in API data conversion: $e');
        throw Exception('Error converting API data: $e');
      }

    } catch (e) {
      print('❌ CustomerOrderStatusCard: Error loading data: $e');
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
      print('🔄 CustomerOrderStatusCard: Processing order data...');
      print('   - Input data type: ${orderData.runtimeType}');
      print('   - Input data keys: ${orderData.keys.toList()}');

      // ✅ FINAL SAFETY CHECK: One more ultra-safe conversion
      final ultraSafeData = _ultraSafeMapConversion(orderData, context: 'final_process');
      final finalSafeData = _fixKnownNestedObjects(ultraSafeData);

      // Debug nested objects before OrderModel creation
      _debugNestedObjects(finalSafeData);

      // Validate required fields
      if (finalSafeData['id'] == null) {
        throw Exception('Invalid order data: missing ID');
      }

      print('🚀 CustomerOrderStatusCard: Creating OrderModel...');

      // Create OrderModel with ultra-safe data
      final newOrder = OrderModel.fromJson(finalSafeData);
      final previousStatus = _currentOrder?.orderStatus;

      setState(() {
        _currentOrder = newOrder;
      });

      print('✅ CustomerOrderStatusCard: Order processed successfully');
      print('   - Order ID: ${newOrder.id}');
      print('   - Status: ${newOrder.orderStatus.name}');
      print('   - Customer: ${newOrder.customer?.name ?? "N/A"}');
      print('   - Store: ${newOrder.store?.name ?? "N/A"}');

      if (previousStatus != null && previousStatus != newOrder.orderStatus) {
        _handleStatusChange(newOrder.orderStatus);
      } else if (_previousStatus == null) {
        _handleInitialStatus(newOrder.orderStatus);
      }

      _previousStatus = newOrder.orderStatus;

    } catch (e, stackTrace) {
      print('❌ CustomerOrderStatusCard: Error processing order data: $e');
      print('   - Input data type: ${orderData.runtimeType}');
      print('   - Full stack trace: $stackTrace');

      // Enhanced error debugging
      _debugDataStructure(orderData);

      setState(() {
        _errorMessage = 'Error memproses data pesanan: $e';
      });
    }
  }

  /// ✅ Debug helper untuk nested objects
  void _debugNestedObjects(Map<String, dynamic> data) {
    final nestedObjects = ['store', 'customer', 'driver', 'items'];

    for (final key in nestedObjects) {
      if (data[key] != null) {
        print('🔍 Debug $key:');
        print('   - Type: ${data[key].runtimeType}');
        print('   - Is Map<String, dynamic>: ${data[key] is Map<String, dynamic>}');

        if (data[key] is Map) {
          final map = data[key] as Map;
          print('   - Keys: ${map.keys.toList()}');

          // Check nested user object in driver
          if (key == 'driver' && map['user'] != null) {
            print('   - Driver.user type: ${map['user'].runtimeType}');
            print('   - Driver.user is Map<String, dynamic>: ${map['user'] is Map<String, dynamic>}');
          }
        } else if (data[key] is List) {
          final list = data[key] as List;
          print('   - Length: ${list.length}');
          if (list.isNotEmpty) {
            print('   - First item type: ${list.first.runtimeType}');
            print('   - First item is Map<String, dynamic>: ${list.first is Map<String, dynamic>}');
          }
        }
      }
    }
  }

  /// ✅ Debug helper untuk full data structure
  void _debugDataStructure(Map<String, dynamic> data) {
    print('🔍 Full data structure debug:');

    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;

      print('   - $key: ${value.runtimeType}');

      if (value is Map && value is! Map<String, dynamic>) {
        print('     ❌ PROBLEM: Map is not Map<String, dynamic>');
        print('     - Actual type: ${value.runtimeType}');
        if (value is Map) {
          print('     - Keys: ${value.keys.toList()}');
        }
      } else if (value is List) {
        print('     - List length: ${value.length}');
        if (value.isNotEmpty) {
          final firstItem = value.first;
          print('     - First item type: ${firstItem.runtimeType}');
          if (firstItem is Map && firstItem is! Map<String, dynamic>) {
            print('     ❌ PROBLEM: List contains Map that is not Map<String, dynamic>');
          }
        }
      }
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
        print('🔄 CustomerOrderStatusCard: Polling status update...');
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
                      color: Colors.white.withOpacity(0.2),
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
                        repeat: ![OrderStatus.delivered, OrderStatus.cancelled, OrderStatus.rejected].contains(currentStatus),
                      ),
                    ),

                  const SizedBox(height: 20),

                  // Status Timeline
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

                  // Store info
                  if (_currentOrder!.store != null)
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
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: ImageService.displayImage(
                                imageSource: _currentOrder!.store!.imageUrl ?? '',
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                placeholder: Container(
                                  width: 40,
                                  height: 40,
                                  color: Colors.grey[300],
                                  child: Icon(Icons.store, color: Colors.grey[600], size: 20),
                                ),
                                errorWidget: Container(
                                  width: 40,
                                  height: 40,
                                  color: Colors.grey[300],
                                  child: Icon(Icons.store, color: Colors.grey[600], size: 20),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _currentOrder!.store!.name,
                                    style: TextStyle(
                                      color: Colors.grey[800],
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: GlobalStyle.fontFamily,
                                    ),
                                  ),
                                  Text(
                                    '${_currentOrder!.totalItems} item',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                      fontFamily: GlobalStyle.fontFamily,
                                    ),
                                  ),
                                ],
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
              'Memuat status pesanan...',
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