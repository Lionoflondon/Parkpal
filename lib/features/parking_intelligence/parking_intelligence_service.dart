import 'package:cloud_firestore/cloud_firestore.dart';

import '../../data/firestore_collections.dart';
import '../parking_query/parking_lookup_result.dart';
import 'parking_intelligence_models.dart';

class ParkingIntelligenceService {
  ParkingIntelligenceService({
    required FirebaseFirestore firestore,
    ParkingIRIS iris = const ParkingIRIS(),
  })  : _firestore = firestore,
        _iris = iris;

  final FirebaseFirestore _firestore;
  final ParkingIRIS _iris;

  Future<ParkingLookupResult> evaluate(
      ParkingIntelligenceContext context) async {
    final query = context.queryText.trim();
    if (query.isEmpty) return ParkingLookupResult.unknown();

    final evidence = <ParkingEvidence>[
      ...await _signEvidence(query),
      ...await _roadEvidence(query),
      ...await _zoneEvidence(query),
      ...await _councilEvidence(query),
      ...await _reportEvidence(query),
    ];

    if (evidence.isEmpty) {
      return ParkingLookupResult.unknown().copyWith(
        evidenceReason:
            'Unknown. ParkPal has no verified information for this road.',
      );
    }

    final selected = _selectEvidence(evidence);
    final confidence = _iris.calculateConfidence([selected]);
    final canPark = _canPark(selected);
    final timeWindow = selected.data['activeHours'] as String? ?? 'Unknown';
    final explanation = _explain(
      selected: selected,
      canPark: canPark,
      confidence: confidence,
      now: context.now,
      timeWindow: timeWindow,
    );

    return ParkingLookupResult(
      canPark: canPark,
      ruleSummary: explanation,
      timeWindow: timeWindow,
      paymentRequired: _paymentFromEvidence(selected),
      riskLevel: _riskFromEvidence(selected, canPark),
      confidenceScore: confidence.score,
      evidenceSource: selected.source,
      evidenceReason: confidence.reason,
    );
  }

  Future<List<ParkingEvidence>> _signEvidence(String query) async {
    final snapshot = await _safeQuery(() => _firestore
        .collection(ParkPalCollections.signs)
        .where('streetName', isEqualTo: query)
        .limit(10)
        .get());
    if (snapshot == null) return const [];

    return snapshot.docs.map((doc) {
      final data = doc.data();
      final verified = data['verificationStatus'] == 'verified';
      final imported = data['source'] == 'imported_dataset' ||
          data['source'] == 'council_data';
      return ParkingEvidence(
        source: imported
            ? ParkingEvidenceSource.councilData
            : verified
                ? ParkingEvidenceSource.verifiedSign
                : ParkingEvidenceSource.userReport,
        data: data,
        summary: data['restrictionSummary'] as String? ??
            data['interpretedText'] as String? ??
            data['rawText'] as String? ??
            'Parking sign evidence found.',
        verified: verified || data['confidenceState'] == 'verified_plus',
      );
    }).toList(growable: false);
  }

  Future<List<ParkingEvidence>> _roadEvidence(String query) async {
    final normalized = _normalize(query);
    final snapshot = await _safeQuery(() => _firestore
        .collection(ParkPalCollections.roads)
        .where('normalizedStreetName', isEqualTo: normalized)
        .limit(3)
        .get());
    if (snapshot == null) return const [];
    return snapshot.docs
        .map((doc) => ParkingEvidence(
              source: ParkingEvidenceSource.seedData,
              data: doc.data(),
              summary: doc.data()['defaultSummary'] as String? ??
                  'Road-level parking intelligence found.',
              seed: true,
              verified: doc.data()['confidenceScore'] == 1,
            ))
        .toList(growable: false);
  }

  Future<List<ParkingEvidence>> _zoneEvidence(String query) async {
    final snapshot = await _safeQuery(() => _firestore
        .collection(ParkPalCollections.zones)
        .where('zoneName', isEqualTo: query)
        .limit(3)
        .get());
    if (snapshot == null) return const [];
    return snapshot.docs
        .map((doc) => ParkingEvidence(
              source: ParkingEvidenceSource.councilData,
              data: doc.data(),
              summary: doc.data()['rulesSummary'] as String? ??
                  'Zone parking intelligence found.',
              verified: doc.data()['source'] == 'council_data',
            ))
        .toList(growable: false);
  }

