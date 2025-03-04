import 'package:flutter/material.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:lottie/lottie.dart';
import '../../Common/global_style.dart';
import '../../Models/item_model.dart';

class AddEditItemForm extends StatefulWidget {
  static const String route = '/Store/AddEditItems';
  final Item? item;

  const AddEditItemForm({Key? key, this.item}) : super(key: key);

  @override
  State<AddEditItemForm> createState() => _AddEditItemFormState();
}

class _AddEditItemFormState extends State<AddEditItemForm> with TickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();

  // Status options for order status
  final List<String> _statusOptions = ['Available', 'Out of Stock', 'Limited'];
  String _selectedStatus = 'Available';

  // Image picker
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  String? _selectedImageUrl;

  // Animation controllers
  late List<AnimationController> _cardControllers;
  late List<Animation<Offset>> _cardAnimations;

  bool _hasChanges = false;
  int _quantity = 1;

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

    // Start animations sequentially
    Future.delayed(const Duration(milliseconds: 100), () {
      for (var controller in _cardControllers) {
        controller.forward();
      }
    });

    // Initialize with existing item data if available
    if (widget.item != null) {
      _nameController.text = widget.item!.name;
      _priceController.text = widget.item!.price.toString();
      _quantity = widget.item!.quantity;
      _selectedImageUrl = widget.item!.imageUrl;
    }

    // Add listeners to track changes
    _nameController.addListener(_onChange);
    _descriptionController.addListener(_onChange);
    _priceController.addListener(_onChange);
    _stockController.addListener(_onChange);
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

    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedImage = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedImage != null) {
        setState(() {
          _imageFile = File(pickedImage.path);
          _selectedImageUrl = pickedImage.path; // This is temporary, in real app you'd upload and get URL
          _hasChanges = true;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting image: $e')),
      );
    }
  }

  void _saveItem() {
    // Validate inputs
    if (_nameController.text.isEmpty || _priceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and price are required')),
      );
      return;
    }

    // Parse stock from controller
    int stock = int.tryParse(_stockController.text) ?? _quantity;

    // Create updated item
    final updatedItem = Item(
      id: widget.item?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text,
      price: double.tryParse(_priceController.text) ?? 0.0,
      imageUrl: _selectedImageUrl ?? 'assets/images/menu_item.jpg', // Default image path
      quantity: stock, isAvailable: true, status: '',
      // Note: In a real implementation, you would handle the additional fields
      // we've created (status, etc.) by extending the Item model or by passing
      // them separately to your state management solution
    );

    // Here you would typically save to your data source

    // Return the updated item to the previous screen
    Navigator.pop(context, updatedItem);
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    // Show confirmation dialog if there are unsaved changes
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved changes. Are you sure you want to discard them?'),
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

  @override
  Widget build(BuildContext context) {
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
              child: Icon(Icons.arrow_back_ios_new, color: GlobalStyle.primaryColor, size: 18),
            ),
            onPressed: () => _onWillPop().then((canPop) {
              if (canPop) Navigator.pop(context);
            }),
          ),
          title: Text(
            widget.item != null ? 'Edit Item' : 'Add Item',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0.5,
        ),
        body: SingleChildScrollView(
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
                            Icon(Icons.info_outline, color: GlobalStyle.primaryColor),
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
                        ),
                        const SizedBox(height: 16),
                        _buildInputField(
                          label: 'Deskripsi',
                          controller: _descriptionController,
                          maxLines: 3,
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
                            Icon(Icons.attach_money, color: GlobalStyle.primaryColor),
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
                        ),
                        const SizedBox(height: 16),
                        _buildInputField(
                          label: 'Stok',
                          controller: _stockController,
                          keyboardType: TextInputType.number,
                          hint: widget.item != null ? widget.item!.quantity.toString() : '0',
                        ),
                        const SizedBox(height: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Status Item',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: GlobalStyle.lightColor.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: _selectedStatus,
                                  items: _statusOptions.map((String status) {
                                    return DropdownMenuItem<String>(
                                      value: status,
                                      child: Text(status),
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
                        _imageFile != null || (widget.item != null && widget.item!.imageUrl != null)
                            ? Column(
                          children: [
                            Container(
                              height: 200,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                image: DecorationImage(
                                  image: _imageFile != null
                                      ? FileImage(_imageFile!) as ImageProvider
                                      : (_selectedImageUrl?.startsWith('assets/') ?? false)
                                      ? AssetImage(_selectedImageUrl!) as ImageProvider
                                      : FileImage(File(_selectedImageUrl!)),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: _pickImage,
                              icon: const Icon(Icons.edit),
                              label: const Text('Ganti Gambar'),
                              style: TextButton.styleFrom(
                                foregroundColor: GlobalStyle.primaryColor,
                              ),
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
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Pilih gambar untuk diunggah',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _pickImage,
                                  icon: const Icon(Icons.upload_file),
                                  label: const Text('Telusuri Gambar'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: GlobalStyle.lightColor,
                                    foregroundColor: GlobalStyle.primaryColor,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
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
            onPressed: _saveItem,
            style: ElevatedButton.styleFrom(
              backgroundColor: GlobalStyle.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text(
              'Simpan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
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
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            filled: true,
            fillColor: GlobalStyle.lightColor.withOpacity(0.3),
            prefixText: prefix,
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
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
}