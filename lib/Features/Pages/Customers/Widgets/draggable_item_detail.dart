// lib/pages/customers/widgets/draggable_item_detail.dart
import 'package:del_pick/Models/Extensions/menu_item_extensions.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../Common/global_style.dart';
import '../../../../Models/Entities/menu_item.dart';

class DraggableItemDetail extends StatefulWidget {
  final MenuItem item;
  final int availableStock;
  final Function(int) onQuantityChanged;
  final VoidCallback onZeroQuantity;
  final VoidCallback onOutOfStock;

  const DraggableItemDetail({
    super.key,
    required this.item,
    required this.availableStock,
    required this.onQuantityChanged,
    required this.onZeroQuantity,
    required this.onOutOfStock,
  });

  @override
  State<DraggableItemDetail> createState() => _DraggableItemDetailState();
}

class _DraggableItemDetailState extends State<DraggableItemDetail> {
  int _quantity = 0;

  @override
  void initState() {
    super.initState();
    // Initialize with current quantity if item is already in cart
    _quantity = 0; // You can pass current cart quantity here if needed
  }

  void _incrementQuantity() {
    if (_quantity < widget.availableStock) {
      setState(() {
        _quantity++;
      });
    } else {
      widget.onOutOfStock();
    }
  }

  void _decrementQuantity() {
    if (_quantity > 0) {
      setState(() {
        _quantity--;
      });
    }
  }

  void _addToCart() {
    if (_quantity > 0) {
      widget.onQuantityChanged(_quantity);
      Navigator.pop(context);
    } else {
      Navigator.pop(context);
      widget.onZeroQuantity();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
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
                _buildDragHandle(),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildItemImage(),
                      const SizedBox(height: 16),
                      _buildItemInfo(),
                      const SizedBox(height: 16),
                      _buildDescription(),
                      const SizedBox(height: 24),
                      _buildQuantitySelector(),
                      const SizedBox(height: 24),
                      _buildAddToCartButton(),
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

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildItemImage() {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: widget.item.imageUrl ?? '',
          fit: BoxFit.contain,
          placeholder: (context, url) => Container(
            color: Colors.grey[200],
            child: const Center(
              child: Icon(Icons.restaurant_menu, size: 60, color: Colors.grey),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: Colors.grey[200],
            child: const Center(
              child: Icon(Icons.restaurant_menu, size: 60, color: Colors.grey),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemInfo() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.item.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.item.formattedPrice,
                style: TextStyle(
                  fontSize: 18,
                  color: GlobalStyle.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: widget.availableStock > 0
                ? Colors.green.withOpacity(0.1)
                : Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 14,
                color: widget.availableStock > 0 ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 4),
              Text(
                'Stok: ${widget.availableStock}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: widget.availableStock > 0 ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Deskripsi',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.item.description ?? 'Tidak ada deskripsi tersedia untuk produk ini.',
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildQuantitySelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildQuantityButton(
          icon: Icons.remove_circle_outline,
          onPressed: _quantity > 0 ? _decrementQuantity : null,
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$_quantity',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        _buildQuantityButton(
          icon: Icons.add_circle_outline,
          onPressed: _quantity < widget.availableStock ? _incrementQuantity : null,
        ),
      ],
    );
  }

  Widget _buildQuantityButton({
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
        color: onPressed != null ? GlobalStyle.primaryColor : Colors.grey,
        iconSize: 32,
        style: IconButton.styleFrom(
          backgroundColor: Colors.white,
          shape: const CircleBorder(),
        ),
      ),
    );
  }

  Widget _buildAddToCartButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _addToCart,
        style: ElevatedButton.styleFrom(
          backgroundColor: GlobalStyle.primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shopping_cart_outlined, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              _quantity > 0
                  ? 'Tambah $_quantity ke keranjang'
                  : 'Tambah ke keranjang',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}