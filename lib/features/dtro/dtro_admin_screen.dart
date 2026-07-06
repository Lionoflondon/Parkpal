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
                _AtlasMapSection(data: view),
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

class _AtlasMapSection extends StatefulWidget {
  const _AtlasMapSection({required this.data});

  final _AtlasViewData data;

  @override
  State<_AtlasMapSection> createState() => _AtlasMapSectionState();
}

class _AtlasMapSectionState extends State<_AtlasMapSection> {
  final TransformationController _controller = TransformationController();
  final TextEditingController _searchController = TextEditingController();
  final Set<_CouncilStatus> _filters = {..._CouncilStatus.values};
  final Set<_AtlasLayer> _layers = {..._AtlasLayer.values};
  String? _hoveredCouncilId;
  String? _selectedCouncilId;
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<_AtlasCouncil> get _councils => _buildCouncilData(widget.data);

  List<_AtlasCouncil> get _visibleCouncils {
    final normalizedQuery = _query.trim().toLowerCase();
    return _councils.where((council) {
      final matchesFilter = _filters.contains(council.status);
      final matchesSearch = normalizedQuery.isEmpty ||
          council.name.toLowerCase().contains(normalizedQuery);
      return matchesFilter && matchesSearch;
    }).toList(growable: false);
  }

  _AtlasCouncil? _findCouncil(String? id) {
    if (id == null) return null;
    for (final council in _councils) {
      if (council.id == id) return council;
    }
    return null;
  }

  void _zoom(double scale) {
    _controller.value = _controller.value.clone()
      ..multiply(Matrix4.diagonal3Values(scale, scale, 1));
  }

  void _resetMap() {
    setState(() {
      _controller.value = Matrix4.identity();
      _hoveredCouncilId = null;
      _selectedCouncilId = null;
      _query = '';
      _searchController.clear();
      _filters
        ..clear()
        ..addAll(_CouncilStatus.values);
      _layers
        ..clear()
        ..addAll(_AtlasLayer.values);
    });
  }

  @override
  Widget build(BuildContext context) {
    final visibleCouncils = _visibleCouncils;
    final selectedCouncil =
        _findCouncil(_selectedCouncilId) ?? _findCouncil(_hoveredCouncilId);
    return _IridescentShell(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: adminGlassDecoration(radius: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: _SectionTitle(
                    title: 'Atlas Map',
                    subtitle:
                        'Interactive UK operational intelligence coverage by council area.',
                  ),
                ),
                _MapControlButton(
                  icon: Icons.add_rounded,
                  label: 'Zoom',
                  onPressed: () => _zoom(1.18),
                ),
                const SizedBox(width: 8),
                _MapControlButton(
                  icon: Icons.remove_rounded,
                  label: 'Pan',
                  onPressed: () => _zoom(0.86),
                ),
                const SizedBox(width: 8),
                _MapControlButton(
                  icon: Icons.restart_alt_rounded,
                  label: 'Reset',
                  onPressed: _resetMap,
                ),
              ],
            ),
            const SizedBox(height: 24),
            _AtlasMapToolbar(
              controller: _searchController,
              filters: _filters,
              layers: _layers,
              onQueryChanged: (value) => setState(() => _query = value),
              onFilterChanged: (status) => setState(() {
                _filters.contains(status)
                    ? _filters.remove(status)
                    : _filters.add(status);
              }),
              onLayerChanged: (layer) => setState(() {
                _layers.contains(layer)
                    ? _layers.remove(layer)
                    : _layers.add(layer);
              }),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 960;
                final map = _InteractiveUkMap(
                  controller: _controller,
                  councils: visibleCouncils,
                  hoveredCouncilId: _hoveredCouncilId,
                  selectedCouncilId: _selectedCouncilId,
                  activeLayers: _layers,
                  lastSyncLabel: widget.data.lastSyncLabel,
                  onHover: (council) =>
                      setState(() => _hoveredCouncilId = council?.id),
                  onSelect: (council) =>
                      setState(() => _selectedCouncilId = council.id),
                );
                final panel = _CouncilIntelligencePanel(
                  council: selectedCouncil,
                  lastSyncFallback: widget.data.lastSyncLabel,
                );
                if (compact) {
                  return Column(
                    children: [
                      map,
                      const SizedBox(height: 16),
                      panel,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: map),
                    const SizedBox(width: 18),
                    Expanded(flex: 2, child: panel),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final status in _CouncilStatus.values)
                  _MapLegend(
                    color: _councilStatusColor(status),
                    label: _councilStatusLabel(status),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AtlasMapToolbar extends StatelessWidget {
  const _AtlasMapToolbar({
    required this.controller,
    required this.filters,
    required this.layers,
    required this.onQueryChanged,
    required this.onFilterChanged,
    required this.onLayerChanged,
  });

  final TextEditingController controller;
  final Set<_CouncilStatus> filters;
  final Set<_AtlasLayer> layers;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<_CouncilStatus> onFilterChanged;
  final ValueChanged<_AtlasLayer> onLayerChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          onChanged: onQueryChanged,
          style: adminBody(),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            hintText: 'Search council',
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final status in [
              _CouncilStatus.verified,
              _CouncilStatus.needsReview,
              _CouncilStatus.updatedToday,
              _CouncilStatus.importFailed,
            ])
              FilterChip(
                selected: filters.contains(status),
                onSelected: (_) => onFilterChanged(status),
                label: Text(_councilStatusLabel(status)),
                avatar: Icon(
                  Icons.circle,
                  size: 10,
                  color: _councilStatusColor(status),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final layer in _AtlasLayer.values)
              FilterChip(
                selected: layers.contains(layer),
                onSelected: (_) => onLayerChanged(layer),
                label: Text(_layerLabel(layer)),
                avatar: Icon(_layerIcon(layer), size: 18),
              ),
          ],
        ),
      ],
    );
  }
}