  Future<List<ParkingEvidence>> _councilEvidence(String query) async {
    final snapshot = await _safeQuery(() => _firestore
        .collection(ParkPalCollections.councils)
        .where('councilName', isEqualTo: query)
        .limit(1)
        .get());
    if (snapshot == null) return const [];
    return snapshot.docs
        .map((doc) => ParkingEvidence(
              source: ParkingEvidenceSource.councilData,
              data: doc.data(),
              summary: 'Council metadata found. Road-level rules still needed.',
              verified: true,
            ))
        .toList(growable: false);
  }

  Future<List<ParkingEvidence>> _reportEvidence(String query) async {
    final snapshot = await _safeQuery(() => _firestore
        .collection(ParkPalCollections.reports)
        .where('streetName', isEqualTo: query)
        .where('status', isEqualTo: 'resolved')
        .limit(5)
        .get());
    if (snapshot == null) return const [];
    if (snapshot.docs.isEmpty) return const [];
    final data = snapshot.docs.first.data();
    return [
      ParkingEvidence(
        source: ParkingEvidenceSource.userReport,
        data: data,
        summary:
            data['description'] as String? ?? 'Verified user report found.',
        verified: true,
        reportCount: snapshot.docs.length,
      ),
    ];
  }

  ParkingEvidence _selectEvidence(List<ParkingEvidence> evidence) {
    final ranked = [...evidence]..sort((a, b) {
        final aScore = _iris.calculateConfidence([a]).score;
        final bScore = _iris.calculateConfidence([b]).score;
        return bScore.compareTo(aScore);
      });
    return ranked.first;
  }

  CanParkStatus _canPark(ParkingEvidence evidence) {
    final parkingAllowed = evidence.data['parkingAllowed'];
    if (parkingAllowed == true) return CanParkStatus.yes;
    if (parkingAllowed == false) return CanParkStatus.no;
    final zoneType = evidence.data['zoneType'];
    if (zoneType == 'red_route' || zoneType == 'school_street') {
      return CanParkStatus.no;
    }
    return CanParkStatus.unknown;
  }

  PaymentRequiredStatus _paymentFromEvidence(ParkingEvidence evidence) {
    if (evidence.data['permitRequired'] == true) {
      return PaymentRequiredStatus.yes;
    }
    if (evidence.data['permitRequired'] == false) {
      return PaymentRequiredStatus.unknown;
    }
    return PaymentRequiredStatus.unknown;
  }

  String _riskFromEvidence(ParkingEvidence evidence, CanParkStatus canPark) {
    if (canPark == CanParkStatus.no ||
        evidence.data['redRoute'] == true ||
        evidence.data['busLane'] == true ||
        evidence.data['schoolStreet'] == true) {
      return 'High';
    }
    if (canPark == CanParkStatus.yes) return 'Low';
    return 'Unknown';
  }

  String _explain({
    required ParkingEvidence selected,
    required CanParkStatus canPark,
    required ParkingConfidence confidence,
    required DateTime now,
    required String timeWindow,
  }) {
    final day = _dayLabel(now.weekday);
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final activeDays = (selected.data['activeDays'] as List?)
            ?.map((value) => value.toString())
            .join(', ') ??
        'unknown days';
    final summary = selected.summary;
    final status = switch (canPark) {
      CanParkStatus.yes => 'Parking is permitted by the selected evidence.',
      CanParkStatus.no => 'Parking is not permitted by the selected evidence.',
      CanParkStatus.unknown =>
        'ParkPal cannot make a yes/no parking claim from this evidence.',
    };

    return '$summary\nRestriction window: $timeWindow on $activeDays.\nCurrent time is $time on $day.\n$status';
  }

  String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _dayLabel(int weekday) {
    return switch (weekday) {
      DateTime.monday => 'Monday',
      DateTime.tuesday => 'Tuesday',
      DateTime.wednesday => 'Wednesday',
      DateTime.thursday => 'Thursday',
      DateTime.friday => 'Friday',
      DateTime.saturday => 'Saturday',
      DateTime.sunday => 'Sunday',
      _ => 'Unknown day',
    };
  }

  Future<QuerySnapshot<Map<String, dynamic>>?> _safeQuery(
    Future<QuerySnapshot<Map<String, dynamic>>> Function() query,
  ) async {
    try {
      return await query();
    } catch (_) {
      return null;
    }
  }
}
