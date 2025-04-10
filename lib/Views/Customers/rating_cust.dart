import 'package:flutter/material.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:lottie/lottie.dart';
import 'package:del_pick/Views/Component/rate_store.dart';
import 'package:del_pick/Views/Component/rate_driver.dart';

class OrderItem {
  final String name;
  final String formattedPrice;

  OrderItem({
    required this.name,
    required this.formattedPrice,
  });
}

class RatingCustomerPage extends StatefulWidget {
  static const String route = "/Customers/RatingCustomerPage";

  final String storeName;
  final String driverName;
  final String vehicleNumber;
  final List<OrderItem> orderItems;
  final double totalAmount;

  const RatingCustomerPage({
    Key? key,
    required this.storeName,
    required this.driverName,
    required this.vehicleNumber,
    required this.orderItems,
    this.totalAmount = 0.0,
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

              // Store Rating Section
              _buildCard(
                index: 0,
                child: RateStore(
                  storeName: widget.storeName,
                  initialRating: _storeRating,
                  onRatingChanged: (value) => setState(() => _storeRating = value),
                  reviewController: _storeReviewController,
                ),
              ),

              // Driver Rating Section
              _buildCard(
                index: 1,
                child: RateDriver(
                  driverName: widget.driverName,
                  vehicleNumber: widget.vehicleNumber,
                  initialRating: _driverRating,
                  onRatingChanged: (value) => setState(() => _driverRating = value),
                  reviewController: _driverReviewController,
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
                        'Ulasan Anda sangat berarti untuk meningkatkan layanan kami',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () async {
                          await _showSuccessDialog();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: GlobalStyle.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          elevation: 5,
                        ),
                        child: Row(
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