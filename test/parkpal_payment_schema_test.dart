import 'package:parkpal/features/payments/parkpal_payment_schema.dart';
import 'package:test/test.dart';

void main() {
  test('subscription schema is intelligence-only and has no booking behaviour',
      () {
    final now = DateTime.utc(2026, 7, 16);
    final entitlement = ParkPalSubscriptionEntitlement(
      subscriptionId: 'sub_123',
      userId: 'user_123',
      planId: 'parkpal_plus',
      status: ParkPalSubscriptionStatus.active,
      currency: 'GBP',
      priceMinor: 799,
      pioneerCreditMinor: 100,
      currentPeriodStart: now,
      currentPeriodEnd: DateTime.utc(2026, 8, 16),
      createdAt: now,
      updatedAt: now,
      features: const ['atlas_history', 'evidence_vault'],
    );

    final map = entitlement.toMap();

    expect(entitlement.active, isTrue);
    expect(map['productScope'], 'parking_intelligence_only');
    expect(map.containsKey('bookingId'), isFalse);
    expect(map.containsKey('reservationId'), isFalse);
    expect(ParkPalPaymentSchemaGuard.isParkingIntelligenceOnly(map), isTrue);
  });

  test('ledger schema rejects populated booking or reservation fields', () {
    final valid = {
      'type': ParkPalLedgerEntryType.subscriptionCredit.name,
      'amountMinor': -100,
      'bookingId': null,
      'reservationId': null,
    };
    final invalid = {
      ...valid,
      'bookingId': 'booking_123',
    };

    expect(ParkPalPaymentSchemaGuard.isParkingIntelligenceOnly(valid), isTrue);
    expect(
      ParkPalPaymentSchemaGuard.isParkingIntelligenceOnly(invalid),
      isFalse,
    );
  });
}
