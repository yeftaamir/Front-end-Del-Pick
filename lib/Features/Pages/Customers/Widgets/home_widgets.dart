// lib/pages/customers/widgets/home_widgets.dart
import 'package:del_pick/Models/Extensions/store_extensions.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lottie/lottie.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../../../Common/global_style.dart';
import '../../../../Models/Entities/store.dart';

class HomeWidgets {
  // Build search app bar
  static PreferredSizeWidget buildSearchAppBar({
    required bool isSearching,
    required TextEditingController searchController,
    required String? userName,
    required VoidCallback onSearchPressed,
    required VoidCallback onBackPressed,
    required VoidCallback onProfilePressed,
  }) {
    return AppBar(
      elevation: 0.5,
      backgroundColor: Colors.white,
      leading: isSearching
          ? IconButton(
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
        onPressed: onBackPressed,
      )
          : IconButton(
        icon: const Icon(Icons.search, color: Colors.black54),
        onPressed: onSearchPressed,
      ),
      title: isSearching
          ? TextField(
        controller: searchController,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Cari toko...',
          border: InputBorder.none,
          hintStyle: TextStyle(
            color: GlobalStyle.fontColor,
            fontSize: GlobalStyle.fontSize,
          ),
        ),
        style: TextStyle(
          color: GlobalStyle.fontColor,
          fontSize: GlobalStyle.fontSize,
        ),
      )
          : Row(
        children: [
          Text(
            'Del Pick',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          if (userName != null && userName.isNotEmpty)
            Flexible(
              child: Text(
                ' • Hi, $userName',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontFamily: GlobalStyle.fontFamily,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: IconButton(
            icon: const Icon(LucideIcons.user, color: Colors.black54),
            onPressed: onProfilePressed,
          ),
        ),
      ],
    );
  }

  // Build location loading indicator
  static Widget buildLocationLoading() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      color: Colors.blue.shade50,
      width: double.infinity,
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: GlobalStyle.primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Mendapatkan lokasi terdekat...',
            style: TextStyle(
              color: GlobalStyle.primaryColor,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // Build recommendations carousel
  static Widget buildRecommendationsCarousel({
    required List<Store> nearbyStores,
    required List<Store> featuredStores,
    required Map<int, double> distances,
    required Function(Store) onStoreTap,
  }) {
    return Column(
      children: [
        // Nearby Stores Section
        if (nearbyStores.isNotEmpty) ...[
          _buildSectionHeader(
            title: 'Toko Terdekat',
            icon: LucideIcons.mapPin,
            color: Colors.green[600]!,
          ),
          const SizedBox(height: 12),
          _buildStoreCarousel(
            stores: nearbyStores,
            distances: distances,
            onStoreTap: onStoreTap,
            showDistance: true,
          ),
          const SizedBox(height: 24),
        ],

        // Featured Stores Section
        if (featuredStores.isNotEmpty) ...[
          _buildSectionHeader(
            title: 'Toko Terpopuler',
            icon: LucideIcons.star,
            color: Colors.orange[600]!,
          ),
          const SizedBox(height: 12),
          _buildStoreCarousel(
            stores: featuredStores,
            distances: distances,
            onStoreTap: onStoreTap,
            showDistance: false,
          ),
          const SizedBox(height: 24),
        ],
      ],
    );
  }

  // Build section header
  static Widget _buildSectionHeader({
    required String title,
    required IconData icon,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: GlobalStyle.fontColor,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  // Build store carousel
  static Widget _buildStoreCarousel({
    required List<Store> stores,
    required Map<int, double> distances,
    required Function(Store) onStoreTap,
    required bool showDistance,
  }) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: stores.length,
        itemBuilder: (context, index) {
          final store = stores[index];
          return Container(
            width: 160,
            margin: const EdgeInsets.only(right: 12),
            child: _buildCarouselStoreCard(
              store: store,
              distance: distances[store.id],
              onTap: () => onStoreTap(store),
              showDistance: showDistance,
            ),
          );
        },
      ),
    );
  }

  // Build carousel store card
  static Widget _buildCarouselStoreCard({
    required Store store,
    required double? distance,
    required VoidCallback onTap,
    required bool showDistance,
  }) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Store image
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: buildStoreImage(
                      imageUrl: store.imageUrl,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                  // Rating badge
                  if (store.rating != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: GlobalStyle.primaryColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.white,
                              size: 12,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              store.formattedRating,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Distance badge
                  if (showDistance && distance != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          distance < 1
                              ? '${(distance * 1000).toInt()} m'
                              : '${distance.toStringAsFixed(1)} km',
                          style: TextStyle(
                            color: GlobalStyle.primaryColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Store info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: GlobalStyle.fontColor,
                        fontFamily: GlobalStyle.fontFamily,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (store.description != null && store.description!.isNotEmpty)
                      Text(
                        store.description!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontFamily: GlobalStyle.fontFamily,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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

  // Build main store card (for list view)
  static Widget buildStoreCard({
    required Store store,
    required double? distance,
    required VoidCallback onTap,
    required Animation<double> scaleAnimation,
    required Animation<double> fadeAnimation,
  }) {
    return ScaleTransition(
      scale: scaleAnimation,
      child: FadeTransition(
        opacity: fadeAnimation,
        child: Card(
          margin: const EdgeInsets.only(bottom: 16.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          elevation: 2,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stack(
                  children: [
                    Hero(
                      tag: 'store-${store.id}',
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12.0),
                        ),
                        child: buildStoreImage(
                          imageUrl: store.imageUrl,
                          width: double.infinity,
                          height: 200,
                        ),
                      ),
                    ),
                    // Rating badge
                    if (store.rating != null)
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 4.0,
                          ),
                          decoration: BoxDecoration(
                            color: GlobalStyle.primaryColor,
                            borderRadius: BorderRadius.circular(16.0),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                store.formattedRating,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // Distance badge
                    if (distance != null)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 4.0,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(16.0),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                LucideIcons.mapPin,
                                color: GlobalStyle.primaryColor,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                distance < 1
                                    ? '${(distance * 1000).toInt()} m'
                                    : '${distance.toStringAsFixed(1)} km',
                                style: TextStyle(
                                  color: GlobalStyle.primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        store.name,
                        style: TextStyle(
                          fontSize: 18.0,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          fontFamily: GlobalStyle.fontFamily,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.store,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${store.reviewCount ?? 0} ulasan • ${store.totalProducts ?? 0} menu',
                            style: TextStyle(
                              fontSize: 14.0,
                              color: Colors.grey[600],
                              fontFamily: GlobalStyle.fontFamily,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (store.description != null && store.description!.isNotEmpty)
                        Text(
                          store.description!,
                          style: TextStyle(
                            fontSize: 14.0,
                            color: Colors.grey[600],
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              store.address,
                              style: TextStyle(
                                fontSize: 14.0,
                                color: Colors.grey[600],
                                fontFamily: GlobalStyle.fontFamily,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${store.openTime ?? "09:00"} - ${store.closeTime ?? "21:00"}',
                            style: TextStyle(
                              fontSize: 14.0,
                              color: Colors.grey[600],
                              fontFamily: GlobalStyle.fontFamily,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: store.isOpen
                                  ? Colors.green[100]
                                  : Colors.red[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              store.statusDisplayName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: store.isOpen
                                    ? Colors.green[700]
                                    : Colors.red[700],
                              ),
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
        ),
      ),
    );
  }

  // Build store image with fallback
  static Widget buildStoreImage({
    required String? imageUrl,
    required double width,
    required double height,
  }) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return _buildPlaceholderImage(width, height);
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: BoxFit.cover,
      placeholder: (context, url) => _buildPlaceholderImage(width, height),
      errorWidget: (context, url, error) => _buildPlaceholderImage(width, height),
    );
  }

  // Build placeholder image
  static Widget _buildPlaceholderImage(double width, double height) {
    return Container(
      height: height,
      width: width,
      color: Colors.grey[300],
      child: Center(
        child: Icon(
          LucideIcons.imageOff,
          size: height > 100 ? 40 : 24,
          color: Colors.grey[500],
        ),
      ),
    );
  }

  // Build loading state
  static Widget buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: GlobalStyle.primaryColor),
          const SizedBox(height: 16),
          Text(
            'Memuat daftar toko...',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  // Build error state
  static Widget buildErrorState({
    required String message,
    required VoidCallback onRetry,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            LucideIcons.alertTriangle,
            color: Colors.orange,
            size: 50,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: GlobalStyle.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  // Build empty state
  static Widget buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.store,
            color: Colors.grey[400],
            size: 50,
          ),
          const SizedBox(height: 16),
          const Text(
            'Tidak ada toko yang ditemukan',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  // Build empty search state
  static Widget buildEmptySearchState() {
    return const Center(
      child: Text(
        'Ketik untuk mencari toko...',
        style: TextStyle(
          color: Colors.grey,
          fontSize: 16,
        ),
      ),
    );
  }

  // Show promotional dialog
  static void showPromotionalDialog(BuildContext context) {
    final audioPlayer = AudioPlayer();

    // Play sound
    audioPlayer.play(AssetSource('audio/kring.mp3'));

    // Get random promotional message
    final messages = [
      "Lapar? Pilih makanan favoritmu sekarang!",
      "Cek toko langganan mu, mungkin ada menu baru!",
      "Yuk, pesan makanan kesukaanmu dalam sekali klik!",
      "Hayo, lagi cari apa? Del Pick siap layani pesanan mu",
      "Waktu makan siang! Pesan sekarang",
      "Kelaparan? Del Pick siap mengantar!",
      "Ingin makan enak tanpa ribet? Del Pick solusinya!",
    ];

    final randomMessage = messages[
    DateTime.now().millisecondsSinceEpoch % messages.length];

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () {
                    audioPlayer.dispose();
                    Navigator.of(context).pop();
                  },
                ),
              ),
              Lottie.asset(
                'assets/animations/pilih_pesanan.json',
                height: 200,
                width: 200,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 20),
              Text(
                randomMessage,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}