import 'package:del_pick/Models/driver_request_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Views/Component/driver_bottom_navigation.dart';
import 'package:del_pick/Views/Driver/history_driver_detail.dart';
import 'package:del_pick/Services/driver_request_service.dart';
import 'package:del_pick/Services/store_service.dart';
import 'package:del_pick/Services/image_service.dart';
import 'package:del_pick/Services/auth_service.dart';
import 'package:del_pick/Models/driver_request.dart';
import 'package:del_pick/Models/order_enum.dart';

class HistoryDriverPage extends StatefulWidget {
  static const String route = '/Driver/HistoryDriver';

  const HistoryDriverPage({Key? key}) : super(key: key);

  @override
  State<HistoryDriverPage> createState() => _HistoryDriverPageState();
}

class _HistoryDriverPageState extends State<HistoryDriverPage>
    with TickerProviderStateMixin {
  int _currentIndex = 1; // History tab selected
  late TabController _tabController;

// State management
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  List<DriverRequestModel> _driverRequests = [];
  Map<String, String> _storeNamesCache = {};

// Authentication state
  bool _isAuthenticated = false;
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _driverData;

// Pagination
  int _currentPage = 1;
  int _totalPages = 1;
  bool _isLoadingMore = false;

// Animation controllers
  late List<AnimationController> _cardControllers;
  late List<Animation<Offset>> _cardAnimations;

// Tab categories berdasarkan ORDER STATUS (bukan request status)
  final List<Map<String, dynamic>> _tabs = [
    {'label': 'Semua', 'statuses': null},
    {
      'label': 'Menunggu',
      'statuses': ['pending'] // Pesanan yang masih menunggu
    },
    {
      'label': 'Diproses',
      'statuses': ['confirmed', 'preparing'] // Toko sedang memproses
    },
    {
      'label': 'Siap Diambil',
      'statuses': ['ready_for_pickup'] // Siap diambil driver
    },
    {
      'label': 'Diantar',
      'statuses': ['on_delivery'] // Sedang diantar
    },
    {
      'label': 'Selesai',
      'statuses': ['delivered'] // Sudah selesai
    },
    {
      'label': 'Dibatalkan',
      'statuses': ['cancelled', 'rejected'] // Dibatalkan/ditolak
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _cardControllers = [];
    _cardAnimations = [];
    _initializeAuthentication();
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (var controller in _cardControllers) {
      controller.dispose();
    }
    super.dispose();
  }

// ===== AUTHENTICATION & INITIALIZATION =====

  Future<void> _initializeAuthentication() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      print('🔍 HistoryDriver: Initializing authentication...');

// Check authentication
      final isAuth = await AuthService.isAuthenticated();
      if (!isAuth) {
        throw Exception('User not authenticated');
      }

// Get user data
      final userData = await AuthService.getUserData();
      if (userData == null) {
        throw Exception('No user data found');
      }

// Verify driver role
      final userRole = await AuthService.getUserRole();
      if (userRole?.toLowerCase() != 'driver') {
        throw Exception('User is not a driver');
      }

// Get driver-specific data
      final roleSpecificData = await AuthService.getRoleSpecificData();
      if (roleSpecificData == null) {
        throw Exception('No driver data found');
      }

      setState(() {
        _isAuthenticated = true;
        _userData = userData;
        _driverData = roleSpecificData;
      });

      print('✅ HistoryDriver: Authentication successful');
      await _fetchDriverRequests();
    } catch (e) {
      print('❌ HistoryDriver: Authentication error: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Authentication failed: $e';
        _isAuthenticated = false;
      });
    }
  }

