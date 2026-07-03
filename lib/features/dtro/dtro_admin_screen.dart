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

  @override
  void initState() {
    super.initState();
    _records = _service.fetchLegalRecords();
  }

  void _refresh() {
    setState(() => _records = _service.fetchLegalRecords());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DtroLegalRecord>>(
      future: _records,
      builder: (context, snapshot) {
        final records = snapshot.data ?? const <DtroLegalRecord>[];
        return ListView(
          children: [
            Row(
              children: [
                Expanded(
                  child:
                      Text('D-TRO Legal Data', style: adminHeading(size: 46)),
                ),
                OutlinedButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_outlined),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Canonical legal-data foundation for Traffic Regulation Orders. D-TRO API credentials are not connected yet.',
              style: adminBody(color: ParkPalAdminColors.muted),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: const [
                _DtroChip('Raw D-TRO JSON preserved'),
                _DtroChip('Official regulationType codes'),
                _DtroChip('IRIS plain-English labels'),
                _DtroChip('Atlas legal layer'),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: adminGlassDecoration(),
              child: records.isEmpty
                  ? const _DtroEmptyState()
                  : Column(
                      children: [
                        for (final record in records)
                          _DtroRecordRow(record: record),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _DtroChip extends StatelessWidget {
  const _DtroChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      backgroundColor: Colors.white.withValues(alpha: 0.08),
    );
  }
}

class _DtroEmptyState extends StatelessWidget {
  const _DtroEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: adminGlassDecoration(),
      child: Column(
        children: [
          const Icon(Icons.policy_outlined,
              color: ParkPalAdminColors.cyan, size: 42),
          const SizedBox(height: 12),
          Text('Waiting for D-TRO API approval.',
              style: adminHeading(size: 28)),
          const SizedBox(height: 8),
          Text(
            'Once credentials are approved, ParkPal will store raw D-TRO JSON and normalized legal records here for Atlas and IRIS review.',
            textAlign: TextAlign.center,
            style: adminBody(color: ParkPalAdminColors.muted),
          ),
        ],
      ),
    );
  }
}

class _DtroRecordRow extends StatelessWidget {
  const _DtroRecordRow({required this.record});

  final DtroLegalRecord record;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ParkPalAdminColors.glassBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.policy_outlined, color: ParkPalAdminColors.cyan),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.irisLabel,
                    style: adminBody(weight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(record.irisExplanation,
                    style:
                        adminBody(color: ParkPalAdminColors.muted, size: 12)),
                const SizedBox(height: 8),
                Text(
                  [
                    record.authority.name,
                    dtroRegulationTypeCode(record.regulationType),
                    'status: ${record.status.name}',
                    'verification: ${record.verificationStatus.name}',
                    if (record.version != null) 'version: ${record.version}',
                    if (record.lastUpdatedAt != null)
                      'updated: ${record.lastUpdatedAt!.toIso8601String()}',
                  ].join(' • '),
                  style: adminBody(color: ParkPalAdminColors.muted, size: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
