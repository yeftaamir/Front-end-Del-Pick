import 'dart:async';
import 'package:del_pick/Models/store.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Models/menu_item.dart';
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
  final List<MenuItem>? sharedMenuItems;

  const StoreDetail({super.key, this.sharedMenuItems});

  @override
  State<StoreDetail> createState() => _StoreDetailState();
}

class _StoreDetailState extends State<StoreDetail> {
  late List<MenuItem> menuItems = [];
  late List<MenuItem> filteredItems = [];
  late PageController _pageController;
  late Timer _timer;
  int _currentPage = 0;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer(); // Audio player instance
  bool _isLoading = true; // Add loading state
  bool _isLoadingLocation = true; // Loading state for location
  Position? _currentPosition; // User's current position
  double? _storeDistance; // Calculated distance to store

  late Store _storeDetail = Store(
    id: 0,
    userId: 0,
    name: '',
    address: '',
    description: '',
    openTime: '',
    closeTime: '',
    rating: 0.0,
    totalProducts: 0,
    imageUrl: '',
    phone: '',
    reviewCount: 0,
  );

  Future<void> fetchMenuItems(String storeId) async {
    try {
      List<MenuItem> fetchedMenuItems =
      await MenuService.fetchMenuItemsByStoreId(storeId);

      setState(() {
        menuItems = fetchedMenuItems;
        filteredItems = fetchedMenuItems;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching menu items: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> getDetailStore(int storeId) async {
    try {
      final storeDetail = await StoreService.fetchStoreById(storeId);
      print(storeDetail);
      setState(() {
        _storeDetail = storeDetail;
        // Calculate distance if we have both store and user location
        if (_currentPosition != null && storeDetail.latitude != null && storeDetail.longitude != null) {
          _calculateDistance();
        }
      });
    } catch (e) {
      print('Error fetching store details: $e');
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
        if (_storeDetail.id != 0 && _storeDetail.latitude != null && _storeDetail.longitude != null) {
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
        _storeDetail.latitude == null ||
        _storeDetail.longitude == null) {
      return;
    }

    double distanceInMeters = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      _storeDetail.latitude,
      _storeDetail.longitude,
    );

    // Convert to kilometers
    setState(() {
      _storeDistance = distanceInMeters / 1000;
    });
  }

  // Format the distance for display
  String _getFormattedDistance() {
    if (_storeDistance == null) {
      return "-- KM"; // Placeholder when distance is not available
    }

    if (_storeDistance! < 1) {
      // If less than 1 km, show in meters
      return "${(_storeDistance! * 1000).toInt()} m";
    } else {
      // Otherwise show in km with 1 decimal place
      return "${_storeDistance!.toStringAsFixed(1)} km";
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final int storeId = ModalRoute.of(context)!.settings.arguments as int;
    fetchMenuItems(storeId.toString());
    getDetailStore(storeId);
    _getCurrentLocation(); // Get location when screen loads
  }

  @override
  void initState() {
    super.initState();
    filteredItems = List<MenuItem>.from(menuItems);
    _pageController = PageController(viewportFraction: 0.8, initialPage: 0);
    _startAutoScroll();
  }

  void _performSearch() {
    final query = _searchController.text;
    final results = query.isEmpty
        ? List<MenuItem>.from(menuItems)
        : menuItems
        .where(
            (item) => item.name.toLowerCase().contains(query.toLowerCase()))
        .toList();

    _showSearchResults(results);
  }

  void _showSearchResults(List<MenuItem> results) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.2,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Search Results (${results.length})',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: results.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (context, index) {
                      final item = results[index];
                      return Opacity(
                        opacity: item.isAvailable ? 1.0 : 0.5,
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            if (item.isAvailable) {
                              _showItemDetail(item);
                            } else {
                              _showItemUnavailableDialog();
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
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
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: ImageService.displayImage(
                                    imageSource: item.getProcessedImageUrl(),
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                    placeholder: Container(
                                      width: 80,
                                      height: 80,
                                      color: Colors.grey[200],
                                      child: const Icon(Icons.restaurant_menu),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        GlobalStyle.formatRupiah(item.price),
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: GlobalStyle.primaryColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (!item.isAvailable)
                                        Container(
                                          margin: const EdgeInsets.only(top: 4),
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'Tidak tersedia',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.red,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (filteredItems.isEmpty) return; // Guard against empty list

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
    _audioPlayer.dispose(); // Dispose the audio player
    super.dispose();
  }

  // Show dialog for quantity 0
  void _showZeroQuantityDialog() {
    // Play the wrong sound
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
                  style: TextStyle(
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
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
    // Play the wrong sound
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
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
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

  // Add item directly to cart from list
  void _addItemToCart(MenuItem item) {
    if (!item.isAvailable) {
      _showItemUnavailableDialog();
      return;
    }

    setState(() {
      // If quantity is 0, set it to 1
      if (item.quantity == 0) {
        item.quantity = 1;
      }
    });
  }

  // Decrement item quantity in cart
  void _decrementItem(MenuItem item) {
    setState(() {
      if (item.quantity > 0) {
        item.quantity--;
      }
    });
  }

  // Increment item quantity in cart
  void _incrementItem(MenuItem item) {
    if (!item.isAvailable) {
      _showItemUnavailableDialog();
      return;
    }

    setState(() {
      item.quantity++;
    });
  }

  void _showItemDetail(MenuItem item) {
    if (!item.isAvailable) {
      _showItemUnavailableDialog();
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableItemDetail(
        item: item,
        onQuantityChanged: (int quantity) {
          setState(() {
            item.quantity = quantity;
          });
        },
        onZeroQuantity: _showZeroQuantityDialog,
      ),
    );
  }

  bool get hasItemsInCart => menuItems.any((item) => item.quantity > 0);
  int get totalItems => menuItems.fold(0, (sum, item) => sum + item.quantity);
  double get totalPrice =>
      menuItems.fold(0, (sum, item) => sum + (item.price * item.quantity));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                _buildHeader(),
                _buildStoreInfo(),
                if (filteredItems.isNotEmpty) _buildCarouselMenu(),
                _buildListMenu(),
                if (hasItemsInCart) const SizedBox(height: 100),
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
        SizedBox(
          width: double.infinity,
          height: 230,
          child: ImageService.displayImage(
            imageSource: _storeDetail.imageUrl,
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
          ),
        ),
        Positioned(
          top: 40,
          left: 16,
          right: 16,
          child: Row(
            children: [
              InkWell(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 6)
                    ],
                  ),
                  child: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.blue, size: 16),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: _isSearching ? double.infinity : 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 6)
                    ],
                  ),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 40,
                        child: Center(
                          child: InkWell(
                            onTap: () {
                              if (_isSearching) {
                                _performSearch();
                              } else {
                                setState(() {
                                  _isSearching = true;
                                });
                              }
                            },
                            child: Icon(
                              _isSearching ? Icons.search : Icons.search,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 300),
                          opacity: _isSearching ? 1.0 : 0.0,
                          child: _isSearching
                              ? Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  decoration: const InputDecoration(
                                    hintText: 'Search menu...',
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 8),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  setState(() {
                                    _isSearching = false;
                                    _searchController.clear();
                                  });
                                },
                              ),
                            ],
                          )
                              : const SizedBox(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
              _storeDetail.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _storeDetail.address,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            Text(
              'Buka: ${_storeDetail.openTime} - ${_storeDetail.closeTime}',
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
                          style: const TextStyle(color: Colors.grey, fontSize: 14)
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
                        _storeDetail.rating.toString(),
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
      height: 300, // Increased height to accommodate full product image
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

  Widget _buildCarouselMenuItem(MenuItem item) {
    // Updated carousel card based on the image example
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
              // Image wrapper with fixed height to prevent cropping
              Expanded(
                child: ClipRRect(
                  borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Container(
                    width: double.infinity,
                    color: Colors.white,
                    child: ImageService.displayImage(
                      imageSource: item.getProcessedImageUrl(),
                      fit: BoxFit.contain,
                      placeholder: Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: Icon(Icons.restaurant_menu, size: 40, color: Colors.grey),
                        ),
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
                    // Price - Using primary color
                    Text(
                      GlobalStyle.formatRupiah(item.price),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: GlobalStyle.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Name
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
          const Text(
            "Menu",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          filteredItems.isEmpty
              ? Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Column(
                children: [
                  Icon(Icons.restaurant_menu, size: 60, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No menu items available',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          )
              : ListView.builder(
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

  Widget _buildListMenuItem(MenuItem item) {
    return Opacity(
      opacity: item.isAvailable ? 1.0 : 0.5,
      child: Container(
        height: 140, // Reduced height
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
            // Main content with image and text
            Row(
              children: [
                // Text section on the left (clickable for details)
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
                          const SizedBox(height: 8),
                          Text(
                            GlobalStyle.formatRupiah(item.price),
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
                // Image on the right (clickable for details)
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
                      borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(12)),
                      child: ImageService.displayImage(
                        imageSource: item.getProcessedImageUrl(),
                        height: 140,
                        fit: BoxFit.cover,
                        placeholder: Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: Icon(Icons.restaurant_menu, size: 30, color: Colors.grey),
                          ),
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
              child: item.quantity > 0
                  ? _buildQuantityControl(item)
                  : _buildAddButton(item),
            ),
            // Status badge for unavailable items
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
          ],
        ),
      ),
    );
  }

  // Add button widget
  Widget _buildAddButton(MenuItem item) {
    return SizedBox(
      height: 30,
      width: 90,
      child: ElevatedButton(
        onPressed: item.isAvailable ? () => _addItemToCart(item) : () => _showItemUnavailableDialog(),
        style: ElevatedButton.styleFrom(
          backgroundColor: item.isAvailable ? GlobalStyle.primaryColor : Colors.grey,
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

  // Quantity control widget (- count +)
  Widget _buildQuantityControl(MenuItem item) {
    return Container(
      height: 30,
      decoration: BoxDecoration(
        color: item.isAvailable ? GlobalStyle.primaryColor : Colors.grey,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Minus button
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
          // Quantity display
          Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '${item.quantity}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Plus button
          InkWell(
            onTap: item.isAvailable ? () => _incrementItem(item) : () => _showItemUnavailableDialog(),
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
                  final cartItems =
                  menuItems.where((item) => item.quantity > 0).toList();
                  final int storeId = ModalRoute.of(context)!.settings.arguments as int;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CartScreen(cartItems: cartItems, storeId: storeId),
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
  final MenuItem item;
  final Function(int) onQuantityChanged;
  final VoidCallback onZeroQuantity;

  const DraggableItemDetail({
    Key? key,
    required this.item,
    required this.onQuantityChanged,
    required this.onZeroQuantity,
  }) : super(key: key);

  @override
  State<DraggableItemDetail> createState() => _DraggableItemDetailState();
}

class _DraggableItemDetailState extends State<DraggableItemDetail> {
  int _quantity = 0;

  @override
  void initState() {
    super.initState();
    _quantity = widget.item.quantity;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      // Increase initial child size to show the add to cart button immediately
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
                      // Updated image container to display the full image without cropping
                      Container(
                        width: double.infinity,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: ImageService.displayImage(
                            imageSource: widget.item.getProcessedImageUrl(),
                            fit: BoxFit.contain,
                            placeholder: Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child: Icon(Icons.restaurant_menu, size: 60, color: Colors.grey),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.item.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        GlobalStyle.formatRupiah(widget.item.price),
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
                        widget.item.description ?? 'Tidak ada deskripsi tersedia untuk produk ini.',
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
                          ),
                          Text(
                            '$_quantity',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _quantity++;
                              });
                            },
                            icon: const Icon(Icons.add_circle_outline),
                            color: GlobalStyle.primaryColor,
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
                                  // Show zero quantity dialog instead of text warning
                                  Navigator.pop(
                                      context); // Close the bottom sheet first
                                  widget.onZeroQuantity(); // Show the dialog
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: GlobalStyle.primaryColor,
                                padding:
                                const EdgeInsets.symmetric(vertical: 16),
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