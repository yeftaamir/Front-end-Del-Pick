import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:lottie/lottie.dart';
import 'package:del_pick/Models/order.dart';
import 'package:del_pick/Models/menu_item.dart';
import 'package:del_pick/Models/store.dart';
import 'package:del_pick/Models/tracking.dart';
import 'package:del_pick/Models/user.dart';
import 'package:del_pick/Models/driver.dart';
import 'package:del_pick/Models/order_item.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:audioplayers/audioplayers.dart';
import 'package:del_pick/Services/order_service.dart';
import 'package:del_pick/Services/store_service.dart';
import 'package:del_pick/Services/driver_service.dart';
import 'package:del_pick/Services/auth_service.dart';
import 'package:del_pick/Services/image_service.dart';
import 'dart:async';
import 'dart:math';
import 'package:intl/intl.dart';

import '../../Models/order_enum.dart';
import '../Component/store_order_status.dart';

class HistoryStoreDetailPage extends StatefulWidget {
  static const String route = '/Store/HistoryStoreDetail';

  // Accept either orderId or full order data
  final String? orderId;
  final Map<String, dynamic>? orderDetail;

  const HistoryStoreDetailPage({
    Key? key,
    this.orderId,
    this.orderDetail,
  }) : assert(orderId != null || orderDetail != null),
        super(key: key);

  @override
  _HistoryStoreDetailPageState createState() => _HistoryStoreDetailPageState();
}

