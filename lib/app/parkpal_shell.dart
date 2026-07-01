import 'package:flutter/material.dart';

import '../features/account/account_screen.dart';
import '../features/history/parking_history_screen.dart';
import '../features/parking_query/parking_home_screen.dart';
import '../features/scan/scan_coming_soon_screen.dart';
import 'parkpal_theme.dart';

class ParkPalShell extends StatefulWidget {
  const ParkPalShell({super.key});

  @override
  State<ParkPalShell> createState() => _ParkPalShellState();
}

class _ParkPalShellState extends State<ParkPalShell> {
  int _selectedIndex = 0;

  void _onDestinationSelected(int index) {
    if (index == 1) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ScanComingSoonScreen()),
      );
      return;
    }
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      ParkingHomeScreen(
        onOpenScan: () => _onDestinationSelected(1),
        onOpenHistory: () => setState(() => _selectedIndex = 2),
      ),
      const SizedBox.shrink(),
      const ParkingHistoryScreen(),
      const AccountScreen(),
    ];

    return Scaffold(
      body: SafeArea(child: pages[_selectedIndex]),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: ParkPalColors.lineSoft),
            boxShadow: [
              BoxShadow(
                color: ParkPalColors.midnight.withValues(alpha: 0.13),
                blurRadius: 28,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onDestinationSelected,
              height: 72,
              backgroundColor: Colors.white.withValues(alpha: 0.88),
              indicatorColor: ParkPalColors.mint100,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_rounded),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.center_focus_strong_rounded),
                  selectedIcon: Icon(Icons.center_focus_strong_rounded),
                  label: 'Scan',
                ),
                NavigationDestination(
                  icon: Icon(Icons.receipt_long_rounded),
                  selectedIcon: Icon(Icons.receipt_long_rounded),
                  label: 'Vault',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_rounded),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: 'Account',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
