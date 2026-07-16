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
    this.sourceConfidence,
    this.lastUpdatedAt,
    this.conflict = false,
    this.geometryValid = true,
    this.sourceHealth = 'unknown',
  });

  final ParkingEvidenceSource source;
  final Map<String, Object?> data;
  final String summary;
  final bool verified;
  final bool seed;
  final int reportCount;
  final double? sourceConfidence;
  final DateTime? lastUpdatedAt;
  final bool conflict;
  final bool geometryValid;
  final String sourceHealth;
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

  Future<void> prepareSignRecognition() async {
    // Reserved architecture hook for future camera/OCR/AI recognition.
  }
}

class ParkingIRIS {
  const ParkingIRIS();

  ParkingConfidence calculateConfidence(List<ParkingEvidence> evidence) {
    if (evidence.isEmpty) {
      return const ParkingConfidence(score: 0, reason: 'Unknown: no evidence.');
    }

    final strongest = evidence.map(_confidenceForEvidence).reduce(
          (a, b) => a.score >= b.score ? a : b,
        );
    return strongest;
  }

  ParkingConfidence _confidenceForEvidence(ParkingEvidence evidence) {
    final base = _baseConfidenceForEvidence(evidence);
    var score = evidence.sourceConfidence == null
        ? base.score
        : (base.score * 0.7 + evidence.sourceConfidence!.clamp(0, 1) * 0.3);
    final reasons = <String>[base.reason.replaceAll('.', '')];

    if (evidence.conflict) {
      score = score * 0.45;
      reasons.add('conflict penalty applied');
    }
    if (!evidence.geometryValid) {
      score = score * 0.75;
      reasons.add('geometry requires validation');
    }
    final freshness = _freshnessMultiplier(evidence.lastUpdatedAt);
    if (freshness < 1) {
      score = score * freshness;
      reasons.add('freshness multiplier ${(freshness * 100).round()}%');
    }
    if (evidence.sourceHealth == 'offline') {
      score = score * 0.7;
      reasons.add('source health offline');
    } else if (evidence.sourceHealth == 'warning') {
      score = score * 0.86;
      reasons.add('source health warning');
    }

    return ParkingConfidence(
      score: score.clamp(0, 1).toDouble(),
      reason: '${reasons.join('; ')}: ${(score * 100).round()}%.',
    );
  }

  ParkingConfidence _baseConfidenceForEvidence(ParkingEvidence evidence) {
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

  double _freshnessMultiplier(DateTime? value) {
    if (value == null) return 1;
    final age = DateTime.now().difference(value);
    if (age.inDays <= 90) return 1;
    if (age.inDays <= 180) return 0.92;
    if (age.inDays <= 365) return 0.82;
    return 0.68;
  }
}
