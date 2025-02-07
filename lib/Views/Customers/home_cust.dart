import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:del_pick/Common/global_style.dart';
import 'store_detail.dart';
import 'profile_cust.dart';
import 'history_cust.dart';

class Store {
  final String name;
  final String category;
  final IconData icon;

  Store({
    required this.name,
    required this.category,
    required this.icon,
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
    Store(name: 'Nama Toko', category: 'Kategori', icon: Icons.home),
    Store(name: 'Nama Rumah Makan', category: 'Kategori', icon: Icons.restaurant),
    Store(name: 'Nama Minimarket', category: 'Kategori', icon: Icons.store),
  ];

  List<Store> get filteredStores {
    if (_searchQuery.isEmpty && !_isSearching) {
      return _stores;
    }
    return _stores
        .where((store) =>
    store.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        store.category.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  String _capitalizeEachWord(String text) {
  return text.split(' ').map((word) {
    return word.isNotEmpty
        ? word[0].toUpperCase() + word.substring(1).toLowerCase()
        : '';
  }).join(' ');
}

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      if (index == 1) {
        // Index 1 is the 'Search' button
        _startSearch();
      } else if (index == 2) { // Index 2 is the 'History' button
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
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: _isSearching
            ? IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black54),
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
            hintText: 'Search stores...',
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
            : null,
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_isSearching && _searchQuery.isEmpty)
              const Center(
                child: Text(
                  'Type to search stores...',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),
              ),
            if (!_isSearching || _searchQuery.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: filteredStores.length,
                  itemBuilder: (context, index) {
                    final store = filteredStores[index];
                    return buildInfoCard(store);
                  },
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: GlobalStyle.primaryColor,
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
    );
  }

  Widget buildInfoCard(Store store) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 15.0),
    child: Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(store.icon, size: 50.0, color: Colors.blue),
            const SizedBox(width: 18.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _capitalizeEachWord(store.name),
                    style: const TextStyle(
                      fontSize: 15.0,
                      fontWeight: FontWeight.normal,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    store.category,
                    style: const TextStyle(
                      fontSize: 12.0,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios, size: 16.0, color: Colors.blue),
              onPressed: () {
                Navigator.pushNamed(context, StoreDetail.route);
              },
            ),
          ],
        ),
      ),
    ),
  );
}
}
