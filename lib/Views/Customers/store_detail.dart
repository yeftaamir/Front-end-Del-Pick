import 'dart:async';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Models/menu_item.dart';
import 'package:del_pick/Views/Customers/cart_screen.dart';
import 'package:lottie/lottie.dart'; // Import Lottie for animations
import 'package:audioplayers/audioplayers.dart'; // Import AudioPlayers for audio playback

class StoreDetail extends StatefulWidget {
  static const String route = "/Customers/StoreDetail";
  final List<MenuItem>? sharedMenuItems;

  const StoreDetail({super.key, this.sharedMenuItems});

  @override
  State<StoreDetail> createState() => _StoreDetailState();
}

class _StoreDetailState extends State<StoreDetail> {
  late List<MenuItem> menuItems;
  late List<MenuItem> filteredItems;
  late PageController _pageController;
  late Timer _timer;
  int _currentPage = 0;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer(); // Audio player instance

  @override
  void initState() {
    super.initState();
    menuItems = widget.sharedMenuItems ?? [
      MenuItem(id: '1', name: 'Ayam Geprek + Nasi', price: 21800),
      MenuItem(id: '2', name: 'Ayam Geprek + Nasi Jumbo + Es Teh', price: 25800),
      MenuItem(id: '3', name: 'Mie Goreng + Pangsit', price: 31800),
      MenuItem(id: '4', name: 'Ayam Saos Hot Bbq + Nasi + Es Teh', price: 23800),
      MenuItem(id: '5', name: 'Ayam Geprek Tanpa Nasi', price: 19800),
    ];
    filteredItems = List<MenuItem>.from(menuItems);
    _pageController = PageController(viewportFraction: 0.8, initialPage: 0);
    _startAutoScroll();
  }

  void _performSearch() {
    final query = _searchController.text;
    final results = query.isEmpty
        ? List<MenuItem>.from(menuItems)
        : menuItems
        .where((item) =>
        item.name.toLowerCase().contains(query.toLowerCase()))
        .toList();

    _showSearchResults(results);
  }

