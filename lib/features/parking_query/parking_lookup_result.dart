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
      evidenceReason: 'No matching verified parking evidence found.',
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
      ParkingEvidenceSource.adminVerifiedRule => 'Verified ParkPal rule',
      ParkingEvidenceSource.seedData => 'ParkPal starter data',
      ParkingEvidenceSource.verifiedSign => 'Verified street sign',
      ParkingEvidenceSource.councilData => 'Council information',
      ParkingEvidenceSource.parkpalConnect => 'Official source',
      ParkingEvidenceSource.userReport => 'Verified community report',
      ParkingEvidenceSource.none => 'No evidence yet',
    };
  }

  String get confidenceLabel {
    final percentage = (confidenceScore * 100).round().clamp(0, 100);
    if (canPark == CanParkStatus.unknown || percentage == 0) return 'Low';
    if (percentage >= 90) return 'High';
    if (percentage >= 70) return 'Medium';
    return 'Low';
  }

  String get customerSafetyNote {
    if (canPark == CanParkStatus.unknown) {
      return 'ParkPal does not have enough verified information here yet. Check the sign in front of you before parking.';
    }
    if (riskLevel.toLowerCase() == 'high') {
      return 'High-risk restrictions may apply here. Do not walk away unless the street sign confirms it is safe.';
    }
    return 'ParkPal guidance is informational. Always check the street sign before parking.';
  }
}
