import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:del_pick/Views/Store/add_item.dart';
import 'package:del_pick/Views/Store/history_store.dart';

/// A custom animated bottom navigation component that provides smooth transitions
/// and animations when switching between tabs.
class BottomNavigationComponent extends StatefulWidget {
  /// The current selected index in the bottom navigation bar
  final int currentIndex;

  /// Callback function when a tab is tapped
  final Function(int) onTap;

  const BottomNavigationComponent({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  @override
  State<BottomNavigationComponent> createState() => _BottomNavigationComponentState();
}

class _BottomNavigationComponentState extends State<BottomNavigationComponent>
    with SingleTickerProviderStateMixin {
  /// Controller for managing the animations
  late AnimationController _controller;

  /// List of animations for each navigation item
  late List<Animation<double>> _animations;

  /// The previous selected index, used for animation direction
  late int _previousIndex;

  @override
  void initState() {
    super.initState();
    _previousIndex = widget.currentIndex;

    // Initialize the animation controller
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    // Create animations for each navigation item
    _initializeAnimations();
  }

  /// Initialize animations for each bottom navigation item
  void _initializeAnimations() {
    _animations = List.generate(3, (index) {
      return Tween<double>(
        begin: index == widget.currentIndex ? 1.0 : 0.0,
        end: index == widget.currentIndex ? 1.0 : 0.0,
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
  void didUpdateWidget(BottomNavigationComponent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _previousIndex = oldWidget.currentIndex;
      _updateAnimations();
    }
  }

  /// Update animations when the selected index changes
  void _updateAnimations() {
    for (int i = 0; i < _animations.length; i++) {
      _animations[i] = Tween<double>(
        begin: i == _previousIndex ? 1.0 : 0.0,
        end: i == widget.currentIndex ? 1.0 : 0.0,
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

  /// Handle navigation when a tab is tapped
  void _handleNavigation(BuildContext context, int index) async {
    if (index == widget.currentIndex) return;

    widget.onTap(index);
    _previousIndex = widget.currentIndex;

    // Update and run animations
    _updateAnimations();

    // Navigate to the appropriate page with fade transition
    switch (index) {
      case 0:
        await Navigator.pushReplacementNamed(
          context,
          '/Store/HomePage',
          arguments: const RouteSettings(name: '/Store/HomePage'),
        );
        break;
      case 1:
        await Navigator.pushReplacementNamed(
          context,
          AddItemPage.route,
          arguments: RouteSettings(name: AddItemPage.route),
        );
        break;
      case 2:
        await Navigator.pushReplacementNamed(
          context,
          HistoryStorePage.route,
          arguments: RouteSettings(name: HistoryStorePage.route),
        );
        break;
    }
  }

  /// Build an animated navigation item
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
            currentIndex: widget.currentIndex,
            onTap: (index) => _handleNavigation(context, index),
            selectedItemColor: Colors.blue,
            unselectedItemColor: Colors.grey,
            showUnselectedLabels: true,
            type: BottomNavigationBarType.fixed,
            selectedFontSize: 12,
            unselectedFontSize: 12,
            items: [
              _buildAnimatedNavItem(0, LucideIcons.home, 'Home'),
              _buildAnimatedNavItem(1, LucideIcons.plusSquare, 'Add Item'),
              _buildAnimatedNavItem(2, LucideIcons.history, 'History'),
            ],
          );
        },
      ),
    );
  }
}

/// Custom page transition builder for fade transitions
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