class _HistoryStoreDetailPageState extends State<HistoryStoreDetailPage>
    with TickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();

  // State variables
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  Map<String, dynamic> _orderData = {};
  Order? _orderObject;
  User? _customer;
  Driver? _driver;
  Store? _store;
  bool _isRefreshing = false;
  bool _isUpdatingStatus = false;

  // For tracking changes that should be reflected in UI
  bool _hasStatusChanged = false;

  // Coordinates for distance calculation
  double? _customerLatitude;
  double? _customerLongitude;
  double? _storeLatitude;
  double? _storeLongitude;

  // Distance and delivery fee
  double _distance = 0.0;
  double _calculatedDeliveryFee = 0.0;

  // Animation controllers
  late List<AnimationController> _cardControllers;
  late List<Animation<Offset>> _cardAnimations;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers for card sections
    _cardControllers = List.generate(
      6, // For all possible cards we might show
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

    // If we have full order data, initialize directly, otherwise load from API
    if (widget.orderDetail != null) {
      _orderData = Map<String, dynamic>.from(widget.orderDetail!);
      _processOrderData();
    } else if (widget.orderId != null) {
      _loadOrderData();
    } else {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'No order ID or details provided';
      });
    }
  }

  // Calculate Haversine distance between two coordinates
  double calculateHaversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Radius of the Earth in kilometers

    // Convert degrees to radians
    double toRadians(double degrees) {
      return degrees * (pi / 180);
    }

    // Calculate differences in coordinates
    double dLat = toRadians(lat2 - lat1);
    double dLon = toRadians(lon2 - lon1);

    // Haversine formula
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(toRadians(lat1)) * cos(toRadians(lat2)) *
            sin(dLon / 2) * sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    double distance = earthRadius * c; // Distance in kilometers

    return distance;
  }

  // Calculate delivery fee based on distance
  double calculateDeliveryFee(double distance) {
    // Calculate fee by multiplying distance by 2500
    double fee = distance * 2500;

    // Round up to the nearest 1000 for easier cash payment
    return (fee / 1000).ceil() * 1000;
  }

  // Load order data using getOrderById for specific order details
  Future<void> _loadOrderData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // Use getOrderById to get complete order details with all relationships
      final orderData = await OrderService.getOrderById(widget.orderId!);

      if (orderData.isNotEmpty) {
        setState(() {
          _orderData = Map<String, dynamic>.from(orderData);
          _isLoading = false;
        });

        // Process the order data
        _processOrderData();
      } else {
        throw Exception('Order not found or empty response');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Failed to load order: $e';
      });
    }
  }

  // Refresh order data
  Future<void> _refreshOrderData() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      await _loadOrderData();
      setState(() {
        _hasStatusChanged = true;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to refresh order: $e')),
      );
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  // Process the order data to set up needed objects
  void _processOrderData() {
    try {
      // Check if the order data has all the necessary keys
      if (_orderData.isEmpty) {
        throw Exception("Order data is empty");
      }

      // Debug logging
      print('Processing order data: ${_orderData.keys.join(', ')}');

      // Create Order object from raw data using the updated model
      if (_orderData['id'] != null) {
        try {
          _orderObject = Order.fromJson(_orderData);
          print('Order object created successfully: ${_orderObject?.id}');
        } catch (e) {
          print('Error creating Order object: $e');
          // Continue with partial data
        }
      }

      // Extract nested objects using the updated models
      _extractCustomerInfo();
      _extractDriverInfo();
      _extractStoreInfo();

      // Extract coordinate data if available
      _extractCoordinates();

      // Calculate distance if coordinates are available
      _calculateDistanceAndFee();

      // Start animations
      Future.delayed(const Duration(milliseconds: 100), () {
        for (var controller in _cardControllers) {
          controller.forward();
        }
      });

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error in _processOrderData: $e');
      setState(() {
        _hasError = true;
        _errorMessage = 'Error processing order data: $e';
        _isLoading = false;
      });
    }
  }

  // Extract coordinates from order data
  void _extractCoordinates() {
    // Store coordinates - from store object
    if (_store != null) {
      _storeLatitude = _store!.latitude;
      _storeLongitude = _store!.longitude;
    } else if (_orderData['store'] != null) {
      _storeLatitude = (_orderData['store']['latitude'] as num?)?.toDouble();
      _storeLongitude = (_orderData['store']['longitude'] as num?)?.toDouble();
    }

    // Customer coordinates - from delivery address or customer location
    // Note: This might need adjustment based on how customer location is stored
    _customerLatitude = (_orderData['delivery_latitude'] as num?)?.toDouble() ??
        (_orderData['customer']?['latitude'] as num?)?.toDouble();
    _customerLongitude = (_orderData['delivery_longitude'] as num?)?.toDouble() ??
        (_orderData['customer']?['longitude'] as num?)?.toDouble();

    // Debug coordinates
    print('Store coordinates: $_storeLatitude, $_storeLongitude');
    print('Customer coordinates: $_customerLatitude, $_customerLongitude');
  }

  // Calculate distance and delivery fee
  void _calculateDistanceAndFee() {
    if (_storeLatitude != null && _storeLongitude != null &&
        _customerLatitude != null && _customerLongitude != null) {
      // Calculate distance using Haversine formula
      _distance = calculateHaversineDistance(
          _storeLatitude!, _storeLongitude!,
          _customerLatitude!, _customerLongitude!
      );

      // Calculate delivery fee based on distance
      _calculatedDeliveryFee = calculateDeliveryFee(_distance);

      print('Calculated distance: $_distance km');
      print('Calculated delivery fee: $_calculatedDeliveryFee');
    } else {
      print('Cannot calculate distance: Coordinates missing');
      // Use the existing delivery fee from order data if available
      _calculatedDeliveryFee = _orderObject?.deliveryFee ??
          (_orderData['delivery_fee'] as num?)?.toDouble() ?? 0.0;
    }
  }

  // Extract customer information using the User model
  void _extractCustomerInfo() {
    try {
      if (_orderObject?.customer != null) {
        _customer = _orderObject!.customer;
        print('Customer extracted from Order object: ${_customer?.name}');
      } else if (_orderData['customer'] != null) {
        _customer = User.fromJson(_orderData['customer']);
        print('Customer extracted from embedded data: ${_customer?.name}');
      }
    } catch (e) {
      print('Error extracting customer info: $e');
    }
  }

  // Extract driver information using the Driver model
  void _extractDriverInfo() {
    try {
      if (_orderObject?.driver != null) {
        _driver = _orderObject!.driver;
        print('Driver extracted from Order object: ${_driver?.name}');
      } else if (_orderData['driver'] != null) {
        _driver = Driver.fromJson(_orderData['driver']);
        print('Driver extracted from embedded data: ${_driver?.name}');
      }
    } catch (e) {
      print('Error extracting driver info: $e');
    }
  }

  // Extract store information using the Store model
  void _extractStoreInfo() {
    try {
      if (_orderObject?.store != null) {
        _store = _orderObject!.store;
        print('Store extracted from Order object: ${_store?.name}');
      } else if (_orderData['store'] != null) {
        _store = Store.fromJson(_orderData['store']);
        print('Store extracted from embedded data: ${_store?.name}');
      }
    } catch (e) {
      print('Error extracting store info: $e');
    }
  }

  @override
  void dispose() {
    for (var controller in _cardControllers) {
      controller.dispose();
    }
    _audioPlayer.dispose();
    super.dispose();
  }

  // Update order status with API call using the updated service
  Future<void> _updateOrderStatus(String status) async {
    if (_isUpdatingStatus) return;

    try {
      // Show loading indicator
      setState(() {
        _isUpdatingStatus = true;
        _isLoading = true;
      });

      // Based on the status, we determine what action to take
      String action = '';
      switch (status) {
        case 'confirmed':
          action = 'approve';
          break;
        case 'cancelled':
          action = 'reject';
          break;
        default:
          action = status; // Use status directly as action if not matched
      }

      print('Updating order status to: $status (action: $action)');

      final orderId = _orderObject?.id?.toString() ?? _orderData['id']?.toString() ?? '';
      await OrderService.processOrderByStore(orderId, action);

      // Update local state to reflect change
      setState(() {
        _orderData['order_status'] = status;
        _hasStatusChanged = true;

        // If we have an Order object, update it too
        if (_orderObject != null) {
          _orderObject = _orderObject!.copyWith(
              orderStatus: OrderStatus.fromString(status)
          );
        }
      });

      // Refresh data to get the latest state from server
      await _refreshOrderData();

      // Play sound based on status
      if (status == 'confirmed') {
        _playSound('audio/found.wav');
      } else if (status == 'cancelled') {
        _playSound('audio/alert.wav');
      }

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status pesanan berhasil diperbarui')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update order status: $e')),
      );
    } finally {
      setState(() {
        _isUpdatingStatus = false;
        _isLoading = false;
      });
    }
  }

  // Supporting function to play sound effects
  Future<void> _playSound(String assetPath) async {
    try {
      await _audioPlayer.play(AssetSource(assetPath));
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }
  }

  // Get current order status from data using the updated enum
  OrderStatus _getOrderStatus() {
    // First check if we have an Order object with a status
    if (_orderObject != null) {
      return _orderObject!.orderStatus;
    }

    // Then try to get status from order data
    String? status = _orderData['order_status'] as String?;
    if (status == null) {
      return OrderStatus.pending; // Default if we can't find status
    }

    // Convert string status to OrderStatus enum using the updated enum
    return OrderStatus.fromString(status);
  }

  void _showCancelConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cancel_outlined,
                  color: Colors.red,
                  size: 60,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Batalkan Pesanan?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Apakah Anda yakin ingin membatalkan pesanan ini?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: const Text(
                        'Tidak',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _updateOrderStatus('cancelled');
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Ya, Batalkan',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showApproveConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: GlobalStyle.primaryColor,
                  size: 60,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Terima Pesanan?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Apakah Anda yakin ingin menerima pesanan ini?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: const Text(
                        'Tidak',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _updateOrderStatus('confirmed');
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        backgroundColor: GlobalStyle.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Ya, Terima',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCard({required Widget child, required int index}) {
    // Ensure index is within bounds
    final animationIndex = index < _cardAnimations.length ? index : 0;

    return SlideTransition(
      position: _cardAnimations[animationIndex],
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

  // Updated to use the new OrderStatusCard implementation
  Widget _buildOrderStatusCard() {
    return _buildCard(
      index: 0,
      child: StoreOrderStatusCard(
        orderData: {
          'id': _orderObject?.id?.toString() ?? _orderData['id']?.toString() ?? '',
          'order_status': _getOrderStatus().toString().split('.').last,
          'total_amount': _orderObject?.totalAmount ?? (_orderData['total_amount'] as num?)?.toDouble() ?? 0,
          'customer': {
            'name': _customer?.name ?? 'Customer',
            'avatar': _customer?.avatar,
            'phone': _customer?.phone ?? '',
          },
          'items': _getOrderItems().map((item) => {
            'id': item.id,
            'name': item.name,
            'price': item.price,
            'quantity': item.quantity,
          }).toList(),
        },
        animation: _cardAnimations[0],
      ),
    );
  }

  Widget _buildDriverInfoCard() {
    // Check if driver info is available
    if (_driver == null) {
      return const SizedBox.shrink();
    }

    // Get the current order status
    final currentStatus = _getOrderStatus();

    // Only show driver info for certain statuses
    if (![
      OrderStatus.ready_for_pickup,
      OrderStatus.on_delivery,
      OrderStatus.delivered,
    ].contains(currentStatus)) {
      return const SizedBox.shrink();
    }

    return _buildCard(
      index: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.drive_eta, color: GlobalStyle.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Informasi Driver',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Show driver image if available, otherwise a placeholder
                if (_driver!.profileImageUrl != null && _driver!.profileImageUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: ImageService.displayImage(
                      imageSource: _driver!.profileImageUrl!,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      placeholder: Container(
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
                    ),
                  )
                else
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Driver: ${_driver!.name}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: GlobalStyle.fontColor,
                          fontFamily: GlobalStyle.fontFamily,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'No. Kendaraan: ${_driver!.vehiclePlate}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontFamily: GlobalStyle.fontFamily,
                        ),
                      ),
                      if (_driver!.phoneNumber.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Telepon: ${_driver!.phoneNumber}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontFamily: GlobalStyle.fontFamily,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chat),
                  onPressed: () => _openWhatsApp(
                    _driver!.phoneNumber,
                    isDriver: true,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.blue.shade100,
                    foregroundColor: Colors.blue,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.call),
                  onPressed: () => _callPhoneNumber(_driver!.phoneNumber),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.green.shade100,
                    foregroundColor: Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerInfoCard() {
    if (_customer == null) {
      return const SizedBox.shrink();
    }

    return _buildCard(
      index: 2,
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
                  'Informasi Customer',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: GlobalStyle.fontFamily,
                    color: GlobalStyle.fontColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                // Show customer image if available, otherwise a placeholder
                if (_customer!.avatar != null && _customer!.avatar!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: ImageService.displayImage(
                      imageSource: _customer!.avatar!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      placeholder: Container(
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
                    ),
                  )
                else
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
                        _customer!.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: GlobalStyle.fontColor,
                          fontFamily: GlobalStyle.fontFamily,
                        ),
                      ),
                      if (_customer!.phone != null && _customer!.phone!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(Icons.phone, color: Colors.grey[600], size: 16),
                              const SizedBox(width: 4),
                              Text(
                                _customer!.phone!,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on,
                              color: Colors.grey[600], size: 16),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _orderData['delivery_address']?.toString() ?? 'Alamat tidak tersedia',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
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
                      _callPhoneNumber(_customer!.phone);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.message, color: Colors.white),
                    label: const Text(
                      'WhatsApp',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      _openWhatsApp(
                        _customer!.phone,
                        isDriver: false,
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreInfoCard() {
    if (_store == null) {
      return const SizedBox.shrink();
    }

    return _buildCard(
      index: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.store, color: GlobalStyle.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Informasi Toko',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: GlobalStyle.fontFamily,
                    color: GlobalStyle.fontColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                // Show store image if available, otherwise a placeholder
                if (_store!.imageUrl != null && _store!.imageUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: ImageService.displayImage(
                      imageSource: _store!.imageUrl!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      placeholder: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: ClipOval(
                          child: Center(
                            child: Icon(
                              Icons.store,
                              size: 30,
                              color: Colors.grey[400],
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                else
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
                          Icons.store,
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
                        _store!.name,
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
                          Icon(Icons.location_on,
                              color: Colors.grey[600], size: 16),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _store!.address,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
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
                            _store!.rating?.toStringAsFixed(1) ?? '0.0',
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
          ],
        ),
      ),
    );
  }

  // Universal method to call a phone number
  Future<void> _callPhoneNumber(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nomor telepon tidak tersedia')),
      );
      return;
    }

    // Format the phone number
    phoneNumber = _formatPhoneNumber(phoneNumber);
    String url = 'tel:$phoneNumber';

    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tidak dapat melakukan panggilan: $e')),
      );
    }
  }

  Future<void> _openWhatsApp(String? phoneNumber, {bool isDriver = false, bool isStore = false}) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nomor telepon tidak tersedia')),
      );
      return;
    }

    // Format phone number for WhatsApp
    String formattedNumber = _formatPhoneNumber(phoneNumber);

    // Remove '+' for WhatsApp URL
    if (formattedNumber.startsWith('+')) {
      formattedNumber = formattedNumber.substring(1);
    }

    // Create appropriate message based on who we're messaging
    String orderNumber = _orderObject?.id?.toString() ??
        _orderData['id']?.toString() ?? '';

    if (orderNumber.length > 8) {
      orderNumber = orderNumber.substring(0, 8);
    }

    String message = '';
    if (isDriver) {
      message = 'Halo, saya dari toko mengenai pesanan #$orderNumber yang akan diambil.';
    } else if (isStore) {
      message = 'Halo, saya ingin bertanya mengenai toko dan pesanan #$orderNumber.';
    } else {
      message = 'Halo, saya dari toko mengenai pesanan #$orderNumber Anda.';
    }

    String url = 'https://wa.me/$formattedNumber?text=${Uri.encodeComponent(message)}';

    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tidak dapat membuka WhatsApp: $e')),
      );
    }
  }

  // Helper method to format phone numbers
  String _formatPhoneNumber(String phoneNumber) {
    // Remove any non-numeric characters except the plus sign
    phoneNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

    // Format for Indonesian numbers
    if (phoneNumber.startsWith('0')) {
      // Convert 08xxx to +628xxx
      return '+62${phoneNumber.substring(1)}';
    } else if (phoneNumber.startsWith('62')) {
      // Convert 628xxx to +628xxx
      return '+$phoneNumber';
    } else if (!phoneNumber.startsWith('+')) {
      // Add plus if it doesn't have one
      return '+$phoneNumber';
    }

    return phoneNumber;
  }

  // Update the _buildPaymentRow method to use the Rupiah format
  Widget _buildPaymentRow(String label, double amount, {bool isTotal = false, String? additionalInfo}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                fontSize: isTotal ? 16 : 14,
              ),
            ),
            Text(
              GlobalStyle.formatRupiah(amount),
              style: TextStyle(
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                fontSize: isTotal ? 16 : 14,
                color: isTotal ? GlobalStyle.primaryColor : Colors.black,
              ),
            ),
          ],
        ),
        if (additionalInfo != null)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              additionalInfo,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),
      ],
    );
  }

  // Format price display
  String _formatPrice(double price) {
    final formatter = NumberFormat.currency(
      locale: 'id',
      symbol: 'Rp',
      decimalDigits: 0,
    );
    return formatter.format(price);
  }

  // Updated to use OrderItem model instead of Item
  Widget _buildItemsCard() {
    final List<OrderItem> items = _getOrderItems();

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    // Calculate totals using the Order object or fallback to data
    final double subtotal = _orderObject?.totalAmount ??
        (_orderData['total_amount'] as num?)?.toDouble() ?? 0.0;

    // Subtract delivery fee to get item subtotal
    final double itemSubtotal = subtotal - (_orderObject?.deliveryFee ?? 0.0);

    // Use calculated delivery fee
    final double deliveryFee = _calculatedDeliveryFee > 0 ? _calculatedDeliveryFee :
    (_orderObject?.deliveryFee ?? 0.0);

    final double totalAmount = subtotal;

    // Create additional info string for delivery fee if we have distance data
    String? deliveryFeeInfo;
    if (_distance > 0) {
      deliveryFeeInfo = 'Jarak: ${_distance.toStringAsFixed(2)} km × Rp 2.500/km = ${(_distance * 2500).toStringAsFixed(0)}';
    }

    return _buildCard(
      index: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shopping_bag, color: GlobalStyle.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Detail Pesanan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...items.map((item) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: GlobalStyle.borderColor),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  // Item image
                  if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: ImageService.displayImage(
                        imageSource: item.imageUrl!,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        placeholder: Container(
                          width: 60,
                          height: 60,
                          color: Colors.grey[300],
                          child: const Icon(Icons.fastfood),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.fastfood),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.formatPrice(),
                          style: TextStyle(
                            color: GlobalStyle.primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (item.description != null && item.description!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              item.description!,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
            )).toList(),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(),
            ),
            _buildPaymentRow('Subtotal', itemSubtotal),
            const SizedBox(height: 8),
            _buildPaymentRow(
                'Biaya Layanan',
                deliveryFee,
                additionalInfo: deliveryFeeInfo
            ),
            const SizedBox(height: 8),
            _buildPaymentRow('Total Pembayaran', totalAmount, isTotal: true),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    // Get current status
    final OrderStatus status = _getOrderStatus();

    // Only show action buttons for pending orders (awaiting store confirmation)
    if (status == OrderStatus.pending) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: _isUpdatingStatus ? null : _showCancelConfirmationDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text(
                'Tolak Pesanan',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _isUpdatingStatus ? null : _showApproveConfirmationDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: GlobalStyle.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text(
                'Terima Pesanan',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      );
    } else if (status == OrderStatus.cancelled) {
      // For cancelled orders, show disabled "Pesanan Dibatalkan" button
      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: null, // Disabled button
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                disabledBackgroundColor: Colors.red.withOpacity(0.6),
                disabledForegroundColor: Colors.white,
              ),
              child: const Text(
                'Pesanan Dibatalkan',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      );
    } else if (status == OrderStatus.confirmed || status == OrderStatus.preparing) {
      // For approved or in-progress orders, show status message
      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: null, // Disabled button
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                disabledBackgroundColor: Colors.blue.withOpacity(0.6),
                disabledForegroundColor: Colors.white,
              ),
              child: const Text(
                'Menunggu Driver',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      );
    } else if (status == OrderStatus.ready_for_pickup || status == OrderStatus.on_delivery) {
      // For orders being delivered
      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: null, // Disabled button
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                disabledBackgroundColor: Colors.purple.withOpacity(0.6),
                disabledForegroundColor: Colors.white,
              ),
              child: const Text(
                'Dalam Pengantaran',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      );
    } else if (status == OrderStatus.delivered) {
      // For completed orders
      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: null, // Disabled button
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                disabledBackgroundColor: Colors.green.withOpacity(0.6),
                disabledForegroundColor: Colors.white,
              ),
              child: const Text(
                'Pesanan Selesai',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // For any other status, don't show action buttons
    return const SizedBox.shrink();
  }

  // Loading indicator widget
  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: GlobalStyle.primaryColor),
          const SizedBox(height: 16),
          Text(
            'Memuat Detail Pesanan...',
            style: TextStyle(
              color: GlobalStyle.fontColor,
              fontSize: 16,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  // Error widget
  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 80, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Terjadi Kesalahan',
            style: TextStyle(
              color: GlobalStyle.fontColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage,
            style: TextStyle(
              color: GlobalStyle.fontColor,
              fontSize: 14,
              fontFamily: GlobalStyle.fontFamily,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              if (widget.orderId != null) {
                _loadOrderData();
              } else {
                Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Coba Lagi'),
            style: ElevatedButton.styleFrom(
              backgroundColor: GlobalStyle.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Extract items from order data using OrderItem model
  List<OrderItem> _getOrderItems() {
    if (_orderObject?.items != null) {
      return _orderObject!.items!;
    }

    final itemsData = _orderData['items'] as List?;
    if (itemsData == null || itemsData.isEmpty) {
      return [];
    }

    return itemsData.map((item) => OrderItem.fromJson(item)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffD6E6F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Detail Pesanan',
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
            child: Icon(Icons.arrow_back_ios_new,
                color: GlobalStyle.primaryColor, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingIndicator()
            : _hasError
            ? _buildErrorWidget()
            : RefreshIndicator(
          onRefresh: _refreshOrderData,
          color: GlobalStyle.primaryColor,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOrderStatusCard(),
                  _buildDriverInfoCard(),
                  _buildCustomerInfoCard(),
                  _buildStoreInfoCard(),
                  _buildItemsCard(),
                  const SizedBox(height: 80), // Space for bottom button
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: _isLoading || _hasError
          ? null
          : Container(
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
        child: _buildActionButtons(),
      ),
    );
  }
}