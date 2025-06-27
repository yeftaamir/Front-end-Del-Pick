import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:del_pick/Views/Component/bottom_navigation.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Views/Store/history_store_detail.dart';
import 'package:del_pick/Views/Store/profil_store.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:lottie/lottie.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';

// Import updated services
import 'package:del_pick/Services/order_service.dart';
import 'package:del_pick/Services/auth_service.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeStore extends StatefulWidget {
  static const String route = '/Store/HomePage';

  const HomeStore({Key? key}) : super(key: key);

  @override
  State<HomeStore> createState() => _HomeStoreState();
}

class _HomeStoreState extends State<HomeStore> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late List<AnimationController> _cardControllers = [];
  late List<Animation<Offset>> _cardAnimations = [];
  late AnimationController _celebrationController;
  late AnimationController _pulseController;
  late AnimationController _rotationController;

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Service data
  List<Map<String, dynamic>> _orders = [];
  Map<String, dynamic>? _storeData;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  int _currentPage = 1;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  bool _isAutoRefreshing = false;
  final ScrollController _scrollController = ScrollController();

  // New order celebration
  String? _newOrderId;
  bool _showCelebration = false;

  // Real-time order monitoring
  Timer? _orderMonitorTimer;
  Set<String> _existingOrderIds = {};

  ///state management untuk melacak perubahan
  Set<String> _processedOrderIds = <String>{}; // Track processed orders locally
  static final Set<String> _globalProcessedOrderIds = <String>{};
  bool _needsRefresh =
      false; // Flag untuk refresh saat kembali dari halaman lain
  DateTime? _lastRefreshTime; // Track last refresh time
  // static const List<String> _excludedOrderStatuses = [
  //   // 'confirmed',
  //   'preparing',
  //   'ready_for_pickup',
  //   'on_delivery',
  //   'delivered',
  //   'cancelled',
  //   'rejected'
  // ];
  //
  // static const List<String> _excludedDeliveryStatuses = [
  //   'picked_up',
  //   'on_way',
  //   'delivered'
  // ];

// ✅ GANTI: Filter logic yang benar
  static bool _shouldShowOrder(Map<String, dynamic> order) {
    final orderStatus = order['order_status']?.toString() ?? '';
    final deliveryStatus = order['delivery_status']?.toString() ?? '';

    print(
        '🔍 Checking order ${order['id']}: order_status=$orderStatus, delivery_status=$deliveryStatus');

    // ✅ ATURAN BISNIS YANG BENAR:
    // - order_status = 'pending' (apapun delivery_status) → TAMPILKAN
    // - order_status selain 'pending' → JANGAN TAMPILKAN

    return orderStatus == 'pending';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check if we need to refresh when returning from other pages
    if (_needsRefresh) {
      _needsRefresh = false;
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          // ✅ PERBAIKAN: Gunakan filtered refresh alih-alih force refresh
          _refreshOrdersWithFiltering();
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeNotifications();
    _requestPermissions();
    _validateAndInitializeData();
    _setupScrollListener();
  }

  void _startOrderMonitoring() {
    print(
        '🔄 HomeStore: Starting real-time order monitoring (20s interval)...');

    _orderMonitorTimer =
        Timer.periodic(const Duration(seconds: 20), (timer) async {
      // ✅ FIXED: 20 detik
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _isAutoRefreshing = true;
      });

      try {
        print('📡 HomeStore: Checking for order updates...');

        final response = await OrderService.getOrdersByStore(
          page: 1,
          limit: 20,
          sortBy: 'created_at',
          sortOrder: 'desc',
          timestamp:
              DateTime.now().millisecondsSinceEpoch, // ✅ SELALU bypass cache
        );

        final allLatestOrders =
            List<Map<String, dynamic>>.from(response['orders'] ?? []);

        // ✅ FIXED: Apply correct business logic filter
        final latestValidOrders = allLatestOrders.where((order) {
          final orderId = order['id']?.toString() ?? '';

          // ✅ Gunakan business logic yang benar
          if (!_shouldShowOrder(order)) {
            return false;
          }

          // ✅ Exclude yang sudah diproses
          if (_globalProcessedOrderIds.contains(orderId) ||
              _processedOrderIds.contains(orderId)) {
            return false;
          }

          return true;
        }).toList();

        // ✅ Compare dengan current orders
        final currentValidOrderIds = filteredOrders
            .map((order) => order['id']?.toString() ?? '')
            .toSet();

        final latestValidOrderIds = latestValidOrders
            .map((order) => order['id']?.toString() ?? '')
            .toSet();

        final newOrderIds =
            latestValidOrderIds.difference(currentValidOrderIds);
        final removedOrderIds =
            currentValidOrderIds.difference(latestValidOrderIds);

        bool hasChanges = newOrderIds.isNotEmpty || removedOrderIds.isNotEmpty;

        if (hasChanges) {
          print(
              '🔄 HomeStore: Real-time changes detected - New: ${newOrderIds.length}, Removed: ${removedOrderIds.length}');

          // ✅ Mark removed orders as globally processed
          for (String removedId in removedOrderIds) {
            _globalProcessedOrderIds.add(removedId);
            print(
                '📝 Order $removedId marked as globally processed (status changed from pending)');
          }

          setState(() {
            // Dispose old controllers
            for (var controller in _cardControllers) {
              controller.dispose();
            }

            _orders = latestValidOrders;
            _existingOrderIds = latestValidOrderIds;

            // Reinitialize animations
            _initialAnimations();
          });

          // Start animations
          _startAnimations();

          // Show notifications for new orders only
          for (String orderId in newOrderIds) {
            final newOrder = latestValidOrders.firstWhere(
              (order) => order['id']?.toString() == orderId,
              orElse: () => {},
            );
            if (newOrder.isNotEmpty) {
              _triggerNewOrderCelebration(orderId);
              _showNotification(newOrder);
            }
          }

          // Show feedback for removed orders
          if (mounted && removedOrderIds.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.sync, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text(
                        '${removedOrderIds.length} pesanan diperbarui (status berubah)'),
                  ],
                ),
                backgroundColor: Colors.blue,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else {
          print('✅ HomeStore: No real-time changes detected');
        }

        setState(() {
          _isAutoRefreshing = false;
        });
      } catch (e) {
        print('❌ HomeStore: Error during real-time monitoring: $e');
        setState(() {
          _isAutoRefreshing = false;
        });
      }
    });
  }

  void _initializeAnimations() {
    _celebrationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _pulseController.repeat(reverse: true);
    _rotationController.repeat();
  }

