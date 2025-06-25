import 'dart:convert';

import 'package:del_pick/Views/Store/home_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:lottie/lottie.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../Common/global_style.dart';
import '../../Models/order_review.dart';
import '../../Models/menu_item.dart';
import '../../Services/parsing_diagnostics.dart';
import '../Component/bottom_navigation.dart';
import 'add_edit_items.dart';
import 'package:del_pick/Services/menu_service.dart';
import 'package:del_pick/Services/image_service.dart';
import 'package:del_pick/Services/auth_service.dart';
import 'package:del_pick/Services/store_data_helper.dart';

class AddItemPage extends StatefulWidget {
  static const String route = '/Store/AddItem';

  const AddItemPage({Key? key}) : super(key: key);

  @override
  State<AddItemPage> createState() => _AddItemPageState();
}

class _AddItemPageState extends State<AddItemPage>
    with TickerProviderStateMixin {
  int _currentIndex = 1;
  late AnimationController _controller;
  late AnimationController _refreshController;
  late AnimationController _itemAddedController;
  late AnimationController _itemDeletedController;
  final AudioPlayer _audioPlayer = AudioPlayer();

  // State management
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  List<MenuItemModel> _menuItems = [];

  // Store information
  String? _storeId;
  Map<String, dynamic>? _storeInfo;

  // Keep track of items being updated
  Set<String> _updatingItems = {};

  // Animation for newly added items
  String? _newlyAddedItemId;
  String? _deletingItemId;

  // Flag to track if we're coming from add/edit form
  bool _isRefreshingAfterEdit = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _refreshController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _itemAddedController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _itemDeletedController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Initialize store ID and fetch items
    _initializeAndFetchItems();

    _controller.forward();
  }

  // Initialize store ID and fetch menu items
  Future<void> _initializeAndFetchItems() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      // Get store information from login data
      await _getStoreFromLoginData();

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
      print('❌ Error initializing: $e');
    }
  }

  // Simplified store ID retrieval from login data
  Future<void> _getStoreFromLoginData() async {
    try {
      print('🔍 AddItem: Getting store data from AuthService...');

      // First, verify user role
      final userRole = await AuthService.getUserRole();
      print('📋 AddItem: Current user role: $userRole');

      if (userRole?.toLowerCase() != 'store') {
        throw Exception('Access denied: User is not a store owner. Current role: $userRole');
      }

      // Get role-specific data (primary method for store owners)
      final roleSpecificData = await AuthService.getRoleSpecificData();
      if (roleSpecificData != null) {
        final storeData = _extractStoreData(roleSpecificData);
        if (storeData != null) {
          _storeId = storeData['id']?.toString();
          _storeInfo = storeData;
          print('✅ AddItem: Store ID found: $_storeId');
          return;
        }
      }

      // Fallback: Try getUserData if role-specific data doesn't contain store info
      final userData = await AuthService.getUserData();
      if (userData != null) {
        final storeData = _extractStoreData(userData);
        if (storeData != null) {
          _storeId = storeData['id']?.toString();
          _storeInfo = storeData;
          print('✅ AddItem: Store ID found from user data: $_storeId');
          return;
        }
      }

      // Final attempt: Refresh user data
      final refreshedData = await AuthService.refreshUserData();
      if (refreshedData != null) {
        final storeData = _extractStoreData(refreshedData);
        if (storeData != null) {
          _storeId = storeData['id']?.toString();
          _storeInfo = storeData;
          print('✅ AddItem: Store ID found from refreshed data: $_storeId');
          return;
        }
      }

      throw Exception('Store information not found in authentication data');

    } catch (e) {
      print('❌ AddItem: Error getting store from login data: $e');
      throw Exception('Failed to get store information: $e');
    }
  }

  // Simplified store data extraction helper
  Map<String, dynamic>? _extractStoreData(Map<String, dynamic> data) {
    try {
      // Check direct store property
      if (data['store'] != null && data['store'] is Map<String, dynamic>) {
        return Map<String, dynamic>.from(data['store']);
      }

      // Check nested under user
      if (data['user'] != null &&
          data['user'] is Map<String, dynamic> &&
          data['user']['store'] != null) {
        return Map<String, dynamic>.from(data['user']['store']);
      }

      // Check nested under data
      if (data['data'] != null &&
          data['data'] is Map<String, dynamic> &&
          data['data']['store'] != null) {
        return Map<String, dynamic>.from(data['data']['store']);
      }

      return null;
    } catch (e) {
      print('❌ Error extracting store data: $e');
      return null;
    }
  }

  // Improved fetch menu items method
  Future<void> _fetchMenuItems({bool showLoadingAnimation = false, bool isAfterEdit = false}) async {
    if (_storeId == null) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Store ID not available';
      });
      return;
    }

    if (showLoadingAnimation) {
      _refreshController.repeat();
    } else if (!isAfterEdit) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    try {
      print('🔍 AddItem: Starting to fetch menu items for store $_storeId');

      // Validate authentication first
      final isAuthenticated = await AuthService.isAuthenticated();
      if (!isAuthenticated) {
        throw Exception('User not authenticated');
      }

      // Store previous items to detect new additions
      final List<MenuItemModel> previousItems = List.from(_menuItems);
      final int previousCount = previousItems.length;

      // Use the service call with cache busting
      final menuResponse = await MenuItemService.getMenuItemsByStore(
        storeId: _storeId!,
        page: 1,
        limit: 100,
        isAvailable: null,
        sortBy: 'created_at',
        sortOrder: 'desc',
        bustCache: isAfterEdit,
      );

      // Check if response indicates success
      if (menuResponse['success'] == false) {
        throw Exception(menuResponse['error'] ?? 'Failed to load menu items');
      }

      // Extract menu items from response
      List<MenuItemModel> fetchedMenuItems = [];

      if (menuResponse['data'] != null && menuResponse['data'] is List) {
        final menuItemsData = menuResponse['data'] as List;

        for (var itemData in menuItemsData) {
          try {
            if (itemData is Map<String, dynamic>) {
              final menuItem = MenuItemModel.fromJson(itemData);
              fetchedMenuItems.add(menuItem);
            }
          } catch (e) {
            print('❌ AddItem: Error parsing menu item: $e');
            // Continue with other items instead of failing completely
          }
        }
      }

      // Enhanced detection for newly added items
      String? detectedNewItemId;
      if (isAfterEdit) {
        if (fetchedMenuItems.length > previousCount) {
          // Look for items that weren't in the previous list
          for (var newItem in fetchedMenuItems) {
            bool isNewItem = !previousItems.any((oldItem) => oldItem.id == newItem.id);
            if (isNewItem) {
              detectedNewItemId = newItem.id.toString();
              print('🆕 AddItem: Detected new item: ${newItem.name}');
              break;
            }
          }
        }
      }

      // Trigger animation for newly added items
      if (detectedNewItemId != null) {
        _newlyAddedItemId = detectedNewItemId;
        _playSuccessSound();
        _itemAddedController.forward().then((_) {
          Future.delayed(const Duration(seconds: 4), () {
            if (mounted) {
              setState(() {
                _newlyAddedItemId = null;
              });
              _itemAddedController.reset();
            }
          });
        });
      }

      setState(() {
        _menuItems = fetchedMenuItems;
        _isLoading = false;
        _hasError = false;
        _isRefreshingAfterEdit = false;
      });

      print('✅ AddItem: Successfully loaded ${fetchedMenuItems.length} menu items');

      // Show appropriate success message
      if (showLoadingAnimation && mounted) {
        _showSnackBar(
          'Data berhasil di-refresh! (${fetchedMenuItems.length} items)',
          Colors.green,
          Icons.refresh,
        );
      } else if (isAfterEdit && mounted) {
        if (detectedNewItemId != null) {
          _showSnackBar(
            'Item baru berhasil dimuat!',
            Colors.green,
            Icons.check_circle,
          );
        } else {
          _showSnackBar(
            'Data telah diperbarui! (${fetchedMenuItems.length} items)',
            Colors.blue,
            Icons.check_circle,
          );
        }
      }

    } catch (e) {
      print('❌ AddItem: Error fetching menu items: $e');
      setState(() {
        _errorMessage = 'Failed to load menu items: $e';
        _isLoading = false;
        _hasError = true;
        _isRefreshingAfterEdit = false;
        if (_menuItems.isEmpty) {
          _menuItems = [];
        }
      });

      if (mounted) {
        _showSnackBar(
          'Error loading items: ${e.toString()}',
          Colors.red,
          Icons.error,
        );
      }
    } finally {
      if (showLoadingAnimation) {
        _refreshController.stop();
        _refreshController.reset();
      }
    }
  }

  void _showSnackBar(String message, Color color, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: color == Colors.red ? 4 : 2),
      ),
    );
  }

  Future<void> _playSuccessSound() async {
    try {
      await _audioPlayer.play(AssetSource('audio/alert.wav'));
    } catch (e) {
      print('Error playing sound: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _refreshController.dispose();
    _itemAddedController.dispose();
    _itemDeletedController.dispose();
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
    print('🚀 AddItem: Navigating to AddEditForm...');

    setState(() {
      _isRefreshingAfterEdit = true;
    });

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditItemForm(menuItem: menuItem),
      ),
    );

    // Handle different types of results
    if (mounted) {
      await Future.delayed(const Duration(milliseconds: 200));

      if (result is Map<String, dynamic>) {
        final status = result['status'];
        final itemData = result['data'];
        final action = result['action'] ?? 'unknown';

        if (status == 'success' && itemData != null) {
          if (action == 'created') {
            await _handleNewItemCreated(itemData);
          } else if (action == 'updated') {
            await _handleItemUpdated(itemData, menuItem);
          } else if (action == 'deleted') {
            await _handleItemDeleted(menuItem);
          }

          _fetchMenuItems(isAfterEdit: true);

        } else {
          await _fetchMenuItems(showLoadingAnimation: true, isAfterEdit: true);
        }

      } else if (result == 'success') {
        await _fetchMenuItems(showLoadingAnimation: true, isAfterEdit: true);
        _showSnackBar(
          menuItem == null ? 'Item berhasil ditambahkan!' : 'Item berhasil diperbarui!',
          Colors.green,
          Icons.check_circle,
        );
      } else if (result == 'deleted') {
        if (menuItem != null) {
          await _handleItemDeleted(menuItem);
        }
        await _fetchMenuItems(showLoadingAnimation: true, isAfterEdit: true);
        _showSnackBar(
          'Item berhasil dihapus!',
          Colors.green,
          Icons.check_circle,
        );
      } else {
        await _fetchMenuItems(isAfterEdit: true);
      }
    }
  }

  // Handle new item created - add directly to list
  Future<void> _handleNewItemCreated(Map<String, dynamic> itemData) async {
    try {
      if (itemData['id'] == null || itemData['name'] == null || itemData['price'] == null) {
        throw Exception('Missing required fields in response data');
      }

      final newMenuItem = MenuItemModel.fromJson(itemData);

      setState(() {
        _menuItems.insert(0, newMenuItem);
        _newlyAddedItemId = newMenuItem.id.toString();
      });

      _playSuccessSound();
      _itemAddedController.forward().then((_) {
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) {
            setState(() {
              _newlyAddedItemId = null;
            });
            _itemAddedController.reset();
          }
        });
      });

      _showSnackBar(
        'Item "${newMenuItem.name}" berhasil ditambahkan!',
        Colors.green,
        Icons.check_circle,
      );

    } catch (e) {
      print('❌ AddItem: Error adding new item directly: $e');
      _showSnackBar(
        'Item berhasil ditambahkan! Memuat ulang data...',
        Colors.blue,
        Icons.refresh,
      );
      await _fetchMenuItems(showLoadingAnimation: true, isAfterEdit: true);
    }
  }

  // Handle item updated - update existing item in list
  Future<void> _handleItemUpdated(Map<String, dynamic> itemData, MenuItemModel? originalItem) async {
    try {
      if (originalItem == null) return;

      final updatedMenuItem = MenuItemModel.fromJson(itemData);

      setState(() {
        final index = _menuItems.indexWhere((item) => item.id == updatedMenuItem.id);
        if (index != -1) {
          _menuItems[index] = updatedMenuItem;
        }
      });

      _showSnackBar(
        'Item "${updatedMenuItem.name}" berhasil diperbarui!',
        Colors.blue,
        Icons.edit,
      );

    } catch (e) {
      print('❌ AddItem: Error updating item directly: $e');
      _showSnackBar(
        'Item berhasil diperbarui! Memuat ulang data...',
        Colors.blue,
        Icons.refresh,
      );
    }
  }

  // Handle item deleted - remove from list with animation
  Future<void> _handleItemDeleted(MenuItemModel? deletedItem) async {
    try {
      if (deletedItem == null) return;

      // Start delete animation
      setState(() {
        _deletingItemId = deletedItem.id.toString();
      });

      // Wait for animation to complete
      await _itemDeletedController.forward();

      // Remove from list
      setState(() {
        _menuItems.removeWhere((item) => item.id == deletedItem.id);
        _deletingItemId = null;
      });

      _itemDeletedController.reset();

      _showSnackBar(
        'Item "${deletedItem.name}" berhasil dihapus!',
        Colors.green,
        Icons.delete,
      );

    } catch (e) {
      print('❌ AddItem: Error removing item directly: $e');
    }
  }

  // Refresh items manually
  Future<void> _refreshItems() async {
    try {
      await _getStoreFromLoginData();
      await _fetchMenuItems(showLoadingAnimation: true);
    } catch (e) {
      _showSnackBar(
        'Refresh failed: $e',
        Colors.red,
        Icons.error,
      );
    }
  }

  // Refresh items from pull-to-refresh
  Future<void> _pullToRefresh() async {
    await _getStoreFromLoginData();
    await _fetchMenuItems();
  }

  // Toggle item availability status
  Future<void> _toggleItemStatus(MenuItemModel menuItem) async {
    if (_updatingItems.contains(menuItem.id.toString())) {
      return;
    }

    if (menuItem.isAvailable) {
      await _showClosingDialog(menuItem);
    } else {
      await _updateItemStatus(menuItem, true);
    }
  }

  // Update item status using improved MenuItemService
  Future<void> _updateItemStatus(MenuItemModel menuItem, bool isAvailable) async {
    setState(() {
      _updatingItems.add(menuItem.id.toString());
    });

    try {
      final String status = isAvailable ? 'available' : 'unavailable';

      final response = await MenuItemService.updateMenuItemStatus(
        menuItemId: menuItem.id.toString(),
        status: status,
      );

      if (response['success']) {
        setState(() {
          final index = _menuItems.indexWhere((element) => element.id == menuItem.id);
          if (index != -1) {
            _menuItems[index] = menuItem.copyWith(isAvailable: isAvailable);
          }
        });

        _showSnackBar(
          isAvailable ? 'Item berhasil diaktifkan.' : 'Item berhasil dinonaktifkan.',
          Colors.green,
          Icons.check_circle,
        );

        await _fetchMenuItems();
      } else {
        throw Exception(response['error'] ?? 'Failed to update item status');
      }
    } catch (e) {
      _showSnackBar(
        'Error updating item status: $e',
        Colors.red,
        Icons.error,
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
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      backgroundColor: Colors.grey.shade200,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
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
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
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
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      backgroundColor: Colors.grey.shade200,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
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
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
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

  // Delete item with animation
  Future<void> _deleteItem(MenuItemModel menuItem) async {
    setState(() {
      _updatingItems.add(menuItem.id.toString());
      _deletingItemId = menuItem.id.toString();
    });

    try {
      final success = await MenuItemService.deleteMenuItem(menuItem.id.toString());

      if (success) {
        // Start delete animation
        await _itemDeletedController.forward();

        setState(() {
          _menuItems.removeWhere((element) => element.id == menuItem.id);
          _deletingItemId = null;
        });

        _itemDeletedController.reset();

        _showSnackBar(
          'Item berhasil dihapus.',
          Colors.green,
          Icons.check_circle,
        );

        await _fetchMenuItems();
      } else {
        throw Exception('Failed to delete item');
      }
    } catch (e) {
      setState(() {
        _deletingItemId = null;
      });
      _itemDeletedController.reset();

      _showSnackBar(
        'Error deleting item: $e',
        Colors.red,
        Icons.error,
      );
    } finally {
      setState(() {
        _updatingItems.remove(menuItem.id.toString());
      });
    }
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
          Text(
            _isRefreshingAfterEdit ? 'Memperbarui data...' : 'Memuat data store...',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // Build enhanced menu item card
  Widget _buildEnhancedMenuItemCard(MenuItemModel menuItem, int index) {
    final bool isUpdating = _updatingItems.contains(menuItem.id.toString());
    final bool isNewlyAdded = _newlyAddedItemId == menuItem.id.toString();
    final bool isDeleting = _deletingItemId == menuItem.id.toString();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        Widget itemCard = SlideTransition(
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

        // Delete animation
        if (isDeleting) {
          return AnimatedBuilder(
            animation: _itemDeletedController,
            builder: (context, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: Offset.zero,
                  end: const Offset(-1, 0),
                ).animate(CurvedAnimation(
                  parent: _itemDeletedController,
                  curve: Curves.easeInOut,
                )),
                child: FadeTransition(
                  opacity: Tween<double>(
                    begin: 1.0,
                    end: 0.0,
                  ).animate(CurvedAnimation(
                    parent: _itemDeletedController,
                    curve: Curves.easeInOut,
                  )),
                  child: child!,
                ),
              );
            },
            child: itemCard,
          );
        }

        // New item animation
        if (isNewlyAdded) {
          return AnimatedBuilder(
            animation: _itemAddedController,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + (0.1 * Curves.elasticOut.transform(_itemAddedController.value)),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: GlobalStyle.primaryColor.withOpacity(
                            0.4 * _itemAddedController.value),
                        blurRadius: 20 * _itemAddedController.value,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: child!,
                ),
              );
            },
            child: itemCard,
          );
        }

        return itemCard;
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.grey.shade50,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                spreadRadius: 1,
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                spreadRadius: 1,
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Opacity(
                  opacity: menuItem.isAvailable ? 1.0 : 0.6,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _navigateToAddEditForm(menuItem: menuItem),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Enhanced image section
                        Container(
                          height: 160,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.grey.shade300,
                                Colors.grey.shade200,
                              ],
                            ),
                          ),
                          child: Stack(
                            children: [
                              // Image
                              Positioned.fill(
                                child: menuItem.hasImage
                                    ? ImageService.displayImage(
                                  imageSource: menuItem.imageUrl!,
                                  width: double.infinity,
                                  height: 160,
                                  fit: BoxFit.cover,
                                  placeholder: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.grey.shade300,
                                          Colors.grey.shade200,
                                        ],
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.image,
                                      color: Colors.grey.shade400,
                                      size: 48,
                                    ),
                                  ),
                                )
                                    : Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        GlobalStyle.primaryColor.withOpacity(0.1),
                                        GlobalStyle.primaryColor.withOpacity(0.05),
                                      ],
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.restaurant,
                                    color: GlobalStyle.primaryColor.withOpacity(0.5),
                                    size: 48,
                                  ),
                                ),
                              ),
                              // Gradient overlay
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withOpacity(0.1),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // Status indicator
                              if (!menuItem.isAvailable)
                                Positioned(
                                  top: 12,
                                  right: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.red.withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.visibility_off, color: Colors.white, size: 14),
                                        const SizedBox(width: 4),
                                        Text(
                                          'TUTUP',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              // New item indicator
                              if (isNewlyAdded)
                                Positioned(
                                  top: 12,
                                  left: 12,
                                  child: AnimatedBuilder(
                                    animation: _itemAddedController,
                                    builder: (context, child) {
                                      return Transform.scale(
                                        scale: 1.0 + (0.2 * _itemAddedController.value),
                                        child: Opacity(
                                          opacity: _itemAddedController.value,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.green,
                                                  Colors.green.shade400,
                                                ],
                                              ),
                                              borderRadius: BorderRadius.circular(20),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.green.withOpacity(0.4),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 3),
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.stars, color: Colors.white, size: 14),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'BARU',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
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
                            ],
                          ),
                        ),
                        // Enhanced content section
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title and price row
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          menuItem.name,
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                GlobalStyle.primaryColor,
                                                GlobalStyle.primaryColor.withOpacity(0.8),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(15),
                                          ),
                                          child: Text(
                                            menuItem.formatPrice(),
                                            style: const TextStyle(
                                              fontSize: 16,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Status badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: menuItem.isAvailable
                                          ? Colors.green.withOpacity(0.1)
                                          : Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(15),
                                      border: Border.all(
                                        color: menuItem.isAvailable
                                            ? Colors.green.withOpacity(0.3)
                                            : Colors.red.withOpacity(0.3),
                                      ),
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
                                        const SizedBox(width: 6),
                                        Text(
                                          formatStatus(menuItem.isAvailable),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: menuItem.isAvailable
                                                ? Colors.green
                                                : Colors.red,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Category info
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.category_outlined,
                                      size: 16,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      menuItem.category,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Description
                              if (menuItem.description.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(
                                  menuItem.description,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                    height: 1.4,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: 20),
                              // Enhanced action buttons
                              Row(
                                children: [
                                  // Toggle availability
                                  Expanded(
                                    child: Container(
                                      height: 45,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(15),
                                        gradient: LinearGradient(
                                          colors: menuItem.isAvailable
                                              ? [Colors.green, Colors.green.shade400]
                                              : [Colors.grey.shade400, Colors.grey.shade300],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: (menuItem.isAvailable ? Colors.green : Colors.grey)
                                                .withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(15),
                                          onTap: isUpdating ? null : () => _toggleItemStatus(menuItem),
                                          child: Center(
                                            child: isUpdating
                                                ? SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                              ),
                                            )
                                                : Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  menuItem.isAvailable
                                                      ? Icons.visibility
                                                      : Icons.visibility_off,
                                                  color: Colors.white,
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  menuItem.isAvailable ? 'BUKA' : 'TUTUP',
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
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Edit button
                                  Expanded(
                                    child: Container(
                                      height: 45,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(15),
                                        gradient: LinearGradient(
                                          colors: [
                                            GlobalStyle.primaryColor,
                                            GlobalStyle.primaryColor.withOpacity(0.8),
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: GlobalStyle.primaryColor.withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(15),
                                          onTap: () => _navigateToAddEditForm(menuItem: menuItem),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.edit, color: Colors.white, size: 18),
                                              const SizedBox(width: 8),
                                              Text(
                                                'EDIT',
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
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Delete button
                                  Container(
                                    width: 45,
                                    height: 45,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(15),
                                      gradient: const LinearGradient(
                                        colors: [Colors.red, Color(0xFFF44336)],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.red.withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(15),
                                        onTap: isUpdating ? null : () => _showDeleteConfirmation(menuItem),
                                        child: Center(
                                          child: Icon(
                                            Icons.delete,
                                            color: Colors.white,
                                            size: 20,
                                          ),
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFE),
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
          // Refresh button with animation
          AnimatedBuilder(
            animation: _refreshController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _refreshController.value * 2 * 3.14159,
                child: IconButton(
                  icon: Icon(Icons.refresh, color: GlobalStyle.primaryColor),
                  onPressed: _refreshItems,
                  tooltip: 'Refresh',
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              onPressed: _storeId != null ? () => _navigateToAddEditForm() : null,
              icon: const Icon(Icons.add),
              label: const Text('Tambah Item'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _storeId != null ? GlobalStyle.primaryColor : Colors.grey,
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
      body: Column(
        children: [
          // Store ID indicator with item count and store info
          if (_storeId != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white,
                    GlobalStyle.lightColor.withOpacity(0.1),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: GlobalStyle.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.store,
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
                          _storeInfo?['name'] ?? 'Your Store',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: GlobalStyle.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: $_storeId',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          GlobalStyle.primaryColor,
                          GlobalStyle.primaryColor.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_menuItems.length} items',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Main content
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _hasError
                ? _buildErrorState()
                : _menuItems.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
              onRefresh: _pullToRefresh,
              color: GlobalStyle.primaryColor,
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: _menuItems.length,
                itemBuilder: (context, index) {
                  final menuItem = _menuItems[index];
                  return _buildEnhancedMenuItemCard(menuItem, index);
                },
              ),
            ),
          ),
        ],
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