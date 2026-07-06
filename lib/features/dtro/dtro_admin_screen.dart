import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../admin/parkpal_admin_theme.dart';
import 'dtro_legal_service.dart';
import 'dtro_models.dart';

class DtroAdminScreen extends StatefulWidget {
  const DtroAdminScreen({super.key});

  @override
  State<DtroAdminScreen> createState() => _DtroAdminScreenState();
}

class _DtroAdminScreenState extends State<DtroAdminScreen> {
  final _service = DtroLegalService();
  late Future<List<DtroLegalRecord>> _records;
  late Stream<Map<String, Object?>> _syncStatus;
  Map<String, Object?> _latestSyncStatus = const {};
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _records = _service.fetchLegalRecords();
    _syncStatus = _watchSyncStatus();
  }

  void _refresh() {
    setState(() {
      _records = _service.fetchLegalRecords();
      _syncStatus = _watchSyncStatus();
    });
  }

  Stream<Map<String, Object?>> _watchSyncStatus() {
    return FirebaseFirestore.instance
        .collection('parkpal_dtro_sync_status')
        .doc('live')
        .snapshots()
        .map((snapshot) => dtroWebSafeMap(snapshot.data() ?? const {}));
  }

  Future<void> _syncLiveDtro() async {
    setState(() => _syncing = true);
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'europe-west2')
          .httpsCallable('syncParkPalDtroLegalData');
      final result = await callable.call<Map<Object?, Object?>>({});
      final data = dtroWebSafeMap(result.data);
      if (!mounted) return;
      setState(() {
        _latestSyncStatus = data;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Atlas sync ${data['status']}.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Atlas sync failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _syncing = false;
          _records = _service.fetchLegalRecords();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DtroLegalRecord>>(
      future: _records,
      builder: (context, recordsSnapshot) {
        final records = recordsSnapshot.data ?? const <DtroLegalRecord>[];
        return StreamBuilder<Map<String, Object?>>(
          stream: _syncStatus,
          initialData: _latestSyncStatus,
          builder: (context, statusSnapshot) {
            final status =
                statusSnapshot.hasData && statusSnapshot.data!.isNotEmpty
                    ? statusSnapshot.data!
                    : _latestSyncStatus;
            final view = _AtlasViewData.from(status, records);
            return ListView(
              children: [
                _AtlasHero(
                  data: view,
                  syncing: _syncing,
                  onRefresh: _refresh,
                  onSync: _syncLiveDtro,
                ),
                const SizedBox(height: 28),
                _SectionTitle(
                  title: 'Source Health',
                  subtitle:
                      'Operational readiness across government data, field evidence and IRIS intelligence.',
                ),
                const SizedBox(height: 14),
                _ResponsiveGrid(
                  minItemWidth: 210,
                  children: [
                    _SourceHealthCard(
                      title: 'Government Data (D-TRO)',
                      status: view.apiConnected ? 'Connected' : 'Offline',
                      lastUpdate: view.lastSyncLabel,
                      health: view.apiConnected
                          ? _AtlasHealth.healthy
                          : _AtlasHealth.offline,
                    ),
                    _SourceHealthCard(
                      title: 'Councils',
                      status: view.apiConnected ? 'Available' : 'Pending',
                      lastUpdate: view.lastSyncLabel,
                      health: view.apiConnected
                          ? _AtlasHealth.healthy
                          : _AtlasHealth.warning,
                    ),
                    _SourceHealthCard(
                      title: 'Sign Repository',
                      status: view.verifiedSigns > 0 ? 'Active' : 'No signal',
                      lastUpdate: view.verifiedSigns > 0
                          ? view.lastSyncLabel
                          : 'Awaiting records',
                      health: view.verifiedSigns > 0
                          ? _AtlasHealth.healthy
                          : _AtlasHealth.warning,
                    ),
                    _SourceHealthCard(
                      title: 'Evidence Vault',
                      status: view.evidenceRecords > 0 ? 'Active' : 'No signal',
                      lastUpdate: view.evidenceRecords > 0
                          ? view.lastSyncLabel
                          : 'Awaiting records',
                      health: view.evidenceRecords > 0
                          ? _AtlasHealth.healthy
                          : _AtlasHealth.warning,
                    ),
                    _SourceHealthCard(
                      title: 'IRIS Intelligence',
                      status: view.apiConnected ? 'Ready' : 'Waiting',
                      lastUpdate: view.lastSyncLabel,
                      health: view.apiConnected
                          ? _AtlasHealth.healthy
                          : _AtlasHealth.warning,
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                _SectionTitle(
                  title: 'Atlas Overview',
                  subtitle: 'Current backend-backed intelligence totals.',
                ),
                const SizedBox(height: 14),
                _ResponsiveGrid(
                  minItemWidth: 220,
                  children: [
                    _KpiCard(
                      label: 'Restrictions Imported Today',
                      value: '${view.recordsImported}',
                      icon: Icons.rule_folder_outlined,
                    ),
                    _KpiCard(
                      label: 'Councils Connected',
                      value: '${view.councilsConnected}',
                      icon: Icons.account_balance_outlined,
                    ),
                    _KpiCard(
                      label: 'Verified Signs',
                      value: '${view.verifiedSigns}',
                      icon: Icons.traffic_outlined,
                    ),
                    _KpiCard(
                      label: 'Evidence Records',
                      value: '${view.evidenceRecords}',
                      icon: Icons.folder_copy_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                _TwoColumn(
                  left: _LiveImportTimeline(data: view),
                  right: _DataSourcesCard(data: view),
                ),
                const SizedBox(height: 30),
                _AtlasMapPlaceholder(data: view),
                const SizedBox(height: 30),
                _TwoColumn(
                  left: _AtlasInsights(data: view),
                  right: _RequiresAttention(data: view),
                ),
                const SizedBox(height: 30),
                _SystemHealthFooter(data: view),
                if (statusSnapshot.hasError) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Unable to read latest Atlas status: ${statusSnapshot.error}',
                    style: adminBody(color: ParkPalAdminColors.red, size: 12),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

class _AtlasViewData {
  const _AtlasViewData({
    required this.apiConnected,
    required this.recordsFetched,
    required this.recordsImported,
    required this.failures,
    required this.lastSync,
    required this.legalRecordCount,
    required this.verifiedSigns,
    required this.evidenceRecords,
  });

  final bool apiConnected;
  final int recordsFetched;
  final int recordsImported;
  final List<String> failures;
  final DateTime? lastSync;
  final int legalRecordCount;
  final int verifiedSigns;
  final int evidenceRecords;

  factory _AtlasViewData.from(
    Map<String, Object?> status,
    List<DtroLegalRecord> records,
  ) {
    final failures = (status['failures'] as List?)
            ?.map((value) => value.toString())
            .where((value) => value.isNotEmpty)
            .toList(growable: false) ??
        const <String>[];
    return _AtlasViewData(
      apiConnected: status['apiConnected'] == true,
      recordsFetched: dtroSafeInt(status['recordsFetched']) ?? 0,
      recordsImported: dtroSafeInt(status['recordsImported']) ?? 0,
      failures: failures,
      lastSync: _parseStatusDate(status['lastSyncTime']),
      legalRecordCount: records.length,
      verifiedSigns: records
          .where((record) =>
              record.verificationStatus == DtroVerificationStatus.verified)
          .length,
      evidenceRecords: records
          .where((record) => (record.rawProvision ?? const {}).isNotEmpty)
          .length,
    );
  }

  bool get successful => apiConnected && failures.isEmpty;

  int get councilsConnected => apiConnected ? 1 : 0;

  String get lastSyncLabel {
    final value = lastSync;
    if (value == null) return 'Never';
    final local = value.toLocal();
    final now = DateTime.now();
    final day = local.year == now.year &&
            local.month == now.month &&
            local.day == now.day
        ? 'Today'
        : '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
    return '$day • ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String get systemStatus => successful ? 'Operational' : 'Needs attention';

  _AtlasHealth get systemHealth =>
      successful ? _AtlasHealth.healthy : _AtlasHealth.warning;
}

class _AtlasHero extends StatelessWidget {
  const _AtlasHero({
    required this.data,
    required this.syncing,
    required this.onRefresh,
    required this.onSync,
  });

  final _AtlasViewData data;
  final bool syncing;
  final VoidCallback onRefresh;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    return _IridescentShell(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: adminGlassDecoration(radius: 30).copyWith(
          color: Colors.white.withValues(alpha: 0.07),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Atlas Intelligence', style: adminHeading(size: 54)),
                      const SizedBox(height: 10),
                      Text(
                        'Government Parking Intelligence Platform',
                        style: adminBody(
                          color: ParkPalAdminColors.muted,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_outlined),
                  label: const Text('Refresh'),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: syncing ? null : onSync,
                  icon: syncing
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync_rounded),
                  label: Text(syncing ? 'Syncing…' : 'Sync Now'),
                ),
              ],
            ),
            const SizedBox(height: 28),
            _ResponsiveGrid(
              minItemWidth: 210,
              children: [
                _HeroMetric(
                  label: 'System Status',
                  value: data.systemStatus,
                  accent: _healthColor(data.systemHealth),
                  prefix: data.successful ? '●' : '●',
                ),
                _HeroMetric(label: 'Last Sync', value: data.lastSyncLabel),
                _HeroMetric(
                  label: 'Records Imported',
                  value: '${data.recordsImported}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.label,
    required this.value,
    this.accent = ParkPalAdminColors.cyan,
    this.prefix,
  });

  final String label;
  final String value;
  final Color accent;
  final String? prefix;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _softCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: adminBody(color: ParkPalAdminColors.muted)),
          const SizedBox(height: 8),
          Text(
            [if (prefix != null) prefix, value].join(' '),
            style: adminHeading(size: 26).copyWith(color: accent),
          ),
        ],
      ),
    );
  }
}

class _SourceHealthCard extends StatelessWidget {
  const _SourceHealthCard({
    required this.title,
    required this.status,
    required this.lastUpdate,
    required this.health,
  });

  final String title;
  final String status;
  final String lastUpdate;
  final _AtlasHealth health;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: adminBody(weight: FontWeight.w800)),
              ),
              _HealthPill(health: health),
            ],
          ),
          const SizedBox(height: 18),
          Text('Status', style: adminBody(color: ParkPalAdminColors.muted)),
          const SizedBox(height: 4),
          Text(status, style: adminHeading(size: 24)),
          const SizedBox(height: 12),
          Text('Last update',
              style: adminBody(color: ParkPalAdminColors.muted)),
          const SizedBox(height: 4),
          Text(lastUpdate, style: adminBody()),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: ParkPalAdminColors.blue.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ParkPalAdminColors.glassBorder),
            ),
            child: Icon(icon, color: ParkPalAdminColors.cyan),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: adminHeading(size: 30)),
                const SizedBox(height: 4),
                Text(label, style: adminBody(color: ParkPalAdminColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveImportTimeline extends StatelessWidget {
  const _LiveImportTimeline({required this.data});

  final _AtlasViewData data;

  @override
  Widget build(BuildContext context) {
    final steps = [
      _TimelineStep('OAuth', data.apiConnected),
      _TimelineStep('Dataset', data.recordsFetched > 0),
      _TimelineStep(
          'Validated', data.recordsFetched > 0 && data.failures.isEmpty),
      _TimelineStep('Imported', data.recordsImported > 0),
      _TimelineStep('Firestore Updated', data.recordsImported > 0),
      _TimelineStep('Completed', data.successful),
    ];
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Live Import Timeline',
            subtitle: 'Current sync pipeline state.',
          ),
          const SizedBox(height: 20),
          for (var index = 0; index < steps.length; index++) ...[
            _TimelineRow(step: steps[index]),
            if (index < steps.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: 13, top: 6, bottom: 6),
                child: Container(
                  width: 2,
                  height: 18,
                  color: ParkPalAdminColors.glassBorder,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _DataSourcesCard extends StatelessWidget {
  const _DataSourcesCard({required this.data});

  final _AtlasViewData data;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Data Sources',
            subtitle: 'Operational connection view.',
          ),
          const SizedBox(height: 20),
          _InfoRow('D-TRO', data.apiConnected ? 'Connected' : 'Not connected'),
          _InfoRow('Status', data.successful ? 'Healthy' : 'Needs review'),
          _InfoRow(
            'Authentication',
            data.apiConnected ? 'Healthy' : 'Pending',
          ),
          _InfoRow('Last Import', data.lastSyncLabel),
          _InfoRow('Records Imported', '${data.recordsImported}'),
          _InfoRow('Connection', data.apiConnected ? 'Live' : 'Unavailable'),
        ],
      ),
    );
  }
}

class _AtlasMapPlaceholder extends StatelessWidget {
  const _AtlasMapPlaceholder({required this.data});

  final _AtlasViewData data;

  @override
  Widget build(BuildContext context) {
    return _IridescentShell(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: adminGlassDecoration(radius: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle(
              title: 'Atlas Map',
              subtitle:
                  'UK council intelligence coverage. Map interaction will open future council intelligence profiles.',
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _UkMapShape(connected: data.apiConnected)),
                const SizedBox(width: 24),
                SizedBox(
                  width: 230,
                  child: Column(
                    children: const [
                      _MapLegend(
                        color: ParkPalAdminColors.emerald,
                        label: 'Verified',
                      ),
                      _MapLegend(
                        color: ParkPalAdminColors.blue,
                        label: 'Updated today',
                      ),
                      _MapLegend(
                        color: ParkPalAdminColors.amber,
                        label: 'Needs review',
                      ),
                      _MapLegend(
                        color: ParkPalAdminColors.red,
                        label: 'Import failure',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AtlasInsights extends StatelessWidget {
  const _AtlasInsights({required this.data});

  final _AtlasViewData data;

  @override
  Widget build(BuildContext context) {
    final insights = <String>[
      if (data.recordsImported > 0)
        '${data.recordsImported} restrictions updated today',
      if (data.failures.isNotEmpty)
        '${data.failures.length} conflicts detected',
      if (data.verifiedSigns == 0) 'Signs awaiting verification',
      if (data.evidenceRecords == 0) 'Evidence gaps remain',
      if (data.apiConnected) 'IRIS confidence can use live government data',
    ];
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Atlas Insights',
            subtitle: 'Operational recommendations from available signals.',
          ),
          const SizedBox(height: 18),
          if (insights.isEmpty)
            Text(
              'No operational insights available yet.',
              style: adminBody(color: ParkPalAdminColors.muted),
            )
          else
            for (final insight in insights) _InsightRow(insight),
        ],
      ),
    );
  }
}

class _RequiresAttention extends StatelessWidget {
  const _RequiresAttention({required this.data});

  final _AtlasViewData data;

  @override
  Widget build(BuildContext context) {
    final items = [
      _AttentionItem(
        'Rule conflicts',
        data.failures.isEmpty
            ? 'None detected'
            : '${data.failures.length} open',
        data.failures.isEmpty ? _AtlasHealth.healthy : _AtlasHealth.warning,
      ),
      _AttentionItem(
          'Duplicate signs', 'Future workflow', _AtlasHealth.warning),
      _AttentionItem(
        'Missing evidence',
        data.evidenceRecords == 0 ? 'Needs review' : 'Tracked',
        data.evidenceRecords == 0 ? _AtlasHealth.warning : _AtlasHealth.healthy,
      ),
      _AttentionItem(
        'Manual council review',
        data.apiConnected ? 'Available' : 'Required',
        data.apiConnected ? _AtlasHealth.healthy : _AtlasHealth.offline,
      ),
    ];
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Requires Attention',
            subtitle: 'Workflow entry points for review teams.',
          ),
          const SizedBox(height: 18),
          for (final item in items) _AttentionCard(item: item),
        ],
      ),
    );
  }
}

class _SystemHealthFooter extends StatelessWidget {
  const _SystemHealthFooter({required this.data});

  final _AtlasViewData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: adminGlassDecoration(radius: 22),
      child: _ResponsiveGrid(
        minItemWidth: 190,
        children: [
          _FooterMetric('API uptime', data.apiConnected ? 'Online' : 'Offline'),
          _FooterMetric('Sync success %', data.successful ? '100%' : '0%'),
          const _FooterMetric('Average sync duration', 'Pending trend'),
          _FooterMetric('Last successful import', data.lastSyncLabel),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: adminHeading(size: 28)),
        const SizedBox(height: 6),
        Text(subtitle, style: adminBody(color: ParkPalAdminColors.muted)),
      ],
    );
  }
}

class _ResponsiveGrid extends StatelessWidget {
  const _ResponsiveGrid({required this.children, this.minItemWidth = 240});

  final List<Widget> children;
  final double minItemWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / minItemWidth)
            .floor()
            .clamp(1, children.length);
        final width = (constraints.maxWidth - ((columns - 1) * 14)) / columns;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

class _TwoColumn extends StatelessWidget {
  const _TwoColumn({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Column(children: [left, const SizedBox(height: 14), right]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 14),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _softCardDecoration(),
      child: child,
    );
  }
}

class _IridescentShell extends StatelessWidget {
  const _IridescentShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        gradient: adminIridescentGradient(),
        borderRadius: BorderRadius.circular(31),
      ),
      child: child,
    );
  }
}

