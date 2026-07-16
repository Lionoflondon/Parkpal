import 'package:flutter_test/flutter_test.dart';
import 'package:parkpal/features/parking_intelligence/iris_parking_assistant.dart';
import 'package:parkpal/features/parking_intelligence/parking_intelligence_models.dart';
import 'package:parkpal/features/parking_query/parking_lookup_result.dart';

class _FakeEvaluator implements ParkingIntelligenceEvaluator {
  _FakeEvaluator(this.result);

  final ParkingLookupResult result;
  ParkingIntelligenceContext? lastContext;

  @override
  Future<ParkingLookupResult> evaluate(
      ParkingIntelligenceContext context) async {
    lastContext = context;
    return result;
  }
}

void main() {
  group('IrisParkingAssistant', () {
    test('answers can I park questions using existing intelligence', () async {
      final evaluator = _FakeEvaluator(const ParkingLookupResult(
        canPark: CanParkStatus.yes,
        ruleSummary: 'Permit bay inactive outside controlled hours.',
        timeWindow: 'Mon-Fri 08:30-18:30',
        paymentRequired: PaymentRequiredStatus.unknown,
        riskLevel: 'Low',
        confidenceScore: 0.92,
        evidenceSource: ParkingEvidenceSource.councilData,
        evidenceReason: 'Official Atlas evidence.',
      ));
      final assistant = IrisParkingAssistant(evaluator: evaluator);

      final answer = await assistant.ask(
        question: 'Can I park here?',
        location: 'Kensington Road',
        now: DateTime(2026, 7, 16, 11, 42),
      );

      expect(answer.intent, IrisParkingIntent.canIPark);
      expect(answer.answer, contains('Yes'));
      expect(answer.answer, contains('Confidence: 92%'));
      expect(evaluator.lastContext?.queryText, 'Kensington Road');
    });

    test('evaluates after-time questions at the requested time', () async {
      final evaluator = _FakeEvaluator(ParkingLookupResult.unknown());
      final assistant = IrisParkingAssistant(evaluator: evaluator);

      await assistant.ask(
        question: 'What changes after 6pm?',
        location: 'Camden High Street',
        now: DateTime(2026, 7, 16, 10),
      );

      expect(evaluator.lastContext?.now.hour, 18);
      expect(evaluator.lastContext?.now.minute, 0);
    });

    test('does not invent alternatives when Atlas lacks verified nearby data',
        () async {
      final evaluator = _FakeEvaluator(const ParkingLookupResult(
        canPark: CanParkStatus.no,
        ruleSummary: 'No waiting at any time.',
        timeWindow: 'At any time',
        paymentRequired: PaymentRequiredStatus.unknown,
        riskLevel: 'High',
        confidenceScore: 0.98,
        evidenceSource: ParkingEvidenceSource.verifiedSign,
        evidenceReason: 'Verified sign.',
      ));
      final assistant = IrisParkingAssistant(evaluator: evaluator);

      final answer = await assistant.ask(
        question: 'Where is the nearest legal alternative?',
        location: 'Oxford Street',
      );

      expect(answer.intent, IrisParkingIntent.nearestAlternative);
      expect(answer.answer, contains('cannot yet recommend a specific'));
    });
  });
}