  void _showSearchResults(List<MenuItem> results) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.2,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Search Results (${results.length})',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: results.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (context, index) {
                      final item = results[index];
                      return InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          _showItemDetail(item);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
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
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.asset(
                                  'assets/images/menu_item.jpg',
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      GlobalStyle.formatRupiah(item.price),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: GlobalStyle.primaryColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_currentPage < menuItems.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }

      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _timer.cancel();
    _searchController.dispose();
    _audioPlayer.dispose(); // Dispose the audio player
    super.dispose();
  }

  // Show dialog for quantity 0
  void _showZeroQuantityDialog() {
    // Play the wrong sound
    _audioPlayer.play(AssetSource('audio/wrong.mp3'));

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
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
                const Text(
                  'Pilih jumlah item terlebih dahulu',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
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

  void _showItemDetail(MenuItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableItemDetail(
        item: item,
        onQuantityChanged: (int quantity) {
          setState(() {
            item.quantity = quantity;
          });
        },
        onZeroQuantity: _showZeroQuantityDialog, // Pass the dialog function
      ),
    );
  }

  bool get hasItemsInCart => menuItems.any((item) => item.quantity > 0);
  int get totalItems => menuItems.fold(0, (sum, item) => sum + item.quantity);
  double get totalPrice =>
      menuItems.fold(0, (sum, item) => sum + (item.price * item.quantity));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                _buildHeader(),
                _buildStoreInfo(),
                _buildCarouselMenu(),
                _buildListMenu(),
                if (hasItemsInCart) const SizedBox(height: 100),
              ],
            ),
          ),
          if (hasItemsInCart) _buildCartSummary(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      children: [
        Image.asset(
          'assets/images/store_front.jpg',
          width: double.infinity,
          height: 230,
          fit: BoxFit.cover,
        ),
        Positioned(
          top: 40,
          left: 16,
          right: 16,
          child: Row(
            children: [
              InkWell(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
                  ),
                  child: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.blue, size: 16),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: _isSearching ? double.infinity : 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 6)
                    ],
                  ),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 40,
                        child: Center(
                          child: InkWell(
                            onTap: () {
                              if (_isSearching) {
                                _performSearch();
                              } else {
                                setState(() {
                                  _isSearching = true;
                                });
                              }
                            },
                            child: Icon(
                              _isSearching ? Icons.search : Icons.search,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 300),
                          opacity: _isSearching ? 1.0 : 0.0,
                          child: _isSearching
                              ? Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  decoration: const InputDecoration(
                                    hintText: 'Search menu...',
                                    border: InputBorder.none,
                                    contentPadding:
                                    EdgeInsets.symmetric(horizontal: 8),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  setState(() {
                                    _isSearching = false;
                                    _searchController.clear();
                                  });
                                },
                              ),
                            ],
                          )
                              : const SizedBox(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStoreInfo() {
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
            Container(
              width: 48,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'TOKO Indonesia',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Jalan Raya Utama No. 123, Jakarta',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const Text(
              'Buka: 08.00 - 22.00 WIB',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      FaIcon(FontAwesomeIcons.locationDot,
                          color: Colors.blue, size: 16),
                      SizedBox(width: 4),
                      Text('3 KM',
                          style: TextStyle(color: Colors.grey, fontSize: 14)),
                    ],
                  ),
                  SizedBox(width: 24),
                  Row(
                    children: [
                      FaIcon(FontAwesomeIcons.star,
                          color: Colors.blue, size: 16),
                      SizedBox(width: 4),
                      Text('4.8 rating',
                          style: TextStyle(color: Colors.grey, fontSize: 14)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarouselMenu() {
    return SizedBox(
      height: 300, // Increased height to accommodate full product image
      child: PageView.builder(
        controller: _pageController,
        itemCount: filteredItems.length,
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
          });
        },
        itemBuilder: (context, index) {
          final item = filteredItems[index];
          return GestureDetector(
            onTap: () => _showItemDetail(item),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _buildCarouselMenuItem(item),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCarouselMenuItem(MenuItem item) {
    // Updated carousel card based on the image example
    return Container(
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
          // Image wrapper with fixed height to prevent cropping
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Container(
                width: double.infinity,
                color: Colors.white,
                child: Image.asset(
                  'assets/images/menu_item.jpg',
                  fit: BoxFit.contain, // Use contain to show full image without cropping
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
                // Price - Using primary color
                Text(
                  GlobalStyle.formatRupiah(item.price),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListMenu() {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Menu",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredItems.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildListMenuItem(filteredItems[index]),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildListMenuItem(MenuItem item) {
    return GestureDetector(
      onTap: () => _showItemDetail(item),
      child: Container(
        height: 140, // Reduced height
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
            // Main content with image and text
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          GlobalStyle.formatRupiah(item.price),
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
                // Image on the right
                Expanded(
                  flex: 1,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
                    child: Image.asset(
                      'assets/images/menu_item.jpg',
                      height: 140,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ],
            ),
            // "Tambah" button positioned on the right, overlapping the image
            Positioned(
              bottom: 10,
              right: 20,
              child: SizedBox(
                height: 30,
                width: 90,
                child: ElevatedButton(
                  onPressed: () => _showItemDetail(item),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlobalStyle.primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    // Add elevation for better visibility over the image
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartSummary() {
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
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final cartItems =
                  menuItems.where((item) => item.quantity > 0).toList();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CartScreen(cartItems: cartItems),
                    ),
                  );
                },
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
}

class DraggableItemDetail extends StatefulWidget {
  final MenuItem item;
  final Function(int) onQuantityChanged;
  final VoidCallback onZeroQuantity; // Add callback for zero quantity

  const DraggableItemDetail({
    Key? key,
    required this.item,
    required this.onQuantityChanged,
    required this.onZeroQuantity,
  }) : super(key: key);

  @override
  State<DraggableItemDetail> createState() => _DraggableItemDetailState();
}

class _DraggableItemDetailState extends State<DraggableItemDetail> {
  int _quantity = 0;

  @override
  void initState() {
    super.initState();
    _quantity = widget.item.quantity;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.2,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Updated image container to display the full image without cropping
                      Container(
                        width: double.infinity,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            'assets/images/menu_item.jpg',
                            fit: BoxFit.contain, // Changed to contain to show full image
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.item.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        GlobalStyle.formatRupiah(widget.item.price),
                        style: TextStyle(
                          fontSize: 18,
                          color: GlobalStyle.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Deskripsi',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: () {
                              if (_quantity > 0) {
                                setState(() {
                                  _quantity--;
                                });
                              }
                            },
                            icon: const Icon(Icons.remove_circle_outline),
                            color: GlobalStyle.primaryColor,
                          ),
                          Text(
                            '$_quantity',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _quantity++;
                              });
                            },
                            icon: const Icon(Icons.add_circle_outline),
                            color: GlobalStyle.primaryColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                if (_quantity > 0) {
                                  widget.onQuantityChanged(_quantity);
                                  Navigator.pop(context);
                                } else {
                                  // Show zero quantity dialog instead of text warning
                                  Navigator.pop(context); // Close the bottom sheet first
                                  widget.onZeroQuantity(); // Show the dialog
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: GlobalStyle.primaryColor,
                                padding:
                                const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Tambah ke keranjang',
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
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}