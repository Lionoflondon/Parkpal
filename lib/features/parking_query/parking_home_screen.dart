import 'package:flutter/material.dart';

import '../../app/parkpal_theme.dart';
import '../history/parking_history_entry.dart';
import '../history/parking_history_service.dart';
import 'parking_lookup_result.dart';
import 'parking_query_service.dart';

class ParkingHomeScreen extends StatefulWidget {
  const ParkingHomeScreen({this.onOpenScan, super.key});

  final VoidCallback? onOpenScan;

  @override
  State<ParkingHomeScreen> createState() => _ParkingHomeScreenState();
}

class _ParkingHomeScreenState extends State<ParkingHomeScreen> {
  final _controller = TextEditingController();
  final _service = ParkingQueryService();
  final _historyService = ParkingHistoryService();

  ParkingLookupResult? _result;
  Future<List<ParkingHistoryEntry>>? _recentHistory;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _recentHistory = _historyService.fetchRecent(limit: 3);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _service.search(_controller.text);
      if (!mounted) return;
      setState(() {
        _result = result;
        _recentHistory = _historyService.fetchRecent(limit: 3);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'ParkPal could not complete this search. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        const _ParkPalHeader(),
        const SizedBox(height: 34),
        Text(
          'Know before\nyou park.',
          style: ParkPalText.display(
            fontSize: 54,
            fontWeight: FontWeight.w800,
            color: ParkPalColors.ink,
            height: 0.94,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Scan a sign or search a road for ParkPal’s current parking intelligence.',
          style: ParkPalText.body(
            color: ParkPalColors.muted,
            fontSize: 16,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 24),
        _IrisScanCard(onTap: widget.onOpenScan),
        const SizedBox(height: 24),
        Center(
          child: Text(
            'OR SEARCH MANUALLY',
            style: ParkPalText.mono(
              color: ParkPalColors.mutedTwo,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _controller,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(hintText: 'e.g. Kensington Road'),
          onSubmitted: (_) => _search(),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _isLoading ? null : _search,
          child: _isLoading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Can I park here?'),
        ),
        OutlinedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.my_location),
          label: const Text('Use GPS location — coming soon'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: ParkPalColors.red)),
        ],
        if (_result != null) ...[
          const SizedBox(height: 22),
          ParkingResultCard(result: _result!),
        ],
        const SizedBox(height: 26),
        _RecentHistorySection(history: _recentHistory),
        const SizedBox(height: 24),
        Center(
          child: Text(
            '“Always check the sign in front of you.”',
            style: ParkPalText.body(
              color: ParkPalColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class ParkingResultCard extends StatelessWidget {
  const ParkingResultCard({required this.result, super.key});

  final ParkingLookupResult result;

  @override
  Widget build(BuildContext context) {
    final statusLabel = _statusCopy(result.canPark);
    final statusColor = parkPalStatusColor(statusLabel);
    final confidence = (result.confidenceScore * 100).round().clamp(0, 100);

    return Container(
      decoration: parkPalGlassDecoration(opacity: 0.9),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: parkPalStatusBg(statusLabel),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: parkPalStatusLine(statusLabel)),
            ),
            child: Text(
              statusLabel,
              style: ParkPalText.display(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _ResultRow(label: 'Rule summary', value: result.ruleSummary),
          _ResultRow(label: 'Time window', value: result.timeWindow),
          _ResultRow(label: 'Paid/free', value: result.paymentRequiredLabel),
          _ResultRow(label: 'Risk level', value: result.riskLevel),
          _ResultRow(
              label: 'Evidence source', value: result.evidenceSourceLabel),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'IRIS confidence',
                style: ParkPalText.body(
                  color: ParkPalColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '$confidence%',
                style: ParkPalText.mono(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: confidence / 100,
              minHeight: 8,
              color: statusColor,
              backgroundColor: ParkPalColors.lineSoft,
            ),
          ),
        ],
      ),
    );
  }

  String _statusCopy(CanParkStatus status) {
    return switch (status) {
      CanParkStatus.yes => 'Safe to park',
      CanParkStatus.no => 'Do not park',
      CanParkStatus.unknown => 'Check restrictions',
    };
  }
}

class _ParkPalHeader extends StatelessWidget {
  const _ParkPalHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _ParkPalLogoMark(),
        const SizedBox(width: 12),
        Text(
          'ParkPal',
          style: ParkPalText.display(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: ParkPalColors.ink,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: ParkPalColors.mint100,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: ParkPalColors.greenLine),
          ),
          child: Text(
            'Powered by IRIS',
            style: ParkPalText.mono(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: ParkPalColors.green700,
            ),
          ),
        ),
      ],
    );
  }
}

class _ParkPalLogoMark extends StatelessWidget {
  const _ParkPalLogoMark();

  @override
  Widget build(BuildContext context) {
    const assetPath = null;
    if (assetPath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(assetPath, width: 44, height: 44),
      );
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: parkPalIridescentBorderGradient(),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: ParkPalColors.irisBlue.withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Center(
        child: Text(
          'P',
          style: ParkPalText.display(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _IrisScanCard extends StatelessWidget {
  const _IrisScanCard({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          gradient: parkPalIridescentBorderGradient(),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: ParkPalColors.irisBlue.withValues(alpha: 0.16),
              blurRadius: 26,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: ParkPalColors.green900,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: ParkPalColors.glassBorder),
                ),
                child: const Icon(
                  Icons.camera_alt_outlined,
                  color: ParkPalColors.irisCyan,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'POWERED BY IRIS',
                      style: ParkPalText.mono(
                        color: ParkPalColors.irisCyan,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Snap the sign in front of you',
                      style: ParkPalText.display(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'IRIS sign scanning is coming soon. Search manually while scan mode is being built.',
                      style: ParkPalText.body(
                        color: Colors.white.withValues(alpha: 0.72),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentHistorySection extends StatelessWidget {
  const _RecentHistorySection({required this.history});

  final Future<List<ParkingHistoryEntry>>? history;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ParkingHistoryEntry>>(
      future: history,
      builder: (context, snapshot) {
        final entries = snapshot.data ?? const <ParkingHistoryEntry>[];
        if (entries.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent scans',
              style: ParkPalText.display(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: ParkPalColors.ink,
              ),
            ),
            const SizedBox(height: 12),
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RecentHistoryCard(entry: entry),
              ),
          ],
        );
      },
    );
  }
}

class _RecentHistoryCard extends StatelessWidget {
  const _RecentHistoryCard({required this.entry});

  final ParkingHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final summary =
        entry.ruleSummary.isEmpty ? entry.resultStatus : entry.ruleSummary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: parkPalGlassDecoration(opacity: 0.82, radius: 20),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: parkPalStatusColor(entry.resultStatus),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.queryText,
                  style: ParkPalText.body(
                    fontWeight: FontWeight.w800,
                    color: ParkPalColors.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: ParkPalText.body(
                    color: ParkPalColors.muted,
                    fontSize: 13,
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

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: ParkPalText.body(
              fontWeight: FontWeight.w800,
              color: ParkPalColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(value, style: ParkPalText.body(color: ParkPalColors.muted)),
        ],
      ),
    );
  }
}
