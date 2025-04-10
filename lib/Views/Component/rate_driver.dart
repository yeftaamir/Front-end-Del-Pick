import 'package:flutter/material.dart';
import 'package:del_pick/Common/global_style.dart';

class RateDriver extends StatefulWidget {
  final String driverName;
  final String vehicleNumber;
  final double initialRating;
  final Function(double) onRatingChanged;
  final TextEditingController reviewController;

  const RateDriver({
    Key? key,
    required this.driverName,
    required this.vehicleNumber,
    required this.initialRating,
    required this.onRatingChanged,
    required this.reviewController,
  }) : super(key: key);

  @override
  State<RateDriver> createState() => _RateDriverState();
}

class _RateDriverState extends State<RateDriver> {
  late double _driverRating;

  @override
  void initState() {
    super.initState();
    _driverRating = widget.initialRating;
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
                onTap: () {
                  setState(() {
                    _driverRating = index + 1.0;
                  });
                  onRatingChanged(index + 1.0);
                },
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
                          Colors.orange,
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
              prefixIcon: const Icon(
                Icons.comment,
                color: Colors.orange,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
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
          onRatingChanged: widget.onRatingChanged,
          controller: widget.reviewController,
        ),
      ],
    );
  }
}