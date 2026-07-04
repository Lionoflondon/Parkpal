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
  late Future<Map<String, Object?>> _syncStatus;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _records = _service.fetchLegalRecords();
    _syncStatus = _fetchSyncStatus();
  }

  void _refresh() {
    setState(() {
      _records = _service.fetchLegalRecords();
      _syncStatus = _fetchSyncStatus();
    });
  }

  Future<Map<String, Object?>> _fetchSyncStatus() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('parkpal_dtro_sync_status')
          .doc('live')
          .get();
      return dtroWebSafeMap(snapshot.data() ?? const {});
    } catch (_) {
      return const {};
    }
  }

  Future<void> _syncLiveDtro() async {
    setState(() => _syncing = true);
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'europe-west2')
          .httpsCallable('syncParkPalDtroLegalData');
      final result = await callable.call<Map<Object?, Object?>>({});
      final data = dtroWebSafeMap(result.data);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('D-TRO sync ${data['status']}.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('D-TRO sync failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _syncing = false;
          _records = _service.fetchLegalRecords();
          _syncStatus = _fetchSyncStatus();
        });
      }
    }
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
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: _syncing ? null : _syncLiveDtro,
                  icon: _syncing
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync_rounded),
                  label: Text(_syncing ? 'Syncing…' : 'Sync D-TRO'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Canonical legal-data foundation for Traffic Regulation Orders. D-TRO API credentials are not connected yet.',
              style: adminBody(color: ParkPalAdminColors.muted),
            ),
            const SizedBox(height: 18),
            FutureBuilder<Map<String, Object?>>(
              future: _syncStatus,
              builder: (context, snapshot) {
                return _DtroSyncStatusCard(status: snapshot.data ?? const {});
              },
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

class _DtroSyncStatusCard extends StatelessWidget {
  const _DtroSyncStatusCard({required this.status});

  final Map<String, Object?> status;

  @override
  Widget build(BuildContext context) {
    final failures = (status['failures'] as List?)
            ?.map((value) => value.toString())
            .where((value) => value.isNotEmpty)
            .toList(growable: false) ??
        const <String>[];
    final apiConnected = status['apiConnected'] == true;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: adminGlassDecoration(),
      child: Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [
          _DtroStatusMetric(
            label: 'API connected',
            value: apiConnected ? 'Yes' : 'No',
            accent: apiConnected
                ? ParkPalAdminColors.emerald
                : ParkPalAdminColors.red,
          ),
          _DtroStatusMetric(
            label: 'Last sync',
            value: _shortStatus(status['lastSyncTime']),
          ),
          _DtroStatusMetric(
            label: 'Records fetched',
            value: '${status['recordsFetched'] ?? 0}',
          ),
          _DtroStatusMetric(
            label: 'Records imported',
            value: '${status['recordsImported'] ?? 0}',
          ),
          _DtroStatusMetric(
            label: 'Failures',
            value: failures.isEmpty ? '0' : '${failures.length}',
            accent: failures.isEmpty
                ? ParkPalAdminColors.cyan
                : ParkPalAdminColors.red,
          ),
          if (failures.isNotEmpty)
            SizedBox(
              width: 520,
              child: Text(
                failures.join(' • '),
                style: adminBody(color: ParkPalAdminColors.red, size: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _DtroStatusMetric extends StatelessWidget {
  const _DtroStatusMetric({
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
      width: 190,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: adminBody(color: ParkPalAdminColors.muted, size: 12)),
          const SizedBox(height: 6),
          Text(value, style: adminHeading(size: 24).copyWith(color: accent)),
        ],
      ),
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
            'Configure DTRO_API_BASE_URL and DTRO_API_KEY in ParkPal Functions to enable live sync. Manual/import-ready records remain supported as fallback.',
            textAlign: TextAlign.center,
            style: adminBody(color: ParkPalAdminColors.muted),
          ),
        ],
      ),
    );
  }
}

String _shortStatus(Object? value) {
  if (value == null) return 'Never';
  final text = value.toString();
  return text.length > 32 ? '${text.substring(0, 32)}…' : text;
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
