import 'package:flutter/material.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:lottie/lottie.dart';

// Import Models
import 'package:del_pick/Models/order.dart';
import 'package:del_pick/Models/driver.dart';
import 'package:del_pick/Models/store.dart';

// Import Services
import 'package:del_pick/Services/order_service.dart';
import 'package:del_pick/Services/driver_service.dart';
import 'package:del_pick/Services/store_service.dart';
import 'package:del_pick/Services/tracking_service.dart';
import 'package:del_pick/Services/auth_service.dart';

// Import Components
import 'package:del_pick/Views/Component/rate_store.dart';
import 'package:del_pick/Views/Component/rate_driver.dart';

class RatingCustomerPage extends StatefulWidget {
  static const String route = "/Customers/RatingCustomerPage";

  final OrderModel order;

  const RatingCustomerPage({
    Key? key,
    required this.order,
  }) : super(key: key);

  @override
  State<RatingCustomerPage> createState() => _RatingCustomerPageState();
}

class _RatingCustomerPageState extends State<RatingCustomerPage> with TickerProviderStateMixin {
  // Rating values
  double _storeRating = 0;
  double _driverRating = 0;
  final TextEditingController _storeReviewController = TextEditingController();
  final TextEditingController _driverReviewController = TextEditingController();

  // Animation controllers
  late List<AnimationController> _cardControllers;
  late List<Animation<Offset>> _cardAnimations;

