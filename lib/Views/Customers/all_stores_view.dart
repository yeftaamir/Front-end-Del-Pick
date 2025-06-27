// File: Views/Customers/all_stores_view.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Models/store.dart';
import 'package:del_pick/Views/Customers/store_detail.dart';
import 'package:del_pick/Services/image_service.dart';
import 'package:del_pick/Views/Controls/internet_connectivity_wrapper.dart';

class AllStoresView extends StatefulWidget {
  static const String route = "/all-stores";

  final List<StoreModel> stores;

  const AllStoresView({
    Key? key,
    required this.stores,
  }) : super(key: key);

  @override
  State<AllStoresView> createState() => _AllStoresViewState();
}

class _AllStoresViewState extends State<AllStoresView> {
  final TextEditingController _searchController = TextEditingController();
  List<StoreModel> _filteredStores = [];
  String _searchQuery = '';
  String _sortBy = 'name'; // name, rating, distance

  @override
  void initState() {
    super.initState();
    _filteredStores = widget.stores;
    _sortStores();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterStores(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredStores = widget.stores;
      } else {
        _filteredStores = widget.stores.where((store) {
          return store.name.toLowerCase().contains(query.toLowerCase()) ||
              store.address.toLowerCase().contains(query.toLowerCase()) ||
              store.description.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
      _sortStores();
    });
  }

  void _sortStores() {
    setState(() {
      switch (_sortBy) {
        case 'name':
          _filteredStores.sort((a, b) => a.name.compareTo(b.name));
          break;
        case 'rating':
          _filteredStores.sort((a, b) => b.rating.compareTo(a.rating));
          break;
        case 'distance':
          _filteredStores.sort((a, b) {
            if (a.distance == null && b.distance == null) return 0;
            if (a.distance == null) return 1;
            if (b.distance == null) return -1;
            return a.distance!.compareTo(b.distance!);
          });
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Semua Toko',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: GlobalStyle.fontFamily,
          ),
        ),
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(LucideIcons.filter, color: Colors.black87),
            onSelected: (value) {
              setState(() {
                _sortBy = value;
              });
              _sortStores();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'name',
                child: Row(
                  children: [
                    Icon(LucideIcons.arrowUpAZ, size: 16),
                    SizedBox(width: 8),
                    Text('Urutkan A-Z'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'rating',
                child: Row(
                  children: [
                    Icon(Icons.star, size: 16),
                    SizedBox(width: 8),
                    Text('Rating Tertinggi'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'distance',
                child: Row(
                  children: [
                    Icon(LucideIcons.mapPin, size: 16),
                    SizedBox(width: 8),
                    Text('Terdekat'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _filterStores,
              decoration: InputDecoration(
                hintText: 'Cari toko...',
                hintStyle: TextStyle(
                  color: Colors.grey[400],
                  fontFamily: GlobalStyle.fontFamily,
                ),
                prefixIcon: Icon(
                  LucideIcons.search,
                  color: Colors.grey[400],
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          LucideIcons.x,
                          color: Colors.grey[400],
                        ),
                        onPressed: () {
                          _searchController.clear();
                          _filterStores('');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
          ),

          // Store Count and Sort Info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '${_filteredStores.length} toko ditemukan',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
                const Spacer(),
                Text(
                  'Diurutkan: ${_getSortLabel()}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Store List
          Expanded(
            child: _filteredStores.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredStores.length,
                    itemBuilder: (context, index) {
                      return _buildStoreCard(_filteredStores[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _getSortLabel() {
    switch (_sortBy) {
      case 'name':
        return 'Nama A-Z';
      case 'rating':
        return 'Rating';
      case 'distance':
        return 'Jarak';
      default:
        return 'Nama';
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.searchX,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Tidak ada toko yang ditemukan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
                fontFamily: GlobalStyle.fontFamily,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Coba gunakan kata kunci yang berbeda',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
                fontFamily: GlobalStyle.fontFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreCard(StoreModel store) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            StoreDetail.route,
            arguments: {
              'storeId': store.storeId,
              'storeName': store.name,
            },
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 180,
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                color: Colors.grey[300],
              ),
              child: Stack(
                children: [
                  if (store.imageUrl != null && store.imageUrl!.isNotEmpty)
                    ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(12)),
                      child: Image.network(
                        store.imageUrl!,
                        width: double.infinity,
                        height: 180,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: double.infinity,
                            height: 180,
                            color: Colors.grey[300],
                            child: Icon(
                              LucideIcons.imageOff,
                              color: Colors.grey[600],
                              size: 50,
                            ),
                          );
                        },
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      height: 180,
                      color: Colors.grey[300],
                      child: Icon(
                        LucideIcons.store,
                        color: Colors.grey[600],
                        size: 50,
                      ),
                    ),
                  if (store.rating > 0)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.yellow,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              store.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (store.distance != null)
                    Positioned(
                      bottom: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: GlobalStyle.primaryColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${store.distance!.toStringAsFixed(1)} km',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    store.name,
                    style: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      fontFamily: GlobalStyle.fontFamily,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.store,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${store.reviewCount} ulasan • ${store.totalProducts} menu',
                        style: TextStyle(
                          fontSize: 14.0,
                          color: Colors.grey[600],
                          fontFamily: GlobalStyle.fontFamily,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: store.status.name == 'active'
                              ? Colors.green.withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          store.status.name == 'active' ? 'Buka' : 'Tutup',
                          style: TextStyle(
                            fontSize: 12,
                            color: store.status.name == 'active'
                                ? Colors.green[700]
                                : Colors.red[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (store.description.isNotEmpty) ...[
                    Text(
                      store.description,
                      style: TextStyle(
                        fontSize: 14.0,
                        color: Colors.grey[600],
                        fontFamily: GlobalStyle.fontFamily,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          store.address,
                          style: TextStyle(
                            fontSize: 14.0,
                            color: Colors.grey[600],
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        LucideIcons.clock,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${store.openTime} - ${store.closeTime}',
                        style: TextStyle(
                          fontSize: 14.0,
                          color: Colors.grey[600],
                          fontFamily: GlobalStyle.fontFamily,
                        ),
                      ),
                      if (store.phone.isNotEmpty) ...[
                        const Spacer(),
                        Icon(
                          LucideIcons.phone,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          store.phone,
                          style: TextStyle(
                            fontSize: 12.0,
                            color: Colors.grey[600],
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
