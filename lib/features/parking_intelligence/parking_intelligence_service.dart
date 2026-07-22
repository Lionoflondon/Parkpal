import 'package:cloud_firestore/cloud_firestore.dart';

import '../../data/firestore_collections.dart';
import '../atlas_intelligence/aie_models.dart';
import '../parking_query/parking_lookup_result.dart';
import 'iris_parking_assistant.dart';
import 'parking_intelligence_models.dart';

class ParkingIntelligenceService implements ParkingIntelligenceEvaluator {
  ParkingIntelligenceService({
    required FirebaseFirestore firestore,
    ParkingIRIS iris = const ParkingIRIS(),
  })  : _firestore = firestore,
        _iris = iris;

  final FirebaseFirestore _firestore;
  final ParkingIRIS _iris;

  @override
  Future<ParkingLookupResult> evaluate(
      ParkingIntelligenceContext context) async {
    final query = context.queryText.trim();
    if (query.isEmpty) return ParkingLookupResult.unknown();

    final evidence = <ParkingEvidence>[
      ...await _canonicalAtlasEvidence(query),
      ...await _signEvidence(query),
      ...await _roadEvidence(query),
      ...await _zoneEvidence(query),
      ...await _councilEvidence(query),
      ...await _atlasIntelligenceEvidence(query),
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

  Future<List<ParkingEvidence>> _canonicalAtlasEvidence(String query) async {
    final normalized = _normalize(query);
    var snapshot = await _safeQuery(() => _firestore
        .collection(AieCollections.canonicalIntelligence)
        .where('normalizedRoadName', isEqualTo: normalized)
        .limit(10)
        .get());
    snapshot ??= await _safeQuery(() => _firestore
        .collection(AieCollections.canonicalIntelligence)
        .where('roadName', isEqualTo: query)
        .limit(10)
        .get());
    if (snapshot == null) return const [];

    return snapshot.docs.map((doc) {
      final data = doc.data();
      final safety = data['customerSafetyState'] as String?;
      final verification = data['verificationState'] as String?;
      final warnings = (data['warnings'] as List?)
              ?.map((value) => value.toString())
              .toList(growable: false) ??
          const <String>[];
      final stale = safety == AtlasCustomerSafetyState.stale.name ||
          _isStale(_date(data['lastImportedAt']) ?? _date(data['updatedAt']));
      final conflict = safety == AtlasCustomerSafetyState.conflicting.name ||
          verification == AtlasVerificationState.conflict.name ||
          ((data['conflictIds'] as List?)?.isNotEmpty ?? false);
      final sourceUnavailable =
          safety == AtlasCustomerSafetyState.sourceUnavailable.name;
      return ParkingEvidence(
        source: ParkingEvidenceSource.adminVerifiedRule,
        data: {
          ...data,
          'source': 'atlas_canonical_intelligence',
          'sourceHealth': sourceUnavailable
              ? 'offline'
              : conflict
                  ? 'warning'
                  : stale
                      ? 'stale'
                      : 'healthy',
          'warnings': warnings,
        },
        summary: _canonicalSummary(data, safety, warnings),
        verified: verification == AtlasVerificationState.official.name ||
            verification == AtlasVerificationState.verifiedPlus.name ||
            safety == AtlasCustomerSafetyState.confirmed.name,
        sourceConfidence:
            ((data['confidence'] as num?)?.toDouble() ?? 0).clamp(0, 1),
        lastUpdatedAt: _date(data['lastVerifiedAt']) ??
            _date(data['lastImportedAt']) ??
            _date(data['updatedAt']),
        conflict: conflict,
        geometryValid: _validLatLng(data['latitude'], data['longitude']) ||
            ((data['geometry'] as Map?)?.isNotEmpty ?? false),
        sourceHealth: sourceUnavailable
            ? 'offline'
            : conflict
                ? 'warning'
                : stale
                    ? 'stale'
                    : 'healthy',
      );
    }).toList(growable: false);
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
        sourceConfidence: (data['confidenceScore'] as num?)?.toDouble(),
        lastUpdatedAt: _date(data['updatedAt']) ??
            _date(data['verifiedAt']) ??
            _date(data['capturedAt']),
        conflict: data['confidenceState'] == 'conflict' ||
            data['verificationStatus'] == 'disputed',
        geometryValid: _validLatLng(data['latitude'], data['longitude']) ||
            data['geoPoint'] != null,
        sourceHealth: _sourceHealth(data),
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
              sourceConfidence:
                  (doc.data()['confidenceScore'] as num?)?.toDouble(),
              lastUpdatedAt: _date(doc.data()['updatedAt']) ??
                  _date(doc.data()['lastVerifiedAt']),
              conflict: doc.data()['confidenceState'] == 'conflict',
              geometryValid: doc.data()['geoBounds'] != null ||
                  doc.data()['centrePoint'] != null,
              sourceHealth: _sourceHealth(doc.data()),
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
              sourceConfidence:
                  (doc.data()['confidenceScore'] as num?)?.toDouble(),
              lastUpdatedAt: _date(doc.data()['updatedAt']),
              conflict: doc.data()['confidenceState'] == 'conflict',
              geometryValid: doc.data()['geoPolygon'] != null,
              sourceHealth: _sourceHealth(doc.data()),
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
              sourceConfidence:
                  (doc.data()['confidenceScore'] as num?)?.toDouble(),
              lastUpdatedAt: _date(doc.data()['lastImportedAt']) ??
                  _date(doc.data()['updatedAt']),
              sourceHealth: _sourceHealth(doc.data()),
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
        lastUpdatedAt: _date(data['updatedAt']) ?? _date(data['createdAt']),
        geometryValid: data['geoPoint'] != null,
        sourceHealth: _sourceHealth(data),
      ),
    ];
  }

