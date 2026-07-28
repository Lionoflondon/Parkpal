import 'package:cloud_functions/cloud_functions.dart';

class ParkPalBillingSession {
  const ParkPalBillingSession({
    required this.url,
    this.sessionId,
  });

  final String url;
  final String? sessionId;
}

class ParkPalSubscriptionSnapshot {
  const ParkPalSubscriptionSnapshot({
    required this.planKey,
    required this.status,
    required this.currency,
    required this.priceMinor,
    required this.cancelAtPeriodEnd,
    this.currentPeriodEnd,
    this.latestPaymentStatus,
  });

  final String planKey;
  final String status;
  final String currency;
  final int priceMinor;
  final bool cancelAtPeriodEnd;
  final DateTime? currentPeriodEnd;
  final String? latestPaymentStatus;

  bool get isActive =>
      status == 'active' ||
      status == 'trialing' ||
      status == 'cancel_at_period_end';

  bool get isPastDue => status == 'past_due' || status == 'unpaid';

  String get planName {
    switch (planKey) {
      case 'parkpal_business_monthly':
      case 'parkpal_fleet':
        return 'ParkPal Business Intelligence';
      default:
        return 'ParkPal Intelligence';
    }
  }

  String get priceLabel {
    if (priceMinor <= 0) return 'Configured in Stripe';
    return '${currency.toUpperCase()} ${(priceMinor / 100).toStringAsFixed(2)} / month';
  }

  factory ParkPalSubscriptionSnapshot.fromMap(Map<String, dynamic> data) {
    return ParkPalSubscriptionSnapshot(
      planKey: data['planKey']?.toString() ?? 'parkpal_monthly',
      status: data['status']?.toString() ?? 'none',
      currency: data['currency']?.toString() ?? 'GBP',
      priceMinor: _intValue(data['priceMinor']),
      cancelAtPeriodEnd: data['cancelAtPeriodEnd'] == true,
      currentPeriodEnd: _dateValue(data['currentPeriodEnd']),
      latestPaymentStatus: data['latestPaymentStatus']?.toString(),
    );
  }

  static int _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _dateValue(Object? value) {
    if (value == null) return null;
    try {
      final seconds = (value as dynamic).seconds;
      if (seconds is num) {
        return DateTime.fromMillisecondsSinceEpoch(seconds.toInt() * 1000);
      }
    } catch (_) {
      // Non-Timestamp values fall through to ISO parsing.
    }
    return DateTime.tryParse(value.toString());
  }
}

class ParkPalBillingService {
  ParkPalBillingService({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'europe-west2');

  final FirebaseFunctions _functions;

  Future<ParkPalBillingSession?> createCheckoutSession({
    String planKey = 'parkpal_monthly',
  }) async {
    try {
      final callable =
          _functions.httpsCallable('createParkPalSubscriptionCheckout');
      final response = await callable.call<Map<String, dynamic>>({
        'planKey': planKey,
      });
      final data = response.data;
      final url = data['url']?.toString();
      if (url == null || url.trim().isEmpty) return null;
      return ParkPalBillingSession(
        url: url,
        sessionId: data['sessionId']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<ParkPalBillingSession?> createBillingPortalSession({
    bool reactivate = false,
  }) async {
    try {
      final callable =
          _functions.httpsCallable('createParkPalBillingPortalSession');
      final response = await callable.call<Map<String, dynamic>>({
        if (reactivate) 'intent': 'reactivate',
      });
      final url = response.data['url']?.toString();
      if (url == null || url.trim().isEmpty) return null;
      return ParkPalBillingSession(url: url);
    } catch (_) {
      return null;
    }
  }

  Future<ParkPalSubscriptionSnapshot?> getSubscription() async {
    try {
      final callable = _functions.httpsCallable('getParkPalSubscription');
      final response = await callable.call<Map<String, dynamic>>();
      final data = response.data['subscription'];
      if (data is! Map) return null;
      return ParkPalSubscriptionSnapshot.fromMap(
        Map<String, dynamic>.from(data),
      );
    } catch (_) {
      return null;
    }
  }

  Future<ParkPalSubscriptionSnapshot?> refreshSubscription() async {
    try {
      final callable = _functions.httpsCallable('refreshParkPalSubscription');
      final response = await callable.call<Map<String, dynamic>>();
      final data = response.data['subscription'];
      if (data is! Map) return null;
      return ParkPalSubscriptionSnapshot.fromMap(
        Map<String, dynamic>.from(data),
      );
    } catch (_) {
      return null;
    }
  }
}
