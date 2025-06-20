import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../Models/order_enum.dart';
import '../Component/cust_bottom_navigation.dart';
import 'package:del_pick/Models/item_model.dart';
import 'package:del_pick/Models/store.dart';
import 'package:del_pick/Models/tracking.dart';
import 'package:del_pick/Models/order.dart';
import 'package:del_pick/Views/Customers/history_detail.dart';
import 'package:del_pick/Services/order_service.dart';
import 'package:del_pick/Services/image_service.dart';
import 'package:del_pick/Common/global_style.dart';
import 'home_cust.dart';

class HistoryCustomer extends StatefulWidget {
  static const String route = "/Customers/HistoryCustomer";

  const HistoryCustomer({Key? key}) : super(key: key);

  @override
  State<HistoryCustomer> createState() => _HistoryCustomerState();
}

class _HistoryCustomerState extends State<HistoryCustomer> with TickerProviderStateMixin {
  int _selectedIndex = 1;
  late TabController _tabController;

  // Animation controllers
  late List<AnimationController> _cardControllers;
  late List<Animation<double>> _fadeAnimations;
  late List<Animation<Offset>> _slideAnimations;
  late AnimationController _headerController;
  late Animation<double> _headerAnimation;

  // List for storing orders from API
  List<Order> orders = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Colors
  final Color _primaryGradientStart = GlobalStyle.primaryColor;
  final Color _primaryGradientEnd = GlobalStyle.primaryColor.withOpacity(0.8);
  final Color _cardBackground = Colors.white;
  final Color _scaffoldBg = const Color(0xFFF7F8FC);

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 4, vsync: this);

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

    // Initialize with placeholders
    _cardControllers = [];
    _fadeAnimations = [];
    _slideAnimations = [];

    // Fetch orders on init
    _fetchOrders();
  }

  // Fetch orders from API
  Future<void> _fetchOrders() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final orderData = await OrderService.getOrdersByUser();

      List<Order> fetchedOrders = [];

      if (orderData.isNotEmpty) {
        if (orderData['orders'] is List) {
          for (var orderJson in orderData['orders']) {
            try {
              final order = Order.fromJson(orderJson);
              fetchedOrders.add(order);
            } catch (e) {
              print('Error parsing order: $e');
            }
          }
        } else {
          try {
            for (var key in orderData.keys) {
              if (orderData[key] is List) {
                for (var orderJson in orderData[key]) {
                  try {
                    final order = Order.fromJson(orderJson);
                    fetchedOrders.add(order);
                  } catch (e) {
                    print('Error parsing order in $key: $e');
                  }
                }
              }
            }
          } catch (e) {
            print('Error iterating order data: $e');
          }
        }
      }

      _setupAnimations(fetchedOrders.length);

      setState(() {
        orders = fetchedOrders;
        _isLoading = false;
      });

      // Start animations with stagger
      for (int i = 0; i < _cardControllers.length; i++) {
        Future.delayed(Duration(milliseconds: 100 * i), () {
          if (mounted && i < _cardControllers.length) {
            _cardControllers[i].forward();
          }
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load orders: $e';
      });
      print('Error fetching orders: $e');
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
      case 0:
        return orders;
      case 1:
        return orders.where((order) => !order.status.isCompleted).toList();
      case 2:
        return orders.where((order) =>
        order.status == OrderStatus.completed ||
            order.status == OrderStatus.delivered
        ).toList();
      case 3:
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
    } else if (status == OrderStatus.on_delivery || status == OrderStatus.driverHeadingToCustomer) {
      return const Color(0xFF3B82F6);
    } else if (status == OrderStatus.preparing || status == OrderStatus.driverAtStore) {
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
    } else if (status == OrderStatus.on_delivery || status == OrderStatus.driverHeadingToCustomer) {
      return Icons.delivery_dining;
    } else if (status == OrderStatus.preparing || status == OrderStatus.driverAtStore) {
      return Icons.restaurant;
    } else {
      return Icons.schedule;
    }
  }

  String getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.completed:
        return 'Selesai';
      case OrderStatus.delivered:
        return 'Terkirim';
      case OrderStatus.cancelled:
        return 'Dibatalkan';
      case OrderStatus.pending:
        return 'Menunggu';
      case OrderStatus.approved:
        return 'Disetujui';
      case OrderStatus.preparing:
        return 'Diproses';
      case OrderStatus.on_delivery:
        return 'Diantar';
      case OrderStatus.driverAssigned:
        return 'Driver Ditugaskan';
      case OrderStatus.driverHeadingToStore:
        return 'Driver Menuju Toko';
      case OrderStatus.driverAtStore:
        return 'Driver Di Toko';
      case OrderStatus.driverHeadingToCustomer:
        return 'Driver Menuju Anda';
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
        Navigator.pushReplacementNamed(context, HomePage.route);
      }
    });
  }

  String getOrderItemsText(Order order) {
    if (order.items.isEmpty) {
      return "Tidak ada item";
    }
    if (order.items.length == 1) {
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
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HistoryDetailPage(order: order),
                  ),
                ).then((_) => _fetchOrders());
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
                          // Store image with hero animation potential
                          Hero(
                            tag: 'order-image-${order.id}',
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: order.items.isNotEmpty && order.items.first.imageUrl.isNotEmpty
                                    ? ImageService.displayImage(
                                  imageSource: order.items.first.imageUrl,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  placeholder: Container(
                                    color: Colors.grey[200],
                                    child: Icon(Icons.restaurant_menu,
                                        color: Colors.grey[400], size: 32),
                                  ),
                                )
                                    : Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.grey[300]!, Colors.grey[200]!],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  child: Icon(Icons.restaurant_menu,
                                      color: Colors.grey[400], size: 32),
                                ),
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
                          const SizedBox(height: 20),
                          // Bottom section with total and action
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total Pembayaran',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    order.formatTotal(),
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
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => HistoryDetailPage(order: order),
                                        ),
                                      ).then((_) => _fetchOrders());
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
                  Icons.receipt_long_outlined,
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
                'Belum ada pesanan untuk ditampilkan',
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
                      Navigator.pushReplacementNamed(context, HomePage.route);
                    },
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.shopping_cart_outlined, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Pesan Sekarang',
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
              _errorMessage ?? 'Terjadi kesalahan saat memuat data',
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
                  onTap: _fetchOrders,
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
          HomePage.route,
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
                      'Riwayat Pesanan',
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
                        HomePage.route,
                            (route) => false,
                      );
                    },
                  ),
                ),
              ),
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
                  tabs: const [
                    Tab(text: 'Semua'),
                    Tab(text: 'Diproses'),
                    Tab(text: 'Selesai'),
                    Tab(text: 'Dibatalkan'),
                  ],
                ),
              ),
            ),
            // Content
            SliverFillRemaining(
              child: _isLoading
                  ? _buildLoadingState()
                  : _errorMessage != null
                  ? _buildErrorState()
                  : RefreshIndicator(
                onRefresh: _fetchOrders,
                color: _primaryGradientStart,
                child: TabBarView(
                  controller: _tabController,
                  children: List.generate(4, (tabIndex) {
                    final filteredOrders = getFilteredOrders(tabIndex);

                    if (filteredOrders.isEmpty) {
                      return _buildEmptyState(
                          'Tidak ada pesanan ${tabIndex == 0 ? '' : tabIndex == 1 ? 'diproses' : tabIndex == 2 ? 'selesai' : 'dibatalkan'}'
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
        bottomNavigationBar: CustomBottomNavigation(
          selectedIndex: _selectedIndex,
          onItemTapped: _onItemTapped,
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