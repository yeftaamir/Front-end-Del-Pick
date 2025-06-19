// lib/pages/customers/widgets/store_detail_widgets.dart
import 'dart:async';
import 'package:del_pick/Models/Extensions/menu_item_extensions.dart';
import 'package:del_pick/Models/Extensions/store_extensions.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lottie/lottie.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../../../Common/global_style.dart';
import '../../../../Models/Entities/menu_item.dart';
import '../../../../Models/Entities/store.dart';

class StoreDetailWidgets {

  // Build store header with image and navigation
  static Widget buildStoreHeader({
    required Store store,
    required TextEditingController searchController,
    required VoidCallback onBackPressed,
    required VoidCallback onSearchFocused,
    required VoidCallback onSearchCleared,
  }) {
    return Stack(
      children: [
        // Store banner image
        SizedBox(
          width: double.infinity,
          height: 230,
          child: CachedNetworkImage(
            imageUrl: store.imageUrl ?? '',
            width: double.infinity,
            height: 230,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              width: double.infinity,
              height: 230,
              color: Colors.grey[300],
              child: const Center(
                child: Icon(Icons.store, size: 80, color: Colors.grey),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              width: double.infinity,
              height: 230,
              color: Colors.grey[300],
              child: const Center(
                child: Icon(Icons.store, size: 80, color: Colors.grey),
              ),
            ),
          ),
        ),

        // Navigation and search bar
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
            child: Row(
              children: [
                // Back button
                _buildBackButton(onBackPressed),
                const SizedBox(width: 12),

                // Search bar
                Expanded(
                  child: _buildSearchBar(
                    searchController,
                    onSearchFocused,
                    onSearchCleared,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Build back button
  static Widget _buildBackButton(VoidCallback onPressed) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(24),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onPressed,
        child: Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(
            Icons.arrow_back_ios_new,
            color: GlobalStyle.primaryColor,
            size: 16,
          ),
        ),
      ),
    );
  }

  // Build search bar
  static Widget _buildSearchBar(
      TextEditingController controller,
      VoidCallback onFocused,
      VoidCallback onCleared,
      ) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(24),
      color: Colors.white,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(Icons.search, color: GlobalStyle.primaryColor, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'Cari menu...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 14),
                onTap: onFocused,
              ),
            ),
            if (controller.text.isNotEmpty)
              GestureDetector(
                onTap: onCleared,
                child: const Icon(Icons.close, color: Colors.grey, size: 18),
              ),
          ],
        ),
      ),
    );
  }

  // Build store information section
  static Widget buildStoreInfo({
    required Store store,
    required String formattedDistance,
    required bool isLoadingLocation,
  }) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      transform: Matrix4.translationValues(0, -30, 0),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 48,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Store name
            Text(
              store.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Address
            Text(
              store.address,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
              textAlign: TextAlign.center,
            ),

            // Operating hours
            Text(
              'Buka: ${store.openTime ?? "09:00"} - ${store.closeTime ?? "21:00"}',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),

            // Distance and rating
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Distance
                  Row(
                    children: [
                      const FaIcon(FontAwesomeIcons.locationDot,
                          color: Colors.blue, size: 16),
                      const SizedBox(width: 4),
                      isLoadingLocation
                          ? SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.grey[400],
                        ),
                      )
                          : Text(
                        formattedDistance,
                        style: const TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(width: 24),

                  // Rating
                  Row(
                    children: [
                      const FaIcon(FontAwesomeIcons.star,
                          color: Colors.blue, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        store.formattedRating,
                        style: const TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Store status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: store.isOpen ? Colors.green[100] : Colors.red[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                store.statusDisplayName,
                style: TextStyle(
                  color: store.isOpen ? Colors.green[700] : Colors.red[700],
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build carousel menu section
  static Widget buildCarouselMenu({
    required List<MenuItem> menuItems,
    required PageController pageController,
    required Function(int) onPageChanged,
    required Function(MenuItem) onItemTapped,
    required Map<int, int> originalStockMap,
  }) {
    if (menuItems.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 300,
      child: PageView.builder(
        controller: pageController,
        itemCount: menuItems.length,
        onPageChanged: onPageChanged,
        itemBuilder: (context, index) {
          final item = menuItems[index];
          return GestureDetector(
            onTap: () => onItemTapped(item),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Opacity(
                opacity: item.isAvailable ? 1.0 : 0.5,
                child: _buildCarouselMenuItem(item, originalStockMap),
              ),
            ),
          );
        },
      ),
    );
  }

  // Build individual carousel menu item
  static Widget _buildCarouselMenuItem(MenuItem item, Map<int, int> originalStockMap) {
    final remainingStock = originalStockMap[item.id] ?? 0;

    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                spreadRadius: 1,
                blurRadius: 6,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Container(
                    width: double.infinity,
                    color: Colors.white,
                    child: CachedNetworkImage(
                      imageUrl: item.imageUrl ?? '',
                      fit: BoxFit.contain,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: Icon(Icons.restaurant_menu, size: 40, color: Colors.grey),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: Icon(Icons.restaurant_menu, size: 40, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Product information
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Price
                    Text(
                      item.formattedPrice,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: GlobalStyle.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Name
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Stock information
                    Row(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 14,
                          color: remainingStock > 0 ? Colors.grey : Colors.red,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Stok: $remainingStock',
                          style: TextStyle(
                            fontSize: 12,
                            color: remainingStock > 0 ? Colors.grey : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Unavailable badge
        if (!item.isAvailable)
          Positioned(
            top: 10,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.8),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
              child: const Text(
                'TUTUP',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Build menu list section
  static Widget buildMenuList({
    required List<MenuItem> menuItems,
    required String searchQuery,
    required Function(MenuItem) onItemTapped,
    required Function(MenuItem) onAddToCart,
    required Function(MenuItem) onIncrement,
    required Function(MenuItem) onDecrement,
    required Map<int, int> originalStockMap,
    required Map<int, int> cartQuantities,
  }) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title or search results
          searchQuery.isNotEmpty
              ? Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              "Hasil pencarian: ${menuItems.length} items",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          )
              : const Text(
            "Menu",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),

          // Menu items or empty state
          menuItems.isEmpty
              ? _buildEmptyState(searchQuery)
              : ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: menuItems.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildListMenuItem(
                  menuItems[index],
                  onItemTapped,
                  onAddToCart,
                  onIncrement,
                  onDecrement,
                  originalStockMap,
                  cartQuantities,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Build empty state
  static Widget _buildEmptyState(String searchQuery) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Column(
          children: [
            Icon(Icons.restaurant_menu, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              searchQuery.isNotEmpty
                  ? 'Tidak ada menu yang sesuai dengan pencarian'
                  : 'Tidak ada menu tersedia',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Build individual list menu item
  static Widget _buildListMenuItem(
      MenuItem item,
      Function(MenuItem) onItemTapped,
      Function(MenuItem) onAddToCart,
      Function(MenuItem) onIncrement,
      Function(MenuItem) onDecrement,
      Map<int, int> originalStockMap,
      Map<int, int> cartQuantities,
      ) {
    final remainingStock = originalStockMap[item.id] ?? 0;
    final currentQuantity = cartQuantities[item.id] ?? 0;

    return Opacity(
      opacity: item.isAvailable ? 1.0 : 0.5,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 6,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Main content
            Row(
              children: [
                // Text section
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: () => onItemTapped(item),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Name
                          Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),

                          // Stock information
                          Row(
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 14,
                                color: remainingStock > 0 ? Colors.grey : Colors.red,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Stok: $remainingStock',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: remainingStock > 0 ? Colors.grey : Colors.red,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Price
                          Text(
                            item.formattedPrice,
                            style: TextStyle(
                              fontSize: 16,
                              color: GlobalStyle.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Image section
                Expanded(
                  flex: 1,
                  child: GestureDetector(
                    onTap: () => onItemTapped(item),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(12)),
                      child: CachedNetworkImage(
                        imageUrl: item.imageUrl ?? '',
                        height: 140,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: Icon(Icons.restaurant_menu, size: 30, color: Colors.grey),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: Icon(Icons.restaurant_menu, size: 30, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Add/Quantity control button
            Positioned(
              bottom: 10,
              right: 20,
              child: currentQuantity > 0
                  ? buildQuantityControl(
                item: item,
                quantity: currentQuantity,
                onIncrement: () => onIncrement(item),
                onDecrement: () => onDecrement(item),
                remainingStock: remainingStock,
              )
                  : buildAddButton(
                item: item,
                onPressed: () => onAddToCart(item),
                remainingStock: remainingStock,
              ),
            ),

            // Status badges
            if (!item.isAvailable)
              _buildUnavailableBadge(),
            if (item.isAvailable && remainingStock <= 0)
              _buildOutOfStockBadge(),
          ],
        ),
      ),
    );
  }

  // Build add button
  static Widget buildAddButton({
    required MenuItem item,
    required VoidCallback onPressed,
    required int remainingStock,
  }) {
    final bool hasStock = remainingStock > 0;

    return SizedBox(
      height: 30,
      width: 90,
      child: ElevatedButton(
        onPressed: (item.isAvailable && hasStock) ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: (item.isAvailable && hasStock)
              ? GlobalStyle.primaryColor
              : Colors.grey,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          elevation: 3,
        ),
        child: const Text(
          'Tambah',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // Build quantity control widget
  static Widget buildQuantityControl({
    required MenuItem item,
    required int quantity,
    required VoidCallback onIncrement,
    required VoidCallback onDecrement,
    required int remainingStock,
  }) {
    final bool hasStock = remainingStock > 0;

    return Container(
      height: 30,
      decoration: BoxDecoration(
        color: item.isAvailable ? GlobalStyle.primaryColor : Colors.grey,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Minus button
          InkWell(
            onTap: onDecrement,
            child: Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              child: const Icon(Icons.remove, color: Colors.white, size: 16),
            ),
          ),

          // Quantity display
          Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '$quantity',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Plus button
          InkWell(
            onTap: (item.isAvailable && hasStock) ? onIncrement : null,
            child: Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              child: const Icon(Icons.add, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  // Build unavailable badge
  static Widget _buildUnavailableBadge() {
    return Positioned(
      top: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.8),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(12),
            bottomLeft: Radius.circular(12),
          ),
        ),
        child: const Text(
          'TUTUP',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  // Build out of stock badge
  static Widget _buildOutOfStockBadge() {
    return Positioned(
      top: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.8),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(12),
            bottomLeft: Radius.circular(12),
          ),
        ),
        child: const Text(
          'STOK HABIS',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  // Build cart summary
  static Widget buildCartSummary({
    required int totalItems,
    required double totalPrice,
    required MenuItem? lastAddedItem,
    required Animation<double> cartAnimation,
    required VoidCallback onViewCart,
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Last added item notification
            if (lastAddedItem != null)
              FadeTransition(
                opacity: cartAnimation,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lastAddedItem.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              lastAddedItem.formattedPrice,
                              style: TextStyle(
                                color: GlobalStyle.primaryColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Cart summary row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$totalItems items',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  GlobalStyle.formatRupiah(totalPrice),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: GlobalStyle.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // View cart button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onViewCart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlobalStyle.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shopping_cart, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Tampilkan Pesanan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Show dialog methods
  static void showItemUnavailableDialog(BuildContext context) {
    _showAnimatedDialog(
      context: context,
      title: 'Item ini sedang tidak tersedia',
      message: 'Mohon pilih item lain yang tersedia',
      audioPath: 'audio/wrong.mp3',
    );
  }

  static void showOutOfStockDialog(BuildContext context) {
    _showAnimatedDialog(
      context: context,
      title: 'Stok item tidak mencukupi',
      message: 'Mohon kurangi jumlah pesanan atau pilih item lain',
      audioPath: 'audio/wrong.mp3',
    );
  }

  static void showZeroQuantityDialog(BuildContext context) {
    _showAnimatedDialog(
      context: context,
      title: 'Pilih jumlah item terlebih dahulu',
      message: '',
      audioPath: 'audio/wrong.mp3',
    );
  }

  static void _showAnimatedDialog({
    required BuildContext context,
    required String title,
    required String message,
    required String audioPath,
  }) {
    // Play sound
    final audioPlayer = AudioPlayer();
    audioPlayer.play(AssetSource(audioPath));

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          child: Container(
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
                const SizedBox(height: 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (message.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      audioPlayer.dispose();
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GlobalStyle.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Mengerti',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Show success animation
  static void showSuccessAnimation(BuildContext context, MenuItem item) {
    final audioPlayer = AudioPlayer();
    audioPlayer.play(AssetSource('audio/kring.mp3'));

    // You can implement a custom success animation here
    // For now, we'll just dispose the audio player
    Future.delayed(const Duration(seconds: 2), () {
      audioPlayer.dispose();
    });
  }

  // Loading state
  static Widget buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
}