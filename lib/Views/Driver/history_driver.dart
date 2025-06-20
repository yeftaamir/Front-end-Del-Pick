import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import '../../Models/user.dart';
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
  Customer? _customer;

  // Animation controllers
  late List<AnimationController> _cardControllers;
  late List<Animation<double>> _fadeAnimations;
  late List<Animation<Offset>> _slideAnimations;
  late AnimationController _headerController;
  late Animation<double> _headerAnimation;

  // Tab categories
  final List<String> _tabs = ['Semua', 'Diproses', 'Selesai', 'Dibatalkan'];

  // Orders list
  List<Order> orders = [];
  bool isLoading = true;
  String errorMessage = '';

  // Driver requests data
  List<Map<String, dynamic>> driverRequests = [];

  // Colors - standardized with global_style
  final Color _primaryGradientStart = GlobalStyle.primaryColor;
  final Color _primaryGradientEnd = GlobalStyle.primaryColor.withOpacity(0.8);
  final Color _cardBackground = Colors.white;
  final Color _scaffoldBg = const Color(0xFFF7F8FC);

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: _tabs.length, vsync: this);

    // Header animation
    _headerController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _headerAnimation = CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOutCubic,
    );
    _headerController.forward();

    // Initialize with empty animations
    _cardControllers = [];
    _fadeAnimations = [];
    _slideAnimations = [];

    // Load user profile data
    _loadUserProfile();

    // Fetch driver requests from API
    _fetchDriverRequests();
  }

  Future<void> _loadUserProfile() async {
    try {
      final userData = await AuthService.getUserData();

      if (userData != null) {
        setState(() {
          _customer = Customer.fromJson(userData);
        });
        print('User profile loaded successfully');
      } else {
        print('User profile data is null');

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

      final Map<String, dynamic> response = await DriverService.getDriverRequests();
      print('Driver requests response received');

      if (response.containsKey('requests') && response['requests'] is List) {
        driverRequests = List<Map<String, dynamic>>.from(response['requests']);
        print('Found ${driverRequests.length} driver requests');

        await _processDriverRequests();
      } else {
        print('No requests found in response');
        setState(() {
          orders = [];
          isLoading = false;
          _setupAnimations(0);
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
          final Map<String, dynamic> requestDetail = await DriverService.getDriverRequestDetail(requestId);

          if (requestDetail.containsKey('order')) {
            Order order = _parseOrderFromJson(requestDetail['order']);
            fetchedOrders.add(order);
            print('Added order ${order.id} to history');
          } else {
            print('No order data found in request detail');
          }
        } catch (e) {
          print('Error fetching details for request $requestId: $e');
        }
      }

      _setupAnimations(fetchedOrders.length);

      setState(() {
        orders = fetchedOrders;
        isLoading = false;
      });

      // Start animations with stagger
      for (int i = 0; i < _cardControllers.length; i++) {
        Future.delayed(Duration(milliseconds: 100 * i), () {
          if (mounted && i < _cardControllers.length) {
            _cardControllers[i].forward();
          }
        });
      }

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

    // Parse items
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

    // Parse order date
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

  void _setupAnimations(int totalCards) {
    for (var controller in _cardControllers) {
      controller.dispose();
    }

    _cardControllers = List.generate(
      totalCards,
          (index) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 800),
      ),
    );

    _fadeAnimations = _cardControllers.map((controller) {
      return Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeOut,
      ));
    }).toList();

    _slideAnimations = _cardControllers.map((controller) {
      return Tween<Offset>(
        begin: const Offset(0.0, 0.3),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeOutCubic,
      ));
    }).toList();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _headerController.dispose();
    for (var controller in _cardControllers) {
      controller.dispose();
    }
    super.dispose();
  }

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
        return orders.where((order) =>
        order.status == OrderStatus.completed ||
            order.status == OrderStatus.delivered
        ).toList();
      case 3: // Cancelled
        return orders.where((order) => order.status == OrderStatus.cancelled).toList();
      default:
        return orders;
    }
  }

  Color getStatusColor(OrderStatus status) {
    if (status == OrderStatus.completed || status == OrderStatus.delivered) {
      return const Color(0xFF10B981);
    } else if (status == OrderStatus.cancelled) {
      return const Color(0xFFEF4444);
    } else if (status == OrderStatus.on_delivery ||
        status == OrderStatus.driverHeadingToCustomer ||
        status == OrderStatus.driverAssigned) {
      return const Color(0xFF3B82F6);
    } else if (status == OrderStatus.preparing ||
        status == OrderStatus.driverAtStore ||
        status == OrderStatus.driverHeadingToStore) {
      return const Color(0xFFF59E0B);
    } else {
      return GlobalStyle.primaryColor;
    }
  }

  IconData getStatusIcon(OrderStatus status) {
    if (status == OrderStatus.completed || status == OrderStatus.delivered) {
      return Icons.check_circle;
    } else if (status == OrderStatus.cancelled) {
      return Icons.cancel;
    } else if (status == OrderStatus.on_delivery ||
        status == OrderStatus.driverHeadingToCustomer) {
      return Icons.delivery_dining;
    } else if (status == OrderStatus.preparing ||
        status == OrderStatus.driverAtStore ||
        status == OrderStatus.driverHeadingToStore) {
      return Icons.restaurant;
    } else if (status == OrderStatus.driverAssigned) {
      return Icons.assignment_turned_in;
    } else {
      return Icons.schedule;
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
        return 'Diambil';
      case OrderStatus.driverAtStore:
        return 'Di Toko';
      case OrderStatus.driverHeadingToCustomer:
      case OrderStatus.on_delivery:
        return 'Diantar';
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

  Widget _buildAnimatedStatusBadge(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Order order, int index) {
    final formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(order.orderDate);
    final statusColor = getStatusColor(order.status);
    final statusIcon = getStatusIcon(order.status);
    final statusText = getStatusText(order.status);
    final itemsText = getOrderItemsText(order);
    final deliveryFee = order.serviceCharge;

    return SlideTransition(
      position: index < _slideAnimations.length ? _slideAnimations[index] : const AlwaysStoppedAnimation(Offset.zero),
      child: FadeTransition(
        opacity: index < _fadeAnimations.length ? _fadeAnimations[index] : const AlwaysStoppedAnimation(1.0),
        child: Container(
          margin: const EdgeInsets.only(bottom: 20),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                _navigateToOrderDetail(order, formattedDate, deliveryFee);
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                decoration: BoxDecoration(
                  color: _cardBackground,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: _primaryGradientStart.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Header section with gradient
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            statusColor.withOpacity(0.1),
                            statusColor.withOpacity(0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: Row(
                        children: [
                          // Delivery icon with hero animation potential
                          Hero(
                            tag: 'delivery-order-${order.id}',
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    _primaryGradientStart.withOpacity(0.1),
                                    _primaryGradientEnd.withOpacity(0.1),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: _primaryGradientStart.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.local_shipping_outlined,
                                color: _primaryGradientStart,
                                size: 40,
                              ),
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
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1F2937),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.receipt_outlined, size: 14,
                                        color: Colors.grey[600]),
                                    const SizedBox(width: 4),
                                    Text(
                                      order.code != null && order.code!.isNotEmpty
                                          ? order.code!
                                          : '#${order.id}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.calendar_today_outlined, size: 14,
                                        color: Colors.grey[600]),
                                    const SizedBox(width: 4),
                                    Text(
                                      formattedDate,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Content section
                    Container(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Status badge
                          _buildAnimatedStatusBadge(statusText, statusColor, statusIcon),
                          const SizedBox(height: 16),
                          // Items preview
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.shopping_bag_outlined,
                                    color: _primaryGradientStart, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    itemsText,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[800],
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Delivery address preview
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.location_on_outlined,
                                    color: Colors.blue[700], size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    order.deliveryAddress,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.blue[900],
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Bottom section with earnings and action
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Pendapatan Pengiriman',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    GlobalStyle.formatRupiah(deliveryFee.toDouble()),
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      foreground: Paint()
                                        ..shader = LinearGradient(
                                          colors: [_primaryGradientStart, _primaryGradientEnd],
                                        ).createShader(const Rect.fromLTWH(0, 0, 200, 70)),
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [_primaryGradientStart, _primaryGradientEnd],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _primaryGradientStart.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      _navigateToOrderDetail(order, formattedDate, deliveryFee);
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 12),
                                      child: Row(
                                        children: const [
                                          Text(
                                            'Lihat Detail',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                          SizedBox(width: 4),
                                          Icon(Icons.arrow_forward_ios,
                                              color: Colors.white, size: 14),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
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
      _fetchDriverRequests();
    });
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: FadeTransition(
        opacity: _headerAnimation,
        child: Container(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _primaryGradientStart.withOpacity(0.1),
                      _primaryGradientEnd.withOpacity(0.1),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.local_shipping_outlined,
                  size: 60,
                  color: _primaryGradientStart,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Belum ada riwayat pengiriman untuk ditampilkan',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_primaryGradientStart, _primaryGradientEnd],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryGradientStart.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.pushReplacementNamed(context, HomeDriverPage.route);
                    },
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.home_outlined, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Kembali ke Beranda',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
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
      ),
    );
  }

  Widget _buildShimmerCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 180,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 120,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 100,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Container(
                  width: 120,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (context, index) => _buildShimmerCard(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.red[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 50,
                color: Colors.red[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Oops! Ada Kesalahan',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.red[600],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              errorMessage.isNotEmpty ? errorMessage : 'Terjadi kesalahan saat memuat data',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_primaryGradientStart, _primaryGradientEnd],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: _primaryGradientStart.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _fetchDriverRequests,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.refresh, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Coba Lagi',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
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
        backgroundColor: _scaffoldBg,
        body: CustomScrollView(
          slivers: [
            // Custom app bar with gradient
            SliverAppBar(
              expandedHeight: 120,
              floating: false,
              pinned: true,
              elevation: 0,
              backgroundColor: Colors.transparent,
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_primaryGradientStart, _primaryGradientEnd],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
                  title: FadeTransition(
                    opacity: _headerAnimation,
                    child: const Text(
                      'Riwayat Pengiriman',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              leading: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                    onPressed: () {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        HomeDriverPage.route,
                            (route) => false,
                      );
                    },
                  ),
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      onPressed: _fetchDriverRequests,
                    ),
                  ),
                ),
              ],
            ),
            // Tab bar
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: _primaryGradientStart,
                  unselectedLabelColor: Colors.grey[600],
                  labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                  indicatorColor: _primaryGradientStart,
                  indicatorWeight: 3,
                  tabs: _tabs.map((String tab) => Tab(text: tab)).toList(),
                ),
              ),
            ),
            // Content
            SliverFillRemaining(
              child: isLoading
                  ? _buildLoadingState()
                  : errorMessage.isNotEmpty
                  ? _buildErrorState()
                  : RefreshIndicator(
                onRefresh: _fetchDriverRequests,
                color: _primaryGradientStart,
                child: TabBarView(
                  controller: _tabController,
                  children: List.generate(_tabs.length, (tabIndex) {
                    final filteredOrders = getFilteredOrders(tabIndex);

                    if (filteredOrders.isEmpty) {
                      return _buildEmptyState(
                          'Tidak ada pengiriman ${_tabs[tabIndex].toLowerCase()}'
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredOrders.length,
                      itemBuilder: (context, index) {
                        return _buildOrderCard(filteredOrders[index], index);
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

// Custom delegate for tab bar
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height + 16;
  @override
  double get maxExtent => _tabBar.preferredSize.height + 16;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xFFF7F8FC),
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}