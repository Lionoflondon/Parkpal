export type ParkPalRewardProgram = "subscription" | "referral" | "promotion";

export interface ProgramPolicy {
  enabled: boolean;
  approved: boolean;
  amountPence: number | null;
  maxPerCustomer: number;
}

export interface ParkPalRewardPolicy {
  programs: Record<ParkPalRewardProgram, ProgramPolicy>;
  reversalsReady: boolean;
}

const disabledProgram = (): ProgramPolicy => ({
  enabled: false,
  approved: false,
  amountPence: null,
  maxPerCustomer: 0,
});

export const DISABLED_PARKPAL_REWARD_POLICY: ParkPalRewardPolicy = {
  programs: {
    subscription: disabledProgram(),
    referral: disabledProgram(),
    promotion: disabledProgram(),
  },
  reversalsReady: false,
};

/** Parse an owner-managed Secret Manager policy. Missing or invalid policy always disables rewards. */
export function parseParkPalRewardPolicy(raw: string | undefined): ParkPalRewardPolicy {
  if (!raw?.trim()) return DISABLED_PARKPAL_REWARD_POLICY;
  try {
    const parsed = JSON.parse(raw) as Record<string, unknown>;
    const programs = (parsed.programs ?? {}) as Record<string, unknown>;
    const result = {} as Record<ParkPalRewardProgram, ProgramPolicy>;
    for (const key of ["subscription", "referral", "promotion"] as const) {
      const value = (programs[key] ?? {}) as Record<string, unknown>;
      const amount = value.amountPence;
      const limit = value.maxPerCustomer;
      const structurallyValid = typeof value.enabled === "boolean" &&
        typeof value.approved === "boolean" &&
        (amount === null || (Number.isSafeInteger(amount) && Number(amount) > 0 && Number(amount) <= 100_000)) &&
        Number.isSafeInteger(limit) && Number(limit) >= 0 && Number(limit) <= 10_000;
      if (!structurallyValid) return DISABLED_PARKPAL_REWARD_POLICY;
      result[key] = {
        enabled: value.enabled === true,
        approved: value.approved === true,
        amountPence: amount === null ? null : Number(amount),
        maxPerCustomer: Number(limit),
      };
    }
    return {
      programs: result,
      reversalsReady: parsed.reversalsReady === true,
    };
  } catch {
    return DISABLED_PARKPAL_REWARD_POLICY;
  }
}

export interface PaidSubscriptionEvidence {
  invoicePaid: boolean;
  invoiceStatus: string;
  amountPaid: number;
  paymentIntentId: string;
  invoiceSubscriptionId: string;
  invoiceCustomerId: string;
  subscriptionId: string;
  subscriptionCustomerId: string;
  subscriptionStatus: string;
  cancelAtPeriodEnd: boolean;
  emailVerified: boolean;
  alreadyRefunded: boolean;
  disputed: boolean;
  existingRewardForInvoice: boolean;
}

/** Strict pre-issuance check; this never creates or issues a reward itself. */
export function subscriptionRewardEligibility(
  evidence: PaidSubscriptionEvidence,
  policy: ParkPalRewardPolicy,
): {eligible: boolean; reason: string; amountPence: number | null} {
  const program = policy.programs.subscription;
  if (!program.enabled || !program.approved || !policy.reversalsReady) {
    return {eligible: false, reason: "reward_policy_disabled_or_unapproved", amountPence: null};
  }
  if (!evidence.invoicePaid || evidence.invoiceStatus !== "paid" ||
      !Number.isSafeInteger(evidence.amountPaid) || evidence.amountPaid <= 0 ||
      !evidence.paymentIntentId) {
    return {eligible: false, reason: "payment_not_verified", amountPence: null};
  }
  if (!evidence.invoiceSubscriptionId || evidence.invoiceSubscriptionId !== evidence.subscriptionId ||
      !evidence.invoiceCustomerId || evidence.invoiceCustomerId !== evidence.subscriptionCustomerId) {
    return {eligible: false, reason: "subscription_identity_mismatch", amountPence: null};
  }
  if (evidence.subscriptionStatus !== "active" || evidence.cancelAtPeriodEnd || !evidence.emailVerified) {
    return {eligible: false, reason: "subscription_not_eligible", amountPence: null};
  }
  if (evidence.alreadyRefunded || evidence.disputed) {
    return {eligible: false, reason: "payment_refunded_or_disputed", amountPence: null};
  }
  if (evidence.existingRewardForInvoice) {
    return {eligible: false, reason: "duplicate_invoice_reward", amountPence: null};
  }
  if (!Number.isSafeInteger(program.amountPence) || (program.amountPence ?? 0) < 1 || program.maxPerCustomer < 1) {
    return {eligible: false, reason: "reward_amount_or_limit_unconfigured", amountPence: null};
  }
  return {eligible: true, reason: "eligible_after_verified_payment", amountPence: program.amountPence};
}
