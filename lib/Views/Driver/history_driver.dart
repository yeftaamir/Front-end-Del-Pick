import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Models/order.dart';
import 'package:del_pick/Models/order_enum.dart';
import 'package:del_pick/Views/Component/driver_bottom_navigation.dart';
import 'package:del_pick/Views/Component/driver_order_status.dart';
import 'package:del_pick/Views/Driver/history_driver_detail.dart';

// Services
import 'package:del_pick/Services/driver_service.dart';
import 'package:del_pick/Services/order_service.dart';
import 'package:del_pick/Services/image_service.dart';

class HistoryDriverPage extends StatefulWidget {
  static const String route = '/Driver/HistoryDriver';

  const HistoryDriverPage({Key? key}) : super(key: key);

  @override
  State<HistoryDriverPage> createState() => _HistoryDriverPageState();
}

class _HistoryDriverPageState extends State<HistoryDriverPage>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {

  // Animation controllers
  late AnimationController _refreshController;
  late Animation<double> _refreshAnimation;

  // Data management
  List<OrderModel> _orders = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;

  // Pagination
  int _currentPage = 1;
  int _totalPages = 1;
  final int _limit = 10;
  bool _hasNextPage = true;

  // Filtering
  String? _selectedStatus;
  final List<Map<String, dynamic>> _statusFilters = [
    {'value': null, 'label': 'Semua', 'color': Colors.grey},
    {'value': 'pending', 'label': 'Menunggu', 'color': Colors.orange},
    {'value': 'confirmed', 'label': 'Dikonfirmasi', 'color': Colors.blue},
    {'value': 'preparing', 'label': 'Disiapkan', 'color': Colors.purple},
    {'value': 'ready_for_pickup', 'label': 'Siap Diambil', 'color': Colors.indigo},
    {'value': 'on_delivery', 'label': 'Diantar', 'color': Colors.teal},
    {'value': 'delivered', 'label': 'Selesai', 'color': Colors.green},
    {'value': 'cancelled', 'label': 'Dibatalkan', 'color': Colors.red},
  ];

