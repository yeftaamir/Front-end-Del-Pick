import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:intl/intl.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Models/menu_item.dart';
import 'package:del_pick/Views/Customers/location_access.dart';
import 'package:del_pick/Views/Customers/track_cust_order.dart';
import 'package:del_pick/Views/Customers/rating_cust.dart';
import 'package:del_pick/Models/item_model.dart';
import 'package:del_pick/Models/store.dart';
import 'package:del_pick/Models/tracking.dart';
import 'package:del_pick/Models/order.dart';
import 'package:del_pick/Views/Component/order_status_card.dart';
import 'package:audioplayers/audioplayers.dart';

import '../Driver/track_order.dart';

class CartScreen extends StatefulWidget {
  static const String route = "/Customers/Cart";
  final List<MenuItem> cartItems;
  final Order? completedOrder; // Add completed order parameter

  const CartScreen({
    Key? key,
    required this.cartItems,
    this.completedOrder, // Optional completed order
  }) : super(key: key);

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> with TickerProviderStateMixin {
  final double serviceCharge = 30000;
  String? _deliveryAddress;
  String? _errorMessage;
  bool _orderCreated = false;
  bool _searchingDriver = false;
  bool _driverFound = false;
  String _driverName = "Budi Santoso";
  String _vehicleNumber = "B 1234 ABC";
  Order? _createdOrder;
  bool _showTrackButton = false;
  bool _hasGivenRating = false; // Track if user has given rating

  // Audio player instance
  final AudioPlayer _audioPlayer = AudioPlayer();

  late AnimationController _slideController;
  late AnimationController _driverCardController;
  late AnimationController _statusCardController;
  late Animation<Offset> _driverCardAnimation;
  late Animation<Offset> _statusCardAnimation;

  // Animation controllers for status animations
  late Map<OrderStatus, AnimationController> _statusAnimationControllers;

  // Create multiple animation controllers for different sections
  late List<AnimationController> _cardControllers;
  late List<Animation<Offset>> _cardAnimations;

  @override
  void initState() {
    super.initState();

    // Initialize with completed order if available
    if (widget.completedOrder != null) {
      _orderCreated = true;
      _driverFound = true;
      _createdOrder = widget.completedOrder;
      _deliveryAddress = widget.completedOrder!.deliveryAddress;

      if (widget.completedOrder!.tracking != null) {
        _driverName = widget.completedOrder!.tracking!.driverName ?? "Nama Driver";
        _vehicleNumber = widget.completedOrder!.tracking!.vehicleNumber ?? "Nomor Kendaraan";
      }
    }

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Initialize animation controllers for each card section
    _cardControllers = List.generate(
      4, // Number of card sections
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

    // Initialize driver card animation controller
    _driverCardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Initialize status card animation controller
    _statusCardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Create driver card animation
    _driverCardAnimation = Tween<Offset>(
      begin: const Offset(0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _driverCardController,
      curve: Curves.easeOutCubic,
    ));

    // Create status card animation
    _statusCardAnimation = Tween<Offset>(
      begin: const Offset(0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _statusCardController,
      curve: Curves.easeOutCubic,
    ));

    // Initialize status animation controllers
    _statusAnimationControllers = {
      OrderStatus.driverHeadingToStore: AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2000),
      ),
      OrderStatus.driverAtStore: AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2000),
      ),
      OrderStatus.driverHeadingToCustomer: AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2000),
      ),
      OrderStatus.completed: AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2000),
      ),
    };

    // Start animations sequentially
    Future.delayed(const Duration(milliseconds: 100), () {
      for (var controller in _cardControllers) {
        controller.forward();
      }

      // If we have a completed order, start these animations too
      if (widget.completedOrder != null) {
        _driverCardController.forward();
        _statusCardController.forward();
      }
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _driverCardController.dispose();
    _statusCardController.dispose();
    for (var controller in _cardControllers) {
      controller.dispose();
    }
    for (var controller in _statusAnimationControllers.values) {
      controller.dispose();
    }
    _audioPlayer.dispose();
    super.dispose();
  }

  double get subtotal {
    if (widget.completedOrder != null) {
      return widget.completedOrder!.subtotal;
    }
    return widget.cartItems.fold(0, (sum, item) => sum + (item.price * item.quantity));
  }

  double get total {
    if (widget.completedOrder != null) {
      return widget.completedOrder!.total;
    }
    return subtotal + serviceCharge;
  }

  // Play sound helper method
  Future<void> _playSound(String assetPath) async {
    await _audioPlayer.stop();
    await _audioPlayer.play(AssetSource(assetPath));
  }

  // Convert MenuItem list to Item list
  List<Item> _convertMenuItemsToItems() {
    return widget.cartItems.map((menuItem) => Item(
      id: menuItem.id.toString(),
      name: menuItem.name,
      description: menuItem.description ?? '',
      price: menuItem.price,
      quantity: menuItem.quantity,
      imageUrl: menuItem.imageUrl ?? 'assets/images/menu_item.jpg',
      isAvailable: true,
      status: 'available',
    )).toList();
  }

  // Create an Order object from cart data
  Order _createOrderFromCart() {
    final items = _convertMenuItemsToItems();
    final store = StoreModel(
      name: 'Warmindo Kayungyun',
      address: 'Jl. P.I. Del, Sitoluama, Laguboti',
      openHours: '08:00 - 22:00',
      rating: 4.8,
      reviewCount: 120,
    );

    return Order.fromCart(
      id: 'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      cartItems: items,
      store: store,
      deliveryAddress: _deliveryAddress ?? 'No address specified',
      serviceCharge: serviceCharge,
    );
  }

  Future<void> _handleLocationAccess() async {
    final result = await Navigator.pushNamed(
        context,
        LocationAccessScreen.route
    );

    if (result is Map<String, dynamic>) {
      setState(() {
        _deliveryAddress = result['address'];
        _errorMessage = null;
      });
    }
  }

  // Show no address dialog with animation and sound
  Future<void> _showNoAddressDialog() async {
    // Play error sound
    await _playSound('audio/wrong.mp3');

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/animations/caution.json',
                  height: 200,
                  width: 200,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 10),
                const Text(
                  "Mohon tentukan alamat pengiriman untuk melanjutkan pesanan",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlobalStyle.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _handleLocationAccess();
                  },
                  child: const Text(
                    "Tentukan Alamat",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Show order success dialog with animation and sound
  Future<void> _showOrderSuccess() async {
    // Play success sound
    await _playSound('audio/kring.mp3');

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
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
                  "Pesanan anda berhasil dibuat",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlobalStyle.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "OK",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    setState(() {
      _orderCreated = true;
    });

    // Start status card animation
    _statusCardController.forward();

    // Start the first status animation
    _statusAnimationControllers[OrderStatus.driverHeadingToStore]?.forward();

    // Simulate status change to "Di Antar" after some time (for demo purposes)
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && _createdOrder != null) {
        // Play status change sound
        _playSound('audio/alert.wav');

        setState(() {
          _createdOrder = _createdOrder!.copyWith(
            status: OrderStatus.driverHeadingToCustomer,
            tracking: _createdOrder!.tracking?.copyWith(
              status: OrderStatus.driverHeadingToCustomer,
              statusMessage: "Driver sedang menuju ke lokasi Anda",
            ),
          );
          _showTrackButton = true;
        });

        // Reset previous animation and start new one
        _statusAnimationControllers[OrderStatus.driverHeadingToStore]?.reset();
        _statusAnimationControllers[OrderStatus.driverHeadingToCustomer]?.forward();
      }
    });
  }

  // Search for driver with animation
  Future<void> _searchDriver() async {
    if (_deliveryAddress == null) {
      await _showNoAddressDialog();
      return;
    }

    // Create order
    _createdOrder = _createOrderFromCart();

    setState(() {
      _searchingDriver = true;
    });

    // Show driver search dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/animations/loading_animation.json',
                  width: 150,
                  height: 150,
                  repeat: true,
                ),
                const SizedBox(height: 20),
                const Text(
                  "Mencari driver...",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Mohon tunggu sebentar",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    // Simulate finding a driver after 3 seconds
    await Future.delayed(const Duration(seconds: 3));

    // Update order status when driver is assigned
    if (_createdOrder != null) {
      _createdOrder = _createdOrder!.copyWith(
        status: OrderStatus.driverAssigned,
        tracking: Tracking.sample().copyWith(
          status: OrderStatus.driverHeadingToStore,
          statusMessage: "Driver sedang menuju ke toko",
        ),
      );
    }

    // Close the dialog
    Navigator.of(context).pop();

    setState(() {
      _searchingDriver = false;
      _driverFound = true;
      _orderCreated = true;
    });

    // Start driver card animation
    _driverCardController.forward();

    // Show order success dialog
    await _showOrderSuccess();
  }

  // Handle "Beri Rating" button press
  void _handleRatingPress() async {
    if (_createdOrder == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RatingCustomerPage(
          storeName: _createdOrder!.store.name,
          driverName: _driverName,
          vehicleNumber: _vehicleNumber,
          orderItems: _createdOrder!.items.map((item) => OrderItem(
            name: item.name,
            formattedPrice: NumberFormat.currency(
              locale: 'id',
              symbol: 'Rp ',
              decimalDigits: 0,
            ).format(item.price),
          )).toList(),
        ),
      ),
    );

    // If the user submitted a rating (result could be a boolean or any value indicating success)
    if (result != null) {
      setState(() {
        _hasGivenRating = true;
      });
    }
  }

  // Handle "Beli Lagi" button press
  void _handleBuyAgain() {
    // Instead of clearing the cart and showing an empty screen,
    // we'll navigate back to the home screen or menu screen
    // while preserving the completed order in history
    Navigator.pop(context);
  }

  void _viewOrderHistory() {
    // Navigate to order history screen
    // This would typically be implemented to show all past orders
    // For now, we'll just show a message dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Riwayat Pesanan'),
        content: const Text('Fitur riwayat pesanan akan segera tersedia'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: GlobalStyle.primaryColor)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine if order is completed or cancelled (for history display)
    bool isCompletedOrder = widget.completedOrder != null &&
        (widget.completedOrder!.status == OrderStatus.completed ||
            widget.completedOrder!.status == OrderStatus.cancelled);

    bool isCancelledOrder = widget.completedOrder != null &&
        widget.completedOrder!.status == OrderStatus.cancelled;

    // Format the order date if available
    String formattedOrderDate = '';
    if (widget.completedOrder != null) {
      formattedOrderDate = DateFormat('dd MMM yyyy, hh.mm a').format(widget.completedOrder!.orderDate);
    }

    return Scaffold(
      backgroundColor: const Color(0xffD6E6F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text(
          isCompletedOrder ?
          isCancelledOrder ? 'Riwayat Pesanan Dibatalkan' : 'Riwayat Pesanan'
              : 'Keranjang Pesanan',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(7.0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: GlobalStyle.primaryColor, width: 1.0),
            ),
            child: Icon(
                Icons.arrow_back_ios_new, color: GlobalStyle.primaryColor,
                size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        // Add history button if we're looking at a cart
        actions: [
          if (!isCompletedOrder)
            IconButton(
              icon: Icon(Icons.history, color: GlobalStyle.primaryColor),
              onPressed: _viewOrderHistory,
            ),
        ],
      ),
      // Updated body condition to properly handle empty cart vs completed/cancelled orders
      body: widget.cartItems.isEmpty && widget.completedOrder == null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              "Keranjang Kosong",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Tambahkan beberapa item untuk mulai memesan",
              style: TextStyle(
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      )
          : Stack(
          children: [
      ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Order status card for active orders - MOVED TO TOP
        if (_orderCreated && !isCompletedOrder && _createdOrder != null)
          OrderStatusCard(
            order: _createdOrder!,
            animation: _statusCardAnimation,
          ),

        // Driver information section - MOVED BELOW STATUS CARD
        if (isCompletedOrder || _driverFound) _buildDriverCard(),

        // Show order date for completed orders
        if (isCompletedOrder)
          _buildCard(
            index: 0,
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

        // Show order items for either active cart or completed order
        _buildCard(
          index: 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.restaurant_menu,
                        color: GlobalStyle.primaryColor),
                    const SizedBox(width: 8),
                    Row(
                      children: [
                        Text(
                          isCompletedOrder
                              ? widget.completedOrder!.store.name
                              : 'Pesanan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: GlobalStyle.fontColor,
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                        if (isCompletedOrder &&
                            widget.completedOrder!.status ==
                                OrderStatus.cancelled)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red[100],
                              borderRadius:
                              BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Dibatalkan',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red[800],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        if (isCompletedOrder &&
                            widget.completedOrder!.status ==
                                OrderStatus.completed)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green[100],
                              borderRadius:
                              BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Selesai',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green[800],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isCompletedOrder)
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: widget.completedOrder!.items.length,
                  separatorBuilder: (context, index) =>
                  const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item =
                    widget.completedOrder!.items[index];
                    return _buildOrderItemRow(item);
                  },
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: widget.cartItems.length,
                  separatorBuilder: (context, index) =>
                  const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = widget.cartItems[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      leading: SizedBox(
                        width: 60,
                        height: 60,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            item.imageUrl ??
                                'https://via.placeholder.com/150',
                            fit: BoxFit.cover,
                            errorBuilder:
                                (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[300],
                                child: const Icon(
                                    Icons.image_not_supported,
                                    color: Colors.white70),
                              );
                            },
                          ),
                        ),
                      ),
                      title: Text(
                        item.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: GlobalStyle.fontColor,
                          fontFamily: GlobalStyle.fontFamily,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(
                            GlobalStyle.formatRupiah(item.price),
                            style: const TextStyle(
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            'Quantity: ${item.quantity}',
                            style: const TextStyle(
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      trailing: Text(
                        GlobalStyle.formatRupiah(
                            item.price * item.quantity),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: GlobalStyle.primaryColor,
                          fontFamily: GlobalStyle.fontFamily,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),

        // Delivery address section
        _buildCard(
          index: 1,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on,
                        color: GlobalStyle.primaryColor),
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
                if (isCompletedOrder || _orderCreated)
                  Text(
                    _deliveryAddress ??
                        widget.completedOrder?.deliveryAddress ??
                        'Alamat tidak tersedia',
                    style: TextStyle(
                      color: GlobalStyle.fontColor,
                      fontFamily: GlobalStyle.fontFamily,
                    ),
                  )
                else
                  GestureDetector(
                    onTap: _handleLocationAccess,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _errorMessage != null
                              ? Colors.red
                              : Colors.grey[300]!,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.my_location,
                            color: _deliveryAddress != null
                                ? GlobalStyle.primaryColor
                                : Colors.grey,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _deliveryAddress ??
                                  'Pilih lokasi pengiriman',
                              style: TextStyle(
                                color: _deliveryAddress != null
                                    ? GlobalStyle.fontColor
                                    : Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Colors.grey[400],
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_errorMessage != null &&
                    !isCompletedOrder &&
                    !_orderCreated)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Payment details section
        _buildCard(
          index: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.payment,
                        color: GlobalStyle.primaryColor),
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
                const SizedBox(height: 12),
                _buildPaymentRow('Subtotal', subtotal),
                const SizedBox(height: 8),
                _buildPaymentRow('Biaya Layanan', serviceCharge),
                const Divider(thickness: 1, height: 24),
                _buildPaymentRow('Total', total, isTotal: true),
              ],
            ),
          ),
        ),

        // Action buttons for completed orders
        // Action buttons for completed orders
        if (isCompletedOrder)
          _buildCard(
            index: 3,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  if (!_hasGivenRating &&
                      widget.completedOrder!.status == OrderStatus.completed)
                    ElevatedButton(
                      onPressed: _handleRatingPress,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GlobalStyle.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 24),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text(
                        "Beri Rating",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (widget.completedOrder!.status == OrderStatus.cancelled)
                    Text(
                      "Pesanan ini telah dibatalkan",
                      style: TextStyle(
                        color: Colors.red[800],
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  OutlinedButton(
                    onPressed: _handleBuyAgain,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: GlobalStyle.primaryColor,
                      side: BorderSide(
                          color: GlobalStyle.primaryColor, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 24),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: widget.completedOrder!.status == OrderStatus.cancelled
                        ? const Text(
                      "Pesan Ulang",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                        : const Text(
                      "Beli Lagi",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Add extra space at the bottom if there's a persistent order button
        if (!isCompletedOrder && !_orderCreated)
          const SizedBox(height: 80),
      ],
    ),
                // Persistent order button for new orders
                if (!isCompletedOrder && !_orderCreated)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
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
                      child: ElevatedButton(
                        onPressed: _searchingDriver ? null : _searchDriver,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GlobalStyle.primaryColor,
                          disabledBackgroundColor: Colors.grey,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: _searchingDriver
                            ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Mencari Driver...',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        )
                            : Text(
                          'Buat Pesanan - ${GlobalStyle.formatRupiah(total)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  // Helper methods
  Widget _buildCard({required int index, required Widget child}) {
    return SlideTransition(
      position: _cardAnimations[index < _cardAnimations.length ? index : 0],
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white, // Changed background to white
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: child,
      ),
    );
  }

// In the _CartScreenState class, update the _buildDriverCard() method
  Widget _buildDriverCard() {
    return SlideTransition(
      position: _driverCardAnimation,
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.delivery_dining, color: GlobalStyle.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Informasi Driver',
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
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: ClipOval(
                    child: Center(
                      child: Icon(
                        Icons.person,
                        size: 30,
                        color: Colors.grey[400],
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
                        _driverName,
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
                          Icon(Icons.motorcycle, color: Colors.grey[600], size: 16),
                          const SizedBox(width: 4),
                          Text(
                            _vehicleNumber,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '4.8',
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.call, color: Colors.white),
                    label: const Text(
                      'Hubungi',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GlobalStyle.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      // Implementasi fungsi panggilan
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.message, color: Colors.white),
                    label: const Text(
                      'Pesan',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[600],
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      // Implementasi fungsi pesan
                    },
                  ),
                ),
              ],
            ),

            // Add track order button when status is "Di Antar"
            if (_showTrackButton && _createdOrder?.status == OrderStatus.driverHeadingToCustomer)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _navigateToTrackOrder,
                    icon: const Icon(Icons.location_on, color: Colors.white, size: 18),
                    label: const Text(
                      'Lacak Pesanan',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GlobalStyle.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
          ],
        ),
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
            color: GlobalStyle.fontColor,
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

  Widget _buildOrderItemRow(Item item) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      leading: SizedBox(
        width: 60,
        height: 60,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            item.imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[300],
                child: const Icon(Icons.image_not_supported, color: Colors.white70),
              );
            },
          ),
        ),
      ),
      title: Text(
        item.name,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: GlobalStyle.fontColor,
          fontFamily: GlobalStyle.fontFamily,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            GlobalStyle.formatRupiah(item.price),
            style: const TextStyle(
              color: Colors.grey,
            ),
          ),
          Text(
            'Quantity: ${item.quantity}',
            style: const TextStyle(
              color: Colors.grey,
            ),
          ),
        ],
      ),
      trailing: Text(
        GlobalStyle.formatRupiah(item.price * item.quantity),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: GlobalStyle.primaryColor,
          fontFamily: GlobalStyle.fontFamily,
        ),
      ),
    );
  }

  void _navigateToTrackOrder() {
    if (_createdOrder == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TrackCustOrderScreen(
          order: _createdOrder!,
        ),
      ),
    );
  }
}