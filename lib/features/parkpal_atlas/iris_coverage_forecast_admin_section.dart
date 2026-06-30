import 'package:flutter/material.dart';

import '../../admin/parkpal_admin_theme.dart';
import 'iris_coverage_forecast_models.dart';
import 'iris_coverage_forecast_service.dart';

class IrisCoverageForecastAdminSection extends StatefulWidget {
  const IrisCoverageForecastAdminSection({super.key});

  @override
  State<IrisCoverageForecastAdminSection> createState() =>
      _IrisCoverageForecastAdminSectionState();
}

class _IrisCoverageForecastAdminSectionState
    extends State<IrisCoverageForecastAdminSection> {
  final _service = IrisCoverageForecastService();
  late Future<IrisCoverageForecast> _forecast;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _forecast = _service.fetchForecastDashboard();
  }

  Future<void> _generateMissions() async {
    setState(() => _generating = true);
    final missions = await _service.generatePioneerMissions();
    if (!mounted) return;
    setState(() {
      _generating = false;
      _forecast = _service.fetchForecastDashboard();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('IRIS recommended ${missions.length} Pioneer mission(s).'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<IrisCoverageForecast>(
      future: _forecast,
      builder: (context, snapshot) {
        final forecast = snapshot.data ?? IrisCoverageForecast.empty;
        return ListView(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('IRIS Coverage Forecast',
                          style: adminHeading(size: 46)),
                      const SizedBox(height: 8),
                      Text(
                        'IRIS predicts where verification work should happen next before missing data reaches drivers.',
                        style: adminBody(color: ParkPalAdminColors.muted),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: _generating ? null : _generateMissions,
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: Text(_generating
                      ? 'Generating…'
                      : 'Generate Pioneer Missions'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _ForecastMetric(
                  label: 'Current PCI',
                  value: '${forecast.currentPci.round()}%',
                ),
                _ForecastMetric(
                  label: 'Expected PCI after active missions',
                  value: '${forecast.expectedPciAfterActiveMissions.round()}%',
                ),
                _ForecastMetric(
                  label: 'Upcoming council imports',
                  value: '${forecast.upcomingCouncilImports}',
                ),
                _ForecastMetric(
                  label: 'Estimated completion',
                  value: _dateLabel(forecast.nationalEstimatedCompletion),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _InsightPanel(
              title: 'IRIS Intelligence',
              lines: [
                forecast.coverageTrend,
                forecast.verificationTrend,
                forecast.conflictTrend,
                ...forecast.recommendations,
              ],
            ),
            const SizedBox(height: 24),
            _BoroughLeaderboard(boroughs: forecast.boroughs),
            const SizedBox(height: 24),
            _RoadPriorityList(roads: forecast.priorityRoads),
          ],
        );
      },
    );
  }
}

class _ForecastMetric extends StatelessWidget {
  const _ForecastMetric({required this.label, required this.value});

  final String label;
  final String value;

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
              style: adminHeading(size: 34)
                  .copyWith(color: ParkPalAdminColors.cyan),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightPanel extends StatelessWidget {
  const _InsightPanel({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: adminGlassDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: adminHeading(size: 28)),
          const SizedBox(height: 12),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.bolt_outlined,
                      color: ParkPalAdminColors.cyan, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      line,
                      style: adminBody(color: ParkPalAdminColors.muted),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BoroughLeaderboard extends StatelessWidget {
  const _BoroughLeaderboard({required this.boroughs});

  final List<BoroughCoverageScore> boroughs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: adminGlassDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Borough Coverage Leaderboard', style: adminHeading(size: 28)),
          const SizedBox(height: 8),
          Text(
            'Borough Coverage = mapped roads / total known roads. A borough cannot reach 100% while roads remain unmapped, stale, conflicted or unverified.',
            style: adminBody(color: ParkPalAdminColors.muted),
          ),
          const SizedBox(height: 16),
          if (boroughs.isEmpty)
            Text('No borough coverage data yet.',
                style: adminBody(color: ParkPalAdminColors.muted))
          else
            for (final borough in boroughs.take(12))
              _BoroughRow(borough: borough),
        ],
      ),
    );
  }
}

class _BoroughRow extends StatelessWidget {
  const _BoroughRow({required this.borough});

  final BoroughCoverageScore borough;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  borough.borough,
                  style: adminBody(weight: FontWeight.w800),
                ),
              ),
              Text(
                'Borough Coverage: ${borough.coveragePercent.round()}%',
                style: adminBody(color: ParkPalAdminColors.cyan),
              ),
            ],
          ),
          const SizedBox(height: 5),
          LinearProgressIndicator(
            value: borough.coveragePercent / 100,
            minHeight: 7,
            backgroundColor: Colors.white.withValues(alpha: 0.10),
            color: ParkPalAdminColors.cyan,
          ),
          const SizedBox(height: 5),
          Text(
            'Roads mapped: ${borough.mappedRoads} / ${borough.totalKnownRoads} • ${borough.statusLabel} • Conflicts: ${borough.conflictRoads} • Unmapped: ${borough.unmappedRoads}',
            style: adminBody(color: ParkPalAdminColors.muted, size: 12),
          ),
        ],
      ),
    );
  }
}

class _RoadPriorityList extends StatelessWidget {
  const _RoadPriorityList({required this.roads});

  final List<IrisRoadPriority> roads;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: adminGlassDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Roads IRIS wants mapped next', style: adminHeading(size: 28)),
          const SizedBox(height: 12),
          if (roads.isEmpty)
            Text('No road priority forecast yet.',
                style: adminBody(color: ParkPalAdminColors.muted))
          else
            for (final road in roads.take(12))
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            road.roadName,
                            style: adminBody(weight: FontWeight.w800),
                          ),
                        ),
                        Text(road.stars,
                            style: adminBody(color: ParkPalAdminColors.amber)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${road.recommendedMission} • Score ${road.priorityScore.round()} • ${road.reasons.join(', ')}',
                      style:
                          adminBody(color: ParkPalAdminColors.muted, size: 12),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

String _dateLabel(DateTime? value) {
  if (value == null) return 'Unknown';
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}
