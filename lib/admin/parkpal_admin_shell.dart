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
            onSelected: (section) {
              if (!_canViewSection(widget.role, section)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('This role cannot access that module.')),
                );
                return;
              }
              setState(() => _section = section);
            },
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
                  child: _pageFor(_section, widget.role),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pageFor(ParkPalAdminSection section, String role) {
    return switch (section) {
      ParkPalAdminSection.dashboard => const _DashboardPage(),
      ParkPalAdminSection.partners => _PartnerApplicationsPage(role: role),
      ParkPalAdminSection.locations => _ParkingLocationsPage(role: role),
      _ => _ModulePage(section: section, role: role),
    };
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
              enabled: _canViewSection(role, section),
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
    required this.enabled,
    required this.selected,
    required this.onTap,
  });

  final ParkPalAdminSection section;
  final bool enabled;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: enabled ? onTap : null,
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
                  color: !enabled
                      ? ParkPalAdminColors.muted.withValues(alpha: 0.38)
                      : selected
                          ? ParkPalAdminColors.cyan
                          : ParkPalAdminColors.muted),
              const SizedBox(width: 12),
              Text(
                _titleFor(section),
                style: adminBody(
                  color: selected
                      ? ParkPalAdminColors.text
                      : enabled
                          ? ParkPalAdminColors.muted
                          : ParkPalAdminColors.muted.withValues(alpha: 0.38),
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
                    label: 'Pending partners',
                    value: '${metrics.pendingPartners}'),
                _MetricCard(
                    label: 'Active partners',
                    value: '${metrics.activePartners}'),
                _MetricCard(
                    label: 'Active locations',
                    value: '${metrics.activeLocations}'),
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
  const _ModulePage({required this.section, required this.role});

  final ParkPalAdminSection section;
  final String role;

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
                    _EmptyState(message: _emptyCopyFor(section))
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

class _PartnerApplicationsPage extends StatefulWidget {
  const _PartnerApplicationsPage({required this.role});

  final String role;

  @override
  State<_PartnerApplicationsPage> createState() =>
      _PartnerApplicationsPageState();
}

class _PartnerApplicationsPageState extends State<_PartnerApplicationsPage> {
  final _service = ParkPalAdminDataService();
  late Future<List<Map<String, Object?>>> _partners;

  bool get _canEdit => _canEditPartners(widget.role);

  @override
  void initState() {
    super.initState();
    _partners = _service.fetchModuleRows(ParkPalAdminCollections.partners);
  }

  Future<void> _setStatus(
    String partnerId,
    String status,
    String onboardingStatus,
  ) async {
    if (!_canEdit) return;
    final ok = await _service.updatePartnerStatus(
      partnerId: partnerId,
      status: status,
      onboardingStatus: onboardingStatus,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(ok ? 'Partner updated' : 'Could not update partner')),
    );
    setState(() {
      _partners = _service.fetchModuleRows(ParkPalAdminCollections.partners);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, Object?>>>(
      future: _partners,
      builder: (context, snapshot) {
        final partners = snapshot.data ?? const <Map<String, Object?>>[];
        return ListView(
          children: [
            Text('Partner Applications', style: adminHeading(size: 46)),
            const SizedBox(height: 8),
            Text(
              'Review partner applications, onboarding status, documents and payout readiness.',
              style: adminBody(color: ParkPalAdminColors.muted),
            ),
            const SizedBox(height: 24),
            if (partners.isEmpty)
              const _EmptyState(message: 'No partners yet.')
            else
              for (final partner in partners)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _PartnerCard(
                    partner: partner,
                    canEdit: _canEdit,
                    onApprove: () => _setStatus(
                      partner['id'].toString(),
                      'active',
                      'approved',
                    ),
                    onReject: () => _setStatus(
                      partner['id'].toString(),
                      'rejected',
                      'rejected',
                    ),
                    onSuspend: () => _setStatus(
                      partner['id'].toString(),
                      'suspended',
                      'suspended',
                    ),
                    onReactivate: () => _setStatus(
                      partner['id'].toString(),
                      'active',
                      'reactivated',
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }
}

class _PartnerCard extends StatelessWidget {
  const _PartnerCard({
    required this.partner,
    required this.canEdit,
    required this.onApprove,
    required this.onReject,
    required this.onSuspend,
    required this.onReactivate,
  });

  final Map<String, Object?> partner;
  final bool canEdit;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onSuspend;
  final VoidCallback onReactivate;

  @override
  Widget build(BuildContext context) {
    final name = partner['businessName'] ??
        partner['name'] ??
        partner['contactName'] ??
        partner['id'];
    final status = partner['status']?.toString() ?? 'pending';
    final onboarding = partner['onboardingStatus']?.toString() ?? 'not started';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: adminGlassDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text(name.toString(), style: adminHeading(size: 28))),
              _StatusPill(label: status),
            ],
          ),
          const SizedBox(height: 8),
          Text('Onboarding: $onboarding',
              style: adminBody(color: ParkPalAdminColors.muted)),
          Text('Documents: ${partner['documentStatus'] ?? 'pending'}',
              style: adminBody(color: ParkPalAdminColors.muted)),
          Text('Payout: ${partner['payoutStatus'] ?? 'not configured'}',
              style: adminBody(color: ParkPalAdminColors.muted)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                  onPressed: canEdit ? onApprove : null,
                  child: const Text('Approve')),
              OutlinedButton(
                  onPressed: canEdit ? onReject : null,
                  child: const Text('Reject')),
              OutlinedButton(
                  onPressed: canEdit ? onSuspend : null,
                  child: const Text('Suspend')),
              OutlinedButton(
                  onPressed: canEdit ? onReactivate : null,
                  child: const Text('Reactivate')),
            ],
          ),
        ],
      ),
    );
  }
}

