// lib/pages/customers/home_page.dart
import 'package:del_pick/Features/Pages/Customers/store_detail.dart';
import 'package:del_pick/Models/Extensions/menu_item_extensions.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

// Import common
import '../../../Common/global_style.dart';
import '../../../Models/Entities/store.dart';
import '../../../Models/Entities/user.dart';
import '../../../Services/Customer/home_service.dart';
import '../../../Services/Utils/error_handler.dart';

// Import models and services

// Import local services and widgets
import '../Component/cust_bottom_navigation.dart';
import 'widgets/home_widgets.dart';
import 'profile_page.dart';

class HomePage extends StatefulWidget {
  static const String route = "/Customers/HomePage";
  const HomePage({super.key});

  @override
  createState() => HomePageState();
}

class HomePageState extends State<HomePage> with TickerProviderStateMixin {
  // State variables
  int _selectedIndex = 0;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Data variables
  List<Store> _stores = [];
  List<Store> _nearbyStores = [];
  List<Store> _featuredStores = [];
  Map<int, double> _storeDistances = {};
  User? _user;
  Position? _currentPosition;

  // Loading states
  bool _isLoading = true;
  bool _isLoadingLocation = false;
  String _errorMessage = '';

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;

  // Animations
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeData();
    _setupSearchListener();

    // Show promotional dialog
    WidgetsBinding.instance.addPostFrameCallback((_) {
      HomeWidgets.showPromotionalDialog(context);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  // Initialize animations
  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.elasticOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
    );

    // Start animations
    _fadeController.forward();
    _slideController.forward();
    _scaleController.forward();
  }

  // Setup search listener
  void _setupSearchListener() {
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  // Initialize data
  Future<void> _initializeData() async {
    await _loadUserProfile();
    await _loadLocationAndStores();
  }

  // Load user profile
  Future<void> _loadUserProfile() async {
    try {
      final user = await HomeService.getUserProfile();
      if (mounted) {
        setState(() {
          _user = user;
        });
      }
    } catch (e) {
      print('Error loading user profile: $e');
    }
  }

  // Load location and stores
  Future<void> _loadLocationAndStores() async {
    setState(() {
      _isLoadingLocation = true;
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Get user location
      final position = await HomeService.getCurrentLocation();

      if (mounted) {
        setState(() {
          _currentPosition = position;
          _isLoadingLocation = false;
        });
      }

      // Load stores with or without location
      if (position != null) {
        await _loadStoresWithLocation(position);
      } else {
        await _loadStoresWithoutLocation();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
          _errorMessage = ErrorHandler.handleError(e);
          _isLoading = false;
        });
      }
    }
  }

  // Load stores with location information
  Future<void> _loadStoresWithLocation(Position position) async {
    try {
      // Get stores with distance calculation
      final result = await HomeService.getStoresWithDistance(
        userPosition: position,
      );

      // Get nearby stores
      final nearbyStores = await HomeService.getNearbyStores(
        latitude: position.latitude,
        longitude: position.longitude,
        limit: 5,
      );

      // Get featured stores
      final featuredStores = await HomeService.getFeaturedStores(limit: 5);

      if (mounted) {
        setState(() {
          _stores = result.stores;
          _storeDistances = result.distances;
          _nearbyStores = nearbyStores;
          _featuredStores = featuredStores;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = ErrorHandler.handleError(e);
          _isLoading = false;
        });
      }
    }
  }

  // Load stores without location information
  Future<void> _loadStoresWithoutLocation() async {
    try {
      final stores = await HomeService.getAllStores();
      final featuredStores = await HomeService.getFeaturedStores(limit: 5);

      if (mounted) {
        setState(() {
          _stores = stores;
          _featuredStores = featuredStores;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = ErrorHandler.handleError(e);
          _isLoading = false;
        });
      }
    }
  }

  // Get filtered stores based on search query
  List<Store> get _filteredStores {
    if (_searchQuery.isEmpty && !_isSearching) {
      return _stores;
    }
    return HomeService.searchStores(_stores, _searchQuery);
  }

