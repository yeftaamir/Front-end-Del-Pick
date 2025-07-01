// lib/Views/Customers/home_cust.dart - Enhanced with Driver Search
import 'dart:convert';
import 'dart:math' as math;
import 'package:geocoding/geocoding.dart';
import 'package:del_pick/Models/store.dart';
import 'package:del_pick/Models/driver.dart'; // Import DriverModel
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
import 'package:del_pick/Services/driver_service.dart'; // Import DriverService
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
            _userName =
                tokenUserData['user']?['name'] ?? tokenUserData['name'] ?? '';
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
            _userName =
                tokenUserData['user']?['name'] ?? tokenUserData['name'] ?? '';
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
            final store =
            _createSafeStoreModel(storeJson as Map<String, dynamic>);
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
        processedData['review_count'] =
            _safeToInt(processedData['review_count']);
      }
      if (processedData['total_products'] != null) {
        processedData['total_products'] =
            _safeToInt(processedData['total_products']);
      }

      // Ensure required string fields are present
      processedData['name'] = processedData['name']?.toString() ?? '';
      processedData['address'] = processedData['address']?.toString() ?? '';
      processedData['description'] =
          processedData['description']?.toString() ?? '';
      processedData['phone'] = processedData['phone']?.toString() ?? '';
      processedData['open_time'] =
          processedData['open_time']?.toString() ?? '08:00';
      processedData['close_time'] =
          processedData['close_time']?.toString() ?? '22:00';
      processedData['status'] = processedData['status']?.toString() ?? 'active';

      // Handle image URL
      if (processedData['image_url'] != null &&
          processedData['image_url'].toString().isNotEmpty) {
        processedData['image_url'] =
            ImageService.getImageUrl(processedData['image_url'].toString());
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
          ) /
              1000; // Convert to kilometers

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

  // ========================================
  // 🚗 ENHANCED DRIVER SEARCH IMPLEMENTATION
  // ========================================

  void _searchDriver() async {
    setState(() {
      _isSearchingDriver = true;
    });

    try {
      // Play search sound
      try {
        await _audioPlayer.play(AssetSource('audio/search_kring.mp3'));
      } catch (e) {
        print('Sound file not found: $e');
      }

      // Show enhanced search modal
      _showDriverSearchModal();

      print('🔍 HomePage: Starting driver search...');

      // Check if user location is available
      if (_currentPosition == null || !_hasLocationPermission) {
        print('⚠️ HomePage: Location not available, requesting location access...');

        // Try to get location first
        await _getCurrentLocation();

        if (_currentPosition == null) {
          throw Exception('Lokasi diperlukan untuk mencari driver terdekat.\nSilakan aktifkan GPS dan izinkan akses lokasi.');
        }
      }

      print('📍 HomePage: User location: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');

      // Start animation
      _driverSearchController.repeat();

      // Search for nearest active driver
// Search for nearest active driver
      final nearestDriver = await DriverService.findNearestActiveDriver(
        userLatitude: _currentPosition!.latitude,
        userLongitude: _currentPosition!.longitude,
        maxRadius: 15, // 15km radius
        minRating: 3, // minimum 3.0 rating
      );

      // Stop animation
      _driverSearchController.stop();
      _driverSearchController.reset();

      if (mounted) {
        Navigator.of(context).pop(); // Close search modal

        if (nearestDriver != null) {
          print('✅ HomePage: Driver found: ${nearestDriver['name']}');
          print('   📏 Distance: ${nearestDriver['distance_km']?.toStringAsFixed(2)}km');
          print('   ⭐ Rating: ${nearestDriver['rating']}');

          // Create DriverModel from the response
          final driverModel = _createDriverModelFromResponse(nearestDriver);

          // Show success and navigate to contact driver
          await _showDriverFoundDialog(driverModel, nearestDriver['distance_km']);

        } else {
          print('❌ HomePage: No drivers found');
          _showNoDriverDialog();
        }
      }

    } catch (e) {
      print('❌ HomePage: Error searching driver: $e');

      if (mounted) {
        Navigator.of(context).pop(); // Close modal
        _showErrorDialog('Gagal mencari driver: $e');
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

  /// Create DriverModel from API response
  DriverModel _createDriverModelFromResponse(Map<String, dynamic> driverData) {
    try {
      // Handle nested user data
      final userData = driverData['user'] ?? driverData;

      // Create safe user data
      final safeUserData = {
        'id': userData['id'] ?? 0,
        'name': userData['name'] ?? 'Driver',
        'email': userData['email'] ?? '',
        'phone': userData['phone'] ?? '',
        'role': 'driver',
        'avatar': userData['avatar'],
        'fcm_token': userData['fcm_token'],
        'created_at': userData['created_at'],
        'updated_at': userData['updated_at'],
      };

      // Create safe driver data
      final safeDriverData = {
        'id': driverData['id'] ?? driverData['driver_id'] ?? 0,
        'license_number': driverData['license_number'] ?? '',
        'vehicle_plate': driverData['vehicle_plate'] ?? '',
        'rating': _safeToDouble(driverData['rating'] ?? 5.0),
        'reviews_count': _safeToInt(driverData['reviews_count'] ?? 0),
        'status': driverData['status'] ?? 'active',
        'latitude': _safeToDouble(driverData['latitude']),
        'longitude': _safeToDouble(driverData['longitude']),
        'created_at': driverData['created_at'],
        'updated_at': driverData['updated_at'],
      };

      // Combine for DriverModel.fromJson
      final combinedData = {
        'user': safeUserData,
        'driver': safeDriverData,
        ...safeDriverData, // Also include driver data at root level for compatibility
      };

      print('🏗️ HomePage: Creating DriverModel with data: $combinedData');

      return DriverModel.fromJson(combinedData);

    } catch (e) {
      print('❌ HomePage: Error creating DriverModel: $e');
      print('   Raw data: $driverData');

      // Create fallback driver model
      return DriverModel.fromJson({
        'user': {
          'id': 0,
          'name': driverData['name'] ?? 'Driver',
          'email': driverData['email'] ?? '',
          'phone': driverData['phone'] ?? '',
          'role': 'driver',
        },
        'driver': {
          'id': 0,
          'license_number': driverData['license_number'] ?? '',
          'vehicle_plate': driverData['vehicle_plate'] ?? '',
          'rating': _safeToDouble(driverData['rating'] ?? 5.0),
          'reviews_count': 0,
          'status': 'active',
          'latitude': _safeToDouble(driverData['latitude']),
          'longitude': _safeToDouble(driverData['longitude']),
        },
      });
    }
  }

  /// Show enhanced driver search modal
  void _showDriverSearchModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Enhanced loading animation
              SizedBox(
                width: 180,
                height: 180,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer spinning circle
                    AnimatedBuilder(
                      animation: _driverSearchController,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _driverSearchController.value * 2 * math.pi,
                          child: Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: GlobalStyle.primaryColor.withOpacity(0.3),
                                width: 3,
                              ),
                            ),
                            child: Container(
                              margin: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: GlobalStyle.primaryColor,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    // Center driver icon
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: GlobalStyle.primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        LucideIcons.car,
                        size: 40,
                        color: GlobalStyle.primaryColor,
                      ),
                    ),

                    // Scanning dots
                    ...List.generate(3, (index) {
                      return AnimatedBuilder(
                        animation: _driverSearchController,
                        builder: (context, child) {
                          final angle = (_driverSearchController.value * 2 * math.pi) +
                              (index * math.pi * 2 / 3);
                          final radius = 70.0;
                          final x = math.cos(angle) * radius;
                          final y = math.sin(angle) * radius;

                          return Transform.translate(
                            offset: Offset(x, y),
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: GlobalStyle.primaryColor.withOpacity(0.8),
                                shape: BoxShape.circle,
                              ),
                            ),
                          );
                        },
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'Mencari Driver Terdekat',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: GlobalStyle.primaryColor,
                  fontFamily: GlobalStyle.fontFamily,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                'Sedang mencari driver terbaik\ndi sekitar lokasi Anda...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontFamily: GlobalStyle.fontFamily,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 20),

              // Location info if available
              if (_currentPosition != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.mapPin,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _userLocation ?? 'Lokasi Anda',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontFamily: GlobalStyle.fontFamily,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Cancel button
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
                    color: Colors.grey[600],
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show driver found success dialog
  Future<void> _showDriverFoundDialog(DriverModel driver, double? distance) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success animation
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  size: 60,
                  color: Colors.green,
                ),
              ),

              const SizedBox(height: 20),

              Text(
                'Driver Ditemukan!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                  fontFamily: GlobalStyle.fontFamily,
                ),
              ),

              const SizedBox(height: 16),

              // Driver preview card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    // Driver avatar
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: GlobalStyle.primaryColor,
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: driver.avatar != null && driver.avatar!.isNotEmpty
                            ? Image.network(
                          driver.avatar!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: GlobalStyle.primaryColor.withOpacity(0.1),
                              child: Icon(
                                LucideIcons.user,
                                color: GlobalStyle.primaryColor,
                                size: 30,
                              ),
                            );
                          },
                        )
                            : Container(
                          color: GlobalStyle.primaryColor.withOpacity(0.1),
                          child: Icon(
                            LucideIcons.user,
                            color: GlobalStyle.primaryColor,
                            size: 30,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Driver info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            driver.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                              fontFamily: GlobalStyle.fontFamily,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.star, color: Colors.amber, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                driver.formattedRating,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontFamily: GlobalStyle.fontFamily,
                                ),
                              ),
                            ],
                          ),
                          if (distance != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(LucideIcons.mapPin, size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  '${distance.toStringAsFixed(1)} km dari Anda',
                                  style: TextStyle(
                                    fontSize: 12,
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

              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  // Cancel button
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[600],
                        side: BorderSide(color: Colors.grey[300]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Batal'),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Contact driver button
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop(); // Close dialog
                        _navigateToContactDriver(driver);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GlobalStyle.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Hubungi Driver',
                        style: TextStyle(fontWeight: FontWeight.bold),
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

  /// Navigate to contact driver page with driver data
  void _navigateToContactDriver(DriverModel driver) {
    try {
      print('🚀 HomePage: Navigating to ContactDriverPage with driver: ${driver.name}');

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ContactDriverPage(
            driver: driver,
            serviceType: 'jastip',
          ),
        ),
      );
    } catch (e) {
      print('❌ HomePage: Error navigating to ContactDriverPage: $e');
      _showErrorDialog('Gagal membuka halaman driver: $e');
    }
  }

  /// Show no driver available dialog
  void _showNoDriverDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              LucideIcons.userX,
              color: Colors.orange,
              size: 28,
            ),
            const SizedBox(width: 12),
            const Text('Driver Tidak Tersedia'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Saat ini tidak ada driver yang tersedia di sekitar lokasi Anda.',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tips:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Coba lagi dalam beberapa menit\n'
                        '• Pastikan lokasi GPS aktif\n'
                        '• Periksa koneksi internet Anda',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tutup'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _searchDriver(); // Try search again
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: GlobalStyle.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  /// Show error dialog
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 28,
            ),
            const SizedBox(width: 12),
            const Text('Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'OK',
              style: TextStyle(color: GlobalStyle.primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  // ========================================
  // EXISTING METHODS (unchanged)
  // ========================================

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
                        _buildSectionTitleWithSeeAll(
                          'Toko Terdekat',
                          onSeeAll: () {
                            Navigator.pushNamed(context, '/nearby-stores',
                                arguments: {
                                  'stores': _nearbyStores,
                                  'title': 'Toko Terdekat'
                                });
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildHorizontalStoreList(_nearbyStores),
                        const SizedBox(height: 24),
                      ],
                      if (_topRatedStores.isNotEmpty) ...[
                        _buildSectionTitleWithSeeAll(
                          'Toko Terpopuler',
                          onSeeAll: () {
                            Navigator.pushNamed(context, '/top-rated-stores',
                                arguments: {
                                  'stores': _topRatedStores,
                                  'title': 'Toko Terpopuler'
                                });
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildHorizontalStoreList(_topRatedStores),
                        const SizedBox(height: 24),
                      ],
                      _buildSectionTitleWithSeeAll(
                        'Semua Toko (${_allStores.length})',
                        onSeeAll: () {
                          Navigator.pushNamed(context, '/all-stores',
                              arguments: {
                                'stores': _allStores,
                                'title': 'Semua Toko'
                              });
                        },
                      ),
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
                  _promotionalPhrases[
                  math.Random().nextInt(_promotionalPhrases.length)],
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _isSearchingDriver ? null : _searchDriver,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: GlobalStyle.primaryColor,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isSearchingDriver) ...[
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              GlobalStyle.primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Mencari...',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ] else ...[
                        const Icon(LucideIcons.search, size: 18),
                        const SizedBox(width: 8),
                        const Text(
                          'Cari Driver',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
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
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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

  Widget _buildSectionTitleWithSeeAll(String title, {VoidCallback? onSeeAll}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            fontFamily: GlobalStyle.fontFamily,
          ),
        ),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Lihat Semua',
                  style: TextStyle(
                    color: GlobalStyle.primaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  LucideIcons.arrowRight,
                  color: GlobalStyle.primaryColor,
                  size: 16,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildHorizontalStoreList(List<StoreModel> stores) {
    return SizedBox(
      height: 220, // Dikurangi dari 280 ke 220
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: stores.length,
        itemBuilder: (context, index) {
          final store = stores[index];
          return Container(
            width: 160, // Dikurangi dari 200 ke 160
            margin: EdgeInsets.only(
                right: index == stores.length - 1 ? 0 : 12), // Dikurangi margin
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
        Navigator.pushNamed(context, StoreDetail.route, arguments: {
          'storeId': store.storeId,
          'storeName': store.name,
        });
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
              height: 110, // Dikurangi dari 120 ke 100
              decoration: BoxDecoration(
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
                color: Colors.grey[300],
              ),
              child: Stack(
                children: [
                  if (store.imageUrl != null && store.imageUrl!.isNotEmpty)
                    ClipRRect(
                      borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                      child: Image.network(
                        store.imageUrl!,
                        width: double.infinity,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: double.infinity,
                            height: 100,
                            color: Colors.grey[300],
                            child: Icon(
                              LucideIcons.imageOff,
                              color: Colors.grey[600],
                              size: 30, // Dikurangi dari 40
                            ),
                          );
                        },
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      height: 100,
                      color: Colors.grey[300],
                      child: Icon(
                        LucideIcons.store,
                        color: Colors.grey[600],
                        size: 30,
                      ),
                    ),
                  if (store.rating > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.yellow,
                              size: 12,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              store.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (store.distance != null)
                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: GlobalStyle.primaryColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${store.distance!.toStringAsFixed(1)} km',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
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
                padding: const EdgeInsets.all(8.0), // Dikurangi dari 12
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.name,
                      style: TextStyle(
                        fontSize: 14, // Dikurangi dari 16
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        fontFamily: GlobalStyle.fontFamily,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      store.address,
                      style: TextStyle(
                        fontSize: 11, // Dikurangi dari 12
                        color: Colors.grey[600],
                        fontFamily: GlobalStyle.fontFamily,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(
                          LucideIcons.clock,
                          size: 10,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            '${store.openTime} - ${store.closeTime}',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey[600],
                              fontFamily: GlobalStyle.fontFamily,
                            ),
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

  Widget _buildSliderStoreCard(StoreModel store) {
    return GestureDetector(
      onTap: () {
        print('🔍 HomePage: Navigating to store with ID: ${store.storeId}');
        Navigator.pushNamed(
          context,
          StoreDetail.route,
          arguments: {
            'storeId': store.storeId,
            'storeName': store.name,
          },
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
              height: 140,
              decoration: BoxDecoration(
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
                color: Colors.grey[300],
              ),
              child: Stack(
                children: [
                  if (store.imageUrl != null && store.imageUrl!.isNotEmpty)
                    ClipRRect(
                      borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                      child: Image.network(
                        store.imageUrl!,
                        width: double.infinity,
                        height: 140,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: double.infinity,
                            height: 140,
                            color: Colors.grey[300],
                            child: Icon(
                              LucideIcons.imageOff,
                              color: Colors.grey[600],
                              size: 40,
                            ),
                          );
                        },
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      height: 140,
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
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
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                      ],
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
                            fontSize: 11,
                            color: Colors.grey[600],
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: store.status.name == 'active'
                                ? Colors.green.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            store.status.name == 'active' ? 'Buka' : 'Tutup',
                            style: TextStyle(
                              fontSize: 10,
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
                padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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

    // Tampilkan maksimal 5 toko dalam sliding view
    final displayStores = _allStores.take(5).toList();

    return SizedBox(
      height: 270, // Naikkan dari 250 ke 270
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: displayStores.length,
        itemBuilder: (context, index) {
          final store = displayStores[index];
          return Container(
            width: 300, // Naikkan dari 280 ke 300
            margin: EdgeInsets.only(
                right: index == displayStores.length - 1 ? 0 : 16),
            child: _buildSliderStoreCard(store),
          );
        },
      ),
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
              'storeId':
              store.storeId, // Ubah dari {'store': store} ke format ini
              'storeName': store.name, // Optional: untuk debugging
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
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
                color: Colors.grey[300],
              ),
              child: Stack(
                children: [
                  if (store.imageUrl != null && store.imageUrl!.isNotEmpty)
                    ClipRRect(
                      borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
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