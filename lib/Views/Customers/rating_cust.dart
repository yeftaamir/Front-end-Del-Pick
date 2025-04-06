import 'package:flutter/material.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:lottie/lottie.dart';

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

  Widget _buildInfoSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Color? customColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: GlobalStyle.borderColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: (customColor ?? GlobalStyle.primaryColor).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: customColor ?? GlobalStyle.primaryColor),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: customColor ?? GlobalStyle.primaryColor,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildRatingSection({
    required String title,
    required double rating,
    required Function(double) onRatingChanged,
    required TextEditingController controller,
    bool isDriver = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: GlobalStyle.fontColor,
            fontFamily: GlobalStyle.fontFamily,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: GlobalStyle.lightColor.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: GlobalStyle.primaryColor.withOpacity(0.1),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return GestureDetector(
                onTap: () => onRatingChanged(index + 1.0),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    begin: 0.0,
                    end: index < rating ? 1.0 : 0.0,
                  ),
                  duration: const Duration(milliseconds: 300),
                  builder: (context, value, _) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        index < rating ? Icons.star : Icons.star_border,
                        color: Color.lerp(
                          Colors.grey[400],
                          isDriver ? Colors.orange : Colors.amber,
                          value,
                        ),
                        size: 40 + (value * 5),
                      ),
                    );
                  },
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: GlobalStyle.primaryColor.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Tulis ulasan anda disini...',
              hintStyle: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: GlobalStyle.borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: GlobalStyle.borderColor.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: GlobalStyle.primaryColor, width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(16),
              prefixIcon: Icon(
                isDriver ? Icons.comment : Icons.rate_review,
                color: isDriver ? Colors.orange : GlobalStyle.primaryColor,
              ),
            ),
          ),
        ),
      ],
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

              // Store Info Section
              _buildCard(
                index: 0,
                child: _buildInfoSection(
                  title: 'Informasi Toko',
                  icon: Icons.store,
                  customColor: Colors.indigo,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.indigo.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.store, color: Colors.indigo, size: 30),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.storeName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.indigo.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'Pesanan Diterima',
                                    style: TextStyle(
                                      color: Colors.indigo,
                                      fontSize: 12,
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
                    const SizedBox(height: 20),
                    _buildRatingSection(
                      title: 'Beri rating untuk toko',
                      rating: _storeRating,
                      onRatingChanged: (value) => setState(() => _storeRating = value),
                      controller: _storeReviewController,
                    ),
                  ],
                ),
              ),

              // Driver Info Section
              _buildCard(
                index: 1,
                child: _buildInfoSection(
                  title: 'Informasi Driver',
                  icon: Icons.delivery_dining,
                  customColor: Colors.orange,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.person, color: Colors.orange, size: 30),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.driverName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.directions_car, size: 14, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(
                                        widget.vehicleNumber,
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
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
                    const SizedBox(height: 20),
                    _buildRatingSection(
                      title: 'Beri rating untuk driver',
                      rating: _driverRating,
                      onRatingChanged: (value) => setState(() => _driverRating = value),
                      controller: _driverReviewController,
                      isDriver: true,
                    ),
                  ],
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