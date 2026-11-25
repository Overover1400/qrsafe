import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import 'widgets/recent_activity_list.dart';
import 'widgets/scan_hero_button.dart';

/// The teal-themed home screen: wordmark + settings gear, the scan hero, the
/// recent-activity list, and a bottom nav. "Scan" and "Account" route out;
/// "History" is a placeholder for a later phase.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.qrColors;
    return Scaffold(
      backgroundColor: c.canvas,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(),
              const SizedBox(height: 24),
              ScanHeroButton(onTap: () => context.push('/scan')),
              const SizedBox(height: 16),
              _DocumentScanTile(onTap: () => context.push('/document')),
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

/// Secondary action under the hero: photograph a paper document and keep it as
/// a PDF. Kept off the bottom nav, which is already full.
class _DocumentScanTile extends StatelessWidget {
  const _DocumentScanTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.qrColors;
    return Material(
      color: Colors.white.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Icon(Icons.document_scanner_rounded, color: c.accent),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scan a document',
                      style: TextStyle(
                        color: c.inkDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Photograph a page and save it as a PDF',
                      style: TextStyle(color: c.inkLight, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: c.inkTint),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.qrColors;
    return Row(
      children: [
        Icon(Icons.qr_code_scanner_rounded, color: c.teal, size: 28),
        const SizedBox(width: 8),
        Text(
          'QRSafe',
          style: TextStyle(
            color: c.inkDark,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Settings',
          icon: Icon(Icons.settings_rounded, color: c.inkMid),
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
      selectedItemColor: c.teal,
      unselectedItemColor: c.inkLight,
      showUnselectedLabels: true,
      onTap: (index) {
        switch (index) {
          case 1:
            context.push('/create');
          case 2:
            context.push('/scan');
          case 3:
            context.push('/link');
          case 4:
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
          icon: Icon(Icons.add_circle_outline_rounded),
          label: 'Create',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.qr_code_scanner_rounded),
          label: 'Scan',
        ),
        // The saved-codes dashboard moved to Settings; this slot is the
        // short-link tool, which is what she reaches for daily.
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
