import 'package:cloud_firestore/cloud_firestore.dart';

class ParkingHistoryEntry {
  const ParkingHistoryEntry({
    required this.id,
    required this.queryText,
    required this.resultStatus,
    required this.riskLevel,
    required this.ruleSummary,
    required this.confidence,
    required this.sourceUsed,
    required this.queriedAt,
  });

  factory ParkingHistoryEntry.fromMap(String id, Map<String, dynamic> data) {
    final timestamp = data['queriedAt'];
    return ParkingHistoryEntry(
      id: id,
      queryText: data['queryText'] as String? ?? 'Unknown location',
      resultStatus: data['resultStatus'] as String? ?? 'Unknown',
      riskLevel: data['riskLevel'] as String? ?? 'Unknown',
      ruleSummary: data['ruleSummary'] as String? ?? '',
      confidence: (data['confidence'] as num?)?.toDouble() ?? 0,
      sourceUsed: data['sourceUsed'] as String? ?? 'none',
      queriedAt: timestamp is Timestamp ? timestamp.toDate() : null,
    );
  }

  final String id;
  final String queryText;
  final String resultStatus;
  final String riskLevel;
  final String ruleSummary;
  final double confidence;
  final String sourceUsed;
  final DateTime? queriedAt;
}
