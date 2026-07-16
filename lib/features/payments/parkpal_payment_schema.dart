enum ParkPalPaymentProvider { stripe, manual, internalLedger }

enum ParkPalPaymentStatus {
  draft,
  pending,
  succeeded,
  failed,
  cancelled,
  refunded,
  disputed,
}

enum ParkPalSubscriptionStatus {
  none,
  trialing,
  active,
  pastDue,
  paused,
  cancelled,
}

enum ParkPalLedgerEntryType {
  subscriptionCharge,
  subscriptionCredit,
  refund,
  adjustment,
  pioneerRewardCredit,
  appealSupportCharge,
}

class ParkPalPaymentCollections {
  const ParkPalPaymentCollections._();

  static const customers = 'parkpalPaymentCustomers';
  static const subscriptions = 'parkpalSubscriptions';
  static const invoices = 'parkpalInvoices';
  static const paymentEvents = 'parkpalPaymentEvents';
  static const ledger = 'parkpalPaymentLedger';
  static const providerConfig = 'parkpalPaymentProviderConfig';
  static const audit = 'parkpalPaymentAudit';
}

class ParkPalPaymentCustomer {
  const ParkPalPaymentCustomer({
    required this.userId,
    required this.email,
    required this.provider,
    required this.providerCustomerId,
    required this.defaultCurrency,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.displayName,
    this.defaultPaymentMethodId,
    this.billingCountry = 'GB',
    this.metadata = const {},
  });

  final String userId;
  final String email;
  final String? displayName;
  final ParkPalPaymentProvider provider;
  final String providerCustomerId;
  final String? defaultPaymentMethodId;
  final String defaultCurrency;
  final String billingCountry;
  final ParkPalPaymentStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, Object?> metadata;

  Map<String, Object?> toMap() => {
        'userId': userId,
        'email': email,
        'displayName': displayName,
        'provider': provider.name,
        'providerCustomerId': providerCustomerId,
        'defaultPaymentMethodId': defaultPaymentMethodId,
        'defaultCurrency': defaultCurrency,
        'billingCountry': billingCountry,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'metadata': metadata,
      };
}

class ParkPalSubscriptionEntitlement {
  const ParkPalSubscriptionEntitlement({
    required this.subscriptionId,
    required this.userId,
    required this.planId,
    required this.status,
    required this.currency,
    required this.priceMinor,
    required this.currentPeriodStart,
    required this.currentPeriodEnd,
    required this.createdAt,
    required this.updatedAt,
    this.provider = ParkPalPaymentProvider.stripe,
    this.providerSubscriptionId,
    this.pioneerCreditMinor = 0,
    this.features = const [],
    this.metadata = const {},
  });

  final String subscriptionId;
  final String userId;
  final String planId;
  final ParkPalSubscriptionStatus status;
  final ParkPalPaymentProvider provider;
  final String? providerSubscriptionId;
  final String currency;
  final int priceMinor;
  final int pioneerCreditMinor;
  final DateTime currentPeriodStart;
  final DateTime currentPeriodEnd;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> features;
  final Map<String, Object?> metadata;

  bool get active =>
      status == ParkPalSubscriptionStatus.active ||
      status == ParkPalSubscriptionStatus.trialing;

  Map<String, Object?> toMap() => {
        'subscriptionId': subscriptionId,
        'userId': userId,
        'planId': planId,
        'status': status.name,
        'provider': provider.name,
        'providerSubscriptionId': providerSubscriptionId,
        'currency': currency,
        'priceMinor': priceMinor,
        'pioneerCreditMinor': pioneerCreditMinor,
        'currentPeriodStart': currentPeriodStart.toIso8601String(),
        'currentPeriodEnd': currentPeriodEnd.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'features': features,
        'metadata': metadata,
        'productScope': 'parking_intelligence_only',
      };
}

class ParkPalPaymentLedgerEntry {
  const ParkPalPaymentLedgerEntry({
    required this.entryId,
    required this.userId,
    required this.type,
    required this.status,
    required this.amountMinor,
    required this.currency,
    required this.reason,
    required this.createdAt,
    this.invoiceId,
    this.providerEventId,
    this.metadata = const {},
  });

  final String entryId;
  final String userId;
  final ParkPalLedgerEntryType type;
  final ParkPalPaymentStatus status;
  final int amountMinor;
  final String currency;
  final String reason;
  final String? invoiceId;
  final String? providerEventId;
  final DateTime createdAt;
  final Map<String, Object?> metadata;

  Map<String, Object?> toMap() => {
        'entryId': entryId,
        'userId': userId,
        'type': type.name,
        'status': status.name,
        'amountMinor': amountMinor,
        'currency': currency,
        'reason': reason,
        'invoiceId': invoiceId,
        'providerEventId': providerEventId,
        'createdAt': createdAt.toIso8601String(),
        'metadata': metadata,
        'bookingId': null,
        'reservationId': null,
      };
}

class ParkPalPaymentSchemaGuard {
  const ParkPalPaymentSchemaGuard._();

  static const forbiddenBookingFields = {
    'bookingId',
    'reservationId',
    'parkingSpaceId',
    'carParkId',
    'arrivalTime',
    'departureTime',
  };

  static bool isParkingIntelligenceOnly(Map<String, Object?> payload) {
    for (final key in forbiddenBookingFields) {
      final value = payload[key];
      if (value != null && value.toString().trim().isNotEmpty) return false;
    }
    return true;
  }
}
