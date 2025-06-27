import 'dart:async';
import 'dart:isolate';
import 'package:del_pick/Models/store.dart';
import 'package:del_pick/Models/menu_item.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Views/Customers/cart_screen.dart';
import 'package:lottie/lottie.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:del_pick/Services/menu_service.dart';
import 'package:del_pick/Services/store_service.dart';
import 'package:del_pick/Services/auth_service.dart';
import 'package:del_pick/Services/image_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

// Ultra-Optimized Cache System
class _CacheManager {
  static final Map<String, dynamic> _storeCache = {};
  static final Map<String, List<MenuItemModel>> _menuCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 5);

  static bool _isCacheValid(String key) {
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null) return false;
    return DateTime.now().difference(timestamp) < _cacheExpiry;
  }

  static void cacheStore(String storeId, StoreModel store) {
    _storeCache[storeId] = store;
    _cacheTimestamps['store_$storeId'] = DateTime.now();
  }

  static StoreModel? getCachedStore(String storeId) {
    if (_isCacheValid('store_$storeId')) {
      return _storeCache[storeId];
    }
    return null;
  }

  static void cacheMenuItems(String storeId, List<MenuItemModel> items) {
    _menuCache[storeId] = items;
    _cacheTimestamps['menu_$storeId'] = DateTime.now();
  }

  static List<MenuItemModel>? getCachedMenuItems(String storeId) {
    if (_isCacheValid('menu_$storeId')) {
      return _menuCache[storeId];
    }
    return null;
  }

  static void clearExpiredCache() {
    final now = DateTime.now();
    final expiredKeys = _cacheTimestamps.entries
        .where((entry) => now.difference(entry.value) >= _cacheExpiry)
        .map((entry) => entry.key)
        .toList();

    for (final key in expiredKeys) {
      _cacheTimestamps.remove(key);
      if (key.startsWith('store_')) {
        _storeCache.remove(key.substring(6));
      } else if (key.startsWith('menu_')) {
        _menuCache.remove(key.substring(5));
      }
    }
  }
}

// Background Processing for Heavy Operations
class _BackgroundProcessor {
  static Future<double?> calculateDistanceInBackground({
    required double userLat,
    required double userLng,
    required double storeLat,
    required double storeLng,
  }) async {
    return await Isolate.run(() {
      final distanceInMeters = Geolocator.distanceBetween(
        userLat, userLng, storeLat, storeLng,
      );
      return distanceInMeters / 1000; // Convert to km
    });
  }

  static Future<Position?> getCurrentLocationInBackground() async {
    try {
      var status = await Permission.location.status;
      if (!status.isGranted) {
        status = await Permission.location.request();
        if (!status.isGranted) return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      return null;
    }
  }
}

class StoreDetail extends StatefulWidget {
  static const String route = "/Customers/StoreDetail";
  final List<MenuItemModel>? sharedMenuItems;

  const StoreDetail({super.key, this.sharedMenuItems});

  @override
  State<StoreDetail> createState() => _StoreDetailState();
}

class _StoreDetailState extends State<StoreDetail>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {

  // Core Data
  List<MenuItemModel> _menuItems = [];
  List<MenuItemModel> _filteredItems = [];
  StoreModel? _storeDetail;
  int? _storeId;

  // UI Controllers - Optimized with late initialization
  late PageController _pageController;
  late Timer _timer;
  late AnimationController _cartAnimationController;
  late Animation<double> _cartAnimation;
  late TextEditingController _searchController;
  late FocusNode _searchFocusNode;
  late AudioPlayer _audioPlayer;

  // State Management - Optimized with ValueNotifiers for specific updates
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier(true);
  final ValueNotifier<bool> _isLoadingMenuNotifier = ValueNotifier(true);
  final ValueNotifier<bool> _isLoadingLocationNotifier = ValueNotifier(true);
  final ValueNotifier<String> _errorNotifier = ValueNotifier('');
  final ValueNotifier<int> _currentPageNotifier = ValueNotifier(0);
  final ValueNotifier<bool> _isSearchingNotifier = ValueNotifier(false);

  // Location & Distance - Background processed
  Position? _currentPosition;
  double? _storeDistance;

  // Cart Management - Optimized with efficient data structures
  final Map<int, int> _itemQuantities = {};
  final Map<int, int> _originalStockMap = {};
  MenuItemModel? _lastAddedItem;

  // Performance Flags
  bool _initialLoadComplete = false;
  bool _disposed = false;

