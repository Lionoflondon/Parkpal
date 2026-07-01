enum CanParkStatus { yes, no, unknown }

enum PaymentRequiredStatus { yes, no, unknown }

enum ParkingEvidenceSource {
  adminVerifiedRule,
  seedData,
  verifiedSign,
  councilData,
  parkpalConnect,
  userReport,
  none,
}

class ParkingLookupResult {
  const ParkingLookupResult({
    required this.canPark,
    required this.ruleSummary,
    required this.timeWindow,
    required this.paymentRequired,
    required this.riskLevel,
    required this.confidenceScore,
    required this.evidenceSource,
    required this.evidenceReason,
    this.leaveByTime = 'Unknown',
  });

  factory ParkingLookupResult.unknown() {
    return const ParkingLookupResult(
      canPark: CanParkStatus.unknown,
      ruleSummary:
          'Unknown — ParkPal does not have enough verified data for this location yet.',
      timeWindow: 'Unknown',
      paymentRequired: PaymentRequiredStatus.unknown,
      riskLevel: 'Unknown',
      confidenceScore: 0,
      evidenceSource: ParkingEvidenceSource.none,
      evidenceReason: 'No matching verified or imported evidence found.',
      leaveByTime: 'Unknown',
    );
  }

  final CanParkStatus canPark;
  final String ruleSummary;
  final String timeWindow;
  final PaymentRequiredStatus paymentRequired;
  final String riskLevel;
  final double confidenceScore;
  final ParkingEvidenceSource evidenceSource;
  final String evidenceReason;
  final String leaveByTime;

  ParkingLookupResult copyWith({
    CanParkStatus? canPark,
    String? ruleSummary,
    String? timeWindow,
    PaymentRequiredStatus? paymentRequired,
    String? riskLevel,
    double? confidenceScore,
    ParkingEvidenceSource? evidenceSource,
    String? evidenceReason,
    String? leaveByTime,
  }) {
    return ParkingLookupResult(
      canPark: canPark ?? this.canPark,
      ruleSummary: ruleSummary ?? this.ruleSummary,
      timeWindow: timeWindow ?? this.timeWindow,
      paymentRequired: paymentRequired ?? this.paymentRequired,
      riskLevel: riskLevel ?? this.riskLevel,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      evidenceSource: evidenceSource ?? this.evidenceSource,
      evidenceReason: evidenceReason ?? this.evidenceReason,
      leaveByTime: leaveByTime ?? this.leaveByTime,
    );
  }

  String get canParkLabel {
    return switch (canPark) {
      CanParkStatus.yes => 'Allowed',
      CanParkStatus.no => 'Not allowed',
      CanParkStatus.unknown => 'Unknown',
    };
  }

  String get paymentRequiredLabel {
    return switch (paymentRequired) {
      PaymentRequiredStatus.yes => 'Paid',
      PaymentRequiredStatus.no => 'Free',
      PaymentRequiredStatus.unknown => 'Unknown',
    };
  }

  String get evidenceSourceLabel {
    return switch (evidenceSource) {
      ParkingEvidenceSource.adminVerifiedRule => 'admin-verified rule',
      ParkingEvidenceSource.seedData => 'seed data',
      ParkingEvidenceSource.verifiedSign => 'verified sign',
      ParkingEvidenceSource.councilData => 'council data',
      ParkingEvidenceSource.parkpalConnect => 'ParkPal Connect source',
      ParkingEvidenceSource.userReport => 'user report',
      ParkingEvidenceSource.none => 'none',
    };
  }
}
