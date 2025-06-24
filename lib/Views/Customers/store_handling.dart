// lib/Views/Customers/store_detail_enhanced.dart

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
import 'package:del_pick/Services/auth_service.dart';
import 'package:del_pick/Services/image_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class StoreDetailEnhanced extends StatefulWidget {
  static const String route = "/Customers/StoreDetailEnhanced";
  final List<MenuItemModel>? sharedMenuItems;

  const StoreDetailEnhanced({super.key, this.sharedMenuItems});

  @override
  State<StoreDetailEnhanced> createState() => _StoreDetailEnhancedState();
}

class _StoreDetailEnhancedState extends State<StoreDetailEnhanced> with SingleTickerProviderStateMixin {
  late List<MenuItemModel> menuItems = [];
  late List<MenuItemModel> filteredItems = [];
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
  int? _storeId;

  /// Enhanced argument parsing dengan multiple fallback options
  int? _parseStoreIdFromArguments(dynamic arguments) {
    print('🔍 StoreDetail: Parsing arguments: $arguments (${arguments.runtimeType})');

    try {
      // Case 1: Direct integer
      if (arguments is int) {
        print('✅ StoreDetail: Direct integer: $arguments');
        return arguments > 0 ? arguments : null;
      }

      // Case 2: String yang bisa diparse ke integer
      if (arguments is String) {
        final parsed = int.tryParse(arguments);
        print('✅ StoreDetail: Parsed string "$arguments" to: $parsed');
        return parsed != null && parsed > 0 ? parsed : null;
      }

      // Case 3: StoreModel object
      if (arguments is StoreModel) {
        print('✅ StoreDetail: StoreModel with ID: ${arguments.storeId}');
        return arguments.storeId > 0 ? arguments.storeId : null;
      }

      // Case 4: Map dengan berbagai kemungkinan key
      if (arguments is Map<String, dynamic>) {
        print('🔍 StoreDetail: Map with keys: ${arguments.keys.toList()}');

        // Coba berbagai kemungkinan key
        final possibleKeys = ['storeId', 'store_id', 'id'];
        for (String key in possibleKeys) {
          if (arguments.containsKey(key)) {
            final value = arguments[key];
            if (value is int && value > 0) {
              print('✅ StoreDetail: Found valid ID in key "$key": $value');
              return value;
            } else if (value is String) {
              final parsed = int.tryParse(value);
              if (parsed != null && parsed > 0) {
                print('✅ StoreDetail: Parsed ID from key "$key": $parsed');
                return parsed;
              }
            }
          }
        }

        // Jika ada nested store data
        if (arguments.containsKey('store')) {
          final storeData = arguments['store'];
          if (storeData is Map<String, dynamic> && storeData.containsKey('id')) {
            final storeId = storeData['id'];
            if (storeId is int && storeId > 0) {
              print('✅ StoreDetail: Found nested store ID: $storeId');
              return storeId;
            }
          }
        }
      }

      // Case 5: List dengan satu element (edge case)
      if (arguments is List && arguments.isNotEmpty) {
        return _parseStoreIdFromArguments(arguments.first);
      }

      print('❌ StoreDetail: Could not parse valid store ID from: $arguments');
      return null;

    } catch (e) {
      print('❌ StoreDetail: Error parsing arguments: $e');
      return null;
    }
  }

  Future<void> fetchMenuItems(String storeId) async {
    setState(() {
      _isLoadingMenuItems = true;
      _errorMessage = '';
    });

    try {
      print('🔍 StoreDetail: Starting to fetch menu items for store $storeId');

      // Validate authentication first
      final isAuthenticated = await AuthService.isAuthenticated();
      if (!isAuthenticated) {
        throw Exception('User not authenticated. Please login first.');
      }

      // Get user role data
      final userData = await AuthService.getRoleSpecificData();
      final userRole = await AuthService.getUserRole();

      print('✅ StoreDetail: User authenticated with role: $userRole');

      // Use the corrected service method with proper error handling
      final menuResponse = await MenuItemService.getMenuItemsByStore(
        storeId: storeId,
        page: 1,
        limit: 100,
        isAvailable: null,
        sortBy: 'name',
        sortOrder: 'asc',
      );

      print('🔍 StoreDetail: Menu response structure: ${menuResponse.keys.toList()}');

      // Check if response indicates success
      if (menuResponse['success'] == false) {
        throw Exception(menuResponse['error'] ?? 'Failed to load menu items');
      }

      // Extract menu items from response with proper error handling
      List<MenuItemModel> fetchedMenuItems = [];

      if (menuResponse['data'] != null && menuResponse['data'] is List) {
        final menuItemsData = menuResponse['data'] as List;
        print('📋 StoreDetail: Found ${menuItemsData.length} raw menu items');

        for (var itemData in menuItemsData) {
          try {
            if (itemData is Map<String, dynamic>) {
              final menuItem = MenuItemModel.fromJson(itemData);
              fetchedMenuItems.add(menuItem);
              print('✅ StoreDetail: Successfully parsed item: ${menuItem.name}');
            }
          } catch (e) {
            print('❌ StoreDetail: Error parsing menu item: $e');
            print('❌ Item data: $itemData');
          }
        }
      } else {
        print('⚠️ StoreDetail: No menu data found or invalid format');
      }

      setState(() {
        menuItems = fetchedMenuItems;
        filteredItems = fetchedMenuItems;

        // Store original stock quantities and initialize cart quantities
        for (var item in menuItems) {
          originalStockMap[item.id] = 10;
          _setItemQuantity(item, 0);
        }

        _isLoadingMenuItems = false;
      });

      print('✅ StoreDetail: Successfully loaded ${fetchedMenuItems.length} menu items');

    } catch (e) {
      print('❌ StoreDetail: Error fetching menu items: $e');
      setState(() {
        _errorMessage = 'Failed to load menu items: $e';
        _isLoadingMenuItems = false;
        menuItems = [];
        filteredItems = [];
      });
    }
  }

