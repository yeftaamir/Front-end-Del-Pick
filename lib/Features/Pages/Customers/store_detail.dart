// lib/pages/customers/store_detail.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

// Import common
import '../../../Common/global_style.dart';
import '../../../Models/Entities/menu_item.dart';
import '../../../Models/Entities/store.dart';
import '../../../Models/Responses/order_responses.dart';
import '../../../Services/Customer/home_service.dart';
import '../../../Services/Customer/store_detail_service.dart';
import '../../../Services/Utils/error_handler.dart';

// Import models and services

// Import local services and widgets
import 'cart_screen.dart';
import 'widgets/store_detail_widgets.dart';
import 'widgets/draggable_item_detail.dart';

class StoreDetail extends StatefulWidget {
  static const String route = "/Customers/StoreDetail";
  final List<MenuItem>? sharedMenuItems;

  const StoreDetail({super.key, this.sharedMenuItems});

  @override
  State<StoreDetail> createState() => _StoreDetailState();
}

class _StoreDetailState extends State<StoreDetail> with SingleTickerProviderStateMixin {
  // Data variables
  Store? _store;
  List<MenuItem> _menuItems = [];
  List<MenuItem> _filteredMenuItems = [];
  Map<int, int> _originalStockMap = {};
  Map<int, int> _cartQuantities = {};
  Position? _currentPosition;
  double? _storeDistance;

  // UI state variables
  bool _isLoading = true;
  bool _isLoadingLocation = false;
  bool _isSearching = false;
  String _errorMessage = '';

  // Controllers and focus nodes
  final TextEditingController _searchController = TextEditingController();
  late PageController _pageController;
  late Timer _carouselTimer;
  int _currentCarouselPage = 0;

  // Animation controllers
  late AnimationController _cartAnimationController;
  late Animation<double> _cartAnimation;

  // Cart state
  MenuItem? _lastAddedItem;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _setupSearchListener();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadStoreData();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  // Initialize controllers and animations
  void _initializeControllers() {
    _pageController = PageController(viewportFraction: 0.8, initialPage: 0);

    _cartAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _cartAnimation = CurvedAnimation(
      parent: _cartAnimationController,
      curve: Curves.easeInOut,
    );
  }

  // Setup search listener
  void _setupSearchListener() {
    _searchController.addListener(() {
      _performSearch();
    });
  }

  // Dispose controllers
  void _disposeControllers() {
    _pageController.dispose();
    _carouselTimer.cancel();
    _searchController.dispose();
    _cartAnimationController.dispose();
  }

