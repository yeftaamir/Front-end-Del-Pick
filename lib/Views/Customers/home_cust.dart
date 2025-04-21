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

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  final List<String> _promotionalPhrases = [
    "Lapar? Pilih makanan favoritmu sekarang!",
    "Cek toko langganan mu, mungkin ada menu baru!",
    "Yuk, pesan makanan kesukaanmu dalam sekali klik!",
    "Hayo, lagi cari apa? Del Pick siap layani pesanan mu",
    "Waktu makan siang! Pesan sekarang",
    "Kelaparan? Del Pick siap mengantar!",
    "Ingin makan enak tanpa ribet? Del Pick solusinya!",
  ];

  List<StoreModel> _stores = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String? _userName = '';
  Position? _currentPosition;
  bool _isLoadingLocation = false;

  // Keep track of calculated distances separately
  Map<int, double> _storeDistances = {};

  List<StoreModel> get _filteredStores {
    if (_searchQuery.isEmpty && !_isSearching) {
      return _stores;
    }
    return _stores
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
      // Call the fetch stores method
      final stores = await StoreService.fetchStores();

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
  void _calculateDistances(List<StoreModel> stores) {
    if (_currentPosition == null) return;

    for (var store in stores) {
      if (store.latitude != null && store.longitude != null) {
        double distanceInMeters = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          store.latitude!,
          store.longitude!,
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
      final stores = await StoreService.fetchStores();
      if (mounted) {
        setState(() {
          _stores = stores;
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

  // Get user profile data
  Future<void> _getUserData() async {
    try {
      // Check if user is logged in
      final userData = await AuthService.getUserData();

      if (userData != null) {
        setState(() {
          _userName = userData['name'] ?? '';
        });
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
              border:
              Border.all(color: GlobalStyle.primaryColor, width: 1.0),
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
              Text(
                ' • Hi, $_userName',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontFamily: GlobalStyle.fontFamily,
                ),
                overflow: TextOverflow.ellipsis,
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
                  : _filteredStores.isEmpty
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
                child: ListView.builder(
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

  Widget _buildStoreCard(StoreModel store) {
    // Get distance for this store if available
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
              Navigator.pushNamed(context, StoreDetail.route,
                  arguments: store.id);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stack(
                  children: [
                    Hero(
                      tag: 'store-${store.id}',
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12.0)),
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
                              store.rating.toString(),
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
                          Icon(
                            Icons.store,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${store.reviewCount} ulasan • ${store.productCount} menu',
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