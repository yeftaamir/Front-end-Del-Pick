import 'dart:async';
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
import 'package:del_pick/Services/image_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class StoreDetail extends StatefulWidget {
  static const String route = "/Customers/StoreDetail";
  final List<MenuItemModel>? sharedMenuItems;

  const StoreDetail({super.key, this.sharedMenuItems});

  @override
  State<StoreDetail> createState() => _StoreDetailState();
}

class _StoreDetailState extends State<StoreDetail> with SingleTickerProviderStateMixin {
  late List<MenuItemModel> menuItems = [];
  late List<MenuItemModel> filteredItems = [];
  // Map to track original item stock
  Map<int, int> originalStockMap = {};

  late PageController _pageController;
  late Timer _timer;
  int _currentPage = 0;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isLoading = true;
  bool _isLoadingLocation = true;
  bool _isLoadingMenuItems = true;
  Position? _currentPosition;
  double? _storeDistance;
  String _errorMessage = '';

  // Animation controller for cart summary
  late AnimationController _cartAnimationController;
  late Animation<double> _cartAnimation;

  // Recently added item to show in cart summary
  MenuItemModel? _lastAddedItem;

  StoreModel? _storeDetail;

  Future<void> fetchMenuItems(String storeId) async {
    setState(() {
      _isLoadingMenuItems = true;
      _errorMessage = '';
    });

    try {
      // Use the correct service method with proper parameters
      final menuResponse = await MenuItemService.getMenuItemsByStore(
        storeId: storeId,
        page: 1,
        limit: 100, // Get all menu items for the store
        isAvailable: null, // Get both available and unavailable items
        sortBy: 'name',
        sortOrder: 'asc',
      );

      // Extract menu items from response
      List<MenuItemModel> fetchedMenuItems = [];
      if (menuResponse['data'] != null) {
        final menuItemsData = menuResponse['data'] as List;
        fetchedMenuItems = menuItemsData
            .map((json) => MenuItemModel.fromJson(json))
            .toList();
      }

      setState(() {
        menuItems = fetchedMenuItems;
        filteredItems = fetchedMenuItems;

        // Store original stock quantities and initialize cart quantities
        for (var item in menuItems) {
          // Create a mutable copy for cart functionality
          final cartItem = MenuItemModel(
            id: item.id,
            name: item.name,
            price: item.price,
            description: item.description,
            imageUrl: item.imageUrl,
            storeId: item.storeId,
            category: item.category,
            isAvailable: item.isAvailable,
            createdAt: item.createdAt,
            updatedAt: item.updatedAt,
          );

          // Store original stock and initialize cart quantity
          originalStockMap[item.id] = 10; // Default stock since it's not in the model
          _setItemQuantity(cartItem, 0); // Initialize cart quantity to 0
        }

        // Update the lists with cart-enabled items
        menuItems = menuItems.map((item) {
          final cartItem = MenuItemModel(
            id: item.id,
            name: item.name,
            price: item.price,
            description: item.description,
            imageUrl: item.imageUrl,
            storeId: item.storeId,
            category: item.category,
            isAvailable: item.isAvailable,
            createdAt: item.createdAt,
            updatedAt: item.updatedAt,
          );
          _setItemQuantity(cartItem, 0);
          return cartItem;
        }).toList();

        filteredItems = List<MenuItemModel>.from(menuItems);
        _isLoadingMenuItems = false;
      });
    } catch (e) {
      print('Error fetching menu items: $e');
      setState(() {
        _errorMessage = 'Failed to load menu items: $e';
        _isLoadingMenuItems = false;
      });
    }
  }

  Future<void> getDetailStore(int storeId) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Use the correct service method
      final storeData = await StoreService.getStoreById(storeId.toString());

      // Convert the returned data to a StoreModel object
      final storeDetail = StoreModel.fromJson(storeData);