// ===== DATA FETCHING =====
  Future<String> _getStoreName(int? storeId) async {
    if (storeId == null) return 'Unknown Store';

    final cacheKey = storeId.toString();
    if (_storeNamesCache.containsKey(cacheKey)) {
      return _storeNamesCache[cacheKey]!;
    }

    try {
      final storeResponse = await StoreService.getStoreById(storeId.toString());

      // ✅ FIX: Handle StoreService response structure
      String storeName = 'Unknown Store';

      if (storeResponse['success'] == true && storeResponse['data'] != null) {
        // Success response structure
        storeName =
            storeResponse['data']['name']?.toString() ?? 'Unknown Store';
      } else if (storeResponse['name'] != null) {
        // Direct data structure
        storeName = storeResponse['name']?.toString() ?? 'Unknown Store';
      }

      _storeNamesCache[cacheKey] = storeName;
      return storeName;
    } catch (e) {
      print('❌ Error fetching store name for ID $storeId: $e');
      _storeNamesCache[cacheKey] = 'Unknown Store';
      return 'Unknown Store';
    }
  }

  Future<void> _fetchDriverRequests({bool isRefresh = false}) async {
    if (!_isAuthenticated) return;

    if (isRefresh) {
      _currentPage = 1;
      _storeNamesCache.clear(); // ✅ ADD: Clear store names cache on refresh
    }

    setState(() {
      if (isRefresh) {
        _isLoading = true;
      } else {
        _isLoadingMore = true;
      }
      _hasError = false;
    });

    try {
      print('🔄 HistoryDriver: Fetching driver requests - Page: $_currentPage');

      final response = await DriverRequestService.getDriverRequests(
        page: _currentPage,
        limit: 20,
        sortBy: 'created_at',
        sortOrder: 'desc',
      );

      final List<dynamic> requestsList = response['requests'] ?? [];
      _totalPages = response['totalPages'] ?? 1;

      List<DriverRequestModel> newRequests = [];
      for (var requestJson in requestsList) {
        try {
          final request = DriverRequestModel.fromJson(requestJson);
          newRequests.add(request);
        } catch (e) {
          print('Error processing request: $e');
        }
      }

      setState(() {
        if (isRefresh) {
          _driverRequests = newRequests;
        } else {
          _driverRequests.addAll(newRequests);
        }
        _isLoading = false;
        _isLoadingMore = false;
        _initializeAnimations();
      });

      print(
          '✅ HistoryDriver: Successfully loaded ${newRequests.length} requests');
    } catch (e) {
      print('❌ HistoryDriver: Error fetching requests: $e');
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _hasError = true;
        _errorMessage = 'Failed to load history: $e';
      });
    }
  }

  void _initializeAnimations() {
    for (var controller in _cardControllers) {
      controller.dispose();
    }

    if (_driverRequests.isEmpty) return;

    _cardControllers = List.generate(
      _driverRequests.length,
      (index) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 600 + (index * 100)),
      ),
    );

    _cardAnimations = _cardControllers.map((controller) {
      return Tween<Offset>(
        begin: const Offset(0.5, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeOutCubic,
      ));
    }).toList();

    for (var controller in _cardControllers) {
      controller.forward();
    }
  }

// ===== FILTERING BERDASARKAN ORDER STATUS =====

  List<DriverRequestModel> getFilteredRequests(int tabIndex) {
    if (tabIndex == 0) return _driverRequests; // Semua

    final tabStatuses = _tabs[tabIndex]['statuses'] as List<String>?;
    if (tabStatuses == null) return _driverRequests;

    return _driverRequests.where((request) {
      final orderStatus = request.order?.orderStatus.value.toLowerCase() ?? '';
      return tabStatuses.contains(orderStatus);
    }).toList();
  }

// ===== NAVIGATION & ACTIONS =====

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _navigateToDetail(DriverRequestModel request) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HistoryDriverDetailPage(
          orderId: request.orderId.toString(),
          requestId: request.id.toString(),
          orderDetail: request.order?.toJson(),
        ),
      ),
    ).then((_) {
      _fetchDriverRequests(isRefresh: true);
    });
  }

  Future<void> _loadMoreRequests() async {
    if (_isLoadingMore || _currentPage >= _totalPages || !_isAuthenticated)
      return;
    _currentPage++;
    await _fetchDriverRequests();
  }

