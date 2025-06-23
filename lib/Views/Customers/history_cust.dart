import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';

// Import Models
import 'package:del_pick/Models/order.dart';
import 'package:del_pick/Models/order_enum.dart';
import 'package:del_pick/Models/store.dart';
import 'package:del_pick/Models/menu_item.dart';

// Import Services
import 'package:del_pick/Services/order_service.dart';
import 'package:del_pick/Services/menu_service.dart';
import 'package:del_pick/Services/image_service.dart';

// Import Components and Screens
import '../Component/cust_bottom_navigation.dart';
import 'package:del_pick/Common/global_style.dart';
import 'home_cust.dart';
import 'history_detail.dart';

class HistoryCustomer extends StatefulWidget {
  static const String route = "/Customers/HistoryCustomer";

  const HistoryCustomer({Key? key}) : super(key: key);

  @override
  State<HistoryCustomer> createState() => _HistoryCustomerState();
}

class _HistoryCustomerState extends State<HistoryCustomer> with TickerProviderStateMixin {
  int _selectedIndex = 1;
  late TabController _tabController;

  // Animation controllers for cards
  late List<AnimationController> _cardControllers;
  late List<Animation<Offset>> _cardAnimations;

  // Data state variables
  List<OrderModel> orders = [];
  Map<int, List<MenuItemModel>> storeMenuItems = {}; // Cache menu items by store ID
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;

  // Pagination variables
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalItems = 0;
  static const int _pageSize = 10;
  bool _hasMoreData = true;

