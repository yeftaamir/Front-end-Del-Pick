import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:del_pick/Views/Component/bottom_navigation.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Views/Store/historystore_detail.dart';
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
  final ScrollController _scrollController = ScrollController();

  // New order celebration
  String? _newOrderId;
  bool _showCelebration = false;

  // Real-time order monitoring
  Timer? _orderMonitorTimer;
  Set<String> _existingOrderIds = {};

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeNotifications();
    _requestPermissions();
    _validateAndInitializeData();
    _setupScrollListener();
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

  // ✅ FIXED: Enhanced validation and initialization dengan service baru
  Future<void> _validateAndInitializeData() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      print('🏪 HomeStore: Starting validation and initialization...');

      // ✅ FIXED: Validate store access menggunakan AuthService yang benar
      final hasStoreAccess = await AuthService.hasRole('store');
      if (!hasStoreAccess) {
        throw Exception('Access denied: Store authentication required');
      }

      // ✅ FIXED: Ensure valid user session
      final hasValidSession = await AuthService.ensureValidUserData();
      if (!hasValidSession) {
        throw Exception('Invalid user session. Please login again.');
      }

      print('✅ HomeStore: Store access validated');

      // Load store-specific data
      await _loadStoreData();

      // Load orders only (statistics removed)
      await _loadOrders();

      // Start real-time monitoring
      _startOrderMonitoring();

      setState(() {
        _isLoading = false;
      });

      print('✅ HomeStore: Initialization completed successfully');
    } catch (e) {
      print('❌ HomeStore: Initialization error: $e');
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  // ✅ FIXED: Enhanced store data loading dengan AuthService yang benar
  Future<void> _loadStoreData() async {
    try {
      print('🔍 HomeStore: Loading store data...');

      // ✅ FIXED: Get role-specific data menggunakan AuthService
      final roleData = await AuthService.getRoleSpecificData();

      if (roleData != null && roleData['store'] != null) {
        setState(() {
          _storeData = roleData['store'];
          _userData = roleData['user'];
        });

        _processStoreData(_storeData!);
        print('✅ HomeStore: Store data loaded from cache');
        print('   - Store ID: ${_storeData!['id']}');
        print('   - Store Name: ${_storeData!['name']}');
      } else {
        // ✅ FIXED: Fallback to fresh profile data
        print('⚠️ HomeStore: No cached store data, fetching fresh data...');
        final profileData = await AuthService.refreshUserData();

        if (profileData != null && profileData['store'] != null) {
          setState(() {
            _storeData = profileData['store'];
            _userData = profileData;
          });
          _processStoreData(_storeData!);
          print('✅ HomeStore: Fresh store data loaded');
        } else {
          throw Exception('Unable to load store data from profile');
        }
      }
    } catch (e) {
      print('❌ HomeStore: Error loading store data: $e');
      throw Exception('Failed to load store data: $e');
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
      // Import url_launcher jika belum ada
      // import 'package:url_launcher/url_launcher.dart';

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
                colors: [
                  Colors.white,
                  Colors.green.shade50,
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Success icon
                Container(
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
                  child: Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 32,
                  ),
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
                  'Pesanan telah berhasil diterima dan sedang diproses',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Order summary
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
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.green, Colors.green.shade600],
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
                              onTap: () {
                                Navigator.of(context).pop();
                                _contactCustomer(
                                    customerPhone, customerName, orderId);
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.phone,
                                      color: Colors.white, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Hubungi Customer',
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
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],

                    // View detail button
                    Expanded(
                      child: Container(
                        height: 48,
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
                              color: GlobalStyle.primaryColor.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              Navigator.of(context).pop();
                              _viewOrderDetail(orderId);
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.visibility,
                                    color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Lihat Detail',
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pesanan berhasil diterima'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  // ✅ FIXED: Enhanced order loading dengan OrderService yang benar
  Future<void> _loadOrders({bool isRefresh = false}) async {
    try {
      print('📋 HomeStore: Loading orders (refresh: $isRefresh)...');

      // ✅ FIXED: Validate store access before loading orders
      final hasStoreAccess = await AuthService.hasRole('store');
      if (!hasStoreAccess) {
        throw Exception('Access denied: Store authentication required');
      }

      if (isRefresh) {
        setState(() {
          _currentPage = 1;
          _hasMoreData = true;
        });
      }

      // ✅ FIXED: Get orders by store menggunakan OrderService.getOrdersByStore
      final response = await OrderService.getOrdersByStore(
        page: _currentPage,
        limit: 10,
        sortBy: 'created_at',
        sortOrder: 'desc',
      );

      // ✅ FIXED: Process response sesuai struktur backend baru
      final orders = List<Map<String, dynamic>>.from(response['orders'] ?? []);
      final totalPages = response['totalPages'] ?? 1;

      print('📋 HomeStore: Retrieved ${orders.length} orders');

      // ✅ FIXED: Detect new orders for celebration
      if (!isRefresh && _existingOrderIds.isNotEmpty) {
        for (var order in orders) {
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
          orders.map((order) => order['id']?.toString() ?? '').toSet();

      setState(() {
        if (isRefresh) {
          _orders = orders;
          _initialAnimations();
        } else {
          _orders.addAll(orders);
          _addNewAnimations(orders.length);
        }

        _hasMoreData = _currentPage < totalPages;
        _currentPage++;
      });

      // Start animations for new items
      if (isRefresh) {
        _startAnimations();
      } else {
        _startNewAnimations();
      }

      print('✅ HomeStore: Orders loaded successfully');
    } catch (e) {
      print('❌ HomeStore: Error loading orders: $e');
      if (isRefresh) {
        throw e;
      }
    }
  }

  // ✅ FIXED: Real-time order monitoring dengan service yang benar
  void _startOrderMonitoring() {
    print('🔄 HomeStore: Starting real-time order monitoring...');

    _orderMonitorTimer =
        Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      try {
        print('📡 HomeStore: Checking for new orders...');

        // ✅ FIXED: Validate session before monitoring
        final hasValidSession = await AuthService.ensureValidUserData();
        if (!hasValidSession) {
          print('❌ HomeStore: Invalid session, stopping monitoring');
          timer.cancel();
          return;
        }

        // ✅ FIXED: Get latest orders menggunakan OrderService
        final response = await OrderService.getOrdersByStore(
          page: 1,
          limit: 5, // Just check latest 5 orders
          sortBy: 'created_at',
          sortOrder: 'desc',
        );

        final latestOrders =
            List<Map<String, dynamic>>.from(response['orders'] ?? []);

        // Check for new orders
        bool hasNewOrders = false;
        for (var order in latestOrders) {
          final orderId = order['id']?.toString();
          if (orderId != null && !_existingOrderIds.contains(orderId)) {
            hasNewOrders = true;
            print(
                '🎉 HomeStore: New order detected during monitoring: $orderId');
            break;
          }
        }

        if (hasNewOrders) {
          print('🔄 HomeStore: Refreshing orders due to new orders...');
          await _refreshOrders();
        }
      } catch (e) {
        print('❌ HomeStore: Error during order monitoring: $e');
      }
    });
  }

  // ✅ FIXED: Enhanced order processing menggunakan OrderService.processOrderByStore
  Future<void> _processOrder(String orderId, String action) async {
    try {
      print('⚙️ HomeStore: Processing order $orderId with action: $action');

      // ✅ FIXED: Validate store access before processing
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
                    fontSize: 16,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // ✅ FIXED: Process order menggunakan OrderService.processOrderByStore
      final result = await OrderService.processOrderByStore(
        orderId: orderId,
        action: action, // 'approve' atau 'reject' sesuai parameter method
        rejectionReason: action == 'reject'
            ? 'Toko sedang tutup atau item tidak tersedia'
            : null,
      );

      Navigator.of(context).pop(); // Close loading dialog

      // ✅ NEW: Update local state immediately untuk responsiveness
      setState(() {
        final orderIndex =
            _orders.indexWhere((order) => order['id']?.toString() == orderId);
        if (orderIndex != -1) {
          _orders[orderIndex]['order_status'] =
              action == 'approve' ? 'preparing' : 'rejected';

          // ✅ NEW: Remove from filtered orders if rejected/cancelled
          if (action == 'reject') {
            _orders.removeAt(orderIndex);
            // Remove corresponding animation controller
            if (orderIndex < _cardControllers.length) {
              _cardControllers[orderIndex].dispose();
              _cardControllers.removeAt(orderIndex);
              _cardAnimations.removeAt(orderIndex);
            }
          }
        }
      });

      // ✅ NEW: Show contact popup for approved orders
      if (action == 'approve') {
        await _showContactCustomerPopup(orderId, result);
      } else {
        // Show success message for rejected orders
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pesanan berhasil ditolak'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }

      print('✅ HomeStore: Order processed successfully');

      // ✅ IMPROVED: Refresh after a short delay untuk memastikan data terbaru
      Future.delayed(const Duration(seconds: 1), () {
        _refreshOrders();
      });
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog

      print('❌ HomeStore: Error processing order: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memproses pesanan: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  // ✅ FIXED: Enhanced order detail viewing menggunakan OrderService.getOrderById
  Future<void> _viewOrderDetail(String orderId) async {
    try {
      print('👁️ HomeStore: Viewing order detail: $orderId');

      // ✅ FIXED: Validate access before viewing details
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

      // ✅ FIXED: Get order detail menggunakan OrderService.getOrderById
      final orderDetail = await OrderService.getOrderById(orderId);

      Navigator.of(context).pop(); // Close loading dialog

      if (orderDetail.isNotEmpty) {
        // Navigate to detail page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HistoryStoreDetailPage(
              orderId: orderId,
            ),
          ),
        );

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

  // ✅ FIXED: Enhanced refresh dengan proper error handling
  Future<void> _refreshOrders() async {
    try {
      print('🔄 HomeStore: Refreshing orders...');
      await _loadOrders(isRefresh: true);
      print('✅ HomeStore: Orders refreshed successfully');
    } catch (e) {
      print('❌ HomeStore: Error refreshing orders: $e');
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
  void dispose() {
    for (var controller in _cardControllers) {
      controller.dispose();
    }
    _celebrationController.dispose();
    _pulseController.dispose();
    _rotationController.dispose();
    _audioPlayer.dispose();
    _scrollController.dispose();
    _orderMonitorTimer?.cancel();
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

  List<Map<String, dynamic>> get filteredOrders {
    return _orders.where((order) {
      final status = order['order_status']?.toString() ?? 'pending';
      // ✅ FIXED: Filter lebih ketat untuk hanya menampilkan order yang perlu action
      return ['pending', 'confirmed'].contains(status);
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