  // Load store data
  Future<void> _loadStoreData() async {
    final int storeId = ModalRoute.of(context)!.settings.arguments as int? ?? 0;

    if (storeId == 0) {
      setState(() {
        _errorMessage = 'Invalid store ID';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Load store details and menu items concurrently
      final results = await Future.wait([
        _loadStoreDetails(storeId),
        _loadMenuItems(storeId),
        _loadCurrentLocation(),
      ]);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _startCarouselAutoScroll();
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

  // Load store details
  Future<void> _loadStoreDetails(int storeId) async {
    try {
      final store = await StoreDetailService.getStoreById(storeId);

      if (mounted) {
        setState(() {
          _store = store;
        });
        _calculateDistance();
      }
    } catch (e) {
      throw Exception('Failed to load store details: ${ErrorHandler.handleError(e)}');
    }
  }

  // Load menu items
  Future<void> _loadMenuItems(int storeId) async {
    try {
      final menuItems = await StoreDetailService.getMenuItemsByStore(storeId);

      if (mounted) {
        setState(() {
          _menuItems = menuItems;
          _filteredMenuItems = menuItems;

          // Initialize stock map and cart quantities
          for (var item in menuItems) {
            _originalStockMap[item.id] = 10; // Default stock - replace with actual stock from API
            _cartQuantities[item.id] = 0;
          }
        });
      }
    } catch (e) {
      throw Exception('Failed to load menu items: ${ErrorHandler.handleError(e)}');
    }
  }

  // Load current location
  Future<void> _loadCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      final position = await HomeService.getCurrentLocation();

      if (mounted) {
        setState(() {
          _currentPosition = position;
          _isLoadingLocation = false;
        });
        _calculateDistance();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
  }

  // Calculate distance between user and store
  void _calculateDistance() {
    if (_store != null && _currentPosition != null) {
      final distance = StoreDetailService.calculateStoreDistance(_currentPosition, _store!);
      setState(() {
        _storeDistance = distance;
      });
    }
  }

  // Start carousel auto scroll
  void _startCarouselAutoScroll() {
    if (_filteredMenuItems.isEmpty) return;

    _carouselTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_filteredMenuItems.isEmpty) return;

      if (_currentCarouselPage < _filteredMenuItems.length - 1) {
        _currentCarouselPage++;
      } else {
        _currentCarouselPage = 0;
      }

      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentCarouselPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  // Perform search
  void _performSearch() {
    final query = _searchController.text.trim();

    final filteredItems = StoreDetailService.searchMenuItems(_menuItems, query);

    setState(() {
      _filteredMenuItems = filteredItems;
    });
  }

  // Cart management methods
  void _addItemToCart(MenuItem item) {
    final currentQuantity = _cartQuantities[item.id] ?? 0;
    final validation = StoreDetailService.validateItemForCart(
      item,
      currentQuantity,
      1,
      _originalStockMap,
    );

    if (!validation.isValid) {
      _handleValidationError(validation.errorType);
      return;
    }

    setState(() {
      _cartQuantities[item.id] = currentQuantity + 1;
      _lastAddedItem = item;
    });

    _showSuccessAnimation();
  }

  void _incrementItem(MenuItem item) {
    final currentQuantity = _cartQuantities[item.id] ?? 0;
    final validation = StoreDetailService.validateItemForCart(
      item,
      currentQuantity,
      1,
      _originalStockMap,
    );

    if (!validation.isValid) {
      _handleValidationError(validation.errorType);
      return;
    }

    setState(() {
      _cartQuantities[item.id] = currentQuantity + 1;
      _lastAddedItem = item;
    });

    _showSuccessAnimation();
  }

  void _decrementItem(MenuItem item) {
    final currentQuantity = _cartQuantities[item.id] ?? 0;

    if (currentQuantity > 0) {
      setState(() {
        _cartQuantities[item.id] = currentQuantity - 1;

        if (_cartQuantities[item.id] == 0 && _lastAddedItem?.id == item.id) {
          _lastAddedItem = null;
        }
      });
    }
  }

  // Handle validation errors
  void _handleValidationError(ItemErrorType errorType) {
    switch (errorType) {
      case ItemErrorType.unavailable:
        StoreDetailWidgets.showItemUnavailableDialog(context);
        break;
      case ItemErrorType.outOfStock:
        StoreDetailWidgets.showOutOfStockDialog(context);
        break;
      case ItemErrorType.zeroQuantity:
        StoreDetailWidgets.showZeroQuantityDialog(context);
        break;
      case ItemErrorType.none:
        break;
    }
  }

  // Show success animation
  void _showSuccessAnimation() {
    StoreDetailWidgets.showSuccessAnimation(context, _lastAddedItem!);
    _cartAnimationController.reset();
    _cartAnimationController.forward();
  }

  // Show item detail modal
  void _showItemDetail(MenuItem item) {
    if (!item.isAvailable) {
      StoreDetailWidgets.showItemUnavailableDialog(context);
      return;
    }

    final availableStock = _originalStockMap[item.id] ?? 0;
    final currentQuantity = _cartQuantities[item.id] ?? 0;
    final remainingStock = availableStock - currentQuantity;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableItemDetail(
        item: item,
        availableStock: remainingStock,
        onQuantityChanged: (int quantity) {
          setState(() {
            _cartQuantities[item.id] = quantity;
            if (quantity > 0) {
              _lastAddedItem = item;
              _showSuccessAnimation();
            }
          });
        },
        onZeroQuantity: () => StoreDetailWidgets.showZeroQuantityDialog(context),
        onOutOfStock: () => StoreDetailWidgets.showOutOfStockDialog(context),
      ),
    );
  }

  // Navigation methods
  void _onSearchFocused() {
    setState(() {
      _isSearching = true;
    });
  }

  void _onSearchCleared() {
    _searchController.clear();
    setState(() {
      _filteredMenuItems = _menuItems;
    });
  }

  void _navigateToCart() {
    final cartItems = _menuItems.where((item) {
      final quantity = _cartQuantities[item.id] ?? 0;
      return quantity > 0;
    }).toList();

    final int storeId = ModalRoute.of(context)!.settings.arguments as int? ?? 0;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CartScreen(
          store: _store!,
          cartItems: cartItems
              .map((item) => CartItem(
            menuItem: item,
            quantity: _cartQuantities[item.id] ?? 0,
          ))
              .toList(),
        ),
      ),
    );
  }

  // Calculate cart totals
  bool get _hasItemsInCart {
    return _cartQuantities.values.any((quantity) => quantity > 0);
  }

  int get _totalItems {
    return _cartQuantities.values.fold(0, (sum, quantity) => sum + quantity);
  }

  double get _totalPrice {
    double total = 0.0;
    for (var item in _menuItems) {
      final quantity = _cartQuantities[item.id] ?? 0;
      total += item.price * quantity;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? StoreDetailWidgets.buildLoadingState()
          : _errorMessage.isNotEmpty
          ? _buildErrorState()
          : _buildMainContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 80, color: Colors.red[400]),
          const SizedBox(height: 16),
          Text(
            'Gagal memuat data toko',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontFamily: GlobalStyle.fontFamily,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadStoreData,
            style: ElevatedButton.styleFrom(
              backgroundColor: GlobalStyle.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    if (_store == null) return const SizedBox.shrink();

    return Stack(
      children: [
        SingleChildScrollView(
          child: Column(
            children: [
              // Store header
              StoreDetailWidgets.buildStoreHeader(
                store: _store!,
                searchController: _searchController,
                onBackPressed: () => Navigator.pop(context),
                onSearchFocused: _onSearchFocused,
                onSearchCleared: _onSearchCleared,
              ),

              // Store info
              StoreDetailWidgets.buildStoreInfo(
                store: _store!,
                formattedDistance: StoreDetailService.formatDistance(_storeDistance),
                isLoadingLocation: _isLoadingLocation,
              ),

              // Carousel menu (only show if items available)
              if (_filteredMenuItems.isNotEmpty)
                StoreDetailWidgets.buildCarouselMenu(
                  menuItems: _filteredMenuItems,
                  pageController: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentCarouselPage = index;
                    });
                  },
                  onItemTapped: _showItemDetail,
                  originalStockMap: _originalStockMap,
                ),

              // Menu list
              StoreDetailWidgets.buildMenuList(
                menuItems: _filteredMenuItems,
                searchQuery: _searchController.text,
                onItemTapped: _showItemDetail,
                onAddToCart: _addItemToCart,
                onIncrement: _incrementItem,
                onDecrement: _decrementItem,
                originalStockMap: _originalStockMap,
                cartQuantities: _cartQuantities,
              ),

              // Bottom padding for cart summary
              if (_hasItemsInCart) const SizedBox(height: 120),
            ],
          ),
        ),

        // Cart summary
        if (_hasItemsInCart)
          StoreDetailWidgets.buildCartSummary(
            totalItems: _totalItems,
            totalPrice: _totalPrice,
            lastAddedItem: _lastAddedItem,
            cartAnimation: _cartAnimation,
            onViewCart: _navigateToCart,
          ),
      ],
    );
  }
}