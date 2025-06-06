import 'package:flutter/material.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:del_pick/Models/order.dart';
import 'package:del_pick/Models/driver.dart';
import 'package:del_pick/Models/order_enum.dart';
import 'package:del_pick/Services/order_service.dart';
import 'package:del_pick/Services/driver_service.dart';
import 'package:del_pick/Services/image_service.dart';
import 'package:del_pick/Services/tracking_service.dart';
import '../Component/cust_order_status.dart';
import 'rating_cust.dart';
import 'home_cust.dart';

class HistoryDetailPage extends StatefulWidget {
  static const String route = "/Customers/HistoryDetailPage";

  final Order order;

  const HistoryDetailPage({
    Key? key,
    required this.order,
  }) : super(key: key);

  @override
  State<HistoryDetailPage> createState() => _HistoryDetailPageState();
}

class _HistoryDetailPageState extends State<HistoryDetailPage> with TickerProviderStateMixin {
  late List<AnimationController> _cardControllers;
  late List<Animation<Offset>> _cardAnimations;

  bool _isLoading = false;
  bool _hasGivenRating = false;
  String? _errorMessage;

  // Driver details
  Driver? _driver;
  bool _isLoadingDriver = false;

  // Order rating details
  Map<String, dynamic>? _orderRating;
  Map<String, dynamic>? _driverRating;
  bool _isLoadingRatings = false;

