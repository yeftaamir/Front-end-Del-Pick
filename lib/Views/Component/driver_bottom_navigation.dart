import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:del_pick/Common/global_style.dart';

class DriverBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const DriverBottomNavigation({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  void _handleNavigation(BuildContext context, int index) {
    if (currentIndex != index) {
      onTap(index);
       backgroundColor: Colors.white;
      switch (index) {
        case 0: // Home tab
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/Driver/HomePage',
                (route) => false,
          );
          break;
        case 1: // History tab
          if (ModalRoute.of(context)?.settings.name != '/Driver/HistoryDriver') {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/Driver/HistoryDriver',
                  (route) => false,
            );
          }
          break;
      }
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
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => _handleNavigation(context, index),
        selectedItemColor: GlobalStyle.primaryColor,
        unselectedItemColor: GlobalStyle.fontColor,
        selectedLabelStyle: TextStyle(
          fontFamily: GlobalStyle.fontFamily,
          fontSize: GlobalStyle.fontSize,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: GlobalStyle.fontFamily,
          fontSize: GlobalStyle.fontSize,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.history),
            label: 'History',
          ),
        ],
      ),
    );
  }
}