// ===== UI BUILDERS =====

  Widget _buildRequestCard(DriverRequestModel request, int index) {
    final order = request.order;
    if (order == null) return const SizedBox.shrink();

    final orderDate = request.createdAt;
    final formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(orderDate);
    final orderStatus = order.orderStatus;
    final statusColor = orderStatus.color;
    final statusText = orderStatus.displayName;
    final customerName = order.customer?.name ?? 'Unknown Customer';
    final customerAvatar = order.customer?.avatar ?? '';
    final totalItems = order.totalItems;
    final driverEarnings = request.driverEarnings;

    final animationIndex = index < _cardAnimations.length ? index : 0;

    return SlideTransition(
      position: _cardAnimations[animationIndex],
      child: Card(
        elevation: 3,
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        color: Colors.white,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () => _navigateToDetail(request),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Order #${request.orderId}',
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
                const SizedBox(height: 12),

                // Customer info
                Row(
                  children: [
                    _buildAvatar(customerAvatar, Icons.person),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customerName,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formattedDate,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ✅ PERBAIKAN: Store info dengan nama dari API berdasarkan store ID
                Row(
                  children: [
                    _buildAvatar(order.store?.imageUrl, Icons.store),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ✅ FIX: Future builder untuk nama toko dari store ID
                          FutureBuilder<String>(
                            future: _getStoreName(
                                order.storeId), // ✅ Ambil nama dari store ID
                            builder: (context, snapshot) {
                              final storeName = snapshot.data ??
                                  (order.store?.name ?? 'Loading...');
                              return Text(
                                storeName,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[800],
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$totalItems item',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Bottom section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Pesanan',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          order.formatTotalAmount(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: GlobalStyle.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    if (driverEarnings > 0)
                      _buildEarningsChip(driverEarnings)
                    else
                      _buildDetailButton(), // ✅ PERBAIKAN: Tombol hijau
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String? imageUrl, IconData fallbackIcon) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: GlobalStyle.lightColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: imageUrl != null && imageUrl.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Icon(
                  fallbackIcon,
                  color: GlobalStyle.primaryColor,
                  size: 28,
                ),
              ),
            )
          : Icon(
              fallbackIcon,
              color: GlobalStyle.primaryColor,
              size: 28,
            ),
    );
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

  Widget _buildEarningsChip(double earnings) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            'Penghasilan',
            style: TextStyle(
              fontSize: 12,
              color: Colors.green[700],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            GlobalStyle.formatRupiah(earnings),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.green[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green, // ✅ CHANGE: Hijau, bukan abu-abu
            Colors.green.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3), // ✅ CHANGE: Shadow hijau
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        'Lihat Detail',
        style: TextStyle(
          color: Colors.white, // ✅ CHANGE: Text putih untuk kontras
          fontWeight: FontWeight.w600,
          fontSize: 14,
          fontFamily: GlobalStyle.fontFamily,
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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
            'Belum ada riwayat pesanan',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _fetchDriverRequests(isRefresh: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: GlobalStyle.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Refresh'),
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
          CircularProgressIndicator(color: GlobalStyle.primaryColor),
          const SizedBox(height: 16),
          Text(
            'Memuat riwayat pesanan...',
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

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 64),
          const SizedBox(height: 16),
          Text(
            'Gagal memuat riwayat pesanan',
            style: TextStyle(
              color: GlobalStyle.fontColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage,
              style: TextStyle(
                color: GlobalStyle.fontColor.withOpacity(0.7),
                fontSize: 14,
                fontFamily: GlobalStyle.fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              if (!_isAuthenticated) {
                _initializeAuthentication();
              } else {
                _fetchDriverRequests(isRefresh: true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: GlobalStyle.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              !_isAuthenticated ? 'Login Ulang' : 'Coba Lagi',
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Riwayat Pesanan',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: GlobalStyle.primaryColor),
            onPressed: () => _fetchDriverRequests(isRefresh: true),
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
          tabs: _tabs.map((tab) => Tab(text: tab['label'])).toList(),
        ),
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _hasError
              ? _buildErrorState()
              : TabBarView(
                  controller: _tabController,
                  children: List.generate(_tabs.length, (tabIndex) {
                    final filteredRequests = getFilteredRequests(tabIndex);

                    if (filteredRequests.isEmpty) {
                      return _buildEmptyState(
                          'Tidak ada pesanan ${_tabs[tabIndex]['label'].toLowerCase()}');
                    }

                    return RefreshIndicator(
                      onRefresh: () => _fetchDriverRequests(isRefresh: true),
                      color: GlobalStyle.primaryColor,
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (ScrollNotification scrollInfo) {
                          if (scrollInfo.metrics.pixels ==
                              scrollInfo.metrics.maxScrollExtent) {
                            _loadMoreRequests();
                          }
                          return false;
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredRequests.length +
                              (_isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == filteredRequests.length) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            return _buildRequestCard(
                                filteredRequests[index], index);
                          },
                        ),
                      ),
                    );
                  }),
                ),
      bottomNavigationBar: DriverBottomNavigation(
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
