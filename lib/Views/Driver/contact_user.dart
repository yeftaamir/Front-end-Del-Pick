import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:lottie/lottie.dart';
import 'package:audioplayers/audioplayers.dart';

// Services
import 'package:del_pick/Services/customer_service.dart';
import 'package:del_pick/Services/order_service.dart';
import 'package:del_pick/Services/image_service.dart';
import 'package:del_pick/Services/auth_service.dart';

class ContactUserPage extends StatefulWidget {
  static const String route = '/Driver/ContactUser';

  final String orderId;
  final Map<String, dynamic>? orderData;

  const ContactUserPage({
    Key? key,
    required this.orderId,
    this.orderData,
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
  Map<String, dynamic>? _orderData;
  Map<String, dynamic>? _customerData;
  Map<String, dynamic>? _driverData;

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
      3, // Three card sections
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

      // Load order and customer data
      await _loadOrderData();

    } catch (e) {
      print('❌ ContactUser: Authentication error: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Authentication failed: $e';
        _isAuthenticated = false;
      });
    }
  }

  // Load order and customer data
  Future<void> _loadOrderData() async {
    if (!_isAuthenticated) {
      print('❌ ContactUser: Cannot load order data - not authenticated');
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      print('🔄 ContactUser: Loading order data for ID: ${widget.orderId}');

      // 1. Get order details using OrderService.getOrderById
      final orderResponse = await OrderService.getOrderById(widget.orderId);
      _orderData = orderResponse;

      print('📦 ContactUser: Order data loaded');

      // 2. Get customer details if customerId available
      if (_orderData!['customer_id'] != null || _orderData!['customerId'] != null) {
        final customerId = (_orderData!['customer_id'] ?? _orderData!['customerId']).toString();

        try {
          final customerResponse = await CustomerService.getCustomerById(customerId);
          _customerData = customerResponse;
          print('👤 ContactUser: Customer data loaded');
        } catch (e) {
          print('❌ ContactUser: Error fetching customer data: $e');
          // Continue without customer data
        }
      }

      setState(() {
        _isLoading = false;
      });

      // Start animations after data is loaded
      _startAnimations();

      print('✅ ContactUser: Order and customer data loaded successfully');

    } catch (e) {
      print('❌ ContactUser: Error loading order data: $e');
      setState(() {
        _errorMessage = 'Failed to load order data: $e';
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

  // Update order status using OrderService.updateOrderStatus
  Future<void> _updateOrderStatus(String status, {String? notes}) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      print('🔄 ContactUser: Updating order status to: $status');

      // Use OrderService.updateOrderStatus
      await OrderService.updateOrderStatus(
        orderId: widget.orderId,
        status: status,
        notes: notes ?? 'Status updated by driver',
      );

      // Play sound
      _playSound('audio/alert.wav');

      // Refresh order data
      await _loadOrderData();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status berhasil diperbarui ke: ${_getStatusDisplayName(status)}'),
            backgroundColor: status == 'confirmed' ? Colors.green : Colors.orange,
          ),
        );
      }

      // If confirmed, show success dialog
      if (status == 'confirmed') {
        _showSuccessDialog();
      }

    } catch (e) {
      print('❌ ContactUser: Error updating order status: $e');
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

  // Helper to get display name for status
  String _getStatusDisplayName(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Menunggu Konfirmasi';
      case 'confirmed':
        return 'Dikonfirmasi';
      case 'preparing':
        return 'Sedang Disiapkan';
      case 'on_delivery':
        return 'Dalam Pengantaran';
      case 'delivered':
        return 'Selesai';
      case 'cancelled':
        return 'Dibatalkan';
      case 'rejected':
        return 'Ditolak';
      default:
        return status;
    }
  }

  // Get status color
  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'preparing':
        return Colors.indigo;
      case 'on_delivery':
        return Colors.teal;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
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

  // Show success dialog after confirming order
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
                  'Pesanan Diterima!',
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

  // Open WhatsApp to contact customer
  Future<void> _openWhatsApp() async {
    try {
      final customerPhone = _customerData?['phone'] ?? _customerData?['phoneNumber'] ?? '';
      if (customerPhone.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nomor telepon customer tidak tersedia')),
          );
        }
        return;
      }

      String formattedPhone = customerPhone;
      if (customerPhone.startsWith('0')) {
        formattedPhone = '62${customerPhone.substring(1)}';
      } else if (!customerPhone.startsWith('+') && !customerPhone.startsWith('62')) {
        formattedPhone = '62$customerPhone';
      }

      final customerName = _customerData?['name'] ?? 'Customer';
      String message = 'Halo $customerName, saya driver dari Del Pick. Saya telah menerima pesanan jasa titip Anda #${widget.orderId}. ';

      final notes = _orderData?['notes'] ?? _orderData?['description'] ?? '';
      if (notes.isNotEmpty) {
        message += 'Detail pesanan: $notes. ';
      }

      message += 'Mohon berikan detail lebih lanjut untuk pembelian barang yang Anda inginkan.';

      String url = 'https://wa.me/$formattedPhone?text=${Uri.encodeComponent(message)}';

      if (await canLaunchUrlString(url)) {
        await launchUrlString(url);
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

  Widget _buildOrderStatusCard() {
    if (_orderData == null) return const SizedBox.shrink();

    final status = _orderData!['status'] ?? 'pending';
    final statusColor = _getStatusColor(status);
    final statusText = _getStatusDisplayName(status);
    final createdAt = _orderData!['created_at'] ?? _orderData!['createdAt'];
    final orderDate = createdAt != null ? DateTime.tryParse(createdAt) : DateTime.now();
    final formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(orderDate ?? DateTime.now());

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
                    Icons.shopping_bag,
                    color: GlobalStyle.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Pesanan Jasa Titip #${widget.orderId}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: GlobalStyle.fontColor,
                      fontFamily: GlobalStyle.fontFamily,
                    ),
                  ),
                ),
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
                      if (_customerData!['phone'] != null || _customerData!['phoneNumber'] != null) ...[
                        Row(
                          children: [
                            Icon(Icons.phone, color: Colors.grey[600], size: 16),
                            const SizedBox(width: 4),
                            Text(
                              _customerData!['phone'] ?? _customerData!['phoneNumber'] ?? '',
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

  Widget _buildOrderDetailsCard() {
    if (_orderData == null) return const SizedBox.shrink();

    final notes = _orderData!['notes'] ?? _orderData!['description'] ?? '';
    final location = _orderData!['delivery_address'] ?? _orderData!['deliveryAddress'] ?? '';
    final totalAmount = _orderData!['total_amount'] ?? _orderData!['totalAmount'] ?? _orderData!['total'] ?? 0.0;
    final deliveryFee = _orderData!['delivery_fee'] ?? _orderData!['deliveryFee'] ?? 0.0;

    return _buildCard(
      index: 2,
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
                  'Detail Pesanan',
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

            // Order Notes/Description
            if (notes.isNotEmpty) ...[
              Text(
                'Catatan Pesanan:',
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
                  notes,
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

            // Delivery Location
            if (location.isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.location_on, color: Colors.grey[600], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lokasi Pengantaran:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          location,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Pricing Info
            const Divider(),
            const SizedBox(height: 12),

            if (deliveryFee > 0) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Biaya Pengiriman:',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      fontFamily: GlobalStyle.fontFamily,
                    ),
                  ),
                  Text(
                    GlobalStyle.formatRupiah(deliveryFee),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: GlobalStyle.fontColor,
                      fontFamily: GlobalStyle.fontFamily,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            if (totalAmount > 0) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Pesanan:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: GlobalStyle.fontColor,
                      fontFamily: GlobalStyle.fontFamily,
                    ),
                  ),
                  Text(
                    GlobalStyle.formatRupiah(totalAmount),
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

  Widget _buildActionButtons() {
    if (_orderData == null || _isProcessing) {
      return const Center(child: CircularProgressIndicator());
    }

    final status = _orderData!['status'] ?? 'pending';

    // Show different buttons based on order status
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
                    onPressed: _isProcessing ? null : () => _updateOrderStatus('confirmed', notes: 'Pesanan jasa titip diterima'),
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
                    onPressed: _isProcessing ? null : () => _updateOrderStatus('rejected', notes: 'Pesanan jasa titip ditolak'),
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
    } else {
      // For non-pending orders, show contact button only
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
                _loadOrderData();
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
          'Pesanan Jasa Titip',
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
              _buildOrderStatusCard(),
              const SizedBox(height: 16),
              _buildOrderDetailsCard(),
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