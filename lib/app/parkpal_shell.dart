import 'package:flutter/material.dart';

import '../features/account/account_screen.dart';
import '../features/atlas_intelligence/customer_atlas_screen.dart';
import '../features/dashboard/customer_dashboard_screen.dart';
import '../features/history/parking_history_screen.dart';
import '../features/parking_query/parking_home_screen.dart';
import '../features/scan/scan_coming_soon_screen.dart';
import 'parkpal_platform_routes.dart';
import 'parkpal_theme.dart';

class ParkPalShell extends StatefulWidget {
  const ParkPalShell({
    required this.routeName,
    super.key,
  });

  final String routeName;

  @override
  State<ParkPalShell> createState() => _ParkPalShellState();
}

class _ParkPalShellState extends State<ParkPalShell> {
  late String _routeName = _normalAppRoute(widget.routeName);

  @override
  void didUpdateWidget(covariant ParkPalShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.routeName != oldWidget.routeName) {
      _routeName = _normalAppRoute(widget.routeName);
    }
  }

  void _go(String route) {
    setState(() => _routeName = _normalAppRoute(route));
    Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 980;
    final current = _destinationForRoute(_routeName);
    final page = _pageFor(_routeName);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              ParkPalColors.cream,
              ParkPalColors.mint50,
              ParkPalColors.porcelain,
            ],
          ),
        ),
        child: SafeArea(
          child: wide
              ? Row(
                  children: [
                    _AppRail(current: current, onNavigate: _go),
                    Expanded(child: page),
                  ],
                )
              : page,
        ),
      ),
      bottomNavigationBar:
          wide ? null : _MobileAppNav(current: current, onNavigate: _go),
    );
  }

  Widget _pageFor(String route) {
    return switch (route) {
      ParkPalPlatformRoutes.dashboard => CustomerDashboardScreen(
          onNavigate: _go,
        ),
      ParkPalPlatformRoutes.map => CustomerAtlasScreen(
          onNavigate: _go,
        ),
      ParkPalPlatformRoutes.find => ParkingHomeScreen(
          onOpenScan: () => _go(ParkPalPlatformRoutes.iris),
          onOpenHistory: () => _go(ParkPalPlatformRoutes.savedPlaces),
        ),
      ParkPalPlatformRoutes.iris => ScanComingSoonScreen(
          onSearchManually: () => _go(ParkPalPlatformRoutes.find),
        ),
      ParkPalPlatformRoutes.savedPlaces => const ParkingHistoryScreen(),
      ParkPalPlatformRoutes.account => const AccountScreen(),
      ParkPalPlatformRoutes.settings => const AccountScreen(
          mode: AccountScreenMode.settings,
        ),
      _ => _ApplicationSection(route: route),
    };
  }

  String _normalAppRoute(String route) {
    final normal = ParkPalPlatformRoutes.normalise(route);
    return ParkPalPlatformRoutes.appRoutes.contains(normal)
        ? normal
        : ParkPalPlatformRoutes.dashboard;
  }

  _AppDestination _destinationForRoute(String route) {
    return _appDestinations.firstWhere(
      (destination) => destination.route == route,
      orElse: () => _appDestinations.first,
    );
  }
}

class _AppRail extends StatelessWidget {
  const _AppRail({
    required this.current,
    required this.onNavigate,
  });

