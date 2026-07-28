const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const test = require("node:test");

const {
  assertParkingIntelligencePlan,
  parseStripePriceConfig,
  planForKey,
  resolveParkPalPlans,
  stripeForm,
  stripeRequest,
  verifyStripeSignature,
} = require("../lib/stripe_payments");

test("parseStripePriceConfig maps configured plan ids to Stripe prices", () => {
  assert.deepEqual(
    parseStripePriceConfig("parkpal_plus:price_123, fleet:price_456"),
    {parkpal_plus: "price_123", fleet: "price_456"},
  );
});

test("assertParkingIntelligencePlan rejects booking-oriented plan ids", () => {
  assert.doesNotThrow(() => assertParkingIntelligencePlan("parkpal_plus"));
  assert.throws(() => assertParkingIntelligencePlan("parking_booking_plus"));
  assert.throws(() => assertParkingIntelligencePlan("reservation"));
});

test("resolveParkPalPlans uses monthly server-side price configuration", () => {
  const plans = resolveParkPalPlans({
    PARKPAL_STRIPE_MONTHLY_PRICE_ID: "price_personal",
    PARKPAL_STRIPE_BUSINESS_MONTHLY_PRICE_ID: "price_business",
  });

  assert.equal(plans[0].key, "parkpal_monthly");
  assert.equal(plans[0].stripePriceId, "price_personal");
  assert.equal(plans[0].billingInterval, "month");
  assert.equal(plans[0].currency, "gbp");
  assert.equal(plans[0].active, true);
  assert.equal(plans[1].stripePriceId, "price_business");
});

test("planForKey resolves aliases without accepting client price ids", () => {
  const env = {PARKPAL_STRIPE_MONTHLY_PRICE_ID: "price_personal"};
  assert.equal(planForKey("parkpal_monthly", env).stripePriceId, "price_personal");
  assert.equal(planForKey("parkpal_plus", env).key, "parkpal_monthly");
  assert.throws(() => planForKey("price_123", env));
});

test("stripeForm encodes Stripe nested form fields", () => {
  assert.equal(
    stripeForm({
      mode: "subscription",
      "line_items[0][quantity]": 1,
      allow_promotion_codes: true,
      optional: undefined,
    }),
    "mode=subscription&line_items%5B0%5D%5Bquantity%5D=1&allow_promotion_codes=true",
  );
});

test("verifyStripeSignature validates Stripe webhook signatures", () => {
  const secret = "whsec_test";
  const timestamp = Math.floor(Date.now() / 1000);
  const rawBody = Buffer.from(JSON.stringify({id: "evt_123", type: "invoice.paid"}));
  const signature = crypto
    .createHmac("sha256", secret)
    .update(`${timestamp}.${rawBody.toString("utf8")}`)
    .digest("hex");

  assert.equal(
    verifyStripeSignature(rawBody, `t=${timestamp},v1=${signature}`, secret),
    true,
  );
  assert.equal(
    verifyStripeSignature(rawBody, `t=${timestamp},v1=bad`, secret),
    false,
  );
});

test("stripeRequest uses bearer auth and form-encoded bodies", async () => {
  const response = await stripeRequest(
    "checkout/sessions",
    "sk_test_secret",
    {mode: "subscription"},
    async (url, init) => {
      assert.equal(url, "https://api.stripe.com/v1/checkout/sessions");
      assert.equal(init.method, "POST");
      assert.equal(init.headers.Authorization, "Bearer sk_test_secret");
      assert.equal(
        init.headers["Content-Type"],
        "application/x-www-form-urlencoded",
      );
      assert.equal(init.body, "mode=subscription");
      return {
        ok: true,
        status: 200,
        json: async () => ({id: "cs_test", url: "https://checkout.stripe.test"}),
      };
    },
  );

  assert.equal(response.id, "cs_test");
});