  @override
  void initState() {
    super.initState();

    // Set initial rating status
    _hasGivenRating = widget.order.hasGivenRating;

    // Initialize animation controllers for each card section
    _cardControllers = List.generate(
      6, // Number of card sections
          (index) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 600 + (index * 200)),
      ),
    );

    // Create slide animations for each card
    _cardAnimations = _cardControllers.map((controller) {
      return Tween<Offset>(
        begin: const Offset(0, -0.5),
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

    // Load additional data
    if (widget.order.driverId != null) {
      _loadDriverDetails(widget.order.driverId.toString());
    }
    _refreshOrderDetails();
  }

  @override
  void dispose() {
    for (var controller in _cardControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // Fetch latest order details and ratings from the API
  Future<void> _refreshOrderDetails() async {
    try {
      final orderData = await OrderService.getOrderDetail(widget.order.id);
      if (mounted) {
        setState(() {
          // Update rating status
          _hasGivenRating = orderData['has_given_rating'] ?? widget.order.hasGivenRating;

          // Load existing ratings if available
          if (orderData['orderReviews'] != null &&
              orderData['orderReviews'] is List &&
              (orderData['orderReviews'] as List).isNotEmpty) {
            _orderRating = (orderData['orderReviews'] as List).first;
          }

          if (orderData['driverReviews'] != null &&
              orderData['driverReviews'] is List &&
              (orderData['driverReviews'] as List).isNotEmpty) {
            _driverRating = (orderData['driverReviews'] as List).first;
          }
        });
      }
    } catch (e) {
      print('Error refreshing order details: $e');
    }
  }

  // Load driver details
  Future<void> _loadDriverDetails(String driverId) async {
    if (_isLoadingDriver) return;

    setState(() {
      _isLoadingDriver = true;
    });

    try {
      final trackingData = await TrackingService.getOrderTracking(widget.order.id);
      if (trackingData['driver'] != null) {
        final driverInfo = {
          'id': driverId,
          'name': trackingData['driver']['name'] ?? 'Unknown Driver',
          'phoneNumber': trackingData['driver']['phoneNumber'] ?? '',
          'vehicleNumber': trackingData['driver']['vehicleNumber'] ?? '-',
          'profileImageUrl': trackingData['driver']['avatar'] ?? '',
          'rating': trackingData['driver']['rating'] ?? 4.5,
        };

        if (mounted) {
          setState(() {
            _driver = Driver.fromJson(driverInfo);
            _isLoadingDriver = false;
          });
        }
      }
    } catch (e) {
      print('Error loading driver details: $e');
      if (mounted) {
        setState(() {
          _isLoadingDriver = false;
        });
      }
    }
  }

  // Navigate to store detail for "Beli Lagi"
  void _navigateToStoreDetail() {
    // Navigate to store detail with the same store
    Navigator.pushNamed(
        context,
        '/Customers/StoreDetail',
        arguments: {
          'storeId': widget.order.store.id,
          'store': widget.order.store,
        }
    );
  }

  // Navigate to rating page
  void _navigateToRating() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RatingCustomerPage(
          order: widget.order,
        ),
      ),
    );

    // Refresh data after rating
    if (result != null) {
      _refreshOrderDetails();
    }
  }

  // Build animated card wrapper
  Widget _buildCard({required Widget child, required int index}) {
    return SlideTransition(
      position: _cardAnimations[index < _cardAnimations.length ? index : 0],
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: child,
      ),
    );
  }

  // Build order status section
  Widget _buildOrderStatusSection() {
    return _buildCard(
      index: 0,
      child: CustomerOrderStatusCard(
        orderData: {
          'id': widget.order.id,
          'order_status': widget.order.status.toString().split('.').last,
          'total': widget.order.total,
          'customer': {
            'name': 'Customer Name',
            'avatar': null,
            'phone': 'Customer Phone'
          },
          'estimatedDeliveryTime': widget.order.orderDate.add(Duration(minutes: 30)).toIso8601String(),
        },
        animation: _cardAnimations[0],
      ),
    );
  }

  // Build order date and info section
  Widget _buildOrderInfoSection() {
    final String formattedOrderDate = DateFormat('dd MMM yyyy, hh.mm a').format(widget.order.orderDate);

    return _buildCard(
      index: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: GlobalStyle.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.calendar_today,
                    color: GlobalStyle.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Informasi Pesanan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: GlobalStyle.fontColor,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  _buildInfoRow('Tanggal Pesanan', formattedOrderDate),
                  const SizedBox(height: 12),
                  _buildInfoRow('Kode Pesanan', '#${widget.order.code ?? widget.order.id}'),
                  const SizedBox(height: 12),
                  _buildInfoRow('Status', _getStatusText(widget.order.status)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build delivery address section
  Widget _buildDeliveryAddressSection() {
    return _buildCard(
      index: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: GlobalStyle.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.location_on,
                    color: GlobalStyle.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Alamat Pengiriman',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: GlobalStyle.fontColor,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.home_rounded,
                    color: GlobalStyle.primaryColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.order.deliveryAddress,
                      style: TextStyle(
                        color: GlobalStyle.fontColor,
                        fontFamily: GlobalStyle.fontFamily,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build driver information section
  Widget _buildDriverInfoSection() {
    final String driverName = _driver?.name ??
        widget.order.tracking?.driverName ??
        'Driver tidak tersedia';

    final String vehicleNumber = _driver?.vehicleNumber ??
        widget.order.tracking?.vehicleNumber ??
        '-';

    final String? driverImageUrl = _driver?.profileImageUrl ??
        widget.order.tracking?.driverImageUrl;

    final double driverRating = _driver?.rating ?? 4.8;

    return _buildCard(
      index: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.delivery_dining,
                    color: Colors.orange,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Informasi Driver',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: GlobalStyle.fontColor,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            widget.order.driverId != null
                ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.orange.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: driverImageUrl != null && driverImageUrl.isNotEmpty
                          ? ImageService.displayImage(
                        imageSource: driverImageUrl,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        placeholder: Center(
                          child: Icon(
                            Icons.person,
                            size: 30,
                            color: Colors.orange,
                          ),
                        ),
                        errorWidget: Center(
                          child: Icon(
                            Icons.person,
                            size: 30,
                            color: Colors.orange,
                          ),
                        ),
                      )
                          : Center(
                        child: Icon(
                          Icons.person,
                          size: 30,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          driverName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: GlobalStyle.fontColor,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.star, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              driverRating.toString(),
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.motorcycle, color: Colors.grey[700], size: 14),
                              const SizedBox(width: 4),
                              Text(
                                vehicleNumber,
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 12,
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
            )
                : Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey[600]),
                  const SizedBox(width: 12),
                  Text(
                    'Driver tidak ditugaskan',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontFamily: GlobalStyle.fontFamily,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build store and items section
  Widget _buildStoreItemsSection() {
    return _buildCard(
      index: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.store,
                    color: Colors.indigo,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.order.store.name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: GlobalStyle.fontColor,
                      fontFamily: GlobalStyle.fontFamily,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...widget.order.items.map((item) => _buildOrderItem(item)),
          ],
        ),
      ),
    );
  }

  // Build payment details section
  Widget _buildPaymentDetailsSection() {
    return _buildCard(
      index: 5,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: GlobalStyle.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.payment,
                    color: GlobalStyle.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Rincian Pembayaran',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: GlobalStyle.fontColor,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  _buildPaymentRow('Subtotal', widget.order.subtotal),
                  const SizedBox(height: 12),
                  _buildPaymentRow('Biaya Pengiriman', widget.order.serviceCharge),
                  const Divider(thickness: 1, height: 24),
                  _buildPaymentRow('Total', widget.order.total, isTotal: true),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (widget.order.paymentMethod != null)
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.blue[700],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pembayaran: ${widget.order.paymentMethod == PaymentMethod.cash ? "Tunai" : "Online"}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // Build rating display section (if rating exists)
  Widget _buildRatingDisplaySection() {
    if (!_hasGivenRating || (_orderRating == null && _driverRating == null)) {
      return Container();
    }

    return _buildCard(
      index: 6,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.star,
                    color: Colors.amber,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Ulasan Anda',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: GlobalStyle.fontColor,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Store rating
            if (_orderRating != null)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.indigo.withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.store, color: Colors.indigo, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Ulasan Toko',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo,
                          ),
                        ),
                        const Spacer(),
                        ...List.generate(5, (index) => Icon(
                          index < (_orderRating!['rating'] ?? 0) ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 16,
                        )),
                      ],
                    ),
                    if (_orderRating!['comment'] != null && _orderRating!['comment'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          _orderRating!['comment'],
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 14,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

            // Driver rating
            if (_driverRating != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.delivery_dining, color: Colors.orange, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Ulasan Driver',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                        const Spacer(),
                        ...List.generate(5, (index) => Icon(
                          index < (_driverRating!['rating'] ?? 0) ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 16,
                        )),
                      ],
                    ),
                    if (_driverRating!['comment'] != null && _driverRating!['comment'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          _driverRating!['comment'],
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 14,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Build action buttons section
  Widget _buildActionButtonsSection() {
    final bool isCompleted = widget.order.status == OrderStatus.completed ||
        widget.order.status == OrderStatus.delivered;
    final bool isCancelled = widget.order.status == OrderStatus.cancelled;

    return Container(
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
      child: Row(
        children: [
          // Beli Lagi button
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _navigateToStoreDetail,
              icon: Icon(
                isCancelled ? Icons.refresh : Icons.shopping_bag,
                color: Colors.white,
              ),
              label: Text(
                isCancelled ? 'Pesan Ulang' : 'Beli Lagi',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: GlobalStyle.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 2,
              ),
            ),
          ),

          // Rating button (only show for completed orders and if not rated yet)
          if (isCompleted && !_hasGivenRating) ...[
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _navigateToRating,
                icon: const Icon(
                  Icons.star,
                  color: Colors.white,
                ),
                label: const Text(
                  'Beri Nilai',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber[600],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Helper methods
  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontFamily: GlobalStyle.fontFamily,
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: GlobalStyle.fontColor,
              fontWeight: FontWeight.w500,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderItem(item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: GlobalStyle.borderColor.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ImageService.displayImage(
              imageSource: item.imageUrl,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              placeholder: Container(
                width: 60,
                height: 60,
                color: Colors.grey[200],
                child: const Icon(Icons.restaurant_menu, color: Colors.grey),
              ),
              errorWidget: Container(
                width: 60,
                height: 60,
                color: Colors.grey[300],
                child: const Icon(Icons.image_not_supported, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: GlobalStyle.fontColor,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
                const SizedBox(height: 4),
                Text(
                  'x${item.quantity}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            GlobalStyle.formatRupiah(item.price * item.quantity),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: GlobalStyle.primaryColor,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(String label, double amount, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? GlobalStyle.fontColor : Colors.grey[700],
            fontFamily: GlobalStyle.fontFamily,
          ),
        ),
        Text(
          GlobalStyle.formatRupiah(amount),
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? GlobalStyle.primaryColor : GlobalStyle.fontColor,
            fontFamily: GlobalStyle.fontFamily,
          ),
        ),
      ],
    );
  }

  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.completed:
        return 'Selesai';
      case OrderStatus.delivered:
        return 'Terkirim';
      case OrderStatus.cancelled:
        return 'Dibatalkan';
      case OrderStatus.pending:
        return 'Menunggu';
      case OrderStatus.approved:
        return 'Disetujui';
      case OrderStatus.preparing:
        return 'Diproses';
      case OrderStatus.on_delivery:
        return 'Diantar';
      case OrderStatus.driverAssigned:
        return 'Driver Ditugaskan';
      case OrderStatus.driverHeadingToStore:
        return 'Driver Menuju Toko';
      case OrderStatus.driverAtStore:
        return 'Driver Di Toko';
      case OrderStatus.driverHeadingToCustomer:
        return 'Driver Menuju Anda';
      case OrderStatus.driverArrived:
        return 'Driver Tiba';
      default:
        return 'Diproses';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF0F7FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text(
          'Detail Pesanan',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
            fontFamily: GlobalStyle.fontFamily,
          ),
        ),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(7.0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: GlobalStyle.primaryColor, width: 1.0),
            ),
            child: Icon(Icons.arrow_back_ios_new,
                color: GlobalStyle.primaryColor, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (widget.order.code != null && widget.order.code!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Text(
                  '#${widget.order.code}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: GlobalStyle.primaryColor,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildOrderStatusSection(),
                _buildOrderInfoSection(),
                _buildDeliveryAddressSection(),
                _buildDriverInfoSection(),
                _buildStoreItemsSection(),
                _buildPaymentDetailsSection(),
                _buildRatingDisplaySection(),
                const SizedBox(height: 80), // Space for action buttons
              ],
            ),
          ),

          // Action buttons at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildActionButtonsSection(),
          ),
        ],
      ),
    );
  }
}