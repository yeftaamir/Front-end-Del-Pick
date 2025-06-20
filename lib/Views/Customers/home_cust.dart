import 'dart:convert';

import 'package:del_pick/Models/store.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Views/Customers/profile_cust.dart';
import 'package:del_pick/Views/Customers/store_detail.dart';
import '../Component/cust_bottom_navigation.dart';
import 'package:lottie/lottie.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:del_pick/Services/store_service.dart';
import 'package:del_pick/Services/menu_item_service.dart';
import 'package:del_pick/Services/image_service.dart';
import 'package:del_pick/Services/auth_service.dart';
import 'package:del_pick/Services/core/token_service.dart';
import 'package:del_pick/Services/driver_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'dart:async';

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

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late AnimationController _carouselController;
  late AnimationController _shakeController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _carouselAnimation;
  late Animation<double> _shakeAnimation;

  final List<String> _promotionalPhrases = [
    "Lapar? Pilih makanan favoritmu sekarang!",
    "Cek toko langganan mu, mungkin ada menu baru!",
    "Yuk, pesan makanan kesukaanmu dalam sekali klik!",
    "Hayo, lagi cari apa? Del Pick siap layani pesanan mu",
    "Waktu makan siang! Pesan sekarang",
    "Kelaparan? Del Pick siap mengantar!",
    "Ingin makan enak tanpa ribet? Del Pick solusinya!",
  ];

  List<Store> _stores = [];
  List<Store> _featuredStores = [];
  bool _isLoading = true;
  bool _isLoadingFeatured = true;
  String _errorMessage = '';
  String? _userName = '';
  Position? _currentPosition;
  bool _isLoadingLocation = false;
  String? _deliveryAddress;

  // Keep track of calculated distances separately
  Map<int, double> _storeDistances = {};

  // Search state
  bool _isSearchLoading = false;
  List<Store> _searchResults = [];

  // Driver search state
  bool _isSearchingDriver = false;
  bool _driverFound = false;
  String _driverName = "";
  String _vehicleNumber = "";
  Timer? _shakeTimer;

  List<Store> get _filteredStores {
    if (_searchQuery.isEmpty && !_isSearching) {
      return _stores;
    }
    return _searchResults;
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

      // Now fetch stores with location info
      await _fetchStoresWithLocation();
    } catch (e) {
      print('Error getting location: $e');
      setState(() {
        _isLoadingLocation = false;
      });

      // Fetch stores without location
      await _fetchStores();
    }
  }

  // Fetch featured stores with highest ratings
  Future<void> _fetchFeaturedStores() async {
    setState(() {
      _isLoadingFeatured = true;
    });

    try {
      // Get all stores and filter for featured ones
      final storesData = await StoreService.getAllStores(
        limit: 20, // Get more stores to have better selection
        latitude: _currentPosition?.latitude,
        longitude: _currentPosition?.longitude,
        radiusKm: 50.0, // Wider radius for featured stores
      );

      // Convert to Store objects
      List<Store> stores = storesData.map((data) => Store.fromJson(data)).toList();

      // Filter active stores with good ratings
      final featuredStores = stores
          .where((store) =>
      store.status == 'active' &&
          (store.rating ?? 0) >= 4.0)
          .toList();

      // Sort by rating (highest first) and take top 5
      featuredStores.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));

      if (mounted) {
        setState(() {
          _featuredStores = featuredStores.take(5).toList();
          _isLoadingFeatured = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingFeatured = false;
        });
        print('Error fetching featured stores: $e');
      }
    }
  }

  // Fetch stores with location information
  Future<void> _fetchStoresWithLocation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Get all stores using the updated StoreService
      final storesData = await StoreService.getAllStores(
        latitude: _currentPosition?.latitude,
        longitude: _currentPosition?.longitude,
        radiusKm: 25.0, // 25km radius
      );

      // Convert to Store objects
      List<Store> stores = storesData.map((data) => Store.fromJson(data)).toList();

      // Filter only active stores
      stores = stores.where((store) => store.status == 'active').toList();

      // Calculate distances if we have location
      _calculateDistances(stores);

      // Sort stores by distance
      stores.sort((a, b) {
        final distanceA = _storeDistances[a.id] ?? double.infinity;
        final distanceB = _storeDistances[b.id] ?? double.infinity;
        return distanceA.compareTo(distanceB);
      });

      if (mounted) {
        setState(() {
          _stores = stores;
          _isLoading = false;
        });
      }

      // Also fetch featured stores
      await _fetchFeaturedStores();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load stores: $e';
          _isLoading = false;
        });
        print('Error fetching stores with location: $e');
      }
    }
  }

  // Calculate distances to stores
  void _calculateDistances(List<Store> stores) {
    if (_currentPosition == null) return;

    for (var store in stores) {
      if (store.latitude != 0 && store.longitude != 0) {
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

  // Fetch stores without location information
  Future<void> _fetchStores() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Using the updated StoreService to get all stores
      final storesData = await StoreService.getAllStores();

      // Convert to Store objects
      List<Store> stores = storesData.map((data) => Store.fromJson(data)).toList();

      // Filter only active stores
      stores = stores.where((store) => store.status == 'active').toList();

      if (mounted) {
        setState(() {
          _stores = stores;
          _isLoading = false;
        });
      }

      // Also fetch featured stores
      await _fetchFeaturedStores();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load stores: $e';
          _isLoading = false;
        });
        print('Error fetching stores: $e');
      }
    }
  }

  // Search stores with backend support
  Future<void> _searchStores(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearchLoading = true;
    });

    try {
      final storesData = await StoreService.getAllStores(
        search: query,
        latitude: _currentPosition?.latitude,
        longitude: _currentPosition?.longitude,
        radiusKm: 50.0,
      );

      // Convert to Store objects
      List<Store> searchResults = storesData.map((data) => Store.fromJson(data)).toList();

      // Filter only active stores
      searchResults = searchResults.where((store) => store.status == 'active').toList();

      if (mounted) {
        setState(() {
          _searchResults = searchResults;
          _isSearchLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearchLoading = false;
        });
        print('Error searching stores: $e');
      }
    }
  }

  // Get user profile data using updated AuthService
  Future<void> _getUserData() async {
    try {
      // Check if user is logged in and fetch profile data
      try {
        final profileData = await AuthService.getProfile();
        if (profileData.isNotEmpty) {
          setState(() {
            _userName = profileData['name'] ?? '';
          });
        }
      } catch (e) {
        // If profile fetch fails, try from cached data
        final userData = await AuthService.getUserData();
        if (userData != null) {
          setState(() {
            _userName = userData['name'] ?? '';
          });
        }
      }
    } catch (e) {
      print('Error getting user data: $e');
    }
  }

  // NEW: Get available drivers
  Future<List<Map<String, dynamic>>> _getAvailableDrivers() async {
    try {
      if (_currentPosition == null) {
        throw Exception('Location not available');
      }

      final drivers = await DriverService.getNearbyDrivers(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        radiusKm: 10.0,
      );

      // Filter only active drivers
      return drivers.where((driver) => driver['status'] == 'active').toList();
    } catch (e) {
      print('Error getting available drivers: $e');
      return [];
    }
  }

  // NEW: Show driver order confirmation modal
  void _showDriverOrderModal() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/animations/driver.json',
                  height: 150,
                  width: 150,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 16),
                const Text(
                  "Pesan Melalui Driver",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Driver akan membantu Anda membeli barang yang tidak tersedia di toko-toko yang ada.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
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
                          "Batal",
                          style: TextStyle(fontWeight: FontWeight.bold),
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
                          "Cari Driver",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // NEW: Search for available driver
  void _searchForDriver() {
    setState(() {
      _isSearchingDriver = true;
      _driverFound = false;
    });

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
                    "Mohon tunggu sementara kami mencarikan driver terdekat untuk Anda...",
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

    // Simulate driver search
    Timer(const Duration(seconds: 3), () async {
      try {
        final availableDrivers = await _getAvailableDrivers();

        Navigator.of(context, rootNavigator: true).pop();

        setState(() {
          _isSearchingDriver = false;
        });

        if (availableDrivers.isNotEmpty) {
          final driver = availableDrivers.first;
          setState(() {
            _driverFound = true;
            _driverName = driver['user']?['name'] ?? 'Driver';
            _vehicleNumber = driver['vehicle_plate'] ?? 'Unknown';
          });

          _showDriverFoundDialog();
        } else {
          _showNoDriverAvailableDialog();
        }
      } catch (e) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() {
          _isSearchingDriver = false;
        });
        _showDriverSearchErrorDialog();
      }
    });
  }

  // NEW: Show driver found dialog
  void _showDriverFoundDialog() {
    _audioPlayer.play(AssetSource('audio/kring.mp3'));

    showDialog(
      context: context,
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
                  width: 200,
                  height: 200,
                  repeat: false,
                ),
                const SizedBox(height: 16),
                Text(
                  _driverName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    "Nomor Kendaraan: $_vehicleNumber",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Driver ditemukan! Anda dapat menghubungi driver untuk bantuan pembelian.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.call, size: 18),
                        label: const Text("Hubungi"),
                        onPressed: () {
                          Navigator.pop(context);
                          // Implement phone call functionality
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GlobalStyle.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: GlobalStyle.primaryColor,
                          side: BorderSide(color: GlobalStyle.primaryColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text("Tutup"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // NEW: Show no driver available dialog
  void _showNoDriverAvailableDialog() {
    _audioPlayer.play(AssetSource('audio/wrong.mp3'));

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/animations/caution.json',
                  height: 150,
                  width: 150,
                ),
                const Text(
                  "Driver Tidak Tersedia",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Maaf, tidak ada driver yang tersedia di area Anda saat ini. Silakan coba lagi nanti.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlobalStyle.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                  child: const Text("OK"),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // NEW: Show driver search error dialog
  void _showDriverSearchErrorDialog() {
    _audioPlayer.play(AssetSource('audio/wrong.mp3'));

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 60,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                const Text(
                  "Terjadi Kesalahan",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Gagal mencari driver. Pastikan Anda terhubung ke internet dan coba lagi.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlobalStyle.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                  child: const Text("OK"),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // NEW: Handle location access for address scanning
  Future<void> _handleLocationAccess() async {
    try {
      setState(() {
        _isLoadingLocation = true;
      });

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Use reverse geocoding to get address (simplified version)
      // In real implementation, you'd use geocoding package
      String address = "Lokasi terdeteksi: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}";

      setState(() {
        _currentPosition = position;
        _deliveryAddress = address;
        _isLoadingLocation = false;
      });

      // Update stores with new location
      await _fetchStoresWithLocation();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Alamat berhasil diperbarui: $address'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      setState(() {
        _isLoadingLocation = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memindai lokasi: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();

    // Get user data
    _getUserData();

    // Get location and fetch stores
    _getCurrentLocation();

    _searchController.addListener(() {
      final query = _searchController.text;
      setState(() {
        _searchQuery = query;
      });

      // Debounce search
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_searchController.text == query) {
          _searchStores(query);
        }
      });
    });

    _initializeAnimations();

    // Start shake animation timer
    _startShakeTimer();

    // Show dialog once when the page is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showPromoDialog();
    });
  }

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

    _carouselController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
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

    _carouselAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _carouselController,
        curve: Curves.easeInOut,
      ),
    );

    _shakeAnimation = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(
        parent: _shakeController,
        curve: Curves.elasticIn,
      ),
    );

    _fadeController.forward();
    _slideController.forward();
    _scaleController.forward();
    _carouselController.forward();
  }

  void _startShakeTimer() {
    _shakeTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        _shakeController.reset();
        _shakeController.forward();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _carouselController.dispose();
    _shakeController.dispose();
    _audioPlayer.dispose();
    _shakeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8F9FA),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (_isLoadingLocation && !_isLoading)
            _buildLocationLoadingBar(),
          if (_isSearching && _searchQuery.isEmpty)
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
            ),
          if (!_isSearching || _searchQuery.isNotEmpty)
            Expanded(
              child: _buildMainContent(),
            ),
        ],
      ),
      bottomNavigationBar: CustomBottomNavigation(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              GlobalStyle.primaryColor,
              GlobalStyle.primaryColor.withOpacity(0.8),
            ],
          ),
        ),
      ),
      leading: _isSearching
          ? IconButton(
        icon: Container(
          padding: const EdgeInsets.all(7.0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.arrow_back_ios_new,
            color: GlobalStyle.primaryColor,
            size: 18,
          ),
        ),
        onPressed: () {
          setState(() {
            _isSearching = false;
            _searchController.clear();
            _searchQuery = '';
            _searchResults = [];
          });
        },
      )
          : IconButton(
        icon: const Icon(Icons.search, color: Colors.white),
        onPressed: _startSearch,
      ),
      title: _isSearching
          ? Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Cari toko favorit...',
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 12,
            ),
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
            suffixIcon: _isSearchLoading
                ? Container(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: GlobalStyle.primaryColor,
                ),
              ),
            )
                : null,
          ),
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 14,
          ),
        ),
      )
          : Row(
        children: [
          Text(
            'Del Pick',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          if (_userName != null && _userName!.isNotEmpty) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Hi, $_userName!',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                  fontFamily: GlobalStyle.fontFamily,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (!_isSearching)
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(LucideIcons.user, color: Colors.white, size: 20),
              ),
              onPressed: () {
                Navigator.pushNamed(context, ProfilePage.route);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildLocationLoadingBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.blue.shade100],
        ),
      ),
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
            'Mencari toko terdekat...',
            style: TextStyle(
              color: GlobalStyle.primaryColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_errorMessage.isNotEmpty) {
      return _buildErrorState();
    }

    if (_isSearching && _searchQuery.isNotEmpty) {
      return _buildSearchResults();
    }

    return _buildHomeContent();
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: GlobalStyle.primaryColor),
          const SizedBox(height: 16),
          Text(
            'Memuat daftar toko...',
            style: TextStyle(
              color: Colors.grey[600],
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
          Icon(
            LucideIcons.alertTriangle,
            color: Colors.orange,
            size: 50,
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              _currentPosition != null
                  ? _fetchStoresWithLocation()
                  : _fetchStores();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: GlobalStyle.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
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

  Widget _buildSearchResults() {
    if (_filteredStores.isEmpty && !_isSearchLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.search,
              color: Colors.grey[400],
              size: 50,
            ),
            const SizedBox(height: 16),
            Text(
              'Tidak ada toko yang ditemukan untuk "$_searchQuery"',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _searchStores(_searchQuery),
      color: GlobalStyle.primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _filteredStores.length,
        itemBuilder: (context, index) {
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
        },
      ),
    );
  }

  Widget _buildHomeContent() {
    return RefreshIndicator(
      onRefresh: () async {
        if (_currentPosition != null) {
          await _fetchStoresWithLocation();
        } else {
          await _getCurrentLocation();
        }
      },
      color: GlobalStyle.primaryColor,
      child: CustomScrollView(
        slivers: [
          // NEW: Address Scanner Section
          SliverToBoxAdapter(
            child: _buildAddressScannerSection(),
          ),

          // Welcome Section
          SliverToBoxAdapter(
            child: _buildWelcomeSection(),
          ),

          // NEW: Driver Order Card
          SliverToBoxAdapter(
            child: _buildDriverOrderCard(),
          ),

          // Featured Stores Carousel
          SliverToBoxAdapter(
            child: _buildFeaturedStoresSection(),
          ),

          // All Stores Section
          SliverToBoxAdapter(
            child: _buildAllStoresHeader(),
          ),

          // Stores List
          _filteredStores.isEmpty
              ? SliverToBoxAdapter(
            child: _buildEmptyStoresState(),
          )
              : SliverList(
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
                          (delay + 0.4).clamp(0.0, 1.0),
                          curve: Curves.elasticOut,
                        ),
                      ),
                    );
                    return SlideTransition(
                      position: slideAnimation,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: _buildStoreCard(store),
                      ),
                    );
                  },
                );
              },
              childCount: _filteredStores.length,
            ),
          ),
        ],
      ),
    );
  }

  // NEW: Build address scanner section
  Widget _buildAddressScannerSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade50,
            Colors.blue.shade100,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: GlobalStyle.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.my_location,
              color: GlobalStyle.primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alamat Pengiriman',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: GlobalStyle.primaryColor,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _deliveryAddress ?? 'Pindai lokasi untuk alamat otomatis',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _isLoadingLocation ? null : _handleLocationAccess,
            icon: _isLoadingLocation
                ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : const Icon(Icons.qr_code_scanner, size: 16),
            label: Text(
              _isLoadingLocation ? 'Memindai...' : 'Pindai',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: GlobalStyle.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            GlobalStyle.primaryColor.withOpacity(0.1),
            GlobalStyle.lightColor.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: GlobalStyle.borderColor,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selamat Datang!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: GlobalStyle.primaryColor,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Temukan makanan favorit dari toko-toko terbaik di sekitar Anda',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            LucideIcons.sparkles,
            size: 40,
            color: GlobalStyle.primaryColor.withOpacity(0.6),
          ),
        ],
      ),
    );
  }

  // NEW: Build driver order card with shake animation
  Widget _buildDriverOrderCard() {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value, 0),
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.orange.shade50,
                  Colors.orange.shade100,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Stack(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.search,
                                color: Colors.orange.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Tidak Menemukan?',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade800,
                                  fontFamily: GlobalStyle.fontFamily,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Barang yang kamu cari tidak ada disini? Pesan melalui driver',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.orange.shade700,
                              fontFamily: GlobalStyle.fontFamily,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton(
                              onPressed: _showDriverOrderModal,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.shade600,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                elevation: 3,
                              ),
                              child: const Text(
                                'Pesan',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: Lottie.asset(
                        'assets/animations/driver.json',
                        fit: BoxFit.contain,
                        repeat: true,
                      ),
                    ),
                  ],
                ),
                // Sparkle effect
                Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(
                    LucideIcons.sparkles,
                    color: Colors.orange.shade300,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeaturedStoresSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                LucideIcons.star,
                color: GlobalStyle.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Toko Rekomendasi',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  fontFamily: GlobalStyle.fontFamily,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _isLoadingFeatured
            ? Container(
          height: 200,
          child: Center(
            child: CircularProgressIndicator(color: GlobalStyle.primaryColor),
          ),
        )
            : _featuredStores.isEmpty
            ? Container(
          height: 120,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Center(
            child: Text(
              'Belum ada toko rekomendasi',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
        )
            : AnimatedBuilder(
          animation: _carouselAnimation,
          builder: (context, child) {
            return Opacity(
              opacity: _carouselAnimation.value,
              child: Container(
                height: 220,
                child: CarouselSlider.builder(
                  itemCount: _featuredStores.length,
                  itemBuilder: (context, index, realIndex) {
                    return _buildFeaturedStoreCard(_featuredStores[index]);
                  },
                  options: CarouselOptions(
                    height: 220,
                    enlargeCenterPage: true,
                    autoPlay: true,
                    autoPlayInterval: const Duration(seconds: 4),
                    autoPlayAnimationDuration: const Duration(milliseconds: 800),
                    autoPlayCurve: Curves.fastOutSlowIn,
                    pauseAutoPlayOnTouch: true,
                    aspectRatio: 16 / 9,
                    viewportFraction: 0.85,
                    enableInfiniteScroll: _featuredStores.length > 1,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildFeaturedStoreCard(Store store) {
    double? storeDistance = _storeDistances[store.id];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            Navigator.pushNamed(context, StoreDetail.route, arguments: store.id);
          },
          child: Stack(
            children: [
              // Background Image
              Hero(
                tag: 'featured-store-${store.id}',
                child: _buildStoreImage(store.imageUrl, height: 220),
              ),

              // Gradient Overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
              ),

              // Content
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Rating Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: GlobalStyle.primaryColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            (store.rating ?? 0).toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Distance Badge
                    if (storeDistance != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.mapPin,
                              color: GlobalStyle.primaryColor,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              storeDistance < 1
                                  ? '${(storeDistance * 1000).toInt()} m'
                                  : '${storeDistance.toStringAsFixed(1)} km',
                              style: TextStyle(
                                color: GlobalStyle.primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // Store Info
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${store.reviewCount ?? 0} ulasan • ${store.totalProducts ?? 0} menu',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                      ),
                    ),
                    if (store.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        store.description,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAllStoresHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            LucideIcons.store,
            color: GlobalStyle.primaryColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            'Semua Toko',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          const Spacer(),
          Text(
            '${_stores.length} toko',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStoresState() {
    return Container(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.store,
              color: Colors.grey[400],
              size: 50,
            ),
            const SizedBox(height: 16),
            const Text(
              'Tidak ada toko yang ditemukan',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreCard(Store store) {
    // Get distance for this store if available
    double? storeDistance = _storeDistances[store.id];

    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Card(
          margin: const EdgeInsets.only(bottom: 16.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          elevation: 3,
          shadowColor: Colors.black.withOpacity(0.1),
          child: InkWell(
            onTap: () {
              Navigator.pushNamed(context, StoreDetail.route,
                  arguments: store.id);
            },
            borderRadius: BorderRadius.circular(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stack(
                  children: [
                    Hero(
                      tag: 'store-${store.id}',
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16.0)),
                        child: _buildStoreImage(store.imageUrl),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10.0,
                          vertical: 6.0,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              GlobalStyle.primaryColor,
                              GlobalStyle.primaryColor.withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20.0),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              (store.rating ?? 0).toString(),
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
                    // Show distance if available
                    if (storeDistance != null)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10.0,
                            vertical: 6.0,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(20.0),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                LucideIcons.mapPin,
                                color: GlobalStyle.primaryColor,
                                size: 14,
                              ),
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
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.store,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 6),
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
                      if (store.description.isNotEmpty) ...[
                        const SizedBox(height: 8),
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
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              store.address,
                              style: TextStyle(
                                fontSize: 13.0,
                                color: Colors.grey[600],
                                fontFamily: GlobalStyle.fontFamily,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (store.openTime != null && store.closeTime != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${store.openTime} - ${store.closeTime}',
                              style: TextStyle(
                                fontSize: 13.0,
                                color: Colors.grey[600],
                                fontFamily: GlobalStyle.fontFamily,
                              ),
                            ),
                          ],
                        ),
                      ],
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

  Widget _buildStoreImage(String? imageUrl, {double height = 200}) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return _buildPlaceholderImage(height: height);
    }

    return ImageService.displayImage(
      imageSource: imageUrl,
      width: double.infinity,
      height: height,
      fit: BoxFit.cover,
      placeholder: _buildPlaceholderImage(height: height),
      errorWidget: _buildPlaceholderImage(height: height),
    );
  }

  Widget _buildPlaceholderImage({double height = 200}) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey[300]!,
            Colors.grey[400]!,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          LucideIcons.imageOff,
          size: height * 0.2,
          color: Colors.grey[500],
        ),
      ),
    );
  }
}