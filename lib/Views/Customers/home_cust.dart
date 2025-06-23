import 'dart:convert';

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
import 'package:del_pick/Services/driver_service.dart';
import 'package:del_pick/Services/image_service.dart';
import 'package:del_pick/Services/auth_service.dart';
import 'package:del_pick/Services/core/token_service.dart';
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
  late Animation<double> _driverSearchAnimation;

  final List<String> _promotionalPhrases = [
    "Lapar? Pilih makanan favoritmu sekarang!",
    "Cek toko langganan mu, mungkin ada menu baru!",
    "Yuk, pesan makanan kesukaanmu dalam sekali klik!",
    "Hayo, lagi cari apa? Del Pick siap layani pesanan mu",
    "Waktu makan siang! Pesan sekarang",
    "Kelaparan? Del Pick siap mengantar!",
    "Ingin makan enak tanpa ribet? Del Pick solusinya!",
  ];

  List<StoreModel> _allStores = [];
  List<StoreModel> _nearbyStores = [];
  List<StoreModel> _topRatedStores = [];
  bool _isLoading = true;
  bool _isSearchingDriver = false;
  String _errorMessage = '';
  String? _userName = '';
  Position? _currentPosition;
  bool _isLoadingLocation = false;

  List<StoreModel> get _filteredStores {
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

  // Fetch stores with location information
  Future<void> _fetchStoresWithLocation() async {
    if (_currentPosition == null) {
      await _fetchStores();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Get all stores
      final allStoresResponse = await StoreService.getAllStores(
        page: 1,
        limit: 50,
        sortBy: 'created_at',
        sortOrder: 'desc',
      );

      List<StoreModel> allStores = [];
      if (allStoresResponse['data'] != null) {
        final storesData = allStoresResponse['data'] as List;
        allStores = storesData.map((store) => StoreModel.fromJson(store)).toList();
      }

      // Get nearby stores
      List<StoreModel> nearbyStores = (await StoreService.getNearbyStores(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        radius: 10.0, // 10 km radius
        limit: 5,
      )).map<StoreModel>((store) => StoreModel.fromJson(store)).toList();

      // Get top rated stores (simulate by sorting by rating)
      List<StoreModel> topRatedStores = List.from(allStores);
      topRatedStores.sort((a, b) => b.rating.compareTo(a.rating));
      topRatedStores = topRatedStores.take(5).toList();

      if (mounted) {
        setState(() {
          _allStores = allStores;
          _nearbyStores = nearbyStores;
          _topRatedStores = topRatedStores;
          _isLoading = false;
        });
      }
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

  // Fetch stores without location information
  Future<void> _fetchStores() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Get all stores
      final allStoresResponse = await StoreService.getAllStores(
        page: 1,
        limit: 50,
        sortBy: 'created_at',
        sortOrder: 'desc',
      );

      List<StoreModel> allStores = [];
      if (allStoresResponse['data'] != null) {
        final storesData = allStoresResponse['data'] as List;
        allStores = storesData.map((store) => StoreModel.fromJson(store)).toList();
      }

      // Get top rated stores
      List<StoreModel> topRatedStores = List.from(allStores);
      topRatedStores.sort((a, b) => b.rating.compareTo(a.rating));
      topRatedStores = topRatedStores.take(5).toList();

      if (mounted) {
        setState(() {
          _allStores = allStores;
          _nearbyStores = []; // No nearby stores without location
          _topRatedStores = topRatedStores;
          _isLoading = false;
        });
      }
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

  // Search for active drivers
  Future<void> _searchForDriver() async {
    setState(() {
      _isSearchingDriver = true;
    });

    _driverSearchController.forward();

    try {
      // Get all active drivers
      final driversResponse = await DriverService.getAllDrivers(
        status: 'active',
        page: 1,
        limit: 20,
      );

      // Simulate search time
      await Future.delayed(const Duration(seconds: 3));

      if (driversResponse['data'] != null && driversResponse['data'].isNotEmpty) {
        final driversData = driversResponse['data'] as List;

        // Get the first available driver
        final driverData = driversData.first;
        final driver = DriverModel.fromJson(driverData);

        if (mounted) {
          setState(() {
            _isSearchingDriver = false;
          });

          // Navigate to contact driver page
          Navigator.pushNamed(
            context,
            ContactDriverPage.route,
            arguments: {
              'driver': driver,
              'serviceType': 'jastip',
            },
          );
        }
      } else {
        // No drivers available
        if (mounted) {
          setState(() {
            _isSearchingDriver = false;
          });

          _showNoDriverAvailableDialog();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearchingDriver = false;
        });

        _showDriverSearchErrorDialog(e.toString());
      }
      print('Error searching for driver: $e');
    }
  }

  void _showNoDriverAvailableDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        title: const Text('Driver Tidak Tersedia'),
        content: const Text(
          'Maaf, saat ini tidak ada driver yang tersedia. Silakan coba lagi nanti.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(color: GlobalStyle.primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  void _showDriverSearchErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        title: const Text('Error'),
        content: Text('Gagal mencari driver: $error'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(color: GlobalStyle.primaryColor),
            ),
          ),
        ],
      ),
    );
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
        if (userData != null && userData['user'] != null) {
          setState(() {
            _userName = userData['user']['name'] ?? '';
          });
        }
      }
    } catch (e) {
      print('Error getting user data: $e');
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
      setState(() {
        _searchQuery = _searchController.text;
      });
    });

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
      duration: const Duration(milliseconds: 1000),
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

    _driverSearchAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _driverSearchController,
        curve: Curves.easeInOut,
      ),
    );

    _fadeController.forward();
    _slideController.forward();
    _scaleController.forward();

    // Show dialog once when the page is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showPromoDialog();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _driverSearchController.dispose();
    _audioPlayer.dispose();
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
              child: _isLoading
                  ? Center(
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
              )
                  : _errorMessage.isNotEmpty
                  ? Center(
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
              )
                  : _filteredStores.isEmpty && _isSearching
                  ? Center(
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
              )
                  : RefreshIndicator(
                onRefresh: () async {
                  if (_currentPosition != null) {
                    await _fetchStoresWithLocation();
                  } else {
                    await _getCurrentLocation();
                  }
                },
                color: GlobalStyle.primaryColor,
                child: _buildMainContent(),
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

  Widget _buildMainContent() {
    if (_isSearching) {
      return ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _filteredStores.length,
        itemBuilder: (context, index) {
          final store = _filteredStores[index];
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
        },
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Jasa Titip Card
          _buildJasaTitipCard(),
          const SizedBox(height: 16),

          // Nearby Stores Section
          if (_nearbyStores.isNotEmpty) ...[
            _buildSectionTitle('Toko Terdekat'),
            const SizedBox(height: 12),
            _buildHorizontalStoreList(_nearbyStores),
            const SizedBox(height: 24),
          ],

          // Top Rated Stores Section
          if (_topRatedStores.isNotEmpty) ...[
            _buildSectionTitle('Toko Rating Terbaik'),
            const SizedBox(height: 12),
            _buildHorizontalStoreList(_topRatedStores),
            const SizedBox(height: 24),
          ],

          // All Stores Section
          _buildSectionTitle('Semua Toko'),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _allStores.length,
            itemBuilder: (context, index) {
              final store = _allStores[index];
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
        ],
      ),
    );
  }

  Widget _buildJasaTitipCard() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Jasa Titip',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: GlobalStyle.primaryColor,
                          fontFamily: GlobalStyle.fontFamily,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Barang yang kamu cari tidak ada di aplikasi? Pesan melalui driver aja!',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontFamily: GlobalStyle.fontFamily,
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
            const SizedBox(height: 16),
            if (_isSearchingDriver) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    RotationTransition(
                      turns: _driverSearchAnimation,
                      child: Icon(
                        LucideIcons.loader,
                        color: GlobalStyle.primaryColor,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Mencari driver...',
                      style: TextStyle(
                        color: GlobalStyle.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _searchForDriver,
                  icon: const Icon(LucideIcons.search, size: 18),
                  label: const Text('Cari Driver'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlobalStyle.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
        fontFamily: GlobalStyle.fontFamily,
      ),
    );
  }

  Widget _buildHorizontalStoreList(List<StoreModel> stores) {
    return SizedBox(
      height: 280,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: stores.length,
        itemBuilder: (context, index) {
          final store = stores[index];
          return Container(
            width: 200,
            margin: EdgeInsets.only(right: index == stores.length - 1 ? 0 : 12),
            child: _buildCompactStoreCard(store),
          );
        },
      ),
    );
  }

  Widget _buildCompactStoreCard(StoreModel store) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(context, StoreDetail.route, arguments: store.storeId);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                Hero(
                  tag: 'store-compact-${store.storeId}',
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12.0)),
                    child: _buildStoreImage(store.imageUrl, height: 120),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: GlobalStyle.primaryColor,
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, color: Colors.white, size: 12),
                        const SizedBox(width: 2),
                        Text(
                          store.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.name,
                      style: TextStyle(
                        fontSize: 14.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        fontFamily: GlobalStyle.fontFamily,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${store.reviewCount} ulasan',
                      style: TextStyle(
                        fontSize: 12.0,
                        color: Colors.grey[600],
                        fontFamily: GlobalStyle.fontFamily,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 12, color: Colors.grey[600]),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            store.address,
                            style: TextStyle(
                              fontSize: 10.0,
                              color: Colors.grey[600],
                              fontFamily: GlobalStyle.fontFamily,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
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
    );
  }

  Widget _buildStoreCard(StoreModel store) {
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
              Navigator.pushNamed(context, StoreDetail.route, arguments: store.storeId);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stack(
                  children: [
                    Hero(
                      tag: 'store-${store.storeId}',
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12.0)),
                        child: _buildStoreImage(store.imageUrl),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 4.0,
                        ),
                        decoration: BoxDecoration(
                          color: GlobalStyle.primaryColor,
                          borderRadius: BorderRadius.circular(16.0),
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
                              store.rating.toStringAsFixed(1),
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
                    if (store.distance != null)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 4.0,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(16.0),
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
                                store.formattedDistance ?? '',
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
                          Icon(
                            Icons.store,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${store.reviewCount} ulasan • ${store.totalProducts} menu',
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
                          Icon(
                            Icons.location_on,
                            size: 16,
                            color: Colors.grey[600],
                          ),
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
                          Icon(
                            Icons.access_time,
                            size: 16,
                            color: Colors.grey[600],
                          ),
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

  Widget _buildStoreImage(String? imageUrl, {double height = 200}) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return _buildPlaceholderImage(height);
    }

    return ImageService.displayImage(
      imageSource: imageUrl,
      width: double.infinity,
      height: height,
      fit: BoxFit.cover,
      placeholder: _buildPlaceholderImage(height),
      errorWidget: _buildPlaceholderImage(height),
    );
  }

  Widget _buildPlaceholderImage(double height) {
    return Container(
      height: height,
      width: double.infinity,
      color: Colors.grey[300],
      child: Center(
        child: Icon(LucideIcons.imageOff, size: 40, color: Colors.grey[500]),
      ),
    );
  }
}