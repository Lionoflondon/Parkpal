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
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'History',
          style: ParkPalText.display(
            fontSize: 34,
            fontWeight: FontWeight.w700,
            color: ParkPalColors.ink,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: parkPalGlassDecoration(),
          child: Text(
            'Saved for dispute support — every search keeps a time-stamped record of what ParkPal found.',
            style: ParkPalText.body(
              color: ParkPalColors.muted,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 20),
        FutureBuilder<List<ParkingHistoryEntry>>(
          future: _entries,
          builder: (context, snapshot) {
            final entries = snapshot.data ?? const <ParkingHistoryEntry>[];
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (entries.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: parkPalGlassDecoration(),
                child: Text(
                  'Sign in and search a road to start building your history.',
                  style: ParkPalText.body(color: ParkPalColors.muted),
                ),
              );
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
      padding: const EdgeInsets.all(16),
      decoration: parkPalGlassDecoration(opacity: 0.88, radius: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_iconFor(entry.resultStatus), color: statusColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.queryText,
                  style: ParkPalText.display(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: ParkPalColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  summary,
                  style: ParkPalText.body(color: ParkPalColors.muted),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_relativeTime(entry.queriedAt)} • Confidence ${(entry.confidence * 100).round()}%',
                  style: ParkPalText.mono(
                    color: ParkPalColors.mutedTwo,
                    fontSize: 12,
                  ),
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
    if (color == ParkPalColors.safeGreen) return Icons.check_circle;
    if (color == ParkPalColors.red) return Icons.cancel;
    return Icons.help_outline;
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
