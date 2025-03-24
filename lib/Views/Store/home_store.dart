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
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Dummy data with status field
  final List<Map<String, dynamic>> _orders = [
    {
      'customerName': 'John Doe',
      'orderTime': DateTime.now(),
      'totalPrice': 150000,
      'status': 'processed',
      'items': [
        {
          'name': 'Product 1',
          'quantity': 2,
          'price': 75000,
          'image': 'https://example.com/image1.jpg'
        }
      ],
      'deliveryFee': 10000,
      'amount': 160000,
      'storeAddress': 'Store Address 1',
      'customerAddress': 'Customer Address 1',
      'phoneNumber': '6281234567890'
    },
    {
      'customerName': 'Jane Smith',
      'orderTime': DateTime.now().subtract(const Duration(hours: 2)),
      'totalPrice': 75000,
      'status': 'detained',
      'items': [
        {
          'name': 'Product 2',
          'quantity': 1,
          'price': 75000,
          'image': 'https://example.com/image2.jpg'
        }
      ],
      'deliveryFee': 10000,
      'amount': 85000,
      'storeAddress': 'Store Address 2',
      'customerAddress': 'Customer Address 2',
      'phoneNumber': '6281234567891'
    },
    {
      'customerName': 'Bob Wilson',
      'orderTime': DateTime.now().subtract(const Duration(hours: 4)),
      'totalPrice': 200000,
      'status': 'picked_up',
      'items': [
        {
          'name': 'Product 3',
          'quantity': 2,
          'price': 100000,
          'image': 'https://example.com/image3.jpg'
        }
      ],
      'deliveryFee': 10000,
      'amount': 210000,
      'storeAddress': 'Store Address 3',
      'customerAddress': 'Customer Address 3',
      'phoneNumber': '6281234567892'
    }
  ];

  // Sample new order for notification demo
  final Map<String, dynamic> _newOrder = {
    'customerName': 'Alice Johnson',
    'orderTime': DateTime.now(),
    'totalPrice': 180000,
    'status': 'new',
    'items': [
      {
        'name': 'Product 4',
        'quantity': 3,
        'price': 60000,
        'image': 'https://example.com/image4.jpg'
      }
    ],
    'deliveryFee': 10000,
    'amount': 190000,
    'storeAddress': 'Store Address 1',
    'customerAddress': 'Customer Address 4',
    'phoneNumber': '6281234567893'
  };

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers for each order card
    _cardControllers = List.generate(
      _orders.length,
          (index) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 600 + (index * 200)),
      ),
    );

    // Create slide animations for each card
    _cardAnimations = _cardControllers.map((controller) {
      return Tween<Offset>(
        begin: const Offset(0, 0.5),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeOutCubic,
      ));
    }).toList();

    // Start animations sequentially
    Future.delayed(const Duration(milliseconds: 100), () {
      for (var controller in _cardControllers) {
        controller.forward();
      }
    });

    // Initialize notifications
    _initializeNotifications();

    // Request notification permissions
    _requestPermissions();

    // Simulate new order after 3 seconds (for demo purposes)
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _simulateNewOrder();
      }
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

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        // Handle notification tap
        _showNewOrderDialog();
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
      'Pelanggan: ${orderDetails['customerName']} - Rp ${NumberFormat('#,###').format(orderDetails['totalPrice'])}',
      platformChannelSpecifics,
    );
  }

  void _simulateNewOrder() {
    if (_isStoreActive) {
      // Show notification
      _showNotification(_newOrder);

      // Play sound and show dialog
      _showNewOrderDialog();
    }
  }

  Future<void> _playSound(String assetPath) async {
    await _audioPlayer.play(AssetSource(assetPath));
  }

  Future<void> _showNewOrderDialog() async {
    await _playSound('audio/kring.mp3');

    if (mounted) {
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
                  'Pelanggan: ${_newOrder['customerName']}',
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
                Text(
                  'Total: Rp ${NumberFormat('#,###').format(_newOrder['totalPrice'])}',
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
                    // Add the new order to the list with processed status
                    setState(() {
                      Map<String, dynamic> processedOrder = Map.from(_newOrder);
                      processedOrder['status'] = 'processed';
                      _orders.insert(0, processedOrder);

                      // Add a new animation controller for the new order
                      AnimationController newController = AnimationController(
                        vsync: this,
                        duration: const Duration(milliseconds: 600),
                      );

                      Animation<Offset> newAnimation = Tween<Offset>(
                        begin: const Offset(0, 0.5),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: newController,
                        curve: Curves.easeOutCubic,
                      ));

                      _cardControllers.insert(0, newController);
                      _cardAnimations.insert(0, newAnimation);

                      newController.forward();
                    });
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
                setState(() {
                  _isStoreActive = false;
                });
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

  void _toggleStoreStatus() {
    if (_isStoreActive) {
      _showDeactivateConfirmationDialog();
    } else {
      setState(() {
        _isStoreActive = true;
      });
      _showStoreActiveDialog();
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

  List<Map<String, dynamic>> get filteredOrders {
    return _orders.where((order) =>
        ['processed', 'detained', 'picked_up'].contains(order['status'])
    ).toList();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'processed':
        return Colors.blue;
      case 'detained':
        return Colors.orange;
      case 'picked_up':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'processed':
        return 'Diprosess';
      case 'detained':
        return 'Ditahan';
      case 'picked_up':
        return 'Diambil';
      default:
        return 'Unknown';
    }
  }

  Widget _buildOrderCard(Map<String, dynamic> order, int index) {
    String status = order['status'] as String;

    return SlideTransition(
      position: _cardAnimations[index],
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
                            Text(
                              order['customerName'],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                fontFamily: GlobalStyle.fontFamily,
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
                              DateFormat('dd MMM yyyy HH:mm').format(order['orderTime']),
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
                              'Rp ${NumberFormat('#,###').format(order['totalPrice'])}',
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
                            'Jumlah Item: ${order['items'].length}',
                            style: TextStyle(
                              color: GlobalStyle.fontColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'No. HP: ${order['phoneNumber']}',
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: GlobalStyle.lightColor.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.inbox_rounded,
              size: 80,
              color: GlobalStyle.primaryColor,
            ),
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
                    const SizedBox(height: 16),
                    // Status toggle button
                    ElevatedButton.icon(
                      onPressed: _toggleStoreStatus,
                      icon: Icon(
                        _isStoreActive ? Icons.toggle_on : Icons.toggle_off,
                        color: Colors.white,
                        size: 24,
                      ),
                      label: Text(
                        _isStoreActive ? 'Status Toko: Aktif' : 'Status Toko: Tidak Aktif',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isStoreActive ? Colors.green : Colors.red,
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
              // Orders List
              Expanded(
                child: orders.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                  itemCount: orders.length,
                  itemBuilder: (context, index) => _buildOrderCard(orders[index], index),
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