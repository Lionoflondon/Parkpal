import 'package:flutter/material.dart';

import '../../app/parkpal_platform_routes.dart';
import '../../app/parkpal_theme.dart';
import '../parkpal_atlas/parkpal_atlas_models.dart';
import '../parkpal_atlas/parkpal_atlas_service.dart';
import 'aie_import_engine.dart';
import 'aie_models.dart';

class CustomerAtlasScreen extends StatefulWidget {
  const CustomerAtlasScreen({
    required this.onNavigate,
    this.atlasService,
    this.importEngine,
    super.key,
  });

  final ValueChanged<String> onNavigate;
  final ParkPalAtlasService? atlasService;
  final AieImportEngine? importEngine;

  @override
  State<CustomerAtlasScreen> createState() => _CustomerAtlasScreenState();
}

class _CustomerAtlasScreenState extends State<CustomerAtlasScreen> {
  late Future<_CustomerAtlasData> _data;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<_CustomerAtlasData> _load() async {
    final atlasService = widget.atlasService ?? ParkPalAtlasService();
    final importEngine = widget.importEngine ?? AieImportEngine();
    final results = await Future.wait<Object>([
      atlasService.fetchNationalSummary(),
      atlasService.fetchRoadsNeedingReview(limit: 8),
      importEngine.fetchDashboardSummary(),
    ]);
    return _CustomerAtlasData(
      summary: results[0] as AtlasSummary,
      roadsNeedingReview: results[1] as List<ParkPalAtlasRoadProfile>,
      imports: results[2] as AieDashboardSummary,
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _data = _load());
        await _data;
      },
      child: FutureBuilder<_CustomerAtlasData>(
        future: _data,
        builder: (context, snapshot) {
          final data = snapshot.data ?? _CustomerAtlasData.empty;
          final loading = snapshot.connectionState == ConnectionState.waiting;

          return ListView(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 128),
            children: [
              _AtlasHero(data: data, loading: loading),
              const SizedBox(height: 18),
              _AtlasKpis(data: data),
              const SizedBox(height: 18),
              _AtlasMapCard(data: data),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 820;
                  final sources = _SourceHealthCard(data: data);
                  final review = _RoadsNeedingReviewCard(
                    roads: data.roadsNeedingReview,
                    onReport: () =>
                        widget.onNavigate(ParkPalPlatformRoutes.reports),
                  );
                  if (!wide) {
                    return Column(
                      children: [sources, const SizedBox(height: 18), review],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: sources),
                      const SizedBox(width: 18),
                      Expanded(child: review),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AtlasHero extends StatelessWidget {
  const _AtlasHero({
    required this.data,
    required this.loading,
  });

  final _CustomerAtlasData data;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ParkPalColors.green900,
            ParkPalColors.navy,
            ParkPalColors.irisBlue.withValues(alpha: 0.82),
          ],
        ),
        borderRadius: BorderRadius.circular(38),
        boxShadow: [
          BoxShadow(
            color: ParkPalColors.irisBlue.withValues(alpha: 0.18),
            blurRadius: 34,
            offset: const Offset(0, 22),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loading ? 'ATLAS SYNCING' : 'ATLAS INTELLIGENCE',
            style: ParkPalText.mono(
              color: ParkPalColors.irisCyan,
              fontWeight: FontWeight.w900,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Live Map',
            style: ParkPalText.display(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Government data, verified signs, evidence records and IRIS confidence in one operational Atlas view.',
            style: ParkPalText.body(
              color: Colors.white.withValues(alpha: 0.78),
              height: 1.5,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroPill('Coverage', '${data.summary.coveragePercent.round()}%'),
              _HeroPill('PCI', '${data.summary.pciScore.round()}'),
              _HeroPill('Councils', '${data.imports.connectedCouncils}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _AtlasKpis extends StatelessWidget {
  const _AtlasKpis({required this.data});

  final _CustomerAtlasData data;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _Kpi('Known roads', '${data.summary.totalKnownRoads}',
          Icons.signpost_rounded),
      _Kpi('Verified roads', '${data.summary.verifiedRoads}',
          Icons.verified_rounded),
      _Kpi('Import logs', '${data.imports.importLogs}',
          Icons.cloud_done_rounded),
      _Kpi('Conflicts', '${data.summary.conflicts}', Icons.warning_rounded),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 820;
        return GridView.count(
          crossAxisCount: wide ? 4 : 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: wide ? 1.55 : 1.25,
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          children: [
            for (final card in cards) _KpiCard(card: card),
          ],
        );
      },
    );
  }
}

class _AtlasMapCard extends StatelessWidget {
  const _AtlasMapCard({required this.data});

  final _CustomerAtlasData data;

  @override
  Widget build(BuildContext context) {
    final coverage = (data.summary.coveragePercent / 100).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: parkPalGlassDecoration(opacity: 0.94, radius: 34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'UK parking intelligence coverage',
            style: ParkPalText.display(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: ParkPalColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This customer map shows Atlas readiness only. It does not invent road-level certainty where verified data is missing.',
            style: ParkPalText.body(color: ParkPalColors.muted, height: 1.45),
          ),
          const SizedBox(height: 22),
          Stack(
            children: [
              Container(
                height: 260,
                decoration: BoxDecoration(
                  color: ParkPalColors.midnight,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: CustomPaint(
                  painter: _AtlasMapPainter(coverage: coverage),
                  child: const SizedBox.expand(),
                ),
              ),
              Positioned(
                right: 18,
                top: 18,
                child: _MapLegend(data: data),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SourceHealthCard extends StatelessWidget {
  const _SourceHealthCard({required this.data});

  final _CustomerAtlasData data;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Source health',
      child: Column(
        children: [
          _HealthRow(
            label: 'Government data',
            value: data.imports.connectedCouncils > 0 ? 'Connected' : 'Ready',
            healthy: data.imports.failedImports == 0,
          ),
          _HealthRow(
            label: 'Atlas Knowledge Graph',
            value: data.summary.totalKnownRoads > 0 ? 'Live' : 'Awaiting data',
            healthy: data.summary.conflicts == 0,
          ),
          _HealthRow(
            label: 'IRIS confidence',
            value: data.summary.pciScore > 0 ? 'Calculated' : 'Pending',
            healthy: data.summary.pciScore >= 50 || data.summary.pciScore == 0,
          ),
          _HealthRow(
            label: 'Import pipeline',
            value: data.imports.failedImports == 0
                ? 'No failures'
                : '${data.imports.failedImports} failed',
            healthy: data.imports.failedImports == 0,
          ),
        ],
      ),
    );
  }
}

class _RoadsNeedingReviewCard extends StatelessWidget {
  const _RoadsNeedingReviewCard({
    required this.roads,
    required this.onReport,
  });

  final List<ParkPalAtlasRoadProfile> roads;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Needs attention',
      actionLabel: 'Report issue',
      onAction: onReport,
      child: roads.isEmpty
          ? const Text(
              'No customer-visible Atlas review items are currently available.',
            )
          : Column(
              children: [
                for (final road in roads) _ReviewRoadRow(road: road),
              ],
            ),
    );
  }
}

class _ReviewRoadRow extends StatelessWidget {
  const _ReviewRoadRow({required this.road});

  final ParkPalAtlasRoadProfile road;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ParkPalColors.lineSoft),
      ),
      child: Row(
        children: [
          Icon(_statusIcon(road.status), color: _statusColor(road.status)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  road.roadName,
                  style: ParkPalText.body(
                    color: ParkPalColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '${road.council} • ${road.status.name.replaceAll('_', ' ')}',
                  style: ParkPalText.body(
                    color: ParkPalColors.muted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${road.coveragePercent.round()}%',
            style: ParkPalText.mono(
              color: ParkPalColors.green700,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  IconData _statusIcon(AtlasRoadStatus status) {
    return switch (status) {
      AtlasRoadStatus.verified => Icons.verified_rounded,
      AtlasRoadStatus.conflict => Icons.warning_rounded,
      AtlasRoadStatus.needs_refresh => Icons.refresh_rounded,
      AtlasRoadStatus.awaiting_verification => Icons.rate_review_rounded,
      AtlasRoadStatus.partially_mapped => Icons.route_rounded,
      AtlasRoadStatus.unmapped => Icons.add_location_alt_rounded,
    };
  }

  Color _statusColor(AtlasRoadStatus status) {
    return switch (status) {
      AtlasRoadStatus.verified => ParkPalColors.safeGreen,
      AtlasRoadStatus.conflict => ParkPalColors.red,
      AtlasRoadStatus.needs_refresh => ParkPalColors.amber,
      AtlasRoadStatus.awaiting_verification => ParkPalColors.irisBlue,
      AtlasRoadStatus.partially_mapped => ParkPalColors.green700,
      AtlasRoadStatus.unmapped => ParkPalColors.mutedTwo,
    };
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.child,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: parkPalGlassDecoration(opacity: 0.92, radius: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: ParkPalText.display(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: ParkPalColors.ink,
                  ),
                ),
              ),
              if (actionLabel != null && onAction != null)
                TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _HealthRow extends StatelessWidget {
  const _HealthRow({
    required this.label,
    required this.value,
    required this.healthy,
  });

  final String label;
  final String value;
  final bool healthy;

  @override
  Widget build(BuildContext context) {
    final color = healthy ? ParkPalColors.safeGreen : ParkPalColors.amber;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: ParkPalText.body(
                color: ParkPalColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(value, style: ParkPalText.body(color: ParkPalColors.muted)),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.card});

  final _Kpi card;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: parkPalGlassDecoration(opacity: 0.92, radius: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(card.icon, color: ParkPalColors.green700),
          Text(
            card.value,
            style: ParkPalText.display(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: ParkPalColors.ink,
            ),
          ),
          Text(
            card.label,
            style: ParkPalText.body(
              color: ParkPalColors.muted,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Text(
        '$label $value',
        style: ParkPalText.mono(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _MapLegend extends StatelessWidget {
  const _MapLegend({required this.data});

  final _CustomerAtlasData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LegendDot('Verified', ParkPalColors.safeGreen),
          _LegendDot('Needs review', ParkPalColors.amber),
          _LegendDot('No data yet', ParkPalColors.mutedTwo),
          if (data.imports.failedImports > 0)
            _LegendDot('Import failure', ParkPalColors.red),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label, style: ParkPalText.body(fontSize: 12)),
        ],
      ),
    );
  }
}

class _AtlasMapPainter extends CustomPainter {
  const _AtlasMapPainter({required this.coverage});

  final double coverage;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = ParkPalColors.irisBlue.withValues(alpha: 0.26);
    final verified = Paint()
      ..style = PaintingStyle.fill
      ..color =
          ParkPalColors.safeGreen.withValues(alpha: 0.35 + coverage * 0.4);
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = Colors.white.withValues(alpha: 0.35);

    final path = Path()
      ..moveTo(size.width * 0.48, size.height * 0.08)
      ..quadraticBezierTo(size.width * 0.58, size.height * 0.18,
          size.width * 0.52, size.height * 0.31)
      ..quadraticBezierTo(size.width * 0.66, size.height * 0.4,
          size.width * 0.55, size.height * 0.54)
      ..quadraticBezierTo(size.width * 0.45, size.height * 0.68,
          size.width * 0.58, size.height * 0.88)
      ..quadraticBezierTo(size.width * 0.42, size.height * 0.82,
          size.width * 0.35, size.height * 0.63)
      ..quadraticBezierTo(size.width * 0.25, size.height * 0.44,
          size.width * 0.36, size.height * 0.26)
      ..quadraticBezierTo(size.width * 0.39, size.height * 0.15,
          size.width * 0.48, size.height * 0.08)
      ..close();

    canvas.drawPath(path, paint);
    canvas.save();
    canvas.clipPath(path);
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        size.height * (1 - coverage),
        size.width,
        size.height * coverage,
      ),
      verified,
    );
    canvas.restore();
    canvas.drawPath(path, outline);
  }

  @override
  bool shouldRepaint(covariant _AtlasMapPainter oldDelegate) {
    return oldDelegate.coverage != coverage;
  }
}

class _Kpi {
  const _Kpi(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;
}

class _CustomerAtlasData {
  const _CustomerAtlasData({
    required this.summary,
    required this.roadsNeedingReview,
    required this.imports,
  });

  final AtlasSummary summary;
  final List<ParkPalAtlasRoadProfile> roadsNeedingReview;
  final AieDashboardSummary imports;

  static const empty = _CustomerAtlasData(
    summary: AtlasSummary(
      totalKnownRoads: 0,
      verifiedRoads: 0,
      unmappedRoads: 0,
      conflicts: 0,
      staleRecords: 0,
      activeMissions: 0,
      coveragePercent: 0,
      pciScore: 0,
    ),
    roadsNeedingReview: [],
    imports: AieDashboardSummary.empty,
  );
}
