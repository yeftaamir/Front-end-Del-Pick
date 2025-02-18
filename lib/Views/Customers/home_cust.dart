import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:del_pick/Common/global_style.dart';
import 'store_detail.dart';
import 'profile_cust.dart';
import 'history_cust.dart';

class Store {
  final String name;
  final String address;
  final String imageUrl;
  final double rating;
  final String category;

  Store({
    required this.name,
    required this.address,
    required this.imageUrl,
    this.rating = 0.0,
    required this.category,
  });
}

class HomePage extends StatefulWidget {
  static const String route = "/Customers/HomePage";
  const HomePage({super.key});

  @override
  createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<Store> _stores = [
    Store(
      name: 'Nama Toko',
      address: 'Alamat Toko',
      imageUrl: 'assets/store_placeholder.png',
      rating: 4.5,
      category: 'Restaurant',
    ),
    Store(
      name: 'Nama Toko',
      address: 'Alamat Toko',
      imageUrl: 'assets/store_placeholder.png',
      rating: 4.8,
      category: 'Cafe',
    ),
    Store(
      name: 'Nama Toko',
      address: 'Alamat Toko',
      imageUrl: 'assets/store_placeholder.png',
      rating: 4.2,
      category: 'Shop',
    ),
  ];

  List<Store> get filteredStores {
    if (_searchQuery.isEmpty && !_isSearching) {
      return _stores;
    }
    return _stores
        .where((store) =>
    store.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        store.address.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      if (index == 1) {
        _startSearch();
      } else if (index == 2) {
        Navigator.pushNamed(context, HistoryCustomer.route);
      }
    });
  }

  void _startSearch() {
    setState(() {
      _isSearching = true;
    });
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: Colors.white,
        leading: _isSearching ? IconButton(
        icon: Container(
                  padding: const EdgeInsets.all(7.0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.blue, width: 1.0),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new, color: Colors.blue, size: 18),
                ),
                onPressed: () {
                  setState(() {
                    _isSearching = false;
                    _searchController.clear();
                    _searchQuery = '';
                  });
                },
              )
            : IconButton(
          icon: const Icon(Icons.search, color: Colors.black54),
          onPressed: () {
            _startSearch();
          },
        ),
        title: _isSearching
            ? TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Cari toko...',
            border: InputBorder.none,
            hintStyle: TextStyle(
              color: GlobalStyle.fontColor,
              fontSize: GlobalStyle.fontSize,
            ),
          ),
          style: TextStyle(
            color: GlobalStyle.fontColor,
            fontSize: GlobalStyle.fontSize,
          ),
        )
            : const Text(
          'Del Pick',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: IconButton(
              icon: const Icon(LucideIcons.user, color: Colors.black54),
              onPressed: () {
                Navigator.pushNamed(context, ProfilePage.route);
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isSearching && _searchQuery.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  'Ketik untuk mencari toko...',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          if (!_isSearching || _searchQuery.isNotEmpty)
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: filteredStores.length,
                itemBuilder: (context, index) {
                  final store = filteredStores[index];
                  return buildStoreCard(store);
                },
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.search),
              label: 'Search',
            ),
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.history),
              label: 'History',
            ),
          ],
        ),
      ),
    );
  }

  Widget buildStoreCard(Store store) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      elevation: 0,
      color: const Color.fromARGB(255, 177, 215, 235),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(context, StoreDetail.route);
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // Store Image
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8.0),
                  color: Colors.grey[200],
                ),
                child: const Icon(
                  Icons.store,
                  size: 40,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(width: 12.0),
              // Store Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.name,
                      style: const TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      store.address,
                      style: TextStyle(
                        fontSize: 14.0,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 4.0,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(4.0),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.star,
                                size: 16.0,
                                color: Colors.blue[700],
                              ),
                              const SizedBox(width: 4.0),
                              Text(
                                store.rating.toString(),
                                style: TextStyle(
                                  fontSize: 12.0,
                                  color: Colors.blue[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 4.0,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(4.0),
                          ),
                          child: Text(
                            store.category,
                            style: TextStyle(
                              fontSize: 12.0,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Visit Button
              Container(
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 8.0,
                  ),
                  child: Text(
                    'Kunjungi Toko',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.0,
                      fontWeight: FontWeight.bold,
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
}