  @override
  bool get wantKeepAlive => true;

  // Ultra-Fast Initialization
  @override
  void initState() {
    super.initState();
    _initializeControllersEfficiently();
    _startBackgroundCacheCleanup();
  }

  void _initializeControllersEfficiently() {
    // Batch initialize all controllers
    _pageController = PageController(viewportFraction: 0.8, initialPage: 0);
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    _audioPlayer = AudioPlayer();

    _cartAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _cartAnimation = CurvedAnimation(
      parent: _cartAnimationController,
      curve: Curves.easeInOut,
    );

    // Optimized search listener with debouncing
    Timer? searchDebounce;
    _searchController.addListener(() {
      searchDebounce?.cancel();
      searchDebounce = Timer(const Duration(milliseconds: 300), () {
        _performSearchOptimized();
      });
    });

    _startAutoScrollOptimized();
  }

  void _startBackgroundCacheCleanup() {
    Timer.periodic(const Duration(minutes: 1), (timer) {
      if (_disposed) {
        timer.cancel();
        return;
      }
      _CacheManager.clearExpiredCache();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_storeId != null || _initialLoadComplete) return;

    _storeId = _extractStoreIdOptimized();
    if (_storeId != null && _storeId! > 0) {
      _loadDataInParallel();
    } else {
      _errorNotifier.value = 'Invalid store ID. Please ensure you are navigating from a valid store.';
      _isLoadingNotifier.value = false;
    }
  }

  // Ultra-Fast Store ID Extraction
  int? _extractStoreIdOptimized() {
    final arguments = ModalRoute.of(context)?.settings.arguments;
    if (arguments == null) return null;

    // Fast type-based extraction
    return switch (arguments.runtimeType) {
      int => arguments as int,
      String => int.tryParse(arguments as String),
      _ => _extractFromComplexArgument(arguments),
    };
  }

  int? _extractFromComplexArgument(dynamic arguments) {
    if (arguments is! Map) {
      try {
        return arguments.id as int?;
      } catch (e) {
        return null;
      }
    }

    final map = arguments as Map;

    // Priority order extraction
    final candidates = ['storeId', 'id'];
    for (final key in candidates) {
      final value = map[key];
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
    }

    // Handle nested store object
    final store = map['store'];
    if (store != null) {
      try {
        return store.id ?? store['id'];
      } catch (e) {
        return null;
      }
    }

    return null;
  }

  // Parallel Data Loading - Maximum Performance
  Future<void> _loadDataInParallel() async {
    final storeIdStr = _storeId.toString();

    // Start all operations in parallel
    final futures = await Future.wait([
      _loadStoreDataOptimized(storeIdStr),
      _loadMenuItemsOptimized(storeIdStr),
      _loadLocationInBackground(),
    ], eagerError: false);

    _isLoadingNotifier.value = false;
    _initialLoadComplete = true;

    // Calculate distance if both location and store data are available
    if (_currentPosition != null && _storeDetail != null) {
      _calculateDistanceInBackground();
    }
  }

  // Ultra-Fast Store Data Loading with Caching
  Future<void> _loadStoreDataOptimized(String storeId) async {
    try {
      // Check cache first
      final cachedStore = _CacheManager.getCachedStore(storeId);
      if (cachedStore != null) {
        _storeDetail = cachedStore;
        return;
      }

      // Parallel authentication check
      final authFuture = AuthService.isAuthenticated();
      final storeResponseFuture = StoreService.getStoreById(storeId);

      final results = await Future.wait([authFuture, storeResponseFuture]);
      final isAuthenticated = results[0] as bool;
      final storeResponse = results[1] as Map<String, dynamic>;

      if (!isAuthenticated) {
        throw Exception('User not authenticated');
      }

      if (storeResponse['success'] == false) {
        throw Exception(storeResponse['error'] ?? 'Store not found');
      }

      final storeData = storeResponse['data'];
      if (storeData == null || storeData.isEmpty) {
        throw Exception('Store data is empty');
      }

      final storeDetail = StoreModel.fromJson(storeData);
      _storeDetail = storeDetail;

      // Cache the result
      _CacheManager.cacheStore(storeId, storeDetail);

    } catch (e) {
      _errorNotifier.value = 'Failed to load store details: $e';
    }
  }

  // Ultra-Fast Menu Loading with Caching
  Future<void> _loadMenuItemsOptimized(String storeId) async {
    try {
      // Check cache first
      final cachedItems = _CacheManager.getCachedMenuItems(storeId);
      if (cachedItems != null) {
        _setMenuItemsOptimized(cachedItems);
        return;
      }

      final menuResponse = await MenuItemService.getMenuItemsByStore(
        storeId: storeId,
        page: 1,
        limit: 100,
        isAvailable: null,
        sortBy: 'name',
        sortOrder: 'asc',
      );

      if (menuResponse['success'] == false) {
        throw Exception(menuResponse['error'] ?? 'Failed to load menu items');
      }

      final fetchedMenuItems = <MenuItemModel>[];
      final menuItemsData = menuResponse['data'] as List? ?? [];

      // Batch process menu items
      for (var itemData in menuItemsData) {
        if (itemData is Map<String, dynamic>) {
          try {
            final menuItem = MenuItemModel.fromJson(itemData);
            fetchedMenuItems.add(menuItem);
          } catch (e) {
            // Skip invalid items but continue processing
            continue;
          }
        }
      }

      // Cache the result
      _CacheManager.cacheMenuItems(storeId, fetchedMenuItems);
      _setMenuItemsOptimized(fetchedMenuItems);

    } catch (e) {
      _errorNotifier.value = 'Failed to load menu items: $e';
      _isLoadingMenuNotifier.value = false;
    }
  }

  void _setMenuItemsOptimized(List<MenuItemModel> items) {
    _menuItems = items;
    _filteredItems = items;

    // Batch initialize quantities and stock
    for (var item in items) {
      _originalStockMap[item.id] = 10; // Default stock
      _itemQuantities[item.id] = 0; // Initialize cart quantity
    }

    _isLoadingMenuNotifier.value = false;
  }

  // Background Location Processing
  Future<void> _loadLocationInBackground() async {
    _currentPosition = await _BackgroundProcessor.getCurrentLocationInBackground();
    _isLoadingLocationNotifier.value = false;
  }

  // Background Distance Calculation
  Future<void> _calculateDistanceInBackground() async {
    if (_currentPosition == null ||
        _storeDetail?.latitude == null ||
        _storeDetail?.longitude == null) {
      return;
    }

    final distance = await _BackgroundProcessor.calculateDistanceInBackground(
      userLat: _currentPosition!.latitude,
      userLng: _currentPosition!.longitude,
      storeLat: _storeDetail!.latitude!,
      storeLng: _storeDetail!.longitude!,
    );

    if (!_disposed && mounted) {
      setState(() {
        _storeDistance = distance;
      });
    }
  }

  // Optimized Search with Minimal Rebuilds
  void _performSearchOptimized() {
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      _filteredItems = List<MenuItemModel>.from(_menuItems);
    } else {
      _filteredItems = _menuItems.where((item) =>
      item.name.toLowerCase().contains(query) ||
          (item.description.isNotEmpty && item.description.toLowerCase().contains(query))
      ).toList();
    }

    // Only rebuild affected widgets
    setState(() {});
  }

