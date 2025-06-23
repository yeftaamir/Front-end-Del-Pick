import 'dart:convert';

import 'package:del_pick/Views/Store/home_store.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../Common/global_style.dart';
import '../../Models/order_review.dart';
import '../../Models/menu_item.dart';
import '../Component/bottom_navigation.dart';
import 'add_edit_items.dart';
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
  List<MenuItemModel> _menuItems = [];

  // Store ID
  String? _storeId;

  // Keep track of items being updated
  Set<String> _updatingItems = {};

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    // Initialize store ID and fetch items
    _initializeAndFetchItems();

    _controller.forward();
  }

  // Initialize store ID and fetch menu items
  Future<void> _initializeAndFetchItems() async {
    try {
      // Get store ID from user data first
      await _getStoreId();

      if (_storeId != null) {
        await _fetchMenuItems();
      } else {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Store information not found. Please login as a store owner.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Failed to initialize: $e';
      });
    }
  }

  // Get store ID from user data
  Future<void> _getStoreId() async {
    try {
      final userData = await AuthService.getUserData();

      if (userData != null) {
        // Try to get store ID from different possible locations in user data
        if (userData['store'] != null && userData['store']['id'] != null) {
          _storeId = userData['store']['id'].toString();
        } else if (userData['user'] != null && userData['user']['store'] != null) {
          _storeId = userData['user']['store']['id'].toString();
        }
      }

      if (_storeId == null) {
        // Try alternative approach with profile
        final profile = await AuthService.getProfile();
        if (profile != null && profile['store'] != null) {
          _storeId = profile['store']['id'].toString();
        }
      }
    } catch (e) {
      print('Error getting store ID: $e');
      throw Exception('Failed to get store information: $e');
    }
  }

  // Fetch menu items from the API using MenuItemService
  Future<void> _fetchMenuItems() async {
    if (_storeId == null) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Store ID not found';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // Use MenuItemService.getMenuItemsByStore method
      final response = await MenuItemService.getMenuItemsByStore(
        storeId: _storeId!,
        page: 1,
        limit: 100, // Get all items
        isAvailable: null, // Get both available and unavailable items
        sortBy: 'created_at',
        sortOrder: 'desc',
      );

      List<MenuItemModel> menuItems = [];

      // Process the response based on the service structure
      if (response['data'] != null && response['data'] is List) {
        final List<dynamic> menuItemsList = response['data'];

        for (var menuItemJson in menuItemsList) {
          try {
            // Convert to MenuItemModel using the model's fromJson method
            final MenuItemModel menuItem = MenuItemModel.fromJson(menuItemJson);
            menuItems.add(menuItem);
          } catch (e) {
            print('Error parsing menu item: $e');
          }
        }
      }

      setState(() {
        _menuItems = menuItems;
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Failed to load menu items: $e';
        _menuItems = []; // Set to empty list if error
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
    try {
      await _audioPlayer.play(AssetSource('audio/wrong.mp3'));
    } catch (e) {
      print('Error playing sound: $e');
    }
  }

  // Navigate to add/edit form and refresh on return
  void _navigateToAddEditForm({MenuItemModel? menuItem}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditItemForm(menuItem: menuItem),
      ),
    );

    // Refresh the items list regardless of the result
    await _fetchMenuItems();
  }

  // Toggle item availability status
  Future<void> _toggleItemStatus(MenuItemModel menuItem) async {
    // Check if this item is already being updated
    if (_updatingItems.contains(menuItem.id.toString())) {
      return;
    }

    if (menuItem.isAvailable) {
      // If item is currently available, show confirmation dialog to make it unavailable
      await _showClosingDialog(menuItem);
    } else {
      // If item is unavailable, directly make it available
      await _updateItemStatus(menuItem, true);
    }
  }

  // Update item status using MenuItemService.updateMenuItemStatus
  Future<void> _updateItemStatus(MenuItemModel menuItem, bool isAvailable) async {
    setState(() {
      _updatingItems.add(menuItem.id.toString());
    });

    try {
      final String status = isAvailable ? 'available' : 'unavailable';

      // Use MenuItemService.updateMenuItemStatus method
      final updatedItem = await MenuItemService.updateMenuItemStatus(
        menuItemId: menuItem.id.toString(),
        status: status,
      );

      if (updatedItem.isNotEmpty) {
        setState(() {
          // Update local state
          final index = _menuItems.indexWhere((element) => element.id == menuItem.id);
          if (index != -1) {
            _menuItems[index] = menuItem.copyWith(isAvailable: isAvailable);
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
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating item status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _updatingItems.remove(menuItem.id.toString());
      });
    }
  }

  // Show dialog to confirm making item unavailable
  Future<void> _showClosingDialog(MenuItemModel menuItem) async {
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
                'Nonaktifkan ${menuItem.name}?',
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
      await _updateItemStatus(menuItem, false);
    }
  }

  // Show dialog to confirm deleting an item
  void _showDeleteConfirmation(MenuItemModel menuItem) async {
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
                'Hapus ${menuItem.name}?',
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
                      await _deleteItem(menuItem);
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

  // Delete item using MenuItemService.deleteMenuItem
  Future<void> _deleteItem(MenuItemModel menuItem) async {
    setState(() {
      _updatingItems.add(menuItem.id.toString());
    });

    try {
      // Use MenuItemService.deleteMenuItem method
      final success = await MenuItemService.deleteMenuItem(menuItem.id.toString());

      if (success) {
        setState(() {
          // Remove from local list
          _menuItems.removeWhere((element) => element.id == menuItem.id);
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
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting item: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _updatingItems.remove(menuItem.id.toString());
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
  String formatStatus(bool isAvailable) {
    return isAvailable ? 'Available' : 'Unavailable';
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
            onPressed: _initializeAndFetchItems,
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
            onPressed: _fetchMenuItems,
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
          : _menuItems.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
        onRefresh: _fetchMenuItems,
        color: GlobalStyle.primaryColor,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _menuItems.length,
          itemBuilder: (context, index) {
            final menuItem = _menuItems[index];
            final bool isUpdating = _updatingItems.contains(menuItem.id.toString());

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
                        opacity: menuItem.isAvailable ? 1.0 : 0.5,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(15),
                          onTap: () => _navigateToAddEditForm(menuItem: menuItem),
                          child: Row(
                            children: [
                              // Item image
                              ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(15),
                                  bottomLeft: Radius.circular(15),
                                ),
                                child: menuItem.hasImage
                                    ? ImageService.displayImage(
                                  imageSource: menuItem.imageUrl!,
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.cover,
                                  placeholder: Container(
                                    width: 120,
                                    height: 120,
                                    color: Colors.grey[300],
                                    child: Icon(Icons.image, color: Colors.grey),
                                  ),
                                )
                                    : Container(
                                  width: 120,
                                  height: 120,
                                  color: Colors.grey[300],
                                  child: Icon(Icons.image, color: Colors.grey),
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
                                        menuItem.name,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        menuItem.formatPrice(),
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
                                            Icons.category_outlined,
                                            size: 16,
                                            color: Colors.grey,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Kategori: ${menuItem.category}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: GlobalStyle.fontColor,
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
                                          color: menuItem.isAvailable
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
                                              menuItem.isAvailable
                                                  ? Icons.check_circle
                                                  : Icons.cancel,
                                              size: 16,
                                              color: menuItem.isAvailable
                                                  ? Colors.green
                                                  : Colors.red,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              formatStatus(menuItem.isAvailable),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: menuItem.isAvailable
                                                    ? Colors.green
                                                    : Colors.red,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (menuItem.description.isNotEmpty)
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
                                                  menuItem.description,
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
                                          colors: menuItem.isAvailable
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
                                            color: menuItem.isAvailable
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
                                              : () => _toggleItemStatus(menuItem),
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
                                                  menuItem.isAvailable
                                                      ? Icons.visibility
                                                      : Icons
                                                      .visibility_off,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  menuItem.isAvailable
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
                                                  menuItem: menuItem),
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
                                              : () => _showDeleteConfirmation(menuItem),
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
                      if (!menuItem.isAvailable)
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
                              'TUTUP',
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