  // Scroll controller for pagination
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setupScrollListener();
    _loadDriverOrders();
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _refreshController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _refreshAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _refreshController, curve: Curves.easeInOut),
    );
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _loadMoreOrders();
      }
    });
  }

  // Load driver orders using DriverService.getDriverOrders
  Future<void> _loadDriverOrders({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() {
        _currentPage = 1;
        _hasNextPage = true;
        _orders.clear();
      });
    }

    if (!isRefresh && !_hasNextPage) return;

    setState(() {
      if (isRefresh) {
        _isLoading = true;
        _errorMessage = null;
      } else {
        _isLoadingMore = true;
      }
    });

    try {
      // Use DriverService.getDriverOrders
      final response = await DriverService.getDriverOrders(
        page: _currentPage,
        limit: _limit,
        status: _selectedStatus,
        sortBy: 'created_at',
        sortOrder: 'desc',
      );

      if (response['data'] != null) {
        final ordersData = response['data'] as List;
        final List<OrderModel> newOrders = ordersData
            .map((orderJson) => OrderModel.fromJson(orderJson))
            .toList();

        setState(() {
          if (isRefresh) {
            _orders = newOrders;
          } else {
            _orders.addAll(newOrders);
          }

          // Update pagination info
          _totalPages = response['totalPages'] ?? 1;
          _hasNextPage = _currentPage < _totalPages;

          _isLoading = false;
          _isLoadingMore = false;
          _errorMessage = null;
        });

        if (isRefresh) {
          _refreshController.forward().then((_) {
            _refreshController.reset();
          });
        }
      }
    } catch (e) {
      print('Error loading driver orders: $e');
      setState(() {
        _errorMessage = 'Gagal memuat riwayat pesanan: $e';
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  // Load more orders for pagination
  Future<void> _loadMoreOrders() async {
    if (_isLoadingMore || !_hasNextPage) return;

    _currentPage++;
    await _loadDriverOrders();
  }

  // Refresh orders
  Future<void> _refreshOrders() async {
    await _loadDriverOrders(isRefresh: true);
  }

  // Filter orders by status
  void _filterOrdersByStatus(String? status) {
    if (_selectedStatus == status) return;

    setState(() {
      _selectedStatus = status;
      _currentPage = 1;
      _hasNextPage = true;
    });

    _loadDriverOrders(isRefresh: true);
  }

  // Navigate to order detail
  Future<void> _navigateToOrderDetail(OrderModel order) async {
    try {
      // Get detailed order data using OrderService.getOrderById
      final detailData = await OrderService.getOrderById(order.id.toString());

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => HistoryDriverDetailPage(
            orderId: order.id.toString(),
            orderDetail: detailData,
          ),
        ),
      );

      // Refresh if needed
      if (result == 'refresh') {
        _refreshOrders();
      }
    } catch (e) {
      print('Error getting order detail: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat detail pesanan: $e')),
      );
    }
  }

  // Get status color
  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.confirmed:
        return Colors.blue;
      case OrderStatus.preparing:
        return Colors.purple;
      case OrderStatus.readyForPickup:
        return Colors.indigo;
      case OrderStatus.onDelivery:
        return Colors.teal;
      case OrderStatus.delivered:
        return Colors.green;
      case OrderStatus.cancelled:
      case OrderStatus.rejected:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Get status display text
  String _getStatusDisplayText(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Menunggu';
      case OrderStatus.confirmed:
        return 'Dikonfirmasi';
      case OrderStatus.preparing:
        return 'Disiapkan';
      case OrderStatus.readyForPickup:
        return 'Siap Diambil';
      case OrderStatus.onDelivery:
        return 'Dalam Pengantaran';
      case OrderStatus.delivered:
        return 'Selesai';
      case OrderStatus.cancelled:
        return 'Dibatalkan';
      case OrderStatus.rejected:
        return 'Ditolak';
      default:
        return 'Unknown';
    }
  }

  // Calculate earnings for delivered orders
  double _calculateEarnings(OrderModel order) {
    if (order.orderStatus != OrderStatus.delivered) return 0.0;

    // Base delivery fee + percentage of service charge
    const double baseDeliveryFee = 5000.0;
    const double commissionRate = 0.8; // 80% of delivery fee
    return baseDeliveryFee + (order.deliveryFee * commissionRate);
  }

  Widget _buildStatusFilter() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _statusFilters.length,
        itemBuilder: (context, index) {
          final filter = _statusFilters[index];
          final isSelected = _selectedStatus == filter['value'];

          return Container(
            margin: const EdgeInsets.only(left: 16),
            child: FilterChip(
              label: Text(filter['label']),
              selected: isSelected,
              onSelected: (_) => _filterOrdersByStatus(filter['value']),
              backgroundColor: Colors.white,
              selectedColor: filter['color'].withOpacity(0.2),
              checkmarkColor: filter['color'],
              labelStyle: TextStyle(
                color: isSelected ? filter['color'] : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontFamily: GlobalStyle.fontFamily,
              ),
              side: BorderSide(
                color: isSelected ? filter['color'] : Colors.grey[300]!,
                width: 1,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order, int index) {
    final statusColor = _getStatusColor(order.orderStatus);
    final earnings = _calculateEarnings(order);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _navigateToOrderDetail(order),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with order ID and status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Order #${order.id}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: GlobalStyle.fontColor,
                        fontFamily: GlobalStyle.fontFamily,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        _getStatusDisplayText(order.orderStatus),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFamily: GlobalStyle.fontFamily,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Customer info
                if (order.customer != null)
                  Row(
                    children: [
                      ClipOval(
                        child: ImageService.displayImage(
                          imageSource: order.customer!.avatar ?? '',
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          placeholder: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.person, color: Colors.grey[600], size: 20),
                          ),
                          errorWidget: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.person, color: Colors.grey[600], size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.customer!.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                fontFamily: GlobalStyle.fontFamily,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              order.deliveryAddress ?? 'Alamat tidak tersedia',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                                fontFamily: GlobalStyle.fontFamily,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 12),

                // Store info
                if (order.store != null)
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: ImageService.displayImage(
                          imageSource: order.store!.imageUrl ?? '',
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          placeholder: Container(
                            width: 40,
                            height: 40,
                            color: Colors.grey[300],
                            child: Icon(Icons.store, color: Colors.grey[600], size: 20),
                          ),
                          errorWidget: Container(
                            width: 40,
                            height: 40,
                            color: Colors.grey[300],
                            child: Icon(Icons.store, color: Colors.grey[600], size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.store!.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                fontFamily: GlobalStyle.fontFamily,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${order.totalItems} item',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                                fontFamily: GlobalStyle.fontFamily,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Order total
                      Text(
                        order.formatTotalAmount(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: GlobalStyle.primaryColor,
                          fontSize: 14,
                          fontFamily: GlobalStyle.fontFamily,
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 12),

                // Date and earnings
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.access_time,
                            color: Colors.grey[600], size: 16),
                        const SizedBox(width: 4),
                        Text(
                          order.formattedDate,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                      ],
                    ),
                    if (earnings > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.monetization_on,
                                color: Colors.green, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              GlobalStyle.formatRupiah(earnings),
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                fontFamily: GlobalStyle.fontFamily,
                              ),
                            ),
                          ],
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/animations/empty_state.json',
            width: 200,
            height: 200,
          ),
          const SizedBox(height: 20),
          Text(
            _selectedStatus != null
                ? 'Tidak ada pesanan dengan status ini'
                : 'Belum ada riwayat pesanan',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedStatus != null
                ? 'Coba ubah filter status'
                : 'Pesanan akan muncul di sini setelah Anda menyelesaikan pengantaran',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          if (_selectedStatus != null) ...[
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _filterOrdersByStatus(null),
              style: ElevatedButton.styleFrom(
                backgroundColor: GlobalStyle.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text(
                'Lihat Semua',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 60),
          const SizedBox(height: 16),
          Text(
            'Terjadi Kesalahan',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Gagal memuat riwayat pesanan',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _refreshOrders,
            style: ElevatedButton.styleFrom(
              backgroundColor: GlobalStyle.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: const Text(
              'Coba Lagi',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingMore() {
    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      child: CircularProgressIndicator(
        color: GlobalStyle.primaryColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: const Color(0xffD6E6F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text(
          'Riwayat Pesanan',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontFamily: GlobalStyle.fontFamily,
          ),
        ),
        automaticallyImplyLeading: false,
        actions: [
          AnimatedBuilder(
            animation: _refreshAnimation,
            builder: (context, child) {
              return Transform.rotate(
                angle: _refreshAnimation.value * 2 * 3.14159,
                child: IconButton(
                  icon: Icon(
                    Icons.refresh,
                    color: GlobalStyle.primaryColor,
                  ),
                  onPressed: _isLoading ? null : _refreshOrders,
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Status filter
          _buildStatusFilter(),

          // Content
          Expanded(
            child: _isLoading && _orders.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: GlobalStyle.primaryColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Memuat riwayat pesanan...',
                    style: TextStyle(
                      color: GlobalStyle.fontColor,
                      fontFamily: GlobalStyle.fontFamily,
                    ),
                  ),
                ],
              ),
            )
                : _errorMessage != null && _orders.isEmpty
                ? _buildErrorState()
                : _orders.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
              color: GlobalStyle.primaryColor,
              onRefresh: _refreshOrders,
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _orders.length + (_isLoadingMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _orders.length) {
                    return _buildLoadingMore();
                  }
                  return _buildOrderCard(_orders[index], index);
                },
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: DriverBottomNavigation(
        currentIndex: 1, // History tab
        onTap: (index) {
          // Handle navigation
        },
      ),
    );
  }
}