  // Optimized Auto Scroll
  void _startAutoScrollOptimized() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_disposed || _filteredItems.isEmpty || !_pageController.hasClients) {
        return;
      }

      final nextPage = (_currentPageNotifier.value + 1) % _filteredItems.length;
      _currentPageNotifier.value = nextPage;

      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  // Optimized Cart Operations
  void _addItemToCartOptimized(MenuItemModel item) {
    if (!item.isAvailable || _getRemainingStock(item) <= 0) {
      _showAppropriateDialog(item);
      return;
    }

    _itemQuantities[item.id] = (_itemQuantities[item.id] ?? 0) + 1;
    _lastAddedItem = item;

    _playSuccessSound();
    _cartAnimationController.reset();
    _cartAnimationController.forward();

    setState(() {}); // Minimal rebuild
  }

  void _showAppropriateDialog(MenuItemModel item) {
    if (!item.isAvailable) {
      _showItemUnavailableDialog();
    } else if (_getRemainingStock(item) <= 0) {
      _showOutOfStockDialog();
    }
  }

  void _playSuccessSound() {
    _audioPlayer.play(AssetSource('audio/kring.mp3')).catchError((e) {
      // Silent fail for audio
    });
  }

  // Efficient Quantity Management
  int _getRemainingStock(MenuItemModel item) {
    final originalStock = _originalStockMap[item.id] ?? 10;
    final cartQuantity = _itemQuantities[item.id] ?? 0;
    return originalStock - cartQuantity;
  }