class _InteractiveUkMap extends StatelessWidget {
  const _InteractiveUkMap({
    required this.controller,
    required this.councils,
    required this.hoveredCouncilId,
    required this.selectedCouncilId,
    required this.activeLayers,
    required this.lastSyncLabel,
    required this.onHover,
    required this.onSelect,
  });

  final TransformationController controller;
  final List<_AtlasCouncil> councils;
  final String? hoveredCouncilId;
  final String? selectedCouncilId;
  final Set<_AtlasLayer> activeLayers;
  final String lastSyncLabel;
  final ValueChanged<_AtlasCouncil?> onHover;
  final ValueChanged<_AtlasCouncil> onSelect;

  @override
  Widget build(BuildContext context) {
    final hovered = _findInList(councils, hoveredCouncilId);
    return Container(
      height: 620,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: ParkPalAdminColors.glassBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              transformationController: controller,
              minScale: 0.86,
              maxScale: 3.2,
              boundaryMargin: const EdgeInsets.all(160),
              child: Center(
                child: SizedBox(
                  width: 560,
                  height: 600,
                  child: RepaintBoundary(
                    child: Stack(
                      children: [
                        const Positioned.fill(child: _UkSeaGlow()),
                        for (final council in councils)
                          _CouncilRegion(
                            key: ValueKey(council.id),
                            council: council,
                            selected: council.id == selectedCouncilId,
                            hovered: council.id == hoveredCouncilId,
                            pulse: council.updatedToday,
                            activeLayers: activeLayers,
                            onHover: onHover,
                            onSelect: onSelect,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (hovered != null)
            Positioned(
              top: 18,
              right: 18,
              child: _CouncilHoverCard(
                council: hovered,
                lastSyncFallback: lastSyncLabel,
              ),
            ),
          Positioned(
            left: 18,
            bottom: 18,
            child: _MapGlassBadge(
              icon: Icons.touch_app_outlined,
              label: 'Hover for detail • Click for council intelligence',
            ),
          ),
        ],
      ),
    );
  }
}

class _CouncilRegion extends StatelessWidget {
  const _CouncilRegion({
    super.key,
    required this.council,
    required this.selected,
    required this.hovered,
    required this.pulse,
    required this.activeLayers,
    required this.onHover,
    required this.onSelect,
  });

  final _AtlasCouncil council;
  final bool selected;
  final bool hovered;
  final bool pulse;
  final Set<_AtlasLayer> activeLayers;
  final ValueChanged<_AtlasCouncil?> onHover;
  final ValueChanged<_AtlasCouncil> onSelect;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: council.bounds.left,
      top: council.bounds.top,
      width: council.bounds.width,
      height: council.bounds.height,
      child: MouseRegion(
        onEnter: (_) => onHover(council),
        onExit: (_) => onHover(null),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => onSelect(council),
          child: AnimatedScale(
            scale: selected
                ? 1.08
                : hovered
                    ? 1.04
                    : 1,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: Stack(
              children: [
                if (pulse)
                  Positioned.fill(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 1600),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: (1 - value) * 0.45,
                          child: Transform.scale(
                            scale: 1 + (value * 0.32),
                            child: child,
                          ),
                        );
                      },
                      child: CustomPaint(
                        painter: _CouncilPathPainter(
                          council: council,
                          fill: _councilStatusColor(council.status),
                          stroke: Colors.transparent,
                        ),
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    child: CustomPaint(
                      painter: _CouncilPathPainter(
                        council: council,
                        fill: _councilStatusColor(council.status).withValues(
                            alpha: hovered || selected ? 0.92 : 0.72),
                        stroke: selected || hovered
                            ? ParkPalAdminColors.cyan
                            : Colors.white.withValues(alpha: 0.42),
                        strokeWidth: selected
                            ? 2.4
                            : hovered
                                ? 2
                                : 1,
                      ),
                    ),
                  ),
                ),
                ..._layerMarkers(council, activeLayers),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CouncilPathPainter extends CustomPainter {
  const _CouncilPathPainter({
    required this.council,
    required this.fill,
    required this.stroke,
    this.strokeWidth = 1,
  });

  final _AtlasCouncil council;
  final Color fill;
  final Color stroke;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    for (var index = 0; index < council.points.length; index++) {
      final point = council.points[index];
      final offset = Offset(point.dx * size.width, point.dy * size.height);
      index == 0
          ? path.moveTo(offset.dx, offset.dy)
          : path.lineTo(offset.dx, offset.dy);
    }
    path.close();
    canvas.drawShadow(path, fill.withValues(alpha: 0.42), 12, true);
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _CouncilPathPainter oldDelegate) {
    return oldDelegate.fill != fill ||
        oldDelegate.stroke != stroke ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.council != council;
  }
}

class _CouncilHoverCard extends StatelessWidget {
  const _CouncilHoverCard({
    required this.council,
    required this.lastSyncFallback,
  });

  final _AtlasCouncil council;
  final String lastSyncFallback;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 250,
      padding: const EdgeInsets.all(16),
      decoration: adminGlassDecoration(radius: 20).copyWith(
        color: ParkPalAdminColors.panel.withValues(alpha: 0.9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(council.name, style: adminHeading(size: 24)),
          const SizedBox(height: 10),
          _InfoRow('Verification', '${council.verificationPercent}%'),
          _InfoRow('Last Sync', council.lastSync ?? lastSyncFallback),
          _InfoRow('Restrictions', '${council.restrictions}'),
          _InfoRow('Sign Coverage', '${council.signCoveragePercent}%'),
          _InfoRow('Confidence', '${council.confidencePercent}%'),
        ],
      ),
    );
  }
}

class _CouncilIntelligencePanel extends StatelessWidget {
  const _CouncilIntelligencePanel({
    required this.council,
    required this.lastSyncFallback,
  });

  final _AtlasCouncil? council;
  final String lastSyncFallback;

  @override
  Widget build(BuildContext context) {
    final selected = council;
    if (selected == null) {
      return _GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Council Intelligence', style: adminHeading(size: 30)),
            const SizedBox(height: 10),
            Text(
              'Select a council area to open Atlas operational intelligence.',
              style: adminBody(color: ParkPalAdminColors.muted),
            ),
            const SizedBox(height: 22),
            const _MapGlassBadge(
              icon: Icons.map_outlined,
              label: 'Road Rules • Evidence • Appeals • IRIS • Missions',
            ),
          ],
        ),
      );
    }
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text(selected.name, style: adminHeading(size: 32))),
              _HealthPill(health: _healthForCouncilStatus(selected.status)),
            ],
          ),
          const SizedBox(height: 18),
          _InfoRow('Council', selected.name),
          _InfoRow('Status', _councilStatusLabel(selected.status)),
          _InfoRow('Last Sync', selected.lastSync ?? lastSyncFallback),
          _InfoRow('Restrictions Imported', '${selected.restrictions}'),
          _InfoRow('Verified Signs', '${selected.verifiedSigns}'),
          _InfoRow('Evidence Records', '${selected.evidenceRecords}'),
          _InfoRow('Conflicts', '${selected.conflicts}'),
          _InfoRow('Temporary Orders', '${selected.temporaryOrders}'),
          _InfoRow('Confidence', '${selected.confidencePercent}%'),
          const SizedBox(height: 18),
          Text('Latest Activity', style: adminBody(weight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(selected.latestActivity,
              style: adminBody(color: ParkPalAdminColors.muted)),
          const SizedBox(height: 18),
          Text('Future Pioneer Missions',
              style: adminBody(weight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(selected.futureMissions,
              style: adminBody(color: ParkPalAdminColors.muted)),
        ],
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _MapGlassBadge extends StatelessWidget {
  const _MapGlassBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: adminGlassDecoration(radius: 999).copyWith(
        color: ParkPalAdminColors.panel.withValues(alpha: 0.72),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: ParkPalAdminColors.cyan, size: 18),
          const SizedBox(width: 8),
          Text(label, style: adminBody(size: 12)),
        ],
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
          _StatusDot(color: color),
          const SizedBox(width: 10),
          Text(label, style: adminBody()),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color, this.size = 18});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
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

class _UkSeaGlow extends StatelessWidget {
  const _UkSeaGlow();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 0.9,
          colors: [
            ParkPalAdminColors.blue.withValues(alpha: 0.16),
            ParkPalAdminColors.cyan.withValues(alpha: 0.05),
            Colors.transparent,
          ],
        ),
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

class _AtlasCouncil {
  const _AtlasCouncil({
    required this.id,
    required this.name,
    required this.bounds,
    required this.points,
    required this.status,
    required this.verificationPercent,
    required this.restrictions,
    required this.signCoveragePercent,
    required this.confidencePercent,
    required this.verifiedSigns,
    required this.evidenceRecords,
    required this.conflicts,
    required this.temporaryOrders,
    required this.latestActivity,
    required this.futureMissions,
    this.lastSync,
    this.updatedToday = false,
  });

  final String id;
  final String name;
  final Rect bounds;
  final List<Offset> points;
  final _CouncilStatus status;
  final int verificationPercent;
  final int restrictions;
  final int signCoveragePercent;
  final int confidencePercent;
  final int verifiedSigns;
  final int evidenceRecords;
  final int conflicts;
  final int temporaryOrders;
  final String latestActivity;
  final String futureMissions;
  final String? lastSync;
  final bool updatedToday;
}

enum _CouncilStatus {
  verified,
  updatedToday,
  needsReview,
  importFailed,
  noData,
}

enum _AtlasLayer {
  governmentData,
  signs,
  evidence,
  conflicts,
  irisConfidence,
}

List<_AtlasCouncil> _buildCouncilData(_AtlasViewData data) {
  final imported = data.recordsImported;
  final fetched = data.recordsFetched;
  final lastSync = data.lastSyncLabel;
  final baseRestrictions = imported > 0 ? imported : fetched;
  return [
    _council(
      id: 'glasgow',
      name: 'Glasgow City',
      bounds: const Rect.fromLTWH(238, 34, 86, 82),
      points: const [
        Offset(0.28, 0.06),
        Offset(0.74, 0.02),
        Offset(0.96, 0.42),
        Offset(0.76, 0.94),
        Offset(0.24, 0.84),
        Offset(0.06, 0.32),
      ],
      status: _CouncilStatus.noData,
      lastSync: 'Awaiting feed',
      restrictions: 0,
    ),
    _council(
      id: 'edinburgh',
      name: 'City of Edinburgh',
      bounds: const Rect.fromLTWH(330, 72, 92, 72),
      points: const [
        Offset(0.16, 0.12),
        Offset(0.88, 0.04),
        Offset(0.96, 0.56),
        Offset(0.58, 0.92),
        Offset(0.08, 0.74),
      ],
      status: _CouncilStatus.noData,
      lastSync: 'Awaiting feed',
      restrictions: 0,
    ),
    _council(
      id: 'newcastle',
      name: 'Newcastle City Council',
      bounds: const Rect.fromLTWH(344, 168, 82, 82),
      points: const [
        Offset(0.20, 0.06),
        Offset(0.84, 0.20),
        Offset(0.90, 0.72),
        Offset(0.48, 0.96),
        Offset(0.08, 0.58),
      ],
      status: _CouncilStatus.needsReview,
      lastSync: 'Awaiting review',
      restrictions: 12,
    ),
    _council(
      id: 'leeds',
      name: 'Leeds City Council',
      bounds: const Rect.fromLTWH(312, 260, 92, 88),
      points: const [
        Offset(0.22, 0.02),
        Offset(0.92, 0.18),
        Offset(0.80, 0.88),
        Offset(0.28, 0.98),
        Offset(0.04, 0.46),
      ],
      status: _CouncilStatus.needsReview,
      lastSync: 'Needs council source',
      restrictions: 18,
    ),
    _council(
      id: 'manchester',
      name: 'Manchester City Council',
      bounds: const Rect.fromLTWH(226, 330, 94, 88),
      points: const [
        Offset(0.16, 0.12),
        Offset(0.70, 0.02),
        Offset(0.98, 0.42),
        Offset(0.72, 0.92),
        Offset(0.18, 0.80),
        Offset(0.02, 0.36),
      ],
      status: _CouncilStatus.noData,
      lastSync: 'Awaiting feed',
      restrictions: 0,
    ),
    _council(
      id: 'birmingham',
      name: 'Birmingham City Council',
      bounds: const Rect.fromLTWH(258, 426, 98, 90),
      points: const [
        Offset(0.10, 0.16),
        Offset(0.58, 0.02),
        Offset(0.96, 0.34),
        Offset(0.88, 0.82),
        Offset(0.38, 0.96),
        Offset(0.02, 0.58),
      ],
      status: _CouncilStatus.needsReview,
      lastSync: 'Evidence required',
      restrictions: 22,
    ),
    _council(
      id: 'cardiff',
      name: 'Cardiff Council',
      bounds: const Rect.fromLTWH(162, 490, 92, 84),
      points: const [
        Offset(0.24, 0.04),
        Offset(0.90, 0.24),
        Offset(0.78, 0.88),
        Offset(0.16, 0.94),
        Offset(0.02, 0.40),
      ],
      status: _CouncilStatus.noData,
      lastSync: 'Awaiting feed',
      restrictions: 0,
    ),
    _council(
      id: 'bristol',
      name: 'Bristol City Council',
      bounds: const Rect.fromLTWH(246, 528, 84, 78),
      points: const [
        Offset(0.18, 0.08),
        Offset(0.78, 0.02),
        Offset(0.96, 0.50),
        Offset(0.62, 0.96),
        Offset(0.04, 0.72),
      ],
      status: _CouncilStatus.needsReview,
      lastSync: 'Needs evidence',
      restrictions: 9,
    ),
    _council(
      id: 'westminster',
      name: 'Westminster City Council',
      bounds: const Rect.fromLTWH(366, 500, 88, 76),
      points: const [
        Offset(0.12, 0.18),
        Offset(0.72, 0.04),
        Offset(0.96, 0.42),
        Offset(0.82, 0.86),
        Offset(0.28, 0.96),
        Offset(0.02, 0.58),
      ],
      status: data.successful
          ? _CouncilStatus.updatedToday
          : data.failures.isNotEmpty
              ? _CouncilStatus.importFailed
              : _CouncilStatus.needsReview,
      verificationPercent: data.successful ? 92 : 41,
      restrictions: baseRestrictions,
      signCoveragePercent: data.successful ? 78 : 34,
      confidencePercent: data.successful ? 94 : 42,
      verifiedSigns: data.verifiedSigns,
      evidenceRecords: data.evidenceRecords,
      conflicts: data.failures.length,
      temporaryOrders: data.successful ? 3 : 0,
      lastSync: lastSync,
      updatedToday: data.successful,
      latestActivity: data.successful
          ? 'Live D-TRO import completed and Atlas legal records updated.'
          : 'Awaiting successful government data import.',
      futureMissions: data.successful
          ? 'Verify high-demand streets and capture field evidence for imported restrictions.'
          : 'Run sync, then assign Pioneer checks for low-confidence roads.',
    ),
    _council(
      id: 'camden',
      name: 'London Borough of Camden',
      bounds: const Rect.fromLTWH(444, 486, 88, 82),
      points: const [
        Offset(0.18, 0.04),
        Offset(0.86, 0.12),
        Offset(0.96, 0.66),
        Offset(0.50, 0.96),
        Offset(0.02, 0.74),
      ],
      status: _CouncilStatus.verified,
      lastSync: data.apiConnected ? lastSync : 'Previous import',
      restrictions: data.apiConnected ? 31 : 18,
      verificationPercent: 86,
      signCoveragePercent: 76,
      confidencePercent: 88,
      verifiedSigns: 12,
      evidenceRecords: 18,
      updatedToday: data.apiConnected,
    ),
    _council(
      id: 'kensington',
      name: 'Royal Borough of Kensington and Chelsea',
      bounds: const Rect.fromLTWH(344, 578, 86, 74),
      points: const [
        Offset(0.12, 0.10),
        Offset(0.72, 0.00),
        Offset(0.94, 0.52),
        Offset(0.60, 0.96),
        Offset(0.08, 0.78),
      ],
      status: _CouncilStatus.verified,
      lastSync: 'Verified field evidence',
      restrictions: 24,
      verificationPercent: 84,
      signCoveragePercent: 82,
      confidencePercent: 89,
      verifiedSigns: 15,
      evidenceRecords: 20,
    ),
    _council(
      id: 'southwark',
      name: 'London Borough of Southwark',
      bounds: const Rect.fromLTWH(454, 584, 92, 84),
      points: const [
        Offset(0.08, 0.16),
        Offset(0.58, 0.02),
        Offset(0.98, 0.34),
        Offset(0.80, 0.92),
        Offset(0.28, 0.98),
      ],
      status: _CouncilStatus.needsReview,
      lastSync: 'Needs review',
      restrictions: 15,
    ),
    _council(
      id: 'brighton',
      name: 'Brighton & Hove City Council',
      bounds: const Rect.fromLTWH(378, 688, 92, 76),
      points: const [
        Offset(0.12, 0.28),
        Offset(0.82, 0.08),
        Offset(0.94, 0.60),
        Offset(0.48, 0.96),
        Offset(0.02, 0.70),
      ],
      status: _CouncilStatus.noData,
      lastSync: 'Awaiting feed',
      restrictions: 0,
    ),
  ];
}

_AtlasCouncil _council({
  required String id,
  required String name,
  required Rect bounds,
  required List<Offset> points,
  required _CouncilStatus status,
  String? lastSync,
  int verificationPercent = 0,
  int restrictions = 0,
  int signCoveragePercent = 0,
  int confidencePercent = 0,
  int verifiedSigns = 0,
  int evidenceRecords = 0,
  int conflicts = 0,
  int temporaryOrders = 0,
  bool updatedToday = false,
  String latestActivity = 'No recent Atlas activity recorded.',
  String futureMissions = 'Future Pioneer Missions can be generated here.',
}) {
  return _AtlasCouncil(
    id: id,
    name: name,
    bounds: bounds,
    points: points,
    status: status,
    verificationPercent: verificationPercent,
    restrictions: restrictions,
    signCoveragePercent: signCoveragePercent,
    confidencePercent: confidencePercent,
    verifiedSigns: verifiedSigns,
    evidenceRecords: evidenceRecords,
    conflicts: conflicts,
    temporaryOrders: temporaryOrders,
    latestActivity: latestActivity,
    futureMissions: futureMissions,
    lastSync: lastSync,
    updatedToday: updatedToday,
  );
}

_AtlasCouncil? _findInList(List<_AtlasCouncil> councils, String? id) {
  if (id == null) return null;
  for (final council in councils) {
    if (council.id == id) return council;
  }
  return null;
}

List<Widget> _layerMarkers(
  _AtlasCouncil council,
  Set<_AtlasLayer> activeLayers,
) {
  final markers = <Widget>[];
  void add(_AtlasLayer layer, Color color, Alignment alignment) {
    if (!activeLayers.contains(layer)) return;
    markers.add(
      Align(
        alignment: alignment,
        child: _StatusDot(color: color, size: 8),
      ),
    );
  }

  add(_AtlasLayer.governmentData, ParkPalAdminColors.blue, Alignment.topCenter);
  add(_AtlasLayer.signs, ParkPalAdminColors.emerald, Alignment.centerLeft);
  add(_AtlasLayer.evidence, ParkPalAdminColors.cyan, Alignment.centerRight);
  if (council.conflicts > 0 || council.status == _CouncilStatus.importFailed) {
    add(_AtlasLayer.conflicts, ParkPalAdminColors.red, Alignment.bottomCenter);
  }
  add(
    _AtlasLayer.irisConfidence,
    council.confidencePercent >= 80
        ? ParkPalAdminColors.emerald
        : ParkPalAdminColors.amber,
    Alignment.center,
  );
  return markers;
}

_AtlasHealth _healthForCouncilStatus(_CouncilStatus status) {
  return switch (status) {
    _CouncilStatus.verified ||
    _CouncilStatus.updatedToday =>
      _AtlasHealth.healthy,
    _CouncilStatus.needsReview || _CouncilStatus.noData => _AtlasHealth.warning,
    _CouncilStatus.importFailed => _AtlasHealth.offline,
  };
}

Color _councilStatusColor(_CouncilStatus status) {
  return switch (status) {
    _CouncilStatus.verified => ParkPalAdminColors.emerald,
    _CouncilStatus.updatedToday => ParkPalAdminColors.blue,
    _CouncilStatus.needsReview => ParkPalAdminColors.amber,
    _CouncilStatus.importFailed => ParkPalAdminColors.red,
    _CouncilStatus.noData => ParkPalAdminColors.muted,
  };
}

String _councilStatusLabel(_CouncilStatus status) {
  return switch (status) {
    _CouncilStatus.verified => 'Verified',
    _CouncilStatus.updatedToday => 'Updated today',
    _CouncilStatus.needsReview => 'Needs review',
    _CouncilStatus.importFailed => 'Import failure',
    _CouncilStatus.noData => 'No data yet',
  };
}

String _layerLabel(_AtlasLayer layer) {
  return switch (layer) {
    _AtlasLayer.governmentData => 'Government Data',
    _AtlasLayer.signs => 'Signs',
    _AtlasLayer.evidence => 'Evidence',
    _AtlasLayer.conflicts => 'Conflicts',
    _AtlasLayer.irisConfidence => 'IRIS Confidence',
  };
}

IconData _layerIcon(_AtlasLayer layer) {
  return switch (layer) {
    _AtlasLayer.governmentData => Icons.account_balance_outlined,
    _AtlasLayer.signs => Icons.traffic_outlined,
    _AtlasLayer.evidence => Icons.folder_copy_outlined,
    _AtlasLayer.conflicts => Icons.warning_amber_rounded,
    _AtlasLayer.irisConfidence => Icons.auto_awesome_outlined,
  };
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
