import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

/// The app's bottom navigation, shared by every screen that is a destination
/// rather than a detail page.
///
/// It lives in one place because it has to look identical everywhere: it used
/// to exist only on Home, so opening "Create" made the bar disappear.
///
/// Scan is deliberately a full-screen camera with no bar of its own.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.currentIndex});

  /// Which destination is showing: 0 Home, 1 Create, 2 Scan, 3 Link,
  /// 4 Account.
  final int currentIndex;

  static const _paths = ['/home', '/create', '/scan', '/link', '/settings'];

  void _onTap(BuildContext context, int index) {
    if (index == currentIndex) return;
    final path = _paths[index];

    if (index == 0) {
      // Home is the root. Going there rather than pushing keeps a single copy
      // of it at the bottom of the stack however long she taps around.
      context.go(path);
    } else if (currentIndex == 0) {
      // From Home, push: Back then returns to Home, as the hardware button
      // should.
      context.push(path);
    } else {
      // Between two destinations, swap one for the other so the stack stays
      // Home → wherever she is, and Back still reaches Home.
      context.pushReplacement(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.qrColors;
    return BottomNavigationBar(
      currentIndex: currentIndex,
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: c.teal,
      unselectedItemColor: c.inkLight,
      showUnselectedLabels: true,
      onTap: (index) => _onTap(context, index),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_rounded),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.add_circle_outline_rounded),
          label: 'Create',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.qr_code_scanner_rounded),
          label: 'Scan',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.link_rounded),
          label: 'Link',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_rounded),
          label: 'Account',
        ),
      ],
    );
  }
}
