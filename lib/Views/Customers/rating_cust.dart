import 'package:flutter/material.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:lottie/lottie.dart';
import 'package:del_pick/Views/Component/rate_store.dart';
import 'package:del_pick/Views/Component/rate_driver.dart';
import 'package:del_pick/Models/order.dart';
import 'package:del_pick/Models/driver.dart';
import 'package:del_pick/Services/order_service.dart';
import 'package:del_pick/Services/driver_service.dart';

class RatingCustomerPage extends StatefulWidget {
  static const String route = "/Customers/RatingCustomerPage";

  final Order order;

  const RatingCustomerPage({
    Key? key,
    required this.order,
  }) : super(key: key);

  @override
  State<RatingCustomerPage> createState() => _RatingCustomerPageState();
}

class _RatingCustomerPageState extends State<RatingCustomerPage> with TickerProviderStateMixin {
  double _storeRating = 0;
  double _driverRating = 0;
  final TextEditingController _storeReviewController = TextEditingController();
  final TextEditingController _driverReviewController = TextEditingController();

  // Animation controllers
  late List<AnimationController> _cardControllers;
  late List<Animation<Offset>> _cardAnimations;

  // State management
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  // Driver data
  Driver? _driver;
  bool _isLoadingDriver = false;

  @override
  void initState() {
    super.initState();

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

    // Start animations sequentially
    Future.delayed(const Duration(milliseconds: 100), () {
      for (var controller in _cardControllers) {
        controller.forward();
      }
    });

    // Fetch the driver data
    _fetchDriverData();
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

  // Fetch driver data if available
  Future<void> _fetchDriverData() async {
    if (widget.order.driverId == null) {
      return;
    }

    setState(() {
      _isLoadingDriver = true;
    });

    try {
      final driverData = await DriverService.getDriverById(widget.order.driverId.toString());
      setState(() {
        _driver = Driver.fromJson(driverData);
        _isLoadingDriver = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load driver data: $e';
        _isLoadingDriver = false;
      });
    }
  }

  // Submit reviews to backend
  Future<void> _submitReviews() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      // Convert ratings to integer values (1-5)
      final int storeRatingInt = _storeRating.round();
      final int driverRatingInt = _driverRating.round();

      // Only submit ratings that have been set by the user
      final bool success = await OrderService.reviewOrder(
        widget.order.id,
        storeRating: storeRatingInt > 0 ? storeRatingInt : null,
        storeComment: _storeReviewController.text.isNotEmpty ? _storeReviewController.text : null,
        driverRating: driverRatingInt > 0 ? driverRatingInt : null,
        driverComment: _driverReviewController.text.isNotEmpty ? _driverReviewController.text : null,
      );

      setState(() {
        _isSubmitting = false;
      });

      if (success) {
        await _showSuccessDialog();
      } else {
        setState(() {
          _errorMessage = 'Failed to submit review. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Error: $e';
      });
    }
  }

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
                    Navigator.pushReplacementNamed(context, '/Customers/HistoryCustomer');
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
            icon: const Icon(Icons.close, color: Colors.red),
            onPressed: () {
              setState(() {
                _errorMessage = null;
              });
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
              _buildCard(
                index: 0,
                child: RateStore(
                  store: widget.order.store,
                  initialRating: _storeRating,
                  onRatingChanged: (value) => setState(() => _storeRating = value),
                  reviewController: _storeReviewController,
                  isLoading: _isSubmitting,
                ),
              ),

              // Driver Rating Section (only shown if there's driver info)
              if (_isLoadingDriver)
                _buildCard(
                  index: 1,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    alignment: Alignment.center,
                    child: const Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading driver data...'),
                      ],
                    ),
                  ),
                )
              else if (_driver != null)
                _buildCard(
                  index: 1,
                  child: RateDriver(
                    driver: _driver!,
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
                        'Pesanan #${widget.order.code} telah selesai',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Total: ${widget.order.formatTotal()}',
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
                              : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.send_rounded),
                              const SizedBox(width: 8),
                              const Text(
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