  Future<void> getDetailStore(String storeId) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      print('🏪 StoreDetail: Starting to fetch store details for ID: $storeId');

      // Validate authentication first
      final isAuthenticated = await AuthService.isAuthenticated();
      if (!isAuthenticated) {
        throw Exception('User not authenticated. Please login first.');
      }

      // Get user role data for logging
      final userRole = await AuthService.getUserRole();
      print('✅ StoreDetail: User authenticated with role: $userRole');

      // Use the corrected service method with proper error handling
      final storeResponse = await StoreService.getStoreById(storeId);

      print('🏪 StoreDetail: Store response structure: ${storeResponse.keys.toList()}');

      // Check if the response indicates success
      if (storeResponse['success'] == false) {
        throw Exception(storeResponse['error'] ?? 'Store not found');
      }

      // Extract store data from response
      final storeData = storeResponse['data'];
      if (storeData == null || storeData.isEmpty) {
        throw Exception('Store data is empty or null');
      }

      print('🏪 StoreDetail: Store data fields: ${storeData.keys.toList()}');

      // Convert the returned data to a StoreModel object with error handling
      StoreModel storeDetail;
      try {
        storeDetail = StoreModel.fromJson(storeData);
        print('✅ StoreDetail: Successfully parsed store model: ${storeDetail.name}');
      } catch (e) {
        print('❌ StoreDetail: Error parsing store model: $e');
        print('❌ Store data: $storeData');
        throw Exception('Invalid store data format: $e');
      }

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

      print('✅ StoreDetail: Successfully loaded store details');

    } catch (e) {
      print('❌ StoreDetail: Error fetching store details: $e');
      setState(() {
        _errorMessage = 'Failed to load store details: $e';
        _isLoading = false;
        _storeDetail = null;
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
          print('⚠️ StoreDetail: Location permission denied');
          setState(() {
            _isLoadingLocation = false;
          });
          return;
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

      print('✅ StoreDetail: Location obtained: ${position.latitude}, ${position.longitude}');

    } catch (e) {
      print('❌ StoreDetail: Error getting location: $e');
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

  // Helper methods for cart functionality
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

    // Only initialize once
    if (_storeId != null) return;

    // Enhanced argument parsing
    final arguments = ModalRoute.of(context)?.settings.arguments;
    final parsedStoreId = _parseStoreIdFromArguments(arguments);

    print('🔍 StoreDetail: Raw arguments: $arguments');
    print('🔍 StoreDetail: Parsed store ID: $parsedStoreId');

    _storeId = parsedStoreId;

    if (_storeId != null && _storeId! > 0) {
      // Start loading store data and menu items
      getDetailStore(_storeId.toString());
      fetchMenuItems(_storeId.toString());
      _getCurrentLocation();
    } else {
      setState(() {
        _errorMessage = 'Invalid store ID. Please select a valid store.\n\nReceived: $arguments\nType: ${arguments.runtimeType}';
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
    int originalStock = originalStockMap[item.id] ?? 10;
    int cartQuantity = _getItemQuantity(item);
    return originalStock - cartQuantity;
  }

  @override
  Widget build(BuildContext context) {
    // Loading state for both store and authentication check
    if (_isLoading) {
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

    // Error state with better error handling
    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Lottie.asset(
                  'assets/animations/caution.json',
                  height: 200,
                  width: 200,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 24),
                Text(
                  'Terjadi Kesalahan',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Text(
                    _errorMessage,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.red[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        // Try to reload data
                        if (_storeId != null && _storeId! > 0) {
                          setState(() {
                            _errorMessage = '';
                          });
                          getDetailStore(_storeId.toString());
                          fetchMenuItems(_storeId.toString());
                        }
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Coba Lagi'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GlobalStyle.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Kembali'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Check if store data is loaded
    if (_storeDetail == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: GlobalStyle.primaryColor),
              const SizedBox(height: 16),
              Text(
                'Memuat data toko...',
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

    // Main content would go here - simplified for this example
    return Scaffold(
      appBar: AppBar(
        title: Text(_storeDetail!.name),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Store Detail Page',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: GlobalStyle.primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text('Store ID: ${_storeDetail!.storeId}'),
            Text('Store Name: ${_storeDetail!.name}'),
            Text('Menu Items: ${menuItems.length}'),
          ],
        ),
      ),
    );
  }
}