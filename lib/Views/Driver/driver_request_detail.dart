import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Services/driver_request_service.dart';
import 'package:lottie/lottie.dart';
import 'package:url_launcher/url_launcher.dart';

class DriverRequestDetailPage extends StatefulWidget {
  static const String route = '/Driver/RequestDetail';

  const DriverRequestDetailPage({Key? key}) : super(key: key);

  @override
  State<DriverRequestDetailPage> createState() =>
      _DriverRequestDetailPageState();
}

class _DriverRequestDetailPageState extends State<DriverRequestDetailPage> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _requestDetail;

  String? _requestId;
  Map<String, dynamic>? _initialRequestData;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        _requestId = args['requestId']?.toString();
        _initialRequestData = args['requestData'];
        _loadRequestDetail();
      } else {
        setState(() {
          _errorMessage = 'Invalid request data';
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _loadRequestDetail() async {
    if (_requestId == null) {
      setState(() {
        _errorMessage = 'Request ID not found';
        _isLoading = false;
      });
      return;
    }

    try {
      print('🔍 Loading driver request detail: $_requestId');

      final detail =
          await DriverRequestService.getDriverRequestDetail(_requestId!);

      setState(() {
        _requestDetail = detail;
        _isLoading = false;
        _errorMessage = null;
      });

      print('✅ Driver request detail loaded successfully');
    } catch (e) {
      print('❌ Error loading request detail: $e');

      // Fallback ke data initial jika ada
      if (_initialRequestData != null) {
        setState(() {
          _requestDetail = _initialRequestData;
          _isLoading = false;
          _errorMessage = null;
        });
        print('✅ Using initial request data as fallback');
      } else {
        setState(() {
          _errorMessage = 'Failed to load request details: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xffD6E6F2),
        appBar: AppBar(
          title: const Text('Request Details'),
          backgroundColor: GlobalStyle.primaryColor,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset(
                'assets/animations/loading_animation.json',
                width: 150,
                height: 150,
              ),
              const SizedBox(height: 16),
              Text(
                "Loading Request Details...",
                style: TextStyle(
                  color: GlobalStyle.primaryColor,
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                  fontFamily: GlobalStyle.fontFamily,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xffD6E6F2),
        appBar: AppBar(
          title: const Text('Request Details'),
          backgroundColor: GlobalStyle.primaryColor,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 80,
                color: Colors.red[400],
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.red[700],
                    fontSize: 16,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadRequestDetail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlobalStyle.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_requestDetail == null) {
      return Scaffold(
        backgroundColor: const Color(0xffD6E6F2),
        appBar: AppBar(
          title: const Text('Request Details'),
          backgroundColor: GlobalStyle.primaryColor,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('No request data available'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xffD6E6F2),
      appBar: AppBar(
        title: Text('Request #$_requestId'),
        backgroundColor: GlobalStyle.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadRequestDetail,
        color: GlobalStyle.primaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Request Status Card
              _buildStatusCard(),
              const SizedBox(height: 16),

              // Customer Information Card
              _buildCustomerInfoCard(),
              const SizedBox(height: 16),

              // Order Details Card (jika ada order)
              if (_requestDetail!['order'] != null) ...[
                _buildOrderDetailsCard(),
                const SizedBox(height: 16),
              ],

              // Contact Actions
              _buildContactActionsCard(),
              const SizedBox(height: 16),

              // Additional Info
              _buildAdditionalInfoCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final String status = _requestDetail!['status'] ?? 'pending';
    final DateTime createdAt = DateTime.parse(
        _requestDetail!['created_at'] ?? DateTime.now().toIso8601String());

    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status.toLowerCase()) {
      case 'accepted':
        statusColor = Colors.green;
        statusText = 'Accepted';
        statusIcon = Icons.check_circle;
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusText = 'Pending';
        statusIcon = Icons.access_time;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusText = 'Rejected';
        statusIcon = Icons.cancel;
        break;
      case 'completed':
        statusColor = Colors.blue;
        statusText = 'Completed';
        statusIcon = Icons.done_all;
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'Unknown';
        statusIcon = Icons.help;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  statusIcon,
                  color: statusColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Request Status',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontFamily: GlobalStyle.fontFamily,
                      ),
                    ),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                        fontFamily: GlobalStyle.fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  'Created: ${DateFormat('dd/MM/yyyy HH:mm').format(createdAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerInfoCard() {
    final order = _requestDetail!['order'];
    final customer = order?['customer'];

    if (customer == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text('Customer information not available'),
      );
    }

    final String customerName = customer['name'] ?? 'Unknown Customer';
    final String? customerPhone = customer['phone'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: GlobalStyle.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.person,
                  color: GlobalStyle.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customer Information',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontFamily: GlobalStyle.fontFamily,
                      ),
                    ),
                    Text(
                      customerName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: GlobalStyle.fontFamily,
                      ),
                    ),
                    if (customerPhone != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        customerPhone,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          fontFamily: GlobalStyle.fontFamily,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderDetailsCard() {
    final order = _requestDetail!['order'];
    if (order == null) return const SizedBox.shrink();

    final store = order['store'];
    final items = order['items'] ?? [];
    final double totalAmount =
        double.tryParse(order['total_amount']?.toString() ?? '0') ?? 0.0;
    final double deliveryFee =
        double.tryParse(order['delivery_fee']?.toString() ?? '0') ?? 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          const SizedBox(height: 16),

          // Store Info
          if (store != null) ...[
            Row(
              children: [
                Icon(Icons.store, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  'Store: ${store['name'] ?? 'Unknown Store'}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Order Items
          if (items.isNotEmpty) ...[
            Text(
              'Items Ordered:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                fontFamily: GlobalStyle.fontFamily,
              ),
            ),
            const SizedBox(height: 8),
            ...items
                .map<Widget>((item) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['name'] ?? 'Unknown Item',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: GlobalStyle.fontFamily,
                                  ),
                                ),
                                Text(
                                  'Qty: ${item['quantity'] ?? 1}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontFamily: GlobalStyle.fontFamily,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            GlobalStyle.formatRupiah(double.tryParse(
                                    item['price']?.toString() ?? '0') ??
                                0.0),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: GlobalStyle.primaryColor,
                              fontFamily: GlobalStyle.fontFamily,
                            ),
                          ),
                        ],
                      ),
                    ))
                .toList(),
            const SizedBox(height: 12),
          ],

          // Total Summary
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: GlobalStyle.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Order:',
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: GlobalStyle.fontFamily,
                      ),
                    ),
                    Text(
                      GlobalStyle.formatRupiah(totalAmount),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: GlobalStyle.fontFamily,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Delivery Fee:',
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: GlobalStyle.fontFamily,
                      ),
                    ),
                    Text(
                      GlobalStyle.formatRupiah(deliveryFee),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                        fontFamily: GlobalStyle.fontFamily,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactActionsCard() {
    final order = _requestDetail!['order'];
    final customer = order?['customer'];
    final store = order?['store'];
    final String? customerPhone = customer?['phone'];
    final String? storePhone = store?['phone'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contact Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          const SizedBox(height: 16),

          // Contact Customer
          if (customerPhone != null) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _contactCustomer(customerPhone),
                icon: const Icon(Icons.phone, color: Colors.white),
                label: const Text(
                  'Contact Customer',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _whatsappCustomer(customerPhone),
                icon: const Icon(Icons.chat, color: Colors.white),
                label: const Text(
                  'WhatsApp Customer',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],

          // Contact Store (if available)
          if (storePhone != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _contactStore(storePhone),
                icon: Icon(Icons.store, color: GlobalStyle.primaryColor),
                label: Text(
                  'Contact Store',
                  style: TextStyle(color: GlobalStyle.primaryColor),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: GlobalStyle.primaryColor),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdditionalInfoCard() {
    final String? notes = _requestDetail!['notes'];
    final estimatedPickupTime = _requestDetail!['estimated_pickup_time'];
    final estimatedDeliveryTime = _requestDetail!['estimated_delivery_time'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Additional Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          const SizedBox(height: 16),

          // Estimated Times
          if (estimatedPickupTime != null) ...[
            _buildInfoRow(
              icon: Icons.schedule,
              label: 'Est. Pickup Time',
              value: DateFormat('dd/MM HH:mm')
                  .format(DateTime.parse(estimatedPickupTime)),
            ),
            const SizedBox(height: 8),
          ],

          if (estimatedDeliveryTime != null) ...[
            _buildInfoRow(
              icon: Icons.access_time,
              label: 'Est. Delivery Time',
              value: DateFormat('dd/MM HH:mm')
                  .format(DateTime.parse(estimatedDeliveryTime)),
            ),
            const SizedBox(height: 8),
          ],

          // Notes
          if (notes != null && notes.isNotEmpty) ...[
            _buildInfoRow(
              icon: Icons.note,
              label: 'Notes',
              value: notes,
            ),
          ],

          // Request ID
          _buildInfoRow(
            icon: Icons.tag,
            label: 'Request ID',
            value: _requestId ?? 'Unknown',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontFamily: GlobalStyle.fontFamily,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  fontFamily: GlobalStyle.fontFamily,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Contact methods
  void _contactCustomer(String phone) async {
    final url = 'tel:$phone';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      _showErrorDialog('Could not launch phone dialer');
    }
  }

  void _whatsappCustomer(String phone) async {
    // Clean phone number (remove non-digits)
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    final url =
        'https://wa.me/$cleanPhone?text=Hello, I am your DelPick driver for request #$_requestId. I will be handling your order delivery.';

    if (await canLaunch(url)) {
      await launch(url);
    } else {
      _showErrorDialog('Could not open WhatsApp');
    }
  }

  void _contactStore(String phone) async {
    final url = 'tel:$phone';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      _showErrorDialog('Could not launch phone dialer');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Error',
            style: TextStyle(
              fontFamily: GlobalStyle.fontFamily,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            message,
            style: TextStyle(
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: GlobalStyle.primaryColor,
              ),
              child: Text(
                'OK',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: GlobalStyle.fontFamily,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