class _ParkingLocationsPage extends StatefulWidget {
  const _ParkingLocationsPage({required this.role});

  final String role;

  @override
  State<_ParkingLocationsPage> createState() => _ParkingLocationsPageState();
}

class _ParkingLocationsPageState extends State<_ParkingLocationsPage> {
  final _service = ParkPalAdminDataService();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _capacity = TextEditingController();
  final _pricePerHour = TextEditingController();
  final _openingHours = TextEditingController();
  final _amenities = TextEditingController();
  final _restrictions = TextEditingController();
  late Future<List<Map<String, Object?>>> _locations;
  String? _editingId;
  bool _active = true;

  bool get _canEdit => _canEditLocations(widget.role);

  @override
  void initState() {
    super.initState();
    _locations = _service.fetchModuleRows(ParkPalAdminCollections.locations);
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _capacity.dispose();
    _pricePerHour.dispose();
    _openingHours.dispose();
    _amenities.dispose();
    _restrictions.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_canEdit) return;
    final ok = await _service.saveLocation(
      locationId: _editingId,
      data: {
        'name': _name.text.trim(),
        'address': _address.text.trim(),
        'capacity': int.tryParse(_capacity.text.trim()) ?? 0,
        'availableSpaces': int.tryParse(_capacity.text.trim()) ?? 0,
        'pricePerHour': double.tryParse(_pricePerHour.text.trim()) ?? 0,
        'openingHours': _openingHours.text.trim(),
        'amenities': _csv(_amenities.text),
        'restrictions': _csv(_restrictions.text),
        'active': _active,
        'status': _active ? 'active' : 'inactive',
      },
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(ok ? 'Location saved' : 'Could not save location')),
    );
    _clearForm();
    setState(() {
      _locations = _service.fetchModuleRows(ParkPalAdminCollections.locations);
    });
  }

  void _edit(Map<String, Object?> location) {
    setState(() {
      _editingId = location['id']?.toString();
      _name.text = location['name']?.toString() ?? '';
      _address.text = location['address']?.toString() ?? '';
      _capacity.text = location['capacity']?.toString() ?? '';
      _pricePerHour.text = location['pricePerHour']?.toString() ?? '';
      _openingHours.text = location['openingHours']?.toString() ?? '';
      _amenities.text = _join(location['amenities']);
      _restrictions.text = _join(location['restrictions']);
      _active = location['active'] != false;
    });
  }

  void _clearForm() {
    _editingId = null;
    _name.clear();
    _address.clear();
    _capacity.clear();
    _pricePerHour.clear();
    _openingHours.clear();
    _amenities.clear();
    _restrictions.clear();
    _active = true;
  }

  Future<void> _setActive(String id, bool active) async {
    if (!_canEdit) return;
    await _service.updateLocationActive(locationId: id, active: active);
    setState(() {
      _locations = _service.fetchModuleRows(ParkPalAdminCollections.locations);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, Object?>>>(
      future: _locations,
      builder: (context, snapshot) {
        final locations = snapshot.data ?? const <Map<String, Object?>>[];
        return ListView(
          children: [
            Text('Parking Locations', style: adminHeading(size: 46)),
            const SizedBox(height: 8),
            Text(
              'Add and manage car parks, capacity, pricing, opening hours, amenities and restrictions.',
              style: adminBody(color: ParkPalAdminColors.muted),
            ),
            const SizedBox(height: 24),
            _LocationForm(
              canEdit: _canEdit,
              editing: _editingId != null,
              name: _name,
              address: _address,
              capacity: _capacity,
              pricePerHour: _pricePerHour,
              openingHours: _openingHours,
              amenities: _amenities,
              restrictions: _restrictions,
              active: _active,
              onActiveChanged: (value) => setState(() => _active = value),
              onSave: _save,
              onCancel: () => setState(_clearForm),
            ),
            const SizedBox(height: 24),
            if (locations.isEmpty)
              const _EmptyState(message: 'No locations yet.')
            else
              for (final location in locations)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _LocationCard(
                    location: location,
                    canEdit: _canEdit,
                    onEdit: () => _edit(location),
                    onToggle: () => _setActive(
                      location['id'].toString(),
                      location['active'] == false,
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }

  List<String> _csv(String value) {
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  String _join(Object? value) {
    if (value is Iterable) return value.join(', ');
    return value?.toString() ?? '';
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

class _LocationForm extends StatelessWidget {
  const _LocationForm({
    required this.canEdit,
    required this.editing,
    required this.name,
    required this.address,
    required this.capacity,
    required this.pricePerHour,
    required this.openingHours,
    required this.amenities,
    required this.restrictions,
    required this.active,
    required this.onActiveChanged,
    required this.onSave,
    required this.onCancel,
  });

  final bool canEdit;
  final bool editing;
  final TextEditingController name;
  final TextEditingController address;
  final TextEditingController capacity;
  final TextEditingController pricePerHour;
  final TextEditingController openingHours;
  final TextEditingController amenities;
  final TextEditingController restrictions;
  final bool active;
  final ValueChanged<bool> onActiveChanged;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: adminGlassDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(editing ? 'Edit location' : 'Add location',
              style: adminHeading(size: 28)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _Field(width: 260, controller: name, label: 'Location name'),
              _Field(width: 360, controller: address, label: 'Address'),
              _Field(width: 160, controller: capacity, label: 'Capacity'),
              _Field(width: 180, controller: pricePerHour, label: '£ / hour'),
              _Field(
                  width: 220, controller: openingHours, label: 'Opening hours'),
              _Field(width: 320, controller: amenities, label: 'Amenities CSV'),
              _Field(
                  width: 320,
                  controller: restrictions,
                  label: 'Restrictions CSV'),
            ],
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: active,
            onChanged: canEdit ? onActiveChanged : null,
            title: const Text('Active'),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            children: [
              FilledButton(
                  onPressed: canEdit ? onSave : null,
                  child: Text(editing ? 'Save changes' : 'Add location')),
              if (editing)
                OutlinedButton(
                    onPressed: onCancel, child: const Text('Cancel')),
            ],
          ),
        ],
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.location,
    required this.canEdit,
    required this.onEdit,
    required this.onToggle,
  });

  final Map<String, Object?> location;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final active = location['active'] != false;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: adminGlassDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(location['name']?.toString() ?? 'Unnamed location',
                    style: adminHeading(size: 26)),
                Text(location['address']?.toString() ?? 'No address',
                    style: adminBody(color: ParkPalAdminColors.muted)),
                const SizedBox(height: 8),
                Text(
                  'Capacity: ${location['capacity'] ?? 0} • £/hr: ${location['pricePerHour'] ?? 0} • Hours: ${location['openingHours'] ?? 'not set'}',
                  style: adminBody(color: ParkPalAdminColors.muted),
                ),
              ],
            ),
          ),
          _StatusPill(label: active ? 'active' : 'inactive'),
          const SizedBox(width: 12),
          OutlinedButton(
              onPressed: canEdit ? onEdit : null, child: const Text('Edit')),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: canEdit ? onToggle : null,
            child: Text(active ? 'Deactivate' : 'Activate'),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.width,
    required this.controller,
    required this.label,
  });

  final double width;
  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = switch (label) {
      'active' || 'approved' => ParkPalAdminColors.emerald,
      'pending' => ParkPalAdminColors.amber,
      'rejected' || 'suspended' => ParkPalAdminColors.red,
      _ => ParkPalAdminColors.cyan,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label, style: adminBody(color: color, size: 12)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: adminGlassDecoration(),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined,
              color: ParkPalAdminColors.cyan, size: 38),
          const SizedBox(height: 12),
          Text(message, style: adminHeading(size: 26)),
          const SizedBox(height: 6),
          Text(
            'ParkPal Firestore is connected. Records will appear here once operational data is added.',
            textAlign: TextAlign.center,
            style: adminBody(color: ParkPalAdminColors.muted),
          ),
        ],
      ),
    );
  }
}

