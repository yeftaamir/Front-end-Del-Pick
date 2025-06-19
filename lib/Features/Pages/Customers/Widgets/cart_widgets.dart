// lib/Features/Pages/Customers/Widgets/cart_widgets.dart
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import '../../../../Common/global_style.dart';
import '../../../../Models/Entities/store.dart';
import '../../../../Models/Entities/driver.dart';
import '../../../../Models/Responses/order_responses.dart';
import '../../../../Models/Enums/order_status.dart';
import '../../../../Models/Extensions/driver_extensions.dart';

class CartWidgets {
  static final AudioPlayer _audioPlayer = AudioPlayer();

  // Build app bar
  static PreferredSizeWidget buildAppBar({
    required BuildContext context,
    required bool isCompletedOrder,
    OrderStatus? orderStatus,
  }) {
    String title = 'Keranjang Pesanan';

    if (isCompletedOrder) {
      if (orderStatus == OrderStatus.cancelled) {
        title = 'Pesanan Dibatalkan';
      } else if (orderStatus == OrderStatus.delivered) {
        title = 'Pesanan Selesai';
      } else {
        title = 'Riwayat Pesanan';
      }
    }

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      title: Text(
        title,
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
            Icons.arrow_back_ios_new,
            color: GlobalStyle.primaryColor,
            size: 18,
          ),
        ),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  // Build empty cart
  static Widget buildEmptyCart() {
    return Center(
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
    );
  }

  // Build order date card
  static Widget buildOrderDateCard({
    required DateTime orderDate,
    required Animation<Offset> animation,
  }) {
    return SlideTransition(
      position: animation,
      child: _buildCard(
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
              DateFormat('dd MMMM yyyy, HH:mm').format(orderDate),
              style: TextStyle(
                color: GlobalStyle.fontColor,
                fontFamily: GlobalStyle.fontFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build order items card
  static Widget buildOrderItemsCard({
    required Store store,
    required List<CartItem> cartItems,
    OrderStatus? orderStatus,
    required Animation<Offset> animation,
  }) {
    return SlideTransition(
      position: animation,
      child: _buildCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.restaurant_menu, color: GlobalStyle.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    store.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: GlobalStyle.fontColor,
                      fontFamily: GlobalStyle.fontFamily,
                    ),
                  ),
                  if (orderStatus != null) _buildStatusBadge(orderStatus),
                ],
              ),
            ),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cartItems.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = cartItems[index];
                return _buildOrderItemRow(item);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Build delivery address card
  static Widget buildDeliveryAddressCard({
    required String? deliveryAddress,
    required bool isCompletedOrder,
    required VoidCallback onLocationAccess,
    String? errorMessage,
    required Animation<Offset> animation,
  }) {
    return SlideTransition(
      position: animation,
      child: _buildCard(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
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
              if (isCompletedOrder || deliveryAddress != null)
                Text(
                  deliveryAddress ?? 'Alamat tidak tersedia',
                  style: TextStyle(
                    color: GlobalStyle.fontColor,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                )
              else
                GestureDetector(
                  onTap: onLocationAccess,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: errorMessage != null ? Colors.red : Colors.grey[300]!,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.my_location,
                          color: deliveryAddress != null
                              ? GlobalStyle.primaryColor
                              : Colors.grey,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            deliveryAddress ?? 'Pilih lokasi pengiriman',
                            style: TextStyle(
                              color: deliveryAddress != null
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
              if (errorMessage != null && !isCompletedOrder)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    errorMessage,
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
    );
  }

  // Build payment details card
  static Widget buildPaymentDetailsCard({
    required double subtotal,
    required double deliveryFee,
    required double total,
    required Animation<Offset> animation,
  }) {
    return SlideTransition(
      position: animation,
      child: _buildCard(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
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
              const SizedBox(height: 12),
              _buildPaymentRow('Subtotal', subtotal),
              const SizedBox(height: 8),
              _buildPaymentRow('Biaya Pengiriman', deliveryFee),
              const Divider(thickness: 1, height: 24),
              _buildPaymentRow('Total', total, isTotal: true),
            ],
          ),
        ),
      ),
    );
  }

  // Build driver card
  static Widget buildDriverCard({
    required Driver driver,
    required Animation<Offset> animation,
    required VoidCallback onCall,
    required VoidCallback onMessage,
    VoidCallback? onTrack,
  }) {
    return SlideTransition(
      position: animation,
      child: _buildCard(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
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
                  _buildDriverAvatar(driver.user?.avatar),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          driver.user?.name ?? 'Driver',
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
                              driver.vehiclePlate,
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
                              driver.formattedRating,
                              style: TextStyle(
                                color: Colors.grey[800],
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '(${driver.reviewsCount})',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
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
                      onPressed: onCall,
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
                      onPressed: onMessage,
                    ),
                  ),
                ],
              ),
              if (onTrack != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onTrack,
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
      ),
    );
  }

