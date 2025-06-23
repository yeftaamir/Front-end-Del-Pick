import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
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
import 'package:del_pick/Services/image_service.dart';
import 'package:del_pick/Models/order.dart';
import 'package:del_pick/Models/customer.dart';
import 'package:del_pick/Services/auth_service.dart';
import 'package:badges/badges.dart' as badges;
import 'dart:async';

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
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isLocaleInitialized = false;

  // Status toggling in progress
  bool _isTogglingStatus = false;

  // Store information
  String? _storeId;
  Map<String, dynamic>? _storeData;
  bool _isStoreActive = false;

  // Notification badge counter
  int _notificationCount = 0;

  // Track previous orders count for new order detection
  int _previousOrdersCount = 0;

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Orders list - Enhanced structure
  List<Map<String, dynamic>> _pendingOrders = []; // Orders pending approval
  List<Map<String, dynamic>> _activeOrders = [];  // Orders being processed
  List<Map<String, dynamic>> _allOrders = [];     // Combined orders for display

  Timer? _pollTimer;

  // Track active dialogs to prevent multiple notifications
  bool _isShowingNewOrderDialog = false;

  @override
  void initState() {
    super.initState();

    // Initialize locale data for date formatting
    _initializeLocaleData();

    // Initialize with empty controllers and animations
    _cardControllers = [];
    _cardAnimations = [];

    // Initialize notifications
    _initializeNotifications();

    // Request notification permissions
    _requestPermissions();

    // Fetch store information
    _fetchStoreInfo();

    // Fetch orders data
    _fetchOrders();

    // Set up periodic order checking
    _setupOrderPolling();
  }

  // Initialize locale data for date formatting
  Future<void> _initializeLocaleData() async {
    try {
      await initializeDateFormatting('id_ID', null);
      setState(() {
        _isLocaleInitialized = true;
      });
    } catch (e) {
      print('Error initializing locale data: $e');
      // We'll still set the flag to true to avoid blocking UI
      setState(() {
        _isLocaleInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    for (var controller in _cardControllers) {
      controller.dispose();
    }
    _audioPlayer.dispose();
    super.dispose();
  }

  // Initialize notifications
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
        if (details.payload != null) {
          _fetchOrders(); // Refresh orders when notification is tapped
        }
      },
    );
  }

  // Request permissions
  Future<void> _requestPermissions() async {
    await Permission.notification.request();
  }

  // Enhanced: Fetch store information
  Future<void> _fetchStoreInfo() async {
    try {
      // Get user profile data
      final profileData = await AuthService.getProfile();

      if (profileData != null && profileData['store'] != null) {
        setState(() {
          _storeData = profileData['store'];
          _storeId = _storeData!['id']?.toString();
          // Update store active status based on store status field
          _isStoreActive = _storeData!['status'] == 'active';
        });
      } else {
        // Try to get from cached user data
        final userData = await AuthService.getUserData();
        if (userData != null && userData['store'] != null) {
          setState(() {
            _storeData = userData['store'];
            _storeId = _storeData!['id']?.toString();
            _isStoreActive = _storeData!['status'] == 'active';
          });
        }
      }
    } catch (e) {
      print('Error fetching store information: $e');
      setState(() {
        _hasError = true;
        _errorMessage = 'Failed to load store information: $e';
      });
    }
  }

  // Enhanced: Toggle store status using StoreService.updateStoreStatus
  Future<void> _toggleStoreStatus() async {
    if (_storeId == null) {
      // Show error if store ID is not available
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Tidak dapat mengubah status toko: ID toko tidak ditemukan',
            style: TextStyle(fontFamily: GlobalStyle.fontFamily),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Set loading state
    setState(() {
      _isTogglingStatus = true;
    });

    try {
      // Get new status (opposite of current status)
      final newStatus = _isStoreActive ? 'inactive' : 'active';

      // Call StoreService.updateStoreStatus with correct parameters
      await StoreService.updateStoreStatus(
        storeId: _storeId!,
        status: newStatus,
      );

      // Update local state
      setState(() {
        _isStoreActive = !_isStoreActive;

        // Update status in store data
        if (_storeData != null) {
          _storeData!['status'] = newStatus;
        }
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isStoreActive
                ? 'Toko aktif: Siap menerima pesanan! 🏪'
                : 'Toko nonaktif: Tidak menerima pesanan baru 🛑',
            style: TextStyle(fontFamily: GlobalStyle.fontFamily),
          ),
          backgroundColor: _isStoreActive ? Colors.green : Colors.red,
        ),
      );

      // Play status change sound
      await _playSound(_isStoreActive ? 'audio/success.mp3' : 'audio/info.mp3');

      // If store is now active, update orders
      if (_isStoreActive) {
        _fetchOrders();
      }

    } catch (e) {
      print('Error toggling store status: $e');

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal mengubah status toko: ${e.toString()}',
            style: TextStyle(fontFamily: GlobalStyle.fontFamily),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      // Reset loading state
      setState(() {
        _isTogglingStatus = false;
      });
    }
  }

  // Enhanced: Show confirmation dialog before toggling store status
  void _showStatusConfirmationDialog() {
    final newStatus = _isStoreActive ? 'nonaktif' : 'aktif';
    final statusIcon = _isStoreActive ? '🛑' : '🏪';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Text(statusIcon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Text(
                'Konfirmasi Status',
                style: TextStyle(
                  fontFamily: GlobalStyle.fontFamily,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Anda yakin ingin mengubah status toko menjadi $newStatus?',
                style: TextStyle(
                  fontFamily: GlobalStyle.fontFamily,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (_isStoreActive ? Colors.red : Colors.green).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _isStoreActive
                      ? 'Toko akan berhenti menerima pesanan baru'
                      : 'Toko akan mulai menerima pesanan baru',
                  style: TextStyle(
                    fontSize: 12,
                    color: _isStoreActive ? Colors.red : Colors.green,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
              ),
            ],
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                'Ya, Ubah Status',
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

  // Enhanced: Fetch orders from API using OrderService.getOrdersByStore
  Future<void> _fetchOrders() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // Use OrderService.getOrdersByStore() with correct parameters
      final response = await OrderService.getOrdersByStore(
        page: 1,
        limit: 50, // Get more orders
        sortBy: 'created_at',
        sortOrder: 'desc',
      );

      List<Map<String, dynamic>> newPendingOrders = [];
      List<Map<String, dynamic>> newActiveOrders = [];

      // Process response structure based on the service implementation
      if (response is Map<String, dynamic> && response['orders'] is List) {
        final List<dynamic> ordersList = response['orders'];

        for (var orderItem in ordersList) {
          if (orderItem is Map<String, dynamic>) {
            final processedOrder = _processStoreOrder(orderItem);
            if (processedOrder != null) {
              // Separate pending and active orders
              if (processedOrder['status'] == 'pending') {
                newPendingOrders.add(processedOrder);
              } else if (!['delivered', 'completed', 'cancelled'].contains(processedOrder['status'])) {
                newActiveOrders.add(processedOrder);
              }
            }
          }
        }
      }

      // Check for new pending orders and show notifications
      int totalNewOrders = newPendingOrders.length + newActiveOrders.length;
      if (totalNewOrders > _previousOrdersCount &&
          _isStoreActive &&
          _previousOrdersCount > 0) {
        // Show notification for new orders
        int newOrdersCount = totalNewOrders - _previousOrdersCount;
        _notificationCount += newOrdersCount;

        // Show notification for the newest pending order
        if (newPendingOrders.isNotEmpty) {
          await _showNotification(newPendingOrders.first);
          await _showNewOrderDialog(orderDetails: newPendingOrders.first);
        }
      }

      setState(() {
        _pendingOrders = newPendingOrders;
        _activeOrders = newActiveOrders;
        _previousOrdersCount = totalNewOrders;
        _combineAllOrders();
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Failed to load orders: $e';
      });
      print('Error fetching orders: $e');
    }
  }

  // Process store order data
  Map<String, dynamic>? _processStoreOrder(Map<String, dynamic> orderData) {
    try {
      // Extract customer information
      final customerData = orderData['user'] ?? orderData['customer'] ?? {};
      final storeData = orderData['store'] ?? {};
      final orderItems = orderData['orderItems'] ?? orderData['items'] ?? [];

      // Get customer avatar
      String customerAvatar = '';
      if (customerData['avatar'] != null && customerData['avatar'].toString().isNotEmpty) {
        customerAvatar = ImageService.getImageUrl(customerData['avatar']);
      }

      // Process items
      List<Map<String, dynamic>> items = [];
      if (orderItems is List) {
        items = orderItems.map((item) {
          String imageUrl = '';
          if (item['imageUrl'] != null && item['imageUrl'].toString().isNotEmpty) {
            imageUrl = ImageService.getImageUrl(item['imageUrl']);
          }

          return {
            'name': item['name'] ?? 'Product',
            'quantity': item['quantity'] ?? 1,
            'price': _parseDouble(item['price'] ?? 0),
            'imageUrl': imageUrl,
          };
        }).toList();
      }

      return {
        'id': orderData['id']?.toString() ?? '',
        'customerName': customerData['name'] ?? 'Unknown Customer',
        'customerPhone': customerData['phone'] ?? customerData['phoneNumber'] ?? '',
        'customerAvatar': customerAvatar,
        'orderTime': _parseDateTime(orderData['created_at'] ?? orderData['createdAt']),
        'totalPrice': _parseDouble(orderData['subtotal'] ?? orderData['total'] ?? 0),
        'status': orderData['status'] ?? orderData['order_status'] ?? 'pending',
        'items': items,
        'deliveryFee': _parseDouble(orderData['service_charge'] ?? orderData['serviceCharge'] ?? 0),
        'amount': _parseDouble(orderData['total'] ?? 0),
        'customerAddress': orderData['delivery_address'] ?? orderData['deliveryAddress'] ?? '',
        'paymentMethod': orderData['payment_method'] ?? orderData['paymentMethod'] ?? 'cash',
        'notes': orderData['notes'] ?? '',
        'orderDetail': orderData,
        'type': 'order', // Mark as store order
      };
    } catch (e) {
      print('Error processing store order: $e');
      return null;
    }
  }

  // Helper methods for safe parsing
  DateTime _parseDateTime(dynamic dateTime) {
    if (dateTime == null) return DateTime.now();
    if (dateTime is DateTime) return dateTime;
    if (dateTime is String) {
      try {
        return DateTime.parse(dateTime);
      } catch (e) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return 0.0;
      }
    }
    return 0.0;
  }

  // Combine all orders for display
  void _combineAllOrders() {
    List<Map<String, dynamic>> combinedOrders = [];

    // Add pending orders first (highest priority)
    combinedOrders.addAll(_pendingOrders);

    // Add active orders (being processed)
    combinedOrders.addAll(_activeOrders.where((order) =>
    !['delivered', 'completed', 'cancelled'].contains(order['status'])
    ).toList());

    // Sort by priority: pending -> approved -> preparing -> ready_for_pickup, etc.
    combinedOrders.sort((a, b) {
      final statusPriority = {
        'pending': 0,
        'approved': 1,
        'preparing': 2,
        'ready_for_pickup': 3,
        'driverHeadingToStore': 4,
        'driverAtStore': 5,
        'driverHeadingToCustomer': 6,
        'on_delivery': 7,
      };

      final aStatus = a['status'];
      final bStatus = b['status'];

      return (statusPriority[aStatus] ?? 8).compareTo(statusPriority[bStatus] ?? 8);
    });

    setState(() {
      _allOrders = combinedOrders;
      // Initialize animations for each card
      _initializeAnimations();
    });
  }

  // Initialize animations
  void _initializeAnimations() {
    // Clear existing controllers first
    for (var controller in _cardControllers) {
      controller.dispose();
    }

    if (_allOrders.isEmpty) return;

    // Initialize new controllers for each card
    _cardControllers = List.generate(
      _allOrders.length,
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

    // Start animations
    for (var controller in _cardControllers) {
      controller.forward();
    }
  }

  // Enhanced: Process order by store using OrderService.processOrderByStore
  Future<void> _processOrderByStore(String orderId, String action) async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Convert action to expected format
      String processAction = action;
      if (action == 'approve') {
        processAction = 'accept'; // API expects 'accept' not 'approve'
      }

      // Use OrderService.processOrderByStore with correct parameters
      final response = await OrderService.processOrderByStore(
        orderId: orderId,
        action: processAction,
        // Add optional parameters if needed
        estimatedPreparationTime: processAction == 'accept' ? '15-20 minutes' : null,
        rejectionReason: processAction == 'reject' ? 'Store tidak dapat memproses pesanan saat ini' : null,
      );

      // Reload orders after processing
      await _fetchOrders();

      // Show success message
      if (mounted) {
        final message = processAction == 'accept'
            ? 'Pesanan berhasil disetujui!'
            : 'Pesanan berhasil ditolak!';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message,
              style: TextStyle(fontFamily: GlobalStyle.fontFamily),
            ),
            backgroundColor: processAction == 'accept' ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );

        // Play sound
        await _playSound(processAction == 'accept' ? 'audio/success.mp3' : 'audio/info.mp3');
      }

    } catch (e) {
      print('Error processing order: $e');

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal memproses pesanan: ${e.toString()}',
              style: TextStyle(fontFamily: GlobalStyle.fontFamily),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Set up periodic order polling
  void _setupOrderPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && _isStoreActive) {
        _fetchOrders();
      } else if (!mounted) {
        timer.cancel();
      }
    });
  }

  // Show notification for new order
  Future<void> _showNotification(Map<String, dynamic> orderDetails) async {
    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
        'store_channel_id',
        'Store Notifications',
        channelDescription: 'Notifications for new store orders',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        sound: RawResourceAndroidNotificationSound('notification_sound'),
      );

      const NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);

      await _flutterLocalNotificationsPlugin.show(
        orderDetails['id'].hashCode,
        'Pesanan Baru Masuk! 🏪',
        'Pelanggan: ${orderDetails['customerName']} - ${GlobalStyle.formatRupiah(orderDetails['totalPrice'])}',
        platformChannelSpecifics,
        payload: orderDetails['id'],
      );
    } catch (e) {
      print('Error showing notification: $e');
    }
  }

  // Play notification sound
  Future<void> _playSound(String assetPath) async {
    try {
      await _audioPlayer.play(AssetSource(assetPath));
    } catch (e) {
      print('Error playing sound: $e');
    }
  }

  // Enhanced: Show new order dialog
  Future<void> _showNewOrderDialog({Map<String, dynamic>? orderDetails}) async {
    if (_isShowingNewOrderDialog) return; // Prevent multiple dialogs

    _isShowingNewOrderDialog = true;
    await _playSound('audio/notification_sound.mp3');

    if (mounted) {
      final order = orderDetails ?? {
        'id': 'new-order-${DateTime.now().millisecondsSinceEpoch}',
        'customerName': 'New Customer',
        'totalPrice': 0.0,
      };

      final result = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animation
                  Lottie.asset(
                    'assets/animations/new_order.json',
                    width: 180,
                    height: 180,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Text(
                    'Pesanan Baru Masuk! 🏪',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: GlobalStyle.fontFamily,
                      color: GlobalStyle.primaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Order Details Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: GlobalStyle.lightColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildOrderDetailRow('Pelanggan:', order['customerName']),
                        const SizedBox(height: 8),
                        _buildOrderDetailRow('Alamat:', order['customerAddress'] ?? 'Tidak ada alamat'),
                        const SizedBox(height: 8),
                        _buildOrderDetailRow('Item:', '${order['items']?.length ?? 0} item'),
                        const SizedBox(height: 8),
                        _buildOrderDetailRow('Total:', GlobalStyle.formatRupiah(order['totalPrice']),
                            isHighlight: true),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              if (order['status'] == 'pending') ...[
                // For pending orders - Approve/Reject buttons
                Row(
                  children: [
                    // Reject button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop('reject');
                        },
                        icon: const Icon(Icons.close, color: Colors.red, size: 18),
                        label: Text(
                          'Tolak',
                          style: TextStyle(
                            color: Colors.red,
                            fontFamily: GlobalStyle.fontFamily,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Approve button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop('approve');
                        },
                        icon: const Icon(Icons.check, color: Colors.white, size: 18),
                        label: Text(
                          'Setujui',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: GlobalStyle.fontFamily,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GlobalStyle.primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // For other orders - Just view button
                Center(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop('view');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GlobalStyle.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      minimumSize: const Size(200, 45),
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
            ],
          );
        },
      );

      _isShowingNewOrderDialog = false;

      // Handle the response
      if (result != null && order['id'] != null) {
        if (result == 'approve' || result == 'reject') {
          await _processOrderByStore(order['id'], result);
        } else if (result == 'view') {
          _fetchOrders(); // Just refresh orders
        }
      }
    }
  }

  // Helper method to build order detail row
  Widget _buildOrderDetailRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: GlobalStyle.fontColor.withOpacity(0.7),
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: isHighlight ? GlobalStyle.primaryColor : GlobalStyle.fontColor,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
        ),
      ],
    );
  }

  // Reset notification count
  void _resetNotificationCount() {
    setState(() {
      _notificationCount = 0;
    });
  }

  // Get status color
  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'preparing':
        return Colors.blue;
      case 'ready_for_pickup':
        return Colors.purple;
      case 'driverHeadingToStore':
        return Colors.indigo;
      case 'driverAtStore':
        return Colors.teal;
      case 'driverHeadingToCustomer':
        return Colors.amber;
      case 'on_delivery':
        return Colors.cyan;
      default:
        return Colors.grey;
    }
  }

  // Get status label
  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Menunggu';
      case 'approved':
        return 'Disetujui';
      case 'preparing':
        return 'Sedang Disiapkan';
      case 'ready_for_pickup':
        return 'Siap Diambil';
      case 'driverHeadingToStore':
        return 'Driver Menuju Toko';
      case 'driverAtStore':
        return 'Driver di Toko';
      case 'driverHeadingToCustomer':
        return 'Driver Menuju Customer';
      case 'on_delivery':
        return 'Sedang Dikirim';
      default:
        return 'Status Tidak Diketahui';
    }
  }

  // Navigate to order detail
  void _navigateToOrderDetail(Map<String, dynamic> order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HistoryStoreDetailPage(
          orderId: order['id'],
        ),
      ),
    ).then((_) {
      // Refresh orders when returning from detail page
      _fetchOrders();
    });
  }

  // Enhanced: Build order card with approve/reject functionality
  Widget _buildOrderCard(Map<String, dynamic> order, int index) {
    String status = order['status'] as String;
    bool isPendingOrder = status == 'pending';
    final animationIndex = index < _cardAnimations.length ? index : 0;

    return SlideTransition(
      position: _cardAnimations[animationIndex],
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isPendingOrder
              ? Border.all(color: Colors.orange, width: 2)
              : null,
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
                            // Customer avatar
                            if (order['customerAvatar'] != null &&
                                order['customerAvatar'].toString().isNotEmpty)
                              ImageService.displayImage(
                                imageSource: order['customerAvatar'],
                                width: 36,
                                height: 36,
                                borderRadius: BorderRadius.circular(18),
                              )
                            else
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: GlobalStyle.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Icon(
                                  Icons.person,
                                  color: GlobalStyle.primaryColor,
                                  size: 20,
                                ),
                              ),
                            const SizedBox(width: 12),
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
                                fontSize: 12,
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
                              GlobalStyle.formatRupiah(order['totalPrice']),
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
                  Column(
                    children: [
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
                      if (isPendingOrder)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'BARU!',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                fontFamily: GlobalStyle.fontFamily,
                              ),
                            ),
                          ),
                        ),
                    ],
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
                          if (order['customerAddress'] != null &&
                              order['customerAddress'].toString().isNotEmpty)
                            Text(
                              'Alamat: ${order['customerAddress']}',
                              style: TextStyle(
                                color: GlobalStyle.fontColor,
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (order['customerPhone'] != null &&
                              order['customerPhone'].toString().isNotEmpty)
                            Text(
                              'Telepon: ${order['customerPhone']}',
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

              // Action buttons
              if (isPendingOrder) ...[
                // For pending orders - Approve/Reject buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await _processOrderByStore(order['id'], 'reject');
                        },
                        icon: const Icon(Icons.close, color: Colors.red, size: 18),
                        label: Text(
                          'Tolak',
                          style: TextStyle(
                            color: Colors.red,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await _processOrderByStore(order['id'], 'approve');
                        },
                        icon: const Icon(Icons.check, color: Colors.white, size: 18),
                        label: Text(
                          'Setujui',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GlobalStyle.primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // For other orders - Detail button
                ElevatedButton(
                  onPressed: () => _navigateToOrderDetail(order),
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
            ],
          ),
        ),
      ),
    );
  }

  // Build empty state
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/animations/empty.json',
            width: 250,
            height: 250,
            fit: BoxFit.contain,
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
            _isStoreActive
                ? 'Pesanan baru akan muncul di sini'
                : 'Aktifkan toko untuk menerima pesanan',
            style: TextStyle(
              color: GlobalStyle.fontColor.withOpacity(0.7),
              fontSize: 14,
              fontFamily: GlobalStyle.fontFamily,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: _isStoreActive
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border:
              Border.all(color: _isStoreActive ? Colors.green : Colors.red, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                    _isStoreActive ? Icons.check_circle : Icons.warning_amber,
                    color: _isStoreActive ? Colors.green : Colors.red,
                    size: 20),
                const SizedBox(width: 8),
                Text(
                  'Status: ${_isStoreActive ? "Aktif 🏪" : "Nonaktif 🛑"}',
                  style: TextStyle(
                    color: _isStoreActive ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Build loading state
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

  // Build error state
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/animations/error.json',
            width: 200,
            height: 200,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 16),
          Text(
            'Gagal memuat pesanan',
            style: TextStyle(
              color: Colors.red,
              fontSize: 18,
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
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              _fetchStoreInfo();
              _fetchOrders();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: GlobalStyle.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
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
    // If locale is not initialized yet, show loading
    if (!_isLocaleInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xffF8F9FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Enhanced Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      GlobalStyle.primaryColor,
                      GlobalStyle.primaryColor.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: GlobalStyle.primaryColor.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
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
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _safeFormatDate(DateTime.now()),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 12,
                                fontFamily: GlobalStyle.fontFamily,
                              ),
                            ),
                            if (_storeData != null && _storeData!['name'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.store,
                                      color: Colors.white.withOpacity(0.8),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _storeData!['name'],
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        fontFamily: GlobalStyle.fontFamily,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        // Enhanced profile button with notification badge
                        GestureDetector(
                          onTap: () {
                            _resetNotificationCount();
                            Navigator.pushNamed(context, ProfileStorePage.route).then((_) {
                              // Refresh store status when returning from profile page
                              _fetchStoreInfo();
                            });
                          },
                          child: _notificationCount > 0
                              ? badges.Badge(
                            badgeContent: Text(
                              _notificationCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            badgeStyle: badges.BadgeStyle(
                              badgeColor: Colors.red,
                              padding: const EdgeInsets.all(5),
                            ),
                            position: badges.BadgePosition.topEnd(
                                top: -5, end: -5),
                            child: _buildProfileButton(),
                          )
                              : _buildProfileButton(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Enhanced store status toggle button
                    ElevatedButton.icon(
                      onPressed: _isTogglingStatus ? null : _showStatusConfirmationDialog,
                      icon: Icon(
                        _isStoreActive ? Icons.radio_button_checked : Icons.radio_button_off,
                        color: _isStoreActive ? Colors.green : Colors.red,
                        size: 24,
                      ),
                      label: _isTogglingStatus
                          ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              color: GlobalStyle.primaryColor,
                              strokeWidth: 2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Mengubah Status...',
                            style: TextStyle(
                              color: GlobalStyle.primaryColor,
                              fontWeight: FontWeight.bold,
                              fontFamily: GlobalStyle.fontFamily,
                            ),
                          ),
                        ],
                      )
                          : Text(
                        _isStoreActive
                            ? 'Status: Aktif 🏪'
                            : 'Status: Nonaktif 🛑',
                        style: TextStyle(
                          color: _isStoreActive ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontFamily: GlobalStyle.fontFamily,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        minimumSize: const Size(double.infinity, 50),
                        disabledBackgroundColor: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Enhanced orders summary
              if (!_isLoading && !_hasError && _allOrders.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
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
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryItem('Total', _allOrders.length.toString()),
                      Container(
                        height: 40,
                        width: 1,
                        color: GlobalStyle.primaryColor.withOpacity(0.3),
                      ),
                      _buildSummaryItem(
                        'Menunggu',
                        _pendingOrders.length.toString(),
                        color: Colors.orange,
                      ),
                      Container(
                        height: 40,
                        width: 1,
                        color: GlobalStyle.primaryColor.withOpacity(0.3),
                      ),
                      _buildSummaryItem(
                        'Aktif',
                        _activeOrders
                            .where((order) => ['preparing', 'approved'].contains(order['status']))
                            .length
                            .toString(),
                        color: Colors.blue,
                      ),
                    ],
                  ),
                ),
              if (!_isLoading && !_hasError && _allOrders.isNotEmpty)
                const SizedBox(height: 20),

              // Orders list
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : _hasError
                    ? _buildErrorState()
                    : _allOrders.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                  onRefresh: _fetchOrders,
                  color: GlobalStyle.primaryColor,
                  child: ListView.builder(
                    itemCount: _allOrders.length,
                    itemBuilder: (context, index) =>
                        _buildOrderCard(_allOrders[index], index),
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

  // Safe date formatting with fallback
  String _safeFormatDate(DateTime date) {
    try {
      return DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(date);
    } catch (e) {
      print('Error formatting date: $e');
      // Fallback to simple date format without locale
      return DateFormat('dd/MM/yyyy').format(date);
    }
  }

  // Build profile button
  Widget _buildProfileButton() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: const FaIcon(
        FontAwesomeIcons.user,
        size: 20,
        color: Colors.white,
      ),
    );
  }

  // Build summary item
  Widget _buildSummaryItem(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color ?? GlobalStyle.primaryColor,
            fontFamily: GlobalStyle.fontFamily,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: GlobalStyle.fontColor.withOpacity(0.7),
            fontFamily: GlobalStyle.fontFamily,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}