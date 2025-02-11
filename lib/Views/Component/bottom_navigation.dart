import 'package:flutter/material.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Views/Store/add_item.dart';
import 'package:del_pick/Views/Store/history_store.dart'; // Added import for history page

class BottomNavigationComponent extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  const BottomNavigationComponent({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  void _handleNavigation(BuildContext context, int index) {
    onTap(index);
    // Prevent navigation if we're already on the selected page
    if (index == currentIndex) return;
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/Store/HomePage');
        break;
      case 1:
        Navigator.pushReplacementNamed(context, AddItemPage.route);
        break;
      case 2:
        Navigator.pushReplacementNamed(context, HistoryStorePage.route); // Updated to use history page route
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => _handleNavigation(context, index),
        selectedItemColor: GlobalStyle.primaryColor,
        unselectedItemColor: GlobalStyle.fontColor,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_box),
            label: 'Add Item',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
    );
  }
}