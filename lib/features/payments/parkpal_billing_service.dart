import 'package:cloud_functions/cloud_functions.dart';

class ParkPalBillingSession {
  const ParkPalBillingSession({
    required this.url,
    this.sessionId,
  });

  final String url;
  final String? sessionId;
}

class ParkPalBillingService {
  ParkPalBillingService({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'europe-west2');

  final FirebaseFunctions _functions;

  Future<ParkPalBillingSession?> createCheckoutSession({
    String planId = 'parkpal_plus',
    String? returnBaseUrl,
  }) async {
    try {
      final callable =
          _functions.httpsCallable('createParkPalStripeCheckoutSession');
      final response = await callable.call<Map<String, dynamic>>({
        'planId': planId,
        if (returnBaseUrl != null) 'returnBaseUrl': returnBaseUrl,
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
    String? returnBaseUrl,
  }) async {
    try {
      final callable =
          _functions.httpsCallable('createParkPalStripeBillingPortalSession');
      final response = await callable.call<Map<String, dynamic>>({
        if (returnBaseUrl != null) 'returnBaseUrl': returnBaseUrl,
      });
      final url = response.data['url']?.toString();
      if (url == null || url.trim().isEmpty) return null;
      return ParkPalBillingSession(url: url);
    } catch (_) {
      return null;
    }
  }
}
