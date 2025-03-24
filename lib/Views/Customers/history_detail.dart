import 'package:flutter/material.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:intl/intl.dart';
import 'package:del_pick/Models/order.dart';
import 'package:del_pick/Views/Component/order_status_card.dart';
import 'cart_screen.dart';
import 'rating_cust.dart';
import 'history_cust.dart';

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

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers for each card section
    _cardControllers = List.generate(
      5, // Number of card sections (added 1 for status card)
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
  }

  @override
  void dispose() {
    for (var controller in _cardControllers) {
      controller.dispose();
    }
    super.dispose();
  }

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
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String formattedOrderDate = DateFormat('dd MMM yyyy, hh.mm a').format(widget.order.orderDate);
    final driverName = widget.order.tracking?.driverName ?? 'Driver belum ditugaskan';
    final vehicleNumber = widget.order.tracking?.vehicleNumber ?? '-';

    // Check if rating has been given
    final bool hasRating = widget.order.hasGivenRating ?? false;

    return Scaffold(
      backgroundColor: const Color(0xffD6E6F2),
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(7.0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: GlobalStyle.primaryColor, width: 1.0),
            ),
            child: Icon(Icons.arrow_back_ios_new, color: GlobalStyle.primaryColor, size: 18),
          ),
          onPressed: () => Navigator.pushNamed(context, HistoryCustomer.route),
        ),
        title: Text(
          'Detail Pesanan',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
            fontFamily: GlobalStyle.fontFamily,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order Status Card
              if (widget.order.tracking != null)
                OrderStatusCard(
                  order: widget.order,
                  animation: _cardAnimations[0],
                ),

              // Order Date Section
              _buildCard(
                index: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_today, color: GlobalStyle.primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          'Tanggal Pesanan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: GlobalStyle.fontColor,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      formattedOrderDate,
                      style: TextStyle(
                        color: GlobalStyle.fontColor,
                        fontFamily: GlobalStyle.fontFamily,
                      ),
                    ),
                  ],
                ),
              ),

              // Delivery Address Section
              _buildCard(
                index: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on, color: GlobalStyle.primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          'Alamat Pengiriman',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: GlobalStyle.fontColor,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.order.deliveryAddress,
                      style: TextStyle(
                        color: GlobalStyle.fontColor,
                        fontFamily: GlobalStyle.fontFamily,
                      ),
                    ),
                  ],
                ),
              ),

              // Driver Information Section
              _buildCard(
                index: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person, color: GlobalStyle.primaryColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Informasi Driver',
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
                    const SizedBox(height: 12),
                    Text(
                      '$driverName\n$vehicleNumber',
                      style: TextStyle(
                        color: GlobalStyle.fontColor,
                        fontFamily: GlobalStyle.fontFamily,
                      ),
                    ),
                  ],
                ),
              ),

              // Store and Items Section
              _buildCard(
                index: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.store, color: GlobalStyle.primaryColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.order.store.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: GlobalStyle.fontColor,
                              fontFamily: GlobalStyle.fontFamily,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...widget.order.items.map((item) => _buildOrderItem(
                      item.name,
                      item.imageUrl,
                      item.quantity,
                      item.price.toInt(),
                    )),
                  ],
                ),
              ),

              // Payment Details Section
              _buildCard(
                index: 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.payment, color: GlobalStyle.primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          'Rincian Pembayaran',
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
                    _buildPaymentRow('Subtotal untuk Produk', widget.order.subtotal.toInt()),
                    _buildPaymentRow('Biaya Layanan', widget.order.serviceCharge.toInt()),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(thickness: 1),
                    ),
                    _buildTotalPaymentRow(widget.order.total.toInt()),
                  ],
                ),
              ),

              // Action Buttons
              const SizedBox(height: 16),
              hasRating
                  ? _buildBuyAgainButton()
                  : _buildActionButtons(driverName, vehicleNumber),
            ],
          ),
        ),
      ),
    );
  }

  // Buy Again button only
  Widget _buildBuyAgainButton() {
    return ElevatedButton(
      onPressed: () {
        Navigator.of(context).pushNamedAndRemoveUntil(
          CartScreen.route,
              (route) => false,
          arguments: const(child: CartScreen(cartItems: [])),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: GlobalStyle.primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      child: const Text('Beli Lagi'),
    );
  }

  // Both buttons (Buy Again + Rate)
  Widget _buildActionButtons(String driverName, String vehicleNumber) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(context).pushNamedAndRemoveUntil(
                CartScreen.route,
                    (route) => false,
                arguments: const (child: CartScreen(cartItems: [])),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: GlobalStyle.fontColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              side: BorderSide(color: GlobalStyle.borderColor),
            ),
            child: const Text('Beli Lagi'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RatingCustomerPage(
                    storeName: widget.order.store.name,
                    driverName: driverName,
                    vehicleNumber: vehicleNumber,
                    orderItems: widget.order.items.map((item) => OrderItem(
                      name: item.name,
                      formattedPrice: NumberFormat.currency(
                        locale: 'id',
                        symbol: 'Rp ',
                        decimalDigits: 0,
                      ).format(item.price),
                    )).toList(),
                  ),
                ),
              ).then((_) {
                // When returning from rating page, refresh the UI
                setState(() {
                  // Simulate that rating has been given (since we don't have actual state management here)
                  widget.order.hasRating = true;
                });
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: GlobalStyle.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: const Text('Beri Rating'),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderItem(String name, String imageUrl, int quantity, int price) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: GlobalStyle.borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              imageUrl,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 60,
                  height: 60,
                  color: Colors.grey[300],
                  child: const Icon(Icons.image_not_supported, color: Colors.grey),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: GlobalStyle.fontColor,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: GlobalStyle.lightColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'x$quantity',
                    style: TextStyle(
                      color: GlobalStyle.primaryColor,
                      fontFamily: GlobalStyle.fontFamily,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            NumberFormat.currency(
              locale: 'id',
              symbol: 'Rp ',
              decimalDigits: 0,
            ).format(price),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: GlobalStyle.fontColor,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(String label, int amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: GlobalStyle.fontColor,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          Text(
            NumberFormat.currency(
              locale: 'id',
              symbol: 'Rp ',
              decimalDigits: 0,
            ).format(amount),
            style: TextStyle(
              color: GlobalStyle.fontColor,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalPaymentRow(int amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Total Pembayaran',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: GlobalStyle.fontColor,
            fontFamily: GlobalStyle.fontFamily,
          ),
        ),
        Text(
          NumberFormat.currency(
            locale: 'id',
            symbol: 'Rp ',
            decimalDigits: 0,
          ).format(amount),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: GlobalStyle.primaryColor,
            fontFamily: GlobalStyle.fontFamily,
          ),
        ),
      ],
    );
  }
}

// This map is used to track ratings since we can't modify the Order class directly
final Map<String, bool> _orderRatings = {};

// Extension to add rating functionality to Order model
extension OrderExtension on Order {
  bool? get hasGivenRating => _orderRatings[id];

  set hasRating(bool? value) {
    _orderRatings[id] = value ?? false;
  }
}