  Future<List<ParkingEvidence>> _atlasIntelligenceEvidence(String query) async {
    final snapshot = await _safeQuery(() => _firestore
        .collection(AieCollections.atlasRoads)
        .where('roadName', isEqualTo: query)
        .limit(3)
        .get());
    if (snapshot == null) return const [];

    return snapshot.docs.map((doc) {
      final data = doc.data();
      final rules = (data['currentParkingRules'] as List?)
              ?.whereType<Map>()
              .map((value) => value.cast<String, Object?>())
              .toList(growable: false) ??
          const <Map<String, Object?>>[];
      final firstRule = rules.isEmpty ? const <String, Object?>{} : rules.first;
      return ParkingEvidence(
        source: ParkingEvidenceSource.councilData,
        data: {
          ...firstRule,
          'parkingAllowed': firstRule['parkingAllowed'],
          'permitRequired': firstRule['permitRequired'],
          'activeHours': firstRule['activeHours'],
          'activeDays': firstRule['activeDays'],
          'redRoute': firstRule['redRoute'],
          'busLane': firstRule['busLane'],
          'schoolStreet': firstRule['schoolStreet'],
          'confidencePercent': data['confidencePercent'],
          'source': 'atlas_intelligence_engine',
          'lastImported': data['lastImported'],
          'activeConflicts': data['activeConflicts'],
          'roadHealth': data['roadHealth'],
        },
        summary: firstRule['restrictionType'] as String? ??
            'Official Atlas Intelligence rule found.',
        verified: data['confidence'] == AieConfidence.official.name ||
            data['confidence'] == AieConfidence.verifiedPlus.name,
        sourceConfidence:
            ((data['confidencePercent'] as num?)?.toDouble() ?? 0) / 100,
        lastUpdatedAt: _date(data['lastImported']) ?? _date(data['updatedAt']),
        conflict: data['confidence'] == AieConfidence.conflict.name ||
            ((data['activeConflicts'] as List?)?.isNotEmpty ?? false),
        geometryValid:
            _validLatLng(firstRule['latitude'], firstRule['longitude']) ||
                data['geometry'] != null,
        sourceHealth: _sourceHealth(data),
      );
    }).toList(growable: false);
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
    final price = evidence.data['price'];
    if (price is num && price > 0) return PaymentRequiredStatus.yes;
    if (evidence.data['chargingPeriod'] != null) {
      return PaymentRequiredStatus.yes;
    }
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
    if (evidence.conflict || evidence.sourceHealth == 'stale') return 'Medium';
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
    final warnings = (selected.data['warnings'] as List?)
            ?.map((value) => value.toString())
            .where((value) => value.trim().isNotEmpty)
            .toList(growable: false) ??
        const <String>[];
    final freshness = selected.lastUpdatedAt == null
        ? 'Freshness unknown.'
        : 'Last updated ${selected.lastUpdatedAt!.toUtc().toIso8601String().split('T').first}.';
    final status = switch (canPark) {
      CanParkStatus.yes => 'Parking is permitted by the selected evidence.',
      CanParkStatus.no => 'Parking is not permitted by the selected evidence.',
      CanParkStatus.unknown =>
        'ParkPal cannot make a yes/no parking claim from this evidence.',
    };

    return [
      summary,
      'Restriction window: $timeWindow on $activeDays.',
      'Current time is $time on $day.',
      freshness,
      status,
      if (warnings.isNotEmpty) 'Warnings: ${warnings.join(' ')}',
    ].join('\n');
  }

