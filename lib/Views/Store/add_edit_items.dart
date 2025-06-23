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
import 'add_item.dart';

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
      4, // Number of card sections
          (index) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 600 + (index * 200)),
      ),
    );

    // Create slide animations for each card
    _cardAnimations = _cardControllers.map((controller) {
      return Tween<Offset>(
        begin: const Offset(0, -0.5),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeOutCubic,
      ));
    }).toList();

    // Initialize success animation controller
    _successAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Start animations sequentially
    Future.delayed(const Duration(milliseconds: 100), () {
      for (var controller in _cardControllers) {
        controller.forward();
      }
    });

    // Initialize store ID and item data
    _initializeData();

    // Add listeners to track changes
    _nameController.addListener(_onChange);
    _descriptionController.addListener(_onChange);
    _priceController.addListener(_onChange);
    _stockController.addListener(_onChange);
  }

  Future<void> _initializeData() async {
    try {
      // Get store ID from user data
      final userData = await AuthService.getUserData();
      if (userData != null && userData['store'] != null) {
        _storeId = userData['store']['id'].toString();
      }

      // Initialize with existing item data if available
      if (widget.menuItem != null) {
        _initializeFromMenuItem(widget.menuItem!);
      } else if (widget.item != null) {
        _initializeFromItem(widget.item!);
      }
    } catch (e) {
      print('Error initializing data: $e');
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
    _originalItemId = menuItem.id.toString();
    _storeId = menuItem.storeId.toString();
  }

  void _initializeFromItem(Item item) {
    _nameController.text = item.name;
    _descriptionController.text = item.description ?? '';
    _priceController.text = item.price.toString();
    _stockController.text = item.quantity.toString();
    _quantity = item.quantity;
    _selectedImageUrl = item.imageUrl;
    _selectedStatus = item.isAvailable ? 'available' : 'unavailable';
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
        const SnackBar(content: Text('Store ID tidak ditemukan')),
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
                Icon(
                  Icons.save_outlined,
                  size: 48,
                  color: GlobalStyle.primaryColor,
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

      if (_originalItemId != null) {
        // Update existing item using MenuItemService.updateMenuItem
        Map<String, dynamic> updateData = {
          'name': name,
          'description': description,
          'price': price,
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
          category: 'general', // Default category
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

    // Auto-dismiss dialog after 3 seconds and navigate back to AddItemPage
    Future.delayed(const Duration(seconds: 3), () {
      setState(() {
        _isSaving = false;
      });

      // Close the success dialog if it's showing
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // Return to the AddItemPage
      Navigator.pushReplacementNamed(context, AddItemPage.route);
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
        margin: const EdgeInsets.only(bottom: 16),
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
        child: child,
      ),
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
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(5.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: GlobalStyle.primaryColor, width: 1.0),
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
          elevation: 0.5,
          actions: [
            IconButton(
              icon: Icon(Icons.save_outlined, color: GlobalStyle.primaryColor),
              onPressed: _isSaving ? null : _saveItem,
            ),
          ],
        ),
        body: _isLoading
            ? Center(
          child: CircularProgressIndicator(color: GlobalStyle.primaryColor),
        )
            : SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Basic Information Card
                _buildCard(
                  index: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: GlobalStyle.primaryColor),
                            const SizedBox(width: 8),
                            const Text(
                              'Informasi Dasar',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildInputField(
                          label: 'Nama Item',
                          controller: _nameController,
                          icon: Icons.shopping_bag_outlined,
                        ),
                        const SizedBox(height: 16),
                        _buildInputField(
                          label: 'Deskripsi',
                          controller: _descriptionController,
                          maxLines: 3,
                          icon: Icons.description_outlined,
                        ),
                      ],
                    ),
                  ),
                ),

                // Pricing and Stock Card
                _buildCard(
                  index: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.attach_money,
                                color: GlobalStyle.primaryColor),
                            const SizedBox(width: 8),
                            const Text(
                              'Harga & Ketersediaan',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildInputField(
                          label: 'Harga',
                          controller: _priceController,
                          keyboardType: TextInputType.number,
                          prefix: 'Rp ',
                          icon: Icons.monetization_on_outlined,
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
                        const SizedBox(height: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.circle,
                                    size: 16, color: GlobalStyle.primaryColor),
                                const SizedBox(width: 8),
                                Text(
                                  'Status Item',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: GlobalStyle.lightColor.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: GlobalStyle.lightColor,
                                  width: 1,
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: _selectedStatus,
                                  icon: Icon(Icons.arrow_drop_down,
                                      color: GlobalStyle.primaryColor),
                                  items: _statusOptions.map((String status) {
                                    String displayStatus = status == 'available' ? 'Available' : 'Unavailable';

                                    return DropdownMenuItem<String>(
                                      value: status,
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: status == 'available'
                                                  ? Colors.green
                                                  : Colors.red,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(displayStatus),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    if (newValue != null) {
                                      setState(() {
                                        _selectedStatus = newValue;
                                        _hasChanges = true;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Image Upload Card
                _buildCard(
                  index: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.image, color: GlobalStyle.primaryColor),
                            const SizedBox(width: 8),
                            const Text(
                              'Gambar Item',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
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
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
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
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _pickImage,
                                  icon: const Icon(Icons.edit),
                                  label: const Text('Ganti Gambar'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor:
                                    GlobalStyle.primaryColor,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                      BorderRadius.circular(30),
                                      side: BorderSide(
                                          color:
                                          GlobalStyle.primaryColor),
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
                                    backgroundColor:
                                    GlobalStyle.lightColor,
                                    foregroundColor:
                                    GlobalStyle.primaryColor,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                      BorderRadius.circular(30),
                                    ),
                                    elevation: 0,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                            : DottedBorder(
                          borderType: BorderType.RRect,
                          radius: const Radius.circular(12),
                          color: Colors.grey[300]!,
                          strokeWidth: 2,
                          dashPattern: const [8, 4],
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.cloud_upload_outlined,
                                  size: 48,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Pilih gambar untuk diunggah',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Format: JPG, PNG (Max 1MB)',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: _pickImage,
                                  icon: const Icon(Icons.upload_file),
                                  label: const Text('Telusuri Gambar'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                    GlobalStyle.lightColor,
                                    foregroundColor:
                                    GlobalStyle.primaryColor,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                      BorderRadius.circular(30),
                                    ),
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
                  index: 3,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.lightbulb_outline,
                                color: Colors.amber[700]),
                            const SizedBox(width: 8),
                            const Text(
                              'Tips',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildTipItem(
                          icon: Icons.photo_size_select_actual_outlined,
                          text:
                          'Gambar dengan rasio 1:1 akan ditampilkan dengan optimal',
                        ),
                        _buildTipItem(
                          icon: Icons.description_outlined,
                          text:
                          'Deskripsi yang detail akan membantu pelanggan memahami produk Anda',
                        ),
                        _buildTipItem(
                          icon: Icons.price_change_outlined,
                          text:
                          'Tetapkan harga yang kompetitif untuk meningkatkan penjualan',
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
              ],
            ),
          ),
        ),
        bottomNavigationBar: Container(
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
            onPressed: _isSaving ? null : _saveItem,
            style: ElevatedButton.styleFrom(
              backgroundColor: GlobalStyle.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 2,
              disabledBackgroundColor: Colors.grey,
            ),
            child: _isSaving
                ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
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
                  ),
                ),
              ],
            )
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.save_outlined),
                const SizedBox(width: 8),
                const Text(
                  'Simpan Item',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
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
              Icon(icon, size: 16, color: GlobalStyle.primaryColor),
            if (icon != null) const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: GlobalStyle.lightColor.withOpacity(0.3),
            prefixText: prefix,
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: GlobalStyle.primaryColor, width: 1),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTipItem({required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: Colors.amber[700],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }
}