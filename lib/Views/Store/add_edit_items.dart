import 'package:flutter/material.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:lottie/lottie.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../Common/global_style.dart';
import '../../Models/item_model.dart';
import 'add_edit_items.dart' as add_item;

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

    // Initialize with existing item data if available
    if (widget.item != null) {
      _nameController.text = widget.item!.name;
      _descriptionController.text = widget.item!.description ?? '';
      _priceController.text = widget.item!.price.toString();
      _stockController.text = widget.item!.quantity.toString();
      _quantity = widget.item!.quantity;
      _selectedImageUrl = widget.item!.imageUrl;
      _selectedStatus = widget.item!.status.isNotEmpty ? widget.item!.status : 'Available';
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

    _successAnimationController.dispose();
    _audioPlayer.dispose();

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

  void _toggleFullImage() {
    setState(() {
      _isViewingFullImage = !_isViewingFullImage;
    });
  }

  Future<void> _showConfirmationDialog() async {
    // Validate inputs first
    if (_nameController.text.isEmpty || _priceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and price are required')),
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
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
      _showSuccessAnimation();
    }
  }

  Future<void> _showSuccessAnimation() async {
    // Play sound from assets/audio/alert.wav
    await _audioPlayer.play(AssetSource('audio/alert.wav'));

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
      // Create updated item
      int stock = int.tryParse(_stockController.text) ?? _quantity;

      // Create updated item
      final updatedItem = Item(
        id: widget.item?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text,
        description: _descriptionController.text,
        price: double.tryParse(_priceController.text) ?? 0.0,
        imageUrl: _selectedImageUrl ?? 'assets/images/menu_item.jpg', // Default image path
        quantity: stock,
        isAvailable: _selectedStatus == 'Available',
        status: _selectedStatus,
      );

      // Close the success dialog if it's showing
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // Return to the AddItemPage with the updated item
      Navigator.pushNamed(context, AddItemPage.route);
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
    // Return full image view if in full image mode
    if (_isViewingFullImage && (_imageFile != null || _selectedImageUrl != null)) {
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
                    child: Image(
                      image: _imageFile != null
                          ? FileImage(_imageFile!) as ImageProvider
                          : (_selectedImageUrl?.startsWith('assets/') ?? false)
                          ? AssetImage(_selectedImageUrl!) as ImageProvider
                          : FileImage(File(_selectedImageUrl!)),
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
          actions: [
            IconButton(
              icon: Icon(Icons.save_outlined, color: GlobalStyle.primaryColor),
              onPressed: _saveItem,
            ),
          ],
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
                          icon: Icons.monetization_on_outlined,
                        ),
                        const SizedBox(height: 16),
                        _buildInputField(
                          label: 'Stok',
                          controller: _stockController,
                          keyboardType: TextInputType.number,
                          hint: widget.item != null ? widget.item!.quantity.toString() : '0',
                          icon: Icons.inventory_2_outlined,
                        ),
                        const SizedBox(height: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.circle, size: 16, color: GlobalStyle.primaryColor),
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
                              padding: const EdgeInsets.symmetric(horizontal: 16),
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
                                  icon: Icon(Icons.arrow_drop_down, color: GlobalStyle.primaryColor),
                                  items: _statusOptions.map((String status) {
                                    return DropdownMenuItem<String>(
                                      value: status,
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: status == 'Available'
                                                  ? Colors.green
                                                  : status == 'Out of Stock'
                                                  ? Colors.red
                                                  : Colors.orange,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(status),
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
                        _imageFile != null || (widget.item != null && widget.item!.imageUrl != null)
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
                                    foregroundColor: GlobalStyle.primaryColor,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
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
                                    backgroundColor: GlobalStyle.lightColor,
                                    foregroundColor: GlobalStyle.primaryColor,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
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
                                  'Format: JPG, PNG (Max 5MB)',
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
                            Icon(Icons.lightbulb_outline, color: Colors.amber[700]),
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
                          text: 'Gambar dengan rasio 1:1 akan ditampilkan dengan optimal',
                        ),
                        _buildTipItem(
                          icon: Icons.description_outlined,
                          text: 'Deskripsi yang detail akan membantu pelanggan memahami produk Anda',
                        ),
                        _buildTipItem(
                          icon: Icons.price_change_outlined,
                          text: 'Tetapkan harga yang kompetitif untuk meningkatkan penjualan',
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
              elevation: 2,
            ),
            child: Row(
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
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) Icon(icon, size: 16, color: GlobalStyle.primaryColor),
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

class AddItemPage extends StatefulWidget {
  static const String route = '/Store/AddItem';

  const AddItemPage({Key? key}) : super(key: key);

  @override
  State<AddItemPage> createState() => _AddItemPageState();
}

class _AddItemPageState extends State<AddItemPage> with TickerProviderStateMixin {
  List<Item> _items = [];
  bool _isLoading = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_fadeController);
    _loadItems();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
    });

    // Simulate loading items from a data source
    await Future.delayed(const Duration(milliseconds: 500));

    // In a real app, you would get items from a database or API
    // For demonstration, we'll use mock data
    setState(() {
      _items = [
        Item(
          id: '1',
          name: 'Sample Item 1',
          description: 'This is a sample item description.',
          price: 25000,
          imageUrl: 'assets/images/menu_item.jpg',
          quantity: 10,
          isAvailable: true,
          status: 'Available',
        ),
        Item(
          id: '2',
          name: 'Sample Item 2',
          description: 'Another sample item with description.',
          price: 30000,
          imageUrl: 'assets/images/menu_item.jpg',
          quantity: 5,
          isAvailable: true,
          status: 'Limited',
        ),
      ];
      _isLoading = false;
    });

    _fadeController.forward();
  }

  void _addNewItem() {
    Navigator.pushNamed(
      context,
      AddEditItemForm.route,
    ).then((result) {
      if (result != null && result is Item) {
        setState(() {
          // Check if item exists, update it; otherwise add as new
          final existingIndex = _items.indexWhere((item) => item.id == result.id);
          if (existingIndex >= 0) {
            _items[existingIndex] = result;
          } else {
            _items.add(result);
          }
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Item "${result.name}" has been saved successfully.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  void _editItem(Item item) {
    Navigator.pushNamed(
      context,
      AddEditItemForm.route,
      arguments: item,
    ).then((result) {
      if (result != null && result is Item) {
        setState(() {
          final index = _items.indexWhere((i) => i.id == result.id);
          if (index >= 0) {
            _items[index] = result;
          }
        });
      }
    });
  }

  void _deleteItem(String itemId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text('Are you sure you want to delete this item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _items.removeWhere((item) => item.id == itemId);
              });

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Item has been deleted.'),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('DELETE'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Try to get an item that might have been passed as a result
    final item = ModalRoute.of(context)?.settings.arguments as Item?;

    // If an item was passed, update the list
    if (item != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          final index = _items.indexWhere((i) => i.id == item.id);
          if (index >= 0) {
            _items[index] = item;
          } else {
            _items.add(item);
          }
        });

        // Clear the arguments to prevent re-adding
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            settings: const RouteSettings(name: AddItemPage.route),
            builder: (context) => const AddItemPage(),
          ),
        );
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xffD6E6F2),
      appBar: AppBar(
        title: const Text(
          'Item Management',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: GlobalStyle.primaryColor),
            onPressed: () {
              // Implement search functionality
            },
          ),
          IconButton(
            icon: Icon(Icons.filter_list, color: GlobalStyle.primaryColor),
            onPressed: () {
              // Implement filter functionality
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Belum Ada Item',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tambahkan item untuk mulai berjualan',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _addNewItem,
              icon: const Icon(Icons.add),
              label: const Text('Tambah Item Baru'),
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
            ),
          ],
        ),
      )
          : FadeTransition(
        opacity: _fadeAnimation,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _items.length,
          itemBuilder: (context, index) {
            final item = _items[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              child: InkWell(
                onTap: () => _editItem(item),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(
                            image: item.imageUrl.startsWith('assets/')
                                ? AssetImage(item.imageUrl) as ImageProvider
                                : FileImage(File(item.imageUrl)),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
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
                              'Rp ${item.price.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 14,
                                color: GlobalStyle.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: item.status == 'Available'
                                        ? Colors.green[50]
                                        : item.status == 'Out of Stock'
                                        ? Colors.red[50]
                                        : Colors.orange[50],
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: item.status == 'Available'
                                              ? Colors.green
                                              : item.status == 'Out of Stock'
                                              ? Colors.red
                                              : Colors.orange,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        item.status,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: item.status == 'Available'
                                              ? Colors.green[700]
                                              : item.status == 'Out of Stock'
                                              ? Colors.red[700]
                                              : Colors.orange[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Stock: ${item.quantity}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert,
                          color: Colors.grey[600],
                        ),
                        onSelected: (value) {
                          if (value == 'edit') {
                            _editItem(item);
                          } else if (value == 'delete') {
                            _deleteItem(item.id);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, size: 20),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outlined, size: 20, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Delete', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: _items.isEmpty
          ? null
          : FloatingActionButton(
        onPressed: _addNewItem,
        backgroundColor: GlobalStyle.primaryColor,
        child: const Icon(Icons.add),
      ),
    );
  }
}