  // State management
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  // Data objects
  StoreModel? _storeDetail;
  DriverModel? _driverDetail;
  Map<String, dynamic>? _orderTrackingData;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _validateAuthenticationAndLoadData();
  }

  void _initializeAnimations() {
    // Initialize animation controllers for each card section
    _cardControllers = List.generate(
      3, // Number of card sections
          (index) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 600 + (index * 200)),
      ),
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
  }

  @override
  void dispose() {
    _storeReviewController.dispose();
    _driverReviewController.dispose();
    for (var controller in _cardControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // ✅ FIXED: Enhanced authentication validation using getUserData() and getRoleSpecificData()
  Future<void> _validateAuthenticationAndLoadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('🔒 RatingCustomerPage: Validating authentication...');

      // Validate user authentication using new methods
      final userData = await AuthService.getUserData();
      final roleData = await AuthService.getRoleSpecificData();

      if (userData == null) {
        throw Exception('Authentication required: Please login');
      }

      if (roleData == null) {
        throw Exception('Role data not found: Please login as customer');
      }

      // Validate customer role
      final userRole = await AuthService.getUserRole();
      if (userRole?.toLowerCase() != 'customer') {
        throw Exception('Access denied: Only customers can rate orders');
      }

      final hasAccess = await AuthService.validateCustomerAccess();
      if (!hasAccess) {
        throw Exception('Access denied: Customer authentication required');
      }

      print('✅ RatingCustomerPage: Customer authentication validated');
      print('   - User ID: ${userData['id']}');
      print('   - User Name: ${userData['name']}');
      print('   - Role: $userRole');

      // After authentication, load required data
      await _loadRequiredData();

    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Authentication failed: ${e.toString()}';
      });
      print('❌ RatingCustomerPage: Authentication error: $e');

      // Show error and navigate back after delay
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          Navigator.pop(context);
        }
      });
    }
  }

  // Load required data using proper services
  Future<void> _loadRequiredData() async {
    try {
      print('📊 RatingCustomerPage: Loading required data...');

      // Load data in parallel for better performance
      await Future.wait([
        _loadStoreDetail(),
        _loadDriverDetail(),
        _loadOrderTrackingData(),
      ]);

      setState(() {
        _isLoading = false;
      });

      // Start animations sequentially after data is loaded
      Future.delayed(const Duration(milliseconds: 100), () {
        for (var controller in _cardControllers) {
          controller.forward();
        }
      });

      print('✅ RatingCustomerPage: All data loaded successfully');
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load rating data: $e';
      });
      print('❌ RatingCustomerPage: Error loading data: $e');
    }
  }

  // Load store detail using StoreService.getStoreById()
  Future<void> _loadStoreDetail() async {
    try {
      final storeData = await StoreService.getStoreById(widget.order.storeId.toString());
      _storeDetail = StoreModel.fromJson(storeData);
      print('✅ RatingCustomerPage: Store detail loaded: ${_storeDetail?.name}');
    } catch (e) {
      print('⚠️ RatingCustomerPage: Error loading store detail: $e');
      // Create fallback store model from order data
      _storeDetail = widget.order.store;
    }
  }

  // Load driver detail using DriverService.getDriverById()
  Future<void> _loadDriverDetail() async {
    if (widget.order.driverId == null) {
      print('ℹ️ RatingCustomerPage: No driver assigned to this order');
      return;
    }

    try {
      final driverData = await DriverService.getDriverById(widget.order.driverId.toString());
      _driverDetail = DriverModel.fromJson(driverData);
      print('✅ RatingCustomerPage: Driver detail loaded: ${_driverDetail?.name}');
    } catch (e) {
      print('⚠️ RatingCustomerPage: Error loading driver detail: $e');
      // Try to get driver from tracking data as fallback
      try {
        final trackingData = await TrackingService.getTrackingData(widget.order.id.toString());
        if (trackingData['driver'] != null) {
          _driverDetail = DriverModel.fromJson(trackingData['driver']);
        }
      } catch (trackingError) {
        print('⚠️ RatingCustomerPage: Error loading driver from tracking: $trackingError');
        // Use driver from order data if available
        _driverDetail = widget.order.driver;
      }
    }
  }

  // Load order tracking data using TrackingService.getTrackingData()
  Future<void> _loadOrderTrackingData() async {
    try {
      _orderTrackingData = await TrackingService.getTrackingData(widget.order.id.toString());
      print('✅ RatingCustomerPage: Tracking data loaded');
    } catch (e) {
      print('ℹ️ RatingCustomerPage: Tracking data not available: $e');
      // This is optional data, so we don't need to fail if it's not available
    }
  }

  // ✅ FIXED: Enhanced review submission with proper validation
  Future<void> _submitReviews() async {
    if (_isSubmitting) return;

    // ✅ FIXED: Enhanced validation - ensure at least one rating is given and > 0
    if (_storeRating <= 0 && _driverRating <= 0) {
      _showErrorSnackBar('Mohon berikan rating minimal 1 bintang untuk toko atau driver');
      return;
    }

    // Additional validation for rating values
    if (_storeRating > 0 && (_storeRating < 1 || _storeRating > 5)) {
      _showErrorSnackBar('Rating toko harus antara 1-5 bintang');
      return;
    }

    if (_driverRating > 0 && (_driverRating < 1 || _driverRating > 5)) {
      _showErrorSnackBar('Rating driver harus antara 1-5 bintang');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      print('📝 RatingCustomerPage: Submitting reviews...');
      print('   - Store rating: $_storeRating');
      print('   - Driver rating: $_driverRating');

      // ✅ FIXED: Prepare review data with proper validation
      final Map<String, dynamic> orderReview = {};
      final Map<String, dynamic> driverReview = {};

      // Only include store review if rating is provided and > 0
      if (_storeRating > 0) {
        orderReview['rating'] = _storeRating.round();
        final storeComment = _storeReviewController.text.trim();
        if (storeComment.isNotEmpty) {
          orderReview['comment'] = storeComment;
        }
      }

      // Only include driver review if rating is provided and > 0
      if (_driverRating > 0) {
        driverReview['rating'] = _driverRating.round();
        final driverComment = _driverReviewController.text.trim();
        if (driverComment.isNotEmpty) {
          driverReview['comment'] = driverComment;
        }
      }

      print('📋 RatingCustomerPage: Review data prepared');
      print('   - Order review: $orderReview');
      print('   - Driver review: $driverReview');

      // Submit review using OrderService.createReview()
      final result = await OrderService.createReview(
        orderId: widget.order.id.toString(),
        orderReview: orderReview,
        driverReview: driverReview,
      );

      print('✅ RatingCustomerPage: Reviews submitted successfully');
      await _showSuccessDialog();

    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
      print('❌ RatingCustomerPage: Submit reviews error: $e');
      _showErrorSnackBar(_errorMessage!);
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  // Show success dialog with animation
  Future<void> _showSuccessDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/animations/check_animation.json',
                  width: 200,
                  height: 200,
                  repeat: false,
                ),
                const SizedBox(height: 20),
                const Text(
                  "Terima kasih atas ulasannya!",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Ulasan Anda sangat berarti untuk meningkatkan layanan kami",
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
                    elevation: 5,
                  ),
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context, {
                      'storeRating': _storeRating > 0 ? _storeRating.round() : null,
                      'storeComment': _storeRating > 0 ? _storeReviewController.text.trim() : null,
                      'driverRating': _driverRating > 0 ? _driverRating.round() : null,
                      'driverComment': _driverRating > 0 ? _driverReviewController.text.trim() : null,
                    }); // Return to previous screen with review data
                  },
                  child: const Text(
                    "OK",
                    style: TextStyle(
                      color: Colors.white,
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

  // Show error snackbar
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Widget _buildCard({required Widget child, required int index}) {
    return SlideTransition(
      position: _cardAnimations[index],
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 5),
              spreadRadius: 2,
            ),
          ],
        ),
        child: child,
      ),
    );
  }

  // Build error message card
  Widget _buildErrorCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage ?? 'An unknown error occurred',
              style: const TextStyle(color: Colors.red),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.red),
            onPressed: _validateAuthenticationAndLoadData,
          ),
        ],
      ),
    );
  }

  // Build loading state
  Widget _buildLoadingState() {
    return Scaffold(
      backgroundColor: const Color(0xffF5F8FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leadingWidth: 70,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: GlobalStyle.primaryColor.withOpacity(0.1),
                border: Border.all(color: GlobalStyle.primaryColor, width: 1.0),
              ),
              child: Icon(Icons.arrow_back_ios_new, color: GlobalStyle.primaryColor, size: 18),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Text(
          'Beri Ulasan',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
            fontFamily: GlobalStyle.fontFamily,
          ),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/animations/loading_animation.json',
              width: 150,
              height: 150,
            ),
            const SizedBox(height: 16),
            Text(
              "Memuat Data Rating...",
              style: TextStyle(
                color: GlobalStyle.primaryColor,
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingState();
    }

    return Scaffold(
      backgroundColor: const Color(0xffF5F8FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leadingWidth: 70,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: GlobalStyle.primaryColor.withOpacity(0.1),
                border: Border.all(color: GlobalStyle.primaryColor, width: 1.0),
              ),
              child: Icon(Icons.arrow_back_ios_new, color: GlobalStyle.primaryColor, size: 18),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Text(
          'Beri Ulasan',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
            fontFamily: GlobalStyle.fontFamily,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  'Bagaimana pengalaman Anda?',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: GlobalStyle.fontColor,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
              ),

              Text(
                'Ulasan Anda membantu kami meningkatkan layanan',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontFamily: GlobalStyle.fontFamily,
                ),
              ),

              const SizedBox(height: 24),

              // Show error message if any
              if (_errorMessage != null)
                _buildErrorCard(),

              // Store Rating Section
              if (_storeDetail != null)
                _buildCard(
                  index: 0,
                  child: RateStore(
                    store: _storeDetail!,
                    initialRating: _storeRating,
                    onRatingChanged: (value) => setState(() => _storeRating = value),
                    reviewController: _storeReviewController,
                    isLoading: _isSubmitting,
                  ),
                ),

              // Driver Rating Section (only shown if there's driver info)
              if (_driverDetail != null)
                _buildCard(
                  index: 1,
                  child: RateDriver(
                    driver: _driverDetail!,
                    initialRating: _driverRating,
                    onRatingChanged: (value) => setState(() => _driverRating = value),
                    reviewController: _driverReviewController,
                    isLoading: _isSubmitting,
                  ),
                ),

              // Submit Button
              _buildCard(
                index: 2,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        GlobalStyle.primaryColor.withOpacity(0.8),
                        GlobalStyle.primaryColor,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Terima Kasih Atas Pesanan Anda',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pesanan #${widget.order.id} telah selesai',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Total: ${widget.order.formatTotalAmount()}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitReviews,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: GlobalStyle.primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            elevation: 5,
                            disabledBackgroundColor: Colors.grey[300],
                            disabledForegroundColor: Colors.grey[600],
                          ),
                          child: _isSubmitting
                              ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(GlobalStyle.primaryColor),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Mengirim Ulasan...',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          )
                              : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.send_rounded),
                              SizedBox(width: 8),
                              Text(
                                'Kirim Ulasan',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
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
            ],
          ),
        ),
      ),
    );
  }
}