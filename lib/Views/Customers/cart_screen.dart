import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'dart:async';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Models/menu_item.dart';
import 'package:del_pick/Views/Customers/location_access.dart';
import 'package:del_pick/Views/Customers/history_detail.dart';
import 'package:del_pick/Models/store.dart';
import 'package:del_pick/Models/order.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geocoding/geocoding.dart';
import 'package:lucide_icons/lucide_icons.dart';

// Import required services
import 'package:del_pick/Services/order_service.dart';
import 'package:del_pick/Services/store_service.dart';
import 'package:del_pick/Services/image_service.dart';
import 'package:del_pick/Services/auth_service.dart';

import '../../Models/order_enum.dart';
import '../../Models/order_item.dart';

class CartScreen extends StatefulWidget {
  static const String route = "/Customers/Cart";
  final int storeId;
  final List<MenuItemModel> cartItems;
  final Map<int, int>? itemQuantities;

  final double? customerLatitude;
  final double? customerLongitude;
  final String? customerAddress;
  final double? storeLatitude;
  final double? storeLongitude;
  final double? storeDistance;

  const CartScreen({
    Key? key,
    required this.cartItems,
    required this.storeId,
    required this.itemQuantities,
    this.customerLatitude,
    this.customerLongitude,
    this.customerAddress,
    this.storeLatitude,
    this.storeLongitude,
    this.storeDistance,
  }) : super(key: key);

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> with TickerProviderStateMixin {
  // ✅ PERBAIKAN: Enhanced state management dengan quantity control
  double _estimatedDeliveryFee = 0;
  String? _deliveryAddress;
  double? _latitude;
  double? _longitude;
  double? _storeLatitude;
  double? _storeLongitude;
  double? _storeDistance;
  String? _errorMessage;
  bool _isLoading = false;
  bool _isCreatingOrder = false;
  String? _orderNotes = '';

  // ✅ FIXED: Enhanced anti-double submission
  bool _hasSubmittedOrder = false;
  Timer? _submitDebounceTimer;
  DateTime? _lastSubmitAttempt;
  static const Duration _submitCooldown = Duration(seconds: 3);

  // ✅ BARU: Local quantity management for cart editing
  Map<int, int> _localQuantities = {};

  // Location specific variables
  bool _isLoadingLocation = false;
  bool _hasLocationPermission = false;
  Position? _currentPosition;
  String? _userLocation = '';
  Map<String, dynamic>? _userData;

  // Store data
  StoreModel? _storeDetail;

  // Audio player instance
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Animation controllers
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late List<AnimationController> _cardControllers;
  late List<Animation<Offset>> _cardAnimations;

  // ✅ FIXED: Notes controller for driver
  late TextEditingController _notesController;

  // ✅ PERBAIKAN: Getter yang sesuai dengan struktur backend

  // Items subtotal = total harga items (sesuai total_amount di backend)
  double get itemsSubtotal {
    double total = 0;
    for (var item in widget.cartItems) {
      final quantity = _getItemQuantity(item);
      if (quantity > 0) {
        total += item.price * quantity;
      }
    }
    return total;
  }

  // Grand total = subtotal + delivery fee (sesuai backend structure)
  double get grandTotal {
    return itemsSubtotal + _estimatedDeliveryFee;
  }

  // ✅ BARU: Helper to get item quantity with local updates
  int _getItemQuantity(MenuItemModel item) {
    return _localQuantities[item.id] ?? widget.itemQuantities?[item.id] ?? 0;
  }

  // ✅ BARU: Update local quantity
  void _updateItemQuantity(MenuItemModel item, int newQuantity) {
    setState(() {
      if (newQuantity <= 0) {
        _localQuantities.remove(item.id);
      } else {
        _localQuantities[item.id] = newQuantity;
      }
    });

    // Recalculate delivery fee if distance changed due to total weight/value
    _calculateEstimatedDeliveryFee();
  }

  // ✅ BARU: Get items with positive quantity
  List<MenuItemModel> get activeItems {
    return widget.cartItems
        .where((item) => _getItemQuantity(item) > 0)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeAnimations();
    _initializeStoreLocation();
    _loadInitialData();
    _initializeLocation();

    // ✅ BARU: Initialize local quantities from widget
    _localQuantities = Map<int, int>.from(widget.itemQuantities ?? {});
  }

  // ✅ FIXED: Initialize controllers properly
  void _initializeControllers() {
    _notesController = TextEditingController();
    _notesController.addListener(() {
      _orderNotes = _notesController.text;
    });
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _cardControllers = List.generate(
      4, // Location, items, payment, submit button
      (index) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 600 + (index * 100)),
      ),
    );

