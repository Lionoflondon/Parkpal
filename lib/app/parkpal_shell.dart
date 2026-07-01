import 'package:flutter/material.dart';

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
    if (index == 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account is coming soon.')),
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
      const SizedBox.shrink(),
    ];

    return Scaffold(
      body: SafeArea(child: pages[_selectedIndex]),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onDestinationSelected,
            backgroundColor: Colors.white.withValues(alpha: 0.94),
            indicatorColor: ParkPalColors.mint100,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.document_scanner_outlined),
                selectedIcon: Icon(Icons.document_scanner),
                label: 'Scan',
              ),
              NavigationDestination(
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history),
                label: 'History',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Account',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
