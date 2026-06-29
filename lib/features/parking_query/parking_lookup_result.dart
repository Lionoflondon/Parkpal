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
