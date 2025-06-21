import 'dart:convert';
import 'dart:async';

import 'package:del_pick/Models/store.dart';
import 'package:del_pick/Models/driver.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Views/Customers/profile_cust.dart';
import 'package:del_pick/Views/Customers/store_detail.dart';
import 'package:del_pick/Views/Customers/contact_driver.dart';
import '../Component/cust_bottom_navigation.dart';
import 'package:lottie/lottie.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:del_pick/Services/store_service.dart';
import 'package:del_pick/Services/image_service.dart';
import 'package:del_pick/Services/auth_service.dart';
import 'package:del_pick/Services/core/token_service.dart';
import 'package:del_pick/Services/location_service.dart';
import 'package:del_pick/Services/driver_service.dart';
import 'package:del_pick/Services/order_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

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
  late AnimationController _driverSearchController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  // User data
  String? _userName = '';
  String? _userRole = '';
  String? _userId = '';

  // Location data with default to Institut Teknologi Del
  Position? _currentPosition;
  String _currentAddress = "Institut Teknologi Del, Sitoluama, Kec. Balige, Toba, Sumatera Utara";
  double _defaultLatitude = 2.38328;
  double _defaultLongitude = 99.148601;
  bool _isLoadingLocation = false;

  // Store data
  List<Store> _allStores = [];
  List<Store> _nearbyStores = [];
  List<Store> _topRatedStores = [];
  bool _isLoadingStores = true;
  String _errorMessage = '';

  // Driver search
  bool _isSearchingDriver = false;
  bool _driverFound = false;
  Driver? _foundDriver;
  Timer? _driverSearchTimer;

  // Keep track of calculated distances
  Map<int, double> _storeDistances = {};

  final List<String> _promotionalPhrases = [
    "Lapar? Pilih makanan favoritmu sekarang!",
    "Cek toko langganan mu, mungkin ada menu baru!",
    "Yuk, pesan makanan kesukaanmu dalam sekali klik!",
    "Hayo, lagi cari apa? Del Pick siap layani pesanan mu",
    "Waktu makan siang! Pesan sekarang",
    "Kelaparan? Del Pick siap mengantar!",
    "Ingin makan enak tanpa ribet? Del Pick solusinya!",
  ];

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

  @override
  void initState() {
    super.initState();
    _initializeApp();
    _initializeAnimations();
    _setupSearch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _driverSearchController.dispose();
    _audioPlayer.dispose();
    _driverSearchTimer?.cancel();
    super.dispose();
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

    _driverSearchController = AnimationController(
      duration: const Duration(milliseconds: 1500),
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

    _fadeController.forward();
    _slideController.forward();
    _scaleController.forward();

    // Show promotional dialog
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showPromoDialog();
    });
  }

  void _setupSearch() {
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  Future<void> _initializeApp() async {
    await _loadUserData();
    await _getCurrentLocation();
    await _loadStoresData();
  }

  // Load user data using TokenService and AuthService
  Future<void> _loadUserData() async {
    try {
      // Get user data using the required services
      final token = await TokenService.getToken();
      final userRole = await TokenService.getUserRole();
      final userId = await TokenService.getUserId();

      if (token != null) {
        final userData = await AuthService.getUserData();
        setState(() {
          _userName = userData?['name'] ?? '';
          _userRole = userRole;
          _userId = userId;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  // Get user's current location using LocationService
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      // Check location permission
      final hasPermission = await LocationService.hasLocationPermission();
      if (!hasPermission) {
        final granted = await LocationService.requestLocationPermission();
        if (!granted) {
          // Use default location (Institut Teknologi Del)
          _setDefaultLocation();
          return;
        }
      }

      // Get current position using LocationService
      final position = await LocationService.getCurrentLocation();
      if (position != null) {
        setState(() {
          _currentPosition = position;
        });

        // Get address from coordinates
        final address = await LocationService.getAddressFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (address != null) {
          setState(() {
            _currentAddress = address;
          });
        }
      } else {
        _setDefaultLocation();
      }
    } catch (e) {
      print('Error getting location: $e');
      _setDefaultLocation();
    } finally {
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  void _setDefaultLocation() {
    setState(() {
      _currentPosition = Position(
        latitude: _defaultLatitude,
        longitude: _defaultLongitude,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        floor: null,
        isMocked: false,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );
      _currentAddress = "Institut Teknologi Del, Sitoluama, Kec. Balige, Toba, Sumatera Utara";
      _isLoadingLocation = false;
    });
  }

  // Load stores data using StoreService
  Future<void> _loadStoresData() async {
    setState(() {
      _isLoadingStores = true;
      _errorMessage = '';
    });

    try {
      // Get all stores using StoreService
      final storesResponse = await StoreService.getAllStores();

      List<Store> stores = [];
      if (storesResponse['data'] != null && storesResponse['data'] is List) {
        for (var storeData in storesResponse['data']) {
          stores.add(Store.fromJson(storeData));
        }
      }

      // Calculate distances if we have location
      if (_currentPosition != null) {
        _calculateDistances(stores);

        // Sort by distance for nearby stores
        final nearbyStores = List<Store>.from(stores);
        nearbyStores.sort((a, b) {
          final distanceA = _storeDistances[a.id] ?? double.infinity;
          final distanceB = _storeDistances[b.id] ?? double.infinity;
          return distanceA.compareTo(distanceB);
        });

        // Get top 5 nearby stores
        _nearbyStores = nearbyStores.take(5).toList();
      }

      // Sort by rating for top rated stores
      final topRatedStores = List<Store>.from(stores);
      topRatedStores.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
      _topRatedStores = topRatedStores.take(5).toList();

      setState(() {
        _allStores = stores;
        _isLoadingStores = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load stores: $e';
        _isLoadingStores = false;
      });
      print('Error loading stores: $e');
    }
  }

  // Calculate distances to stores using LocationService
  void _calculateDistances(List<Store> stores) {
    if (_currentPosition == null) return;

    for (var store in stores) {
      if (store.latitude != null && store.longitude != null) {
        double distance = LocationService.calculateDistance(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          store.latitude!,
          store.longitude!,
        );
        _storeDistances[store.id] = distance;
      }
    }
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
    _audioPlayer.play(AssetSource('audio/kring.mp3'));

    final randomPhrase = _promotionalPhrases[
    DateTime.now().millisecondsSinceEpoch % _promotionalPhrases.length];

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                  onPressed: () => Navigator.of(context).pop(),
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

  void _showDriverRequestModal() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(LucideIcons.truck, color: GlobalStyle.primaryColor, size: 24),
            const SizedBox(width: 8),
            const Text('Cari Driver'),
          ],
        ),
        content: const Text(
          'Apakah kamu yakin ingin mencari driver untuk pesanan khusus?',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Batal',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _searchForDriver();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: GlobalStyle.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Cari'),
          ),
        ],
      ),
    );
  }

  Future<void> _searchForDriver() async {
    setState(() {
      _isSearchingDriver = true;
      _driverFound = false;
    });

    _driverSearchController.repeat();

    // Show driver search dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _driverSearchController,
                  child: Lottie.asset(
                    'assets/animations/driver.json',
                    width: 180,
                    height: 180,
                  ),
                  builder: (context, child) {
                    return Transform.scale(
                      scale: 1.0 + 0.1 * _driverSearchController.value,
                      child: child,
                    );
                  },
                ),
                const SizedBox(height: 24),
                const Text(
                  "Mencari Driver Terdekat",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Mohon tunggu sementara kami mencarikan driver terbaik untuk kebutuhan Anda...",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () {
                    _cancelDriverSearch();
                    Navigator.pop(context);
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
      ),
    );

    try {
      // Use DriverService to find nearby drivers
      if (_currentPosition != null) {
        final nearbyDrivers = await DriverService.getNearbyDrivers(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          radius: 10.0,
          limit: 1,
        );

        // Simulate search time
        await Future.delayed(const Duration(seconds: 3));

        if (nearbyDrivers.isNotEmpty) {
          setState(() {
            _driverFound = true;
            _foundDriver = Driver.fromJson(nearbyDrivers.first);
          });

          _driverSearchController.stop();
          Navigator.pop(context); // Close search dialog
          _showDriverFoundDialog();
        } else {
          throw Exception('No drivers available');
        }
      }
    } catch (e) {
      print('Error searching for driver: $e');
      _driverSearchController.stop();
      Navigator.pop(context); // Close search dialog
      _showDriverNotFoundDialog();
    }

    setState(() {
      _isSearchingDriver = false;
    });
  }

  void _cancelDriverSearch() {
    _driverSearchTimer?.cancel();
    _driverSearchController.stop();
    setState(() {
      _isSearchingDriver = false;
    });
  }

  void _showDriverFoundDialog() {
    _audioPlayer.play(AssetSource('audio/kring.mp3'));

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset(
                'assets/animations/driver_found.json',
                width: 120,
                height: 120,
                repeat: false,
              ),
              const SizedBox(height: 16),
              const Text(
                "Driver Ditemukan!",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _foundDriver?.name ?? 'Driver tersedia',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(
                    context,
                    ContactDriverScreen.route,
                    arguments: _foundDriver,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlobalStyle.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 14,
                  ),
                ),
                child: const Text("Hubungi Driver"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDriverNotFoundDialog() {
    _audioPlayer.play(AssetSource('audio/wrong.mp3'));

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset(
                'assets/animations/caution.json',
                width: 120,
                height: 120,
              ),
              const SizedBox(height: 16),
              const Text(
                "Driver Tidak Ditemukan",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Maaf, tidak ada driver yang tersedia saat ini. Silakan coba lagi nanti.",
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
                ),
                child: const Text("OK"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF0F7FF),
      appBar: _buildAppBar(),
      body: _buildBody(),
      bottomNavigationBar: CustomBottomNavigation(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
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
            Expanded(
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
    );
  }

  Widget _buildBody() {
    if (_isSearching && _searchQuery.isEmpty) {
      return const Center(
        child: Text(
          'Ketik untuk mencari toko...',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    if (_isLoadingStores) {
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

    if (_errorMessage.isNotEmpty) {
      return Center(
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
              onPressed: _loadStoresData,
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

    return RefreshIndicator(
      onRefresh: () async {
        await _getCurrentLocation();
        await _loadStoresData();
      },
      color: GlobalStyle.primaryColor,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          if (!_isSearching) ...[
            _buildLocationCard(),
            const SizedBox(height: 16),
            _buildDriverRequestCard(),
            const SizedBox(height: 16),
            _buildTopRatedStoresCard(),
            const SizedBox(height: 16),
            _buildNearbyStoresCard(),
            const SizedBox(height: 16),
          ],
          _buildAllStoresCard(),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: GlobalStyle.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              LucideIcons.mapPin,
              color: GlobalStyle.primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lokasi Anda',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _currentAddress,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: GlobalStyle.fontColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (_isLoadingLocation)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: GlobalStyle.primaryColor,
              ),
            )
          else
            IconButton(
              onPressed: _getCurrentLocation,
              icon: Icon(
                LucideIcons.refreshCw,
                color: GlobalStyle.primaryColor,
                size: 20,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDriverRequestCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: GlobalStyle.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  LucideIcons.truck,
                  color: GlobalStyle.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Pesan melalui Driver',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Barang yang kamu cari tidak ada di aplikasi? Pesan melalui driver aja!',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _showDriverRequestModal,
                      icon: const Icon(LucideIcons.search, size: 18),
                      label: const Text('Cari Driver'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GlobalStyle.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 80,
                height: 80,
                child: Lottie.asset(
                  'assets/animations/driver.json',
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopRatedStoresCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.star,
                    color: Colors.amber,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Toko Rating Tertinggi',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 240,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _topRatedStores.length,
              itemBuilder: (context, index) {
                final store = _topRatedStores[index];
                return _buildHorizontalStoreCard(store);
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildNearbyStoresCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    LucideIcons.mapPin,
                    color: Colors.green,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Toko Terdekat',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 240,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _nearbyStores.length,
              itemBuilder: (context, index) {
                final store = _nearbyStores[index];
                return _buildHorizontalStoreCard(store);
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildHorizontalStoreCard(Store store) {
    double? storeDistance = _storeDistances[store.id];

    return Container(
      width: 180,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        child: InkWell(
          onTap: () {
            Navigator.pushNamed(context, StoreDetail.route, arguments: store.id);
          },
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: ImageService.displayImage(
                      imageSource: store.imageUrl ?? '',
                      width: double.infinity,
                      height: 120,
                      fit: BoxFit.cover,
                      placeholder: Container(
                        height: 120,
                        color: Colors.grey[300],
                        child: Icon(LucideIcons.imageOff, size: 30, color: Colors.grey[500]),
                      ),
                      errorWidget: Container(
                        height: 120,
                        color: Colors.grey[300],
                        child: Icon(LucideIcons.imageOff, size: 30, color: Colors.grey[500]),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: GlobalStyle.primaryColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, color: Colors.white, size: 12),
                          const SizedBox(width: 2),
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
                  ),
                  if (storeDistance != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          storeDistance < 1
                              ? '${(storeDistance * 1000).toInt()} m'
                              : '${storeDistance.toStringAsFixed(1)} km',
                          style: TextStyle(
                            color: GlobalStyle.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        store.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
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
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${store.reviewCount ?? 0} ulasan • ${store.totalProducts ?? 0} menu',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[500],
                        ),
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

  Widget _buildAllStoresCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: GlobalStyle.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    LucideIcons.store,
                    color: GlobalStyle.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _isSearching ? 'Hasil Pencarian' : 'Semua Toko',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (_filteredStores.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(LucideIcons.store, color: Colors.grey, size: 40),
                    SizedBox(height: 8),
                    Text(
                      'Tidak ada toko yang ditemukan',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredStores.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final store = _filteredStores[index];
                return _buildStoreListTile(store);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStoreListTile(Store store) {
    double? storeDistance = _storeDistances[store.id];

    return ListTile(
      contentPadding: const EdgeInsets.all(16),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ImageService.displayImage(
          imageSource: store.imageUrl ?? '',
          width: 60,
          height: 60,
          fit: BoxFit.cover,
          placeholder: Container(
            width: 60,
            height: 60,
            color: Colors.grey[300],
            child: Icon(LucideIcons.imageOff, size: 24, color: Colors.grey[500]),
          ),
          errorWidget: Container(
            width: 60,
            height: 60,
            color: Colors.grey[300],
            child: Icon(LucideIcons.imageOff, size: 24, color: Colors.grey[500]),
          ),
        ),
      ),
      title: Text(
        store.name,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.star, color: Colors.amber, size: 14),
              const SizedBox(width: 4),
              Text(
                '${store.rating ?? 0} • ${store.reviewCount ?? 0} ulasan',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            store.address,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (storeDistance != null)
            Text(
              storeDistance < 1
                  ? '${(storeDistance * 1000).toInt()} m dari Anda'
                  : '${storeDistance.toStringAsFixed(1)} km dari Anda',
              style: TextStyle(
                fontSize: 12,
                color: GlobalStyle.primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
      trailing: Icon(
        LucideIcons.chevronRight,
        color: Colors.grey[400],
      ),
      onTap: () {
        Navigator.pushNamed(context, StoreDetail.route, arguments: store.id);
      },
    );
  }
}