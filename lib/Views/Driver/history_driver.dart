import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import '../../Models/customer.dart';
import '../../Models/driver.dart';
import '../../Models/order_enum.dart';
import '../Component/driver_bottom_navigation.dart';
import 'package:del_pick/Models/order_review.dart';
import 'package:del_pick/Models/store.dart';
import 'package:del_pick/Models/tracking.dart';
import 'package:del_pick/Models/order.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Views/Driver/history_driver_detail.dart';
import 'package:del_pick/Services/driver_service.dart';  // Changed from order_service
import 'package:del_pick/Services/auth_service.dart';
import 'home_driver.dart';

class HistoryDriverPage extends StatefulWidget {
  static const String route = '/Driver/HistoryDriver';

  const HistoryDriverPage({Key? key}) : super(key: key);

  @override
  State<HistoryDriverPage> createState() => _HistoryDriverPageState();
}

class _HistoryDriverPageState extends State<HistoryDriverPage> with TickerProviderStateMixin {
  int _selectedIndex = 1; // History tab selected
  late TabController _tabController;
  Customer? _customer;

  // Animation controllers for cards
  late List<AnimationController> _cardControllers = [];
  late List<Animation<Offset>> _cardAnimations = [];

  // Tab categories
  final List<String> _tabs = ['Semua', 'Diproses', 'Selesai', 'Di Batalkan'];

  // Orders list
  List<Order> orders = [];
  bool isLoading = true;
  String errorMessage = '';

