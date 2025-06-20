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
    with TickerProviderStateMixin {
  int _currentIndex = 1;
  late AnimationController _headerAnimationController;
  late Animation<double> _headerAnimation;
  late List<AnimationController> _cardControllers;
  late List<Animation<Offset>> _cardAnimations;
  late List<Animation<double>> _cardScaleAnimations;
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

    _headerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _headerAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _headerAnimationController,
      curve: Curves.easeOutCubic,
    ));

    _cardControllers = [];
    _cardAnimations = [];
    _cardScaleAnimations = [];

    // Start header animation
    _headerAnimationController.forward();

    // Fetch items on init
    fetchMenuItems();
  }

  void _setupAnimations() {
    // Clean up existing controllers if any
    for (var controller in _cardControllers) {
      controller.dispose();
    }

    // Create new controllers
    _cardControllers = List.generate(
      _items.length,
          (index) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 600 + (index * 50)),
      ),
    );

    // Create slide animations for each card
    _cardAnimations = _cardControllers.map((controller) {
      return Tween<Offset>(
        begin: const Offset(0.3, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeOutCubic,
      ));
    }).toList();

    // Create scale animations for each card
    _cardScaleAnimations = _cardControllers.map((controller) {
      return Tween<double>(
        begin: 0.8,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeOutBack,
      ));
    }).toList();

    // Start animations with staggered delay
    for (int i = 0; i < _cardControllers.length; i++) {
      Future.delayed(Duration(milliseconds: 100 + (i * 80)), () {
        if (mounted) {
          _cardControllers[i].forward();
        }
      });
    }
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
        _setupAnimations();
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
    _headerAnimationController.dispose();
    for (var controller in _cardControllers) {
      controller.dispose();
    }
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
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            AddEditItemForm(item: item),
        transitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        },
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
      _showModernSnackBar(
        'Tidak dapat mengaktifkan produk tanpa stok.',
        icon: Icons.warning_rounded,
        color: Colors.orange,
      );
    }
  }

  void _showModernSnackBar(String message, {IconData? icon, Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) Icon(icon, color: Colors.white, size: 20),
            if (icon != null) const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color ?? GlobalStyle.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
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

          _showModernSnackBar(
            isAvailable ? 'Item berhasil diaktifkan.' : 'Item berhasil dinonaktifkan.',
            icon: Icons.check_circle_rounded,
            color: Colors.green,
          );
        } else {
          throw Exception('Failed to update item status');
        }
      } else {
        throw Exception('Invalid item ID');
      }
    } catch (e) {
      _showModernSnackBar(
        'Error updating item status: $e',
        icon: Icons.error_rounded,
        color: Colors.red,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [Colors.white, Color(0xFFFAFBFC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset(
                'assets/animations/cancel.json',
                width: 120,
                height: 120,
                repeat: true,
                animate: true,
              ),
              const SizedBox(height: 20),
              Text(
                'Nonaktifkan ${item.name}?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1A1D29),
                  letterSpacing: -0.5,
                  fontFamily: GlobalStyle.fontFamily,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Item yang dinonaktifkan tidak akan terlihat oleh pelanggan.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.grey.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.pop(context, false),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              'Batal',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEF5350), Color(0xFFE57373)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.pop(context, true),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              'Nonaktifkan',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [Colors.white, Color(0xFFFAFBFC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset(
                'assets/animations/trash.json',
                width: 120,
                height: 120,
                repeat: true,
                animate: true,
              ),
              const SizedBox(height: 20),
              Text(
                'Hapus ${item.name}?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1A1D29),
                  letterSpacing: -0.5,
                  fontFamily: GlobalStyle.fontFamily,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Item yang dihapus tidak dapat dikembalikan.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.grey.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.pop(context),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              'Batal',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEF5350), Color(0xFFE57373)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () async {
                            Navigator.pop(context);
                            await _deleteItem(item);
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              'Hapus',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
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
            _setupAnimations(); // Re-setup animations after removing item
          });

          _showModernSnackBar(
            'Item berhasil dihapus.',
            icon: Icons.check_circle_rounded,
            color: Colors.green,
          );
        } else {
          throw Exception('Failed to delete item');
        }
      } else {
        throw Exception('Invalid item ID');
      }
    } catch (e) {
      _showModernSnackBar(
        'Error deleting item: $e',
        icon: Icons.error_rounded,
        color: Colors.red,
      );
    } finally {
      setState(() {
        _updatingItems.remove(item.id);
      });
    }
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
  Widget _buildModernErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFFEBEE),
                    Color(0xFFFFF5F5),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 60,
                color: Color(0xFFE57373),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Gagal memuat item',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1D29),
                letterSpacing: -0.5,
                fontFamily: GlobalStyle.fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
                fontFamily: GlobalStyle.fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    GlobalStyle.primaryColor,
                    GlobalStyle.primaryColor.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: GlobalStyle.primaryColor.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: fetchMenuItems,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.refresh_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Coba Lagi',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            letterSpacing: 0.3,
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
    );
  }

  // Widget for displaying empty state
  Widget _buildModernEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/animations/empty.json',
              width: 200,
              height: 200,
              repeat: true,
              animate: true,
            ),
            const SizedBox(height: 24),
            Text(
              'Belum ada item',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1D29),
                letterSpacing: -0.5,
                fontFamily: GlobalStyle.fontFamily,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tambahkan item baru dengan menekan tombol + di bawah',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
                fontFamily: GlobalStyle.fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    GlobalStyle.primaryColor,
                    GlobalStyle.primaryColor.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: GlobalStyle.primaryColor.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(25),
                  onTap: () => _navigateToAddEditForm(),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Tambah Item Sekarang',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            letterSpacing: 0.3,
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
    );
  }

  // Widget for displaying loading state
  Widget _buildModernLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  GlobalStyle.primaryColor.withOpacity(0.1),
                  GlobalStyle.primaryColor.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: GlobalStyle.primaryColor.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: CircularProgressIndicator(
              color: GlobalStyle.primaryColor,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Memuat item...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A1D29),
              letterSpacing: -0.3,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Mohon tunggu sebentar',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernItemCard(Item item, int index) {
    final bool isOutOfStock = item.quantity <= 0;
    final bool isUpdating = _updatingItems.contains(item.id);

    return SlideTransition(
      position: index < _cardAnimations.length ? _cardAnimations[index] : const AlwaysStoppedAnimation(Offset.zero),
      child: ScaleTransition(
        scale: index < _cardScaleAnimations.length ? _cardScaleAnimations[index] : const AlwaysStoppedAnimation(1.0),
        child: Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [Colors.white, Color(0xFFFAFBFC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Stack(
            children: [
              Opacity(
                opacity: item.isAvailable ? 1.0 : 0.6,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => _navigateToAddEditForm(item: item),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          // Item image with modern styling
                          Hero(
                            tag: 'item_image_${item.id}',
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: GlobalStyle.primaryColor.withOpacity(0.1),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: ImageService.displayImage(
                                  imageSource: item.imageUrl,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  placeholder: Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.grey[100]!,
                                          Colors.grey[50]!,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Icon(
                                      Icons.restaurant_menu_rounded,
                                      color: Colors.grey[400],
                                      size: 32,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Item details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF1A1D29),
                                    letterSpacing: -0.5,
                                    fontFamily: GlobalStyle.fontFamily,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  item.formatPrice(),
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: GlobalStyle.primaryColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isOutOfStock
                                            ? Colors.red.withOpacity(0.1)
                                            : Colors.green.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isOutOfStock ? Colors.red.withOpacity(0.3) : Colors.green.withOpacity(0.3),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.inventory_2_rounded,
                                            size: 14,
                                            color: isOutOfStock ? Colors.red : Colors.green,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Stok: ${item.quantity}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isOutOfStock ? Colors.red : Colors.green,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: item.isAvailable
                                        ? Colors.green.withOpacity(0.1)
                                        : Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: item.isAvailable
                                          ? Colors.green.withOpacity(0.3)
                                          : Colors.red.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: item.isAvailable ? Colors.green : Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        formatStatus(item.status),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: item.isAvailable ? Colors.green : Colors.red,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                if (item.description != null && item.description!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      item.description!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                        height: 1.3,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Action buttons
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Toggle Status Button
                              _buildModernActionButton(
                                icon: item.isAvailable ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                label: item.isAvailable ? 'BUKA' : 'TUTUP',
                                color: item.isAvailable ? Colors.green : Colors.grey,
                                onTap: isUpdating ? null : () => _toggleItemStatus(item),
                                isLoading: isUpdating,
                              ),
                              const SizedBox(height: 8),

                              // Edit Button
                              _buildModernActionButton(
                                icon: Icons.edit_rounded,
                                label: 'EDIT',
                                color: GlobalStyle.primaryColor,
                                onTap: () => _navigateToAddEditForm(item: item),
                              ),
                              const SizedBox(height: 8),

                              // Delete Button
                              _buildModernActionButton(
                                icon: Icons.delete_rounded,
                                label: 'HAPUS',
                                color: Colors.red,
                                onTap: isUpdating ? null : () => _showDeleteConfirmation(item),
                                isLoading: isUpdating,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Status overlay for unavailable items
              if (!item.isAvailable)
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEF5350), Color(0xFFE57373)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      isOutOfStock ? 'STOK HABIS' : 'TUTUP',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 0.5,
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

  Widget _buildModernActionButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return Container(
      width: 70,
      height: 36,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color,
            color.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Center(
            child: isLoading
                ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 16),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // Modern App Bar
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    GlobalStyle.primaryColor,
                    GlobalStyle.primaryColor.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 72, bottom: 16),
                title: FadeTransition(
                  opacity: _headerAnimation,
                  child: const Text(
                    'Kelola Item',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        GlobalStyle.primaryColor,
                        GlobalStyle.primaryColor.withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
            ),
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 20,
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
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  onPressed: fetchMenuItems,
                ),
              ),
            ],
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _isLoading
                  ? Container(
                height: MediaQuery.of(context).size.height * 0.6,
                child: _buildModernLoadingState(),
              )
                  : _hasError
                  ? Container(
                height: MediaQuery.of(context).size.height * 0.6,
                child: _buildModernErrorState(),
              )
                  : _items.isEmpty
                  ? Container(
                height: MediaQuery.of(context).size.height * 0.6,
                child: _buildModernEmptyState(),
              )
                  : Column(
                children: [
                  // Stats row
                  Container(
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: [
                          GlobalStyle.primaryColor.withOpacity(0.1),
                          GlobalStyle.primaryColor.withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: GlobalStyle.primaryColor.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                '${_items.length}',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: GlobalStyle.primaryColor,
                                ),
                              ),
                              Text(
                                'Total Item',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: GlobalStyle.primaryColor.withOpacity(0.2),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                '${_items.where((item) => item.isAvailable).length}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.green,
                                ),
                              ),
                              Text(
                                'Tersedia',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Items list
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      return _buildModernItemCard(_items[index], index);
                    },
                  ),

                  const SizedBox(height: 100), // Space for FAB
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Container(
        width: 65,
        height: 65,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              GlobalStyle.primaryColor,
              GlobalStyle.primaryColor.withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: GlobalStyle.primaryColor.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _navigateToAddEditForm(),
            child: const Icon(
              Icons.add_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
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