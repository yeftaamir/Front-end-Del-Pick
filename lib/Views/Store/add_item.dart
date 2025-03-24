import 'package:del_pick/Views/Store/home_store.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../Common/global_style.dart';
import '../../Models/item_model.dart';
import '../Component/bottom_navigation.dart';
import 'add_edit_items.dart';

class AddItemPage extends StatefulWidget {
  static const String route = '/Store/AddItem';

  const AddItemPage({Key? key}) : super(key: key);

  @override
  State<AddItemPage> createState() => _AddItemPageState();
}

class _AddItemPageState extends State<AddItemPage> with SingleTickerProviderStateMixin {
  int _currentIndex = 1;
  late AnimationController _controller;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<Item> _items = [
    Item(
      id: '1',
      name: 'Item 1',
      description: 'Description for Item 1',
      price: 25000,
      quantity: 10,
      imageUrl: 'assets/images/menu_item.jpg',
      isAvailable: true,
      status: 'Available',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _controller.forward();
    // Memeriksa status ketersediaan berdasarkan jumlah stok saat inisialisasi
    _checkItemsAvailability();
  }

  // Metode untuk memeriksa dan memperbarui status ketersediaan semua item
  void _checkItemsAvailability() {
    for (int i = 0; i < _items.length; i++) {
      if (_items[i].quantity <= 0 && _items[i].isAvailable) {
        _items[i] = _items[i].copyWith(isAvailable: false, status: 'Out of Stock');
      }
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

  void _navigateToAddEditForm({Item? item}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditItemForm(item: item),
      ),
    );

    // Jika item yang diperbarui dikembalikan, perbarui daftar dan periksa ketersediaan
    if (result != null && result is Item) {
      setState(() {
        final index = _items.indexWhere((element) => element.id == result.id);
        if (index != -1) {
          _items[index] = result;
        } else {
          _items.add(result);
        }
        _checkItemsAvailability();
      });
    }
  }

  void _toggleItemStatus(Item item) async {
    if (item.isAvailable) {
      // Jika item saat ini tersedia, maka akan menutup/nonaktifkan item
      await _showClosingDialog(item);
    } else if (!item.isAvailable && item.quantity > 0) {
      // Jika item tidak tersedia tetapi ada stok, langsung aktifkan
      setState(() {
        final index = _items.indexWhere((element) => element.id == item.id);
        if (index != -1) {
          _items[index] = item.copyWith(
              isAvailable: true,
              status: 'Available'
          );
        }
      });
    } else {
      // Jika stok 0 dan mencoba mengaktifkan, tampilkan pesan
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak dapat mengaktifkan produk tanpa stok.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

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
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
      setState(() {
        final index = _items.indexWhere((element) => element.id == item.id);
        if (index != -1) {
          _items[index] = item.copyWith(
              isAvailable: false,
              status: 'Out of Stock'
          );
        }
      });
    }
  }

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
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                    onPressed: () {
                      setState(() {
                        _items.removeWhere((element) => element.id == item.id);
                      });
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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

  Color _getColorWithOpacity(Color color, double opacity) {
    return Color.fromRGBO(
      color.red,
      color.green,
      color.blue,
      opacity,
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
                color: GlobalStyle.primaryColor,
                size: 18
            ),
          ),
          onPressed: () {
            Navigator.push(
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
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          final bool isOutOfStock = item.quantity <= 0;

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
                child: child,
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
                            ClipRRect(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(15),
                                bottomLeft: Radius.circular(15),
                              ),
                              child: Image.asset(
                                item.imageUrl,
                                height: 120,
                                width: 120,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                      'Rp ${item.price.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: GlobalStyle.primaryColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Stok: ${item.quantity}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isOutOfStock ? Colors.red : GlobalStyle.fontColor,
                                        fontWeight: isOutOfStock ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: item.isAvailable
                                            ? _getColorWithOpacity(Colors.green, 0.1)
                                            : _getColorWithOpacity(Colors.red, 0.1),
                                        borderRadius: BorderRadius.circular(12),
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
                                            item.status,
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
                                    if (item.description != null && item.description!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          item.description!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(right: 12.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  // Improved Toggle Button
                                  Container(
                                    width: 70,
                                    height: 30,
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(15),
                                      gradient: LinearGradient(
                                        colors: item.isAvailable
                                            ? [const Color(0xFF43A047), const Color(0xFF66BB6A)]
                                            : [Colors.grey.shade400, Colors.grey.shade300],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: item.isAvailable
                                              ? Colors.green.withOpacity(0.3)
                                              : Colors.grey.withOpacity(0.3),
                                          spreadRadius: 1,
                                          blurRadius: 3,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(15),
                                        onTap: () => _toggleItemStatus(item),
                                        child: Center(
                                          child: Text(
                                            item.isAvailable ? 'BUKA' : 'TUTUP',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Improved Edit Button
                                  Container(
                                    width: 70,
                                    height: 30,
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(15),
                                      gradient: LinearGradient(
                                        colors: [GlobalStyle.primaryColor, GlobalStyle.primaryColor.withOpacity(0.8)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: GlobalStyle.primaryColor.withOpacity(0.3),
                                          spreadRadius: 1,
                                          blurRadius: 3,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(15),
                                        onTap: () => _navigateToAddEditForm(item: item),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: const [
                                            Icon(
                                              Icons.edit,
                                              color: Colors.white,
                                              size: 14,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'EDIT',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Improved Delete Button
                                  Container(
                                    width: 70,
                                    height: 30,
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(15),
                                      gradient: const LinearGradient(
                                        colors: [Colors.red, Color(0xFFF44336)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.red.withOpacity(0.3),
                                          spreadRadius: 1,
                                          blurRadius: 3,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(15),
                                        onTap: () => _showDeleteConfirmation(item),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: const [
                                            Icon(
                                              Icons.delete,
                                              color: Colors.white,
                                              size: 14,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'HAPUS',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
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
                          ],
                        ),
                      ),
                    ),
                    if (!item.isAvailable)
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
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
      bottomNavigationBar: BottomNavigationComponent(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
      ),
    );
  }
}