class _HealthPill extends StatelessWidget {
  const _HealthPill({required this.health});

  final _AtlasHealth health;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _healthColor(health).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _healthColor(health).withValues(alpha: 0.4)),
      ),
      child: Text(
        _healthLabel(health),
        style: adminBody(color: _healthColor(health), size: 12),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.step});

  final _TimelineStep step;

  @override
  Widget build(BuildContext context) {
    final color =
        step.complete ? ParkPalAdminColors.emerald : ParkPalAdminColors.amber;
    return Row(
      children: [
        Icon(
          step.complete ? Icons.check_circle_rounded : Icons.pending_rounded,
          color: color,
          size: 28,
        ),
        const SizedBox(width: 12),
        Text(step.label, style: adminBody(weight: FontWeight.w800)),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child:
                Text(label, style: adminBody(color: ParkPalAdminColors.muted)),
          ),
          Text(value, style: adminBody(weight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _UkMapShape extends StatelessWidget {
  const _UkMapShape({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    final color =
        connected ? ParkPalAdminColors.emerald : ParkPalAdminColors.amber;
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: ParkPalAdminColors.glassBorder),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 42,
            child: Icon(
              Icons.map_outlined,
              size: 170,
              color: color.withValues(alpha: 0.26),
            ),
          ),
          Positioned(
            top: 52,
            left: 90,
            child: _CouncilDot(color: ParkPalAdminColors.blue),
          ),
          Positioned(
            top: 114,
            right: 150,
            child: _CouncilDot(color: color),
          ),
          Positioned(
            bottom: 84,
            left: 180,
            child: const _CouncilDot(color: ParkPalAdminColors.amber),
          ),
          Positioned(
            bottom: 58,
            right: 86,
            child: _CouncilDot(
              color: connected
                  ? ParkPalAdminColors.emerald
                  : ParkPalAdminColors.red,
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Council intelligence map placeholder',
                style: adminBody(color: ParkPalAdminColors.muted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CouncilDot extends StatelessWidget {
  const _CouncilDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.6),
            blurRadius: 18,
          ),
        ],
      ),
    );
  }
}

class _MapLegend extends StatelessWidget {
  const _MapLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          _CouncilDot(color: color),
          const SizedBox(width: 10),
          Text(label, style: adminBody()),
        ],
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.auto_awesome_outlined,
            color: ParkPalAdminColors.cyan,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: adminBody())),
        ],
      ),
    );
  }
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({required this.item});

  final _AttentionItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ParkPalAdminColors.glassBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.chevron_right_rounded, color: _healthColor(item.health)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(item.title, style: adminBody(weight: FontWeight.w800)),
          ),
          Text(
            item.status,
            style: adminBody(color: _healthColor(item.health), size: 12),
          ),
        ],
      ),
    );
  }
}

