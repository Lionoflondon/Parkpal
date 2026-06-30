import 'package:flutter/material.dart';

import 'parkpal_admin_data_service.dart';
import 'parkpal_admin_theme.dart';

enum ParkPalAdminSection {
  dashboard,
  partners,
  locations,
  bookings,
  members,
  payments,
  support,
  analytics,
  settings,
}

class ParkPalAdminShell extends StatefulWidget {
  const ParkPalAdminShell({required this.role, super.key});

  final String role;

  @override
  State<ParkPalAdminShell> createState() => _ParkPalAdminShellState();
}

class _ParkPalAdminShellState extends State<ParkPalAdminShell> {
  ParkPalAdminSection _section = ParkPalAdminSection.dashboard;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _AdminSidebar(
            role: widget.role,
            selected: _section,
            onSelected: (section) => setState(() => _section = section),
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topRight,
                  radius: 1.2,
                  colors: [
                    Color(0x332C7DFF),
                    ParkPalAdminColors.background,
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: _section == ParkPalAdminSection.dashboard
                      ? const _DashboardPage()
                      : _ModulePage(section: _section),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminSidebar extends StatelessWidget {
  const _AdminSidebar({
    required this.role,
    required this.selected,
    required this.onSelected,
  });

  final String role;
  final ParkPalAdminSection selected;
  final ValueChanged<ParkPalAdminSection> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(22),
      color: ParkPalAdminColors.panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ParkPal', style: adminHeading(size: 34)),
          Text('Operations Admin',
              style: adminBody(color: ParkPalAdminColors.muted)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              gradient: adminIridescentGradient(),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              role,
              style: adminBody(size: 12, weight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 28),
          for (final section in ParkPalAdminSection.values)
            _SidebarItem(
              section: section,
              selected: selected == section,
              onTap: () => onSelected(section),
            ),
          const Spacer(),
          Text(
            'Separate ParkPal admin surface. No public access routes.',
            style: adminBody(color: ParkPalAdminColors.muted, size: 12),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.section,
    required this.selected,
    required this.onTap,
  });

  final ParkPalAdminSection section;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: selected
                ? Border.all(color: ParkPalAdminColors.glassBorder)
                : null,
          ),
          child: Row(
            children: [
              Icon(_iconFor(section),
                  color: selected
                      ? ParkPalAdminColors.cyan
                      : ParkPalAdminColors.muted),
              const SizedBox(width: 12),
              Text(
                _titleFor(section),
                style: adminBody(
                  color: selected
                      ? ParkPalAdminColors.text
                      : ParkPalAdminColors.muted,
                  weight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardPage extends StatelessWidget {
  const _DashboardPage();

  @override
  Widget build(BuildContext context) {
    final service = ParkPalAdminDataService();
    return FutureBuilder<ParkPalAdminMetrics>(
      future: service.fetchDashboardMetrics(),
      builder: (context, snapshot) {
        final metrics = snapshot.data ?? ParkPalAdminMetrics.empty;
        return ListView(
          children: [
            Text('Dashboard', style: adminHeading(size: 46)),
            const SizedBox(height: 8),
            Text(
              'Live operating view for ParkPal bookings, spaces, partners, revenue and alerts.',
              style: adminBody(color: ParkPalAdminColors.muted),
            ),
            const SizedBox(height: 26),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _MetricCard(
                    label: 'Live bookings', value: '${metrics.liveBookings}'),
                _MetricCard(
                    label: 'Available spaces',
                    value: '${metrics.availableSpaces}'),
                _MetricCard(
                    label: 'Revenue today',
                    value: '£${metrics.revenueToday.toStringAsFixed(2)}'),
                _MetricCard(
                    label: 'Partner applications',
                    value: '${metrics.partnerApplications}'),
                _MetricCard(
                    label: 'Alerts',
                    value: '${metrics.alerts}',
                    accent: ParkPalAdminColors.amber),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _ModulePage extends StatelessWidget {
  const _ModulePage({required this.section});

  final ParkPalAdminSection section;

  @override
  Widget build(BuildContext context) {
    final definition = _definitionFor(section);
    final service = ParkPalAdminDataService();
    return FutureBuilder<List<Map<String, Object?>>>(
      future: service.fetchModuleRows(definition.collection),
      builder: (context, snapshot) {
        final rows = snapshot.data ?? const <Map<String, Object?>>[];
        return ListView(
          children: [
            Text(definition.title, style: adminHeading(size: 46)),
            const SizedBox(height: 8),
            Text(definition.description,
                style: adminBody(color: ParkPalAdminColors.muted)),
            const SizedBox(height: 24),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final item in definition.capabilities)
                  Chip(
                    label: Text(item),
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: adminGlassDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Firestore collection',
                      style: adminBody(weight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(definition.collection,
                      style: adminBody(color: ParkPalAdminColors.cyan)),
                  const SizedBox(height: 18),
                  if (rows.isEmpty)
                    Text(
                      'No records yet. This module is wired to ParkPal Firestore and ready for operational data.',
                      style: adminBody(color: ParkPalAdminColors.muted),
                    )
                  else
                    for (final row in rows)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          row['name']?.toString() ??
                              row['title']?.toString() ??
                              row['id'].toString(),
                          style: adminBody(weight: FontWeight.w700),
                        ),
                      ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    this.accent = ParkPalAdminColors.cyan,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: adminGlassDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: adminBody(color: ParkPalAdminColors.muted)),
            const SizedBox(height: 12),
            Text(
              value,
              style: adminHeading(size: 38).copyWith(color: accent),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleDefinition {
  const _ModuleDefinition({
    required this.title,
    required this.description,
    required this.collection,
    required this.capabilities,
  });

  final String title;
  final String description;
  final String collection;
  final List<String> capabilities;
}

_ModuleDefinition _definitionFor(ParkPalAdminSection section) {
  return switch (section) {
    ParkPalAdminSection.partners => const _ModuleDefinition(
        title: 'Partners',
        description:
            'Partner applications, approvals, documents, profiles and payouts.',
        collection: ParkPalAdminCollections.partners,
        capabilities: [
          'Applications',
          'Approve',
          'Reject',
          'Documents',
          'Payout status'
        ],
      ),
    ParkPalAdminSection.locations => const _ModuleDefinition(
        title: 'Parking Locations',
        description:
            'Car parks, capacity, pricing, opening hours, amenities, photos and restrictions.',
        collection: ParkPalAdminCollections.locations,
        capabilities: [
          'Add/edit',
          'Capacity',
          'Pricing',
          'Opening hours',
          'Amenities',
          'Photos',
          'Restrictions'
        ],
      ),
    ParkPalAdminSection.bookings => const _ModuleDefinition(
        title: 'Bookings',
        description:
            'Active, upcoming, completed, cancelled bookings and refunds.',
        collection: ParkPalAdminCollections.bookings,
        capabilities: [
          'Active',
          'Upcoming',
          'Completed',
          'Cancelled',
          'Refunds'
        ],
      ),
    ParkPalAdminSection.members => const _ModuleDefinition(
        title: 'Members',
        description:
            'Member search, vehicles, booking history, wallet/Roth placeholder and support history.',
        collection: ParkPalAdminCollections.members,
        capabilities: [
          'Search',
          'Vehicles',
          'Booking history',
          'Wallet/Roth',
          'Support history'
        ],
      ),
    ParkPalAdminSection.payments => const _ModuleDefinition(
        title: 'Payments',
        description: 'Stripe, Roth and partner settlement placeholders.',
        collection: ParkPalAdminCollections.payments,
        capabilities: ['Stripe', 'Roth', 'Partner settlement'],
      ),
    ParkPalAdminSection.support => const _ModuleDefinition(
        title: 'Support',
        description: 'Tickets, disputes and incident reports.',
        collection: ParkPalAdminCollections.supportTickets,
        capabilities: ['Tickets', 'Disputes', 'Incident reports'],
      ),
    ParkPalAdminSection.analytics => const _ModuleDefinition(
        title: 'Analytics',
        description:
            'Occupancy, revenue, peak hours, conversion and repeat usage.',
        collection: ParkPalAdminCollections.bookings,
        capabilities: [
          'Occupancy',
          'Revenue',
          'Peak hours',
          'Conversion',
          'Repeat usage'
        ],
      ),
    ParkPalAdminSection.settings => const _ModuleDefinition(
        title: 'Settings',
        description: 'Fees, promotions, notifications and admin roles.',
        collection: ParkPalAdminCollections.adminUsers,
        capabilities: ['Fees', 'Promotions', 'Notifications', 'Admin roles'],
      ),
    ParkPalAdminSection.dashboard => const _ModuleDefinition(
        title: 'Dashboard',
        description: 'ParkPal operating overview.',
        collection: ParkPalAdminCollections.bookings,
        capabilities: [],
      ),
  };
}

String _titleFor(ParkPalAdminSection section) {
  return _definitionFor(section).title;
}

IconData _iconFor(ParkPalAdminSection section) {
  return switch (section) {
    ParkPalAdminSection.dashboard => Icons.dashboard_outlined,
    ParkPalAdminSection.partners => Icons.handshake_outlined,
    ParkPalAdminSection.locations => Icons.local_parking_outlined,
    ParkPalAdminSection.bookings => Icons.event_available_outlined,
    ParkPalAdminSection.members => Icons.people_outline,
    ParkPalAdminSection.payments => Icons.payments_outlined,
    ParkPalAdminSection.support => Icons.support_agent_outlined,
    ParkPalAdminSection.analytics => Icons.analytics_outlined,
    ParkPalAdminSection.settings => Icons.settings_outlined,
  };
}