bool _canEditPartners(String role) {
  return const ['superAdmin', 'admin', 'partnerManager'].contains(role);
}

bool _canEditLocations(String role) {
  return const ['superAdmin', 'admin', 'partnerManager'].contains(role);
}

bool _canViewSection(String role, ParkPalAdminSection section) {
  if (role == 'superAdmin' || role == 'admin') return true;
  if (role == 'partnerManager') {
    return const {
      ParkPalAdminSection.dashboard,
      ParkPalAdminSection.partners,
      ParkPalAdminSection.locations,
    }.contains(section);
  }
  if (role == 'support') {
    return const {
      ParkPalAdminSection.dashboard,
      ParkPalAdminSection.bookings,
      ParkPalAdminSection.support,
    }.contains(section);
  }
  if (role == 'reviewer') {
    return const {
      ParkPalAdminSection.dashboard,
      ParkPalAdminSection.support,
      ParkPalAdminSection.analytics,
    }.contains(section);
  }
  if (role == 'pioneerManager') {
    return const {
      ParkPalAdminSection.dashboard,
      ParkPalAdminSection.partners,
      ParkPalAdminSection.support,
    }.contains(section);
  }
  if (role == 'atlasManager') {
    return const {
      ParkPalAdminSection.dashboard,
      ParkPalAdminSection.locations,
      ParkPalAdminSection.analytics,
      ParkPalAdminSection.settings,
    }.contains(section);
  }
  return section == ParkPalAdminSection.dashboard;
}

String _emptyCopyFor(ParkPalAdminSection section) {
  return switch (section) {
    ParkPalAdminSection.bookings => 'No bookings yet.',
    ParkPalAdminSection.partners => 'No partners yet.',
    ParkPalAdminSection.locations => 'No locations yet.',
    _ => 'No records yet.',
  };
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
