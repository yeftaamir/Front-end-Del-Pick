import 'dart:convert';
import 'dart:math' as math;
import 'package:geocoding/geocoding.dart';
import 'package:del_pick/Models/store.dart';
import 'package:del_pick/Models/driver.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Views/Customers/profile_cust.dart';
import 'package:del_pick/Views/Customers/store_detail.dart';
import 'package:del_pick/Views/Customers/contact_driver.dart';
import '../../Services/Core/token_service.dart';
import '../Component/cust_bottom_navigation.dart';
import 'package:lottie/lottie.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:del_pick/Services/store_service.dart';
import 'package:del_pick/Services/driver_service.dart';
import 'package:del_pick/Services/image_service.dart';
import 'package:del_pick/Services/auth_service.dart';
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
  bool _isLoadingLocation = false;
  String _errorMessage = '';
  String? _userName = '';
  String? _userLocation = '';
  Map<String, dynamic>? _userData;
  Position? _currentPosition;
  bool _hasLocationPermission = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeData();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _driverSearchController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
    _driverSearchAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _driverSearchController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
    _slideController.forward();
    _scaleController.forward();
  }

  void _initializeData() {
    _loadUserData();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _driverSearchController.dispose();
    _searchController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // Helper method to safely convert dynamic values to double
  double _safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  // Helper method to safely convert dynamic values to int
  int _safeToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  // Helper method to safely convert dynamic values to string
  String _safeToString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is int || value is double || value is bool) {
      return value.toString();
    }
    return '';
  }

  Future<void> _loadUserData() async {
    try {
      // Get user data from AuthService
      final userData = await AuthService.getUserData();
      if (userData != null) {
        setState(() {
          _userData = userData;
          _userName = userData['user']?['name'] ?? userData['name'] ?? '';
        });
      } else {
        // Fallback to TokenService if AuthService fails
        final tokenUserData = await TokenService.getUserData();
        if (tokenUserData != null) {
          setState(() {
            _userData = tokenUserData;
            _userName = tokenUserData['user']?['name'] ?? tokenUserData['name'] ?? '';
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
      // Try to get from token service as fallback
      try {
        final tokenUserData = await TokenService.getUserData();
        if (tokenUserData != null) {
          setState(() {
            _userData = tokenUserData;
            _userName = tokenUserData['user']?['name'] ?? tokenUserData['name'] ?? '';
          });
        }
      } catch (tokenError) {
        print('Error loading user data from token: $tokenError');
      }
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

      // Get address from coordinates
      String locationText = await _getAddressFromCoordinates(position);

      setState(() {
        _currentPosition = position;
        _userLocation = locationText;
        _hasLocationPermission = true;
        _isLoadingLocation = false;
      });

      // Now fetch stores with location info
      await _fetchStores();
    } catch (e) {
      print('Error getting location: $e');
      setState(() {
        _hasLocationPermission = false;
        _userLocation = 'Lokasi tidak tersedia';
        _isLoadingLocation = false;
      });

      // Fetch stores without location
      await _fetchStores();
    }
  }

// Get address from coordinates
  Future<String> _getAddressFromCoordinates(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        return '${place.locality ?? ''}, ${place.subAdministrativeArea ?? ''}';
      }
    } catch (e) {
      print('Error getting address: $e');
    }
    return 'Balige, North Sumatra'; // Default fallback
  }

  // Fetch all stores and process them
  Future<void> _fetchStores() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      print('Fetching stores...');

      // Get all stores from service with correct response structure
      final storesResponse = await StoreService.getAllStores(
        page: 1,
        limit: 100, // Get more stores
        sortBy: 'created_at',
        sortOrder: 'desc',
      );

      print('Stores response: $storesResponse');

      List<StoreModel> allStores = [];

      // The response structure is now: {'stores': [...], 'totalItems': x, ...}
      if (storesResponse['stores'] != null) {
        final storesData = storesResponse['stores'] as List;
        print('Found ${storesData.length} stores');

        for (var storeJson in storesData) {
          try {
            // Create StoreModel with proper error handling
            final store = _createSafeStoreModel(storeJson as Map<String, dynamic>);
            if (store != null) {
              allStores.add(store);
            }
          } catch (e) {
            print('Error parsing store: $e');
            print('Store data: $storeJson');
            // Continue with other stores
          }
        }
      }

      print('Successfully parsed ${allStores.length} stores');

      // Process stores for different categories
      List<StoreModel> topRatedStores = _getTopRatedStores(allStores);
      List<StoreModel> nearbyStores = _getNearbyStores(allStores);

      print('Top rated stores: ${topRatedStores.length}');
      print('Nearby stores: ${nearbyStores.length}');

      if (mounted) {
        setState(() {
          _allStores = allStores;
          _topRatedStores = topRatedStores;
          _nearbyStores = nearbyStores;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching stores: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load stores: $e';
          _isLoading = false;
        });
      }
    }
  }

  // Helper method to create safe StoreModel from JSON with better error handling
  StoreModel? _createSafeStoreModel(Map<String, dynamic> storeData) {
    try {
      // Process the store data with safe conversions
      final processedData = <String, dynamic>{
        ...storeData,
      };

      // Handle nested store data structure if present
      if (storeData.containsKey('store')) {
        final nestedStore = storeData['store'] as Map<String, dynamic>? ?? {};
        processedData.addAll(nestedStore);
      }

      // Safe conversion for numeric fields
      if (processedData['latitude'] != null) {
        processedData['latitude'] = _safeToDouble(processedData['latitude']);
      }
      if (processedData['longitude'] != null) {
        processedData['longitude'] = _safeToDouble(processedData['longitude']);
      }
      if (processedData['rating'] != null) {
        processedData['rating'] = _safeToDouble(processedData['rating']);
      }
      if (processedData['distance'] != null) {
        processedData['distance'] = _safeToDouble(processedData['distance']);
      }
      if (processedData['review_count'] != null) {
        processedData['review_count'] = _safeToInt(processedData['review_count']);
      }
      if (processedData['total_products'] != null) {
        processedData['total_products'] = _safeToInt(processedData['total_products']);
      }

      // Ensure required string fields are present
      processedData['name'] = processedData['name']?.toString() ?? '';
      processedData['address'] = processedData['address']?.toString() ?? '';
      processedData['description'] = processedData['description']?.toString() ?? '';
      processedData['phone'] = processedData['phone']?.toString() ?? '';
      processedData['open_time'] = processedData['open_time']?.toString() ?? '08:00';
      processedData['close_time'] = processedData['close_time']?.toString() ?? '22:00';
      processedData['status'] = processedData['status']?.toString() ?? 'active';

      // Handle image URL
      if (processedData['image_url'] != null && processedData['image_url'].toString().isNotEmpty) {
        processedData['image_url'] = ImageService.getImageUrl(processedData['image_url'].toString());
      }

      // Create owner data if not present
      if (processedData['owner'] == null) {
        processedData['owner'] = {
          'id': processedData['user_id'] ?? 0,
          'name': processedData['owner_name'] ?? 'Unknown Owner',
          'email': processedData['owner_email'] ?? '',
          'phone': processedData['phone'] ?? '',
          'role': 'store',
          'avatar': null,
          'fcm_token': null,
          'created_at': null,
          'updated_at': null,
        };
      }

      return StoreModel.fromJson(processedData);
    } catch (e) {
      print('Error creating StoreModel: $e');
      print('Store data: $storeData');
      return null;
    }
  }

  // Get top rated stores
  List<StoreModel> _getTopRatedStores(List<StoreModel> allStores) {
    List<StoreModel> topRated = List.from(allStores);
    topRated.sort((a, b) => b.rating.compareTo(a.rating));
    return topRated.where((store) => store.rating > 0).take(5).toList();
  }

  // Get nearby stores based on current location
  List<StoreModel> _getNearbyStores(List<StoreModel> allStores) {
    if (_currentPosition == null) {
      // If no location, return stores sorted by rating
      List<StoreModel> fallback = List.from(allStores);
      fallback.sort((a, b) => b.rating.compareTo(a.rating));
      return fallback.take(5).toList();
    }

    List<MapEntry<StoreModel, double>> storesWithDistance = [];

    for (var store in allStores) {
      if (store.latitude != null && store.longitude != null) {
        try {
          double distance = Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            store.latitude!,
            store.longitude!,
          ) / 1000; // Convert to kilometers

          // Create a new store with distance
          final storeWithDistance = store.copyWith(distance: distance);
          storesWithDistance.add(MapEntry(storeWithDistance, distance));
        } catch (e) {
          print('Error calculating distance for store ${store.name}: $e');
        }
      }
    }

    // Sort by distance and take the closest 5
    storesWithDistance.sort((a, b) => a.value.compareTo(b.value));
    return storesWithDistance
        .where((entry) => entry.value <= 10.0) // Within 10km
        .take(5)
        .map((entry) => entry.key)
        .toList();
  }

  void _searchDriver() async {
    setState(() {
      _isSearchingDriver = true;
    });

    _driverSearchController.repeat();

    try {
      // Play search sound
      try {
        await _audioPlayer.play(AssetSource('audio/search_kring.mp3'));
      } catch (e) {
        print('Sound file not found: $e');
      }

      // Show modal with loading animation
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _buildDriverSearchModal(),
      );

      // Simulate driver search
      await Future.delayed(const Duration(seconds: 3));

      if (mounted) {
        Navigator.of(context).pop(); // Close modal

        // Check if ContactDriverPage route exists
        try {
          Navigator.pushNamed(context, '/contact-driver');
        } catch (e) {
          // If route doesn't exist, show a placeholder dialog
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Driver Ditemukan'),
              content: const Text('Fitur contact driver belum tersedia.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      print('Error searching driver: $e');
      if (mounted) {
        Navigator.of(context).pop(); // Close modal
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSearchingDriver = false;
        });
        _driverSearchController.stop();
        _driverSearchController.reset();
      }
    }
  }

  Widget _buildDriverSearchModal() {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Loading animation
            SizedBox(
              width: 150,
              height: 150,
              child: Lottie.asset(
                'assets/animations/loading_animation.json',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      color: GlobalStyle.primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      LucideIcons.car,
                      size: 60,
                      color: GlobalStyle.primaryColor,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Mencari Driver Terdekat...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: GlobalStyle.primaryColor,
                fontFamily: GlobalStyle.fontFamily,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tunggu sebentar, kami sedang\nmencarikan driver terbaik untuk Anda',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontFamily: GlobalStyle.fontFamily,
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _isSearchingDriver = false;
                });
                _driverSearchController.stop();
                _driverSearchController.reset();
              },
              child: Text(
                'Batalkan',
                style: TextStyle(
                  color: Colors.red,
                  fontFamily: GlobalStyle.fontFamily,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<StoreModel> _getFilteredStores() {
    if (_searchQuery.isEmpty) {
      return _allStores;
    }
    return _allStores.where((store) {
      return store.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          store.address.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          store.description.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _buildMainContent(),
      bottomNavigationBar: CustomBottomNavigation(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }

  Widget _buildMainContent() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: CustomScrollView(
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLocationCard(),
                    const SizedBox(height: 16),
                    _buildDriverSearchCard(),
                    const SizedBox(height: 24),
                    _buildSearchBar(),
                    const SizedBox(height: 24),
                    if (_isSearching) ...[
                      _buildSearchResults(),
                    ] else ...[
                      if (_nearbyStores.isNotEmpty) ...[
                        _buildSectionTitle('Toko Terdekat'),
                        const SizedBox(height: 16),
                        _buildHorizontalStoreList(_nearbyStores),
                        const SizedBox(height: 24),
                      ],
                      if (_topRatedStores.isNotEmpty) ...[
                        _buildSectionTitle('Toko Terpopuler'),
                        const SizedBox(height: 16),
                        _buildHorizontalStoreList(_topRatedStores),
                        const SizedBox(height: 24),
                      ],
                      _buildSectionTitle('Semua Toko (${_allStores.length})'),
                      const SizedBox(height: 16),
                      _buildAllStoresList(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      floating: true,
      snap: true,
      elevation: 0,
      backgroundColor: Colors.white,
      title: Text(
        'Del Pick',
        style: TextStyle(
          color: GlobalStyle.primaryColor,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          fontFamily: GlobalStyle.fontFamily,
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(LucideIcons.user, color: GlobalStyle.primaryColor),
          onPressed: () {
            Navigator.pushNamed(context, ProfilePage.route);
          },
        ),
      ],
    );
  }

  Widget _buildLocationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
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
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lokasi Anda',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _userLocation ?? 'Memuat lokasi...',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
                if (_hasLocationPermission && _currentPosition != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Lat: ${_currentPosition!.latitude.toStringAsFixed(4)}, Lng: ${_currentPosition!.longitude.toStringAsFixed(4)}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[500],
                      fontFamily: GlobalStyle.fontFamily,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_isLoadingLocation)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (!_hasLocationPermission)
            IconButton(
              onPressed: _getCurrentLocation,
              icon: Icon(
                LucideIcons.refreshCw,
                color: GlobalStyle.primaryColor,
                size: 20,
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.checkCircle,
                    color: Colors.green[700],
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Aktif',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDriverSearchCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            GlobalStyle.primaryColor,
            GlobalStyle.primaryColor.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: GlobalStyle.primaryColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Driver animation
          SizedBox(
            width: 80,
            height: 80,
            child: Lottie.asset(
              'assets/animations/driver.json',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    LucideIcons.car,
                    color: Colors.white,
                    size: 40,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_userName?.isNotEmpty == true) ...[
                  Text(
                    'Halo, $_userName!',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  _promotionalPhrases[math.Random().nextInt(_promotionalPhrases.length)],
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _searchDriver,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: GlobalStyle.primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(LucideIcons.car, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Cari Driver',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
            _isSearching = value.isNotEmpty;
          });
        },
        decoration: InputDecoration(
          hintText: 'Cari toko atau makanan...',
          hintStyle: TextStyle(
            color: Colors.grey[400],
            fontFamily: GlobalStyle.fontFamily,
          ),
          prefixIcon: Icon(
            LucideIcons.search,
            color: Colors.grey[400],
          ),
          suffixIcon: _isSearching
              ? IconButton(
            icon: Icon(
              LucideIcons.x,
              color: Colors.grey[400],
            ),
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
                _isSearching = false;
              });
            },
          )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    final filteredStores = _getFilteredStores();

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (filteredStores.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              LucideIcons.searchX,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Tidak ada toko yang ditemukan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
                fontFamily: GlobalStyle.fontFamily,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Coba gunakan kata kunci yang berbeda',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
                fontFamily: GlobalStyle.fontFamily,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hasil Pencarian (${filteredStores.length})',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            fontFamily: GlobalStyle.fontFamily,
          ),
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredStores.length,
          itemBuilder: (context, index) {
            return _buildStoreCard(filteredStores[index]);
          },
        ),
      ],
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
            margin: EdgeInsets.only(right: index == stores.length - 1 ? 0 : 16),
            child: _buildHorizontalStoreCard(store),
          );
        },
      ),
    );
  }

  Widget _buildHorizontalStoreCard(StoreModel store) {
    return GestureDetector(
      onTap: () {
        print('🔍 HomePage: Navigating to store with ID: ${store.storeId}');
        Navigator.pushNamed(
            context,
            StoreDetail.route,
            arguments: {
              'storeId': store.storeId,
              'storeName': store.name, // Optional: untuk debugging
            }
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 120,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                color: Colors.grey[300],
              ),
              child: Stack(
                children: [
                  if (store.imageUrl != null && store.imageUrl!.isNotEmpty)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      child: Image.network(
                        store.imageUrl!,
                        width: double.infinity,
                        height: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: double.infinity,
                            height: 120,
                            color: Colors.grey[300],
                            child: Icon(
                              LucideIcons.imageOff,
                              color: Colors.grey[600],
                              size: 40,
                            ),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            width: double.infinity,
                            height: 120,
                            color: Colors.grey[300],
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        },
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      height: 120,
                      color: Colors.grey[300],
                      child: Icon(
                        LucideIcons.store,
                        color: Colors.grey[600],
                        size: 40,
                      ),
                    ),
                  if (store.rating > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.yellow,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              store.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (store.distance != null)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: GlobalStyle.primaryColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${store.distance!.toStringAsFixed(1)} km',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
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
                    const SizedBox(height: 8),
                    if (store.description.isNotEmpty)
                      Text(
                        store.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                          fontFamily: GlobalStyle.fontFamily,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(
                          LucideIcons.clock,
                          size: 12,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${store.openTime} - ${store.closeTime}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                            fontFamily: GlobalStyle.fontFamily,
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

  Widget _buildAllStoresList() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              LucideIcons.alertCircle,
              size: 64,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Terjadi Kesalahan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red[600],
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
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchStores,
              style: ElevatedButton.styleFrom(
                backgroundColor: GlobalStyle.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (_allStores.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              LucideIcons.store,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Belum Ada Toko',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
                fontFamily: GlobalStyle.fontFamily,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Saat ini belum ada toko yang tersedia',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
                fontFamily: GlobalStyle.fontFamily,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _allStores.length,
      itemBuilder: (context, index) {
        return _buildStoreCard(_allStores[index]);
      },
    );
  }

  Widget _buildStoreCard(StoreModel store) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          // FIX: Gunakan format yang sama dengan horizontal store card
          print('🔍 HomePage: Navigating to store with ID: ${store.storeId}');
          Navigator.pushNamed(
            context,
            StoreDetail.route,
            arguments: {
              'storeId': store.storeId,  // Ubah dari {'store': store} ke format ini
              'storeName': store.name,  // Optional: untuk debugging
            },
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 180,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                color: Colors.grey[300],
              ),
              child: Stack(
                children: [
                  if (store.imageUrl != null && store.imageUrl!.isNotEmpty)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      child: Image.network(
                        store.imageUrl!,
                        width: double.infinity,
                        height: 180,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: double.infinity,
                            height: 180,
                            color: Colors.grey[300],
                            child: Icon(
                              LucideIcons.imageOff,
                              color: Colors.grey[600],
                              size: 50,
                            ),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            width: double.infinity,
                            height: 180,
                            color: Colors.grey[300],
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        },
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      height: 180,
                      color: Colors.grey[300],
                      child: Icon(
                        LucideIcons.store,
                        color: Colors.grey[600],
                        size: 50,
                      ),
                    ),
                  if (store.rating > 0)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.yellow,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              store.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (store.distance != null)
                    Positioned(
                      bottom: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: GlobalStyle.primaryColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${store.distance!.toStringAsFixed(1)} km',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        LucideIcons.clock,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${store.openTime} - ${store.closeTime}',
                        style: TextStyle(
                          fontSize: 14.0,
                          color: Colors.grey[600],
                          fontFamily: GlobalStyle.fontFamily,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: store.status.name == 'active'
                              ? Colors.green.withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          store.status.name == 'active' ? 'Buka' : 'Tutup',
                          style: TextStyle(
                            fontSize: 12,
                            color: store.status.name == 'active'
                                ? Colors.green[700]
                                : Colors.red[700],
                            fontWeight: FontWeight.bold,
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
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
}