  String _canonicalSummary(
    Map<String, Object?> data,
    String? safety,
    List<String> warnings,
  ) {
    final type = data['restrictionType'] as String? ?? 'Parking restriction';
    final hours = data['activeHours'] as String? ?? 'Unknown hours';
    final maxStay = data['maxStayMinutes'];
    final permit = data['permitRequired'] == true
        ? ' Permit or vehicle eligibility may be required.'
        : '';
    final charge = data['price'] is num
        ? ' Charging information is available for this restriction.'
        : data['chargingPeriod'] != null
            ? ' Charging period: ${data['chargingPeriod']}.'
            : '';
    final prefix = switch (safety) {
      'confirmed' => 'Confirmed Atlas intelligence.',
      'likely' => 'Likely Atlas intelligence.',
      'conflicting' => 'Conflicting Atlas intelligence.',
      'stale' => 'Stale Atlas intelligence.',
      'incompleteCoverage' => 'Limited Atlas information.',
      'sourceUnavailable' => 'Atlas source unavailable.',
      _ => 'Atlas intelligence.',
    };
    return [
      '$prefix $type applies during $hours.$permit$charge',
      if (maxStay is num) 'Maximum stay: ${maxStay.toInt()} minutes.',
      if (data['noReturnMinutes'] is num)
        'No return: ${(data['noReturnMinutes'] as num).toInt()} minutes.',
      if (data['suspensionActive'] == true)
        'Temporary suspension is active; do not rely on normal parking rules.',
      if (warnings.isNotEmpty) warnings.join(' '),
    ].join(' ');
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

  DateTime? _date(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  bool _validLatLng(Object? latitude, Object? longitude) {
    final lat = (latitude as num?)?.toDouble();
    final lng = (longitude as num?)?.toDouble();
    if (lat == null || lng == null) return false;
    if (lat == 0 && lng == 0) return false;
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  String _sourceHealth(Map<String, Object?> data) {
    final explicit = data['sourceHealth'] ?? data['operationalHealth'];
    if (explicit is String && explicit.isNotEmpty) return explicit;
    if (data['importStatus'] == 'failed') return 'offline';
    if (data['confidenceState'] == 'conflict' ||
        data['confidence'] == AieConfidence.conflict.name) {
      return 'warning';
    }
    return 'healthy';
  }

  bool _isStale(DateTime? value) {
    if (value == null) return false;
    return DateTime.now().difference(value).inDays > 180;
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