  // Navigation handlers
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      if (index == 1) {
        _startSearch();
      }
    });
  }

  void _startSearch() {
    setState(() {
      _isSearching = true;
    });
    _resetAnimations();
  }

  void _stopSearch() {
    setState(() {
      _isSearching = false;
      _searchController.clear();
      _searchQuery = '';
    });
  }

  void _resetAnimations() {
    _fadeController.reset();
    _slideController.reset();
    _scaleController.reset();
    _fadeController.forward();
    _slideController.forward();
    _scaleController.forward();
  }

  // Navigation to store detail
  void _navigateToStoreDetail(Store store) {
    Navigator.pushNamed(
      context,
      StoreDetail.route,
      arguments: store.id,
    );
  }

  // Navigation to profile
  void _navigateToProfile() {
    Navigator.pushNamed(context, ProfilePage.route);
  }

  // Refresh data
  Future<void> _refreshData() async {
    if (_currentPosition != null) {
      await _loadStoresWithLocation(_currentPosition!);
    } else {
      await _loadLocationAndStores();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffD6E6F2),
      appBar: HomeWidgets.buildSearchAppBar(
        isSearching: _isSearching,
        searchController: _searchController,
        userName: _user?.displayName,
        onSearchPressed: _startSearch,
        onBackPressed: _stopSearch,
        onProfilePressed: _navigateToProfile,
      ),
      body: _buildBody(),
      bottomNavigationBar: CustomBottomNavigation(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }

  // Build main body content
  Widget _buildBody() {
    return Column(
      children: [
        // Location loading indicator
        if (_isLoadingLocation && !_isLoading)
          HomeWidgets.buildLocationLoading(),

        // Main content
        Expanded(
          child: _buildMainContent(),
        ),
      ],
    );
  }

  // Build main content based on state
  Widget _buildMainContent() {
    // Empty search state
    if (_isSearching && _searchQuery.isEmpty) {
      return HomeWidgets.buildEmptySearchState();
    }

    // Loading state
    if (_isLoading) {
      return HomeWidgets.buildLoadingState();
    }

    // Error state
    if (_errorMessage.isNotEmpty) {
      return HomeWidgets.buildErrorState(
        message: _errorMessage,
        onRetry: _loadLocationAndStores,
      );
    }

    // Empty state
    if (_filteredStores.isEmpty) {
      return HomeWidgets.buildEmptyState();
    }

    // Content with refresh indicator
    return RefreshIndicator(
      onRefresh: _refreshData,
      color: GlobalStyle.primaryColor,
      child: CustomScrollView(
        slivers: [
          // Recommendations section (only show when not searching)
          if (!_isSearching) ...[
            SliverToBoxAdapter(
              child: HomeWidgets.buildRecommendationsCarousel(
                nearbyStores: _nearbyStores,
                featuredStores: _featuredStores,
                distances: _storeDistances,
                onStoreTap: _navigateToStoreDetail,
              ),
            ),

            // Section divider
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey[300])),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Semua Toko',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                          fontFamily: GlobalStyle.fontFamily,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey[300])),
                  ],
                ),
              ),
            ),
          ],

          // Store list
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final store = _filteredStores[index];
                  return AnimatedBuilder(
                    animation: _slideController,
                    builder: (context, child) {
                      final delay = index * 0.1;
                      final slideAnimation = Tween<Offset>(
                        begin: const Offset(1.0, 0.0),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: _slideController,
                          curve: Interval(
                            delay.clamp(0.0, 1.0),
                            (delay + 0.3).clamp(0.0, 1.0),
                            curve: Curves.easeOut,
                          ),
                        ),
                      );

                      return SlideTransition(
                        position: slideAnimation,
                        child: HomeWidgets.buildStoreCard(
                          store: store,
                          distance: _storeDistances[store.id],
                          onTap: () => _navigateToStoreDetail(store),
                          scaleAnimation: _scaleAnimation,
                          fadeAnimation: _fadeAnimation,
                        ),
                      );
                    },
                  );
                },
                childCount: _filteredStores.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}