  // Build completed order actions
  static Widget buildCompletedOrderActions({
    required bool canShowRating,
    OrderStatus? orderStatus,
    required VoidCallback onRating,
    required VoidCallback onBuyAgain,
    required Animation<Offset> animation,
  }) {
    return SlideTransition(
      position: animation,
      child: _buildCard(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              if (canShowRating && orderStatus == OrderStatus.delivered)
                ElevatedButton(
                  onPressed: onRating,
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
              if (canShowRating) const SizedBox(height: 12),
              if (orderStatus == OrderStatus.cancelled)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    "Pesanan ini telah dibatalkan",
                    style: TextStyle(
                      color: Colors.red[800],
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              OutlinedButton(
                onPressed: onBuyAgain,
                style: OutlinedButton.styleFrom(
                  foregroundColor: GlobalStyle.primaryColor,
                  side: BorderSide(color: GlobalStyle.primaryColor, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(
                      vertical: 12, horizontal: 24),
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: Text(
                  orderStatus == OrderStatus.cancelled ? "Pesan Ulang" : "Beli Lagi",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build cancel order button
  static Widget buildCancelOrderButton({
    required VoidCallback onCancel,
    required bool isLoading,
    required Animation<Offset> animation,
  }) {
    return SlideTransition(
      position: animation,
      child: _buildCard(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: isLoading ? null : onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: isLoading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                ),
              )
                  : const Text(
                "Batalkan Pesanan",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Build create order button
  static Widget buildCreateOrderButton({
    required double total,
    required bool isLoading,
    required VoidCallback onCreateOrder,
  }) {
    return Positioned(
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
          onPressed: isLoading ? null : onCreateOrder,
          style: ElevatedButton.styleFrom(
            backgroundColor: GlobalStyle.primaryColor,
            disabledBackgroundColor: Colors.grey,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          child: isLoading
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
                'Memproses...',
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
    );
  }

  // Build loading overlay
  static Widget buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.3),
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      ),
    );
  }

  // Dialog methods
  static Future<void> showNoAddressDialog(BuildContext context, VoidCallback onLocationAccess) async {
    await _playSound('audio/wrong.mp3');

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlobalStyle.primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    onLocationAccess();
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

  static Future<void> showCreatingOrderDialog(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  "Membuat pesanan...",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Mohon tunggu sebentar",
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Future<void> showOrderSuccessDialog(BuildContext context) async {
    await _playSound('audio/kring.mp3');

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  "Pesanan berhasil dibuat",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlobalStyle.primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
  }

  static Future<bool> showCancelConfirmationDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Batalkan Pesanan',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          content: Text(
            'Apakah Anda yakin ingin membatalkan pesanan ini?',
            style: TextStyle(fontFamily: GlobalStyle.fontFamily),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Tidak',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontFamily: GlobalStyle.fontFamily,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                'Ya, Batalkan',
                style: TextStyle(
                  fontFamily: GlobalStyle.fontFamily,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  static Future<void> showOrderCancelledDialog(BuildContext context) async {
    await _playSound('audio/found.wav');

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/animations/cancel.json',
                  width: 200,
                  height: 200,
                  repeat: false,
                ),
                const SizedBox(height: 20),
                const Text(
                  "Pesanan telah dibatalkan",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
  }

  static Future<void> showRatingSuccessDialog(BuildContext context) async {
    await _playSound('audio/kring.mp3');

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/animations/check_animation.json',
                  width: 150,
                  height: 150,
                  repeat: false,
                ),
                const SizedBox(height: 20),
                const Text(
                  "Terima kasih atas rating Anda!",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlobalStyle.primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
  }

  static Future<void> showErrorDialog(BuildContext context, String message) async {
    await _playSound('audio/wrong.mp3');

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Error'),
          content: Text(message),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: GlobalStyle.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                'OK',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  // Play sound
  static Future<void> playStatusChangeSound() async {
    await _playSound('audio/kring.mp3');
  }

  static Future<void> _playSound(String assetPath) async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource(assetPath));
    } catch (e) {
      print('Error playing sound: $e');
    }
  }

  // Helper methods
  static Widget _buildCard({required Widget child}) {
    return Container(
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
      child: child,
    );
  }

  static Widget _buildStatusBadge(OrderStatus status) {
    Color backgroundColor;
    Color textColor;
    String text;

    switch (status) {
      case OrderStatus.cancelled:
        backgroundColor = Colors.red[100]!;
        textColor = Colors.red[800]!;
        text = 'Dibatalkan';
        break;
      case OrderStatus.delivered:
        backgroundColor = Colors.green[100]!;
        textColor = Colors.green[800]!;
        text = 'Selesai';
        break;
      default:
        backgroundColor = Colors.blue[100]!;
        textColor = Colors.blue[800]!;
        text = 'Aktif';
    }

    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  static Widget _buildOrderItemRow(CartItem item) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      leading: SizedBox(
        width: 60,
        height: 60,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: item.menuItem.imageUrl ?? '',
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: Colors.grey[300],
              child: const Icon(Icons.restaurant_menu, color: Colors.white70),
            ),
            errorWidget: (context, error, stackTrace) => Container(
              color: Colors.grey[300],
              child: const Icon(Icons.image_not_supported, color: Colors.white70),
            ),
          ),
        ),
      ),
      title: Text(
        item.menuItem.name,
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
            GlobalStyle.formatRupiah(item.menuItem.price),
            style: const TextStyle(color: Colors.grey),
          ),
          Text(
            'Jumlah: ${item.quantity}',
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
      trailing: Text(
        GlobalStyle.formatRupiah(item.totalPrice),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: GlobalStyle.primaryColor,
          fontFamily: GlobalStyle.fontFamily,
        ),
      ),
    );
  }

  static Widget _buildPaymentRow(String label, double amount, {bool isTotal = false}) {
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

  static Widget _buildDriverAvatar(String? avatarUrl) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: ClipOval(
        child: avatarUrl != null && avatarUrl.isNotEmpty
            ? CachedNetworkImage(
          imageUrl: avatarUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => Center(
            child: Icon(Icons.person, size: 30, color: Colors.grey[400]),
          ),
          errorWidget: (context, error, stackTrace) => Center(
            child: Icon(Icons.person, size: 30, color: Colors.grey[400]),
          ),
        )
            : Center(
          child: Icon(Icons.person, size: 30, color: Colors.grey[400]),
        ),
      ),
    );
  }
}