// ✅ PERBAIKAN: Enhanced validation dengan proper mounted checks
  Future<void> _validateAndInitializeData() async {
    try {
      // ✅ Early mounted check
      if (!mounted) {
        print('⚠️ HomeStore: Widget not mounted, skipping initialization');
        return;
      }

      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      print('🏪 HomeStore: Starting validation and initialization...');

      // ✅ FIXED: Validate store access menggunakan AuthService yang benar
      final hasStoreAccess = await AuthService.hasRole('store');

      if (!mounted) return; // Check after async call

      if (!hasStoreAccess) {
        throw Exception('Access denied: Store authentication required');
      }

      // ✅ FIXED: Ensure valid user session
      final hasValidSession = await AuthService.ensureValidUserData();

      if (!mounted) return; // Check after async call

      if (!hasValidSession) {
        throw Exception('Invalid user session. Please login again.');
      }

      print('✅ HomeStore: Store access validated');

      // Load store-specific data
      await _loadStoreData();

      if (!mounted) return; // Check after loading store data

      // Load orders only (statistics removed)
      await _loadOrders();

      if (!mounted) return; // Check after loading orders
      // ✅ TAMBAH: Start real-time monitoring setelah data berhasil dimuat
      _startOrderMonitoring();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      print('✅ HomeStore: Initialization completed successfully');
    } catch (e) {
      print('❌ HomeStore: Initialization error: $e');

      // ✅ Only update state if still mounted
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // ✅ FIXED: Enhanced store data loading dengan AuthService yang benar
  // Add mounted checks untuk mencegah setState after dispose
  Future<void> _loadStoreData() async {
    try {
      print('🔍 HomeStore: Loading store data...');

      // ✅ Check mounted sebelum operasi async
      if (!mounted) {
        print('⚠️ HomeStore: Widget not mounted, skipping store data load');
        return;
      }

      // ✅ FIXED: Get role-specific data menggunakan AuthService
      final roleData = await AuthService.getRoleSpecificData();

      // ✅ Check mounted setelah operasi async
      if (!mounted) {
        print('⚠️ HomeStore: Widget not mounted after getRoleSpecificData');
        return;
      }

      if (roleData != null && roleData['store'] != null) {
        // ✅ Only call setState if mounted
        if (mounted) {
          setState(() {
            _storeData = roleData['store'];
            _userData = roleData['user'];
          });
        }

        _processStoreData(_storeData!);
        print('✅ HomeStore: Store data loaded from cache');
        print('   - Store ID: ${_storeData!['id']}');
        print('   - Store Name: ${_storeData!['name']}');
      } else {
        // ✅ FIXED: Fallback to fresh profile data
        print('⚠️ HomeStore: No cached store data, fetching fresh data...');

        if (!mounted) return; // Check before another async call

        final profileData = await AuthService.refreshUserData();

        if (!mounted) return; // Check after async call

        if (profileData != null && profileData['store'] != null) {
          if (mounted) {
            setState(() {
              _storeData = profileData['store'];
              _userData = profileData;
            });
          }
          _processStoreData(_storeData!);
          print('✅ HomeStore: Fresh store data loaded');
        } else {
          throw Exception('Unable to load store data from profile');
        }
      }
    } catch (e) {
      print('❌ HomeStore: Error loading store data: $e');
      // ✅ Only throw if still mounted
      if (mounted) {
        throw Exception('Failed to load store data: $e');
      }
    }
  }

// ✅ Add mounted checks ke semua method yang menggunakan setState

  Future<void> _forceRefreshOrders() async {
    try {
      if (!mounted) return;

      print('🔄 HomeStore: Force refreshing orders with cache buster...');

      setState(() {
        // _processedOrderIds
        // .clear(); // ✅ HAPUS ini jika ingin keep local processed state
        _orders.clear();
        _existingOrderIds.clear();
      });

      // ✅ TAMBAH: Small delay untuk ensure database consistency
      await Future.delayed(const Duration(milliseconds: 500));

      await _loadOrders(forceRefresh: true);

      print('✅ HomeStore: Force refresh completed');
    } catch (e) {
      print('❌ HomeStore: Error force refreshing orders: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat pesanan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _processStoreData(Map<String, dynamic> storeData) {
    // Ensure all required store fields with defaults
    storeData['rating'] = storeData['rating'] ?? 0.0;
    storeData['review_count'] = storeData['review_count'] ?? 0;
    storeData['total_products'] = storeData['total_products'] ?? 0;
    storeData['status'] = storeData['status'] ?? 'active';

    print('📊 HomeStore: Store data processed');
    print('   - Rating: ${storeData['rating']}');
    print('   - Review Count: ${storeData['review_count']}');
    print('   - Status: ${storeData['status']}');
  }

  /// Contact customer method
  void _contactCustomer(
      String phoneNumber, String customerName, String orderId) {
    try {
      // Clean phone number (remove any non-digits except +)
      String cleanedPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

      // Add country code if not present
      if (!cleanedPhone.startsWith('+') && !cleanedPhone.startsWith('62')) {
        if (cleanedPhone.startsWith('0')) {
          cleanedPhone = '62${cleanedPhone.substring(1)}';
        } else {
          cleanedPhone = '62$cleanedPhone';
        }
      }

      // Prepare WhatsApp message
      final message = Uri.encodeComponent('Halo $customerName! 👋\n\n'
          'Pesanan Anda dengan Order ID #$orderId telah kami terima dan sedang diproses. '
          'Kami akan segera menyiapkan pesanan Anda.\n\n'
          'Terima kasih telah mempercayai toko kami! 🙏');

      final whatsappUrl = 'https://wa.me/$cleanedPhone?text=$message';

      print('🚀 HomeStore: Opening WhatsApp URL: $whatsappUrl');

      // Try to open WhatsApp
      _launchWhatsApp(whatsappUrl, phoneNumber);
    } catch (e) {
      print('❌ HomeStore: Error contacting customer: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuka WhatsApp: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  /// Launch WhatsApp method
  void _launchWhatsApp(String whatsappUrl, String fallbackPhone) async {
    try {
      final Uri url = Uri.parse(whatsappUrl);

      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );
      } else {
        // Fallback: show phone number
        _showPhoneNumberDialog(fallbackPhone);
      }
    } catch (e) {
      print('❌ HomeStore: Error launching WhatsApp: $e');
      _showPhoneNumberDialog(fallbackPhone);
    }
  }

  /// Show phone number dialog sebagai fallback
  void _showPhoneNumberDialog(String phoneNumber) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Nomor Customer',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: GlobalStyle.fontFamily,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Silakan hubungi customer melalui:',
              style: TextStyle(fontFamily: GlobalStyle.fontFamily),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.phone, color: GlobalStyle.primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      phoneNumber,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: GlobalStyle.fontFamily,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      // Copy to clipboard
                      Clipboard.setData(ClipboardData(text: phoneNumber));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Nomor disalin ke clipboard'),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    },
                    icon: Icon(Icons.copy, color: GlobalStyle.primaryColor),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Tutup',
              style: TextStyle(fontFamily: GlobalStyle.fontFamily),
            ),
          ),
        ],
      ),
    );
  }

  /// method _showContactCustomerPopup
  Future<void> _showContactCustomerPopup(
      String orderId, Map<String, dynamic> orderData) async {
    try {
      // Get fresh order details for contact info
      final orderDetail = await OrderService.getOrderById(orderId);

      final customerName = orderDetail['customer']?['name'] ?? 'Customer';
      final customerPhone = orderDetail['customer']?['phone'] ?? '';
      final totalAmount = _parseDouble(orderDetail['total_amount']) ?? 0.0;
      final itemCount = orderDetail['items']?.length ?? 0;

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Colors.green.shade50],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Success icon with animation
                TweenAnimationBuilder(
                  duration: const Duration(milliseconds: 600),
                  tween: Tween<double>(begin: 0, end: 1),
                  builder: (context, double value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Icon(Icons.check, color: Colors.white, size: 32),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  'Pesanan Diterima!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
                const SizedBox(height: 8),

                Text(
                  'Pesanan telah berhasil diterima dan siap diproses',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Order summary card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person,
                              color: GlobalStyle.primaryColor, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              customerName,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                fontFamily: GlobalStyle.fontFamily,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.receipt,
                              color: Colors.grey.shade600, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            '$itemCount item • ${GlobalStyle.formatRupiah(totalAmount)}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                              fontFamily: GlobalStyle.fontFamily,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Action buttons
                Row(
                  children: [
                    // Contact customer button
                    if (customerPhone.isNotEmpty) ...[
                      Expanded(
                        child: _buildActionButton(
                          onTap: () {
                            Navigator.of(context).pop();
                            _contactCustomer(
                                customerPhone, customerName, orderId);
                          },
                          icon: Icons.phone,
                          label: 'Hubungi Customer',
                          gradient: [Colors.green, Colors.green.shade600],
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],

                    // View detail button - PERBAIKAN UNTUK NAVIGASI YANG BENAR
                    Expanded(
                      child: _buildActionButton(
                        onTap: () {
                          Navigator.of(context).pop();
                          // Navigasi ke halaman detail order store
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => HistoryStoreDetailPage(
                                orderId: orderId,
                              ),
                            ),
                          );
                        },
                        icon: Icons.visibility,
                        label: 'Lihat Detail',
                        gradient: [
                          GlobalStyle.primaryColor,
                          GlobalStyle.primaryColor.withOpacity(0.8)
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Close button
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Tutup',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                      fontFamily: GlobalStyle.fontFamily,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      print('❌ HomeStore: Error showing contact popup: $e');

      // Fallback success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('Pesanan berhasil diterima'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  // Method untuk refresh dengan filtering yang lebih pintar
  Future<void> _refreshOrdersWithFiltering() async {
    try {
      print('🔄 HomeStore: Refreshing with smart filtering...');
      if (!mounted) return;
      final hasStoreAccess = await AuthService.hasRole('store');
      if (!hasStoreAccess) {
        throw Exception('Access denied: Store authentication required');
      }

      final response = await OrderService.getOrdersByStore(
        page: 1,
        limit: 10,
        sortBy: 'created_at',
        sortOrder: 'desc',
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      final allOrders =
          List<Map<String, dynamic>>.from(response['orders'] ?? []);

      // ✅ Apply filtering yang benar sesuai backend logic
      final validOrders = allOrders.where((order) {
        final orderId = order['id']?.toString() ?? '';
        final orderStatus = order['order_status']?.toString() ?? '';

        print('🔍 Smart filtering Order $orderId: order_status=$orderStatus');

        // ✅ HANYA tampilkan jika order_status = 'pending'
        if (orderStatus != 'pending') {
          print(
              '❌ Order $orderId excluded: order_status = $orderStatus (not pending)');
          return false;
        }

        // ✅ Exclude jika sudah diproses globally
        if (_globalProcessedOrderIds.contains(orderId)) {
          print('❌ Order $orderId excluded: globally processed');
          return false;
        }

        // ✅ Exclude jika sudah diproses locally
        if (_processedOrderIds.contains(orderId)) {
          print('❌ Order $orderId excluded: locally processed');
          return false;
        }

        print('✅ Order $orderId included: valid pending order');
        return true;
      }).toList();

      print(
          '📋 HomeStore: Smart filtered ${validOrders.length} valid orders from ${allOrders.length} total');

      if (mounted) {
        setState(() {
          // Dispose old controllers safely
          for (var controller in _cardControllers) {
            if (controller.isCompleted || controller.isDismissed) {
              controller.dispose();
            }
          }

          _orders = validOrders;
          _existingOrderIds =
              validOrders.map((order) => order['id']?.toString() ?? '').toSet();

          // Reinitialize animations
          _initialAnimations();
          _lastRefreshTime = DateTime.now();
        });

        // Start animations
        _startAnimations();

        // Show appropriate feedback
        if (validOrders.isEmpty && allOrders.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.info, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text('Semua pesanan telah diproses'),
                ],
              ),
              backgroundColor: Colors.blue,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ HomeStore: Error in smart refresh: $e');
      // Error handling tetap sama
    }
  }

  Future<void> _loadOrders(
      {bool isRefresh = false, bool forceRefresh = false}) async {
    try {
      print(
          '📋 HomeStore: Loading orders (refresh: $isRefresh, force: $forceRefresh)...');

      if (!mounted) {
        print('⚠️ HomeStore: Widget not mounted, skipping load orders');
        return;
      }

      final hasStoreAccess = await AuthService.hasRole('store');
      if (!mounted) return;

      if (!hasStoreAccess) {
        throw Exception('Access denied: Store authentication required');
      }

      if (isRefresh || forceRefresh) {
        if (mounted) {
          setState(() {
            _currentPage = 1;
            _hasMoreData = true;
            if (forceRefresh) {
              _processedOrderIds.clear();
            }
          });
        }
      }

      final response = await OrderService.getOrdersByStore(
        page: _currentPage,
        limit: 10,
        sortBy: 'created_at',
        sortOrder: 'desc',
        timestamp:
            DateTime.now().millisecondsSinceEpoch, // ✅ SELALU bypass cache
      );

      if (!mounted) return;

      final allOrders =
          List<Map<String, dynamic>>.from(response['orders'] ?? []);

      print('📋 HomeStore: Backend returned ${allOrders.length} orders');

      // ✅ FIXED: Apply correct business logic filter
      final validOrders = allOrders.where((order) {
        final orderId = order['id']?.toString() ?? '';

        // ✅ Apply business logic filter
        if (!_shouldShowOrder(order)) {
          print('🔍 Excluding order $orderId: does not meet business rules');
          return false;
        }

        if (_processedOrderIds.contains(orderId)) {
          print('🔍 Excluding order $orderId: already processed locally');
          return false;
        }

        if (_globalProcessedOrderIds.contains(orderId)) {
          print('🔍 Excluding order $orderId: already processed globally');
          return false;
        }

        print('✅ Including order $orderId: valid for store processing');
        return true;
      }).toList();

      final totalPages = response['totalPages'] ?? 1;

      print('📋 HomeStore: Showing ${validOrders.length} valid orders');

      // Detect new orders for celebration
      if (!isRefresh && !forceRefresh && _existingOrderIds.isNotEmpty) {
        for (var order in validOrders) {
          final orderId = order['id']?.toString();
          if (orderId != null && !_existingOrderIds.contains(orderId)) {
            print('🎉 HomeStore: New order detected: $orderId');
            _triggerNewOrderCelebration(orderId);
            _showNotification(order);
          }
        }
      }

      // Update existing order IDs
      _existingOrderIds =
          validOrders.map((order) => order['id']?.toString() ?? '').toSet();

      // ✅ Only update state if mounted
      if (mounted) {
        setState(() {
          if (isRefresh || forceRefresh) {
            _orders = validOrders;
            _initialAnimations();
          } else {
            _orders.addAll(validOrders);
            _addNewAnimations(validOrders.length);
          }

          _hasMoreData = _currentPage < totalPages;
          _currentPage++;
          _lastRefreshTime = DateTime.now();
        });

        // Start animations
        if (isRefresh || forceRefresh) {
          _startAnimations();
        } else {
          _startNewAnimations();
        }
      }

      print('✅ HomeStore: Orders loaded successfully');
    } catch (e) {
      print('❌ HomeStore: Error loading orders: $e');
      if (isRefresh || forceRefresh && mounted) {
        throw e;
      }
    }
  }

  //Real-time order monitoring dengan service yang benar
  // void _startOrderMonitoring() {
  //   print('🔄 HomeStore: Starting real-time order monitoring (10s interval)...');
  //
  //   _orderMonitorTimer = Timer.periodic(const Duration(seconds: 10), (timer) async { // ✅ UBAH: 20 → 10
  //     if (!mounted) {
  //       timer.cancel();
  //       return;
  //     }
  //
  //     setState(() {
  //       _isAutoRefreshing = true;
  //     });
  //
  //     try {
  //       print('📡 HomeStore: Checking for order updates...');
  //
  //       final response = await OrderService.getOrdersByStore(
  //         page: 1,
  //         limit: 20,
  //         sortBy: 'created_at',
  //         sortOrder: 'desc',
  //         timestamp: DateTime.now().millisecondsSinceEpoch, // ✅ SELALU bypass cache
  //       );
  //
  //       final allLatestOrders = List<Map<String, dynamic>>.from(response['orders'] ?? []);
  //
  //       // ✅ Filter berdasarkan order_status = 'pending' saja
  //       final latestValidOrders = allLatestOrders.where((order) {
  //         final orderId = order['id']?.toString() ?? '';
  //         final orderStatus = order['order_status']?.toString() ?? '';
  //
  //         print('🔍 Real-time check Order $orderId: order_status=$orderStatus'); // ✅ DEBUG
  //
  //         // ✅ Hanya tampilkan jika order_status = 'pending'
  //         bool isPending = orderStatus == 'pending';
  //
  //         // ✅ Dan belum pernah diproses
  //         bool notProcessed = !_globalProcessedOrderIds.contains(orderId) &&
  //             !_processedOrderIds.contains(orderId);
  //
  //         if (!isPending) {
  //           print('❌ Order $orderId excluded from real-time: not pending ($orderStatus)');
  //         }
  //
  //         return isPending && notProcessed;
  //       }).toList();
  //
  //       // ✅ Compare dengan current orders
  //       final currentValidOrderIds = filteredOrders
  //           .map((order) => order['id']?.toString() ?? '')
  //           .toSet();
  //
  //       final latestValidOrderIds = latestValidOrders
  //           .map((order) => order['id']?.toString() ?? '')
  //           .toSet();
  //
  //       final newOrderIds = latestValidOrderIds.difference(currentValidOrderIds);
  //       final removedOrderIds = currentValidOrderIds.difference(latestValidOrderIds);
  //
  //       bool hasChanges = newOrderIds.isNotEmpty || removedOrderIds.isNotEmpty;
  //
  //       if (hasChanges) {
  //         print('🔄 HomeStore: Real-time changes detected - New: ${newOrderIds.length}, Removed: ${removedOrderIds.length}');
  //
  //         // ✅ Mark removed orders as globally processed
  //         for (String removedId in removedOrderIds) {
  //           _globalProcessedOrderIds.add(removedId);
  //           print('📝 Order $removedId marked as globally processed (status changed from pending)');
  //         }
  //
  //         setState(() {
  //           // Dispose old controllers
  //           for (var controller in _cardControllers) {
  //             controller.dispose();
  //           }
  //
  //           _orders = latestValidOrders;
  //           _existingOrderIds = latestValidOrderIds;
  //
  //           // Reinitialize animations
  //           _initialAnimations();
  //         });
  //
  //         // Start animations
  //         _startAnimations();
  //
  //         // Show notifications for new orders only
  //         for (String orderId in newOrderIds) {
  //           final newOrder = latestValidOrders.firstWhere(
  //                 (order) => order['id']?.toString() == orderId,
  //             orElse: () => {},
  //           );
  //           if (newOrder.isNotEmpty) {
  //             _triggerNewOrderCelebration(orderId);
  //             _showNotification(newOrder);
  //           }
  //         }
  //
  //         // Show feedback for removed orders
  //         if (mounted && removedOrderIds.isNotEmpty) {
  //           ScaffoldMessenger.of(context).showSnackBar(
  //             SnackBar(
  //               content: Row(
  //                 children: [
  //                   Icon(Icons.sync, color: Colors.white, size: 16),
  //                   const SizedBox(width: 8),
  //                   Text('${removedOrderIds.length} pesanan diperbarui (status berubah)'),
  //                 ],
  //               ),
  //               backgroundColor: Colors.blue,
  //               behavior: SnackBarBehavior.floating,
  //               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  //               duration: const Duration(seconds: 2),
  //             ),
  //           );
  //         }
  //       } else {
  //         print('✅ HomeStore: No real-time changes detected');
  //       }
  //
  //       setState(() {
  //         _isAutoRefreshing = false;
  //       });
  //     } catch (e) {
  //       print('❌ HomeStore: Error during real-time monitoring: $e');
  //       setState(() {
  //         _isAutoRefreshing = false;
  //       });
  //     }
  //   });
  // }

  /// Enhanced order processing menggunakan OrderService.processOrderByStore
  Future<void> _processOrder(String orderId, String action) async {
    try {
      print('⚙️ HomeStore: Processing order $orderId with action: $action');

      final hasStoreAccess = await AuthService.hasRole('store');
      if (!hasStoreAccess) {
        throw Exception('Access denied: Store authentication required');
      }

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: GlobalStyle.primaryColor),
                const SizedBox(height: 16),
                Text(
                  action == 'approve'
                      ? 'Menyetujui pesanan...'
                      : 'Menolak pesanan...',
                  style: TextStyle(
                      fontSize: 16, fontFamily: GlobalStyle.fontFamily),
                ),
              ],
            ),
          ),
        ),
      );

      // Process order using OrderService
      final result = await OrderService.processOrderByStore(
        orderId: orderId,
        action: action,
      );

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // ✅ TAMBAH: Mark as processed SETELAH sukses
      setState(() {
        _processedOrderIds.add(orderId);
        _globalProcessedOrderIds.add(orderId);
      });

      // ✅ TAMBAH: Force refresh immediately setelah berhasil
      await _forceRefreshOrders();

      print(
          '✅ HomeStore: Order $orderId processed successfully and UI refreshed');

      // Show appropriate response
      if (action == 'approve') {
        await _showContactCustomerPopup(orderId, result);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Pesanan berhasil ditolak'),
                ],
              ),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) Navigator.of(context).pop();

      print('❌ HomeStore: Error processing order: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Gagal memproses pesanan: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Force refresh untuk get current state dari server
      await _forceRefreshOrders();
    }
  }

  /// Enhanced order detail viewing menggunakan OrderService.getOrderById
  Future<void> _viewOrderDetail(String orderId) async {
    try {
      print('👁️ HomeStore: Viewing order detail: $orderId');

      // Validate access before viewing details
      final hasStoreAccess = await AuthService.hasRole('store');
      if (!hasStoreAccess) {
        throw Exception('Access denied: Store authentication required');
      }

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: GlobalStyle.primaryColor),
                const SizedBox(height: 16),
                Text(
                  'Memuat detail pesanan...',
                  style: TextStyle(
                    fontSize: 16,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Get order detail menggunakan OrderService.getOrderById
      final orderDetail = await OrderService.getOrderById(orderId);

      Navigator.of(context).pop(); // Close loading dialog

      if (orderDetail.isNotEmpty) {
        // ✅ PERBAIKAN: Navigate dengan proper return handling
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HistoryStoreDetailPage(
              orderId: orderId,
            ),
          ),
        );

        // ✅ BARU: Handle return from detail page
        if (result != null || mounted) {
          await _handleNavigationReturn();
        }

        print('✅ HomeStore: Navigated to order detail');
      } else {
        throw Exception('Order detail is empty');
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog

      print('❌ HomeStore: Error viewing order detail: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat detail pesanan: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  /// Enhanced refresh dengan proper error handling
  Future<void> _refreshOrders() async {
    try {
      print('🔄 HomeStore: Refreshing orders...');

      // Use force refresh to clear cache
      await _forceRefreshOrders();

      print('✅ HomeStore: Orders refreshed successfully');

      // Show subtle feedback for refresh
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.refresh, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text('Data pesanan diperbarui'),
              ],
            ),
            backgroundColor: GlobalStyle.primaryColor,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      print('❌ HomeStore: Error refreshing orders: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat pesanan: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _handleNavigationReturn() async {
    print('🔙 HomeStore: Handling navigation return');
    _needsRefresh = true;

    // Small delay to ensure smooth transition
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      _forceRefreshOrders();
    }
  }

  void _initialAnimations() {
    // Dispose old controllers
    for (var controller in _cardControllers) {
      controller.dispose();
    }

    _cardControllers = List.generate(
      _orders.length,
      (index) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 600 + (index * 100)),
      ),
    );

    _cardAnimations = _cardControllers.map((controller) {
      return Tween<Offset>(
        begin: const Offset(0, 0.5),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeOutCubic,
      ));
    }).toList();
  }

  void _addNewAnimations(int count) {
    for (int i = 0; i < count; i++) {
      AnimationController newController = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 600 + (i * 100)),
      );

      Animation<Offset> newAnimation = Tween<Offset>(
        begin: const Offset(0, 0.5),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: newController,
        curve: Curves.easeOutCubic,
      ));

      _cardControllers.add(newController);
      _cardAnimations.add(newAnimation);
    }
  }

  void _startAnimations() {
    Future.delayed(const Duration(milliseconds: 100), () {
      for (int i = 0; i < _cardControllers.length; i++) {
        Future.delayed(Duration(milliseconds: i * 100), () {
          if (mounted) _cardControllers[i].forward();
        });
      }
    });
  }

  void _startNewAnimations() {
    int startIndex = _cardControllers.length - _orders.length;
    if (startIndex < 0) startIndex = 0;

    for (int i = startIndex; i < _cardControllers.length; i++) {
      if (mounted) _cardControllers[i].forward();
    }
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        if (!_isLoadingMore && _hasMoreData) {
          _loadMoreOrders();
        }
      }
    });
  }

  Future<void> _loadMoreOrders() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      await _loadOrders();
    } catch (e) {
      print('❌ HomeStore: Error loading more orders: $e');
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  void _triggerNewOrderCelebration(String orderId) {
    setState(() {
      _newOrderId = orderId;
      _showCelebration = true;
    });

    // Play celebration sound
    _audioPlayer.play(AssetSource('audio/celebration.wav'));

    // Start celebration animation
    _celebrationController.forward().then((_) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showCelebration = false;
            _newOrderId = null;
          });
          _celebrationController.reset();
        }
      });
    });
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        _refreshOrders();
      },
    );
  }

  Future<void> _requestPermissions() async {
    await Permission.notification.request();
  }

  Future<void> _showNotification(Map<String, dynamic> orderDetails) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'store_channel_id',
      'Store Notifications',
      channelDescription: 'Notifications for new store orders',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/delpick',
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    // ✅ FIXED: Safe numeric conversion for notification
    final totalAmount = _parseDouble(orderDetails['total_amount']) ?? 0.0;
    final customerName = orderDetails['customer']?['name'] ?? 'Customer';

    await _flutterLocalNotificationsPlugin.show(
      0,
      'Pesanan Baru!',
      'Pelanggan: $customerName - ${GlobalStyle.formatRupiah(totalAmount)}',
      platformChannelSpecifics,
    );
  }

  // ✅ BARU: Helper method untuk safely parse double dari string
  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  @override
  @override
  void dispose() {
    print('🗑️ HomeStore: Disposing widget...');

    // ✅ Cancel timer first
    _orderMonitorTimer?.cancel();

    // ✅ Dispose animation controllers
    for (var controller in _cardControllers) {
      controller.dispose();
    }
    _celebrationController.dispose();
    _pulseController.dispose();
    _rotationController.dispose();

    // ✅ Dispose other resources
    _audioPlayer.dispose();
    _scrollController.dispose();

    print('✅ HomeStore: Widget disposed successfully');
    super.dispose();
  }

  // ✅ FIXED: Filter to show active orders (not cancelled/completed)
  List<Map<String, dynamic>> get activeFilteredOrders {
    return _orders
        .where((order) => [
              'pending',
              'confirmed',
              'preparing',
              'ready_for_pickup'
            ].contains(order['order_status']))
        .toList();
  }

  /// method filteredOrders di home_store.dart

