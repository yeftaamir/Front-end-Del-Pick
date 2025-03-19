import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Models/menu_item.dart';
import 'package:del_pick/Views/Customers/location_access.dart';
import 'package:del_pick/Views/Customers/track_cust_order.dart';
import 'package:del_pick/Models/item_model.dart';
import 'package:del_pick/Models/store.dart';
import 'package:del_pick/Models/tracking.dart';
import 'package:del_pick/Models/order.dart';

class CartScreen extends StatefulWidget {
  static const String route = "/Customers/Cart";
  final List<MenuItem> cartItems;

  const CartScreen({Key? key, required this.cartItems}) : super(key: key);

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

  // Status timeline definition
  final List<Map<String, dynamic>> _statusTimeline = [
    {'status': OrderStatus.driverHeadingToStore, 'label': 'Di Proses', 'icon': Icons.store_outlined, 'color': Colors.blue},
    {'status': OrderStatus.driverAtStore, 'label': 'Di Ambil', 'icon': Icons.delivery_dining_outlined, 'color': Colors.orange},
    {'status': OrderStatus.driverHeadingToCustomer, 'label': 'Di Antar', 'icon': Icons.directions_bike_outlined, 'color': Colors.purple},
    {'status': OrderStatus.completed, 'label': 'Selesai', 'icon': Icons.check_circle_outline, 'color': Colors.green},
  ];

  late AnimationController _slideController;
  late AnimationController _driverCardController;
  late AnimationController _statusCardController;
  late Animation<Offset> _driverCardAnimation;
  late Animation<Offset> _statusCardAnimation;

  // Create multiple animation controllers for different sections
  late List<AnimationController> _cardControllers;
  late List<Animation<Offset>> _cardAnimations;

