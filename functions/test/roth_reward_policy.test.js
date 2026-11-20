const assert = require("node:assert/strict");
const test = require("node:test");
const {
  DISABLED_PARKPAL_REWARD_POLICY,
  parseParkPalRewardPolicy,
  subscriptionRewardEligibility,
} = require("../lib/roth_reward_policy");

const validEvidence = {
  invoicePaid: true,
  invoiceStatus: "paid",
  amountPaid: 1200,
  paymentIntentId: "pi_test_123",
  invoiceSubscriptionId: "sub_test_123",
  invoiceCustomerId: "cus_test_123",
  subscriptionId: "sub_test_123",
  subscriptionCustomerId: "cus_test_123",
  subscriptionStatus: "active",
  cancelAtPeriodEnd: false,
  emailVerified: true,
  alreadyRefunded: false,
  disputed: false,
  existingRewardForInvoice: false,
};

function approvedPolicy(overrides = {}) {
  return parseParkPalRewardPolicy(JSON.stringify({
    reversalsReady: true,
    programs: {
      subscription: {enabled: true, approved: true, amountPence: 100, maxPerCustomer: 1},
      referral: {enabled: false, approved: false, amountPence: null, maxPerCustomer: 0},
      promotion: {enabled: false, approved: false, amountPence: null, maxPerCustomer: 0},
      ...overrides,
    },
  }));
}

test("missing and malformed reward policy fails closed for every reward program", () => {
  assert.deepEqual(parseParkPalRewardPolicy(undefined), DISABLED_PARKPAL_REWARD_POLICY);
  assert.deepEqual(parseParkPalRewardPolicy("not-json"), DISABLED_PARKPAL_REWARD_POLICY);
  assert.equal(parseParkPalRewardPolicy(undefined).programs.subscription.enabled, false);
  assert.equal(parseParkPalRewardPolicy(undefined).programs.referral.enabled, false);
  assert.equal(parseParkPalRewardPolicy(undefined).programs.promotion.enabled, false);
});

test("subscription policy rejects unapproved issuance or unavailable reversal controls", () => {
  const policy = approvedPolicy();
  policy.programs.subscription.approved = false;
  assert.equal(subscriptionRewardEligibility(validEvidence, policy).eligible, false);
  policy.programs.subscription.approved = true;
  policy.reversalsReady = false;
  assert.equal(subscriptionRewardEligibility(validEvidence, policy).eligible, false);
});

test("subscription eligibility requires verified paid, active, linked and refundable-safe evidence", () => {
  const policy = approvedPolicy();
  assert.deepEqual(subscriptionRewardEligibility(validEvidence, policy), {
    eligible: true,
    reason: "eligible_after_verified_payment",
    amountPence: 100,
  });
  for (const change of [
    {invoicePaid: false},
    {invoiceStatus: "open"},
    {amountPaid: 0},
    {paymentIntentId: ""},
    {subscriptionStatus: "trialing"},
    {cancelAtPeriodEnd: true},
    {emailVerified: false},
    {alreadyRefunded: true},
    {disputed: true},
    {existingRewardForInvoice: true},
    {invoiceCustomerId: "cus_other"},
    {invoiceSubscriptionId: "sub_other"},
  ]) {
    assert.equal(subscriptionRewardEligibility({...validEvidence, ...change}, policy).eligible, false);
  }
});

test("policy rejects invalid amounts and customer limits instead of partially enabling rewards", () => {
  const invalid = JSON.stringify({programs: {
    subscription: {enabled: true, approved: true, amountPence: -1, maxPerCustomer: 1},
  }});
  assert.deepEqual(parseParkPalRewardPolicy(invalid), DISABLED_PARKPAL_REWARD_POLICY);
});
