import 'package:flutter/material.dart';

import '../../app/parkpal_theme.dart';
import 'iris_inspector_service.dart';
import 'parkpal_atlas_cards.dart';
import 'parkpal_atlas_models.dart';
import 'parkpal_atlas_service.dart';

class ParkPalAtlasAdminScreen extends StatefulWidget {
  const ParkPalAtlasAdminScreen({super.key});

  @override
  State<ParkPalAtlasAdminScreen> createState() =>
      _ParkPalAtlasAdminScreenState();
}

class _ParkPalAtlasAdminScreenState extends State<ParkPalAtlasAdminScreen> {
  final _atlasService = ParkPalAtlasService();
  late Future<_AtlasAdminData> _data;
  bool _inspecting = false;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<_AtlasAdminData> _load() async {
    final national = await _atlasService.fetchNationalSummary();
    final london = await _atlasService.fetchCitySummary('London');
    final roads = await _atlasService.fetchRoadsNeedingReview();
    final findings = await _atlasService.fetchInspectorFindings();
    return _AtlasAdminData(
      national: national,
      city: london,
      roads: roads,
      findings: findings,
    );
  }

  Future<void> _runInspector() async {
    setState(() => _inspecting = true);
    await IrisInspectorService(atlasService: _atlasService).inspectAtlasBatch();
    if (!mounted) return;
    setState(() {
      _data = _load();
      _inspecting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ParkPal Atlas / IRIS Inspector')),
      body: FutureBuilder<_AtlasAdminData>(
        future: _data,
        builder: (context, snapshot) {
          final data = snapshot.data;
          if (data == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final conflicts = data.roads
              .where((road) => road.status == AtlasRoadStatus.conflict)
              .toList(growable: false);
          final stale = data.roads
              .where((road) => road.status == AtlasRoadStatus.needs_refresh)
              .toList(growable: false);

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Atlas Overview',
                style: ParkPalText.display(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: ParkPalColors.ink,
                ),
              ),
              const SizedBox(height: 14),
              AtlasSummaryCard(
                  title: 'National Atlas summary', summary: data.national),
              const SizedBox(height: 16),
              AtlasSummaryCard(
                  title: 'City summary — London', summary: data.city),
              const SizedBox(height: 24),
              _SectionTitle(title: 'Borough Coverage'),
              AtlasSummaryCard(
                  title: 'Current borough snapshot', summary: data.city),
              const SizedBox(height: 24),
              _SectionTitle(title: 'Roads Needing Review'),
              for (final road in data.roads)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AtlasRoadProfileCard(profile: road),
                ),
              if (data.roads.isEmpty)
                const _EmptyPanel('No roads currently need review.'),
              const SizedBox(height: 24),
              _SectionTitle(title: 'Conflicts'),
              for (final road in conflicts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AtlasRoadProfileCard(profile: road),
                ),
              if (conflicts.isEmpty)
                const _EmptyPanel('No conflicts detected.'),
              const SizedBox(height: 24),
              _SectionTitle(title: 'Stale Records'),
              for (final road in stale)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AtlasRoadProfileCard(profile: road),
                ),
              if (stale.isEmpty)
                const _EmptyPanel('No stale records detected.'),
              const SizedBox(height: 24),
              _SectionTitle(title: 'Inspector Recommendations'),
              FilledButton.icon(
                onPressed: _inspecting ? null : _runInspector,
                icon: const Icon(Icons.radar),
                label: Text(_inspecting ? 'Inspecting…' : 'Run IRIS Inspector'),
              ),
              const SizedBox(height: 12),
              for (final finding in data.findings)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InspectorFindingCard(finding: finding),
                ),
              if (data.findings.isEmpty)
                const _EmptyPanel(
                  'IRIS Inspector has no recommendations. Coverage, stale-data and conflict alerts are routed here when action is needed.',
                ),
            ],
          );
        },
      ),
    );
  }
}

class _AtlasAdminData {
  const _AtlasAdminData({
    required this.national,
    required this.city,
    required this.roads,
    required this.findings,
  });

  final AtlasSummary national;
  final AtlasSummary city;
  final List<ParkPalAtlasRoadProfile> roads;
  final List<IrisInspectorFinding> findings;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: ParkPalText.display(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: ParkPalColors.ink,
        ),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: parkPalGlassDecoration(opacity: 0.82, radius: 20),
      child: Text(message, style: ParkPalText.body(color: ParkPalColors.muted)),
    );
  }
}
