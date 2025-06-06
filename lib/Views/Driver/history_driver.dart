import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import '../../Models/customer.dart';
import '../../Models/driver.dart';
import '../../Models/order_enum.dart';
import '../Component/driver_bottom_navigation.dart';
import 'package:del_pick/Models/item_model.dart';
import 'package:del_pick/Models/store.dart';
import 'package:del_pick/Models/tracking.dart';
import 'package:del_pick/Models/order.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Views/Driver/history_driver_detail.dart';
import 'package:del_pick/Services/driver_service.dart';
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
  late AnimationController _headerAnimationController;
  late Animation<double> _headerAnimation;
  Customer? _customer;

  // Animation controllers for cards
  late List<AnimationController> _cardControllers = [];
  late List<Animation<Offset>> _cardAnimations = [];
  late List<Animation<double>> _cardScaleAnimations = [];

  // Tab categories
  final List<String> _tabs = ['Semua', 'Diproses', 'Selesai', 'Dibatalkan'];

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

    // Header animation controller
    _headerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _headerAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _headerAnimationController,
      curve: Curves.easeOutCubic,
    ));

    // Initialize with empty animations
    _cardControllers = [];
    _cardAnimations = [];
    _cardScaleAnimations = [];

    // Start header animation
    _headerAnimationController.forward();

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
        duration: Duration(milliseconds: 800 + (index * 50)),
      ),
    );

    // Create slide animations for each card
    _cardAnimations = _cardControllers.map((controller) {
      return Tween<Offset>(
        begin: const Offset(0.3, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeOutCubic,
      ));
    }).toList();

    // Create scale animations for each card
    _cardScaleAnimations = _cardControllers.map((controller) {
      return Tween<double>(
        begin: 0.8,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeOutBack,
      ));
    }).toList();

    // Start animations with staggered delay
    for (int i = 0; i < _cardControllers.length; i++) {
      Future.delayed(Duration(milliseconds: 150 + (i * 100)), () {
        if (mounted) {
          _cardControllers[i].forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _headerAnimationController.dispose();
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

  // Get status color based on order status
  Color getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.completed:
      case OrderStatus.delivered:
        return const Color(0xFF4CAF50);
      case OrderStatus.cancelled:
        return const Color(0xFFE57373);
      case OrderStatus.driverAssigned:
      case OrderStatus.driverHeadingToStore:
      case OrderStatus.driverAtStore:
      case OrderStatus.driverHeadingToCustomer:
      case OrderStatus.driverArrived:
      case OrderStatus.on_delivery:
        return const Color(0xFF42A5F5);
      default:
        return const Color(0xFFFF9800);
    }
  }

  // Get gradient colors for status
  List<Color> getStatusGradient(OrderStatus status) {
    switch (status) {
      case OrderStatus.completed:
      case OrderStatus.delivered:
        return [const Color(0xFF66BB6A), const Color(0xFF4CAF50)];
      case OrderStatus.cancelled:
        return [const Color(0xFFEF5350), const Color(0xFFE57373)];
      case OrderStatus.driverAssigned:
      case OrderStatus.driverHeadingToStore:
      case OrderStatus.driverAtStore:
      case OrderStatus.driverHeadingToCustomer:
      case OrderStatus.driverArrived:
      case OrderStatus.on_delivery:
        return [const Color(0xFF42A5F5), const Color(0xFF1E88E5)];
      default:
        return [const Color(0xFFFFB74D), const Color(0xFFFF9800)];
    }
  }

  String getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.completed:
      case OrderStatus.delivered:
        return 'Selesai';
      case OrderStatus.cancelled:
        return 'Dibatalkan';
      case OrderStatus.pending:
        return 'Menunggu';
      case OrderStatus.approved:
        return 'Dikonfirmasi';
      case OrderStatus.preparing:
        return 'Dipersiapkan';
      case OrderStatus.driverAssigned:
        return 'Driver Ditugaskan';
      case OrderStatus.driverHeadingToStore:
        return 'Menuju Toko';
      case OrderStatus.driverAtStore:
        return 'Di Toko';
      case OrderStatus.driverHeadingToCustomer:
      case OrderStatus.on_delivery:
        return 'Mengantar';
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

  Widget _buildModernStatusChip(String text, OrderStatus status) {
    final colors = getStatusGradient(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors[0].withOpacity(0.2), colors[1].withOpacity(0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: colors[0].withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: colors[0].withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: colors[0],
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: colors[0].withOpacity(0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colors[0],
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernOrderCard(Order order, int index) {
    final formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(order.orderDate);
    final statusText = getStatusText(order.status);
    final itemsText = getOrderItemsText(order);
    final deliveryFee = order.serviceCharge; // For driver, we show the delivery fee

    return SlideTransition(
      position: index < _cardAnimations.length ? _cardAnimations[index] : const AlwaysStoppedAnimation(Offset.zero),
      child: ScaleTransition(
        scale: index < _cardScaleAnimations.length ? _cardScaleAnimations[index] : const AlwaysStoppedAnimation(1.0),
        child: Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [Colors.white, Color(0xFFFAFBFC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () {
                _navigateToOrderDetail(order, formattedDate, deliveryFee);
              },
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with store and status
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.store.name,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF1A1D29),
                                  letterSpacing: -0.5,
                                  fontFamily: GlobalStyle.fontFamily,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                order.code != null && order.code!.isNotEmpty
                                    ? 'Order #${order.code}'
                                    : 'Order #${order.id}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: GlobalStyle.primaryColor.withOpacity(0.8),
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildModernStatusChip(statusText, order.status),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Main content
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Delivery icon with modern styling
                        Hero(
                          tag: 'order_delivery_${order.id}',
                          child: Container(
                            width: 75,
                            height: 75,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              gradient: LinearGradient(
                                colors: [
                                  GlobalStyle.primaryColor.withOpacity(0.15),
                                  GlobalStyle.primaryColor.withOpacity(0.05),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: GlobalStyle.primaryColor.withOpacity(0.2),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.local_shipping_rounded,
                              color: GlobalStyle.primaryColor,
                              size: 36,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Order details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    formattedDate,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: GlobalStyle.primaryColor.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: GlobalStyle.primaryColor.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  itemsText,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: const Color(0xFF1A1D29),
                                    fontWeight: FontWeight.w600,
                                    fontFamily: GlobalStyle.fontFamily,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Delivery address chip
                              if (order.deliveryAddress.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.location_on_rounded,
                                        size: 12,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          order.deliveryAddress,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[700],
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Bottom section with delivery fee and button
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            GlobalStyle.primaryColor.withOpacity(0.03),
                            GlobalStyle.primaryColor.withOpacity(0.01),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: GlobalStyle.primaryColor.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Biaya Pengiriman',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                GlobalStyle.formatRupiah(deliveryFee.toDouble()),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: GlobalStyle.primaryColor,
                                  letterSpacing: -0.5,
                                  fontFamily: GlobalStyle.fontFamily,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  GlobalStyle.primaryColor,
                                  GlobalStyle.primaryColor.withOpacity(0.8),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: GlobalStyle.primaryColor.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  _navigateToOrderDetail(order, formattedDate, deliveryFee);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'Lihat Detail',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToOrderDetail(Order order, String formattedDate, double deliveryFee) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            HistoryDriverDetailPage(orderDetail: {
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
        transitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        },
      ),
    ).then((_) {
      // Refresh orders when returning from detail page
      _fetchDriverRequests();
    });
  }

  Widget _buildModernEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    GlobalStyle.primaryColor.withOpacity(0.1),
                    GlobalStyle.primaryColor.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: GlobalStyle.primaryColor.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                Icons.local_shipping_rounded,
                size: 60,
                color: GlobalStyle.primaryColor.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1D29),
                letterSpacing: -0.5,
                fontFamily: GlobalStyle.fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Belum ada riwayat pengiriman',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
                fontFamily: GlobalStyle.fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  GlobalStyle.primaryColor.withOpacity(0.1),
                  GlobalStyle.primaryColor.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: GlobalStyle.primaryColor.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: CircularProgressIndicator(
              color: GlobalStyle.primaryColor,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Memuat riwayat pengiriman...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A1D29),
              letterSpacing: -0.3,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Mohon tunggu sebentar',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFFEBEE),
                    Color(0xFFFFF5F5),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 60,
                color: Color(0xFFE57373),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Oops! Ada Masalah',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1D29),
                letterSpacing: -0.5,
                fontFamily: GlobalStyle.fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              errorMessage.isNotEmpty ? errorMessage : 'Terjadi kesalahan saat memuat data',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
                fontFamily: GlobalStyle.fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
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
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: _fetchDriverRequests,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.refresh_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Coba Lagi',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            letterSpacing: 0.3,
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
      ),
    );
  }

  Widget _buildModernTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: false,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey[600],
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          letterSpacing: 0.3,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        indicator: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              GlobalStyle.primaryColor,
              GlobalStyle.primaryColor.withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: GlobalStyle.primaryColor.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: _tabs.map((String tab) => Tab(text: tab)).toList(),
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
        backgroundColor: const Color(0xFFF8FAFC),
        body: CustomScrollView(
          slivers: [
            // Modern App Bar
            SliverAppBar(
              expandedHeight: 120,
              floating: false,
              pinned: true,
              elevation: 0,
              backgroundColor: Colors.transparent,
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      GlobalStyle.primaryColor,
                      GlobalStyle.primaryColor.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(left: 72, bottom: 16),
                  title: FadeTransition(
                    opacity: _headerAnimation,
                    child: const Text(
                      'Riwayat Pengiriman',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          GlobalStyle.primaryColor,
                          GlobalStyle.primaryColor.withOpacity(0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
              ),
              leading: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      HomeDriverPage.route,
                          (route) => false,
                    );
                  },
                ),
              ),
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    onPressed: _fetchDriverRequests,
                  ),
                ),
              ],
            ),

            // Tab Bar
            SliverToBoxAdapter(
              child: _buildModernTabBar(),
            ),

            // Content
            SliverFillRemaining(
              child: isLoading
                  ? _buildModernLoadingState()
                  : errorMessage.isNotEmpty
                  ? _buildModernErrorState()
                  : RefreshIndicator(
                onRefresh: _fetchDriverRequests,
                color: GlobalStyle.primaryColor,
                backgroundColor: Colors.white,
                strokeWidth: 3,
                displacement: 40,
                child: TabBarView(
                  controller: _tabController,
                  children: List.generate(_tabs.length, (tabIndex) {
                    final filteredOrders = getFilteredOrders(tabIndex);

                    if (filteredOrders.isEmpty) {
                      return _buildModernEmptyState(
                          'Tidak ada pengiriman ${_tabs[tabIndex].toLowerCase()}'
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      itemCount: filteredOrders.length,
                      itemBuilder: (context, index) {
                        return _buildModernOrderCard(filteredOrders[index], index);
                      },
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: DriverBottomNavigation(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}