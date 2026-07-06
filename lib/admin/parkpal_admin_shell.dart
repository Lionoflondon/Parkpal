import 'package:flutter/material.dart';

import '../features/atlas_intelligence/aie_admin_screen.dart';
import '../features/dtro/dtro_admin_screen.dart';
import '../features/parkpal_atlas/iris_coverage_forecast_admin_section.dart';
import 'parkpal_admin_data_service.dart';
import 'parkpal_admin_settings_screen.dart';
import 'parkpal_admin_theme.dart';

enum ParkPalAdminSection {
  dashboard,
  atlasIntelligence,
  dtroLegalData,
  councils,
  signRepository,
  roadRules,
  userChecks,
  evidenceVault,
  appealSupport,
  reports,
  irisReview,
  coverageForecast,
  adminUsers,
  settings,
}

class ParkPalAdminShell extends StatefulWidget {
  const ParkPalAdminShell({
    required this.role,
    required this.onSignedOut,
    super.key,
  });

  final String role;
  final VoidCallback onSignedOut;

  @override
  State<ParkPalAdminShell> createState() => _ParkPalAdminShellState();
}

class _ParkPalAdminShellState extends State<ParkPalAdminShell> {
  final _service = ParkPalAdminDataService();
  ParkPalAdminSection _section = ParkPalAdminSection.dashboard;

  Future<void> _signOut() async {
    await _service.signOut();
    if (!mounted) return;
    widget.onSignedOut();
  }

  Future<void> _showChangePassword() async {
    final result = await showDialog<ParkPalAdminPasswordResult>(
      context: context,
      builder: (context) => _ChangePasswordDialog(service: _service),
    );
    if (!mounted || result == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
    if (result.success && result.requiresSignIn) {
      await _signOut();
    }
  }

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
                    content: Text('This role cannot access that module.'),
                  ),
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
                  child: Column(
                    children: [
                      _AdminTopBar(
                        service: _service,
                        onChangePassword: _showChangePassword,
                        onSignOut: _signOut,
                      ),
                      const SizedBox(height: 18),
                      Expanded(child: _pageFor(_section, widget.role)),
                    ],
                  ),
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
      ParkPalAdminSection.atlasIntelligence => const AieAdminScreen(),
      ParkPalAdminSection.dtroLegalData => const DtroAdminScreen(),
      ParkPalAdminSection.coverageForecast =>
        const IrisCoverageForecastAdminSection(),
      ParkPalAdminSection.settings => const ParkPalAdminSettingsScreen(),
      _ => _ModulePage(section: section, role: role),
    };
  }
}

class _AdminTopBar extends StatelessWidget {
  const _AdminTopBar({
    required this.service,
    required this.onChangePassword,
    required this.onSignOut,
  });