  // Scroll controller for pagination
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 4, vsync: this);
    _scrollController = ScrollController();

    // Initialize with empty controllers, will be updated when data is fetched
    _cardControllers = [];
    _cardAnimations = [];

    // Setup scroll listener for pagination
    _scrollController.addListener(_onScroll);

    // Fetch initial orders
    _fetchOrders(isRefresh: true);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    for (var controller in _cardControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // Scroll listener for pagination
  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8) {
      _loadMoreOrders();
    }
  }

  // Fetch orders from API using OrderService.getOrdersByUser()
  Future<void> _fetchOrders({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() {
        _currentPage = 1;
        _hasMoreData = true;
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      // Get current tab filter
      String? statusFilter = _getStatusFilter(_tabController.index);

      // Call OrderService.getOrdersByUser() with proper parameters
      final orderData = await OrderService.getOrdersByUser(
        page: _currentPage,
        limit: _pageSize,
        status: statusFilter,
        sortBy: 'created_at',
        sortOrder: 'desc',
      );

      // Parse the response according to the service structure
      List<OrderModel> fetchedOrders = [];
      if (orderData['orders'] != null && orderData['orders'] is List) {
        for (var orderJson in orderData['orders']) {
          try {
            final order = OrderModel.fromJson(orderJson);
            fetchedOrders.add(order);
          } catch (e) {
            print('Error parsing order: $e');
            // Continue with next order if one fails to parse
          }
        }
      }

      // Load menu items for stores if needed
      await _loadMenuItemsForOrders(fetchedOrders);

      // Update pagination info
      _totalItems = orderData['totalItems'] ?? 0;
      _totalPages = orderData['totalPages'] ?? 1;
      _hasMoreData = _currentPage < _totalPages;

      setState(() {
        if (isRefresh) {
          orders = fetchedOrders;
        } else {
          orders.addAll(fetchedOrders);
        }
        _isLoading = false;
        _isLoadingMore = false;
      });

      // Setup animations after data is fetched
      if (isRefresh) {
        _setupAnimations(orders.length);
        _startAnimations();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _errorMessage = 'Failed to load orders: $e';
      });
      print('Error fetching orders: $e');
    }
  }

  // Load more orders for pagination
  Future<void> _loadMoreOrders() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() {
      _isLoadingMore = true;
    });

    _currentPage++;
    await _fetchOrders(isRefresh: false);
  }

  // Load menu items for stores using MenuItemService.getMenuItemsByStore()
  Future<void> _loadMenuItemsForOrders(List<OrderModel> ordersList) async {
    // Get unique store IDs that we don't have menu items for yet
    Set<int> storeIds = {};
    for (var order in ordersList) {
      if (!storeMenuItems.containsKey(order.storeId)) {
        storeIds.add(order.storeId);
      }
    }

    // Load menu items for each store
    for (int storeId in storeIds) {
      try {
        final menuData = await MenuItemService.getMenuItemsByStore(
          storeId: storeId.toString(),
          page: 1,
          limit: 50, // Get enough items to cover order items
          isAvailable: null, // Get all items regardless of availability
        );

        if (menuData['data'] != null && menuData['data'] is List) {
          List<MenuItemModel> menuItems = [];
          for (var menuJson in menuData['data']) {
            try {
              final menuItem = MenuItemModel.fromJson(menuJson);
              menuItems.add(menuItem);
            } catch (e) {
              print('Error parsing menu item: $e');
            }
          }
          storeMenuItems[storeId] = menuItems;
        }
      } catch (e) {
        print('Error loading menu items for store $storeId: $e');
        // Continue with other stores if one fails
      }
    }
  }

  // Get status filter based on tab index
  String? _getStatusFilter(int tabIndex) {
    switch (tabIndex) {
      case 0: // All orders
        return null;
      case 1: // In progress
        return 'pending,confirmed,preparing,ready_for_pickup,on_delivery';
      case 2: // Completed
        return 'delivered';
      case 3: // Cancelled
        return 'cancelled';
      default:
        return null;
    }
  }

  // Setup animations based on number of items
  void _setupAnimations(int totalCards) {
    // Clean up existing controllers if any
    for (var controller in _cardControllers) {
      controller.dispose();
    }

    // Create new controllers
    _cardControllers = List.generate(
      totalCards,
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
  }

  // Start animations
  void _startAnimations() {
    Future.delayed(const Duration(milliseconds: 100), () {
      for (var controller in _cardControllers) {
        controller.forward();
      }
    });
  }

  // Get filtered orders based on tab index (client-side filtering for better UX)
  List<OrderModel> getFilteredOrders(int tabIndex) {
    switch (tabIndex) {
      case 0: // All orders
        return orders;
      case 1: // In progress
        return orders.where((order) => !order.orderStatus.isCompleted).toList();
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

  // Get status color based on order status
  Color getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.delivered:
        return Colors.green;
      case OrderStatus.cancelled:
      case OrderStatus.rejected:
        return Colors.red;
      case OrderStatus.onDelivery:
        return Colors.blue;
      case OrderStatus.preparing:
        return Colors.orange;
      case OrderStatus.confirmed:
        return Colors.indigo;
      default:
        return GlobalStyle.primaryColor;
    }
  }

  // Get human-readable status text
  String getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Menunggu';
      case OrderStatus.confirmed:
        return 'Dikonfirmasi';
      case OrderStatus.preparing:
        return 'Diproses';
      case OrderStatus.readyForPickup:
        return 'Siap Diambil';
      case OrderStatus.onDelivery:
        return 'Diantar';
      case OrderStatus.delivered:
        return 'Selesai';
      case OrderStatus.cancelled:
        return 'Dibatalkan';
      case OrderStatus.rejected:
        return 'Ditolak';
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

  // Create a summary of items for display
  String getOrderItemsText(OrderModel order) {
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

  // Get first item image URL
  String? getFirstItemImageUrl(OrderModel order) {
    if (order.items.isNotEmpty && order.items[0].imageUrl != null) {
      return order.items[0].imageUrl;
    }
    return null;
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

  Widget _buildOrderCard(OrderModel order, int index) {
    final formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(order.createdAt);
    final statusColor = getStatusColor(order.orderStatus);
    final statusText = getStatusText(order.orderStatus);
    final itemsText = getOrderItemsText(order);
    final firstImageUrl = getFirstItemImageUrl(order);

    return SlideTransition(
      position: index < _cardAnimations.length ? _cardAnimations[index] : const AlwaysStoppedAnimation(Offset.zero),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => HistoryDetailPage(
                  order: order,
                ),
              ),
            ).then((_) => _fetchOrders(isRefresh: true)); // Refresh when returning
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Order item image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: firstImageUrl != null
                          ? ImageService.displayImage(
                        imageSource: firstImageUrl,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        placeholder: Container(
                          width: 60,
                          height: 60,
                          color: Colors.grey[200],
                          child: const Icon(Icons.restaurant_menu, color: Colors.grey),
                        ),
                        errorWidget: Container(
                          width: 60,
                          height: 60,
                          color: Colors.grey[300],
                          child: const Icon(Icons.image_not_supported, color: Colors.grey),
                        ),
                      )
                          : Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.restaurant_menu, color: Colors.grey),
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
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: GlobalStyle.fontColor,
                                    fontFamily: GlobalStyle.fontFamily,
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
                            'Order #${order.id}',
                            style: TextStyle(
                              fontSize: 13,
                              color: GlobalStyle.primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formattedDate,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            itemsText,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w500,
                              fontFamily: GlobalStyle.fontFamily,
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
                          'Total Pembayaran',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          order.formatTotalAmount(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: GlobalStyle.primaryColor,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => HistoryDetailPage(
                              order: order,
                            ),
                          ),
                        ).then((_) => _fetchOrders(isRefresh: true));
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
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/animations/empty_cart.json',
              width: 200,
              height: 200,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
                fontFamily: GlobalStyle.fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Belum ada pesanan untuk ditampilkan',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontFamily: GlobalStyle.fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushReplacementNamed(context, HomePage.route);
              },
              icon: const Icon(Icons.shopping_bag),
              label: const Text('Mulai Belanja'),
              style: ElevatedButton.styleFrom(
                backgroundColor: GlobalStyle.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/animations/loading_animation.json',
            width: 150,
            height: 150,
          ),
          const SizedBox(height: 16),
          Text(
            'Memuat riwayat pesanan...',
            style: TextStyle(
              fontSize: 16,
              color: GlobalStyle.primaryColor,
              fontWeight: FontWeight.w500,
              fontFamily: GlobalStyle.fontFamily,
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
          Lottie.asset(
            'assets/animations/caution.json',
            width: 150,
            height: 150,
          ),
          const SizedBox(height: 16),
          Text(
            'Gagal Memuat Data',
            style: TextStyle(
              fontSize: 18,
              color: Colors.red[600],
              fontWeight: FontWeight.bold,
              fontFamily: GlobalStyle.fontFamily,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage ?? 'Terjadi kesalahan saat memuat data',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontFamily: GlobalStyle.fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _fetchOrders(isRefresh: true),
            icon: const Icon(Icons.refresh),
            label: const Text('Coba Lagi'),
            style: ElevatedButton.styleFrom(
              backgroundColor: GlobalStyle.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadMoreIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(GlobalStyle.primaryColor),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Memuat lebih banyak...',
            style: TextStyle(
              color: GlobalStyle.primaryColor,
              fontSize: 14,
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
          HomePage.route,
              (route) => false,
        );
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xffF5F7FA),
        appBar: AppBar(
          elevation: 0.5,
          backgroundColor: Colors.white,
          title: Text(
            'Riwayat Pesanan',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: GlobalStyle.fontColor,
              fontFamily: GlobalStyle.fontFamily,
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
                HomePage.route,
                    (route) => false,
              );
            },
          ),
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: GlobalStyle.primaryColor,
            unselectedLabelColor: Colors.grey[600],
            labelStyle: const TextStyle(fontWeight: FontWeight.w600),
            indicatorColor: GlobalStyle.primaryColor,
            indicatorWeight: 3,
            onTap: (index) {
              // Refresh data when tab changes
              _fetchOrders(isRefresh: true);
            },
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Semua'),
                    if (_totalItems > 0)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: GlobalStyle.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _totalItems.toString(),
                          style: TextStyle(
                            fontSize: 11,
                            color: GlobalStyle.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Tab(text: 'Diproses'),
              const Tab(text: 'Selesai'),
              const Tab(text: 'Dibatalkan'),
            ],
          ),
        ),
        body: _isLoading
            ? _buildLoadingState()
            : _errorMessage != null
            ? _buildErrorState()
            : RefreshIndicator(
          onRefresh: () => _fetchOrders(isRefresh: true),
          color: GlobalStyle.primaryColor,
          child: TabBarView(
            controller: _tabController,
            children: List.generate(4, (tabIndex) {
              final filteredOrders = getFilteredOrders(tabIndex);

              if (filteredOrders.isEmpty && !_isLoading) {
                return _buildEmptyState(
                    'Tidak ada pesanan ${tabIndex == 0 ? '' : tabIndex == 1 ? 'yang sedang diproses' : tabIndex == 2 ? 'yang selesai' : 'yang dibatalkan'}'
                );
              }

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: filteredOrders.length + (_isLoadingMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index < filteredOrders.length) {
                    return _buildOrderCard(filteredOrders[index], index);
                  } else {
                    return _buildLoadMoreIndicator();
                  }
                },
              );
            }),
          ),
        ),
        bottomNavigationBar: CustomBottomNavigation(
          selectedIndex: _selectedIndex,
          onItemTapped: _onItemTapped,
        ),
      ),
    );
  }
}