import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Models/driver.dart';
import 'package:del_pick/Services/image_service.dart';
import 'package:del_pick/Services/service_order_service.dart';
import 'package:del_pick/Services/auth_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lottie/lottie.dart';
import 'package:geolocator/geolocator.dart';

import '../../Services/master_location.dart';

class ContactDriverPage extends StatefulWidget {
  static const String route = "/Customers/ContactDriver";

  final DriverModel driver;
  final String serviceType;

  const ContactDriverPage({
    super.key,
    required this.driver,
    this.serviceType = 'jastip',
  });

  @override
  createState() => _ContactDriverPageState();
}

class _ContactDriverPageState extends State<ContactDriverPage>
    with TickerProviderStateMixin {

  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _pickupAddressController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Master Location data
  List<Map<String, dynamic>> _availableLocations = [];
  Map<String, dynamic>? _selectedLocation;
  double _serviceFee = 0.0;
  int _estimatedDuration = 0;

  // Location state
  Position? _currentPosition;
  double _pickupLatitude = 0.0;
  double _pickupLongitude = 0.0;

  bool _isLoading = false;
  bool _isLocationLoading = false;
  bool _isSubmitting = false;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _pulseController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Start animations and load data
    _fadeController.forward();
    _slideController.forward();
    _pulseController.repeat(reverse: true);

    _initializeData();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _phoneController.dispose();
    _pickupAddressController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Load customer data
      await _loadCustomerData();

      // Load available locations
      await _loadAvailableLocations();

      // Get current location
      await _getCurrentLocation();

    } catch (e) {
      print('❌ ContactDriver: Error initializing data: $e');
      _showErrorDialog('Gagal memuat data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCustomerData() async {
    try {
      final customerData = await AuthService.getCustomerData();
      if (customerData != null) {
        _phoneController.text = customerData['phone'] ?? '';
      }
    } catch (e) {
      print('❌ ContactDriver: Error loading customer data: $e');
    }
  }

  Future<void> _loadAvailableLocations() async {
    try {
      // Get popular locations first for quick selection
      final popularLocations = await MasterLocationService.getPopularLocations();

      if (popularLocations.isNotEmpty) {
        setState(() {
          _availableLocations = popularLocations;
        });
      } else {
        // Fallback to all locations if no popular locations
        final allLocationsResponse = await MasterLocationService.getAllLocations(limit: 50);
        setState(() {
          _availableLocations = allLocationsResponse['locations'] ?? [];
        });
      }

      print('✅ ContactDriver: Loaded ${_availableLocations.length} locations');
    } catch (e) {
      print('❌ ContactDriver: Error loading locations: $e');
      // Set default locations as fallback
      setState(() {
        _availableLocations = [
          {
            'id': 1,
            'name': 'Balige',
            'service_fee': 30000.0,
            'estimated_duration_minutes': 45,
          },
          {
            'id': 2,
            'name': 'Laguboti',
            'service_fee': 15000.0,
            'estimated_duration_minutes': 25,
          },
        ];
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      setState(() {
        _isLocationLoading = true;
      });

      // Check permissions
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showErrorDialog('Layanan lokasi tidak aktif');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showErrorDialog('Izin lokasi ditolak');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showErrorDialog('Izin lokasi ditolak permanen');
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _pickupLatitude = position.latitude;
        _pickupLongitude = position.longitude;
      });

      // Try to get address from coordinates (reverse geocoding)
      await _updatePickupAddress();

    } catch (e) {
      print('❌ ContactDriver: Error getting location: $e');
      _showErrorDialog('Gagal mendapatkan lokasi: $e');
    } finally {
      setState(() {
        _isLocationLoading = false;
      });
    }
  }

  Future<void> _updatePickupAddress() async {
    if (_pickupLatitude == 0.0 || _pickupLongitude == 0.0) return;

    try {
      // For now, set a default address
      // In production, you would use reverse geocoding service
      _pickupAddressController.text = 'Lokasi Saat Ini (${_pickupLatitude.toStringAsFixed(6)}, ${_pickupLongitude.toStringAsFixed(6)})';
    } catch (e) {
      print('❌ ContactDriver: Error updating pickup address: $e');
    }
  }

  Future<void> _calculateServiceFee() async {
    if (_selectedLocation == null) return;

    try {
      final locationId = _selectedLocation!['id'];
      final serviceFeeData = await MasterLocationService.getServiceFee(
        pickupLocationId: locationId,
      );

      setState(() {
        _serviceFee = serviceFeeData['service_fee']?.toDouble() ?? 0.0;
        _estimatedDuration = serviceFeeData['estimated_duration'] ?? 0;
      });

      print('✅ ContactDriver: Service fee calculated: $_serviceFee');
    } catch (e) {
      print('❌ ContactDriver: Error calculating service fee: $e');
      // Use fallback fee from location data
      setState(() {
        _serviceFee = _selectedLocation!['service_fee']?.toDouble() ?? 20000.0;
        _estimatedDuration = _selectedLocation!['estimated_duration_minutes'] ?? 30;
      });
    }
  }

  bool get _isFormValid {
    return _notesController.text.trim().isNotEmpty &&
        _phoneController.text.trim().isNotEmpty &&
        _pickupAddressController.text.trim().isNotEmpty &&
        _selectedLocation != null &&
        _pickupLatitude != 0.0 &&
        _pickupLongitude != 0.0;
  }

  Future<void> _submitServiceOrder() async {
    if (!_isFormValid || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      print('🚀 ContactDriver: Submitting service order...');

      // Create service order using ServiceOrderService
      final serviceOrderData = await ServiceOrderService.createServiceOrder(
        pickupAddress: _pickupAddressController.text.trim(),
        pickupLatitude: _pickupLatitude,
        pickupLongitude: _pickupLongitude,
        customerPhone: _phoneController.text.trim(),
        description: _notesController.text.trim(),
      );

      print('✅ ContactDriver: Service order created: ${serviceOrderData['id']}');

      // Show success dialog
      _showSuccessDialog(serviceOrderData);

    } catch (e) {
      print('❌ ContactDriver: Error creating service order: $e');
      _showErrorDialog('Gagal membuat pesanan: $e');
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Future<void> _openWhatsApp() async {
    try {
      final phoneNumber = widget.driver.phone.replaceAll(RegExp(r'[^\d+]'), '');
      final serviceFee = MasterLocationService.formatServiceFee(_serviceFee);

      final message = ServiceOrderService.generateWhatsAppLink(
        phoneNumber: phoneNumber,
        pickupAddress: _pickupAddressController.text.trim(),
        destinationAddress: 'IT Del',
        serviceFee: _serviceFee,
        description: _notesController.text.trim(),
      );

      if (await canLaunchUrl(Uri.parse(message))) {
        await launchUrl(Uri.parse(message), mode: LaunchMode.externalApplication);
      } else {
        _showErrorDialog('Tidak dapat membuka WhatsApp');
      }
    } catch (e) {
      _showErrorDialog('Error: $e');
    }
  }

  void _showSuccessDialog(Map<String, dynamic> serviceOrderData) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset(
                'assets/animations/success.json',
                height: 120,
                width: 120,
                repeat: false,
              ),
              const SizedBox(height: 16),
              Text(
                'Pesanan Berhasil!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: GlobalStyle.primaryColor,
                  fontFamily: GlobalStyle.fontFamily,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Pesanan jasa titip Anda telah dibuat. Sistem sedang mencari driver terdekat.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontFamily: GlobalStyle.fontFamily,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: GlobalStyle.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      'ID Pesanan: ${serviceOrderData['id']}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: GlobalStyle.primaryColor,
                        fontFamily: GlobalStyle.fontFamily,
                      ),
                    ),
                    if (serviceOrderData['estimated_duration_text'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Estimasi: ${serviceOrderData['estimated_duration_text']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontFamily: GlobalStyle.fontFamily,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(context); // Close dialog
                        Navigator.pop(context); // Back to home
                      },
                      child: const Text('Kembali'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context); // Close dialog
                        // Navigate to service order tracking page
                        Navigator.pushNamed(
                          context,
                          '/ServiceOrder/Tracking',
                          arguments: {'serviceOrderId': serviceOrderData['id']},
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GlobalStyle.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Lihat Status'),
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

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        title: const Text('Error'),
        content: Text(message),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.arrow_back_ios_new,
              color: GlobalStyle.primaryColor,
              size: 20,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Jasa Titip ke IT Del',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontFamily: GlobalStyle.fontFamily,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: GlobalStyle.primaryColor),
            const SizedBox(height: 16),
            Text(
              'Memuat data...',
              style: TextStyle(
                color: Colors.grey[600],
                fontFamily: GlobalStyle.fontFamily,
              ),
            ),
          ],
        ),
      )
          : FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Driver Info Card
                  _buildDriverInfoCard(),
                  const SizedBox(height: 20),

                  // Service Info Card
                  _buildServiceInfoCard(),
                  const SizedBox(height: 20),

                  // Pickup Location Card
                  _buildPickupLocationCard(),
                  const SizedBox(height: 20),

                  // Destination Selection Card
                  _buildDestinationCard(),
                  const SizedBox(height: 20),

                  // Order Form Card
                  _buildOrderFormCard(),
                  const SizedBox(height: 24),

                  // Action Buttons
                  _buildActionButtons(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDriverInfoCard() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.1),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              GlobalStyle.primaryColor.withOpacity(0.05),
              Colors.white,
            ],
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Driver Avatar
                Hero(
                  tag: 'driver-avatar-${widget.driver.driverId}',
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: GlobalStyle.primaryColor,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: GlobalStyle.primaryColor.withOpacity(0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: _buildDriverImage(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Driver Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.driver.name,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          fontFamily: GlobalStyle.fontFamily,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.star,
                            color: Colors.amber,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.driver.formattedRating,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontFamily: GlobalStyle.fontFamily,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: widget.driver.isAvailable
                              ? Colors.green.withOpacity(0.1)
                              : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.driver.statusDisplayName,
                          style: TextStyle(
                            fontSize: 12,
                            color: widget.driver.isAvailable
                                ? Colors.green[700]
                                : Colors.orange[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Driver Additional Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      LucideIcons.car,
                      'Kendaraan',
                      widget.driver.vehiclePlate.isNotEmpty
                          ? widget.driver.vehiclePlate
                          : 'Motor',
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.grey.withOpacity(0.3),
                  ),
                  Expanded(
                    child: _buildInfoItem(
                      LucideIcons.phone,
                      'Telepon',
                      widget.driver.phone,
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

  Widget _buildServiceInfoCard() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                    LucideIcons.package,
                    color: GlobalStyle.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Layanan Jasa Titip ke IT Del',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      fontFamily: GlobalStyle.fontFamily,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Destinasi tetap: Institut Teknologi Del',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w500,
                        fontFamily: GlobalStyle.fontFamily,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Pesan barang yang tidak tersedia di aplikasi melalui driver kami. Driver akan membelikan dan mengantarkan barang ke IT Del sesuai permintaan Anda.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontFamily: GlobalStyle.fontFamily,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickupLocationCard() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  LucideIcons.mapPin,
                  color: GlobalStyle.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Lokasi Pickup',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Pickup Address Input
            TextFormField(
              controller: _pickupAddressController,
              decoration: InputDecoration(
                hintText: 'Alamat lengkap lokasi pickup...',
                prefixIcon: Icon(Icons.location_on, color: GlobalStyle.primaryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: GlobalStyle.primaryColor),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              maxLines: 2,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Alamat pickup harus diisi';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Get Current Location Button
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLocationLoading ? null : _getCurrentLocation,
                    icon: _isLocationLoading
                        ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(GlobalStyle.primaryColor),
                      ),
                    )
                        : Icon(Icons.my_location, size: 18),
                    label: Text(_isLocationLoading ? 'Mencari...' : 'Gunakan Lokasi Saat Ini'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: GlobalStyle.primaryColor,
                      side: BorderSide(color: GlobalStyle.primaryColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDestinationCard() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  LucideIcons.navigation,
                  color: GlobalStyle.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Lokasi Pickup (Pilih Kota/Area)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Pilih kota/area asal untuk menentukan biaya layanan',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontFamily: GlobalStyle.fontFamily,
              ),
            ),
            const SizedBox(height: 16),

            // Location Selection
            DropdownButtonFormField<Map<String, dynamic>>(
              value: _selectedLocation,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: GlobalStyle.primaryColor),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                prefixIcon: Icon(Icons.location_city, color: GlobalStyle.primaryColor),
              ),
              hint: const Text('Pilih kota/area pickup'),
              items: _availableLocations.map((location) {
                return DropdownMenuItem<Map<String, dynamic>>(
                  value: location,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          location['name'] ?? 'Unknown',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        MasterLocationService.formatServiceFee(
                          location['service_fee']?.toDouble() ?? 0.0,
                        ),
                        style: TextStyle(
                          color: GlobalStyle.primaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedLocation = value;
                });
                if (value != null) {
                  _calculateServiceFee();
                }
              },
              validator: (value) {
                if (value == null) {
                  return 'Pilih lokasi pickup';
                }
                return null;
              },
            ),

            // Service Fee Display
            if (_selectedLocation != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: GlobalStyle.primaryColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: GlobalStyle.primaryColor.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Biaya Pengiriman:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                        Text(
                          MasterLocationService.formatServiceFee(_serviceFee),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: GlobalStyle.primaryColor,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                      ],
                    ),
                    if (_estimatedDuration > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Estimasi Waktu:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                              fontFamily: GlobalStyle.fontFamily,
                            ),
                          ),
                          Text(
                            MasterLocationService.formatEstimatedDuration(_estimatedDuration),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                              fontFamily: GlobalStyle.fontFamily,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Tujuan:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                        Text(
                          'IT Del',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: GlobalStyle.primaryColor,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOrderFormCard() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detail Pesanan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                fontFamily: GlobalStyle.fontFamily,
              ),
            ),
            const SizedBox(height: 20),

            // Phone Number Input
            Text(
              'Nomor Telepon *',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
                fontFamily: GlobalStyle.fontFamily,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: 'Nomor WhatsApp yang bisa dihubungi...',
                prefixIcon: Icon(Icons.phone, color: GlobalStyle.primaryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: GlobalStyle.primaryColor),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Nomor telepon harus diisi';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Notes Input
            Text(
              'Detail Barang yang Dititipkan *',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
                fontFamily: GlobalStyle.fontFamily,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Tulis detail barang yang ingin dititipkan...\nContoh: Beli nasi gudeg di warung X, porsi 2\nBeli oleh-oleh khas Batak, budget 100rb',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: GlobalStyle.primaryColor),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Detail barang harus diisi';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Order Button
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _isFormValid ? _pulseAnimation.value : 1.0,
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isFormValid && !_isSubmitting ? _submitServiceOrder : null,
                  icon: _isSubmitting
                      ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : const Icon(LucideIcons.shoppingCart, size: 20),
                  label: Text(
                    _isSubmitting ? 'Memproses...' : 'Pesan Jasa Titip',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isFormValid
                        ? GlobalStyle.primaryColor
                        : Colors.grey.shade400,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    elevation: _isFormValid ? 4 : 1,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),

        // Chat Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: _openWhatsApp,
            icon: const Icon(LucideIcons.messageCircle, size: 20),
            label: const Text(
              'Chat via WhatsApp',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: GlobalStyle.primaryColor,
              side: BorderSide(color: GlobalStyle.primaryColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(
          icon,
          color: GlobalStyle.primaryColor,
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
            fontFamily: GlobalStyle.fontFamily,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
            fontFamily: GlobalStyle.fontFamily,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildDriverImage() {
    if (widget.driver.avatar != null && widget.driver.avatar!.isNotEmpty) {
      return ImageService.displayImage(
        imageSource: widget.driver.avatar!,
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        errorWidget: _buildDriverPlaceholder(),
      );
    }
    return _buildDriverPlaceholder();
  }

  Widget _buildDriverPlaceholder() {
    return Container(
      width: 80,
      height: 80,
      color: GlobalStyle.primaryColor.withOpacity(0.1),
      child: Icon(
        LucideIcons.user,
        color: GlobalStyle.primaryColor,
        size: 40,
      ),
    );
  }
}