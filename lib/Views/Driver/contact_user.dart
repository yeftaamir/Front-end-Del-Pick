import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:lottie/lottie.dart';
import 'package:audioplayers/audioplayers.dart';

// Services
import 'package:del_pick/Services/service_order_service.dart';
import 'package:del_pick/Services/image_service.dart';
import 'package:del_pick/Services/auth_service.dart';

import '../../Services/master_location.dart';

class ContactUserPage extends StatefulWidget {
  static const String route = '/Driver/ContactUser';

  final String serviceOrderId;
  final Map<String, dynamic>? serviceOrderData;

  const ContactUserPage({
    Key? key,
    required this.serviceOrderId,
    this.serviceOrderData,
  }) : super(key: key);

  @override
  State<ContactUserPage> createState() => _ContactUserPageState();
}

class _ContactUserPageState extends State<ContactUserPage> with TickerProviderStateMixin {
  // Audio player initialization
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Animation controllers
  late List<AnimationController> _cardControllers;
  late List<Animation<Offset>> _cardAnimations;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Data state
  Map<String, dynamic>? _serviceOrderData;
  Map<String, dynamic>? _customerData;
  Map<String, dynamic>? _driverData;
  Map<String, dynamic>? _pickupLocationData;
  Map<String, dynamic>? _destinationLocationData;

  bool _isLoading = true;
  bool _isProcessing = false;
  String? _errorMessage;

