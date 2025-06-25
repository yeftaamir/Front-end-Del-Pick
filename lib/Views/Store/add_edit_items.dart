import 'package:flutter/material.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:lottie/lottie.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../Common/global_style.dart';
import '../../Models/order_review.dart';
import '../../Models/menu_item.dart';
import '../../Services/menu_service.dart';
import '../../Services/image_service.dart';
import '../../Services/auth_service.dart';
import '../../Services/store_data_helper.dart';

class AddEditItemForm extends StatefulWidget {
  static const String route = '/Store/AddEditItems';
  final Item? item;
  final MenuItemModel? menuItem;

  const AddEditItemForm({Key? key, this.item, this.menuItem}) : super(key: key);

  @override
  State<AddEditItemForm> createState() => _AddEditItemFormState();
}

class _AddEditItemFormState extends State<AddEditItemForm>
    with TickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();

  // Category options
  final List<Map<String, dynamic>> _categoryOptions = [
    {'value': 'makanan', 'label': 'Makanan', 'icon': Icons.restaurant},
    {'value': 'minuman', 'label': 'Minuman', 'icon': Icons.local_cafe},
    {'value': 'alat_tulis', 'label': 'Alat Tulis', 'icon': Icons.edit},
    {'value': 'bouqet', 'label': 'Bouqet', 'icon': Icons.local_florist},
    {'value': 'hadiah', 'label': 'Hadiah', 'icon': Icons.card_giftcard},
    {'value': 'elektronik', 'label': 'Elektronik', 'icon': Icons.devices},
    {'value': 'snack', 'label': 'Snack', 'icon': Icons.cake},
    {'value': 'kebutuhan', 'label': 'Harian', 'icon': Icons.shopping_cart},
    {'value': 'barang', 'label': 'Barang', 'icon': Icons.inventory_2},
    {'value': 'lainnya', 'label': 'Lainnya', 'icon': Icons.category },
  ];
  String _selectedCategory = 'general';

  // Status options for menu item
  final List<String> _statusOptions = ['available', 'unavailable'];
  String _selectedStatus = 'available';

  // Image handling
  XFile? _selectedImageFile;
  String? _selectedImageUrl;
  String? _imageBase64;
  bool _isUploading = false;

  // Form state
  bool _isLoading = false;
  bool _isSaving = false;
  bool _hasError = false;
  String _errorMessage = '';

  // Store ID and item ID
  String? _storeId;
  String? _originalItemId;

  // Animation controllers
  late List<AnimationController> _cardControllers;
  late List<Animation<Offset>> _cardAnimations;
  late AnimationController _successAnimationController;
  late AnimationController _pulseController;
  late AnimationController _categoryController;

  // Audio player
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _hasChanges = false;
  int _quantity = 1;
  bool _isViewingFullImage = false;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers for each card section
    _cardControllers = List.generate(
      5, // Increased number of card sections
          (index) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 800 + (index * 150)),
      ),
    );

    // Create slide animations for each card
    _cardAnimations = _cardControllers.map((controller) {
      return Tween<Offset>(
        begin: const Offset(0, 0.3),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.elasticOut,
      ));
    }).toList();

    // Initialize other animation controllers
    _successAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _categoryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Start animations sequentially with stagger effect
    _startStaggeredAnimations();

    // Initialize store ID and item data
    _initializeData();

    // Add listeners to track changes
    _nameController.addListener(_onChange);
    _descriptionController.addListener(_onChange);
    _priceController.addListener(_onChange);
    _stockController.addListener(_onChange);
  }

  void _startStaggeredAnimations() {
    Future.delayed(const Duration(milliseconds: 200), () {
      for (int i = 0; i < _cardControllers.length; i++) {
        Future.delayed(Duration(milliseconds: i * 100), () {
          if (mounted) {
            _cardControllers[i].forward();
          }
        });
      }
    });
  }

  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get store ID from user data first
      await _getStoreId();

      if (_storeId != null) {
        // Initialize with existing item data if available
        if (widget.menuItem != null) {
          _initializeFromMenuItem(widget.menuItem!);
        } else if (widget.item != null) {
          _initializeFromItem(widget.item!);
        }
      } else {
        throw Exception('Store information not found. Please ensure you are logged in as a store owner.');
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Error initializing data: $e';
      });
      print('Error initializing data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Enhanced store ID retrieval with multiple fallback methods
  Future<void> _getStoreId() async {
    try {
      // Method 1: Try using getRoleSpecificData()
      final roleSpecificData = await AuthService.getRoleSpecificData();
      print('Role specific data: $roleSpecificData');

      if (roleSpecificData != null && roleSpecificData['store'] != null) {
        _storeId = roleSpecificData['store']['id'].toString();
        print('Store ID from role specific data: $_storeId');
        return;
      }

      // Method 2: Try regular getUserData()
      final userData = await AuthService.getUserData();
      print('User data: $userData');

      if (userData != null) {
        // Try different possible locations for store data
        if (userData['store'] != null && userData['store']['id'] != null) {
          _storeId = userData['store']['id'].toString();
          print('Store ID from userData[store]: $_storeId');
          return;
        }

        if (userData['user'] != null && userData['user']['store'] != null) {
          _storeId = userData['user']['store']['id'].toString();
          print('Store ID from userData[user][store]: $_storeId');
          return;
        }
      }

      // Method 3: Try using getProfile()
      final profile = await AuthService.getProfile();
      print('Profile data: $profile');

      if (profile != null) {
        if (profile['store'] != null && profile['store']['id'] != null) {
          _storeId = profile['store']['id'].toString();
          print('Store ID from profile[store]: $_storeId');
          return;
        }
      }

      // Method 4: Check user role and refresh data if needed
      final userRole = await AuthService.getUserRole();
      print('User role: $userRole');

      if (userRole == 'store') {
        // Try refreshing user data
        final refreshedData = await AuthService.refreshUserData();
        print('Refreshed data: $refreshedData');

        if (refreshedData != null && refreshedData['store'] != null) {
          _storeId = refreshedData['store']['id'].toString();
          print('Store ID from refreshed data: $_storeId');
          return;
        }
      }

      throw Exception('Store ID not found in any data source. User role: $userRole');

    } catch (e) {
      print('Error getting store ID: $e');
      throw Exception('Failed to get store information: $e');
    }
  }

  void _initializeFromMenuItem(MenuItemModel menuItem) {
    _nameController.text = menuItem.name;
    _descriptionController.text = menuItem.description;
    _priceController.text = menuItem.price.toString();
    _stockController.text = '1'; // Default quantity
    _quantity = 1;
    _selectedImageUrl = menuItem.imageUrl;
    _selectedStatus = menuItem.isAvailable ? 'available' : 'unavailable';
    _selectedCategory = menuItem.category.isNotEmpty ? menuItem.category : 'general';
    _originalItemId = menuItem.id.toString();

    // Use the store ID from menu item if available, otherwise use the detected one
    if (menuItem.storeId > 0) {
      _storeId = menuItem.storeId.toString();
    }
  }

  void _initializeFromItem(Item item) {
    _nameController.text = item.name;
    _descriptionController.text = item.description ?? '';
    _priceController.text = item.price.toString();
    _stockController.text = item.quantity.toString();
    _quantity = item.quantity;
    _selectedImageUrl = item.imageUrl;
    _selectedStatus = item.isAvailable ? 'available' : 'unavailable';
    _selectedCategory = 'general'; // Default for legacy items
    _originalItemId = item.id;
  }

  void _onChange() {
    setState(() {
      _hasChanges = true;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();

    for (var controller in _cardControllers) {
      controller.dispose();
    }

    _successAnimationController.dispose();
    _pulseController.dispose();
    _categoryController.dispose();
    _audioPlayer.dispose();

    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      setState(() {
        _isUploading = true;
      });

      // Use ImageService.pickImage method
      final XFile? imageFile = await ImageService.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (imageFile != null) {
        // Convert image to base64 using ImageService
        final String? base64String = await ImageService.imageToBase64(imageFile);

        if (base64String != null) {
          setState(() {
            _selectedImageFile = imageFile;
            _imageBase64 = base64String;
            _selectedImageUrl = imageFile.path; // For display purposes
            _isUploading = false;
            _hasChanges = true;
          });

          // Add success animation for image upload
          _pulseController.forward().then((_) => _pulseController.reverse());
        } else {
          throw Exception('Failed to convert image to base64');
        }
      } else {
        setState(() {
          _isUploading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting image: $e')),
      );
    }
  }

  void _toggleFullImage() {
    setState(() {
      _isViewingFullImage = !_isViewingFullImage;
    });
  }

  Future<void> _showConfirmationDialog() async {
    // Validate inputs first
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama item harus diisi')),
      );
      return;
    }

    if (_priceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harga harus diisi')),
      );
      return;
    }

    if (_storeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Store ID tidak ditemukan. Silakan coba login ulang.')),
      );
      return;
    }

    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: GlobalStyle.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.save_outlined,
                    size: 48,
                    color: GlobalStyle.primaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Simpan Item',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Apakah Anda yakin ingin menyimpan item ${_nameController.text}?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      child: const Text('Batal'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GlobalStyle.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text('Simpan'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result == true) {
      await _saveItemToDatabase();
    }
  }

  Future<void> _saveItemToDatabase() async {
    setState(() {
      _isSaving = true;
      _hasError = false;
    });

    try {
      final String name = _nameController.text;
      final String description = _descriptionController.text;
      final double price = double.tryParse(_priceController.text.replaceAll(',', '').replaceAll('.', '')) ?? 0.0;
      final int stock = int.tryParse(_stockController.text) ?? 1;
      final bool isAvailable = _selectedStatus == 'available';

      print('Saving item with store ID: $_storeId');

      if (_originalItemId != null) {
        // Update existing item using MenuItemService.updateMenuItem
        Map<String, dynamic> updateData = {
          'name': name,
          'description': description,
          'price': price,
          'category': _selectedCategory,
          'isAvailable': isAvailable,
        };

        // Add image if new image is selected
        if (_imageBase64 != null) {
          updateData['image'] = _imageBase64;
        }

        final updatedItem = await MenuItemService.updateMenuItem(
          menuItemId: _originalItemId!,
          updateData: updateData,
        );

        if (updatedItem.isNotEmpty) {
          _showSuccessAnimation();
        } else {
          throw Exception('Failed to update menu item');
        }
      } else {
        // Create new item using MenuItemService.createMenuItem
        final newItem = await MenuItemService.createMenuItem(
          name: name,
          price: price,
          storeId: _storeId!,
          category: _selectedCategory,
          description: description,
          imageBase64: _imageBase64,
          quantity: stock,
          isAvailable: isAvailable,
        );

        if (newItem.isNotEmpty) {
          _showSuccessAnimation();
        } else {
          throw Exception('Failed to create menu item');
        }
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
        _hasError = true;
        _errorMessage = 'Failed to save item: $e';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving item: $e')),
      );
    }
  }

  Future<void> _showSuccessAnimation() async {
    // Play sound from assets/audio/alert.wav
    try {
      await _audioPlayer.play(AssetSource('audio/alert.wav'));
    } catch (e) {
      print('Error playing sound: $e');
    }

    // Show success animation dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/animations/check_animation.json',
                  controller: _successAnimationController,
                  onLoaded: (composition) {
                    _successAnimationController
                      ..duration = composition.duration
                      ..forward();
                  },
                  width: 150,
                  height: 150,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Item Berhasil Disimpan!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    // Auto-dismiss dialog after 2 seconds and return to previous page with success result
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _isSaving = false;
      });

      // Close the success dialog if it's showing
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // Return to the previous page with success result to trigger refresh
      Navigator.pop(context, 'success');
    });
  }

  void _saveItem() {
    _showConfirmationDialog();
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    // Show confirmation dialog if there are unsaved changes
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text(
            'You have unsaved changes. Are you sure you want to discard them?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DISCARD'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Widget _buildCard({required Widget child, required int index}) {
    return SlideTransition(
      position: _cardAnimations[index],
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: child,
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.category, color: GlobalStyle.primaryColor, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Kategori Item',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 120,
          child: GridView.builder(
            scrollDirection: Axis.horizontal,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.8,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _categoryOptions.length,
            itemBuilder: (context, index) {
              final category = _categoryOptions[index];
              final isSelected = _selectedCategory == category['value'];

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCategory = category['value'];
                    _hasChanges = true;
                  });

                  // Add scale animation when selected
                  _categoryController.forward().then((_) => _categoryController.reverse());
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? GlobalStyle.primaryColor.withOpacity(0.1)
                        : Colors.grey[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? GlobalStyle.primaryColor
                          : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedScale(
                        scale: isSelected ? 1.2 : 1.0,
                        duration: const Duration(milliseconds: 300),
                        child: Icon(
                          category['icon'],
                          color: isSelected
                              ? GlobalStyle.primaryColor
                              : Colors.grey[600],
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        category['label'],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected
                              ? GlobalStyle.primaryColor
                              : Colors.grey[700],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Format currency for display in the price field
  String _formatCurrency(String value) {
    if (value.isEmpty) return '';

    // Remove all non-numeric characters
    String cleanValue = value.replaceAll(RegExp(r'[^\d]'), '');

    // Convert to double
    double amount = double.tryParse(cleanValue) ?? 0;

    // Format using GlobalStyle
    return GlobalStyle.formatRupiah(amount);
  }

  @override
  Widget build(BuildContext context) {
    // Return full image view if in full image mode
    if (_isViewingFullImage && _selectedImageUrl != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: _toggleFullImage,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image
              Center(
                child: Hero(
                  tag: 'itemImage',
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: _selectedImageFile != null
                        ? Image.file(
                      File(_selectedImageFile!.path),
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.contain,
                    )
                        : ImageService.displayImage(
                      imageSource: _selectedImageUrl!,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              // Close button
              Positioned(
                top: 40,
                right: 20,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: _toggleFullImage,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(Icons.arrow_back_ios_new,
                  color: GlobalStyle.primaryColor, size: 18),
            ),
            onPressed: () => _onWillPop().then((canPop) {
              if (canPop) Navigator.pop(context);
            }),
          ),
          title: Text(
            _originalItemId != null ? 'Edit Item' : 'Tambah Item',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          actions: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + (_pulseController.value * 0.1),
                  child: IconButton(
                    icon: Icon(Icons.save_outlined, color: GlobalStyle.primaryColor),
                    onPressed: _isSaving ? null : _saveItem,
                  ),
                );
              },
            ),
          ],
        ),
        body: _isLoading
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: GlobalStyle.primaryColor),
              const SizedBox(height: 16),
              const Text('Memuat data store...'),
              if (_storeId != null)
                Text('Store ID: $_storeId', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        )
            : _hasError
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              Text(
                'Error',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _errorMessage,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _initializeData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlobalStyle.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text('Coba Lagi', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        )
            : SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Store Info Card
                if (_storeId != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          GlobalStyle.primaryColor.withOpacity(0.1),
                          GlobalStyle.primaryColor.withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: GlobalStyle.primaryColor.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: GlobalStyle.primaryColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.store, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Store ID: $_storeId',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: GlobalStyle.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Basic Information Card
                _buildCard(
                  index: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: GlobalStyle.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.info_outline,
                                  color: GlobalStyle.primaryColor, size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Informasi Dasar',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildInputField(
                          label: 'Nama Item',
                          controller: _nameController,
                          icon: Icons.shopping_bag_outlined,
                          hint: 'Masukkan nama item',
                        ),
                        const SizedBox(height: 20),
                        _buildInputField(
                          label: 'Deskripsi',
                          controller: _descriptionController,
                          maxLines: 3,
                          icon: Icons.description_outlined,
                          hint: 'Deskripsikan item Anda dengan detail',
                        ),
                      ],
                    ),
                  ),
                ),

                // Category Selection Card
                _buildCard(
                  index: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: _buildCategorySelector(),
                  ),
                ),

                // Pricing and Availability Card
                _buildCard(
                  index: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.attach_money,
                                  color: Colors.green, size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Harga & Ketersediaan',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildInputField(
                          label: 'Harga',
                          controller: _priceController,
                          keyboardType: TextInputType.number,
                          prefix: 'Rp ',
                          icon: Icons.monetization_on_outlined,
                          hint: '0',
                          onChanged: (value) {
                            final cleanValue = value.replaceAll(RegExp(r'[^\d]'), '');
                            if (cleanValue.isNotEmpty) {
                              final double amount = double.tryParse(cleanValue) ?? 0;
                              final formatted = GlobalStyle.formatRupiah(amount);

                              // Only update if the formatting actually changed something
                              if (formatted != value) {
                                // Keep cursor position relative to the end
                                final cursorPosition = _priceController.text.length - _priceController.selection.extentOffset;
                                _priceController.value = TextEditingValue(
                                  text: formatted.replaceAll('Rp ', ''),
                                  selection: TextSelection.collapsed(
                                    offset: formatted.replaceAll('Rp ', '').length - cursorPosition,
                                  ),
                                );
                              }
                            }
                          },
                        ),
                        const SizedBox(height: 20),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.toggle_on,
                                    size: 20, color: GlobalStyle.primaryColor),
                                const SizedBox(width: 8),
                                Text(
                                  'Status Ketersediaan',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: _statusOptions.map((status) {
                                bool isSelected = _selectedStatus == status;
                                String displayStatus = status == 'available' ? 'Tersedia' : 'Tidak Tersedia';
                                Color statusColor = status == 'available' ? Colors.green : Colors.red;

                                return Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedStatus = status;
                                        _hasChanges = true;
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 300),
                                      margin: const EdgeInsets.symmetric(horizontal: 4),
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? statusColor.withOpacity(0.1)
                                            : Colors.grey[50],
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected ? statusColor : Colors.grey[300]!,
                                          width: isSelected ? 2 : 1,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          AnimatedScale(
                                            scale: isSelected ? 1.2 : 1.0,
                                            duration: const Duration(milliseconds: 300),
                                            child: Icon(
                                              status == 'available' ? Icons.check_circle : Icons.cancel,
                                              color: isSelected ? statusColor : Colors.grey[400],
                                              size: 24,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            displayStatus,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                              color: isSelected ? statusColor : Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Image Upload Card
                _buildCard(
                  index: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.purple.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.image, color: Colors.purple, size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Gambar Item',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _isUploading
                            ? Center(
                          child: Column(
                            children: [
                              CircularProgressIndicator(color: GlobalStyle.primaryColor),
                              const SizedBox(height: 16),
                              const Text('Memuat gambar...'),
                            ],
                          ),
                        )
                            : (_selectedImageFile != null || _selectedImageUrl != null)
                            ? Column(
                          children: [
                            GestureDetector(
                              onTap: _toggleFullImage,
                              child: Hero(
                                tag: 'itemImage',
                                child: Container(
                                  height: 250,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 15,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: _selectedImageFile != null
                                        ? Image.file(
                                      File(_selectedImageFile!.path),
                                      width: double.infinity,
                                      height: 250,
                                      fit: BoxFit.cover,
                                    )
                                        : ImageService.displayImage(
                                      imageSource: _selectedImageUrl!,
                                      width: double.infinity,
                                      height: 250,
                                      fit: BoxFit.cover,
                                      placeholder: Container(
                                        width: double.infinity,
                                        height: 250,
                                        color: Colors.grey[300],
                                        child: const Icon(Icons.image, size: 64, color: Colors.grey),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _pickImage,
                                  icon: const Icon(Icons.edit),
                                  label: const Text('Ganti Gambar'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: GlobalStyle.primaryColor,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                      side: BorderSide(color: GlobalStyle.primaryColor),
                                    ),
                                    elevation: 0,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  onPressed: _toggleFullImage,
                                  icon: const Icon(Icons.fullscreen),
                                  label: const Text('Lihat Full'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: GlobalStyle.primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    elevation: 2,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                            : DottedBorder(
                          borderType: BorderType.RRect,
                          radius: const Radius.circular(16),
                          color: GlobalStyle.primaryColor.withOpacity(0.3),
                          strokeWidth: 2,
                          dashPattern: const [12, 6],
                          child: Container(
                            padding: const EdgeInsets.all(32),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: GlobalStyle.primaryColor.withOpacity(0.02),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: GlobalStyle.primaryColor.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.cloud_upload_outlined,
                                    size: 48,
                                    color: GlobalStyle.primaryColor,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Pilih gambar untuk diunggah',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Format: JPG, PNG (Max 1MB)',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: _pickImage,
                                  icon: const Icon(Icons.upload_file),
                                  label: const Text('Telusuri Gambar'),
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
                                    elevation: 2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Tips Card
                _buildCard(
                  index: 4,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.lightbulb_outline,
                                  color: Colors.amber[700], size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Tips untuk Item Terbaik',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildTipItem(
                          icon: Icons.photo_size_select_actual_outlined,
                          text: 'Gunakan gambar berkualitas tinggi dengan rasio 1:1',
                          color: Colors.blue,
                        ),
                        _buildTipItem(
                          icon: Icons.description_outlined,
                          text: 'Tulis deskripsi yang menarik dan informatif',
                          color: Colors.green,
                        ),
                        _buildTipItem(
                          icon: Icons.category_outlined,
                          text: 'Pilih kategori yang sesuai untuk memudahkan pencarian',
                          color: Colors.purple,
                        ),
                        _buildTipItem(
                          icon: Icons.price_change_outlined,
                          text: 'Tetapkan harga yang kompetitif dan wajar',
                          color: Colors.orange,
                        ),
                      ],
                    ),
                  ),
                ),

                // Error message if exists
                if (_hasError)
                  Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red[700]),
                            const SizedBox(width: 8),
                            Text(
                              'Error',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage,
                          style: TextStyle(color: Colors.red[700]),
                        ),
                      ],
                    ),
                  ),

                // Add bottom padding for the floating button
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
        floatingActionButton: Container(
          width: MediaQuery.of(context).size.width - 40,
          height: 56,
          child: FloatingActionButton.extended(
            onPressed: _isSaving ? null : _saveItem,
            backgroundColor: _isSaving ? Colors.grey : GlobalStyle.primaryColor,
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            label: _isSaving
                ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Menyimpan...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            )
                : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.save_outlined, color: Colors.white),
                const SizedBox(width: 8),
                const Text(
                  'Simpan Item',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    String? prefix,
    String? hint,
    int maxLines = 1,
    IconData? icon,
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null)
              Icon(icon, size: 18, color: GlobalStyle.primaryColor),
            if (icon != null) const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey[50],
            prefixText: prefix,
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: GlobalStyle.primaryColor, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTipItem({
    required IconData icon,
    required String text,
    required Color color
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              size: 16,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}