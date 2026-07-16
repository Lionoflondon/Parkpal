import 'parking_intelligence_models.dart';
import '../parking_query/parking_lookup_result.dart';

enum IrisParkingIntent {
  canIPark,
  restrictions,
  restrictionEnd,
  vehicleEligibility,
  nearestAlternative,
  afterTime,
  signMeaning,
  nearbyLowerRestriction,
  unknown,
}

class IrisParkingAnswer {
  const IrisParkingAnswer({
    required this.intent,
    required this.answer,
    required this.result,
    required this.confidence,
    required this.followUpSuggestion,
  });

  final IrisParkingIntent intent;
  final String answer;
  final ParkingLookupResult result;
  final double confidence;
  final String followUpSuggestion;
}

abstract interface class ParkingIntelligenceEvaluator {
  Future<ParkingLookupResult> evaluate(ParkingIntelligenceContext context);
}

class IrisParkingAssistant {
  const IrisParkingAssistant({required ParkingIntelligenceEvaluator evaluator})
      : _evaluator = evaluator;

  final ParkingIntelligenceEvaluator _evaluator;

  Future<IrisParkingAnswer> ask({
    required String question,
    required String location,
    DateTime? now,
    String? vehicleType,
  }) async {
    final intent = classify(question);
    final contextTime = _timeFromQuestion(question, now ?? DateTime.now());
    final result = await _evaluator.evaluate(
      ParkingIntelligenceContext(queryText: location, now: contextTime),
    );
    final answer = _answerFor(
      intent: intent,
      result: result,
      location: location,
      vehicleType: vehicleType,
      questionTime: contextTime,
    );
    return IrisParkingAnswer(
      intent: intent,
      answer: answer,
      result: result,
      confidence: result.confidenceScore,
      followUpSuggestion: _followUpFor(intent, result),
    );
  }

  IrisParkingIntent classify(String question) {
    final lower = question.toLowerCase();
    if (lower.contains('nearest') ||
        lower.contains('alternative') ||
        lower.contains('nearby')) {
      if (lower.contains('fewer') || lower.contains('less restriction')) {
        return IrisParkingIntent.nearbyLowerRestriction;
      }
      return IrisParkingIntent.nearestAlternative;
    }
    if (lower.contains('after') || lower.contains('6pm')) {
      return IrisParkingIntent.afterTime;
    }
    if (lower.contains('when') &&
        (lower.contains('end') || lower.contains('finish'))) {
      return IrisParkingIntent.restrictionEnd;
    }
    if (lower.contains('vehicle') ||
        lower.contains('van') ||
        lower.contains('motorbike') ||
        lower.contains('disabled') ||
        lower.contains('permit')) {
      return IrisParkingIntent.vehicleEligibility;
    }
    if (lower.contains('sign') || lower.contains('mean')) {
      return IrisParkingIntent.signMeaning;
    }
    if (lower.contains('restriction') || lower.contains('rules')) {
      return IrisParkingIntent.restrictions;
    }
    if (lower.contains('park')) return IrisParkingIntent.canIPark;
    return IrisParkingIntent.unknown;
  }

  String _answerFor({
    required IrisParkingIntent intent,
    required ParkingLookupResult result,
    required String location,
    required String? vehicleType,
    required DateTime questionTime,
  }) {
    if (result.canPark == CanParkStatus.unknown) {
      return 'Unknown for $location. ParkPal does not have enough verified Atlas intelligence to answer confidently yet. Always check the street sign before parking.';
    }

    final status = switch (result.canPark) {
      CanParkStatus.yes => 'Yes — parking appears permitted',
      CanParkStatus.no => 'No — do not park',
      CanParkStatus.unknown => 'Unknown',
    };
    final confidence = (result.confidenceScore * 100).round().clamp(0, 100);
    final time =
        '${questionTime.hour.toString().padLeft(2, '0')}:${questionTime.minute.toString().padLeft(2, '0')}';

    return switch (intent) {
      IrisParkingIntent.canIPark =>
        '$status at $location based on current Atlas evidence. Confidence: $confidence%. ${result.ruleSummary}',
      IrisParkingIntent.restrictions =>
        'Restrictions for $location: ${result.ruleSummary} Time window: ${result.timeWindow}. Confidence: $confidence%.',
      IrisParkingIntent.restrictionEnd =>
        'The known restriction window is ${result.timeWindow}. If the sign shows a different end time, treat the sign as authoritative and report it to ParkPal.',
      IrisParkingIntent.vehicleEligibility =>
        'For ${vehicleType ?? 'this vehicle'}, ParkPal can only use the verified restriction data available. ${result.ruleSummary} Permit/payment status: ${result.paymentRequiredLabel}.',
      IrisParkingIntent.nearestAlternative ||
      IrisParkingIntent.nearbyLowerRestriction =>
        'ParkPal cannot yet recommend a specific legal alternative from verified nearby Atlas data. Use the Live Map to compare nearby roads and only rely on verified/official confidence labels.',
      IrisParkingIntent.afterTime =>
        'At $time, ParkPal evaluates the same Atlas rule window: ${result.timeWindow}. ${result.ruleSummary}',
      IrisParkingIntent.signMeaning =>
        'This means: ${result.ruleSummary} IRIS has not used live sign OCR here; this explanation comes from existing Atlas/parking intelligence.',
      IrisParkingIntent.unknown =>
        '$status. ${result.ruleSummary} Confidence: $confidence%.',
    };
  }

  String _followUpFor(IrisParkingIntent intent, ParkingLookupResult result) {
    if (result.canPark == CanParkStatus.unknown) {
      return 'Submit a Pioneer report or upload sign evidence for moderation.';
    }
    return switch (intent) {
      IrisParkingIntent.nearestAlternative ||
      IrisParkingIntent.nearbyLowerRestriction =>
        'Open Live Map and enable confidence overlays.',
      IrisParkingIntent.signMeaning =>
        'Upload a clear sign photo when IRIS scan is available.',
      _ => 'Save this check to your Evidence Vault before walking away.',
    };
  }

  DateTime _timeFromQuestion(String question, DateTime fallback) {
    final lower = question.toLowerCase();
    if (lower.contains('6pm')) {
      return DateTime(
        fallback.year,
        fallback.month,
        fallback.day,
        18,
      );
    }
    final match = RegExp(r'after\s+(\d{1,2})(?::(\d{2}))?').firstMatch(lower);
    if (match == null) return fallback;
    final hour = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '0') ?? 0;
    if (hour == null || hour > 23 || minute > 59) return fallback;
    return DateTime(fallback.year, fallback.month, fallback.day, hour, minute);
  }
}
