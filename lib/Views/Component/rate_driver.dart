import 'package:flutter/material.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Models/driver.dart';
import 'package:del_pick/Services/image_service.dart';

class RateDriver extends StatefulWidget {
  final DriverModel driver;
  final double initialRating;
  final Function(double) onRatingChanged;
  final TextEditingController reviewController;
  final bool isLoading;

  const RateDriver({
    Key? key,
    required this.driver,
    required this.initialRating,
    required this.onRatingChanged,
    required this.reviewController,
    this.isLoading = false,
  }) : super(key: key);

  @override
  State<RateDriver> createState() => _RateDriverState();
}

class _RateDriverState extends State<RateDriver> with TickerProviderStateMixin {
  late double _driverRating;
  late AnimationController _starAnimationController;
  late AnimationController _avatarAnimationController;
  late Animation<double> _starScaleAnimation;
  late Animation<double> _avatarBounceAnimation;

  @override
  void initState() {
    super.initState();
    _driverRating = widget.initialRating;

    // Initialize animations
    _starAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _avatarAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _starScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _starAnimationController,
      curve: Curves.elasticOut,
    ));

    _avatarBounceAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _avatarAnimationController,
      curve: Curves.elasticOut,
    ));

    // Start avatar animation
    _avatarAnimationController.forward();
  }

  @override
  void dispose() {
    _starAnimationController.dispose();
    _avatarAnimationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(RateDriver oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialRating != widget.initialRating) {
      setState(() {
        _driverRating = widget.initialRating;
      });
    }
  }

  void _onStarTapped(int starIndex) {
    setState(() {
      _driverRating = starIndex + 1.0;
    });
    widget.onRatingChanged(starIndex + 1.0);

    // Trigger star animation
    _starAnimationController.forward().then((_) {
      _starAnimationController.reverse();
    });
  }

  String _getRatingLabel(double rating) {
    if (rating >= 5) return 'Sangat Puas';
    if (rating >= 4) return 'Puas';
    if (rating >= 3) return 'Cukup';
    if (rating >= 2) return 'Kurang';
    if (rating >= 1) return 'Sangat Kurang';
    return 'Tap untuk memberi rating';
  }

  Color _getRatingColor(double rating) {
    if (rating >= 4) return Colors.green;
    if (rating >= 3) return Colors.orange;
    if (rating >= 2) return Colors.red;
    if (rating >= 1) return Colors.grey;
    return Colors.grey[400]!;
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
        boxShadow: [
          BoxShadow(
            color: (customColor ?? Colors.orange).withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: (customColor ?? Colors.orange).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: customColor ?? Colors.orange),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: customColor ?? Colors.orange,
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

        // ✅ FIXED: Enhanced rating stars with better visual feedback
        AbsorbPointer(
          absorbing: widget.isLoading,
          child: Opacity(
            opacity: widget.isLoading ? 0.7 : 1.0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: rating > 0
                      ? Colors.orange.withOpacity(0.3)
                      : Colors.grey.withOpacity(0.3),
                  width: rating > 0 ? 2 : 1,
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  // Instruction text for better UX
                  if (rating <= 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.touch_app, color: Colors.blue[700], size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Tap bintang untuk memberi rating',
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return GestureDetector(
                        onTap: () => _onStarTapped(index),
                        child: AnimatedBuilder(
                          animation: _starScaleAnimation,
                          builder: (context, child) {
                            final isSelected = index < rating;
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Transform.scale(
                                scale: isSelected ? _starScaleAnimation.value : 1.0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.orange.withOpacity(0.2)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    isSelected ? Icons.star : Icons.star_border,
                                    color: isSelected ? Colors.orange : Colors.grey[400],
                                    size: 40,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),

                  // Rating Label with better styling
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _getRatingColor(rating).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getRatingColor(rating).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          rating > 0 ? Icons.sentiment_satisfied : Icons.sentiment_neutral,
                          color: _getRatingColor(rating),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _getRatingLabel(rating),
                          style: TextStyle(
                            color: _getRatingColor(rating),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // ✅ ENHANCED: Review Text Field with conditional styling
        AbsorbPointer(
          absorbing: widget.isLoading,
          child: Opacity(
            opacity: widget.isLoading ? 0.7 : 1.0,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: controller,
                maxLines: 3,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: rating > 0
                      ? 'Tulis ulasan anda untuk driver disini...'
                      : 'Berikan rating terlebih dahulu untuk menulis ulasan',
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
                    borderSide: BorderSide(
                      color: rating > 0
                          ? Colors.orange.withOpacity(0.3)
                          : Colors.grey.withOpacity(0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Colors.orange, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                  prefixIcon: Icon(
                    Icons.comment,
                    color: rating > 0
                        ? Colors.orange
                        : Colors.grey[400],
                  ),
                  counterStyle: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                enabled: rating > 0, // Only enable if rating is given
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get driver data using the model properties
    final String driverName = widget.driver.name.isNotEmpty
        ? widget.driver.name
        : 'Driver';

    final String vehicleNumber = widget.driver.vehiclePlate.isNotEmpty
        ? widget.driver.vehiclePlate
        : 'No Plate';

    // Use processed avatar URL from the model
    final String? avatarUrl = widget.driver.avatar;

    return _buildInfoSection(
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
              // Driver profile image with animation
              AnimatedBuilder(
                animation: _avatarBounceAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _avatarBounceAnimation.value,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.3),
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: avatarUrl != null && avatarUrl.isNotEmpty
                            ? ImageService.displayImage(
                          imageSource: avatarUrl,
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                          placeholder: Container(
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                          errorWidget: Container(
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                            ),
                            child: const Icon(Icons.person, color: Colors.orange, size: 35),
                          ),
                        )
                            : Container(
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                          ),
                          child: const Icon(Icons.person, color: Colors.orange, size: 35),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driverName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Driver Rating Display
                    if (widget.driver.rating > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.driver.rating.toStringAsFixed(1)} (${widget.driver.reviewsCount} reviews)',
                              style: TextStyle(
                                color: Colors.amber[800],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 8),

                    // Vehicle Information
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.directions_car, size: 16, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text(
                            vehicleNumber,
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Driver Status
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: widget.driver.isAvailable ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.driver.statusDisplayName,
                        style: TextStyle(
                          color: widget.driver.isAvailable ? Colors.green[700] : Colors.red[700],
                          fontSize: 11,
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
          title: 'Beri rating untuk driver',
          rating: _driverRating,
          onRatingChanged: widget.onRatingChanged,
          controller: widget.reviewController,
        ),
      ],
    );
  }
}