import 'package:flutter/material.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Models/store.dart';
import 'package:del_pick/Services/image_service.dart';

class RateStore extends StatefulWidget {
  final StoreModel store;
  final double initialRating;
  final Function(double) onRatingChanged;
  final TextEditingController reviewController;
  final bool isLoading;

  const RateStore({
    Key? key,
    required this.store,
    required this.initialRating,
    required this.onRatingChanged,
    required this.reviewController,
    this.isLoading = false,
  }) : super(key: key);

  @override
  State<RateStore> createState() => _RateStoreState();
}

class _RateStoreState extends State<RateStore> with TickerProviderStateMixin {
  late double _storeRating;
  late AnimationController _starAnimationController;
  late AnimationController _storeImageController;
  late Animation<double> _starScaleAnimation;
  late Animation<double> _storeImageScaleAnimation;

  @override
  void initState() {
    super.initState();
    _storeRating = widget.initialRating;

    // Initialize animations
    _starAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _storeImageController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _starScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _starAnimationController,
      curve: Curves.elasticOut,
    ));

    _storeImageScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _storeImageController,
      curve: Curves.elasticOut,
    ));

    // Start store image animation
    _storeImageController.forward();
  }

  @override
  void dispose() {
    _starAnimationController.dispose();
    _storeImageController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(RateStore oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialRating != widget.initialRating) {
      setState(() {
        _storeRating = widget.initialRating;
      });
    }
  }

  void _onStarTapped(int starIndex) {
    setState(() {
      _storeRating = starIndex + 1.0;
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
    return 'Belum dinilai';
  }

  Color _getRatingColor(double rating) {
    if (rating >= 4) return Colors.green;
    if (rating >= 3) return Colors.orange;
    if (rating >= 2) return Colors.red;
    return Colors.grey;
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
            color: (customColor ?? GlobalStyle.primaryColor).withOpacity(0.1),
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

        // Rating Stars with Animation
        AbsorbPointer(
          absorbing: widget.isLoading,
          child: Opacity(
            opacity: widget.isLoading ? 0.7 : 1.0,
            child: Container(
              decoration: BoxDecoration(
                color: GlobalStyle.primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: GlobalStyle.primaryColor.withOpacity(0.2),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return GestureDetector(
                        onTap: () => _onStarTapped(index),
                        child: AnimatedBuilder(
                          animation: _starScaleAnimation,
                          builder: (context, child) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Transform.scale(
                                scale: index < rating ? _starScaleAnimation.value : 1.0,
                                child: Icon(
                                  index < rating ? Icons.star : Icons.star_border,
                                  color: index < rating ? Colors.amber : Colors.grey[400],
                                  size: 40,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  // Rating Label
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getRatingColor(rating).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getRatingLabel(rating),
                      style: TextStyle(
                        color: _getRatingColor(rating),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Review Text Field
        AbsorbPointer(
          absorbing: widget.isLoading,
          child: Opacity(
            opacity: widget.isLoading ? 0.7 : 1.0,
            child: Container(
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
                  hintText: 'Tulis ulasan anda untuk toko disini...',
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
                    Icons.rate_review,
                    color: GlobalStyle.primaryColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get store data using the model properties
    final String storeName = widget.store.name.isNotEmpty
        ? widget.store.name
        : 'Store';

    // Use processed image URL from the model
    final String? storeImageUrl = widget.store.imageUrl;

    return _buildInfoSection(
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
              // Store image with animation
              AnimatedBuilder(
                animation: _storeImageScaleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _storeImageScaleAnimation.value,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.indigo.withOpacity(0.3),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.indigo.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: storeImageUrl != null && storeImageUrl.isNotEmpty
                            ? ImageService.displayImage(
                          imageSource: storeImageUrl,
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                          placeholder: Container(
                            decoration: BoxDecoration(
                              color: Colors.indigo.withOpacity(0.2),
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo),
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                          errorWidget: Container(
                            decoration: BoxDecoration(
                              color: Colors.indigo.withOpacity(0.2),
                            ),
                            child: const Icon(Icons.store, color: Colors.indigo, size: 35),
                          ),
                        )
                            : Container(
                          decoration: BoxDecoration(
                            color: Colors.indigo.withOpacity(0.2),
                          ),
                          child: const Icon(Icons.store, color: Colors.indigo, size: 35),
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
                      storeName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),

                    // Store Address
                    if (widget.store.address.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                widget.store.address,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 6),

                    // Store Rating Display
                    if (widget.store.rating > 0)
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
                              '${widget.store.rating.toStringAsFixed(1)} (${widget.store.reviewCount} reviews)',
                              style: TextStyle(
                                color: Colors.amber[800],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 6),

                    // Store Open Hours
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: widget.store.isOpen ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: widget.store.isOpen ? Colors.green[700] : Colors.red[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.store.openHours.isNotEmpty
                                ? widget.store.openHours
                                : widget.store.statusDisplayName,
                            style: TextStyle(
                              color: widget.store.isOpen ? Colors.green[700] : Colors.red[700],
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Product Count
                    if (widget.store.totalProducts > 0)
                      Text(
                        '${widget.store.totalProducts} produk tersedia',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
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
          onRatingChanged: widget.onRatingChanged,
          controller: widget.reviewController,
        ),
      ],
    );
  }
}