      setState(() {
        _storeDetail = storeDetail;
        _isLoading = false;

        // Calculate distance if we have both store and user location
        if (_currentPosition != null &&
            storeDetail.latitude != null &&
            storeDetail.longitude != null) {
          _calculateDistance();
        }
      });
    } catch (e) {
      print('Error fetching store details: $e');
      setState(() {
        _errorMessage = 'Failed to load store details: $e';
        _isLoading = false;
      });
    }
  }

  // Get user's current location
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      // Check if location permission is granted
      var status = await Permission.location.status;
      if (!status.isGranted) {
        status = await Permission.location.request();
        if (!status.isGranted) {
          throw Exception('Location permission denied');
        }
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;

        // Calculate distance if store details are already loaded
        if (_storeDetail != null &&
            _storeDetail!.latitude != null &&
            _storeDetail!.longitude != null) {
          _calculateDistance();
        }
      });
    } catch (e) {
      print('Error getting location: $e');
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  // Calculate distance between user and store
  void _calculateDistance() {
    if (_currentPosition == null ||
        _storeDetail?.latitude == null ||
        _storeDetail?.longitude == null) {
      return;
    }

    double distanceInMeters = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      _storeDetail!.latitude!,
      _storeDetail!.longitude!,
    );

    // Convert to kilometers
    setState(() {
      _storeDistance = distanceInMeters / 1000;
    });
  }

  // Format the distance for display
  String _getFormattedDistance() {
    if (_storeDistance == null) {
      return "-- KM";
    }

    if (_storeDistance! < 1) {
      return "${(_storeDistance! * 1000).toInt()} m";
    } else {
      return "${_storeDistance!.toStringAsFixed(1)} km";
    }
  }

  // Helper methods for cart functionality (since MenuItemModel doesn't have quantity field)
  final Map<int, int> _itemQuantities = {};

  int _getItemQuantity(MenuItemModel item) {
    return _itemQuantities[item.id] ?? 0;
  }

  void _setItemQuantity(MenuItemModel item, int quantity) {
    _itemQuantities[item.id] = quantity;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final int storeId = ModalRoute.of(context)!.settings.arguments as int? ?? 0;
    if (storeId > 0) {
      fetchMenuItems(storeId.toString());
      getDetailStore(storeId);
      _getCurrentLocation();
    } else {
      setState(() {
        _errorMessage = 'Invalid store ID';
        _isLoading = false;
        _isLoadingMenuItems = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    filteredItems = List<MenuItemModel>.from(menuItems);
    _pageController = PageController(viewportFraction: 0.8, initialPage: 0);
    _startAutoScroll();

    // Initialize cart animation
    _cartAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _cartAnimation = CurvedAnimation(
      parent: _cartAnimationController,
      curve: Curves.easeInOut,
    );

    // Add listener for search text changes
    _searchController.addListener(() {
      _performSearch();
    });
  }

  // Improved search method
  void _performSearch() {
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      setState(() {
        filteredItems = List<MenuItemModel>.from(menuItems);
      });
    } else {
      List<MenuItemModel> results = menuItems
          .where((item) =>
      item.name.toLowerCase().contains(query) ||
          (item.description.isNotEmpty &&
              item.description.toLowerCase().contains(query)))
          .toList();

      setState(() {
        filteredItems = results;
      });
    }
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (filteredItems.isEmpty) return;

      if (_currentPage < filteredItems.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }

      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _timer.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _audioPlayer.dispose();
    _cartAnimationController.dispose();
    super.dispose();
  }

  // Calculate remaining stock for an item
  int _getRemainingStock(MenuItemModel item) {
    int originalStock = originalStockMap[item.id] ?? 10; // Default stock
    int cartQuantity = _getItemQuantity(item);
    return originalStock - cartQuantity;
  }

  // Show dialog for quantity 0
  void _showZeroQuantityDialog() {
    _audioPlayer.play(AssetSource('audio/wrong.mp3'));

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/animations/caution.json',
                  height: 200,
                  width: 200,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Pilih jumlah item terlebih dahulu',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GlobalStyle.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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

  // Show dialog for out of stock
  void _showOutOfStockDialog() {
    _audioPlayer.play(AssetSource('audio/wrong.mp3'));

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/animations/caution.json',
                  height: 200,
                  width: 200,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Stok item tidak mencukupi',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Mohon kurangi jumlah pesanan atau pilih item lain',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GlobalStyle.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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

  // Show dialog for unavailable item
  void _showItemUnavailableDialog() {
    _audioPlayer.play(AssetSource('audio/wrong.mp3'));

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/animations/caution.json',
                  height: 200,
                  width: 200,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Item ini sedang tidak tersedia',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Mohon pilih item lain yang tersedia',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GlobalStyle.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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

  // Show success animation when adding item to cart
  void _showSuccessAnimation(MenuItemModel item) {
    setState(() {
      _lastAddedItem = item;
    });

    _audioPlayer.play(AssetSource('audio/kring.mp3'));

    _cartAnimationController.reset();
    _cartAnimationController.forward();
  }

  // Add item directly to cart from list
  void _addItemToCart(MenuItemModel item) {
    if (!item.isAvailable) {
      _showItemUnavailableDialog();
      return;
    }

    if (_getRemainingStock(item) <= 0) {
      _showOutOfStockDialog();
      return;
    }

    setState(() {
      _setItemQuantity(item, _getItemQuantity(item) + 1);
    });

    _showSuccessAnimation(item);
  }

  // Decrement item quantity in cart
  void _decrementItem(MenuItemModel item) {
    setState(() {
      int currentQuantity = _getItemQuantity(item);
      if (currentQuantity > 0) {
        _setItemQuantity(item, currentQuantity - 1);

        if (currentQuantity - 1 == 0 && _lastAddedItem?.id == item.id) {
          _lastAddedItem = null;
        }
      }
    });
  }

  // Increment item quantity in cart
  void _incrementItem(MenuItemModel item) {
    if (!item.isAvailable) {
      _showItemUnavailableDialog();
      return;
    }

    if (_getRemainingStock(item) <= 0) {
      _showOutOfStockDialog();
      return;
    }

    setState(() {
      _setItemQuantity(item, _getItemQuantity(item) + 1);
    });

    _showSuccessAnimation(item);
  }

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
        initialQuantity: _getItemQuantity(item),
        onQuantityChanged: (int quantity) {
          setState(() {
            if (quantity != initialQuantity) {
              _setItemQuantity(item, quantity);
              if (quantity > initialQuantity) {
                _showSuccessAnimation(item);
              }
            }
          });
        },
        onZeroQuantity: _showZeroQuantityDialog,
        onOutOfStock: _showOutOfStockDialog,
      ),
    );
  }

  bool get hasItemsInCart => _itemQuantities.values.any((quantity) => quantity > 0);
  int get totalItems => _itemQuantities.values.fold(0, (sum, quantity) => sum + quantity);
  double get totalPrice {
    double total = 0;
    for (var item in menuItems) {
      total += item.price * _getItemQuantity(item);
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _storeDetail == null) {
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

    if (_errorMessage.isNotEmpty) {
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
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[400],
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlobalStyle.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Kembali'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                _buildHeader(),
                _buildStoreInfo(),
                if (filteredItems.isNotEmpty && !_isLoadingMenuItems)
                  _buildCarouselMenu(),
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
        // Store banner image
        SizedBox(
          width: double.infinity,
          height: 230,
          child: _storeDetail!.imageUrl != null && _storeDetail!.imageUrl!.isNotEmpty
              ? ImageService.displayImage(
            imageSource: _storeDetail!.imageUrl!,
            width: double.infinity,
            height: 230,
            fit: BoxFit.cover,
            placeholder: Container(
              width: double.infinity,
              height: 230,
              color: Colors.grey[300],
              child: const Center(
                child: Icon(Icons.store, size: 80, color: Colors.grey),
              ),
            ),
          )
              : Container(
            width: double.infinity,
            height: 230,
            color: Colors.grey[300],
            child: const Center(
              child: Icon(Icons.store, size: 80, color: Colors.grey),
            ),
          ),
        ),

        // Back button and search bar
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
            child: Row(
              children: [
                // Back button
                Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(24),
                  color: Colors.white,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new,
                        color: GlobalStyle.primaryColor,
                        size: 16,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Search bar
                Expanded(
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(24),
                    color: Colors.white,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () {
                        setState(() {
                          _isSearching = true;
                        });
                        FocusScope.of(context).requestFocus(_searchFocusNode);
                      },
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.search,
                              color: GlobalStyle.primaryColor,
                              size: 20,
                            ),
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
                                onTap: () {
                                  setState(() {
                                    _isSearching = true;
                                  });
                                },
                              ),
                            ),
                            if (_searchController.text.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  _searchController.clear();
                                  setState(() {
                                    filteredItems = List<MenuItemModel>.from(menuItems);
                                  });
                                },
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.grey,
                                  size: 18,
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
      ],
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
                      _isLoadingLocation
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
                        style: const TextStyle(color: Colors.grey, fontSize: 14),
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
      child: PageView.builder(
        controller: _pageController,
        itemCount: filteredItems.length,
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
          });
        },
        itemBuilder: (context, index) {
          final item = filteredItems[index];
          return GestureDetector(
            onTap: () {
              if (item.isAvailable) {
                _showItemDetail(item);
              } else {
                _showItemUnavailableDialog();
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Opacity(
                opacity: item.isAvailable ? 1.0 : 0.5,
                child: _buildCarouselMenuItem(item),
              ),
            ),
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
              // Image wrapper
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
                      placeholder: Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: Icon(Icons.restaurant_menu, size: 40, color: Colors.grey),
                        ),
                      ),
                    )
                        : Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: Icon(Icons.restaurant_menu, size: 40, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              ),
              // Product information
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
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
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
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!item.isAvailable)
          Positioned(
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
          ),
      ],
    );
  }

  Widget _buildListMenu() {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _searchController.text.isNotEmpty
              ? Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              "Hasil pencarian: ${filteredItems.length} items",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          )
              : const Text(
            "Menu",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          if (_isLoadingMenuItems)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Column(
                  children: [
                    CircularProgressIndicator(color: GlobalStyle.primaryColor),
                    const SizedBox(height: 16),
                    Text(
                      'Memuat menu...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (filteredItems.isEmpty)
            Center(
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
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredItems.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildListMenuItem(filteredItems[index]),
                );
              },
            ),
        ],
      ),
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
                // Text section on the left
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: () {
                      if (item.isAvailable) {
                        _showItemDetail(item);
                      } else {
                        _showItemUnavailableDialog();
                      }
                    },
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
                // Image on the right
                Expanded(
                  flex: 1,
                  child: GestureDetector(
                    onTap: () {
                      if (item.isAvailable) {
                        _showItemDetail(item);
                      } else {
                        _showItemUnavailableDialog();
                      }
                    },
                    child: ClipRRect(
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
                      child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                          ? ImageService.displayImage(
                        imageSource: item.imageUrl!,
                        height: 140,
                        fit: BoxFit.cover,
                        placeholder: Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: Icon(Icons.restaurant_menu, size: 30, color: Colors.grey),
                          ),
                        ),
                      )
                          : Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: Icon(Icons.restaurant_menu, size: 30, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Button to add item or quantity control
            Positioned(
              bottom: 10,
              right: 20,
              child: itemQuantity > 0
                  ? _buildQuantityControl(item)
                  : _buildAddButton(item),
            ),
            // Status badges
            if (!item.isAvailable)
              Positioned(
                top: 0,
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
              ),
            if (item.isAvailable && _getRemainingStock(item) <= 0)
              Positioned(
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
              ),
          ],
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
        onPressed: (item.isAvailable && hasStock) ? () => _addItemToCart(item) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: (item.isAvailable && hasStock) ? GlobalStyle.primaryColor : Colors.grey,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
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
              child: const Icon(
                Icons.remove,
                color: Colors.white,
                size: 16,
              ),
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
              child: const Icon(
                Icons.add,
                color: Colors.white,
                size: 16,
              ),
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
            if (_lastAddedItem != null)
              FadeTransition(
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
                      Icon(
                        Icons.check_circle,
                        color: Colors.green[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _lastAddedItem!.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _lastAddedItem!.formatPrice(),
                              style: TextStyle(
                                color: GlobalStyle.primaryColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        "x${_getItemQuantity(_lastAddedItem!)}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$totalItems items',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
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
                onPressed: () {
                  // Create cart items with quantities
                  final cartItems = <MenuItemModel>[];
                  for (var item in menuItems) {
                    final quantity = _getItemQuantity(item);
                    if (quantity > 0) {
                      // Create a copy with the cart quantity (we need to pass this info to cart screen)
                      cartItems.add(item);
                    }
                  }

                  final int storeId = ModalRoute.of(context)!.settings.arguments as int? ?? 0;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CartScreen(
                        cartItems: cartItems,
                        storeId: storeId,
                        itemQuantities: Map<int, int>.from(_itemQuantities),
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlobalStyle.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
}

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
  int _quantity = 0;

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
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
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
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.item.description.isNotEmpty
                            ? widget.item.description
                            : 'Tidak ada deskripsi tersedia untuk produk ini.',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: () {
                              if (_quantity > 0) {
                                setState(() {
                                  _quantity--;
                                });
                              }
                            },
                            icon: const Icon(Icons.remove_circle_outline),
                            color: GlobalStyle.primaryColor,
                            iconSize: 32,
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              '$_quantity',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              if (_quantity < widget.availableStock) {
                                setState(() {
                                  _quantity++;
                                });
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
                      Row(
                        children: [
                          Expanded(
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
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
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