    _cardAnimations = _cardControllers.map((controller) {
      return Tween<Offset>(
        begin: const Offset(0, 0.3),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeOutCubic,
      ));
    }).toList();

    _startCardAnimations();
  }

  void _startCardAnimations() {
    for (int i = 0; i < _cardControllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted && _cardControllers[i].isCompleted == false) {
          _cardControllers[i].forward();
        }
      });
    }
  }

  void _initializeStoreLocation() {
    // Use data from store_detail if available
    if (widget.storeLatitude != null && widget.storeLongitude != null) {
      _storeLatitude = widget.storeLatitude;
      _storeLongitude = widget.storeLongitude;
      print(
          '✅ CartScreen: Store location initialized: $_storeLatitude, $_storeLongitude');
    }

    if (widget.storeDistance != null) {
      _storeDistance = widget.storeDistance;
      print('✅ CartScreen: Store distance initialized: $_storeDistance km');
    }

    if (widget.customerAddress != null) {
      _deliveryAddress = widget.customerAddress;
      print('✅ CartScreen: Customer address initialized: $_deliveryAddress');
    }

    if (widget.customerLatitude != null && widget.customerLongitude != null) {
      _latitude = widget.customerLatitude;
      _longitude = widget.customerLongitude;
      print(
          '✅ CartScreen: Customer location initialized: $_latitude, $_longitude');
    }

    _calculateEstimatedDeliveryFee();
  }

  void _calculateEstimatedDeliveryFee() {
    if (_storeDistance != null) {
      setState(() {
        double fee = calculateDeliveryFee(_storeDistance!);
        _estimatedDeliveryFee = fee;
      });
      print(
          '✅ CartScreen: Estimated delivery fee calculated: ${GlobalStyle.formatRupiah(_estimatedDeliveryFee)}');
      return;
    }

    if (_latitude != null &&
        _longitude != null &&
        _storeLatitude != null &&
        _storeLongitude != null) {
      _updateDeliveryFee();
      print('✅ CartScreen: Estimated delivery fee calculated from coordinates');
    } else {
      print(
          '⚠️ CartScreen: Cannot calculate estimated delivery fee - missing location data');
    }
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // ✅ PERBAIKAN: Validate customer access using new AuthService method
      final hasAccess = await AuthService.validateCustomerAccess();
      if (!hasAccess) {
        throw Exception('Invalid customer access. Please login as customer.');
      }

      // Get user data
      _userData = await AuthService.getCustomerData();
      if (_userData == null) {
        throw Exception('Unable to get customer data');
      }

      print('✅ CartScreen: Customer data loaded - ${_userData!['name']}');

      // Get store details if location is not available
      if (_storeLatitude == null || _storeLongitude == null) {
        final storeData =
            await StoreService.getStoreById(widget.storeId.toString());

        if (storeData['success'] == true && storeData['data'] != null) {
          final store = storeData['data'];
          _storeDetail = StoreModel.fromJson(store);

          if (_storeDetail != null) {
            _storeLatitude = _storeDetail!.latitude;
            _storeLongitude = _storeDetail!.longitude;
            print(
                '✅ CartScreen: Store location loaded from API: $_storeLatitude, $_storeLongitude');
            _updateDeliveryFee();
          }
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load data: $e';
        _isLoading = false;
      });
      print('❌ CartScreen: Error loading initial data: $e');
    }
  }

  void _initializeLocation() {
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      var status = await Permission.location.status;
      if (!status.isGranted) {
        status = await Permission.location.request();
        if (!status.isGranted) {
          throw Exception('Location permission denied');
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      String locationText = await _getAddressFromCoordinates(position);

      setState(() {
        _currentPosition = position;
        _latitude = position.latitude;
        _longitude = position.longitude;
        _userLocation = locationText;

        if (_deliveryAddress == null || _deliveryAddress!.isEmpty) {
          _deliveryAddress = locationText;
        }

        _hasLocationPermission = true;
        _isLoadingLocation = false;
      });

      print('✅ CartScreen: User location obtained: $_latitude, $_longitude');
      _updateDeliveryFee();
    } catch (e) {
      print('❌ CartScreen: Error getting location: $e');
      setState(() {
        _hasLocationPermission = false;
        _userLocation = 'Lokasi tidak tersedia';
        _isLoadingLocation = false;
      });
    }
  }

  void _updateDeliveryFee() {
    print('🔄 CartScreen: Attempting to update delivery fee...');
    print('   - User location: $_latitude, $_longitude');
    print('   - Store location: $_storeLatitude, $_storeLongitude');

    if (_latitude != null &&
        _longitude != null &&
        _storeLatitude != null &&
        _storeLongitude != null) {
      // ✅ PERBAIKAN: Use exact haversine algorithm from backend
      _storeDistance = _calculateHaversineDistance(
          _latitude!, _longitude!, _storeLatitude!, _storeLongitude!);

      final calculatedFee = calculateDeliveryFee(_storeDistance!);

      setState(() {
        _estimatedDeliveryFee = calculatedFee;
      });

      print('✅ CartScreen: Delivery fee updated successfully!');
      print('   - Distance: ${_getFormattedDistance()}');
      print('   - Fee: ${GlobalStyle.formatRupiah(_estimatedDeliveryFee)}');
    } else {
      print(
          '⚠️ CartScreen: Cannot update delivery fee - missing location data');
    }
  }

  double _calculateHaversineDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // ✅ SAMA: Earth radius 6371 km

    // Convert degrees to radians
    double _degreesToRadians(double degrees) => degrees * (pi / 180);

    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c; // ✅ SAMA: Hasil dalam kilometer
  }

