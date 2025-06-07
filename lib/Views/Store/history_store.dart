import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:del_pick/Models/item_model.dart';
import 'package:del_pick/Models/store.dart';
import 'package:del_pick/Models/tracking.dart';
import 'package:del_pick/Models/order.dart';
import 'package:del_pick/Models/order_enum.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Views/Component/bottom_navigation.dart';
import 'package:del_pick/Views/Store/home_store.dart';
import 'package:del_pick/Views/Store/historystore_detail.dart';
import 'package:del_pick/Services/order_service.dart';
import 'package:del_pick/Services/store_service.dart';
import 'package:del_pick/Services/image_service.dart';

class HistoryStorePage extends StatefulWidget {
  static const String route = '/Store/HistoryStore';

  const HistoryStorePage({Key? key}) : super(key: key);

  @override
  State<HistoryStorePage> createState() => _HistoryStorePageState();
}

class _HistoryStorePageState extends State<HistoryStorePage> with TickerProviderStateMixin {
  int _currentIndex = 2; // History tab selected
  late TabController _tabController;

  // State management variables
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  List<Order> _orders = [];

  // Animation controllers
  late List<AnimationController> _cardControllers;
  late List<Animation<double>> _fadeAnimations;
  late List<Animation<Offset>> _slideAnimations;
  late AnimationController _headerController;
  late Animation<double> _headerAnimation;

  // Tab categories
  final List<String> _tabs = ['Semua', 'Diproses', 'Selesai', 'Dibatalkan'];

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

    // Initialize with empty controllers and animations
    _cardControllers = [];
    _fadeAnimations = [];
    _slideAnimations = [];

    // Fetch order data
    _fetchOrderHistory();
  }

  // Fetch order history from the API
  Future<void> _fetchOrderHistory() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final orderData = await OrderService.getOrdersByStore();
      final List<dynamic> ordersList = orderData['orders'] ?? [];

      List<Order> orders = [];

      for (var orderJson in ordersList) {
        try {
          if (orderJson['store'] != null && orderJson['store']['image'] != null) {
            orderJson['store']['image'] =
                ImageService.getImageUrl(orderJson['store']['image']);
          }

          if (orderJson['customer'] != null && orderJson['customer']['avatar'] != null) {
            orderJson['customer']['avatar'] =
                ImageService.getImageUrl(orderJson['customer']['avatar']);
          }

          if (orderJson['items'] != null && orderJson['items'] is List) {
            for (var item in orderJson['items']) {
              if (item['imageUrl'] != null) {
                item['imageUrl'] = ImageService.getImageUrl(item['imageUrl']);
              }
            }
          }

          Order order = Order.fromJson(orderJson);
          orders.add(order);
        } catch (e) {
          print('Error parsing order: $e');
        }
      }

      orders.sort((a, b) => b.orderDate.compareTo(a.orderDate));

      _setupAnimations(orders.length);

      setState(() {
        _orders = orders;
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
        _hasError = true;
        _errorMessage = 'Failed to load order history: $e';
      });
      print('Error in _fetchOrderHistory: $e');
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
        return _orders;
      case 1: // In progress
        return _orders.where((order) =>
        order.status != OrderStatus.completed &&
            order.status != OrderStatus.cancelled &&
            order.status != OrderStatus.delivered
        ).toList();
      case 2: // Completed
        return _orders.where((order) =>
        order.status == OrderStatus.completed ||
            order.status == OrderStatus.delivered
        ).toList();
      case 3: // Cancelled
        return _orders.where((order) => order.status == OrderStatus.cancelled).toList();
      default:
        return _orders;
    }
  }

  Color getStatusColor(OrderStatus status) {
    if (status == OrderStatus.completed || status == OrderStatus.delivered) {
      return const Color(0xFF10B981);
    } else if (status == OrderStatus.cancelled) {
      return const Color(0xFFEF4444);
    } else if (status == OrderStatus.on_delivery ||
        status == OrderStatus.driverHeadingToCustomer) {
      return const Color(0xFF3B82F6);
    } else if (status == OrderStatus.preparing ||
        status == OrderStatus.approved) {
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
    } else if (status == OrderStatus.preparing) {
      return Icons.restaurant_menu;
    } else if (status == OrderStatus.approved) {
      return Icons.thumb_up;
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
        return 'Disetujui';
      case OrderStatus.preparing:
        return 'Disiapkan';
      case OrderStatus.on_delivery:
        return 'Diantar';
      case OrderStatus.driverAssigned:
        return 'Driver Ditugaskan';
      case OrderStatus.driverHeadingToStore:
        return 'Diambil';
      case OrderStatus.driverAtStore:
        return 'Di Toko';
      case OrderStatus.driverHeadingToCustomer:
        return 'Diantar';
      case OrderStatus.driverArrived:
        return 'Driver Tiba';
      default:
        return 'Diproses';
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
      if (index == 0) {
        Navigator.pushReplacementNamed(context, HomeStore.route);
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

  void _navigateToOrderDetail(Order order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HistoryStoreDetailPage(orderId: order.id),
      ),
    ).then((_) {
      _fetchOrderHistory();
    });
  }

  Widget _buildOrderCard(Order order, int index) {
    final formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(order.orderDate);
    final statusColor = getStatusColor(order.status);
    final statusIcon = getStatusIcon(order.status);
    final statusText = getStatusText(order.status);
    final itemsText = getOrderItemsText(order);
    final orderTotal = order.total;

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
                          // Store icon with hero animation potential
                          Hero(
                            tag: 'store-order-${order.id}',
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
                                Icons.storefront_outlined,
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
                                        'Order #${order.id.substring(0, order.id.length < 8 ? order.id.length : 8)}',
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
                          // Customer info preview
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.purple[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.purple[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.person_outline,
                                    color: Colors.purple[700], size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Pelanggan: ${order.customerId ?? "Tidak Diketahui"}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.purple[900],
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
                          // Bottom section with total and action
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total Pesanan',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    GlobalStyle.formatRupiah(orderTotal),
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
                'Belum ada riwayat pesanan untuk ditampilkan',
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
                    onTap: _fetchOrderHistory,
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.refresh_outlined, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Refresh',
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
              _errorMessage.isNotEmpty ? _errorMessage : 'Terjadi kesalahan saat memuat data',
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
                  onTap: _fetchOrderHistory,
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
          HomeStore.route,
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
                        HomeStore.route,
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
                      onPressed: _fetchOrderHistory,
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
              child: _isLoading
                  ? _buildLoadingState()
                  : _hasError
                  ? _buildErrorState()
                  : RefreshIndicator(
                onRefresh: _fetchOrderHistory,
                color: _primaryGradientStart,
                child: TabBarView(
                  controller: _tabController,
                  children: List.generate(_tabs.length, (tabIndex) {
                    final filteredOrders = getFilteredOrders(tabIndex);

                    if (filteredOrders.isEmpty) {
                      return _buildEmptyState(
                          'Tidak ada pesanan ${_tabs[tabIndex].toLowerCase()}'
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
        bottomNavigationBar: BottomNavigationComponent(
          currentIndex: _currentIndex,
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