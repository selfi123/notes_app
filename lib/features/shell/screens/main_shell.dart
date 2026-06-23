import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_theme.dart';

class MainShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  void _onTap(BuildContext context, int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: navigationShell.currentIndex,
          backgroundColor: Colors.transparent,
          elevation: 0,
          onTap: (index) => _onTap(context, index),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.amber,
          unselectedItemColor: AppColors.textMuted,
          items: [
            BottomNavigationBarItem(
              icon: Icon(PhosphorIcons.users(PhosphorIconsStyle.light)),
              activeIcon: Icon(PhosphorIcons.users(PhosphorIconsStyle.fill)),
              label: 'Contacts',
            ),
            BottomNavigationBarItem(
              icon: Icon(PhosphorIcons.notebook(PhosphorIconsStyle.light)),
              activeIcon: Icon(PhosphorIcons.notebook(PhosphorIconsStyle.fill)),
              label: 'Notes',
            ),
            BottomNavigationBarItem(
              icon: Icon(PhosphorIcons.crown(PhosphorIconsStyle.light)),
              activeIcon: Icon(PhosphorIcons.crown(PhosphorIconsStyle.fill)),
              label: 'Premium',
            ),
            BottomNavigationBarItem(
              icon: Icon(PhosphorIcons.gear(PhosphorIconsStyle.light)),
              activeIcon: Icon(PhosphorIcons.gear(PhosphorIconsStyle.fill)),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