  @override
  void initState() {
    super.initState();
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

    // Start animations sequentially
    Future.delayed(const Duration(milliseconds: 100), () {
      for (var controller in _cardControllers) {
        controller.forward();
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
    super.dispose();
  }

  double get subtotal {
    return widget.cartItems.fold(0, (sum, item) => sum + (item.price * item.quantity));
  }

  double get total => subtotal + serviceCharge;

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

  // Get color based on order status
  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
      case OrderStatus.driverAssigned:
      case OrderStatus.driverHeadingToStore:
        return Colors.blue;
      case OrderStatus.driverAtStore:
        return Colors.orange;
      case OrderStatus.driverHeadingToCustomer:
      case OrderStatus.driverArrived:
        return Colors.purple;
      case OrderStatus.completed:
        return Colors.green;
      case OrderStatus.cancelled:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Get text representation of order status
  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return "Menunggu";
      case OrderStatus.driverAssigned:
      case OrderStatus.driverHeadingToStore:
        return "Di Proses";
      case OrderStatus.driverAtStore:
        return "Di Jemput";
      case OrderStatus.driverHeadingToCustomer:
      case OrderStatus.driverArrived:
        return "Di Antar";
      case OrderStatus.completed:
        return "Selesai";
      case OrderStatus.cancelled:
        return "Dibatalkan";
      default:
        return "Unknown";
    }
  }

  // Get current status index for timeline visualization
  int _getCurrentStatusIndex(OrderStatus currentStatus) {
    int currentStatusIndex = 0;

    for (int i = 0; i < _statusTimeline.length; i++) {
      if (_statusTimeline[i]['status'] == currentStatus) {
        currentStatusIndex = i;
        break;
      }
    }

    // Handle special cases
    if (currentStatus == OrderStatus.driverArrived) {
      currentStatusIndex = 2; // Same as driverHeadingToCustomer but complete
    } else if (currentStatus == OrderStatus.pending ||
        currentStatus == OrderStatus.driverAssigned) {
      currentStatusIndex = 0; // At the beginning
    }

    return currentStatusIndex;
  }

  Future<void> _showOrderSuccess() async {
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

    // Simulate status change to "Di Antar" after some time (for demo purposes)
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && _createdOrder != null) {
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
      }
    });
  }

  // Function to search for driver
  Future<void> _searchDriver() async {
    if (_deliveryAddress == null) {
      setState(() {
        _errorMessage = 'Please select a delivery address';
      });
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
                  'assets/animations/loading_animation.json', // Replace with your loading animation
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

  void _navigateToTrackOrder() {
    Navigator.pushNamed(
      context,
      TrackCustOrderScreen.route,
      arguments: _createdOrder,
    );
  }

  Widget _buildCard({required Widget child, required int index}) {
    return SlideTransition(
      position: _cardAnimations[index],
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
        child: child,
      ),
    );
  }

  Widget _buildDriverCard() {
    return SlideTransition(
      position: _driverCardAnimation,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.person, color: GlobalStyle.primaryColor),
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
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: GlobalStyle.lightColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.person,
                        color: GlobalStyle.primaryColor,
                        size: 30,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _driverName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: GlobalStyle.fontColor,
                          fontFamily: GlobalStyle.fontFamily,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _vehicleNumber,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontFamily: GlobalStyle.fontFamily,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    if (_createdOrder == null || _createdOrder!.tracking == null) return const SizedBox();

    // Get current status index
    final currentStatus = _createdOrder!.tracking!.status;
    final int currentStatusIndex = _getCurrentStatusIndex(currentStatus);

    return SlideTransition(
      position: _statusCardAnimation,
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Status Pesanan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: List.generate(_statusTimeline.length, (index) {
                final isActive = index <= currentStatusIndex;
                final isLast = index == _statusTimeline.length - 1;

                return Expanded(
                  child: Row(
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: isActive ? _statusTimeline[index]['color'] : Colors.grey[300],
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _statusTimeline[index]['icon'],
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _statusTimeline[index]['label'],
                            style: TextStyle(
                              fontSize: 10,
                              color: isActive ? _statusTimeline[index]['color'] : Colors.grey,
                              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            height: 2,
                            color: index < currentStatusIndex ? _statusTimeline[index]['color'] : Colors.grey[300],
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: _getStatusColor(currentStatus).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _createdOrder!.tracking!.statusMessage,
                style: TextStyle(
                  color: _getStatusColor(currentStatus),
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (_showTrackButton)
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

  // Build status timeline widget integrated into cart screen
  Widget _buildStatusTimeline(Tracking tracking) {
    // Get current status index
    int currentStatusIndex = _getCurrentStatusIndex(tracking.status);

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                'Status Pesanan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(_statusTimeline.length, (index) {
              final isActive = index <= currentStatusIndex;
              final isLast = index == _statusTimeline.length - 1;

              return Expanded(
                child: Row(
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: isActive
                                ? _statusTimeline[index]['color']
                                : Colors.grey[300],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _statusTimeline[index]['icon'],
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _statusTimeline[index]['label'],
                          style: TextStyle(
                            fontSize: 10,
                            color: isActive
                                ? _statusTimeline[index]['color']
                                : Colors.grey,
                            fontWeight: isActive ? FontWeight.bold : FontWeight
                                .normal,
                          ),
                        ),
                      ],
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: index < currentStatusIndex
                              ? _statusTimeline[index]['color']
                              : Colors.grey[300],
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: _getStatusColor(tracking.status).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              tracking.statusMessage,
              style: TextStyle(
                color: _getStatusColor(tracking.status),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (_showTrackButton ||
              tracking.status == OrderStatus.driverHeadingToCustomer ||
              tracking.status == OrderStatus.driverArrived)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _navigateToTrackOrder,
                  icon: const Icon(
                      Icons.location_on, color: Colors.white, size: 18),
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
    );
  }

  // Payment row helper
  Widget _buildPaymentRow(String label, double amount, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isTotal ? Colors.black : Colors.grey[600],
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            fontSize: isTotal ? 16 : 14,
          ),
        ),
        Text(
          'Rp ${amount.toStringAsFixed(0)}',
          style: TextStyle(
            color: isTotal ? GlobalStyle.primaryColor : Colors.black,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            fontSize: isTotal ? 16 : 14,
          ),
        ),
      ],
    );
  }

  Future<void> _simulateStatusUpdates() async {
    if (_createdOrder == null) return;

    // First status update: Driver assigned and heading to store
    setState(() {
      _createdOrder = _createdOrder!.copyWith(
        status: OrderStatus.driverAssigned,
        tracking: Tracking.sample().copyWith(
          status: OrderStatus.driverHeadingToStore,
          statusMessage: "Driver sedang menuju ke toko",
        ),
      );
    });

    // After 5 seconds, update to driver at store
    await Future.delayed(const Duration(seconds: 5));
    if (mounted && _createdOrder != null) {
      setState(() {
        _createdOrder = _createdOrder!.copyWith(
          status: OrderStatus.driverAtStore,
          tracking: _createdOrder!.tracking?.copyWith(
            status: OrderStatus.driverAtStore,
            statusMessage: "Driver sedang mengambil pesanan Anda",
          ),
        );
      });
    }

    // After 5 more seconds, update to driver heading to customer
    await Future.delayed(const Duration(seconds: 5));
    if (mounted && _createdOrder != null) {
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffD6E6F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Keranjang Pesanan',
          style: TextStyle(
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
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Delivery Address Section
              _buildCard(
                index: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.location_on, color: GlobalStyle
                              .primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            'Alamat Pengiriman',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              fontFamily: GlobalStyle.fontFamily,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _deliveryAddress == null
                          ? ElevatedButton.icon(
                        onPressed: _handleLocationAccess,
                        icon: const Icon(
                            Icons.location_on, color: Colors.white, size: 18),
                        label: const Text(
                          'Izinkan akses lokasi',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GlobalStyle.primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                        ),
                      )
                          : Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: GlobalStyle.borderColor),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _deliveryAddress!,
                          style: TextStyle(
                            fontFamily: GlobalStyle.fontFamily,
                            color: GlobalStyle.fontColor,
                          ),
                        ),
                      ),
                      if (_errorMessage != null)
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

              // Status card (visible only when order is created)
              if (_orderCreated) _buildStatusCard(),

              // Driver information card (visible only when driver is found)
              if (_driverFound) _buildDriverCard(),

              // Store Items Section
              _buildCard(
                index: 1,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.store, color: GlobalStyle.primaryColor),
                          const SizedBox(width: 8),
                          const Text(
                            'Warmindo Kayungyun',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ...widget.cartItems
                          .where((item) => item.quantity > 0)
                          .map((item) =>
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: GlobalStyle.borderColor),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.asset(
                                    item.imageUrl ??
                                        'assets/images/menu_item.jpg',
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment
                                        .start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Rp ${item.price.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          color: GlobalStyle.primaryColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: GlobalStyle.lightColor,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    'x${item.quantity}',
                                    style: TextStyle(
                                      color: GlobalStyle.primaryColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ))
                          .toList(),
                    ],
                  ),
                ),
              ),

              // Payment Details Section
              _buildCard(
                index: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          FaIcon(
                            FontAwesomeIcons.clipboardCheck,
                            color: GlobalStyle.primaryColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Rincian Pembayaran',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildPaymentRow('Subtotal untuk Produk', subtotal),
                      const SizedBox(height: 8),
                      _buildPaymentRow('Biaya Layanan', serviceCharge),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(),
                      ),
                      _buildPaymentRow(
                          'Total Pembayaran', total, isTotal: true),
                      const SizedBox(height: 12),
                      const Row(
                        children: [
                          Icon(Icons.payment, size: 16, color: Colors.grey),
                          SizedBox(width: 8),
                          Text(
                            'Metode Pembayaran: Tunai',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
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
          onPressed: _searchingDriver
              ? null
              : (_orderCreated && _showTrackButton
              ? _navigateToTrackOrder
              : (_orderCreated ? null : _searchDriver)),
          style: ElevatedButton.styleFrom(
            backgroundColor: GlobalStyle.primaryColor,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            disabledBackgroundColor: _orderCreated && !_showTrackButton ? Colors
                .grey[300] : Colors.grey,
          ),
          child: Text(
            _searchingDriver
                ? 'Mencari Driver...'
                : (_orderCreated && _showTrackButton
                ? 'Lacak Pesanan'
                : (_orderCreated ? 'Pesanan Diproses' : 'Buat Pesanan')),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _orderCreated && !_showTrackButton
                  ? Colors.grey[700]
                  : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}