import 'package:flutter/material.dart';
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

// Import services
import 'package:del_pick/Services/order_service.dart';
import 'package:del_pick/Services/auth_service.dart';

import '../../Services/service_manager.dart';

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

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Service data
  List<Map<String, dynamic>> _orders = [];
  Map<String, dynamic>? _storeData;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  int _currentPage = 1;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    // Initialize notifications
    _initializeNotifications();

    // Request notification permissions
    _requestPermissions();

    // Load initial data
    _initializeData();

    // Setup scroll listener for pagination
    _setupScrollListener();
  }

  Future<void> _initializeData() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      // Get store-specific data
      await _loadStoreData();

      // Load orders
      await _loadOrders();

    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStoreData() async {
    try {
      // Get role-specific data from ServiceManager
      final roleData = await AuthService.getRoleSpecificData();

      if (roleData != null && roleData['store'] != null) {
        setState(() {
          _storeData = roleData['store'];
        });

        // Process store data (equivalent to _processStoreData)
        _processStoreData(_storeData!);
      } else {
        // Fallback: get fresh profile data
        final profileData = await AuthService.getProfile();
        if (profileData['store'] != null) {
          setState(() {
            _storeData = profileData['store'];
          });
          _processStoreData(_storeData!);
        }
      }
    } catch (e) {
      print('Error loading store data: $e');
      throw Exception('Failed to load store data: $e');
    }
  }

  void _processStoreData(Map<String, dynamic> storeData) {
    // Ensure all required store fields with defaults (equivalent to backend _processStoreData)
    storeData['rating'] = storeData['rating'] ?? 0.0;
    storeData['review_count'] = storeData['review_count'] ?? 0;
    storeData['total_products'] = storeData['total_products'] ?? 0;
    storeData['status'] = storeData['status'] ?? 'active';

    // Process store image if needed
    if (storeData['image_url'] != null && storeData['image_url'].toString().isNotEmpty) {
      // Image processing handled by service
    }
  }

  Future<void> _loadOrders({bool isRefresh = false}) async {
    try {
      if (isRefresh) {
        setState(() {
          _currentPage = 1;
          _hasMoreData = true;
        });
      }

      // Get orders by store using OrderService
      final response = await OrderService.getOrdersByStore(
        page: _currentPage,
        limit: 10,
        sortBy: 'created_at',
        sortOrder: 'desc',
      );

      final orders = List<Map<String, dynamic>>.from(response['orders'] ?? []);
      final totalPages = response['totalPages'] ?? 1;

      setState(() {
        if (isRefresh) {
          _orders = orders;
          _initializeAnimations();
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

    } catch (e) {
      print('Error loading orders: $e');
      if (isRefresh) {
        throw e;
      }
    }
  }

  void _initializeAnimations() {
    // Dispose old controllers
    for (var controller in _cardControllers) {
      controller.dispose();
    }

    _cardControllers = List.generate(
      _orders.length,
          (index) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 600 + (index * 200)),
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
        duration: Duration(milliseconds: 600 + (i * 200)),
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
      for (var controller in _cardControllers) {
        controller.forward();
      }
    });
  }

  void _startNewAnimations() {
    int startIndex = _cardControllers.length - _orders.length;
    if (startIndex < 0) startIndex = 0;

    for (int i = startIndex; i < _cardControllers.length; i++) {
      _cardControllers[i].forward();
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
      print('Error loading more orders: $e');
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _refreshOrders() async {
    try {
      await _loadOrders(isRefresh: true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat pesanan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _processOrder(String orderId, String action) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Process order using OrderService
      await OrderService.processOrderByStore(
        orderId: orderId,
        action: action, // 'approve' or 'reject'
      );

      Navigator.of(context).pop(); // Close loading dialog

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              action == 'approve'
                  ? 'Pesanan berhasil disetujui'
                  : 'Pesanan berhasil ditolak'
          ),
          backgroundColor: Colors.green,
        ),
      );

      // Refresh orders
      await _refreshOrders();

    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memproses pesanan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _viewOrderDetail(String orderId) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Get order detail using OrderService
      final orderDetail = await OrderService.getOrderById(orderId);

      Navigator.of(context).pop(); // Close loading dialog

      // Navigate to detail page
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => HistoryStoreDetailPage(
            orderId: orderId,
          ),
        ),
      );

    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat detail pesanan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        // Handle notification tap
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

    await _flutterLocalNotificationsPlugin.show(
      0,
      'Pesanan Baru!',
      'Pelanggan: ${orderDetails['customer']?['name']} - ${GlobalStyle.formatRupiah(orderDetails['total_amount']?.toDouble() ?? 0)}',
      platformChannelSpecifics,
    );
  }

  Future<void> _playSound(String assetPath) async {
    await _audioPlayer.play(AssetSource(assetPath));
  }

  @override
  void dispose() {
    for (var controller in _cardControllers) {
      controller.dispose();
    }
    _audioPlayer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get filteredOrders {
    return _orders.where((order) =>
        ['pending', 'confirmed', 'preparing', 'ready_for_pickup'].contains(order['order_status'])
    ).toList();
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

    return SlideTransition(
      position: index < _cardAnimations.length ? _cardAnimations[index] :
      const AlwaysStoppedAnimation(Offset.zero),
      child: Container(
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
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.person, color: GlobalStyle.primaryColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                order['customer']?['name'] ?? 'Unknown Customer',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
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
                            Icon(Icons.access_time, color: GlobalStyle.fontColor, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              order['created_at'] != null
                                  ? DateFormat('dd MMM yyyy HH:mm').format(DateTime.parse(order['created_at']))
                                  : 'Unknown Time',
                              style: TextStyle(
                                color: GlobalStyle.fontColor,
                                fontFamily: GlobalStyle.fontFamily,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.payments, color: GlobalStyle.primaryColor, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              GlobalStyle.formatRupiah(order['total_amount']?.toDouble() ?? 0),
                              style: TextStyle(
                                color: GlobalStyle.primaryColor,
                                fontWeight: FontWeight.bold,
                                fontFamily: GlobalStyle.fontFamily,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status),
                      borderRadius: BorderRadius.circular(20),
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
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: GlobalStyle.lightColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.shopping_basket, color: GlobalStyle.primaryColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Jumlah Item: ${order['items']?.length ?? 0}',
                            style: TextStyle(
                              color: GlobalStyle.fontColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'No. HP: ${order['customer']?['phone'] ?? 'Unknown'}',
                            style: TextStyle(
                              color: GlobalStyle.fontColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  // View Detail Button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _viewOrderDetail(orderId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GlobalStyle.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        minimumSize: const Size(0, 40),
                      ),
                      child: Text(
                        'Lihat Detail',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontFamily: GlobalStyle.fontFamily,
                        ),
                      ),
                    ),
                  ),

                  // Action buttons for pending orders
                  if (status == 'pending') ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _processOrder(orderId, 'approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          minimumSize: const Size(0, 40),
                        ),
                        child: Text(
                          'Terima',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _processOrder(orderId, 'reject'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          minimumSize: const Size(0, 40),
                        ),
                        child: Text(
                          'Tolak',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontFamily: GlobalStyle.fontFamily,
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
      ),
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
          ),
          const SizedBox(height: 16),
          Text(
            'Tidak ada pesanan',
            style: TextStyle(
              color: GlobalStyle.fontColor,
              fontSize: 16,
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
    return const Center(
      child: CircularProgressIndicator(),
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
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage,
            style: TextStyle(
              color: GlobalStyle.fontColor.withOpacity(0.7),
              fontSize: 14,
              fontFamily: GlobalStyle.fontFamily,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _initializeData,
            style: ElevatedButton.styleFrom(
              backgroundColor: GlobalStyle.primaryColor,
            ),
            child: Text(
              'Coba Lagi',
              style: TextStyle(
                color: Colors.white,
                fontFamily: GlobalStyle.fontFamily,
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
      backgroundColor: const Color(0xffD6E6F2),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pesanan Toko',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _storeData?['name'] ?? 'Nama Toko',
                          style: TextStyle(
                            color: GlobalStyle.primaryColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                        Text(
                          DateFormat('EEEE, dd MMMM yyyy').format(DateTime.now()),
                          style: TextStyle(
                            color: GlobalStyle.fontColor,
                            fontSize: 12,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(context, ProfileStorePage.route);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: GlobalStyle.lightColor.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: FaIcon(
                          FontAwesomeIcons.user,
                          size: 20,
                          color: GlobalStyle.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Orders List
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : _hasError
                    ? _buildErrorState()
                    : orders.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                  onRefresh: _refreshOrders,
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: orders.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index < orders.length) {
                        return _buildOrderCard(orders[index], index);
                      } else {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
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