  int _getItemQuantity(MenuItemModel item) => _itemQuantities[item.id] ?? 0;

  void _incrementItem(MenuItemModel item) {
    if (!item.isAvailable || _getRemainingStock(item) <= 0) {
      _showAppropriateDialog(item);
      return;
    }
    _addItemToCartOptimized(item);
  }

  void _decrementItem(MenuItemModel item) {
    final currentQuantity = _itemQuantities[item.id] ?? 0;
    if (currentQuantity > 0) {
      _itemQuantities[item.id] = currentQuantity - 1;
      if (currentQuantity - 1 == 0 && _lastAddedItem?.id == item.id) {
        _lastAddedItem = null;
      }
      setState(() {});
    }
  }

  // Efficient Distance Formatting
  String _getFormattedDistance() {
    final distance = _storeDistance;
    if (distance == null) return "-- KM";

    return distance < 1
        ? "${(distance * 1000).toInt()} m"
        : "${distance.toStringAsFixed(1)} km";
  }

  // Efficient Cart Calculations
  bool get hasItemsInCart => _itemQuantities.values.any((qty) => qty > 0);
  int get totalItems => _itemQuantities.values.fold(0, (sum, qty) => sum + qty);
  double get totalPrice {
    double total = 0;
    for (var item in _menuItems) {
      total += item.price * (_itemQuantities[item.id] ?? 0);
    }
    return total;
  }

