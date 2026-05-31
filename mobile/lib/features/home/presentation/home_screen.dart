import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import 'widgets/recent_activity_list.dart';
import 'widgets/scan_hero_button.dart';

/// The peach-themed home screen: wordmark + settings gear, the scan hero, the
/// recent-activity list, and a bottom nav. "Scan" and "Account" route out;
/// "History" is a placeholder for a later phase.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.qrColors;
    return Scaffold(
      backgroundColor: c.cream,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(),
              const SizedBox(height: 24),
              ScanHeroButton(onTap: () => context.push('/scan')),
              const SizedBox(height: 28),
              const RecentActivityList(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _BottomNav(),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.qrColors;
    return Row(
      children: [
        Icon(Icons.shield_rounded, color: c.peach, size: 28),
        const SizedBox(width: 8),
        Text(
          'QRSafe',
          style: TextStyle(
            color: c.brownDark,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Settings',
          icon: Icon(Icons.settings_rounded, color: c.brownMid),
          onPressed: () => context.push('/settings'),
        ),
      ],
    );
  }
}

class _BottomNav extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.qrColors;
    return BottomNavigationBar(
      currentIndex: 0,
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: c.peach,
      unselectedItemColor: c.brownLight,
      showUnselectedLabels: true,
      onTap: (index) {
        switch (index) {
          case 1:
            context.push('/scan');
          case 2:
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('History is coming soon.')),
            );
          case 3:
            context.push('/settings');
          case 0:
          default:
            break; // already home
        }
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_rounded),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.qr_code_scanner_rounded),
          label: 'Scan',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.history_rounded),
          label: 'History',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_rounded),
          label: 'Account',
        ),
      ],
    );
  }
}