  final ParkPalAdminDataService service;
  final VoidCallback onChangePassword;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: service.currentAdminEmail(),
      builder: (context, snapshot) {
        final email = snapshot.data ?? 'Admin account';
        return Row(
          children: [
            const Spacer(),
            PopupMenuButton<String>(
              tooltip: 'Account',
              color: ParkPalAdminColors.panel,
              onSelected: (value) {
                if (value == 'password') onChangePassword();
                if (value == 'signOut') onSignOut();
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  enabled: false,
                  child: Text(
                    email,
                    style: adminBody(
                      color: ParkPalAdminColors.muted,
                      size: 12,
                    ),
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'password',
                  child: Text('Change password'),
                ),
                const PopupMenuItem<String>(
                  value: 'signOut',
                  child: Text('Sign out'),
                ),
              ],
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: adminGlassDecoration(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.account_circle_outlined,
                      color: ParkPalAdminColors.cyan,
                    ),
                    const SizedBox(width: 8),
                    Text(email, style: adminBody(weight: FontWeight.w700)),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      color: ParkPalAdminColors.muted,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog({required this.service});

  final ParkPalAdminDataService service;

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final current = _current.text;
    final next = _new.text;
    final confirm = _confirm.text;
    setState(() => _error = null);

    if (current.isEmpty) {
      setState(() => _error = 'Current password required.');
      return;
    }
    if (next.length < 7) {
      setState(() => _error = 'Password too weak.');
      return;
    }
    if (next != confirm) {
      setState(() => _error = 'New password and confirmation must match.');
      return;
    }

    setState(() => _saving = true);
    final result = await widget.service.changePassword(
      currentPassword: current,
      newPassword: next,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.success) {
      Navigator.of(context).pop(result);
    } else {
      setState(() => _error = result.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: adminGlassDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Change password', style: adminHeading(size: 34)),
              const SizedBox(height: 8),
              Text(
                'Re-enter your current password before setting a new one.',
                style: adminBody(color: ParkPalAdminColors.muted),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _current,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Current password'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _new,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirm,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Confirm new password'),
                onSubmitted: (_) => _saving ? null : _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: adminBody(color: ParkPalAdminColors.red)),
              ],
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _saving ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _submit,
                      child: Text(_saving ? 'Updating…' : 'Update password'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
      width: 290,
      padding: const EdgeInsets.all(22),
      color: ParkPalAdminColors.panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ParkPal', style: adminHeading(size: 34)),
          Text('Intelligence Admin',
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
          Expanded(
            child: ListView(
              children: [
                for (final section in ParkPalAdminSection.values)
                  _SidebarItem(
                    section: section,
                    enabled: _canViewSection(role, section),
                    selected: selected == section,
                    onTap: () => onSelected(section),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'ParkPal prevents fines by managing sign, rule, council and evidence intelligence.',
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
              Icon(
                _iconFor(section),
                color: !enabled
                    ? ParkPalAdminColors.muted.withValues(alpha: 0.38)
                    : selected
                        ? ParkPalAdminColors.cyan
                        : ParkPalAdminColors.muted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
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
              'Operating view for parking checks, sign certainty, council rules, evidence records and IRIS review.',
              style: adminBody(color: ParkPalAdminColors.muted),
            ),
            const SizedBox(height: 26),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _MetricCard(
                  label: 'Total parking checks',
                  value: '${metrics.totalParkingChecks}',
                ),
                _MetricCard(
                  label: 'Unknown / review-needed checks',
                  value: '${metrics.reviewNeededChecks}',
                  accent: ParkPalAdminColors.amber,
                ),
                _MetricCard(
                  label: 'Verified signs',
                  value: '${metrics.verifiedSigns}',
                ),
                _MetricCard(
                  label: 'Council rules loaded',
                  value: '${metrics.councilRulesLoaded}',
                ),
                _MetricCard(
                  label: 'Evidence records',
                  value: '${metrics.evidenceRecords}',
                ),
                _MetricCard(
                  label: 'Appeal support cases',
                  value: '${metrics.appealSupportCases}',
                ),
                _MetricCard(
                  label: 'Active users',
                  value: '${metrics.activeUsers}',
                ),
                _MetricCard(
                  label: 'Alerts',
                  value: '${metrics.alerts}',
                  accent: ParkPalAdminColors.amber,
                ),
              ],
            ),
            const SizedBox(height: 26),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: adminGlassDecoration(),
              child: Text(
                'ParkPal helps users understand roadside restrictions before they walk away. Admin work here is about council data, signs, rules, evidence, review queues and fine-prevention support.',
                style: adminBody(color: ParkPalAdminColors.muted),
              ),
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
                          row['streetName']?.toString() ??
                              row['councilName']?.toString() ??
                              row['queryText']?.toString() ??
                              row['title']?.toString() ??
                              row['email']?.toString() ??
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
      width: 250,
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
          const Icon(Icons.manage_search_outlined,
              color: ParkPalAdminColors.cyan, size: 38),
          const SizedBox(height: 12),
          Text(message, style: adminHeading(size: 26)),
          const SizedBox(height: 6),
          Text(
            'ParkPal Firestore is connected. Intelligence records will appear here once the repository has data for review.',
            textAlign: TextAlign.center,
            style: adminBody(color: ParkPalAdminColors.muted),
          ),
        ],
      ),
    );
  }
}

bool _canViewSection(String role, ParkPalAdminSection section) {
  if (role == 'superAdmin' || role == 'admin') return true;
  if (role == 'support') {
    return const {
      ParkPalAdminSection.dashboard,
      ParkPalAdminSection.evidenceVault,
      ParkPalAdminSection.appealSupport,
      ParkPalAdminSection.reports,
    }.contains(section);
  }
  if (role == 'reviewer') {
    return const {
      ParkPalAdminSection.dashboard,
      ParkPalAdminSection.atlasIntelligence,
      ParkPalAdminSection.dtroLegalData,
      ParkPalAdminSection.signRepository,
      ParkPalAdminSection.roadRules,
      ParkPalAdminSection.irisReview,
      ParkPalAdminSection.coverageForecast,
      ParkPalAdminSection.reports,
    }.contains(section);
  }
  if (role == 'pioneerManager') {
    return const {
      ParkPalAdminSection.dashboard,
      ParkPalAdminSection.signRepository,
      ParkPalAdminSection.reports,
      ParkPalAdminSection.irisReview,
      ParkPalAdminSection.coverageForecast,
    }.contains(section);
  }
  if (role == 'atlasManager') {
    return const {
      ParkPalAdminSection.dashboard,
      ParkPalAdminSection.atlasIntelligence,
      ParkPalAdminSection.dtroLegalData,
      ParkPalAdminSection.councils,
      ParkPalAdminSection.signRepository,
      ParkPalAdminSection.roadRules,
      ParkPalAdminSection.userChecks,
      ParkPalAdminSection.irisReview,
      ParkPalAdminSection.coverageForecast,
    }.contains(section);
  }
  return section == ParkPalAdminSection.dashboard;
}

String _emptyCopyFor(ParkPalAdminSection section) {
  return switch (section) {
    ParkPalAdminSection.councils => 'No council rule sources loaded yet.',
    ParkPalAdminSection.atlasIntelligence =>
      'No Atlas Intelligence Engine records visible yet.',
    ParkPalAdminSection.dtroLegalData =>
      'Atlas Intelligence is waiting for live government data.',
    ParkPalAdminSection.signRepository => 'No sign records ready for review.',
    ParkPalAdminSection.roadRules => 'No road rules loaded yet.',
    ParkPalAdminSection.userChecks => 'No user parking checks recorded yet.',
    ParkPalAdminSection.evidenceVault => 'No evidence records saved yet.',
    ParkPalAdminSection.appealSupport => 'No fine support cases yet.',
    ParkPalAdminSection.reports => 'No user reports awaiting review.',
    ParkPalAdminSection.irisReview => 'No IRIS review items pending.',
    ParkPalAdminSection.coverageForecast =>
      'No coverage forecast records available yet.',
    ParkPalAdminSection.adminUsers => 'No admin user rows visible.',
    ParkPalAdminSection.settings => 'No settings records visible.',
    ParkPalAdminSection.dashboard => 'No dashboard records visible.',
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
    ParkPalAdminSection.councils => const _ModuleDefinition(
        title: 'Councils',
        description:
            'Manage council metadata, official sources, import status and rule provenance.',
        collection: ParkPalAdminCollections.councils,
        capabilities: ['Sources', 'Import status', 'Rule provenance'],
      ),
    ParkPalAdminSection.atlasIntelligence => const _ModuleDefinition(
        title: 'Atlas Intelligence',
        description:
            'Operate the Atlas Intelligence Engine: sources, imports, parsing, versioning, conflicts, missions and public intelligence APIs.',
        collection: 'parkpal_aie_sources',
        capabilities: [
          'Official sources',
          'Import engine',
          'IRIS structuring',
          'Atlas Knowledge Graph',
          'Conflict engine',
          'Mission queue'
        ],
      ),
    ParkPalAdminSection.dtroLegalData => const _ModuleDefinition(
        title: 'Atlas Intelligence',
        description:
            'Government Parking Intelligence Platform for live D-TRO sync status, source health, Atlas coverage and operational review.',
        collection: 'parkpal_dtro_legal_records',
        capabilities: [
          'Government D-TRO',
          'Council APIs',
          'Sign Repository',
          'Evidence Vault',
          'IRIS reasoning'
        ],
      ),
    ParkPalAdminSection.signRepository => const _ModuleDefinition(
        title: 'Sign Repository',
        description:
            'Review captured signs, verification status, restriction text and source evidence.',
        collection: ParkPalAdminCollections.signs,
        capabilities: ['Captured signs', 'Verification', 'Restriction text'],
      ),
    ParkPalAdminSection.roadRules => const _ModuleDefinition(
        title: 'Road Rules',
        description:
            'Manage road-level parking intelligence, zones, risk summaries and confidence.',
        collection: ParkPalAdminCollections.roads,
        capabilities: ['Road profiles', 'Zones', 'Confidence'],
      ),
    ParkPalAdminSection.userChecks => const _ModuleDefinition(
        title: 'User Checks',
        description:
            'Review user parking checks, unknown answers and demand hotspots.',
        collection: ParkPalAdminCollections.checks,
        capabilities: ['Checks', 'Unknown results', 'Demand hotspots'],
      ),
    ParkPalAdminSection.evidenceVault => const _ModuleDefinition(
        title: 'Evidence Vault',
        description:
            'Store time-stamped evidence records for sign certainty and dispute support.',
        collection: ParkPalAdminCollections.evidence,
        capabilities: ['Evidence records', 'Snapshots', 'Audit trail'],
      ),
    ParkPalAdminSection.appealSupport => const _ModuleDefinition(
        title: 'Fine / Appeal Support',
        description:
            'Track user fine-prevention support, appeal evidence packs and case status.',
        collection: ParkPalAdminCollections.appealSupport,
        capabilities: ['Support cases', 'Evidence packs', 'Case status'],
      ),
    ParkPalAdminSection.reports => const _ModuleDefinition(
        title: 'Reports',
        description:
            'Review user reports for changed signs, suspensions, enforcement and incorrect rules.',
        collection: ParkPalAdminCollections.reports,
        capabilities: ['User reports', 'Suspensions', 'Rule corrections'],
      ),
    ParkPalAdminSection.irisReview => const _ModuleDefinition(
        title: 'IRIS Review',
        description:
            'Review uncertain IRIS outcomes, conflicts, stale records and confidence warnings.',
        collection: ParkPalAdminCollections.irisReview,
        capabilities: ['Uncertain results', 'Conflicts', 'Stale records'],
      ),
    ParkPalAdminSection.coverageForecast => const _ModuleDefinition(
        title: 'Coverage Forecast',
        description:
            'Forecast borough coverage, PCI lift, road priority and recommended Pioneer Missions.',
        collection: 'parkpal_iris_road_priorities',
        capabilities: [
          'Borough coverage',
          'Priority scoring',
          'Mission recommendations'
        ],
      ),
    ParkPalAdminSection.adminUsers => const _ModuleDefinition(
        title: 'Admin Users',
        description:
            'Manage ParkPal admin users, roles, access status and permissions.',
        collection: ParkPalAdminCollections.adminUsers,
        capabilities: ['Roles', 'Access status', 'Permissions'],
      ),
    ParkPalAdminSection.settings => const _ModuleDefinition(
        title: 'Settings',
        description:
            'Configure operational thresholds, notifications, review policies and admin controls.',
        collection: ParkPalAdminCollections.alerts,
        capabilities: ['Thresholds', 'Notifications', 'Review policies'],
      ),
    ParkPalAdminSection.dashboard => const _ModuleDefinition(
        title: 'Dashboard',
        description: 'ParkPal intelligence overview.',
        collection: ParkPalAdminCollections.checks,
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
    ParkPalAdminSection.atlasIntelligence => Icons.hub_outlined,
    ParkPalAdminSection.dtroLegalData => Icons.policy_outlined,
    ParkPalAdminSection.councils => Icons.account_balance_outlined,
    ParkPalAdminSection.signRepository => Icons.traffic_outlined,
    ParkPalAdminSection.roadRules => Icons.edit_road_outlined,
    ParkPalAdminSection.userChecks => Icons.fact_check_outlined,
    ParkPalAdminSection.evidenceVault => Icons.folder_copy_outlined,
    ParkPalAdminSection.appealSupport => Icons.gavel_outlined,
    ParkPalAdminSection.reports => Icons.report_problem_outlined,
    ParkPalAdminSection.irisReview => Icons.visibility_outlined,
    ParkPalAdminSection.coverageForecast => Icons.auto_graph_outlined,
    ParkPalAdminSection.adminUsers => Icons.admin_panel_settings_outlined,
    ParkPalAdminSection.settings => Icons.settings_outlined,
  };
}