// ✅ SAMA: Formula delivery fee calculation
  double calculateDeliveryFee(double distanceInKm) {
    double rawFee = distanceInKm * 2000; // ✅ SAMA: × 2000
    return rawFee.ceil().toDouble(); // ✅ SAMA: Math.ceil()
  }

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
    return 'Balige, North Sumatra';
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
                      'Lokasi Pengiriman',
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
                    if (_storeDistance != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.route,
                            size: 12,
                            color: GlobalStyle.primaryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Jarak: ${_getFormattedDistance()} (Haversine)',
                            style: TextStyle(
                              fontSize: 12,
                              color: GlobalStyle.primaryColor,
                              fontWeight: FontWeight.w500,
                              fontFamily: GlobalStyle.fontFamily,
                            ),
                          ),
                        ],
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
          const SizedBox(height: 16),

          // ✅ FIXED: Enhanced Notes input field for driver
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.note_add_outlined,
                    size: 16,
                    color: GlobalStyle.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Catatan untuk Driver',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                      fontFamily: GlobalStyle.fontFamily,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                decoration: InputDecoration(
                  hintText:
                      'Contoh: Tolong hubungi saat sampai, rumah cat biru di sebelah warung',
                  hintStyle: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: GlobalStyle.primaryColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  fillColor: Colors.grey[50],
                  filled: true,
                ),
                maxLines: 3,
                maxLength: 200,
                style: const TextStyle(fontSize: 14),
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 8),
              // Helper text
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 14,
                      color: Colors.blue[600],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tips: Berikan alamat yang jelas agar driver mudah menemukan lokasi Anda',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ✅ BARU: Widget untuk quantity control
  Widget _buildQuantityControls(MenuItemModel item) {
    final quantity = _getItemQuantity(item);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: quantity > 1 ? GlobalStyle.primaryColor : Colors.grey[300],
            borderRadius: BorderRadius.circular(6),
          ),
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: Icon(
              Icons.remove,
              size: 16,
              color: quantity > 1 ? Colors.white : Colors.grey[500],
            ),
            onPressed: quantity > 1
                ? () => _updateItemQuantity(item, quantity - 1)
                : null,
          ),
        ),
        Container(
          width: 40,
          alignment: Alignment.center,
          child: Text(
            '$quantity',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: GlobalStyle.fontColor,
            ),
          ),
        ),
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: GlobalStyle.primaryColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: const Icon(
              Icons.add,
              size: 16,
              color: Colors.white,
            ),
            onPressed: () => _updateItemQuantity(item, quantity + 1),
          ),
        ),
      ],
    );
  }

  // ✅ BARU: Widget untuk remove item completely
  Widget _buildRemoveButton(MenuItemModel item) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(
          Icons.delete_outline,
          size: 16,
          color: Colors.red[600],
        ),
        onPressed: () => _showRemoveItemDialog(item),
      ),
    );
  }

  Future<void> _showRemoveItemDialog(MenuItemModel item) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Hapus Item'),
        content: Text('Hapus "${item.name}" dari keranjang?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Batal',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Hapus',
              style: TextStyle(
                color: Colors.red[600],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldRemove == true) {
      _updateItemQuantity(item, 0);
    }
  }

  // ✅ PERBAIKAN: Updated untuk struktur backend yang baru
  List<Map<String, dynamic>> _prepareOrderItems() {
    return activeItems.map((item) {
      final quantity = _getItemQuantity(item);
      return {
        'id': item.id, // Frontend menggunakan 'id'
        'menu_item_id': item.id, // Backend expect 'menu_item_id'
        'quantity': quantity,
        'notes': '',
      };
    }).toList();
  }

  // ✅ PERBAIKAN: Updated payment details widget
  Widget _buildPaymentDetails() {
    return _buildCard(
      index: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.payment, color: GlobalStyle.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Rincian Pembayaran',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: GlobalStyle.fontColor,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  // ✅ FIXED: Subtotal sesuai backend (total_amount)
                  _buildPaymentRow('Subtotal', itemsSubtotal),
                  const SizedBox(height: 4),
                  // Helper text untuk subtotal
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${activeItems.length} item × harga per-pcs',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ✅ FIXED: Biaya pengiriman sesuai backend (delivery_fee)
                  _buildPaymentRow('Biaya Pengiriman', _estimatedDeliveryFee),
                  if (_storeDistance != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'Jarak: ${_getFormattedDistance()} × Rp2.500/km',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const Divider(thickness: 1, height: 24),

                  // ✅ FIXED: Grand total = subtotal + delivery fee
                  _buildPaymentRow('Total Pembayaran', grandTotal,
                      isTotal: true),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ✅ ENHANCED: Info section dengan penjelasan struktur pembayaran
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Colors.blue[700],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Struktur Pembayaran DelPick',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow('Subtotal', 'Total harga semua item pesanan'),
                  _buildInfoRow('Biaya Pengiriman',
                      'Dihitung berdasarkan jarak Toko - IT Del'),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.monetization_on_outlined,
                          size: 14,
                          color: Colors.green[700],
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Pembayaran: Tunai kepada driver (COD)',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.green[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ BARU: Helper widget untuk info row
  Widget _buildInfoRow(String label, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: TextStyle(
              fontSize: 11,
              color: Colors.blue[600],
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 11,
              color: Colors.blue[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              description,
              style: TextStyle(
                fontSize: 11,
                color: Colors.blue[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _slideController.dispose();
    _pulseController.dispose();
    for (var controller in _cardControllers) {
      controller.dispose();
    }
    _audioPlayer.dispose();
    // ✅ FIXED: Dispose notes controller and timer
    _notesController.dispose();
    _submitDebounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _playSound(String assetPath) async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource(assetPath));
    } catch (e) {
      print('Error playing sound: $e');
    }
  }

  Future<void> _handleLocationAccess() async {
    final result =
        await Navigator.pushNamed(context, LocationAccessScreen.route);

    if (result is Map<String, dynamic> && result['address'] != null) {
      setState(() {
        _deliveryAddress = result['address'];
        _latitude = result['latitude'];
        _longitude = result['longitude'];
        _userLocation = result['address'];
        _hasLocationPermission = true;
        _errorMessage = null;

        _updateDeliveryFee();
      });
    }
  }

  Future<void> _showNoLocationDialog() async {
    await _playSound('audio/wrong.mp3');

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          elevation: 5,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 180,
                  width: 180,
                  child: Lottie.asset(
                    'assets/animations/caution.json',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.warning_amber_rounded,
                        size: 100,
                        color: Colors.orange,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Lokasi Diperlukan",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Mohon aktifkan lokasi untuk menghitung biaya pengiriman yang akurat",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlobalStyle.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 14),
                    elevation: 2,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _handleLocationAccess();
                  },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on, size: 18),
                      SizedBox(width: 8),
                      Text(
                        "Aktifkan Lokasi",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
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

  Future<void> _showErrorDialog(String title, String message) async {
    await _playSound('audio/wrong.mp3');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(
                color: GlobalStyle.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ PERBAIKAN: Enhanced anti-double submission with stronger protection
  Future<void> _createOrder() async {
    // ✅ FIXED: Multiple layers of protection against double submission
    final now = DateTime.now();

    // Check if already submitted
    if (_hasSubmittedOrder || _isCreatingOrder) {
      print('⚠️ CartScreen: Order submission already in progress, ignoring...');
      return;
    }

    // Check cooldown period
    if (_lastSubmitAttempt != null &&
        now.difference(_lastSubmitAttempt!) < _submitCooldown) {
      print('⚠️ CartScreen: Still in cooldown period, ignoring...');
      await _showErrorDialog('Tunggu Sebentar',
          'Mohon tunggu ${_submitCooldown.inSeconds} detik sebelum mencoba lagi.');
      return;
    }

    // Check if debounce timer is still active
    if (_submitDebounceTimer != null && _submitDebounceTimer!.isActive) {
      print('⚠️ CartScreen: Debouncing rapid clicks...');
      return;
    }

    // ✅ BARU: Validate cart has active items
    if (activeItems.isEmpty) {
      await _showErrorDialog('Keranjang Kosong',
          'Tidak ada item dalam keranjang. Tambahkan item terlebih dahulu.');
      return;
    }

    // Set debounce timer
    _submitDebounceTimer = Timer(const Duration(milliseconds: 3000), () {
      // Reset debounce after 3 seconds
    });

    // Set last attempt time
    _lastSubmitAttempt = now;

    // Validate customer access first
    final hasAccess = await AuthService.validateCustomerAccess();
    if (!hasAccess) {
      await _showErrorDialog('Akses Ditolak',
          'Anda harus login sebagai customer untuk membuat pesanan.');
      return;
    }

    // Check if location is available (for fee calculation display)
    if (!_hasLocationPermission || _latitude == null || _longitude == null) {
      await _showNoLocationDialog();
      return;
    }

    // ✅ FIXED: Set flags to prevent double submission
    setState(() {
      _isCreatingOrder = true;
      _hasSubmittedOrder = true;
    });

    // Show creating order dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: Colors.white,
            elevation: 5,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 150,
                    height: 150,
                    child: Lottie.asset(
                      'assets/animations/loading_animation.json',
                      repeat: true,
                      errorBuilder: (context, error, stackTrace) {
                        return CircularProgressIndicator(
                          color: GlobalStyle.primaryColor,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Membuat Pesanan",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Mohon tunggu sebentar sementara kami memproses pesanan Anda...",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Sistem otomatis akan mencarikan driver terdekat",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // ✅ BARU: Show order summary in loading dialog
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${activeItems.length} item - ${GlobalStyle.formatRupiah(grandTotal)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: GlobalStyle.primaryColor,
                          ),
                        ),
                        if (_orderNotes != null &&
                            _orderNotes!.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '"${_orderNotes!.trim()}"',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
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
      },
    );

    try {
      print('🚀 CartScreen: Creating order with backend-aligned structure...');
      print('   - Store ID: ${widget.storeId}');
      print('   - Items count: ${activeItems.length}');
      print(
          '   - Expected subtotal: ${GlobalStyle.formatRupiah(itemsSubtotal)}');
      print(
          '   - Expected delivery fee: ${GlobalStyle.formatRupiah(_estimatedDeliveryFee)}');
      print(
          '   - Expected grand total: ${GlobalStyle.formatRupiah(grandTotal)}');
      print('   - Notes: "$_orderNotes"');

      // ✅ FIXED: Ensure notes are sent properly
      final notes = _orderNotes?.trim() ?? '';
      print('   - Processed notes: "$notes"');

      // ✅ PERBAIKAN: Menggunakan OrderService.placeOrder() yang baru
      final orderResponse = await OrderService.placeOrder(
        storeId: widget.storeId.toString(),
        items: _prepareOrderItems(),
        notes: notes,
      );

      // Close creating order dialog
      Navigator.of(context, rootNavigator: true).pop();

      if (orderResponse.isNotEmpty && orderResponse['id'] != null) {
        print('✅ CartScreen: Order created successfully!');
        print('   - Order ID: ${orderResponse['id']}');

        // ✅ VALIDATE: Check backend calculations match frontend
        if (orderResponse['total_amount'] != null) {
          final backendSubtotal =
              double.tryParse(orderResponse['total_amount'].toString()) ?? 0.0;
          final frontendSubtotal = itemsSubtotal;

          print(
              '   - Backend subtotal (total_amount): ${GlobalStyle.formatRupiah(backendSubtotal)}');
          print(
              '   - Frontend subtotal calculated: ${GlobalStyle.formatRupiah(frontendSubtotal)}');

          if ((backendSubtotal - frontendSubtotal).abs() > 0.01) {
            print('⚠️ MISMATCH: Subtotal calculation difference detected!');
          }
        }

        if (orderResponse['delivery_fee'] != null) {
          final backendDeliveryFee =
              double.tryParse(orderResponse['delivery_fee'].toString()) ?? 0.0;
          final frontendDeliveryFee = _estimatedDeliveryFee;

          print(
              '   - Backend delivery fee: ${GlobalStyle.formatRupiah(backendDeliveryFee)}');
          print(
              '   - Frontend delivery fee calculated: ${GlobalStyle.formatRupiah(frontendDeliveryFee)}');

          if ((backendDeliveryFee - frontendDeliveryFee).abs() > 0.01) {
            print('⚠️ MISMATCH: Delivery fee calculation difference detected!');
          }
        }

        // Show success and get order details
        await _showOrderCreatedSuccess(orderResponse['id'].toString());

        // ✅ PERBAIKAN: Get full order details for navigation
        try {
          final orderDetails =
              await OrderService.getOrderById(orderResponse['id'].toString());
          final createdOrder = OrderModel.fromJson(orderDetails);

          setState(() {
            _isCreatingOrder = false;
          });

          // Navigate to history detail page
          Navigator.pushReplacementNamed(
            context,
            HistoryDetailPage.route,
            arguments: createdOrder,
          );
        } catch (detailError) {
          print('⚠️ CartScreen: Error getting order details: $detailError');

          // ✅ FALLBACK: Jika gagal get details, tetap navigate dengan data minimal
          final minimumOrder = OrderModel(
            id: int.parse(orderResponse['id'].toString()),
            customerId: _userData?['id'] ?? 0,
            storeId: widget.storeId,
            totalAmount: itemsSubtotal,
            deliveryFee: orderResponse['delivery_fee']?.toDouble() ??
                _estimatedDeliveryFee,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            orderStatus: OrderStatus.pending,
            deliveryStatus: DeliveryStatus.pending,
            items: activeItems
                .map((item) =>
                    // Create basic OrderItemModel from MenuItemModel
                    // This is a simplified conversion for navigation
                    OrderItemModel(
                      id: 0,
                      orderId: int.parse(orderResponse['id'].toString()),
                      menuItemId: item.id,
                      name: item.name,
                      description: item.description,
                      imageUrl: item.imageUrl,
                      category: item.category,
                      quantity: _getItemQuantity(item),
                      price: item.price,
                      notes: '',
                      menuItem: null,
                      createdAt: null,
                      updatedAt: null,
                    ))
                .toList(),
          );

          setState(() {
            _isCreatingOrder = false;
          });

          Navigator.pushReplacementNamed(
            context,
            HistoryDetailPage.route,
            arguments: minimumOrder,
          );
        }
      } else {
        throw Exception('Order created but no order ID returned');
      }
    } catch (e) {
      print('❌ CartScreen: Error creating order: $e');

      Navigator.of(context, rootNavigator: true).pop();

      // ✅ FIXED: Reset flags on error so user can retry
      setState(() {
        _isCreatingOrder = false;
        _hasSubmittedOrder = false;
      });

      // Reset last attempt time so user can retry
      _lastSubmitAttempt = null;

      // ✅ PERBAIKAN: Enhanced error messages based on service errors
      String errorMessage = 'Terjadi kesalahan saat membuat pesanan';

      if (e.toString().contains('authentication') ||
          e.toString().contains('Access denied')) {
        errorMessage = 'Sesi login Anda telah berakhir. Silakan login kembali.';
      } else if (e.toString().contains('network') ||
          e.toString().contains('connection')) {
        errorMessage =
            'Koneksi internet bermasalah. Periksa koneksi Anda dan coba lagi.';
      } else if (e.toString().contains('validation')) {
        errorMessage =
            'Data pesanan tidak valid. Periksa item dan lokasi Anda.';
      } else {
        errorMessage = 'Gagal membuat pesanan: $e';
      }

      await _showErrorDialog('Gagal Membuat Pesanan', errorMessage);
    }
  }

  // ✅ PERBAIKAN: Update success dialog to show backend data structure
  Future<void> _showOrderCreatedSuccess(String orderId) async {
    await _playSound('audio/kring.mp3');

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          elevation: 5,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 180,
                  height: 180,
                  child: Lottie.asset(
                    'assets/animations/check_animation.json',
                    repeat: false,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.check_circle,
                        size: 100,
                        color: Colors.green,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Pesanan Berhasil Dibuat",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Pesanan Anda telah diterima dan siap diproses",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Order ID: $orderId",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),

                // ✅ ENHANCED: Show payment breakdown
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Rincian Pesanan',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Subtotal (${activeItems.length} item):',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.green[600],
                            ),
                          ),
                          Text(
                            GlobalStyle.formatRupiah(itemsSubtotal),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.green[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Biaya Pengiriman:',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.green[600],
                            ),
                          ),
                          Text(
                            GlobalStyle.formatRupiah(_estimatedDeliveryFee),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.green[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Pembayaran:',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            GlobalStyle.formatRupiah(grandTotal),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ✅ FIXED: Show notes if provided
                if (_orderNotes != null && _orderNotes!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.note_outlined,
                              size: 14,
                              color: Colors.green[700],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Catatan terkirim:',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '"${_orderNotes!.trim()}"',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.green[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                // ✅ BARU: Informasi auto driver search
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    "🚗 Sistem otomatis mencari driver terdekat",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlobalStyle.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 14),
                    elevation: 2,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "OK",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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

  @override
  Widget build(BuildContext context) {
    String storeName = 'Pesanan';
    if (_storeDetail != null) {
      storeName = _storeDetail!.name;
    }

    return Scaffold(
      backgroundColor: const Color(0xffF0F7FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Keranjang Pesanan',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(7.0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: GlobalStyle.primaryColor, width: 1.0),
            ),
            child: Icon(Icons.arrow_back_ios_new,
                color: GlobalStyle.primaryColor, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 150,
                    height: 150,
                    child: Lottie.asset(
                      'assets/animations/loading_animation.json',
                      errorBuilder: (context, error, stackTrace) {
                        return CircularProgressIndicator(
                          color: GlobalStyle.primaryColor,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Memuat Data...",
                    style: TextStyle(
                      color: GlobalStyle.primaryColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : activeItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 200,
                        height: 200,
                        child: Lottie.asset(
                          'assets/animations/empty_cart.json',
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.shopping_cart_outlined,
                              size: 100,
                              color: Colors.grey[400],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Keranjang Kosong",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          "Tambahkan beberapa item untuk mulai memesan",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.shopping_bag_outlined),
                        label: const Text("Mulai Belanja"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GlobalStyle.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Location card with notes
                        _buildCard(
                          index: 0,
                          child: _buildLocationCard(),
                        ),

                        // Order items with quantity controls
                        _buildCard(
                          index: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    Icon(Icons.restaurant_menu,
                                        color: GlobalStyle.primaryColor),
                                    const SizedBox(width: 8),
                                    Text(
                                      storeName,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: GlobalStyle.fontColor,
                                        fontFamily: GlobalStyle.fontFamily,
                                      ),
                                    ),
                                    const Spacer(),
                                    // ✅ BARU: Show total items count
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: GlobalStyle.primaryColor
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${activeItems.length} item',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: GlobalStyle.primaryColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: activeItems.length,
                                separatorBuilder: (context, index) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final item = activeItems[index];
                                  final quantity = _getItemQuantity(item);
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16.0, vertical: 8.0),
                                    leading: SizedBox(
                                      width: 60,
                                      height: 60,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: ImageService.displayImage(
                                          imageSource: item.imageUrl ?? '',
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                          placeholder: Container(
                                            color: Colors.grey[300],
                                            child: const Icon(Icons.image,
                                                color: Colors.white70),
                                          ),
                                          errorWidget: Container(
                                            color: Colors.grey[300],
                                            child: const Icon(
                                                Icons.image_not_supported,
                                                color: Colors.white70),
                                          ),
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      item.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: GlobalStyle.fontColor,
                                        fontFamily: GlobalStyle.fontFamily,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.formatPrice(),
                                          style: const TextStyle(
                                              color: Colors.grey),
                                        ),
                                        const SizedBox(height: 8),
                                        // ✅ BARU: Quantity controls in cart
                                        Row(
                                          children: [
                                            _buildQuantityControls(item),
                                            const SizedBox(width: 12),
                                            _buildRemoveButton(item),
                                          ],
                                        ),
                                      ],
                                    ),
                                    trailing: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          GlobalStyle.formatRupiah(
                                              item.price * quantity),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: GlobalStyle.primaryColor,
                                            fontFamily: GlobalStyle.fontFamily,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'x$quantity',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),

                        // Payment details
                        _buildPaymentDetails(),

                        // Add some bottom spacing
                        const SizedBox(height: 100),
                      ],
                    ),

                    // Order button
                    Positioned(
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
                        child: ElevatedButton(
                          // ✅ FIXED: Enhanced button state management
                          onPressed: (_isCreatingOrder ||
                                  _isLoading ||
                                  _hasSubmittedOrder ||
                                  activeItems.isEmpty)
                              ? null
                              : _createOrder,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: GlobalStyle.primaryColor,
                            disabledBackgroundColor: Colors.grey,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 2,
                          ),
                          child: _isCreatingOrder || _isLoading
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'Memproses...',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.shopping_cart_checkout),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Buat Pesanan - ${GlobalStyle.formatRupiah(grandTotal)}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildCard({required int index, required Widget child}) {
    final safeIndex = index < _cardAnimations.length ? index : 0;

    return SlideTransition(
      position: _cardAnimations[safeIndex],
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: child,
      ),
    );
  }

  Widget _buildPaymentRow(String label, double amount, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? GlobalStyle.fontColor : Colors.grey[700],
            fontFamily: GlobalStyle.fontFamily,
          ),
        ),
        Text(
          GlobalStyle.formatRupiah(amount),
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? GlobalStyle.primaryColor : GlobalStyle.fontColor,
            fontFamily: GlobalStyle.fontFamily,
          ),
        ),
      ],
    );
  }
}