class _FooterMetric extends StatelessWidget {
  const _FooterMetric(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: adminBody(color: ParkPalAdminColors.muted)),
        const SizedBox(height: 6),
        Text(value, style: adminBody(weight: FontWeight.w800)),
      ],
    );
  }
}

class _TimelineStep {
  const _TimelineStep(this.label, this.complete);

  final String label;
  final bool complete;
}

class _AttentionItem {
  const _AttentionItem(this.title, this.status, this.health);

  final String title;
  final String status;
  final _AtlasHealth health;
}

enum _AtlasHealth { healthy, warning, offline }

BoxDecoration _softCardDecoration() {
  return adminGlassDecoration(radius: 22).copyWith(
    color: Colors.white.withValues(alpha: 0.06),
  );
}

Color _healthColor(_AtlasHealth health) {
  return switch (health) {
    _AtlasHealth.healthy => ParkPalAdminColors.emerald,
    _AtlasHealth.warning => ParkPalAdminColors.amber,
    _AtlasHealth.offline => ParkPalAdminColors.red,
  };
}

String _healthLabel(_AtlasHealth health) {
  return switch (health) {
    _AtlasHealth.healthy => 'Healthy',
    _AtlasHealth.warning => 'Warning',
    _AtlasHealth.offline => 'Offline',
  };
}

DateTime? _parseStatusDate(Object? value) {
  if (value is DateTime) return value;
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