  // Driver requests data
  List<Map<String, dynamic>> driverRequests = [];

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: _tabs.length, vsync: this);

    // Initialize with empty animations
    _cardControllers = [];
    _cardAnimations = [];

    // Load user profile data
    _loadUserProfile();

    // Fetch driver requests from API
    _fetchDriverRequests();
  }

  Future<void> _loadUserProfile() async {
    try {
      // Get user data from local storage (saved during login)
      final userData = await AuthService.getUserData();

      if (userData != null) {
        setState(() {
          _customer = Customer.fromJson(userData);
        });
        print('User profile loaded successfully');
      } else {
        print('User profile data is null');

        // Try to fetch profile data from server as fallback
        try {
          final profileData = await AuthService.getProfile();
          if (profileData != null) {
            setState(() {
              _customer = Customer.fromJson(profileData);
            });
            print('User profile loaded from API');
          }
        } catch (e) {
          print('Error fetching profile data: $e');
        }
      }
    } catch (e) {
      print('Error loading user profile: $e');
    }
  }

  Future<void> _fetchDriverRequests() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      print('Fetching driver requests...');

      // Fetch driver requests using the DriverService
      final Map<String, dynamic> response = await DriverService.getDriverRequests();
      print('Driver requests response received');

      if (response.containsKey('requests') && response['requests'] is List) {
        driverRequests = List<Map<String, dynamic>>.from(response['requests']);
        print('Found ${driverRequests.length} driver requests');

        // Process and convert all requests to Order objects
        await _processDriverRequests();
      } else {
        print('No requests found in response');
        setState(() {
          orders = [];
          isLoading = false;
          _initializeAnimations();
        });
      }
    } catch (e) {
      print('Error fetching driver requests: $e');
      setState(() {
        errorMessage = 'Gagal memuat data permintaan: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _processDriverRequests() async {
    final List<Order> fetchedOrders = [];

    try {
      for (var request in driverRequests) {
        final String requestId = request['id'].toString();
        print('Processing driver request: $requestId');

        try {
          // Get detailed information for each request
          final Map<String, dynamic> requestDetail = await DriverService.getDriverRequestDetail(requestId);

          if (requestDetail.containsKey('order')) {
            // Parse the order from the request detail
            Order order = _parseOrderFromJson(requestDetail['order']);
            fetchedOrders.add(order);
            print('Added order ${order.id} to history');
          } else {
            print('No order data found in request detail');
          }
        } catch (e) {
          print('Error fetching details for request $requestId: $e');
          // Continue with the next request
        }
      }

      setState(() {
        orders = fetchedOrders;
        isLoading = false;
        // Initialize animations after we have the data
        _initializeAnimations();
      });

      print('Processed ${fetchedOrders.length} orders successfully');
    } catch (e) {
      print('Error processing driver requests: $e');
      setState(() {
        errorMessage = 'Gagal memproses data permintaan: $e';
        isLoading = false;
      });
    }
  }

  Order _parseOrderFromJson(dynamic json) {
    // Parse store
    StoreModel store = StoreModel(
      id: json['store']?['id'] ?? 0,
      name: json['store']?['name'] ?? 'Unknown Store',
      address: json['store']?['address'] ?? 'Address not available',
      openHours: '${json['store']?['open_time'] ?? ''} - ${json['store']?['close_time'] ?? ''}',
      phoneNumber: json['store']?['phone'] ?? '',
      imageUrl: json['store']?['image'] ?? '',
    );

    // Parse items - check both 'items' and 'orderItems' fields
    List<Item> items = [];

    if (json['items'] is List && (json['items'] as List).isNotEmpty) {
      for (var itemData in json['items']) {
        items.add(Item(
          id: itemData['id']?.toString() ?? '',
          name: itemData['name'] ?? 'Unknown Item',
          description: itemData['description'] ?? '',
          price: (itemData['price'] ?? 0).toDouble(),
          quantity: itemData['quantity'] ?? 1,
          imageUrl: itemData['imageUrl'] ?? 'assets/images/menu_item.jpg',
          isAvailable: true,
          status: 'available',
        ));
      }
    } else if (json['orderItems'] is List && (json['orderItems'] as List).isNotEmpty) {
      // Alternative field name for items in the response
      for (var itemData in json['orderItems']) {
        items.add(Item(
          id: itemData['id']?.toString() ?? '',
          name: itemData['name'] ?? 'Unknown Item',
          description: itemData['description'] ?? '',
          price: (itemData['price'] ?? 0).toDouble(),
          quantity: itemData['quantity'] ?? 1,
          imageUrl: itemData['imageUrl'] ?? 'assets/images/menu_item.jpg',
          isAvailable: true,
          status: 'available',
        ));
      }
    }

    // Parse order status
    OrderStatus status = _parseOrderStatus(json['status']);

    // Parse order date - handle various date field names
    DateTime orderDate;
    if (json['created_at'] != null) {
      orderDate = DateTime.parse(json['created_at']);
    } else if (json['orderDate'] != null) {
      orderDate = DateTime.parse(json['orderDate']);
    } else {
      orderDate = DateTime.now();
    }

    // Parse delivery status if available
    DeliveryStatus? deliveryStatus;
    if (json['delivery_status'] != null) {
      deliveryStatus = DeliveryStatus.fromString(json['delivery_status']);
    }

    // Create Order object with parsed data
    return Order(
      id: json['id']?.toString() ?? '',
      code: json['code'] ?? '',
      items: items,
      store: store,
      deliveryAddress: json['delivery_address'] ?? json['deliveryAddress'] ?? '',
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      serviceCharge: (json['delivery_fee'] ?? json['serviceCharge'] ?? 0).toDouble(),
      total: (json['total'] ?? 0).toDouble(),
      status: status,
      deliveryStatus: deliveryStatus,
      orderDate: orderDate,
      notes: json['notes'] ?? '',
      customerId: json['user_id'] ?? json['userId'],
      driverId: json['driver_id'] ?? json['driverId'],
      storeId: json['store_id'] ?? json['storeId'],
    );
  }

  OrderStatus _parseOrderStatus(String? statusString) {
    if (statusString == null || statusString.isEmpty) {
      return OrderStatus.pending;
    }

    try {
      return OrderStatus.fromString(statusString);
    } catch (e) {
      print('Error parsing order status: $e. Using default status.');
      return OrderStatus.pending;
    }
  }

  void _initializeAnimations() {
    // Clear existing controllers
    for (var controller in _cardControllers) {
      controller.dispose();
    }

    _cardControllers = List.generate(
      orders.length,
          (index) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 600 + (index * 100)),
      ),
    );

    // Create slide animations for each card
    _cardAnimations = _cardControllers.map((controller) {
      return Tween<Offset>(
        begin: const Offset(0.5, 0),
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
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (var controller in _cardControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // Get filtered orders based on tab index
  List<Order> getFilteredOrders(int tabIndex) {
    switch (tabIndex) {
      case 0: // All orders
        return orders;
      case 1: // In progress
        return orders.where((order) =>
        order.status != OrderStatus.completed &&
            order.status != OrderStatus.cancelled
        ).toList();
      case 2: // Completed
        return orders.where((order) => order.status == OrderStatus.completed).toList();
      case 3: // Cancelled
        return orders.where((order) => order.status == OrderStatus.cancelled).toList();
      default:
        return orders;
    }
  }

  Color getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.completed:
      case OrderStatus.delivered:
        return Colors.green;
      case OrderStatus.cancelled:
        return Colors.red;
      case OrderStatus.driverAssigned:
      case OrderStatus.driverHeadingToStore:
      case OrderStatus.driverAtStore:
      case OrderStatus.driverHeadingToCustomer:
      case OrderStatus.driverArrived:
      case OrderStatus.on_delivery:
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  String getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.completed:
      case OrderStatus.delivered:
        return 'Selesai';
      case OrderStatus.cancelled:
        return 'Di Batalkan';
      case OrderStatus.pending:
        return 'Menunggu';
      case OrderStatus.approved:
        return 'Dikonfirmasi';
      case OrderStatus.preparing:
        return 'Dipersiapkan';
      case OrderStatus.driverAssigned:
        return 'Driver Ditugaskan';
      case OrderStatus.driverHeadingToStore:
        return 'Di Ambil';
      case OrderStatus.driverAtStore:
        return 'Di Toko';
      case OrderStatus.driverHeadingToCustomer:
      case OrderStatus.on_delivery:
        return 'Di Antar';
      case OrderStatus.driverArrived:
        return 'Driver Tiba';
      default:
        return 'Diproses';
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      if (index == 0) {
        Navigator.pushReplacementNamed(context, HomeDriverPage.route);
      }
    });
  }

  String getOrderItemsText(Order order) {
    if (order.items.isEmpty) {
      return "Tidak ada item";
    } else if (order.items.length == 1) {
      return order.items[0].name;
    } else {
      final firstItem = order.items[0].name;
      final otherItemsCount = order.items.length - 1;
      return '$firstItem, +$otherItemsCount item lainnya';
    }
  }

  Widget _buildOrderCard(Order order, int index) {
    final formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(order.orderDate);
    final statusColor = getStatusColor(order.status);
    final statusText = getStatusText(order.status);
    final deliveryFee = order.serviceCharge; // For driver, we show the delivery fee

    // Use the animation controller only if it exists
    final animationIndex = index < _cardAnimations.length ? index : 0;
    final hasAnimation = index < _cardAnimations.length;

    Widget card = Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () {
          _navigateToOrderDetail(order, formattedDate, deliveryFee);
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: GlobalStyle.lightColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.local_shipping_outlined,
                      color: GlobalStyle.primaryColor,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                order.store.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildStatusChip(statusText, statusColor),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          formattedDate,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          getOrderItemsText(order),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[800],
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Biaya Pengiriman',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        GlobalStyle.formatRupiah(deliveryFee.toDouble()),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: GlobalStyle.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: () {
                      _navigateToOrderDetail(order, formattedDate, deliveryFee);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GlobalStyle.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Lihat Detail',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    // Apply animation if available
    if (hasAnimation) {
      return SlideTransition(
        position: _cardAnimations[animationIndex],
        child: card,
      );
    }

    return card;
  }

  Widget _buildStatusChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  void _navigateToOrderDetail(Order order, String formattedDate, double deliveryFee) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HistoryDriverDetailPage(orderDetail: {
          'customerName': _customer?.name ?? 'Customer',
          'date': formattedDate,
          'amount': order.total,
          'items': order.items.map((item) => {
            'name': item.name,
            'quantity': item.quantity,
            'price': item.price,
            'image': item.imageUrl
          }).toList(),
          'status': order.status.toString().split('.').last,
          'deliveryFee': deliveryFee,
          'customerAddress': order.deliveryAddress,
          'storeAddress': order.store.address,
          'storePhone': order.store.phoneNumber,
          'customerPhone': _customer?.phoneNumber,
          'orderCode': order.code,
          'storeName': order.store.name,
          'orderId': order.id,
        }),
      ),
    ).then((_) {
      // Refresh orders when returning from detail page
      _fetchDriverRequests();
    });
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Lottie animation for empty state
          Lottie.asset(
            'assets/animations/empty.json',
            width: 200,
            height: 200,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 20),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Belum ada riwayat pengiriman',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
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
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Memuat data...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
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
            color: Colors.red[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Terjadi kesalahan',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            errorMessage,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _fetchDriverRequests,
            icon: const Icon(Icons.refresh),
            label: const Text('Coba Lagi'),
            style: ElevatedButton.styleFrom(
              backgroundColor: GlobalStyle.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pushNamedAndRemoveUntil(
          context,
          HomeDriverPage.route,
              (route) => false,
        );
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          title: const Text(
            'Riwayat Pengiriman',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(4.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: GlobalStyle.primaryColor, width: 1.0),
              ),
              child: Icon(Icons.arrow_back_ios_new, color: GlobalStyle.primaryColor, size: 18),
            ),
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                HomeDriverPage.route,
                    (route) => false,
              );
            },
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.refresh, color: GlobalStyle.primaryColor),
              onPressed: _fetchDriverRequests,
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: GlobalStyle.primaryColor,
            unselectedLabelColor: Colors.grey[600],
            labelStyle: const TextStyle(fontWeight: FontWeight.w600),
            indicatorColor: GlobalStyle.primaryColor,
            indicatorWeight: 3,
            tabs: _tabs.map((String tab) => Tab(text: tab)).toList(),
          ),
        ),
        body: isLoading
            ? _buildLoadingState()
            : errorMessage.isNotEmpty
            ? _buildErrorState()
            : TabBarView(
          controller: _tabController,
          children: List.generate(_tabs.length, (tabIndex) {
            final filteredOrders = getFilteredOrders(tabIndex);

            if (filteredOrders.isEmpty) {
              return _buildEmptyState('Tidak ada pengiriman ${_tabs[tabIndex].toLowerCase()}');
            }

            return RefreshIndicator(
              onRefresh: _fetchDriverRequests,
              color: GlobalStyle.primaryColor,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredOrders.length,
                itemBuilder: (context, index) {
                  return _buildOrderCard(filteredOrders[index], index);
                },
              ),
            );
          }),
        ),
        bottomNavigationBar: DriverBottomNavigation(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}