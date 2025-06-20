import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import '../../Models/user.dart';
import '../../Models/driver.dart';
import '../../Models/order.dart';
import '../../Models/order_item.dart';
import '../../Models/order_enum.dart';
import '../../Models/store.dart';
import '../Component/driver_bottom_navigation.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Views/Driver/history_driver_detail.dart';
import 'package:del_pick/Services/driver_service.dart';
import 'package:del_pick/Services/order_service.dart';
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
  User? _currentUser;

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

  // Pagination
  int currentPage = 1;
  bool hasMoreData = true;
  bool isLoadingMore = false;

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

    // Fetch driver orders from API
    _fetchDriverOrders();
  }

  Future<void> _loadUserProfile() async {
    try {
      final userData = await AuthService.getUserData();

      if (userData != null) {
        setState(() {
          _currentUser = User.fromJson(userData);
        });
        print('User profile loaded successfully');
      } else {
        print('User profile data is null');

        try {
          final profileData = await AuthService.getProfile();
          if (profileData.isNotEmpty) {
            setState(() {
              _currentUser = User.fromJson(profileData);
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

  Future<void> _fetchDriverOrders({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() {
        currentPage = 1;
        hasMoreData = true;
        isLoading = true;
        errorMessage = '';
        orders.clear();
      });
    } else if (!hasMoreData || isLoadingMore) {
      return;
    }

    setState(() {
      if (currentPage == 1) {
        isLoading = true;
        errorMessage = '';
      } else {
        isLoadingMore = true;
      }
    });

    try {
      print('Fetching driver orders - Page: $currentPage');

      final Map<String, dynamic> response = await DriverService.getDriverOrders(
        page: currentPage,
        limit: 10,
      );

      print('Driver orders response received');

      final List<Order> fetchedOrders = [];

      // Process orders from response
      if (response.containsKey('orders') && response['orders'] is List) {
        final List<dynamic> ordersData = response['orders'];

        for (var orderData in ordersData) {
          try {
            final Order order = Order.fromJson(orderData);
            fetchedOrders.add(order);
          } catch (e) {
            print('Error parsing order: $e');
          }
        }
      } else if (response.containsKey('data') && response['data'] is Map) {
        // Handle nested data structure
        final Map<String, dynamic> dataMap = response['data'];
        if (dataMap.containsKey('orders') && dataMap['orders'] is List) {
          final List<dynamic> ordersData = dataMap['orders'];

          for (var orderData in ordersData) {
            try {
              final Order order = Order.fromJson(orderData);
              fetchedOrders.add(order);
            } catch (e) {
              print('Error parsing order: $e');
            }
          }
        }
      } else if (response.containsKey('data') && response['data'] is List) {
        // Handle case where data is directly a list
        final List<dynamic> ordersData = response['data'];

        for (var orderData in ordersData) {
          try {
            final Order order = Order.fromJson(orderData);
            fetchedOrders.add(order);
          } catch (e) {
            print('Error parsing order: $e');
          }
        }
      }

      // Check pagination
      final int totalPages = response['totalPages'] ?? 1;
      hasMoreData = currentPage < totalPages;

      if (currentPage == 1) {
        _setupAnimations(fetchedOrders.length);
        orders = fetchedOrders;
      } else {
        orders.addAll(fetchedOrders);
        _setupAnimations(orders.length);
      }

      setState(() {
        isLoading = false;
        isLoadingMore = false;
        currentPage++;
      });

      // Start animations with stagger for new cards
      if (currentPage == 2) { // First load
        for (int i = 0; i < _cardControllers.length; i++) {
          Future.delayed(Duration(milliseconds: 100 * i), () {
            if (mounted && i < _cardControllers.length) {
              _cardControllers[i].forward();
            }
          });
        }
      }

      print('Processed ${fetchedOrders.length} orders successfully. Total: ${orders.length}');
    } catch (e) {
      print('Error fetching driver orders: $e');
      setState(() {
        errorMessage = 'Gagal memuat data pesanan: $e';
        isLoading = false;
        isLoadingMore = false;
      });
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
        order.orderStatus == OrderStatus.confirmed ||
            order.orderStatus == OrderStatus.preparing ||
            order.orderStatus == OrderStatus.ready_for_pickup ||
            order.orderStatus == OrderStatus.on_delivery
        ).toList();
      case 2: // Completed
        return orders.where((order) =>
        order.orderStatus == OrderStatus.delivered
        ).toList();
      case 3: // Cancelled
        return orders.where((order) =>
        order.orderStatus == OrderStatus.cancelled
        ).toList();
      default:
        return orders;
    }
  }

  Color getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.delivered:
        return const Color(0xFF10B981);
      case OrderStatus.cancelled:
        return const Color(0xFFEF4444);
      case OrderStatus.on_delivery:
        return const Color(0xFF3B82F6);
      case OrderStatus.preparing:
      case OrderStatus.ready_for_pickup:
        return const Color(0xFFF59E0B);
      case OrderStatus.confirmed:
        return GlobalStyle.primaryColor;
      default:
        return Colors.grey;
    }
  }

  IconData getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.delivered:
        return Icons.check_circle;
      case OrderStatus.cancelled:
        return Icons.cancel;
      case OrderStatus.on_delivery:
        return Icons.delivery_dining;
      case OrderStatus.preparing:
      case OrderStatus.ready_for_pickup:
        return Icons.restaurant;
      case OrderStatus.confirmed:
        return Icons.assignment_turned_in;
      default:
        return Icons.schedule;
    }
  }

  String getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.delivered:
        return 'Selesai';
      case OrderStatus.cancelled:
        return 'Dibatalkan';
      case OrderStatus.pending:
        return 'Menunggu';
      case OrderStatus.confirmed:
        return 'Dikonfirmasi';
      case OrderStatus.preparing:
        return 'Dipersiapkan';
      case OrderStatus.ready_for_pickup:
        return 'Siap Diambil';
      case OrderStatus.on_delivery:
        return 'Sedang Diantar';
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
    if (order.items == null || order.items!.isEmpty) {
      return "Tidak ada item";
    } else if (order.items!.length == 1) {
      return order.items![0].name;
    } else {
      final firstItem = order.items![0].name;
      final otherItemsCount = order.items!.length - 1;
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
    final formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(order.createdAt ?? DateTime.now());
    final statusColor = getStatusColor(order.orderStatus);
    final statusIcon = getStatusIcon(order.orderStatus);
    final statusText = getStatusText(order.orderStatus);
    final itemsText = getOrderItemsText(order);
    final deliveryFee = order.deliveryFee;

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
                _navigateToOrderDetail(order);
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
                                        order.store?.name ?? 'Unknown Store',
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
                                      '#${order.id}',
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
                          // Customer info
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.person_outline,
                                    color: Colors.blue[700], size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    order.customer?.name ?? 'Customer',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.blue[900],
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
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
                                    GlobalStyle.formatRupiah(deliveryFee),
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
                                      _navigateToOrderDetail(order);
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

  void _navigateToOrderDetail(Order order) async {
    try {
      // Get detailed order data using OrderService
      final orderDetail = await OrderService.getOrderById(order.id.toString());

      // Navigate to detail page with processed data
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => HistoryDriverDetailPage(orderDetail: {
            'customerName': orderDetail['customer']?['name'] ?? order.customer?.name ?? 'Customer',
            'customerPhone': orderDetail['customer']?['phone'] ?? order.customer?.phone ?? '-',
            'customerAddress': orderDetail['delivery_address'] ?? '-',
            'storeName': orderDetail['store']?['name'] ?? order.store?.name ?? 'Store',
            'storePhone': orderDetail['store']?['phone'] ?? order.store?.phone ?? '-',
            'storeAddress': orderDetail['store']?['address'] ?? order.store?.address ?? '-',
            'storeImage': orderDetail['store']?['imageUrl'] ?? order.store?.imageUrl ?? '',
            'status': orderDetail['order_status'] ?? order.orderStatus.toString().split('.').last,
            'amount': orderDetail['total_amount'] ?? order.totalAmount,
            'deliveryFee': orderDetail['delivery_fee'] ?? order.deliveryFee,
            'items': (orderDetail['items'] as List<dynamic>?)?.map((item) => {
              'name': item['name'] ?? 'Product',
              'price': item['price'] ?? 0,
              'quantity': item['quantity'] ?? 0,
              'image': item['imageUrl'] ?? '',
            }).toList() ?? [],
            'date': DateFormat('dd MMM yyyy, HH:mm').format(order.createdAt ?? DateTime.now()),
            'orderCode': '#${order.id}',
            'orderId': order.id.toString(),
          }),
        ),
      ).then((_) {
        _fetchDriverOrders(isRefresh: true);
      });
    } catch (e) {
      print('Error getting order detail: $e');
      // Fallback navigation with available data
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => HistoryDriverDetailPage(orderDetail: {
            'customerName': order.customer?.name ?? 'Customer',
            'customerPhone': order.customer?.phone ?? '-',
            'customerAddress': '-',
            'storeName': order.store?.name ?? 'Store',
            'storePhone': order.store?.phone ?? '-',
            'storeAddress': order.store?.address ?? '-',
            'storeImage': order.store?.imageUrl ?? '',
            'status': order.orderStatus.toString().split('.').last,
            'amount': order.totalAmount,
            'deliveryFee': order.deliveryFee,
            'items': order.items?.map((item) => {
              'name': item.name,
              'price': item.price,
              'quantity': item.quantity,
              'image': item.imageUrl ?? '',
            }).toList() ?? [],
            'date': DateFormat('dd MMM yyyy, HH:mm').format(order.createdAt ?? DateTime.now()),
            'orderCode': '#${order.id}',
            'orderId': order.id.toString(),
          }),
        ),
      ).then((_) {
        _fetchDriverOrders(isRefresh: true);
      });
    }
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
                  onTap: () => _fetchDriverOrders(isRefresh: true),
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
                      onPressed: () => _fetchDriverOrders(isRefresh: true),
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
                onRefresh: () => _fetchDriverOrders(isRefresh: true),
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

                    return NotificationListener<ScrollNotification>(
                      onNotification: (ScrollNotification scrollInfo) {
                        if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent &&
                            hasMoreData && !isLoadingMore) {
                          _fetchDriverOrders();
                        }
                        return false;
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredOrders.length + (isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == filteredOrders.length) {
                            return Container(
                              padding: const EdgeInsets.all(16),
                              child: Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(_primaryGradientStart),
                                ),
                              ),
                            );
                          }
                          return _buildOrderCard(filteredOrders[index], index);
                        },
                      ),
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