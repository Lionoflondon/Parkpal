import 'package:flutter/material.dart';

import '../../app/parkpal_theme.dart';
import 'parking_history_entry.dart';
import 'parking_history_service.dart';

class ParkingHistoryScreen extends StatefulWidget {
  const ParkingHistoryScreen({super.key});

  @override
  State<ParkingHistoryScreen> createState() => _ParkingHistoryScreenState();
}

class _ParkingHistoryScreenState extends State<ParkingHistoryScreen> {
  final _service = ParkingHistoryService();
  late Future<List<ParkingHistoryEntry>> _entries;

  @override
  void initState() {
    super.initState();
    _entries = _service.fetchRecent();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const ColoredBox(color: ParkPalColors.cream),
        ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
          children: [
            Row(
              children: [
                Text(
                  'Evidence Vault',
                  style: ParkPalText.display(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: ParkPalColors.ink,
                  ),
                ),
                const Spacer(),
                IconButton.filledTonal(
                  onPressed: () {
                    setState(() => _entries = _service.fetchRecent());
                  },
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: parkPalGlassDecoration(opacity: 0.92, radius: 30),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: ParkPalColors.midnight,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      color: ParkPalColors.irisCyan,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Saved for dispute support — every search keeps a time-stamped record of what ParkPal found.',
                      style: ParkPalText.body(
                        color: ParkPalColors.muted,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FutureBuilder<List<ParkingHistoryEntry>>(
              future: _entries,
              builder: (context, snapshot) {
                final entries = snapshot.data ?? const <ParkingHistoryEntry>[];
                if (snapshot.connectionState != ConnectionState.done) {
                  return const _VaultLoadingState();
                }
                if (entries.isEmpty) {
                  return const _VaultEmptyState();
                }

                return Column(
                  children: [
                    for (final entry in entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _HistoryCard(entry: entry),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.entry});

  final ParkingHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final statusColor = parkPalStatusColor(entry.resultStatus);
    final summary =
        entry.ruleSummary.isEmpty ? entry.resultStatus : entry.ruleSummary;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: parkPalGlassDecoration(opacity: 0.9, radius: 26),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: statusColor.withValues(alpha: 0.2)),
            ),
            child: Icon(_iconFor(entry.resultStatus), color: statusColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.queryText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ParkPalText.display(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: ParkPalColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(entry.confidence * 100).round()}%',
                      style: ParkPalText.mono(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  summary,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: ParkPalText.body(
                    color: ParkPalColors.muted,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MetaChip(label: entry.resultStatus),
                    _MetaChip(label: entry.riskLevel),
                    _MetaChip(label: _relativeTime(entry.queriedAt)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String status) {
    final color = parkPalStatusColor(status);
    if (color == ParkPalColors.safeGreen) return Icons.check_rounded;
    if (color == ParkPalColors.red) return Icons.close_rounded;
    return Icons.priority_high_rounded;
  }

  String _relativeTime(DateTime? value) {
    if (value == null) return 'Time unknown';
    final difference = DateTime.now().difference(value);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ParkPalColors.cream.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ParkPalColors.lineSoft),
      ),
      child: Text(
        label,
        style: ParkPalText.mono(
          color: ParkPalColors.muted,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _VaultLoadingState extends StatelessWidget {
  const _VaultLoadingState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: parkPalGlassDecoration(opacity: 0.86, radius: 26),
      child: Row(
        children: [
          const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            'Loading your evidence records…',
            style: ParkPalText.body(color: ParkPalColors.muted),
          ),
        ],
      ),
    );
  }
}

class _VaultEmptyState extends StatelessWidget {
  const _VaultEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: parkPalGlassDecoration(opacity: 0.9, radius: 30),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: parkPalIridescentBorderGradient(),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No evidence records yet',
            style: ParkPalText.display(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: ParkPalColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sign in and search a road to start building your time-stamped parking history.',
            textAlign: TextAlign.center,
            style: ParkPalText.body(color: ParkPalColors.muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}