  @override
  void dispose() {
    _disposed = true;

    // Efficient cleanup
    _pageController.dispose();
    _timer.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _audioPlayer.dispose();
    _cartAnimationController.dispose();

    // Dispose ValueNotifiers
    _isLoadingNotifier.dispose();
    _isLoadingMenuNotifier.dispose();
    _isLoadingLocationNotifier.dispose();
    _errorNotifier.dispose();
    _currentPageNotifier.dispose();
    _isSearchingNotifier.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return ValueListenableBuilder<bool>(
      valueListenable: _isLoadingNotifier,
      builder: (context, isLoading, _) {
        if (isLoading) {
          return _buildLoadingScreen();
        }

        return ValueListenableBuilder<String>(
          valueListenable: _errorNotifier,
          builder: (context, error, _) {
            if (error.isNotEmpty) {
              return _buildErrorScreen(error);
            }

            if (_storeDetail == null) {
              return _buildLoadingScreen();
            }

            return _buildMainContent();
          },
        );
      },
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: GlobalStyle.primaryColor),
            const SizedBox(height: 16),
            Text(
              'Memuat detail toko...',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
                fontFamily: GlobalStyle.fontFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen(String error) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Error'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                if (_storeId != null) {
                  _errorNotifier.value = '';
                  _isLoadingNotifier.value = true;
                  _loadDataInParallel();
                } else {
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: GlobalStyle.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Coba Lagi'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kembali'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Scaffold(
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                _buildHeader(),
                _buildStoreInfo(),
                ValueListenableBuilder<bool>(
                  valueListenable: _isLoadingMenuNotifier,
                  builder: (context, isLoadingMenu, _) {
                    if (!isLoadingMenu && _filteredItems.isNotEmpty) {
                      return _buildCarouselMenu();
                    }
                    return const SizedBox.shrink();
                  },
                ),
                _buildListMenu(),
                if (hasItemsInCart) const SizedBox(height: 120),
              ],
            ),
          ),
          if (hasItemsInCart) _buildCartSummary(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      children: [
        // Store banner image with optimized loading
        SizedBox(
          width: double.infinity,
          height: 230,
          child: _storeDetail!.imageUrl != null && _storeDetail!.imageUrl!.isNotEmpty
              ? ImageService.displayImage(
            imageSource: _storeDetail!.imageUrl!,
            width: double.infinity,
            height: 230,
            fit: BoxFit.cover,
            placeholder: _buildImagePlaceholder(),
          )
              : _buildImagePlaceholder(),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
            child: Row(
              children: [
                _buildBackButton(),
                const SizedBox(width: 12),
                Expanded(child: _buildSearchBar()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: double.infinity,
      height: 230,
      color: Colors.grey[300],
      child: const Center(
        child: Icon(Icons.store, size: 80, color: Colors.grey),
      ),
    );
  }

  Widget _buildBackButton() {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(24),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => Navigator.pop(context),
        child: Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(24)),
          child: Icon(
            Icons.arrow_back_ios_new,
            color: GlobalStyle.primaryColor,
            size: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(24),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          _isSearchingNotifier.value = true;
          FocusScope.of(context).requestFocus(_searchFocusNode);
        },
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(Icons.search, color: GlobalStyle.primaryColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  decoration: const InputDecoration(
                    hintText: 'Cari menu...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 14),
                  onTap: () => _isSearchingNotifier.value = true,
                ),
              ),
              if (_searchController.text.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    _filteredItems = List<MenuItemModel>.from(_menuItems);
                    setState(() {});
                  },
                  child: const Icon(Icons.close, color: Colors.grey, size: 18),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStoreInfo() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      transform: Matrix4.translationValues(0, -30, 0),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              _storeDetail!.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _storeDetail!.address,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            Text(
              'Buka: ${_storeDetail!.openTime} - ${_storeDetail!.closeTime}',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      const FaIcon(FontAwesomeIcons.locationDot,
                          color: Colors.blue, size: 16),
                      const SizedBox(width: 4),
                      ValueListenableBuilder<bool>(
                        valueListenable: _isLoadingLocationNotifier,
                        builder: (context, isLoadingLocation, _) {
                          return isLoadingLocation
                              ? SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.grey[400],
                            ),
                          )
                              : Text(
                            _getFormattedDistance(),
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 14),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(width: 24),
                  Row(
                    children: [
                      const FaIcon(FontAwesomeIcons.star,
                          color: Colors.blue, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        _storeDetail!.rating.toStringAsFixed(1),
                        style: const TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarouselMenu() {
    return SizedBox(
      height: 300,
      child: ValueListenableBuilder<int>(
        valueListenable: _currentPageNotifier,
        builder: (context, currentPage, _) {
          return PageView.builder(
            controller: _pageController,
            itemCount: _filteredItems.length,
            onPageChanged: (index) => _currentPageNotifier.value = index,
            itemBuilder: (context, index) {
              final item = _filteredItems[index];
              return GestureDetector(
                onTap: () => item.isAvailable
                    ? _showItemDetail(item)
                    : _showItemUnavailableDialog(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Opacity(
                    opacity: item.isAvailable ? 1.0 : 0.5,
                    child: _buildCarouselMenuItem(item),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCarouselMenuItem(MenuItemModel item) {
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                spreadRadius: 1,
                blurRadius: 6,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Container(
                    width: double.infinity,
                    color: Colors.white,
                    child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                        ? ImageService.displayImage(
                      imageSource: item.imageUrl!,
                      fit: BoxFit.contain,
                      placeholder: _buildMenuItemPlaceholder(),
                    )
                        : _buildMenuItemPlaceholder(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.formatPrice(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: GlobalStyle.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.name,
                      style: const TextStyle(fontSize: 14, color: Colors.black87),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 14,
                          color: _getRemainingStock(item) > 0 ? Colors.grey : Colors.red,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Stok: ${_getRemainingStock(item)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: _getRemainingStock(item) > 0 ? Colors.grey : Colors.red,
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
        if (!item.isAvailable) _buildUnavailableBadge(),
      ],
    );
  }

  Widget _buildMenuItemPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Icon(Icons.restaurant_menu, size: 40, color: Colors.grey),
      ),
    );
  }

  Widget _buildUnavailableBadge() {
    return Positioned(
      top: 10,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.8),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(12),
            bottomLeft: Radius.circular(12),
          ),
        ),
        child: const Text(
          'TUTUP',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildListMenu() {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMenuHeader(),
          const SizedBox(height: 2),
          ValueListenableBuilder<bool>(
            valueListenable: _isLoadingMenuNotifier,
            builder: (context, isLoadingMenu, _) {
              if (isLoadingMenu) {
                return _buildMenuLoadingState();
              } else if (_filteredItems.isEmpty) {
                return _buildEmptyMenuState();
              } else {
                return _buildMenuList();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuHeader() {
    return _searchController.text.isNotEmpty
        ? Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        "Hasil pencarian: ${_filteredItems.length} items",
        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
      ),
    )
        : const Text(
      "Menu",
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildMenuLoadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Column(
          children: [
            CircularProgressIndicator(color: GlobalStyle.primaryColor),
            const SizedBox(height: 16),
            Text(
              'Memuat menu...',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyMenuState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Column(
          children: [
            Icon(Icons.restaurant_menu, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isNotEmpty
                  ? 'Tidak ada menu yang sesuai dengan pencarian'
                  : 'Tidak ada menu tersedia',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredItems.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildListMenuItem(_filteredItems[index]),
        );
      },
    );
  }

  Widget _buildListMenuItem(MenuItemModel item) {
    final itemQuantity = _getItemQuantity(item);

    return Opacity(
      opacity: item.isAvailable ? 1.0 : 0.5,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 6,
            ),
          ],
        ),
        child: Stack(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: () => item.isAvailable
                        ? _showItemDetail(item)
                        : _showItemUnavailableDialog(),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 14,
                                color: _getRemainingStock(item) > 0 ? Colors.grey : Colors.red,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Stok: ${_getRemainingStock(item)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _getRemainingStock(item) > 0 ? Colors.grey : Colors.red,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.formatPrice(),
                            style: TextStyle(
                              fontSize: 16,
                              color: GlobalStyle.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: GestureDetector(
                    onTap: () => item.isAvailable
                        ? _showItemDetail(item)
                        : _showItemUnavailableDialog(),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
                      child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                          ? ImageService.displayImage(
                        imageSource: item.imageUrl!,
                        height: 140,
                        fit: BoxFit.cover,
                        placeholder: _buildListItemPlaceholder(),
                      )
                          : _buildListItemPlaceholder(),
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              bottom: 10,
              right: 20,
              child: itemQuantity > 0
                  ? _buildQuantityControl(item)
                  : _buildAddButton(item),
            ),
            if (!item.isAvailable) _buildUnavailableBadge(),
            if (item.isAvailable && _getRemainingStock(item) <= 0) _buildOutOfStockBadge(),
          ],
        ),
      ),
    );
  }

  Widget _buildListItemPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Icon(Icons.restaurant_menu, size: 30, color: Colors.grey),
      ),
    );
  }

  Widget _buildOutOfStockBadge() {
    return Positioned(
      top: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.8),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(12),
            bottomLeft: Radius.circular(12),
          ),
        ),
        child: const Text(
          'STOK HABIS',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildAddButton(MenuItemModel item) {
    final bool hasStock = _getRemainingStock(item) > 0;

    return SizedBox(
      height: 30,
      width: 90,
      child: ElevatedButton(
        onPressed: (item.isAvailable && hasStock) ? () => _addItemToCartOptimized(item) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: (item.isAvailable && hasStock) ? GlobalStyle.primaryColor : Colors.grey,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          elevation: 3,
        ),
        child: const Text(
          'Tambah',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildQuantityControl(MenuItemModel item) {
    final bool hasStock = _getRemainingStock(item) > 0;
    final itemQuantity = _getItemQuantity(item);

    return Container(
      height: 30,
      decoration: BoxDecoration(
        color: item.isAvailable ? GlobalStyle.primaryColor : Colors.grey,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => _decrementItem(item),
            child: Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              child: const Icon(Icons.remove, color: Colors.white, size: 16),
            ),
          ),
          Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '$itemQuantity',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          InkWell(
            onTap: (item.isAvailable && hasStock) ? () => _incrementItem(item) : null,
            child: Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              child: const Icon(Icons.add, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartSummary() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_lastAddedItem != null) _buildLastAddedItemIndicator(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$totalItems items',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  GlobalStyle.formatRupiah(totalPrice),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: GlobalStyle.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _navigateToCart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlobalStyle.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shopping_cart, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Tampilkan Pesanan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLastAddedItemIndicator() {
    return FadeTransition(
      opacity: _cartAnimation,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[700], size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _lastAddedItem!.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _lastAddedItem!.formatPrice(),
                    style: TextStyle(color: GlobalStyle.primaryColor, fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              "x${_getItemQuantity(_lastAddedItem!)}",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToCart() {
    final cartItems = _menuItems.where((item) => _getItemQuantity(item) > 0).toList();

    if (_storeId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CartScreen(
            cartItems: cartItems,
            storeId: _storeId!,
            itemQuantities: Map<int, int>.from(_itemQuantities),
            customerLatitude: _currentPosition?.latitude,
            customerLongitude: _currentPosition?.longitude,
            customerAddress: null,
            storeLatitude: _storeDetail?.latitude,
            storeLongitude: _storeDetail?.longitude,
            storeDistance: _storeDistance,
          ),
        ),
      );
    }
  }

  // Dialog Methods - Optimized for minimal rebuild
  void _showItemDetail(MenuItemModel item) {
    if (!item.isAvailable) {
      _showItemUnavailableDialog();
      return;
    }

    final initialQuantity = _getItemQuantity(item);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableItemDetail(
        item: item,
        availableStock: _getRemainingStock(item),
        initialQuantity: initialQuantity,
        onQuantityChanged: (int quantity) {
          if (quantity != initialQuantity) {
            _itemQuantities[item.id] = quantity;
            if (quantity > initialQuantity) {
              _addItemToCartOptimized(item);
            } else {
              setState(() {});
            }
          }
        },
        onZeroQuantity: _showZeroQuantityDialog,
        onOutOfStock: _showOutOfStockDialog,
      ),
    );
  }

  void _showZeroQuantityDialog() {
    _audioPlayer.play(AssetSource('audio/wrong.mp3')).catchError((e) {});
    _showSimpleDialog(
      'Pilih jumlah item terlebih dahulu',
      'assets/animations/caution.json',
    );
  }

  void _showOutOfStockDialog() {
    _audioPlayer.play(AssetSource('audio/wrong.mp3')).catchError((e) {});
    _showSimpleDialog(
      'Stok item tidak mencukupi\nMohon kurangi jumlah pesanan atau pilih item lain',
      'assets/animations/caution.json',
    );
  }

  void _showItemUnavailableDialog() {
    _audioPlayer.play(AssetSource('audio/wrong.mp3')).catchError((e) {});
    _showSimpleDialog(
      'Item ini sedang tidak tersedia\nMohon pilih item lain yang tersedia',
      'assets/animations/caution.json',
    );
  }

  void _showSimpleDialog(String message, String animationPath) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(animationPath, height: 200, width: 200, fit: BoxFit.contain),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GlobalStyle.primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Mengerti',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Optimized DraggableItemDetail with minimal changes
class DraggableItemDetail extends StatefulWidget {
  final MenuItemModel item;
  final int availableStock;
  final int initialQuantity;
  final Function(int) onQuantityChanged;
  final VoidCallback onZeroQuantity;
  final VoidCallback onOutOfStock;

  const DraggableItemDetail({
    Key? key,
    required this.item,
    required this.availableStock,
    required this.initialQuantity,
    required this.onQuantityChanged,
    required this.onZeroQuantity,
    required this.onOutOfStock,
  }) : super(key: key);

  @override
  State<DraggableItemDetail> createState() => _DraggableItemDetailState();
}

class _DraggableItemDetailState extends State<DraggableItemDetail> {
  late int _quantity;

  @override
  void initState() {
    super.initState();
    _quantity = widget.initialQuantity;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.2,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: widget.item.imageUrl != null && widget.item.imageUrl!.isNotEmpty
                              ? ImageService.displayImage(
                            imageSource: widget.item.imageUrl!,
                            fit: BoxFit.contain,
                            placeholder: Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child: Icon(Icons.restaurant_menu, size: 60, color: Colors.grey),
                              ),
                            ),
                          )
                              : Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: Icon(Icons.restaurant_menu, size: 60, color: Colors.grey),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.item.name,
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: widget.availableStock > 0
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: 14,
                                  color: widget.availableStock > 0 ? Colors.green : Colors.red,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Stok: ${widget.availableStock}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: widget.availableStock > 0 ? Colors.green : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.item.formatPrice(),
                        style: TextStyle(
                          fontSize: 18,
                          color: GlobalStyle.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Deskripsi',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.item.description.isNotEmpty
                            ? widget.item.description
                            : 'Tidak ada deskripsi tersedia untuk produk ini.',
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: _quantity > 0 ? () => setState(() => _quantity--) : null,
                            icon: const Icon(Icons.remove_circle_outline),
                            color: GlobalStyle.primaryColor,
                            iconSize: 32,
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              '$_quantity',
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              if (_quantity < widget.availableStock) {
                                setState(() => _quantity++);
                              } else {
                                widget.onOutOfStock();
                              }
                            },
                            icon: const Icon(Icons.add_circle_outline),
                            color: GlobalStyle.primaryColor,
                            iconSize: 32,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            if (_quantity > 0) {
                              widget.onQuantityChanged(_quantity);
                              Navigator.pop(context);
                            } else {
                              Navigator.pop(context);
                              widget.onZeroQuantity();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: GlobalStyle.primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text(
                            'Tambah ke keranjang',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
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
        );
      },
    );
  }
}