// ✅ GANTI: Gunakan _shouldShowOrder method
  List<Map<String, dynamic>> get filteredOrders {
    return _orders.where((order) {
      final orderId = order['id']?.toString() ?? '';

      // ✅ Apply business logic filter
      if (!_shouldShowOrder(order)) {
        print('❌ Order $orderId filtered out: does not meet business rules');
        return false;
      }

      // Exclude processed orders
      if (_globalProcessedOrderIds.contains(orderId)) {
        print('❌ Order $orderId filtered out: globally processed');
        return false;
      }

      if (_processedOrderIds.contains(orderId)) {
        print('❌ Order $orderId filtered out: locally processed');
        return false;
      }

      print('✅ Order $orderId included: valid for store processing');
      return true;
    }).toList();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'preparing':
        return Colors.purple;
      case 'ready_for_pickup':
        return Colors.green;
      case 'on_delivery':
        return Colors.teal;
      case 'delivered':
        return Colors.green[700]!;
      case 'cancelled':
        return Colors.red;
      case 'rejected':
        return Colors.red[800]!;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Menunggu';
      case 'confirmed':
        return 'Dikonfirmasi';
      case 'preparing':
        return 'Disiapkan';
      case 'ready_for_pickup':
        return 'Siap Diambil';
      case 'on_delivery':
        return 'Diantar';
      case 'delivered':
        return 'Selesai';
      case 'cancelled':
        return 'Dibatalkan';
      case 'rejected':
        return 'Ditolak';
      default:
        return 'Unknown';
    }
  }

  Widget _buildOrderCard(Map<String, dynamic> order, int index) {
    String status = order['order_status'] as String? ?? 'pending';
    String orderId = order['id']?.toString() ?? '';
    bool isNewOrder = _newOrderId == orderId;

    // ✅ FIXED: Safe parsing of numeric values
    final totalAmount = _parseDouble(order['total_amount']) ?? 0.0;
    final deliveryFee = _parseDouble(order['delivery_fee']) ?? 0.0;

    Widget cardContent = Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.grey.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Background pattern
            Positioned(
              top: -20,
              right: -20,
              child: AnimatedBuilder(
                animation: _rotationController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _rotationController.value * 2 * 3.14159,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            _getStatusColor(status).withOpacity(0.1),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // Main content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Header section
                  Row(
                    children: [
                      // Order ID badge
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              GlobalStyle.primaryColor,
                              GlobalStyle.primaryColor.withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.receipt_long,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Order info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order #$orderId',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 16,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  order['created_at'] != null
                                      ? DateFormat('dd MMM yyyy HH:mm').format(
                                          DateTime.parse(order['created_at']))
                                      : 'Unknown Time',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: _getStatusColor(status).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          _getStatusLabel(status),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Order details
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey.shade200,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.attach_money,
                              color: GlobalStyle.primaryColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Total Amount',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    GlobalStyle.primaryColor,
                                    GlobalStyle.primaryColor.withOpacity(0.8),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                GlobalStyle.formatRupiah(totalAmount),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.delivery_dining,
                              color: Colors.grey.shade600,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Delivery Fee: ${GlobalStyle.formatRupiah(deliveryFee)}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Action buttons
                  Row(
                    children: [
                      // View Detail Button
                      Expanded(
                        child: Container(
                          height: 45,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                GlobalStyle.primaryColor,
                                GlobalStyle.primaryColor.withOpacity(0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    GlobalStyle.primaryColor.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _viewOrderDetail(orderId),
                              child: Center(
                                child: Text(
                                  'Lihat Detail',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Action buttons for pending orders
                      if (status == 'pending') ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            height: 45,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Colors.green, Color(0xFF4CAF50)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => _processOrder(orderId, 'approve'),
                                child: Center(
                                  child: Text(
                                    'Terima',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 45,
                          height: 45,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.red, Color(0xFFF44336)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _processOrder(orderId, 'reject'),
                              child: Center(
                                child: Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    // Wrap with celebration animation if it's a new order
    if (isNewOrder && _showCelebration) {
      return AnimatedBuilder(
        animation: _celebrationController,
        builder: (context, child) {
          return Transform.scale(
            scale: 1.0 +
                (0.1 *
                    Curves.elasticOut.transform(_celebrationController.value)),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.yellow
                        .withOpacity(0.6 * _celebrationController.value),
                    blurRadius: 20 * _celebrationController.value,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  cardContent,
                  // Celebration overlay
                  if (_celebrationController.value > 0.5)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.yellow
                                .withOpacity(_celebrationController.value),
                            width: 3,
                          ),
                        ),
                      ),
                    ),
                  // Celebration particles
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Lottie.asset(
                      'assets/animations/celebration.json',
                      width: 60,
                      height: 60,
                      repeat: false,
                      animate: _celebrationController.isAnimating,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.celebration,
                          color: Colors.yellow,
                          size: 60,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    // Regular slide animation
    return SlideTransition(
      position: index < _cardAnimations.length
          ? _cardAnimations[index]
          : const AlwaysStoppedAnimation(Offset.zero),
      child: cardContent,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/animations/empty.json',
            width: 200,
            height: 200,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.inbox_outlined,
                size: 100,
                color: Colors.grey[400],
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Tidak ada pesanan',
            style: TextStyle(
              color: GlobalStyle.fontColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pesanan baru akan muncul di sini',
            style: TextStyle(
              color: GlobalStyle.fontColor.withOpacity(0.7),
              fontSize: 14,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: GlobalStyle.primaryColor),
          const SizedBox(height: 16),
          Text(
            'Memuat data pesanan...',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            'Terjadi Kesalahan',
            style: TextStyle(
              color: GlobalStyle.fontColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage,
              style: TextStyle(
                color: GlobalStyle.fontColor.withOpacity(0.7),
                fontSize: 14,
                fontFamily: GlobalStyle.fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _validateAndInitializeData,
            style: ElevatedButton.styleFrom(
              backgroundColor: GlobalStyle.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              'Coba Lagi',
              style: TextStyle(
                color: Colors.white,
                fontFamily: GlobalStyle.fontFamily,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback onTap,
    required IconData icon,
    required String label,
    required List<Color> gradient,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: GlobalStyle.fontFamily,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orders = filteredOrders;

    return Scaffold(
      backgroundColor: const Color(0xffF8FAFE),
      body: SafeArea(
        child: Column(
          children: [
            // Enhanced Header (Statistics removed)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    GlobalStyle.lightColor.withOpacity(0.3),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dashboard Toko',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            fontFamily: GlobalStyle.fontFamily,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _storeData?['name'] ?? 'Nama Toko',
                          style: TextStyle(
                            color: GlobalStyle.primaryColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('EEEE, dd MMMM yyyy')
                              .format(DateTime.now()),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, ProfileStorePage.route);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            GlobalStyle.primaryColor,
                            GlobalStyle.primaryColor.withOpacity(0.8),
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: GlobalStyle.primaryColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: FaIcon(
                        FontAwesomeIcons.user,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Orders List Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Pesanan Masuk',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: GlobalStyle.fontFamily,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: GlobalStyle.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${orders.length} pesanan',
                      style: TextStyle(
                        color: GlobalStyle.primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Orders List
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: _isLoading
                    ? _buildLoadingState()
                    : _hasError
                        ? _buildErrorState()
                        : orders.isEmpty
                            ? _buildEmptyState()
                            : RefreshIndicator(
                                onRefresh: _refreshOrders,
                                color: GlobalStyle.primaryColor,
                                child: ListView.builder(
                                  controller: _scrollController,
                                  padding:
                                      const EdgeInsets.only(top: 8, bottom: 80),
                                  itemCount:
                                      orders.length + (_isLoadingMore ? 1 : 0),
                                  itemBuilder: (context, index) {
                                    if (index < orders.length) {
                                      return _buildOrderCard(
                                          orders[index], index);
                                    } else {
                                      return Container(
                                        padding: const EdgeInsets.all(16),
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            color: GlobalStyle.primaryColor,
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationComponent(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
      ),
    );
  }
}