  // Authentication state
  bool _isAuthenticated = false;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _cardControllers = List.generate(
      4, // Four card sections
          (index) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 600 + (index * 200)),
      ),
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // Create slide animations for each card
    _cardAnimations = _cardControllers.map((controller) {
      return Tween<Offset>(
        begin: const Offset(0, 0.5),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeOutCubic,
      ));
    }).toList();

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Initialize authentication and load data
    _initializeAuthentication();
  }

  @override
  void dispose() {
    for (var controller in _cardControllers) {
      controller.dispose();
    }
    _pulseController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // Initialize authentication
  Future<void> _initializeAuthentication() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      print('🔍 ContactUser: Initializing authentication...');

      // Check authentication status
      final isAuth = await AuthService.isAuthenticated();
      if (!isAuth) {
        throw Exception('User not authenticated');
      }

      // Get user data
      final userData = await AuthService.getUserData();
      if (userData == null) {
        throw Exception('No user data found');
      }

      // Get role-specific data
      final roleSpecificData = await AuthService.getRoleSpecificData();
      if (roleSpecificData == null) {
        throw Exception('No role-specific data found');
      }

      // Verify user role
      final userRole = await AuthService.getUserRole();
      if (userRole?.toLowerCase() != 'driver') {
        throw Exception('User is not a driver');
      }

      _userData = userData;
      _driverData = roleSpecificData;
      _isAuthenticated = true;

      print('✅ ContactUser: Authentication successful');

      // Load service order and customer data
      await _loadServiceOrderData();

    } catch (e) {
      print('❌ ContactUser: Authentication error: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Authentication failed: $e';
        _isAuthenticated = false;
      });
    }
  }

  // Load service order and customer data
  Future<void> _loadServiceOrderData() async {
    if (!_isAuthenticated) {
      print('❌ ContactUser: Cannot load service order data - not authenticated');
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      print('🔄 ContactUser: Loading service order data for ID: ${widget.serviceOrderId}');

      // 1. Get service order details using ServiceOrderService.getServiceOrderById
      final serviceOrderResponse = await ServiceOrderService.getServiceOrderById(widget.serviceOrderId);
      _serviceOrderData = serviceOrderResponse;

      print('📦 ContactUser: Service order data loaded');

      // 2. Extract customer data from service order
      if (_serviceOrderData!['customer'] != null) {
        _customerData = _serviceOrderData!['customer'];
        print('👤 ContactUser: Customer data extracted from service order');
      }

      // 3. Load pickup location data if available
      if (_serviceOrderData!['pickup_location_id'] != null) {
        try {
          final pickupLocationResponse = await MasterLocationService.getLocationById(
            _serviceOrderData!['pickup_location_id'].toString(),
          );
          _pickupLocationData = pickupLocationResponse;
          print('📍 ContactUser: Pickup location data loaded');
        } catch (e) {
          print('❌ ContactUser: Error loading pickup location: $e');
        }
      }

      // 4. Get IT Del destination data (fixed destination)
      _destinationLocationData = MasterLocationService.getITDelDestination();

      setState(() {
        _isLoading = false;
      });

      // Start animations after data is loaded
      _startAnimations();

      print('✅ ContactUser: Service order and related data loaded successfully');

    } catch (e) {
      print('❌ ContactUser: Error loading service order data: $e');
      setState(() {
        _errorMessage = 'Failed to load service order data: $e';
        _isLoading = false;
      });
    }
  }

  // Start animations sequentially
  void _startAnimations() {
    Future.delayed(const Duration(milliseconds: 100), () {
      for (var i = 0; i < _cardControllers.length; i++) {
        Future.delayed(Duration(milliseconds: 100 * i), () {
          if (mounted) {
            _cardControllers[i].forward();
          }
        });
      }
    });
    _pulseController.repeat(reverse: true);
  }

  // Update service order status using ServiceOrderService.updateServiceOrderStatus
  Future<void> _updateServiceOrderStatus(String status, {String? notes}) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      print('🔄 ContactUser: Updating service order status to: $status');

      // Use ServiceOrderService.updateServiceOrderStatus
      await ServiceOrderService.updateServiceOrderStatus(
        serviceOrderId: widget.serviceOrderId,
        status: status,
        notes: notes ?? 'Status updated by driver',
      );

      // Play sound
      _playSound('audio/alert.wav');

      // Refresh service order data
      await _loadServiceOrderData();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status berhasil diperbarui ke: ${ServiceOrderService.getStatusDisplayText(status)}'),
            backgroundColor: status == 'in_progress' ? Colors.green : Colors.orange,
          ),
        );
      }

      // If in_progress, show success dialog
      if (status == 'in_progress') {
        _showSuccessDialog();
      }

    } catch (e) {
      print('❌ ContactUser: Error updating service order status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memperbarui status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  // Accept service order using ServiceOrderService.acceptServiceOrder
  Future<void> _acceptServiceOrder() async {
    if (_serviceOrderData == null || _isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      print('🤝 ContactUser: Accepting service order...');

      // Use ServiceOrderService.acceptServiceOrder
      await ServiceOrderService.acceptServiceOrder(
        customerId: _serviceOrderData!['customer_id'],
        pickupAddress: _serviceOrderData!['pickup_address'],
        pickupLatitude: double.parse(_serviceOrderData!['pickup_latitude'].toString()),
        pickupLongitude: double.parse(_serviceOrderData!['pickup_longitude'].toString()),
        destinationAddress: _serviceOrderData!['destination_address'],
        destinationLatitude: double.parse(_serviceOrderData!['destination_latitude'].toString()),
        destinationLongitude: double.parse(_serviceOrderData!['destination_longitude'].toString()),
        customerPhone: _serviceOrderData!['customer_phone'],
        description: _serviceOrderData!['description'],
      );

      // Play sound
      _playSound('audio/kring.mp3');

      // Refresh service order data
      await _loadServiceOrderData();

      // Show success dialog
      _showAcceptSuccessDialog();

    } catch (e) {
      print('❌ ContactUser: Error accepting service order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menerima pesanan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  // Cancel service order for customer
  Future<void> _cancelServiceOrder({String? reason}) async {
    if (_serviceOrderData == null || _isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      print('❌ ContactUser: Cancelling service order...');

      // Use ServiceOrderService.cancelServiceOrder
      await ServiceOrderService.cancelServiceOrder(
        serviceOrderId: widget.serviceOrderId,
        reason: reason ?? 'Cancelled by driver',
      );

      // Play sound
      _playSound('audio/alert.wav');

      // Refresh service order data
      await _loadServiceOrderData();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pesanan berhasil dibatalkan'),
            backgroundColor: Colors.orange,
          ),
        );
      }

    } catch (e) {
      print('❌ ContactUser: Error cancelling service order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membatalkan pesanan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  // Play sound effect
  Future<void> _playSound(String assetPath) async {
    try {
      await _audioPlayer.play(AssetSource(assetPath));
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }
  }

  // Show success dialog after accepting service order
  void _showAcceptSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/animations/success.json',
                  width: 120,
                  height: 120,
                  repeat: false,
                ),
                const SizedBox(height: 20),
                Text(
                  'Jasa Titip Diterima!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Anda telah menerima pesanan jasa titip ini. Segera hubungi customer untuk detail lebih lanjut.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pop(); // Close dialog
                          Navigator.of(context).pop(); // Back to previous page
                        },
                        child: const Text('Kembali'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop(); // Close dialog
                          _openWhatsApp(); // Open WhatsApp
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GlobalStyle.primaryColor,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Chat Customer'),
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

  // Show success dialog after updating status
  void _showSuccessDialog() {
    _playSound('audio/kring.mp3');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/animations/success.json',
                  width: 120,
                  height: 120,
                  repeat: false,
                ),
                const SizedBox(height: 20),
                Text(
                  'Status Diperbarui!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Status jasa titip telah diperbarui. Customer akan mendapatkan notifikasi.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pop(); // Close dialog
                        },
                        child: const Text('Tutup'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop(); // Close dialog
                          _openWhatsApp(); // Open WhatsApp
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GlobalStyle.primaryColor,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Chat Customer'),
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

  // Open WhatsApp to contact customer
  Future<void> _openWhatsApp() async {
    try {
      if (_serviceOrderData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Data pesanan tidak tersedia')),
          );
        }
        return;
      }

      // Generate WhatsApp URL using ServiceOrderService
      final whatsappUrl = _serviceOrderData!['customer_whatsapp_link'] ??
          _generateCustomerWhatsAppUrl();

      if (await canLaunchUrlString(whatsappUrl)) {
        await launchUrlString(whatsappUrl);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tidak dapat membuka WhatsApp')),
          );
        }
      }
    } catch (e) {
      print('❌ ContactUser: Error opening WhatsApp: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  // Generate WhatsApp URL for customer communication
  String _generateCustomerWhatsAppUrl() {
    if (_serviceOrderData == null) return '';

    final customerPhone = _serviceOrderData!['customer_phone'] ?? '';
    if (customerPhone.isEmpty) return '';

    final cleanPhone = customerPhone.replaceAll(RegExp(r'\D'), '');
    String formattedPhone = cleanPhone;

    if (cleanPhone.startsWith('0')) {
      formattedPhone = '62${cleanPhone.substring(1)}';
    } else if (!cleanPhone.startsWith('62')) {
      formattedPhone = '62$cleanPhone';
    }

    final customerName = _customerData?['name'] ?? 'Customer';
    final pickupAddress = _serviceOrderData!['pickup_address'] ?? '';
    final destinationAddress = _serviceOrderData!['destination_address'] ?? 'IT Del';
    final serviceFee = _serviceOrderData!['service_fee']?.toDouble() ?? 0.0;
    final description = _serviceOrderData!['description'] ?? '';

    String message = 'Halo $customerName, saya driver dari DelPick. ';
    message += 'Saya telah menerima pesanan jasa titip Anda #${widget.serviceOrderId}.\n\n';
    message += '📍 Pickup: $pickupAddress\n';
    message += '📍 Tujuan: $destinationAddress\n';
    message += '💰 Biaya: ${MasterLocationService.formatServiceFee(serviceFee)}\n';

    if (description.isNotEmpty) {
      message += '📝 Detail: $description\n';
    }

    message += '\nSaya akan segera menuju lokasi pickup. Terima kasih!';

    return 'https://wa.me/$formattedPhone?text=${Uri.encodeComponent(message)}';
  }

  Widget _buildCard({required Widget child, required int index}) {
    return SlideTransition(
      position: _cardAnimations[index],
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      ),
    );
  }

  Widget _buildServiceOrderStatusCard() {
    if (_serviceOrderData == null) return const SizedBox.shrink();

    final status = _serviceOrderData!['status'] ?? 'pending';
    final statusColor = _getStatusColor(status);
    final statusText = ServiceOrderService.getStatusDisplayText(status);
    final createdAt = _serviceOrderData!['created_at'];
    final orderDate = createdAt != null ? DateTime.tryParse(createdAt) : DateTime.now();
    final formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(orderDate ?? DateTime.now());
    final urgencyLevel = ServiceOrderService.getServiceOrderUrgency(_serviceOrderData!);

    return _buildCard(
      index: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
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
                    Icons.local_shipping,
                    color: GlobalStyle.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Jasa Titip #${widget.serviceOrderId}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: GlobalStyle.fontColor,
                      fontFamily: GlobalStyle.fontFamily,
                    ),
                  ),
                ),
                if (urgencyLevel != 'normal') ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: urgencyLevel == 'urgent'
                          ? Colors.red.withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      urgencyLevel == 'urgent' ? 'URGENT' : 'HIGH',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: urgencyLevel == 'urgent'
                            ? Colors.red[700]
                            : Colors.orange[700],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Status Pesanan',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tanggal Pesanan',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
                Text(
                  formattedDate,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: GlobalStyle.fontColor,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
              ],
            ),
            if (_serviceOrderData!['service_fee'] != null) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Biaya Layanan',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontFamily: GlobalStyle.fontFamily,
                    ),
                  ),
                  Text(
                    MasterLocationService.formatServiceFee(
                      _serviceOrderData!['service_fee']?.toDouble() ?? 0.0,
                    ),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: GlobalStyle.primaryColor,
                      fontFamily: GlobalStyle.fontFamily,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerInfoCard() {
    if (_customerData == null) return const SizedBox.shrink();

    return _buildCard(
      index: 1,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: GlobalStyle.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Informasi Customer',
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
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: GlobalStyle.lightColor,
                  ),
                  child: ClipOval(
                    child: _customerData!['avatar'] != null && _customerData!['avatar'].toString().isNotEmpty
                        ? Image.network(
                      ImageService.getImageUrl(_customerData!['avatar']),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.person,
                        color: GlobalStyle.primaryColor,
                        size: 28,
                      ),
                    )
                        : Icon(
                      Icons.person,
                      color: GlobalStyle.primaryColor,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _customerData!['name'] ?? 'Unknown Customer',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: GlobalStyle.fontColor,
                          fontFamily: GlobalStyle.fontFamily,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (_customerData!['email'] != null) ...[
                        Row(
                          children: [
                            Icon(Icons.email, color: Colors.grey[600], size: 16),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _customerData!['email'],
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                  fontFamily: GlobalStyle.fontFamily,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],
                      if (_serviceOrderData!['customer_phone'] != null) ...[
                        Row(
                          children: [
                            Icon(Icons.phone, color: Colors.grey[600], size: 16),
                            const SizedBox(width: 4),
                            Text(
                              _serviceOrderData!['customer_phone'],
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
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
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.chat, color: Colors.white),
                    label: const Text(
                      'Chat Customer',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GlobalStyle.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _openWhatsApp,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationDetailsCard() {
    if (_serviceOrderData == null) return const SizedBox.shrink();

    return _buildCard(
      index: 2,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: GlobalStyle.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Detail Lokasi',
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

            // Pickup Location
            _buildLocationItem(
              icon: Icons.radio_button_checked,
              label: 'Lokasi Pickup',
              address: _serviceOrderData!['pickup_address'] ?? '',
              iconColor: Colors.green,
            ),
            const SizedBox(height: 12),

            // Destination Location
            _buildLocationItem(
              icon: Icons.location_on,
              label: 'Lokasi Tujuan',
              address: _serviceOrderData!['destination_address'] ?? 'IT Del',
              iconColor: Colors.red,
            ),

            if (_serviceOrderData!['estimated_duration'] != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Estimasi: ${MasterLocationService.formatEstimatedDuration(_serviceOrderData!['estimated_duration'])}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[700],
                        fontFamily: GlobalStyle.fontFamily,
                      ),
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

  Widget _buildLocationItem({
    required IconData icon,
    required String label,
    required String address,
    required Color iconColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                  fontFamily: GlobalStyle.fontFamily,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                address,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontFamily: GlobalStyle.fontFamily,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildServiceDetailsCard() {
    if (_serviceOrderData == null) return const SizedBox.shrink();

    final description = _serviceOrderData!['description'] ?? '';
    final notes = _serviceOrderData!['notes'] ?? '';

    return _buildCard(
      index: 3,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long, color: GlobalStyle.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Detail Layanan',
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

            // Service Description
            if (description.isNotEmpty) ...[
              Text(
                'Permintaan Customer:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                  fontFamily: GlobalStyle.fontFamily,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    fontFamily: GlobalStyle.fontFamily,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Service Notes (if any)
            if (notes.isNotEmpty) ...[
              Text(
                'Catatan Tambahan:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                  fontFamily: GlobalStyle.fontFamily,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber[200]!),
                ),
                child: Text(
                  notes,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    fontFamily: GlobalStyle.fontFamily,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_serviceOrderData == null || _isProcessing) {
      return const Center(child: CircularProgressIndicator());
    }

    final status = _serviceOrderData!['status'] ?? 'pending';

    // Show different buttons based on service order status
    if (status.toLowerCase() == 'pending') {
      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: Column(
              children: [
                // Accept Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _acceptServiceOrder,
                    icon: const Icon(Icons.check_circle, color: Colors.white),
                    label: const Text(
                      'Terima Pesanan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      elevation: 4,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Reject Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _isProcessing ? null : () => _cancelServiceOrder(reason: 'Ditolak oleh driver'),
                    icon: const Icon(Icons.cancel, size: 20),
                    label: const Text(
                      'Tolak Pesanan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    } else if (status.toLowerCase() == 'driver_found') {
      return Column(
        children: [
          // Start Service Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : () => _updateServiceOrderStatus('in_progress'),
              icon: const Icon(Icons.play_arrow, color: Colors.white),
              label: const Text(
                'Mulai Mengerjakan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                elevation: 4,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Chat Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _openWhatsApp,
              icon: const Icon(Icons.chat, size: 20),
              label: const Text(
                'Chat Customer',
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
    } else if (status.toLowerCase() == 'in_progress') {
      return Column(
        children: [
          // Complete Service Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : () => _updateServiceOrderStatus('completed'),
              icon: const Icon(Icons.check_circle, color: Colors.white),
              label: const Text(
                'Selesaikan Layanan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                elevation: 4,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Chat Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _openWhatsApp,
              icon: const Icon(Icons.chat, size: 20),
              label: const Text(
                'Chat Customer',
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
    } else {
      // For completed/cancelled orders, show contact button only
      return SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: _openWhatsApp,
          icon: const Icon(Icons.chat, color: Colors.white),
          label: const Text(
            'Chat Customer',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: GlobalStyle.primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
            elevation: 4,
          ),
        ),
      );
    }
  }

  // Get status color
  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'driver_found':
        return Colors.blue;
      case 'in_progress':
        return Colors.indigo;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: GlobalStyle.primaryColor),
          const SizedBox(height: 16),
          Text(
            'Memuat data pesanan...',
            style: TextStyle(
              color: GlobalStyle.fontColor,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 60),
          const SizedBox(height: 16),
          Text(
            'Terjadi Kesalahan',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Gagal memuat data pesanan',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              if (!_isAuthenticated) {
                _initializeAuthentication();
              } else {
                _loadServiceOrderData();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: GlobalStyle.primaryColor,
            ),
            child: Text(
              !_isAuthenticated ? 'Login Ulang' : 'Coba Lagi',
              style: const TextStyle(color: Colors.white),
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
        backgroundColor: Colors.white,
        title: Text(
          'Jasa Titip ke IT Del',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            fontFamily: GlobalStyle.fontFamily,
          ),
        ),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
              border: Border.all(color: GlobalStyle.primaryColor, width: 1.0),
            ),
            child: Icon(
              Icons.arrow_back_ios_new,
              color: GlobalStyle.primaryColor,
              size: 18,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingIndicator()
            : _errorMessage != null
            ? _buildErrorWidget()
            : SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildServiceOrderStatusCard(),
              const SizedBox(height: 16),
              _buildLocationDetailsCard(),
              const SizedBox(height: 16),
              _buildServiceDetailsCard(),
              const SizedBox(height: 16),
              _buildCustomerInfoCard(),
              const SizedBox(height: 80), // Space for action buttons
            ],
          ),
        ),
      ),
      bottomNavigationBar: _isLoading || _errorMessage != null
          ? null
          : Container(
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
        child: _buildActionButtons(),
      ),
    );
  }
}