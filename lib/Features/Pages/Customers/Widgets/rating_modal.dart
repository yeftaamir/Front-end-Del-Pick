// lib/Features/Pages/Customers/Widgets/rating_modal.dart
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../../Common/global_style.dart';

class RatingModal extends StatefulWidget {
  final String storeName;
  final String driverName;
  final int orderId;

  const RatingModal({
    Key? key,
    required this.storeName,
    required this.driverName,
    required this.orderId,
  }) : super(key: key);

  @override
  State<RatingModal> createState() => _RatingModalState();
}

class _RatingModalState extends State<RatingModal>
    with TickerProviderStateMixin {
  int _storeRating = 0;
  int _driverRating = 0;
  final TextEditingController _storeCommentController = TextEditingController();
  final TextEditingController _driverCommentController = TextEditingController();
  bool _isSubmitting = false;

  late AnimationController _slideController;
  late AnimationController _fadeController;
  late AnimationController _starController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _starAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _starController.dispose();
    _storeCommentController.dispose();
    _driverCommentController.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _starController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));

    _starAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _starController,
      curve: Curves.elasticOut,
    ));
  }

  void _startAnimations() {
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 100), () {
      _slideController.forward();
    });
  }

  void _animateStars() {
    _starController.reset();
    _starController.forward();
  }

  bool get _isFormValid {
    return _storeRating > 0 && _driverRating > 0;
  }

  Future<void> _submitRating() async {
    if (!_isFormValid) {
      _showValidationMessage();
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    // Simulate API call delay
    await Future.delayed(const Duration(seconds: 1));

    final ratingData = {
      'store_rating': _storeRating,
      'store_comment': _storeCommentController.text.trim(),
      'driver_rating': _driverRating,
      'driver_comment': _driverCommentController.text.trim(),
    };

    if (mounted) {
      Navigator.of(context).pop(ratingData);
    }
  }

  void _showValidationMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Mohon berikan rating untuk toko dan driver'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return 'Sangat Buruk';
      case 2:
        return 'Buruk';
      case 3:
        return 'Cukup';
      case 4:
        return 'Baik';
      case 5:
        return 'Sangat Baik';
      default:
        return 'Pilih Rating';
    }
  }

  Color _getRatingColor(int rating) {
    switch (rating) {
      case 1:
      case 2:
        return Colors.red;
      case 3:
        return Colors.orange;
      case 4:
      case 5:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        color: Colors.black.withOpacity(0.5),
        child: Center(
          child: SlideTransition(
            position: _slideAnimation,
            child: Container(
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(),
                    _buildContent(),
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            GlobalStyle.primaryColor,
            GlobalStyle.primaryColor.withOpacity(0.8),
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Lottie.asset(
            'assets/animations/check_animation.json',
            height: 80,
            width: 80,
            fit: BoxFit.contain,
            repeat: false,
          ),
          const SizedBox(height: 12),
          const Text(
            'Berikan Rating',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Pesanan #${widget.orderId} telah selesai',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildStoreRating(),
          const SizedBox(height: 24),
          _buildDriverRating(),
        ],
      ),
    );
  }

  Widget _buildStoreRating() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.store, color: GlobalStyle.primaryColor),
              const SizedBox(width: 8),
              Text(
                'Rating Toko',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: GlobalStyle.fontColor,
                  fontFamily: GlobalStyle.fontFamily,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.storeName,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          const SizedBox(height: 16),
          _buildStarRating(
            rating: _storeRating,
            onRatingChanged: (rating) {
              setState(() {
                _storeRating = rating;
              });
              _animateStars();
            },
          ),
          const SizedBox(height: 8),
          Text(
            _getRatingText(_storeRating),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _getRatingColor(_storeRating),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _storeCommentController,
            decoration: InputDecoration(
              hintText: 'Tulis komentar untuk toko (opsional)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: GlobalStyle.primaryColor),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
            maxLines: 3,
            style: TextStyle(
              fontSize: 14,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverRating() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.delivery_dining, color: GlobalStyle.primaryColor),
              const SizedBox(width: 8),
              Text(
                'Rating Driver',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: GlobalStyle.fontColor,
                  fontFamily: GlobalStyle.fontFamily,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.driverName,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          const SizedBox(height: 16),
          _buildStarRating(
            rating: _driverRating,
            onRatingChanged: (rating) {
              setState(() {
                _driverRating = rating;
              });
              _animateStars();
            },
          ),
          const SizedBox(height: 8),
          Text(
            _getRatingText(_driverRating),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _getRatingColor(_driverRating),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _driverCommentController,
            decoration: InputDecoration(
              hintText: 'Tulis komentar untuk driver (opsional)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: GlobalStyle.primaryColor),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
            maxLines: 3,
            style: TextStyle(
              fontSize: 14,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStarRating({
    required int rating,
    required Function(int) onRatingChanged,
  }) {
    return ScaleTransition(
      scale: _starAnimation,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(5, (index) {
          final starIndex = index + 1;
          return GestureDetector(
            onTap: () => onRatingChanged(starIndex),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                starIndex <= rating ? Icons.star : Icons.star_border,
                color: starIndex <= rating ? Colors.amber : Colors.grey[400],
                size: 32,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Skip Button
          Expanded(
            child: OutlinedButton(
              onPressed: _isSubmitting
                  ? null
                  : () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey[700],
                side: BorderSide(color: Colors.grey[400]!, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Lewati',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Submit Button
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitRating,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isFormValid
                    ? GlobalStyle.primaryColor
                    : Colors.grey[400],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: _isFormValid ? 2 : 0,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
                  : const Text(
                'Kirim Rating',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}