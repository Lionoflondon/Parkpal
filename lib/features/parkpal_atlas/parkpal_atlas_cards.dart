import 'package:flutter/material.dart';

import '../../app/parkpal_theme.dart';
import 'parkpal_atlas_models.dart';

class AtlasSummaryCard extends StatelessWidget {
  const AtlasSummaryCard({
    required this.title,
    required this.summary,
    super.key,
  });

  final String title;
  final AtlasSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: parkPalGlassDecoration(opacity: 0.88),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: ParkPalText.display(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: ParkPalColors.ink,
            ),
          ),
          const SizedBox(height: 14),
          _MetricRow(
              label: 'Coverage', value: '${summary.coveragePercent.round()}%'),
          _MetricRow(
              label: 'PCI score', value: summary.pciScore.round().toString()),
          _MetricRow(
              label: 'Verified roads', value: '${summary.verifiedRoads}'),
          _MetricRow(
              label: 'Unmapped roads', value: '${summary.unmappedRoads}'),
          _MetricRow(label: 'Conflicts', value: '${summary.conflicts}'),
          _MetricRow(label: 'Stale records', value: '${summary.staleRecords}'),
          _MetricRow(
            label: 'Active Pioneer Missions',
            value: '${summary.activeMissions}',
          ),
          _MetricRow(label: 'Last sync', value: _dateLabel(summary.lastSyncAt)),
          _MetricRow(
              label: 'Last IRIS review',
              value: _dateLabel(summary.lastReviewAt)),
        ],
      ),
    );
  }
}

class AtlasRoadProfileCard extends StatelessWidget {
  const AtlasRoadProfileCard({required this.profile, super.key});

  final ParkPalAtlasRoadProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: parkPalGlassDecoration(opacity: 0.9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            profile.roadName,
            style: ParkPalText.display(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: ParkPalColors.ink,
            ),
          ),
          Text(
            '${profile.borough} • ${profile.council}',
            style: ParkPalText.body(color: ParkPalColors.muted),
          ),
          const SizedBox(height: 12),
          _MetricRow(label: 'Status', value: profile.status.name),
          _MetricRow(
              label: 'Coverage', value: '${profile.coveragePercent.round()}%'),
          _MetricRow(
              label: 'PCI score', value: profile.pciScore.round().toString()),
          _MetricRow(
              label: 'Verified signs', value: '${profile.verifiedSigns}'),
          _MetricRow(
              label: 'Council records', value: '${profile.councilRecords}'),
          _MetricRow(label: 'Conflicts', value: '${profile.conflicts}'),
          _MetricRow(label: 'Stale records', value: '${profile.staleRecords}'),
          _MetricRow(
            label: 'Active missions',
            value: '${profile.activeMissions}',
          ),
        ],
      ),
    );
  }
}

class InspectorFindingCard extends StatelessWidget {
  const InspectorFindingCard({required this.finding, super.key});

  final IrisInspectorFinding finding;

  @override
  Widget build(BuildContext context) {
    final color = switch (finding.priority) {
      IrisInspectorPriority.critical => ParkPalColors.red,
      IrisInspectorPriority.high => ParkPalColors.amber,
      IrisInspectorPriority.medium => ParkPalColors.irisBlue,
      IrisInspectorPriority.low => ParkPalColors.safeGreen,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: parkPalGlassDecoration(opacity: 0.9, radius: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.radar, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  finding.title,
                  style: ParkPalText.body(
                    color: ParkPalColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  finding.notes,
                  style: ParkPalText.body(color: ParkPalColors.muted),
                ),
                const SizedBox(height: 8),
                Text(
                  '${finding.state.name} • ${finding.priority.name} • ${finding.recommendedMissionType}',
                  style: ParkPalText.mono(
                    color: ParkPalColors.mutedTwo,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
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

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: ParkPalText.body(color: ParkPalColors.muted)),
          ),
          Text(
            value,
            style: ParkPalText.mono(
              color: ParkPalColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

String _dateLabel(DateTime? value) {
  if (value == null) return 'Not yet';
  return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
