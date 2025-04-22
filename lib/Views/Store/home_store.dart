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
import 'package:del_pick/Services/store_service.dart';
import 'package:del_pick/Services/order_service.dart';
import 'package:del_pick/Models/order.dart';
import 'package:del_pick/Models/customer.dart';
import 'package:del_pick/Services/auth_service.dart';

class HomeStore extends StatefulWidget {
  static const String route = '/Store/HomePage';

  const HomeStore({Key? key}) : super(key: key);

  @override
  State<HomeStore> createState() => _HomeStoreState();
}

class _HomeStoreState extends State<HomeStore> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late List<AnimationController> _cardControllers;
  late List<Animation<Offset>> _cardAnimations;
  bool _isStoreActive = false;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  // Add loading state for store status toggle
  bool _isTogglingStatus = false;
  // Store ID
  int? _storeId;

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Real orders list to replace the dummy data
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();

    // Initialize with empty controllers and animations
    _cardControllers = [];
    _cardAnimations = [];

    // Initialize notifications
    _initializeNotifications();

    // Request notification permissions
    _requestPermissions();

    // Fetch store information and status
    _fetchStoreInfo();

    // Fetch orders data
    fetchOrders();
  }

  // New method to fetch store information including ID and status
  Future<void> _fetchStoreInfo() async {
    try {
      // Get user data to extract store information
      final userData = await AuthService.getUserData();

      if (userData != null && userData['store'] != null) {
        setState(() {
          _storeId = userData['store']['id'];
          // Set store status based on the 'status' field
          _isStoreActive = userData['store']['status'] == 'active';
        });
      }
    } catch (e) {
      print('Error fetching store information: $e');
      // Don't show error - we'll still load orders
    }
  }

  // In _HomeStoreState class, replace this:
  Future<void> fetchOrders() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // Directly use OrderService instead of the static method
      final orderData = await OrderService.getStoreOrders();
      // Process the response properly
      List<Map<String, dynamic>> processedOrders = [];

      if (orderData != null && orderData['orders'] != null) {
        // Map each order to the format your UI expects
        processedOrders = (orderData['orders'] as List).map((orderJson) {
          // Extract customer name
          String customerName = 'Customer';
          if (orderJson['user'] != null) {
            customerName = orderJson['user']['name'] ?? 'Customer';
          }

          // Process items if available
          List<Map<String, dynamic>> items = [];
          if (orderJson['items'] != null && orderJson['items'] is List) {
            items = (orderJson['items'] as List).map((item) => {
              'name': item['name'] ?? 'Product',
              'quantity': item['quantity'] ?? 1,
              'price': item['price'] ?? 0,
              'image': item['imageUrl'] ?? ''
            }).toList();
          }

          return {
            'id': orderJson['id']?.toString() ?? '',
            'customerName': customerName,
            'orderTime': orderJson['orderDate'] != null ?
            DateTime.parse(orderJson['orderDate']) : DateTime.now(),
            'totalPrice': orderJson['subtotal'] ?? 0,
            'status': orderJson['order_status'] ?? 'pending',
            'items': items,
            'deliveryFee': orderJson['serviceCharge'] ?? 0,
            'amount': orderJson['total'] ?? 0,
            'storeAddress': orderJson['store']?['address'] ?? 'Store address',
            'customerAddress': orderJson['deliveryAddress'] ?? '',
            'phoneNumber': orderJson['user']?['phone'] ?? '',
          };
        }).toList();
      }

      setState(() {
        _orders = processedOrders;
        _isLoading = false;

        // Initialize animation controllers
        _cardControllers = List.generate(
          _orders.length,
              (index) => AnimationController(
            vsync: this,
            duration: Duration(milliseconds: 600 + (index * 200)),
          ),
        );

        // Create animations
        _cardAnimations = _cardControllers.map((controller) {
          return Tween<Offset>(
            begin: const Offset(0, 0.5),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: controller,
            curve: Curves.easeOutCubic,
          ));
        }).toList();

        // Start animations
        for (var controller in _cardControllers) {
          controller.forward();
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Failed to load orders: $e';
      });
    }
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@drawable/launch_background');

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
        // Handle notification tap
        if (details.payload != null) {
          // You could parse order details from the payload and show dialog
          _showNewOrderDialog();
        }
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
      icon: '@mipmap/delpick', // Ensure this icon exists in your project
    );

    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.show(
      0,
      'Pesanan Baru!',
      'Pelanggan: ${orderDetails['customerName']} - ${GlobalStyle.formatRupiah(orderDetails['totalPrice'].toDouble())}',
      platformChannelSpecifics,
      payload: orderDetails['id'], // Pass the order ID as payload
    );
  }

  Future<void> _playSound(String assetPath) async {
    await _audioPlayer.play(AssetSource(assetPath));
  }

  // Show a dialog when a new order comes in
  Future<void> _showNewOrderDialog({Map<String, dynamic>? orderDetails}) async {
    await _playSound('audio/kring.mp3');

    if (mounted) {
      // Use provided order details or placeholder if none
      final order = orderDetails ?? {
        'id': 'new-order-${DateTime.now().millisecondsSinceEpoch}',
        'customerName': 'New Customer',
        'totalPrice': 0.0,
      };

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Colors.white,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/animations/pilih_pesanan.json',
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 16),
                Text(
                  'Pesanan Baru Masuk!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Pelanggan: ${order['customerName']}',
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
                Text(
                  'Total: ${GlobalStyle.formatRupiah(order['totalPrice'].toDouble())}',
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: GlobalStyle.fontFamily,
                    color: GlobalStyle.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            actions: [
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Refresh orders to get the latest data
                    fetchOrders();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlobalStyle.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    minimumSize: const Size(double.infinity, 45),
                  ),
                  child: Text(
                    'Lihat Pesanan',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: GlobalStyle.fontFamily,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    }
  }

  void _showStoreActiveDialog() async {
    await _playSound('audio/found.wav');

    if (mounted) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Colors.white,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/animations/diproses.json',
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 16),
                Text(
                  'Toko Anda Sekarang Aktif!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Anda akan menerima pesanan baru.',
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
              ],
            ),
            actions: [
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlobalStyle.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    minimumSize: const Size(double.infinity, 45),
                  ),
                  child: Text(
                    'Mengerti',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: GlobalStyle.fontFamily,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    }
  }

  void _showDeactivateConfirmationDialog() async {
    // Play wrong sound for deactivation confirmation
    await _playSound('audio/wrong.mp3');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Konfirmasi',
            style: TextStyle(
              fontFamily: GlobalStyle.fontFamily,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Anda yakin ingin menonaktifkan status toko? Anda tidak akan menerima pesanan baru.',
            style: TextStyle(
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Batal',
                style: TextStyle(
                  color: GlobalStyle.primaryColor,
                  fontFamily: GlobalStyle.fontFamily,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _toggleStoreStatus();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: GlobalStyle.primaryColor,
              ),
              child: Text(
                'Ya, Nonaktifkan',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: GlobalStyle.fontFamily,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Updated method to toggle store status using StoreService
  void _toggleStoreStatus() async {
    // Check if we have a valid store ID
    if (_storeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Store ID tidak ditemukan'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Set toggling status to show loading
    setState(() {
      _isTogglingStatus = true;
    });

    try {
      // Determine new status based on current status
      final newStatus = _isStoreActive ? 'inactive' : 'active';

      // Call the StoreService to update status
      final result = await StoreService.updateStoreStatus(_storeId!, newStatus);

      // Update the local state based on the response
      if (result != null && result.containsKey('status')) {
        setState(() {
          _isStoreActive = result['status'] == 'active';
        });

        // Show activation dialog if the store is now active
        if (_isStoreActive) {
          _showStoreActiveDialog();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Toko berhasil dinonaktifkan'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengubah status toko: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      // Regardless of success or failure, set toggling status to false
      setState(() {
        _isTogglingStatus = false;
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _cardControllers) {
      controller.dispose();
    }
    _audioPlayer.dispose();
    super.dispose();
  }

  // Filter orders based on status
  List<Map<String, dynamic>> get filteredOrders {
    return _orders
        .where((order) => ['processed', 'detained', 'picked_up', 'pending', 'approved', 'preparing']
        .contains(order['status']))
        .toList();
  }

  // Get status color based on order status
  Color _getStatusColor(String status) {
    switch (status) {
      case 'processed':
        return Colors.blue;
      case 'detained':
        return Colors.orange;
      case 'picked_up':
        return Colors.purple;
      case 'approved':
        return Colors.green;
      case 'preparing':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  // Get readable status label
  String _getStatusLabel(String status) {
    switch (status) {
      case 'processed':
        return 'Diproses';
      case 'detained':
        return 'Ditahan';
      case 'picked_up':
        return 'Diambil';
      case 'approved':
        return 'Disetujui';
      case 'preparing':
        return 'Sedang Disiapkan';
      case 'pending':
        return 'Menunggu';
      default:
        return 'Unknown';
    }
  }

  // Build an order card for the list
  Widget _buildOrderCard(Map<String, dynamic> order, int index) {
    String status = order['status'] as String;

    // Ensure index is within bounds of animations array
    final animationIndex = index < _cardAnimations.length ? index : 0;

    return SlideTransition(
      position: _cardAnimations[animationIndex],
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
                                order['customerName'] ?? 'Customer',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  fontFamily: GlobalStyle.fontFamily,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.access_time,
                                color: GlobalStyle.fontColor, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('dd MMM yyyy HH:mm')
                                  .format(order['orderTime']),
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
                            Icon(Icons.payments,
                                color: GlobalStyle.primaryColor, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              GlobalStyle.formatRupiah(
                                  order['totalPrice'].toDouble()),
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
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                    Icon(Icons.shopping_basket,
                        color: GlobalStyle.primaryColor),
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
                            'Alamat Pengiriman: ${order['customerAddress'] ?? 'No address'}',
                            style: TextStyle(
                              color: GlobalStyle.fontColor,
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HistoryStoreDetailPage(
                        orderDetail: order,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlobalStyle.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  minimumSize: const Size(double.infinity, 40),
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
            ],
          ),
        ),
      ),
    );
  }

  // Empty state widget
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
            'Tidak ada pesanan yang diproses',
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
          const SizedBox(height: 20),
          Text(
            _isStoreActive
                ? 'Status: Aktif - Siap Menerima Pesanan'
                : 'Status: Tidak Aktif - Aktifkan untuk menerima pesanan',
            style: TextStyle(
              color: _isStoreActive ? Colors.green : Colors.red,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  // Loading state widget
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: GlobalStyle.primaryColor),
          const SizedBox(height: 16),
          Text(
            'Memuat pesanan...',
            style: TextStyle(
              color: GlobalStyle.fontColor,
              fontSize: 16,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  // Error state widget
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 64),
          const SizedBox(height: 16),
          Text(
            'Gagal memuat pesanan',
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
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: fetchOrders,
            style: ElevatedButton.styleFrom(
              backgroundColor: GlobalStyle.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              'Coba Lagi',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
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
                child: Column(
                  children: [
                    Row(
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
                              DateFormat('EEEE, dd MMMM yyyy')
                                  .format(DateTime.now()),
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
                            Navigator.pushNamed(
                                context, ProfileStorePage.route);
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
                    const SizedBox(height: 16),
                    // Status toggle button with loading indicator
                    _isTogglingStatus
                        ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _isStoreActive ? Colors.green : Colors.red,
                          ),
                        ),
                      ),
                    )
                        : ElevatedButton.icon(
                      onPressed: () {
                        if (_isStoreActive) {
                          _showDeactivateConfirmationDialog();
                        } else {
                          _toggleStoreStatus();
                        }
                      },
                      icon: Icon(
                        _isStoreActive ? Icons.toggle_on : Icons.toggle_off,
                        color: Colors.white,
                        size: 24,
                      ),
                      label: Text(
                        _isStoreActive
                            ? 'Status Toko: Aktif'
                            : 'Status Toko: Tidak Aktif',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                        _isStoreActive ? Colors.green : Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        minimumSize: const Size(double.infinity, 45),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Orders List or appropriate state widget
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : _hasError
                    ? _buildErrorState()
                    : orders.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                  itemCount: orders.length,
                  itemBuilder: (context, index) =>
                      _buildOrderCard(orders[index], index),
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