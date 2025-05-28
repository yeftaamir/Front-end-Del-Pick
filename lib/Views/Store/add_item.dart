import 'dart:convert';

import 'package:del_pick/Views/Store/home_store.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../Common/global_style.dart';
import '../../Models/item_model.dart';
import '../../Models/menu_item.dart';
import '../Component/bottom_navigation.dart';
import 'add_edit_items.dart';
import 'package:del_pick/Services/core/token_service.dart';
import 'package:del_pick/Services/menu_service.dart';
import 'package:del_pick/Services/image_service.dart';
import 'package:del_pick/Services/auth_service.dart';

class AddItemPage extends StatefulWidget {
  static const String route = '/Store/AddItem';

  const AddItemPage({Key? key}) : super(key: key);

  @override
  State<AddItemPage> createState() => _AddItemPageState();
}

class _AddItemPageState extends State<AddItemPage>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 1;
  late AnimationController _controller;
  final AudioPlayer _audioPlayer = AudioPlayer();

  // State management
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  List<Item> _items = [];

  // Keep track of items being updated
  Set<String> _updatingItems = {};

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    // Fetch items on init
    fetchMenuItems();

    _controller.forward();
  }

  // Fetch menu items from the API
  Future<void> fetchMenuItems() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // Get the current user's profile to determine their role and store
      final userData = await AuthService.getUserData();

      if (userData == null) {
        throw Exception('User data not found. Please login again.');
      }

      // Check if user has a store (most reliable way)
      Map<String, dynamic>? storeData;
      if (userData['store'] != null) {
        storeData = userData['store'];
      }

      if (storeData == null) {
        // Try alternative approach if store isn't in the profile
        final String? rawUserData = await TokenService.getUserData();
        if (rawUserData != null) {
          final Map<String, dynamic> data = json.decode(rawUserData);
          if (data['user'] != null && data['user']['store'] != null) {
            storeData = data['user']['store'];
          }
        }
      }

      if (storeData == null) {
        throw Exception('Store information not found. Please login as a store owner.');
      }

      final String storeId = storeData['id'].toString();

      // Fetch items using the MenuService.getMenuItemsByStoreId method
      final menuItems = await MenuService.getMenuItemsByStoreId(storeId);

      List<Item> items = [];
      // Process items from the response structure
      if (menuItems['menuItems'] != null && menuItems['menuItems'] is List) {
        final List<dynamic> menuItemsList = menuItems['menuItems'];

        for (var menuItemJson in menuItemsList) {
          try {
            // Process image URL using ImageService
            if (menuItemJson['imageUrl'] != null) {
              menuItemJson['imageUrl'] = ImageService.getImageUrl(menuItemJson['imageUrl']);
            }

            // Convert to Item model
            final Item item = Item.fromJson(menuItemJson);
            items.add(item);
          } catch (e) {
            print('Error parsing menu item: $e');
          }
        }
      }

      setState(() {
        _items = items;
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Failed to load menu items: $e';
        _items = []; // Set to empty list if error
      });
      print('Error fetching menu items: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playSound() async {
    await _audioPlayer.play(AssetSource('audio/wrong.mp3'));
  }

  // Navigate to add/edit form and refresh on return
  void _navigateToAddEditForm({Item? item}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditItemForm(item: item),
      ),
    );

    // Refresh the items list regardless of the result
    fetchMenuItems();
  }

  // Toggle item availability status
  Future<void> _toggleItemStatus(Item item) async {
    // Check if this item is already being updated
    if (_updatingItems.contains(item.id)) {
      return;
    }

    if (item.isAvailable) {
      // If item is currently available, show confirmation dialog to close it
      await _showClosingDialog(item);
    } else if (!item.isAvailable && item.quantity > 0) {
      // If item is unavailable but has stock, directly activate it
      await _updateItemStatus(item, true);
    } else {
      // If stock is 0 and trying to activate, show error message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak dapat mengaktifkan produk tanpa stok.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Update item status in the database
  Future<void> _updateItemStatus(Item item, bool isAvailable) async {
    setState(() {
      _updatingItems.add(item.id);
    });

    try {
      final int itemId = int.tryParse(item.id) ?? 0;
      if (itemId > 0) {
        // Create data object for update
        final Map<String, dynamic> itemData = {
          'isAvailable': isAvailable,
          'status': isAvailable ? 'available' : 'out_of_stock',
        };

        // Use MenuService.updateMenuItem method from the updated service
        final updatedItem = await MenuService.updateMenuItem(item.id, itemData);

        if (updatedItem != null) {
          setState(() {
            // Update local state
            final index = _items.indexWhere((element) => element.id == item.id);
            if (index != -1) {
              _items[index] = item.copyWith(
                  isAvailable: isAvailable,
                  status: isAvailable ? 'available' : 'out_of_stock'
              );
            }
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isAvailable
                  ? 'Item berhasil diaktifkan.'
                  : 'Item berhasil dinonaktifkan.'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          throw Exception('Failed to update item status');
        }
      } else {
        throw Exception('Invalid item ID');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating item status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _updatingItems.remove(item.id);
      });
    }
  }

  // Show dialog to confirm closing an item
  Future<void> _showClosingDialog(Item item) async {
    await _playSound();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset(
                'assets/animations/cancel.json',
                width: 150,
                height: 150,
                repeat: true,
                animate: true,
              ),
              const SizedBox(height: 20),
              Text(
                'Nonaktifkan ${item.name}?',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Item yang dinonaktifkan tidak akan terlihat oleh pelanggan.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      backgroundColor: Colors.grey.shade200,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text(
                      'Batal',
                      style: TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text(
                      'Nonaktifkan',
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
      ),
    );

    if (result == true) {
      await _updateItemStatus(item, false);
    }
  }

  // Show dialog to confirm deleting an item
  void _showDeleteConfirmation(Item item) async {
    await _playSound();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset(
                'assets/animations/trash.json',
                width: 150,
                height: 150,
                repeat: true,
                animate: true,
              ),
              const SizedBox(height: 20),
              Text(
                'Hapus ${item.name}?',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Item yang dihapus tidak dapat dikembalikan.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      backgroundColor: Colors.grey.shade200,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text(
                      'Batal',
                      style: TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _deleteItem(item);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text(
                      'Hapus',
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
      ),
    );
  }

  // Delete item via API
  Future<void> _deleteItem(Item item) async {
    setState(() {
      _updatingItems.add(item.id);
    });

    try {
      final int itemId = int.tryParse(item.id) ?? 0;

      if (itemId > 0) {
        // Use MenuService.deleteMenuItem method from the updated service
        final success = await MenuService.deleteMenuItem(item.id);

        if (success) {
          setState(() {
            // Remove from local list
            _items.removeWhere((element) => element.id == item.id);
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Item berhasil dihapus.'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          throw Exception('Failed to delete item');
        }
      } else {
        throw Exception('Invalid item ID');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting item: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _updatingItems.remove(item.id);
      });
    }
  }

  // Helper for color opacity
  Color _getColorWithOpacity(Color color, double opacity) {
    return Color.fromRGBO(
      color.red,
      color.green,
      color.blue,
      opacity,
    );
  }

  // Format status for display
  String formatStatus(String status) {
    // Convert backend status to display format
    switch (status.toLowerCase()) {
      case 'available':
        return 'Available';
      case 'out_of_stock':
        return 'Out of Stock';
      case 'limited':
        return 'Limited';
      default:
        return status;
    }
  }

  // Widget for displaying error state
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 64),
          const SizedBox(height: 16),
          Text(
            'Failed to load items',
            style: TextStyle(
              color: GlobalStyle.fontColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage,
              style: TextStyle(
                color: GlobalStyle.fontColor.withOpacity(0.7),
                fontSize: 14,
                fontFamily: GlobalStyle.fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: fetchMenuItems,
            style: ElevatedButton.styleFrom(
              backgroundColor: GlobalStyle.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              'Coba Lagi',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontFamily: GlobalStyle.fontFamily,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget for displaying empty state
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/animations/empty.json',
            width: 250,
            height: 250,
            repeat: true,
            animate: true,
          ),
          const SizedBox(height: 20),
          const Text(
            'Belum ada item',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Tambahkan item baru dengan menekan tombol + di atas',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _navigateToAddEditForm(),
            icon: const Icon(Icons.add),
            label: const Text('Tambah Item Sekarang'),
            style: ElevatedButton.styleFrom(
              backgroundColor: GlobalStyle.primaryColor,
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget for displaying loading state
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: GlobalStyle.primaryColor),
          const SizedBox(height: 20),
          const Text(
            'Memuat item...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffD6E6F2),
      appBar: AppBar(
        title: const Text(
          'Tambah Item',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(4.0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: GlobalStyle.primaryColor, width: 1.0),
            ),
            child: Icon(Icons.arrow_back_ios_new,
                color: GlobalStyle.primaryColor, size: 18),
          ),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const HomeStore(),
              ),
            );
          },
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: GlobalStyle.primaryColor),
            onPressed: fetchMenuItems,
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              onPressed: () => _navigateToAddEditForm(),
              icon: const Icon(Icons.add),
              label: const Text('Tambah Item'),
              style: ElevatedButton.styleFrom(
                backgroundColor: GlobalStyle.primaryColor,
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _hasError
          ? _buildErrorState()
          : _items.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
        onRefresh: fetchMenuItems,
        color: GlobalStyle.primaryColor,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _items.length,
          itemBuilder: (context, index) {
            final item = _items[index];
            final bool isOutOfStock = item.quantity <= 0;
            final bool isUpdating = _updatingItems.contains(item.id);

            return AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(1, 0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: _controller,
                    curve: Interval(
                      index * 0.1,
                      1.0,
                      curve: Curves.easeOut,
                    ),
                  )),
                  child: child!,
                );
              },
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: _getColorWithOpacity(Colors.grey, 0.1),
                        spreadRadius: 1,
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Opacity(
                        opacity: item.isAvailable ? 1.0 : 0.5,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(15),
                          onTap: () => _navigateToAddEditForm(item: item),
                          child: Row(
                            children: [
                              // Item image
                              ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(15),
                                  bottomLeft: Radius.circular(15),
                                ),
                                child: ImageService.displayImage(
                                  imageSource: item.imageUrl,
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.cover,
                                  placeholder: Container(
                                    width: 120,
                                    height: 120,
                                    color: Colors.grey[300],
                                    child: Icon(Icons.image, color: Colors.grey),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        item.formatPrice(),
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: GlobalStyle.primaryColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.inventory_2_outlined,
                                            size: 16,
                                            color: isOutOfStock
                                                ? Colors.red
                                                : Colors.grey,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Stok: ${item.quantity}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: isOutOfStock
                                                  ? Colors.red
                                                  : GlobalStyle.fontColor,
                                              fontWeight: isOutOfStock
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: item.isAvailable
                                              ? _getColorWithOpacity(
                                              Colors.green, 0.1)
                                              : _getColorWithOpacity(
                                              Colors.red, 0.1),
                                          borderRadius:
                                          BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              item.isAvailable
                                                  ? Icons.check_circle
                                                  : Icons.cancel,
                                              size: 16,
                                              color: item.isAvailable
                                                  ? Colors.green
                                                  : Colors.red,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              formatStatus(item.status),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: item.isAvailable
                                                    ? Colors.green
                                                    : Colors.red,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (item.description != null &&
                                          item.description!.isNotEmpty)
                                        Padding(
                                          padding:
                                          const EdgeInsets.only(top: 8),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.description_outlined,
                                                size: 16,
                                                color: Colors.grey[600],
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  item.description!,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                  TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12.0, vertical: 8.0),
                                child: Column(
                                  mainAxisAlignment:
                                  MainAxisAlignment.spaceEvenly,
                                  children: [
                                    // Toggle Button
                                    Container(
                                      width: 75,
                                      height: 35,
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 5),
                                      decoration: BoxDecoration(
                                        borderRadius:
                                        BorderRadius.circular(18),
                                        gradient: LinearGradient(
                                          colors: item.isAvailable
                                              ? [
                                            const Color(0xFF43A047),
                                            const Color(0xFF66BB6A)
                                          ]
                                              : [
                                            Colors.grey.shade400,
                                            Colors.grey.shade300
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: item.isAvailable
                                                ? Colors.green
                                                .withOpacity(0.3)
                                                : Colors.grey
                                                .withOpacity(0.3),
                                            spreadRadius: 1,
                                            blurRadius: 3,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius:
                                          BorderRadius.circular(18),
                                          onTap: isUpdating
                                              ? null
                                              : () => _toggleItemStatus(item),
                                          child: Center(
                                            child: isUpdating
                                                ? SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(
                                                    Colors.white
                                                ),
                                              ),
                                            )
                                                : Row(
                                              mainAxisAlignment:
                                              MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  item.isAvailable
                                                      ? Icons.visibility
                                                      : Icons
                                                      .visibility_off,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  item.isAvailable
                                                      ? 'BUKA'
                                                      : 'TUTUP',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight:
                                                    FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Edit Button
                                    Container(
                                      width: 75,
                                      height: 35,
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 5),
                                      decoration: BoxDecoration(
                                        borderRadius:
                                        BorderRadius.circular(18),
                                        gradient: LinearGradient(
                                          colors: [
                                            GlobalStyle.primaryColor,
                                            GlobalStyle.primaryColor
                                                .withOpacity(0.8)
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: GlobalStyle.primaryColor
                                                .withOpacity(0.3),
                                            spreadRadius: 1,
                                            blurRadius: 3,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius:
                                          BorderRadius.circular(18),
                                          onTap: () =>
                                              _navigateToAddEditForm(
                                                  item: item),
                                          child: Row(
                                            mainAxisAlignment:
                                            MainAxisAlignment.center,
                                            children: const [
                                              Icon(
                                                Icons.edit,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                'EDIT',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight:
                                                  FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Delete Button
                                    Container(
                                      width: 75,
                                      height: 35,
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 5),
                                      decoration: BoxDecoration(
                                        borderRadius:
                                        BorderRadius.circular(18),
                                        gradient: const LinearGradient(
                                          colors: [
                                            Colors.red,
                                            Color(0xFFF44336)
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                            Colors.red.withOpacity(0.3),
                                            spreadRadius: 1,
                                            blurRadius: 3,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius:
                                          BorderRadius.circular(18),
                                          onTap: isUpdating
                                              ? null
                                              : () => _showDeleteConfirmation(item),
                                          child: Center(
                                            child: isUpdating
                                                ? SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(
                                                    Colors.white
                                                ),
                                              ),
                                            )
                                                : Row(
                                              mainAxisAlignment:
                                              MainAxisAlignment.center,
                                              children: const [
                                                Icon(
                                                  Icons.delete,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  'HAPUS',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight:
                                                    FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (!item.isAvailable)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getColorWithOpacity(Colors.red, 0.9),
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(15),
                                bottomLeft: Radius.circular(15),
                              ),
                            ),
                            child: Text(
                              isOutOfStock ? 'STOK HABIS' : 'TUTUP',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: BottomNavigationComponent(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);

          if (index == 0) {
            Navigator.pushReplacementNamed(context, HomeStore.route);
          }
        },
      ),
    );
  }
}