  final _AppDestination current;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 282,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
      decoration: parkPalGlassDecoration(opacity: 0.94, radius: 34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: parkPalIridescentBorderGradient(),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(Icons.local_parking_rounded,
                    color: Colors.white),
              ),
              const SizedBox(width: 12),
              Text(
                'ParkPal',
                style: ParkPalText.display(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: ParkPalColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Customer platform',
            style: ParkPalText.mono(
              color: ParkPalColors.mutedTwo,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              children: [
                for (final destination in _appDestinations)
                  _RailButton(
                    destination: destination,
                    selected: destination.route == current.route,
                    onTap: () => onNavigate(destination.route),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileAppNav extends StatelessWidget {
  const _MobileAppNav({
    required this.current,
    required this.onNavigate,
  });

  final _AppDestination current;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final primary = _appDestinations.take(5).toList(growable: false);
    final selectedIndex =
        primary.indexWhere((item) => item.route == current.route);

    return Padding(
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
            selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
            onDestinationSelected: (index) => onNavigate(primary[index].route),
            height: 72,
            backgroundColor: Colors.white.withValues(alpha: 0.88),
            indicatorColor: ParkPalColors.mint100,
            destinations: [
              for (final item in primary)
                NavigationDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.icon),
                  label: item.shortLabel,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _AppDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? ParkPalColors.mint100 : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? ParkPalColors.greenLine : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                destination.icon,
                color: selected ? ParkPalColors.green700 : ParkPalColors.muted,
                size: 22,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  destination.label,
                  style: ParkPalText.body(
                    color: selected
                        ? ParkPalColors.green700
                        : ParkPalColors.graphite,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ApplicationSection extends StatelessWidget {
  const _ApplicationSection({required this.route});

  final String route;

  @override
  Widget build(BuildContext context) {
    final destination = _appDestinations.firstWhere(
      (item) => item.route == route,
      orElse: () => _appDestinations.first,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 128),
      children: [
        Text(
          destination.label,
          style: ParkPalText.display(
            fontSize: 38,
            fontWeight: FontWeight.w900,
            color: ParkPalColors.ink,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          destination.description,
          style: ParkPalText.body(
            color: ParkPalColors.muted,
            fontSize: 16,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: parkPalGlassDecoration(opacity: 0.92, radius: 30),
          child: Row(
            children: [
              Icon(destination.icon, color: ParkPalColors.green700, size: 34),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  _emptyStateFor(destination.route),
                  style: ParkPalText.body(
                    color: ParkPalColors.graphite,
                    height: 1.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _emptyStateFor(String route) {
    return switch (route) {
      ParkPalPlatformRoutes.trips =>
        'You haven’t saved any trips yet. Plan a journey or check a road to begin.',
      ParkPalPlatformRoutes.vehicles =>
        'No vehicles saved yet. Add a vehicle to improve permit and restriction context.',
      ParkPalPlatformRoutes.reports =>
        'No reports submitted. Report unclear signs, missing signs or temporary suspensions when you spot them.',
      ParkPalPlatformRoutes.appPioneer =>
        'No Pioneer missions assigned. Verified mapping missions unlock as nearby roads need review.',
      ParkPalPlatformRoutes.notifications =>
        'No notifications. Parking alerts, report outcomes and evidence updates are enabled for future activity.',
      _ =>
        'No records yet. Start with a parking check to build your ParkPal intelligence history.',
    };
  }
}

class _AppDestination {
  const _AppDestination({
    required this.route,
    required this.label,
    required this.shortLabel,
    required this.icon,
    required this.description,
  });

  final String route;
  final String label;
  final String shortLabel;
  final IconData icon;
  final String description;
}

const _appDestinations = [
  _AppDestination(
    route: ParkPalPlatformRoutes.dashboard,
    label: 'Dashboard',
    shortLabel: 'Home',
    icon: Icons.home_rounded,
    description: 'Your live ParkPal overview, recent checks and evidence.',
  ),
  _AppDestination(
    route: ParkPalPlatformRoutes.map,
    label: 'Live Map',
    shortLabel: 'Map',
    icon: Icons.map_rounded,
    description: 'Atlas-powered parking intelligence by street and council.',
  ),
  _AppDestination(
    route: ParkPalPlatformRoutes.find,
    label: 'Find Parking',
    shortLabel: 'Find',
    icon: Icons.travel_explore_rounded,
    description: 'Search a road or location before you park.',
  ),
  _AppDestination(
    route: ParkPalPlatformRoutes.iris,
    label: 'IRIS Assistant',
    shortLabel: 'IRIS',
    icon: Icons.auto_awesome_rounded,
    description: 'IRIS explains source confidence and parking certainty.',
  ),
  _AppDestination(
    route: ParkPalPlatformRoutes.trips,
    label: 'Trips',
    shortLabel: 'Trips',
    icon: Icons.route_rounded,
    description: 'Plan parking checks around journeys and delivery stops.',
  ),
  _AppDestination(
    route: ParkPalPlatformRoutes.vehicles,
    label: 'Vehicles',
    shortLabel: 'Cars',
    icon: Icons.directions_car_rounded,
    description: 'Manage vehicles, permits and parking context.',
  ),
  _AppDestination(
    route: ParkPalPlatformRoutes.savedPlaces,
    label: 'Saved Places',
    shortLabel: 'Saved',
    icon: Icons.bookmark_rounded,
    description: 'Your evidence vault and saved parking checks.',
  ),
  _AppDestination(
    route: ParkPalPlatformRoutes.reports,
    label: 'Reports',
    shortLabel: 'Reports',
    icon: Icons.report_problem_rounded,
    description: 'Report changed signs, unclear rules or missing data.',
  ),
  _AppDestination(
    route: ParkPalPlatformRoutes.appPioneer,
    label: 'Pioneer',
    shortLabel: 'Pioneer',
    icon: Icons.explore_rounded,
    description: 'Mapping missions and field verification opportunities.',
  ),
  _AppDestination(
    route: ParkPalPlatformRoutes.notifications,
    label: 'Notifications',
    shortLabel: 'Alerts',
    icon: Icons.notifications_rounded,
    description: 'Fine-prevention alerts and ParkPal updates.',
  ),
  _AppDestination(
    route: ParkPalPlatformRoutes.account,
    label: 'Profile',
    shortLabel: 'Profile',
    icon: Icons.account_circle_rounded,
    description: 'Your profile, privacy and evidence settings.',
  ),
  _AppDestination(
    route: ParkPalPlatformRoutes.settings,
    label: 'Settings',
    shortLabel: 'Settings',
    icon: Icons.settings_rounded,
    description: 'Control app preferences, notifications and security.',
  ),
];
