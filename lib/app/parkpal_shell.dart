import 'package:flutter/material.dart';

import '../features/parking_query/parking_home_screen.dart';
import '../features/parking_query/parking_result_screen.dart';
import '../features/placeholders/saved_locations_screen.dart';
import '../features/placeholders/scan_sign_screen.dart';
import '../features/placeholders/settings_screen.dart';

class ParkPalShell extends StatefulWidget {
  const ParkPalShell({super.key});

  @override
  State<ParkPalShell> createState() => _ParkPalShellState();
}

class _ParkPalShellState extends State<ParkPalShell> {
  int _selectedIndex = 0;

  void _selectTab(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      ParkingHomeScreen(onOpenScan: () => _selectTab(1)),
      const ScanSignScreen(),
      const ParkingResultScreen(),
      const SavedLocationsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('ParkPal')),
      body: SafeArea(child: screens[_selectedIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectTab,
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
            icon: Icon(Icons.local_parking_outlined),
            selectedIcon: Icon(Icons.local_parking),
            label: 'Result',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_border),
            selectedIcon: Icon(Icons.bookmark),
            label: 'Saved',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
