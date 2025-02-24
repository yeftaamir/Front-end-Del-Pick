import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:del_pick/Views/Customers/home_cust.dart';
import 'package:del_pick/Views/Customers/history_cust.dart';

class CustomBottomNavigation extends StatefulWidget {
  final int selectedIndex;

  final Function(int) onItemTapped;

  const CustomBottomNavigation({
    Key? key,
    required this.selectedIndex,
    required this.onItemTapped,
  }) : super(key: key);

  @override
  State<CustomBottomNavigation> createState() => _CustomBottomNavigationState();
}

class _CustomBottomNavigationState extends State<CustomBottomNavigation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  late List<Animation<double>> _animations;

  late int _previousIndex;

  @override
  void initState() {
    super.initState();
    _previousIndex = widget.selectedIndex;

    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _initializeAnimations();
  }

  void _initializeAnimations() {
    _animations = List.generate(2, (index) {
      return Tween<double>(
        begin: index == widget.selectedIndex ? 1.0 : 0.0,
        end: index == widget.selectedIndex ? 1.0 : 0.0,
      ).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(
            index * 0.2,
            0.6 + index * 0.2,
            curve: Curves.easeInOut,
          ),
        ),
      );
    });
  }

  @override
  void didUpdateWidget(CustomBottomNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _previousIndex = oldWidget.selectedIndex;
      _updateAnimations();
    }
  }

  void _updateAnimations() {
    for (int i = 0; i < _animations.length; i++) {
      _animations[i] = Tween<double>(
        begin: i == _previousIndex ? 1.0 : 0.0,
        end: i == widget.selectedIndex ? 1.0 : 0.0,
      ).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(
            i * 0.2,
            0.6 + i * 0.2,
            curve: Curves.easeInOut,
          ),
        ),
      );
    }
    _controller.forward(from: 0.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleNavigation(BuildContext context, int index) async {
    if (index == widget.selectedIndex) return;

    widget.onItemTapped(index);
    _previousIndex = widget.selectedIndex;

    _updateAnimations();
    switch (index) {
      case 0:
        await Navigator.pushReplacementNamed(
          context,
          HomePage.route,
          arguments: RouteSettings(name: HomePage.route),
        );
        break;
      case 1:
        await Navigator.pushReplacementNamed(
          context,
          HistoryCustomer.route,
          arguments: RouteSettings(name: HistoryCustomer.route),
        );
        break;
    }
  }

  BottomNavigationBarItem _buildAnimatedNavItem(
      int index,
      IconData icon,
      String label,
      ) {
    return BottomNavigationBarItem(
      icon: AnimatedBuilder(
        animation: _animations[index],
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _animations[index].value * -4),
            child: Transform.scale(
              scale: 1.0 + (_animations[index].value * 0.2),
              child: Icon(
                icon,
                color: _animations[index].value > 0.5
                    ? Colors.blue
                    : Colors.grey,
              ),
            ),
          );
        },
      ),
      activeIcon: Icon(
        icon,
        color: Colors.blue,
      ),
      label: label,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return BottomNavigationBar(
            currentIndex: widget.selectedIndex,
            onTap: (index) => _handleNavigation(context, index),
            selectedItemColor: Colors.blue,
            unselectedItemColor: Colors.grey,
            showUnselectedLabels: true,
            type: BottomNavigationBarType.fixed,
            selectedFontSize: 12,
            unselectedFontSize: 12,
            items: [
              _buildAnimatedNavItem(0, LucideIcons.home, 'Home'),
              _buildAnimatedNavItem(1, LucideIcons.history, 'History'),
            ],
          );
        },
      ),
    );
  }
}

class FadePageTransition extends PageTransitionsBuilder {
  @override
  Widget buildTransitions<T>(
      PageRoute<T> route,
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
      ) {
    return FadeTransition(
      opacity: animation.drive(
        CurveTween(curve: Curves.easeInOut),
      ),
      child: child,
    );
  }
}