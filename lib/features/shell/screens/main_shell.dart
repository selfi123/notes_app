import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

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
              icon: Icon(PhosphorIconsLight.users),
              activeIcon: Icon(PhosphorIconsFill.users),
              label: 'Contacts',
            ),
            BottomNavigationBarItem(
              icon: Icon(PhosphorIconsLight.notebook),
              activeIcon: Icon(PhosphorIconsFill.notebook),
              label: 'Notes',
            ),
            BottomNavigationBarItem(
              icon: Icon(PhosphorIconsLight.crown),
              activeIcon: Icon(PhosphorIconsFill.crown),
              label: 'Premium',
            ),
            BottomNavigationBarItem(
              icon: Icon(PhosphorIconsLight.gear),
              activeIcon: Icon(PhosphorIconsFill.gear),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
