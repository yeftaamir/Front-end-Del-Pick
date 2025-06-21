import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:del_pick/Models/store.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Views/Customers/profile_cust.dart';
import 'package:del_pick/Views/Customers/store_detail.dart';
import 'package:del_pick/Views/Customers/cart_screen.dart';
import '../../Models/menu_item.dart';
import '../Component/cust_bottom_navigation.dart';
import 'package:lottie/lottie.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

// Import required services
import 'package:del_pick/Services/store_service.dart';
import 'package:del_pick/Services/image_service.dart';
import 'package:del_pick/Services/auth_service.dart';
import 'package:del_pick/Services/core/token_service.dart';
import 'package:del_pick/Services/driver_service.dart';
import 'package:del_pick/Services/order_service.dart';

class HomePage extends StatefulWidget {
  static const String route = "/Customers/HomePage";
  const HomePage({super.key});

  @override
  createState() => HomePageState();
}

class HomePageState extends State<HomePage> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late AnimationController _shakeController;
  late AnimationController _carouselController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shakeAnimation;

  // Timer for shake animation
  Timer? _shakeTimer;

  // Page controller for carousel
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _autoScrollTimer;

  final List<String> _promotionalPhrases = [
    "Lapar? Pilih makanan favoritmu sekarang!",
    "Cek toko langganan mu, mungkin ada menu baru!",
    "Yuk, pesan makanan kesukaanmu dalam sekali klik!",
    "Hayo, lagi cari apa? Del Pick siap layani pesanan mu",
    "Waktu makan siang! Pesan sekarang",
    "Kelaparan? Del Pick siap mengantar!",
    "Ingin makan enak tanpa ribet? Del Pick solusinya!",
  ];

  // Data variables
  List<Store> _allStores = [];
  List<Store> _featuredStores = [];
  bool _isLoading = true;
  bool _isLoadingFeatured = true;
  bool _isInitializing = true; // NEW: Track overall initialization status
  String _errorMessage = '';
  String? _userName = '';
  String? _userToken = '';
  Position? _currentPosition;
  bool _isLoadingLocation = false;

  // Driver search variables
  bool _isSearchingDriver = false;
  bool _driverFound = false;

  // Keep track of calculated distances separately
  Map<int, double> _storeDistances = {};

  List<Store> get _filteredStores {
    if (_searchQuery.isEmpty && !_isSearching) {
      return _allStores;
    }
    return _allStores
        .where((store) =>
    store.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        store.address.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

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
    _fadeController.reset();
    _slideController.reset();
    _scaleController.reset();
    _fadeController.forward();
    _slideController.forward();
    _scaleController.forward();
  }

  void _showPromoDialog() {
    // Play sound
    _audioPlayer.play(AssetSource('audio/kring.mp3'));

    // Get random promotional phrase
    final randomPhrase = _promotionalPhrases[
    DateTime.now().millisecondsSinceEpoch % _promotionalPhrases.length];

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ),
              Lottie.asset(
                'assets/animations/pilih_pesanan.json',
                height: 200,
                width: 200,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 20),
              Text(
                randomPhrase,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  // Initialize token and user data
  Future<bool> _initializeUserData() async {
    try {
      // Get token from TokenService
      final token = await TokenService.getToken();
      if (token == null || token.isEmpty) {
        print('No authentication token found');
        // Navigate to login and prevent further execution
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacementNamed(context, '/login');
        });
        return false;
      }

      setState(() {
        _userToken = token;
      });

      // Verify token by getting user profile
      try {
        final profileData = await AuthService.getProfile();
        if (profileData.isNotEmpty) {
          setState(() {
            _userName = profileData['name'] ?? '';
          });
          print('Authentication successful, user: ${_userName}');
          return true;
        } else {
          throw Exception('Empty profile data');
        }
      } catch (e) {
        print('Profile fetch failed: $e');

        // If profile fetch fails, try to get cached user data
        try {
          final userData = await AuthService.getUserData();
          if (userData != null && userData.isNotEmpty) {
            setState(() {
              _userName = userData['name'] ?? '';
            });
            print('Using cached user data: ${_userName}');
            return true;
          }
        } catch (cacheError) {
          print('Cached data fetch failed: $cacheError');
        }

        // If both fail, clear token and redirect to login
        print('Authentication failed, clearing token and redirecting to login');
        await TokenService.clearToken();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacementNamed(context, '/login');
        });
        return false;
      }
    } catch (e) {
      print('Error initializing user data: $e');
      // Clear potentially corrupted token
      await TokenService.clearToken();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/login');
      });
      return false;
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
      });

      print('Location obtained: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      print('Error getting location: $e');
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  // Fetch all stores using StoreService.getAllStores()
  Future<void> _fetchAllStores() async {
    // Ensure we have a valid token before making API calls
    if (_userToken == null || _userToken!.isEmpty) {
      print('Cannot fetch stores: No authentication token');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Get all stores using StoreService
      final storesData = await StoreService.getAllStores(
        page: 1,
        limit: 50, // Get more stores
        latitude: _currentPosition?.latitude,
        longitude: _currentPosition?.longitude,
        radiusKm: 50.0, // 50km radius
      );

      // Convert the dynamic list to a list of Store objects
      List<Store> stores = [];
      for (var storeData in storesData) {
        stores.add(Store.fromJson(storeData));
      }

      // Calculate distances if we have location
      if (_currentPosition != null) {
        _calculateDistances(stores);

        // Sort stores by distance
        stores.sort((a, b) {
          final distanceA = _storeDistances[a.id] ?? double.infinity;
          final distanceB = _storeDistances[b.id] ?? double.infinity;
          return distanceA.compareTo(distanceB);
        });
      }

      if (mounted) {
        setState(() {
          _allStores = stores;
          _isLoading = false;
        });
        print('Successfully loaded ${stores.length} stores');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load stores: $e';
          _isLoading = false;
        });
        print('Error fetching all stores: $e');

        // If error is due to authentication, try to re-authenticate
        if (e.toString().contains('401') || e.toString().contains('UNAUTHORIZED')) {
          print('Authentication error detected, clearing token and redirecting to login');
          await TokenService.clearToken();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacementNamed(context, '/login');
          });
        }
      }
    }
  }

  // Get featured stores (highest rating and nearest)
  Future<void> _fetchFeaturedStores() async {
    // Ensure we have a valid token before making API calls
    if (_userToken == null || _userToken!.isEmpty) {
      print('Cannot fetch featured stores: No authentication token');
      return;
    }

    setState(() {
      _isLoadingFeatured = true;
    });

    try {
      List<Store> featuredStores = [];

      // If we have location, get nearby stores first
      if (_currentPosition != null) {
        try {
          final nearbyStoresData = await StoreService.getNearbyStores(
            latitude: _currentPosition!.latitude,
            longitude: _currentPosition!.longitude,
            radiusKm: 10.0, // 10km radius for featured
            limit: 10,
          );

          for (var storeData in nearbyStoresData) {
            featuredStores.add(Store.fromJson(storeData));
          }

          // Calculate distances
          _calculateDistances(featuredStores);
        } catch (e) {
          print('Error getting nearby stores: $e');
        }
      }

      // If we don't have enough featured stores from nearby, get high-rated stores
      if (featuredStores.length < 5) {
        try {
          final allStoresData = await StoreService.getAllStores(
            page: 1,
            limit: 20,
          );

          List<Store> allStores = [];
          for (var storeData in allStoresData) {
            allStores.add(Store.fromJson(storeData));
          }

          // Sort by rating and take top ones
          allStores.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));

          // Add stores that aren't already in featured
          for (var store in allStores) {
            if (featuredStores.length >= 8) break;
            if (!featuredStores.any((fs) => fs.id == store.id)) {
              featuredStores.add(store);
            }
          }
        } catch (e) {
          print('Error getting high-rated stores: $e');
        }
      }

      if (mounted) {
        setState(() {
          _featuredStores = featuredStores.take(8).toList(); // Limit to 8 for carousel
          _isLoadingFeatured = false;
        });
        print('Successfully loaded ${_featuredStores.length} featured stores');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingFeatured = false;
        });
        print('Error fetching featured stores: $e');

        // If error is due to authentication, handle it
        if (e.toString().contains('401') || e.toString().contains('UNAUTHORIZED')) {
          print('Authentication error in featured stores, clearing token and redirecting to login');
          await TokenService.clearToken();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacementNamed(context, '/login');
          });
        }
      }
    }
  }

  // Calculate distances to stores
  void _calculateDistances(List<Store> stores) {
    if (_currentPosition == null) return;

    for (var store in stores) {
      if (store.latitude != 0.0 && store.longitude != 0.0) {
        double distanceInMeters = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          store.latitude,
          store.longitude,
        );

        // Convert to kilometers and store
        _storeDistances[store.id] = distanceInMeters / 1000;
      }
    }
  }

  // Show driver order confirmation modal
  void _showDriverOrderModal() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset(
                'assets/animations/driver.json',
                height: 120,
                width: 120,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 16),
              const Text(
                'Pesan Melalui Driver',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Apakah Anda yakin ingin mencari driver untuk membantu Anda berbelanja?',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[600],
                        side: BorderSide(color: Colors.grey[300]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Batalkan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _searchForDriver();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GlobalStyle.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 2,
                      ),
                      child: const Text(
                        'Cari',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Search for driver functionality
  void _searchForDriver() {
    setState(() {
      _isSearchingDriver = true;
      _driverFound = false;
    });

    // Show driver search dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: Colors.white,
            elevation: 5,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Lottie.asset(
                    'assets/animations/loading_animation.json',
                    width: 180,
                    height: 180,
                    repeat: true,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Mencari Driver",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Mohon tunggu sementara kami mencarikan driver terbaik untuk membantu Anda berbelanja...",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() {
                        _isSearchingDriver = false;
                      });
                    },
                    child: Text(
                      "Batalkan Pencarian",
                      style: TextStyle(
                        color: Colors.red.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    // Simulate driver search (replace with actual API call)
    Timer(const Duration(seconds: 3), () {
      if (mounted && _isSearchingDriver) {
        Navigator.of(context, rootNavigator: true).pop();

        setState(() {
          _isSearchingDriver = false;
          _driverFound = true;
        });

        _playSound('audio/kring.mp3');
        _showDriverFoundDialog();
      }
    });
  }

  // Show driver found dialog
  Future<void> _showDriverFoundDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          elevation: 5,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/animations/driver_found.json',
                  width: 150,
                  height: 150,
                  repeat: false,
                ),
                const SizedBox(height: 16),
                const Text(
                  "Driver Ditemukan!",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Driver siap membantu Anda berbelanja. Anda akan diarahkan ke halaman pesanan.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlobalStyle.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                    elevation: 2,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    // Navigate to cart screen for driver order
                    Navigator.pushNamed(
                      context,
                      CartScreen.route,
                      arguments: {
                        'cartItems': <MenuItem>[], // Empty cart for driver order
                        'storeId': 0, // Special ID for driver orders
                        'isDriverOrder': true,
                      },
                    );
                  },
                  child: const Text(
                    "Lanjutkan",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Play sound helper method
  Future<void> _playSound(String assetPath) async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource(assetPath));
    } catch (e) {
      print('Error playing sound: $e');
    }
  }

  // Start shake animation timer
  void _startShakeTimer() {
    _shakeTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        _shakeController.forward().then((_) {
          _shakeController.reset();
        });
      }
    });
  }

  // Start carousel auto scroll
  void _startCarouselAutoScroll() {
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted && _featuredStores.isNotEmpty) {
        int nextPage = (_currentPage + 1) % _featuredStores.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();

    // Initialize user data and token first, then load data
    _initializeApp();

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });

    // Initialize animations
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

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _carouselController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeInOut,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: Curves.elasticOut,
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: Curves.easeOutBack,
      ),
    );

    _shakeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _shakeController,
        curve: Curves.elasticInOut,
      ),
    );

    // Initialize page controller
    _pageController = PageController();

    _fadeController.forward();
    _slideController.forward();
    _scaleController.forward();

    // Start timers
    _startShakeTimer();

    // Show dialog once when the page is opened (after authentication)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Only show promo dialog if user is authenticated
      if (_userToken != null && _userToken!.isNotEmpty) {
        _showPromoDialog();
      }
    });
  }

  // Initialize the entire app: user data, location, then stores
  Future<void> _initializeApp() async {
    setState(() {
      _isInitializing = true;
    });

    try {
      // Step 1: Initialize user data and validate authentication
      print('Initializing user authentication...');
      final isAuthenticated = await _initializeUserData();

      if (!isAuthenticated) {
        print('Authentication failed, stopping initialization');
        setState(() {
          _isInitializing = false;
        });
        return;
      }

      // Step 2: Get user location
      print('Getting user location...');
      await _getCurrentLocation();

      // Step 3: Fetch stores data (only after authentication is confirmed)
      print('Fetching stores data...');
      await Future.wait([
        _fetchAllStores(),
        _fetchFeaturedStores(),
      ]);

      // Step 4: Start carousel auto scroll if we have featured stores
      if (_featuredStores.isNotEmpty) {
        _startCarouselAutoScroll();
      }

      setState(() {
        _isInitializing = false;
      });

      print('App initialization completed successfully');
    } catch (e) {
      print('Error during app initialization: $e');

      setState(() {
        _isInitializing = false;
        _errorMessage = 'Failed to initialize app: $e';
      });

      // If there's any critical error, ensure user gets redirected to login
      await TokenService.clearToken();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _shakeController.dispose();
    _carouselController.dispose();
    _pageController.dispose();
    _audioPlayer.dispose();
    _shakeTimer?.cancel();
    _autoScrollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffD6E6F2),
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: Colors.white,
        leading: _isSearching
            ? IconButton(
          icon: Container(
            padding: const EdgeInsets.all(7.0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: GlobalStyle.primaryColor, width: 1.0),
            ),
            child: Icon(Icons.arrow_back_ios_new,
                color: GlobalStyle.primaryColor, size: 18),
          ),
          onPressed: () {
            setState(() {
              _isSearching = false;
              _searchController.clear();
              _searchQuery = '';
            });
          },
        )
            : IconButton(
          icon: const Icon(Icons.search, color: Colors.black54),
          onPressed: _startSearch,
        ),
        title: _isSearching
            ? TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Cari toko...',
            border: InputBorder.none,
            hintStyle: TextStyle(
              color: GlobalStyle.fontColor,
              fontSize: GlobalStyle.fontSize,
            ),
          ),
          style: TextStyle(
            color: GlobalStyle.fontColor,
            fontSize: GlobalStyle.fontSize,
          ),
        )
            : Row(
          children: [
            Text(
              'Del Pick',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontFamily: GlobalStyle.fontFamily,
              ),
            ),
            if (_userName != null && _userName!.isNotEmpty)
              Flexible(
                child: Text(
                  ' • Hi, $_userName',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: IconButton(
              icon: const Icon(LucideIcons.user, color: Colors.black54),
              onPressed: () {
                Navigator.pushNamed(context, ProfilePage.route);
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoadingLocation && !_isLoading)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              color: Colors.blue.shade50,
              width: double.infinity,
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: GlobalStyle.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Mendapatkan lokasi terdekat...',
                    style: TextStyle(
                      color: GlobalStyle.primaryColor,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          if (_isInitializing)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: GlobalStyle.primaryColor),
                    const SizedBox(height: 16),
                    Text(
                      'Memuat aplikasi...',
                      style: TextStyle(
                        color: GlobalStyle.primaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Mohon tunggu sebentar',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (_isSearching && _searchQuery.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  'Ketik untuk mencari toko...',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),
              ),
            )
          else if (!_isSearching || _searchQuery.isNotEmpty)
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    // Ensure user is still authenticated before refreshing
                    if (_userToken == null || _userToken!.isEmpty) {
                      final isAuthenticated = await _initializeUserData();
                      if (!isAuthenticated) {
                        return;
                      }
                    }

                    await Future.wait([
                      _fetchAllStores(),
                      _fetchFeaturedStores(),
                    ]);
                  },
                  color: GlobalStyle.primaryColor,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Driver Order Card
                        if (!_isSearching)
                          AnimatedBuilder(
                            animation: _shakeAnimation,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(
                                  sin(_shakeAnimation.value * 2 * pi * 2) * 3,
                                  0,
                                ),
                                child: _buildDriverOrderCard(),
                              );
                            },
                          ),

                        if (!_isSearching) const SizedBox(height: 20),

                        // Featured Stores Carousel
                        if (!_isSearching) _buildFeaturedStoresSection(),

                        if (!_isSearching) const SizedBox(height: 20),

                        // All Stores Section
                        _buildAllStoresSection(),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
      bottomNavigationBar: CustomBottomNavigation(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }

  // Build driver order card
  Widget _buildDriverOrderCard() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              GlobalStyle.primaryColor.withOpacity(0.1),
              GlobalStyle.primaryColor.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: GlobalStyle.primaryColor.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: GlobalStyle.primaryColor.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pesan Melalui Driver',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: GlobalStyle.primaryColor,
                          fontFamily: GlobalStyle.fontFamily,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Barang yang kamu cari tidak ada di aplikasi? Pesan dari driver aja!',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          fontFamily: GlobalStyle.fontFamily,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Lottie.asset(
                    'assets/animations/driver.json',
                    height: 80,
                    width: 80,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: _showDriverOrderModal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlobalStyle.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  elevation: 2,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.search, size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'Cari Driver',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
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

  // Build featured stores section with carousel
  Widget _buildFeaturedStoresSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Rekomendasi Toko',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                fontFamily: GlobalStyle.fontFamily,
              ),
            ),
            Icon(
              LucideIcons.star,
              color: Colors.amber,
              size: 24,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoadingFeatured)
          Container(
            height: 200,
            child: Center(
              child: CircularProgressIndicator(color: GlobalStyle.primaryColor),
            ),
          )
        else if (_featuredStores.isEmpty)
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                'Tidak ada toko rekomendasi',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          SizedBox(
            height: 220,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemCount: _featuredStores.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(right: 16),
                  child: _buildFeaturedStoreCard(_featuredStores[index]),
                );
              },
            ),
          ),
        if (!_isLoadingFeatured && _featuredStores.isNotEmpty)
          const SizedBox(height: 12),
        if (!_isLoadingFeatured && _featuredStores.isNotEmpty)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _featuredStores.length,
                  (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentPage == index
                      ? GlobalStyle.primaryColor
                      : Colors.grey[300],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Build featured store card
  Widget _buildFeaturedStoreCard(Store store) {
    double? storeDistance = _storeDistances[store.id];

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        elevation: 4,
        child: InkWell(
          onTap: () {
            Navigator.pushNamed(context, StoreDetail.route, arguments: store.id);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12.0)),
                      child: _buildStoreImage(store.imageUrl),
                    ),
                    // Rating badge
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              store.rating?.toString() ?? '0.0',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Distance badge
                    if (storeDistance != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            storeDistance < 1
                                ? '${(storeDistance * 1000).toInt()} m'
                                : '${storeDistance.toStringAsFixed(1)} km',
                            style: TextStyle(
                              color: GlobalStyle.primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        store.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          fontFamily: GlobalStyle.fontFamily,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        store.address,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontFamily: GlobalStyle.fontFamily,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Icon(Icons.store, size: 12, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '${store.totalProducts ?? 0} menu',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build all stores section
  Widget _buildAllStoresSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _isSearching ? 'Hasil Pencarian' : 'Semua Toko',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                fontFamily: GlobalStyle.fontFamily,
              ),
            ),
            if (_isSearching && _filteredStores.isNotEmpty)
              Text(
                '${_filteredStores.length} hasil',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoading)
          Column(
            children: List.generate(3, (index) => _buildLoadingStoreCard()),
          )
        else if (_errorMessage.isNotEmpty)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.alertTriangle, color: Colors.orange, size: 50),
                const SizedBox(height: 16),
                Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.grey, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    // Ensure user is still authenticated before retrying
                    if (_userToken == null || _userToken!.isEmpty) {
                      final isAuthenticated = await _initializeUserData();
                      if (!isAuthenticated) {
                        return;
                      }
                    }
                    _fetchAllStores();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlobalStyle.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          )
        else if (_filteredStores.isEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.store, color: Colors.grey[400], size: 50),
                  const SizedBox(height: 16),
                  Text(
                    _isSearching ? 'Tidak ada toko yang ditemukan' : 'Tidak ada toko tersedia',
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            )
          else
            Column(
              children: _filteredStores.asMap().entries.map((entry) {
                final index = entry.key;
                final store = entry.value;
                return AnimatedBuilder(
                  animation: _slideController,
                  builder: (context, child) {
                    final delay = index * 0.2;
                    final slideAnimation = Tween<Offset>(
                      begin: const Offset(1.0, 0.0),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: _slideController,
                        curve: Interval(
                          delay.clamp(0.0, 1.0),
                          (delay + 0.4).clamp(0.0, 1.0),
                          curve: Curves.elasticOut,
                        ),
                      ),
                    );
                    return SlideTransition(
                      position: slideAnimation,
                      child: _buildStoreCard(store),
                    );
                  },
                );
              }).toList(),
            ),
      ],
    );
  }

  // Build loading store card
  Widget _buildLoadingStoreCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 20,
                    width: double.infinity,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 16,
                    width: 200,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 16,
                    width: 150,
                    color: Colors.grey[300],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build regular store card
  Widget _buildStoreCard(Store store) {
    double? storeDistance = _storeDistances[store.id];

    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Card(
          margin: const EdgeInsets.only(bottom: 16.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          elevation: 2,
          child: InkWell(
            onTap: () {
              Navigator.pushNamed(context, StoreDetail.route, arguments: store.id);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stack(
                  children: [
                    Hero(
                      tag: 'store-${store.id}',
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12.0)),
                        child: _buildStoreImage(store.imageUrl),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        decoration: BoxDecoration(
                          color: GlobalStyle.primaryColor,
                          borderRadius: BorderRadius.circular(16.0),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, color: Colors.white, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              store.rating?.toString() ?? '0.0',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (storeDistance != null)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(16.0),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.mapPin, color: GlobalStyle.primaryColor, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                storeDistance < 1
                                    ? '${(storeDistance * 1000).toInt()} m'
                                    : '${storeDistance.toStringAsFixed(1)} km',
                                style: TextStyle(
                                  color: GlobalStyle.primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        store.name,
                        style: TextStyle(
                          fontSize: 18.0,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          fontFamily: GlobalStyle.fontFamily,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.store, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '${store.reviewCount ?? 0} ulasan • ${store.totalProducts ?? 0} menu',
                            style: TextStyle(
                              fontSize: 14.0,
                              color: Colors.grey[600],
                              fontFamily: GlobalStyle.fontFamily,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (store.description.isNotEmpty)
                        Text(
                          store.description,
                          style: TextStyle(
                            fontSize: 14.0,
                            color: Colors.grey[600],
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              store.address,
                              style: TextStyle(
                                fontSize: 14.0,
                                color: Colors.grey[600],
                                fontFamily: GlobalStyle.fontFamily,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            store.openHours,
                            style: TextStyle(
                              fontSize: 14.0,
                              color: Colors.grey[600],
                              fontFamily: GlobalStyle.fontFamily,
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
    );
  }

  // Build store image with proper error handling
  Widget _buildStoreImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return _buildPlaceholderImage();
    }

    return ImageService.displayImage(
      imageSource: imageUrl,
      width: double.infinity,
      height: 200,
      fit: BoxFit.cover,
      placeholder: _buildPlaceholderImage(),
      errorWidget: _buildPlaceholderImage(),
    );
  }

  // Build placeholder image
  Widget _buildPlaceholderImage() {
    return Container(
      height: 200,
      width: double.infinity,
      color: Colors.grey[300],
      child: Center(
        child: Icon(LucideIcons.imageOff, size: 40, color: Colors.grey[500]),
      ),
    );
  }
}