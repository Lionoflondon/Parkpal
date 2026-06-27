enum CanParkStatus { yes, no, unknown }
enum PaymentRequiredStatus { yes, no, unknown }
enum ParkingEvidenceSource { seedData, verifiedSign, councilData, userReport, none }

class ParkingLookupResult {
  const ParkingLookupResult({
    required this.canPark,
    required this.ruleSummary,
    required this.timeWindow,
    required this.paymentRequired,
    required this.riskLevel,
    required this.confidenceScore,
    required this.evidenceSource,
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
    );
  }

  final CanParkStatus canPark;
  final String ruleSummary;
  final String timeWindow;
  final PaymentRequiredStatus paymentRequired;
  final String riskLevel;
  final double confidenceScore;
  final ParkingEvidenceSource evidenceSource;

  String get canParkLabel {
    return switch (canPark) {
      CanParkStatus.yes => 'Yes',
      CanParkStatus.no => 'No',
      CanParkStatus.unknown => 'Unknown',
    };
  }

  String get paymentRequiredLabel {
    return switch (paymentRequired) {
      PaymentRequiredStatus.yes => 'Yes',
      PaymentRequiredStatus.no => 'No',
      PaymentRequiredStatus.unknown => 'Unknown',
    };
  }

  String get evidenceSourceLabel {
    return switch (evidenceSource) {
      ParkingEvidenceSource.seedData => 'seed data',
      ParkingEvidenceSource.verifiedSign => 'verified sign',
      ParkingEvidenceSource.councilData => 'council data',
      ParkingEvidenceSource.userReport => 'user report',
      ParkingEvidenceSource.none => 'none',
    };
  }
}
