import '../parking_query/parking_lookup_result.dart';

class ParkingIntelligenceContext {
  ParkingIntelligenceContext({
    required this.queryText,
    DateTime? now,
  }) : now = now ?? DateTime.now();

  final String queryText;
  final DateTime now;
}

class ParkingEvidence {
  const ParkingEvidence({
    required this.source,
    required this.data,
    required this.summary,
    this.verified = false,
    this.seed = false,
    this.reportCount = 0,
  });

  final ParkingEvidenceSource source;
  final Map<String, Object?> data;
  final String summary;
  final bool verified;
  final bool seed;
  final int reportCount;
}

class ParkingConfidence {
  const ParkingConfidence({
    required this.score,
    required this.reason,
  });

  final double score;
  final String reason;
}

abstract interface class CurrentLocationProvider {
  Future<Object?> currentLocation();
}

abstract interface class RoadMatcher {
  Future<String?> matchRoad(Object location);
}

abstract interface class NearestRestrictionLookup {
  Future<ParkingEvidence?> nearestRestriction(Object location);
}

class DisabledCurrentLocationProvider implements CurrentLocationProvider {
  const DisabledCurrentLocationProvider();

  @override
  Future<Object?> currentLocation() async => null;
}

class ParkingSignRecognitionService {
  const ParkingSignRecognitionService();

  Future<void> recogniseSignPlaceholder() async {
    // Intentionally empty. Camera/OCR/AI recognition is not implemented yet.
  }
}

class ParkingIRIS {
  const ParkingIRIS();

  ParkingConfidence calculateConfidence(List<ParkingEvidence> evidence) {
    if (evidence.isEmpty) {
      return const ParkingConfidence(score: 0, reason: 'Unknown: no evidence.');
    }

    final strongest = evidence
        .map(_confidenceForEvidence)
        .reduce((a, b) => a.score >= b.score ? a : b);
    return strongest;
  }

  ParkingConfidence _confidenceForEvidence(ParkingEvidence evidence) {
    if (evidence.source == ParkingEvidenceSource.councilData &&
        evidence.verified) {
      return const ParkingConfidence(
        score: 1,
        reason: 'Verified council data: 100%.',
      );
    }
    if (evidence.source == ParkingEvidenceSource.verifiedSign &&
        evidence.verified) {
      return const ParkingConfidence(
        score: 0.98,
        reason: 'Verified sign: 98%.',
      );
    }
    if (evidence.reportCount >= 2 && evidence.verified) {
      return const ParkingConfidence(
        score: 0.95,
        reason: 'Multiple verified reports: 95%.',
      );
    }
    if (evidence.reportCount == 1 && evidence.verified) {
      return const ParkingConfidence(
        score: 0.75,
        reason: 'Single verified report: 75%.',
      );
    }
    if (evidence.seed) {
      return const ParkingConfidence(score: 0.70, reason: 'Seed data: 70%.');
    }
    return const ParkingConfidence(score: 0, reason: 'Unknown: 0%.');
  }
}
