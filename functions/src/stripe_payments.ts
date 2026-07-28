import * as admin from "firebase-admin";
import * as crypto from "crypto";
import {HttpsError, onCall, onRequest} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import {logger} from "firebase-functions";

const STRIPE_SECRET_KEY = defineSecret("STRIPE_SECRET_KEY");
const STRIPE_WEBHOOK_SECRET = defineSecret("STRIPE_WEBHOOK_SECRET");
const PARKPAL_STRIPE_MONTHLY_PRICE_ID = defineSecret("PARKPAL_STRIPE_MONTHLY_PRICE_ID");
const PARKPAL_STRIPE_BUSINESS_MONTHLY_PRICE_ID = defineSecret("PARKPAL_STRIPE_BUSINESS_MONTHLY_PRICE_ID");
const PARKPAL_STRIPE_PRICE_IDS = defineSecret("PARKPAL_STRIPE_PRICE_IDS");

const paymentCustomers = "parkpalPaymentCustomers";
const subscriptions = "parkpalSubscriptions";
const invoices = "parkpalInvoices";
const paymentEvents = "parkpalPaymentEvents";
const paymentLedger = "parkpalPaymentLedger";
const paymentAudit = "parkpalPaymentAudit";
const adminUsers = "parkpalAdminUsers";
const productDescription =
  "ParkPal provides subscription-based access to parking restriction intelligence, road-sign guidance, evidence records, and fine-prevention tools for UK drivers and businesses. ParkPal does not sell, reserve, or operate parking spaces.";
const allowedRoles = new Set([
  "superAdmin",
  "admin",
  "support",
  "reviewer",
  "pioneerManager",
  "atlasManager",
]);

type Fetcher = typeof fetch;
type StripePayload = Record<string, unknown>;
type PlanKey = "parkpal_monthly" | "parkpal_business_monthly" | "parkpal_plus" | "parkpal_fleet";

type ParkPalPlan = {
  key: PlanKey;
  name: string;
  stripePriceId: string;
  billingInterval: "month";
  currency: "gbp";
  features: string[];
  active: boolean;
};

const activeSubscriptionStatuses = new Set(["trialing", "active", "past_due", "incomplete"]);

export function parseStripePriceConfig(raw = ""): Record<string, string> {
  return raw
    .split(",")
    .map((entry) => entry.trim())
    .filter(Boolean)
    .reduce<Record<string, string>>((result, entry) => {
      const [planId, priceId] = entry.split(":").map((value) => value?.trim());
      if (planId && priceId) result[planId] = priceId;
      return result;
    }, {});
}

export function resolveParkPalPlans(env: NodeJS.ProcessEnv = process.env): ParkPalPlan[] {
  const extra = parseStripePriceConfig(env.PARKPAL_STRIPE_PRICE_IDS);
  const personalPrice = env.PARKPAL_STRIPE_MONTHLY_PRICE_ID ?? extra.parkpal_monthly ?? extra.parkpal_plus ?? "";
  const businessPrice =
    env.PARKPAL_STRIPE_BUSINESS_MONTHLY_PRICE_ID ?? extra.parkpal_business_monthly ?? extra.parkpal_fleet ?? "";
  return [
    {
      key: "parkpal_monthly",
      name: "ParkPal Intelligence",
      stripePriceId: personalPrice,
      billingInterval: "month",
      currency: "gbp",
      features: [
        "Advanced parking restriction checks",
        "IRIS parking guidance",
        "Evidence Vault records",
        "Parking alerts and history",
      ],
      active: Boolean(personalPrice.trim()),
    },
    {
      key: "parkpal_business_monthly",
      name: "ParkPal Business Intelligence",
      stripePriceId: businessPrice,
      billingInterval: "month",
      currency: "gbp",
      features: [
        "Business parking intelligence",
        "Fleet-ready evidence history",
        "Advanced alerts",
        "Priority support workflows",
      ],
      active: Boolean(businessPrice.trim()),
    },
  ];
}

export function planForKey(planKey: string, env: NodeJS.ProcessEnv = process.env): ParkPalPlan {
  assertParkingIntelligencePlan(planKey);
  const aliases: Record<string, PlanKey> = {
    parkpal_plus: "parkpal_monthly",
    parkpal_fleet: "parkpal_business_monthly",
  };
  const canonicalKey = aliases[planKey] ?? planKey;
  const plan = resolveParkPalPlans(env).find((candidate) => candidate.key === canonicalKey);
  if (!plan || !plan.active) {
    throw new HttpsError("failed-precondition", "ParkPal monthly plan is not configured.");
  }
  return plan;
}

export function assertParkingIntelligencePlan(planId: string): void {
  if (!/^[a-z0-9_:-]+$/i.test(planId)) {
    throw new HttpsError("invalid-argument", "Invalid plan key.");
  }
  const forbidden = ["booking", "reservation", "space", "carpark", "car_park", "operator", "session"];
  if (forbidden.some((value) => planId.toLowerCase().includes(value))) {
    throw new HttpsError(
      "invalid-argument",
      "ParkPal payments are for parking intelligence subscriptions only.",
    );
  }
}

export function stripeForm(data: Record<string, string | number | boolean | undefined>): string {
  const params = new URLSearchParams();
  for (const [key, value] of Object.entries(data)) {
    if (value !== undefined) params.append(key, String(value));
  }
  return params.toString();
}

export async function stripeRequest(
  path: string,
  secretKey: string,
  body?: Record<string, string | number | boolean | undefined>,
  fetcher: Fetcher = fetch,
  method: "GET" | "POST" = "POST",
): Promise<StripePayload> {
  if (!secretKey.trim()) {
    throw new HttpsError("failed-precondition", "Stripe is not configured.");
  }
  const response = await fetcher(`https://api.stripe.com/v1/${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${secretKey}`,
      ...(method === "POST" ? {"Content-Type": "application/x-www-form-urlencoded"} : {}),
    },
    ...(method === "POST" ? {body: stripeForm(body ?? {})} : {}),
  });
  const payload = (await response.json().catch(() => ({}))) as Record<string, unknown>;
  if (!response.ok) {
    logger.warn("Stripe request failed", {
      path,
      status: response.status,
      type: (payload.error as Record<string, unknown> | undefined)?.type,
    });
    throw new HttpsError("internal", "Stripe request failed.");
  }
  return payload;
}

export function verifyStripeSignature(
  rawBody: Buffer,
  signatureHeader: string | undefined,
  webhookSecret: string,
  toleranceSeconds = 300,
): boolean {
  if (!signatureHeader || !webhookSecret.trim()) return false;
  const parts = Object.fromEntries(
    signatureHeader.split(",").map((part) => {
      const [key, value] = part.split("=");
      return [key, value];
    }),
  );
  const timestamp = Number(parts.t);
  const signature = parts.v1;
  if (!timestamp || !signature) return false;
  const age = Math.abs(Math.floor(Date.now() / 1000) - timestamp);
  if (age > toleranceSeconds) return false;
  const expected = crypto
    .createHmac("sha256", webhookSecret)
    .update(`${timestamp}.${rawBody.toString("utf8")}`)
    .digest("hex");
  const expectedBuffer = Buffer.from(expected, "hex");
  const signatureBuffer = Buffer.from(signature, "hex");
  if (expectedBuffer.length !== signatureBuffer.length) return false;
  return crypto.timingSafeEqual(expectedBuffer, signatureBuffer);
}

export const createParkPalSubscriptionCheckout = onCall(
  {
    region: "europe-west2",
    secrets: [
      STRIPE_SECRET_KEY,
      PARKPAL_STRIPE_MONTHLY_PRICE_ID,
      PARKPAL_STRIPE_BUSINESS_MONTHLY_PRICE_ID,
      PARKPAL_STRIPE_PRICE_IDS,
    ],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in to manage ParkPal billing.");
    }
    const planKey = String(request.data?.planKey ?? request.data?.planId ?? "parkpal_monthly").trim();
    const plan = planForKey(planKey);
    const userId = request.auth.uid;
    const email = request.auth.token.email ? String(request.auth.token.email) : undefined;
    const customerId = await ensureStripeCustomer(userId, email);
    const existing = await admin.firestore().collection(subscriptions).doc(userId).get();
    const existingData = existing.data() ?? {};
    if (
      activeSubscriptionStatuses.has(String(existingData.stripeStatus ?? existingData.status ?? "")) &&
      existingData.cancelAtPeriodEnd !== true
    ) {
      throw new HttpsError("already-exists", "This account already has an active ParkPal subscription.");
    }
    const baseUrl = appUrl();
    const session = await stripeRequest("checkout/sessions", process.env.STRIPE_SECRET_KEY ?? "", {
      mode: "subscription",
      customer: customerId,
      "line_items[0][price]": plan.stripePriceId,
      "line_items[0][quantity]": 1,
      success_url: `${baseUrl}/profile/payments/success`,
      cancel_url: `${baseUrl}/profile/payments/cancelled`,
      "metadata[parkpalUserId]": userId,
      "metadata[parkpalPlanKey]": plan.key,
      "metadata[environment]": process.env.GCLOUD_PROJECT ?? "parkpal-prod",
      "metadata[productScope]": "parking_intelligence_only",
      "subscription_data[metadata][parkpalUserId]": userId,
      "subscription_data[metadata][parkpalPlanKey]": plan.key,
      "subscription_data[metadata][productScope]": "parking_intelligence_only",
      allow_promotion_codes: true,
    });
    await auditPayment(userId, "checkout_session_created", {
      planKey: plan.key,
      sessionId: session.id,
      productDescription,
    });
    return {url: session.url, sessionId: session.id};
  },
);

export const createParkPalStripeCheckoutSession = createParkPalSubscriptionCheckout;

export const createParkPalBillingPortalSession = onCall(
  {
    region: "europe-west2",
    secrets: [STRIPE_SECRET_KEY],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in to manage ParkPal billing.");
    }
    const userId = request.auth.uid;
    const customerSnapshot = await admin.firestore().collection(paymentCustomers).doc(userId).get();
    const customerId = String(customerSnapshot.data()?.stripeCustomerId ?? customerSnapshot.data()?.providerCustomerId ?? "");
    if (!customerId) {
      throw new HttpsError("failed-precondition", "No Stripe customer exists for this account.");
    }
    const session = await stripeRequest("billing_portal/sessions", process.env.STRIPE_SECRET_KEY ?? "", {
      customer: customerId,
      return_url: `${appUrl()}/profile/payments`,
    });
    await auditPayment(userId, "billing_portal_created", {sessionId: session.id});
    return {url: session.url};
  },
);

export const createParkPalStripeBillingPortalSession = createParkPalBillingPortalSession;

export const getParkPalSubscription = onCall(
  {region: "europe-west2"},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in to view ParkPal billing.");
    }
    const snapshot = await admin.firestore().collection(subscriptions).doc(request.auth.uid).get();
    return {subscription: snapshot.exists ? safeSubscription(snapshot.data() ?? {}) : null};
  },
);

export const refreshParkPalSubscription = onCall(
  {
    region: "europe-west2",
    secrets: [STRIPE_SECRET_KEY],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in to refresh ParkPal billing.");
    }
    const snapshot = await admin.firestore().collection(subscriptions).doc(request.auth.uid).get();
    const subscriptionId = String(snapshot.data()?.stripeSubscriptionId ?? snapshot.data()?.providerSubscriptionId ?? "");
    if (!subscriptionId) return {subscription: null};
    const subscription = await stripeRequest(
      `subscriptions/${subscriptionId}`,
      process.env.STRIPE_SECRET_KEY ?? "",
      undefined,
      fetch,
      "GET",
    );
    await upsertSubscription(subscription);
    const refreshed = await admin.firestore().collection(subscriptions).doc(request.auth.uid).get();
    return {subscription: refreshed.exists ? safeSubscription(refreshed.data() ?? {}) : null};
  },
);

export const parkPalStripeWebhook = onRequest(
  {
    region: "europe-west2",
    secrets: [STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET, PARKPAL_STRIPE_MONTHLY_PRICE_ID, PARKPAL_STRIPE_BUSINESS_MONTHLY_PRICE_ID],
  },
  async (request, response) => {
    const rawBody = Buffer.isBuffer((request as unknown as {rawBody?: Buffer}).rawBody) ?
      (request as unknown as {rawBody: Buffer}).rawBody :
      Buffer.from(JSON.stringify(request.body ?? {}));
    if (
      !verifyStripeSignature(
        rawBody,
        request.header("stripe-signature"),
        process.env.STRIPE_WEBHOOK_SECRET ?? "",
      )
    ) {
      response.status(400).send("invalid_signature");
      return;
    }
    const event = JSON.parse(rawBody.toString("utf8")) as Record<string, unknown>;
    await handleStripeEvent(event);
    response.status(200).send("ok");
  },
);

async function ensureStripeCustomer(userId: string, email?: string): Promise<string> {
  const ref = admin.firestore().collection(paymentCustomers).doc(userId);
  const existing = await ref.get();
  const currentId = String(existing.data()?.stripeCustomerId ?? existing.data()?.providerCustomerId ?? "");
  if (currentId) return currentId;

  const customer = await stripeRequest("customers", process.env.STRIPE_SECRET_KEY ?? "", {
    email,
    "metadata[parkpalUserId]": userId,
    "metadata[productScope]": "parking_intelligence_only",
    description: "ParkPal software subscription customer",
  });
  const customerId = String(customer.id ?? "");
  if (!customerId) throw new HttpsError("internal", "Stripe customer was not created.");
  await ref.create({
    userId,
    email: email ?? null,
    provider: "stripe",
    stripeCustomerId: customerId,
    providerCustomerId: customerId,
    defaultCurrency: "GBP",
    billingCountry: "GB",
    status: "succeeded",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    metadata: {productScope: "parking_intelligence_only"},
  }).catch(async (error) => {
    if (String(error?.code ?? "") !== "already-exists" && Number(error?.code) !== 6) throw error;
  });
  const afterCreate = await ref.get();
  return String(afterCreate.data()?.stripeCustomerId ?? afterCreate.data()?.providerCustomerId ?? customerId);
}

async function handleStripeEvent(event: Record<string, unknown>): Promise<void> {
  const eventId = String(event.id ?? "");
  const type = String(event.type ?? "");
  if (!eventId || !type) return;
  const eventRef = admin.firestore().collection(paymentEvents).doc(eventId);
  const existing = await eventRef.get();
  if (existing.data()?.processed === true) return;
  const object = (event.data as Record<string, unknown> | undefined)?.object as
    | Record<string, unknown>
    | undefined;
  await eventRef.set(
    {
      eventId,
      eventType: type,
      type,
      provider: "stripe",
      objectId: object?.id ?? null,
      receivedAt: admin.firestore.FieldValue.serverTimestamp(),
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
      processed: true,
      productScope: "parking_intelligence_only",
    },
    {merge: true},
  );

  if (type === "checkout.session.completed" && object) {
    const subscriptionId = String(object.subscription ?? "");
    if (subscriptionId) {
      const subscription = await stripeRequest(
        `subscriptions/${subscriptionId}`,
        process.env.STRIPE_SECRET_KEY ?? "",
        undefined,
        fetch,
        "GET",
      );
      await upsertSubscription(subscription);
    }
  }
  if (type.startsWith("customer.subscription.") && object) {
    await upsertSubscription(object);
  }
  if (type === "invoice.paid" || type === "invoice.payment_failed") {
    await upsertInvoiceAndLedger(type, object);
  }
}

async function upsertSubscription(subscription: Record<string, unknown>): Promise<void> {
  const metadata = (subscription.metadata ?? {}) as Record<string, unknown>;
  const userId = String(metadata.parkpalUserId ?? metadata.userId ?? "");
  if (!userId) return;
  const stripeSubscriptionId = String(subscription.id ?? "");
  const status = stripeSubscriptionStatus(String(subscription.status ?? ""));
  const cancelAtPeriodEnd = subscription.cancel_at_period_end === true;
  const stripeCustomerId = String(subscription.customer ?? "");
  const price = (((subscription.items as Record<string, unknown> | undefined)?.data as unknown[])?.[0] ??
    {}) as Record<string, unknown>;
  const priceData = (price.price ?? {}) as Record<string, unknown>;
  const recurring = (priceData.recurring ?? {}) as Record<string, unknown>;
  const planKey = String(metadata.parkpalPlanKey ?? metadata.planId ?? planKeyForPrice(String(priceData.id ?? "")));
  await admin.firestore().collection(subscriptions).doc(userId).set(
    {
      userId,
      subscriptionId: userId,
      stripeCustomerId,
      provider: "stripe",
      providerSubscriptionId: stripeSubscriptionId,
      stripeSubscriptionId,
      stripePriceId: String(priceData.id ?? ""),
      stripeProductId: priceData.product ?? null,
      planKey,
      planId: planKey,
      status: cancelAtPeriodEnd && status === "active" ? "cancel_at_period_end" : status,
      stripeStatus: subscription.status ?? null,
      cancelAtPeriodEnd,
      currency: String(priceData.currency ?? "gbp").toUpperCase(),
      billingInterval: String(recurring.interval ?? "month"),
      priceMinor: Number(priceData.unit_amount ?? 0),
      currentPeriodStart: timestampFromSeconds(subscription.current_period_start),
      currentPeriodEnd: timestampFromSeconds(subscription.current_period_end),
      latestInvoiceId: subscription.latest_invoice ?? null,
      latestPaymentStatus: null,
      productScope: "parking_intelligence_only",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      metadata: {productDescription},
    },
    {merge: true},
  );
}

async function upsertInvoiceAndLedger(type: string, invoice?: Record<string, unknown>): Promise<void> {
  if (!invoice) return;
  const subscriptionId = String(invoice.subscription ?? "");
  const subscription = subscriptionId ?
    await stripeRequest(`subscriptions/${subscriptionId}`, process.env.STRIPE_SECRET_KEY ?? "", undefined, fetch, "GET")
      .catch(() => undefined) :
    undefined;
  const metadata = ((subscription?.metadata ?? invoice.metadata) ?? {}) as Record<string, unknown>;
  const userId = String(metadata.parkpalUserId ?? metadata.userId ?? "");
  const invoiceId = String(invoice.id ?? "");
  if (!invoiceId) return;
  const amountPaid = Number(invoice.amount_paid ?? invoice.amount_due ?? 0);
  const currency = String(invoice.currency ?? "gbp").toUpperCase();
  await admin.firestore().collection(invoices).doc(invoiceId).set(
    {
      invoiceId,
      userId: userId || null,
      provider: "stripe",
      status: type === "invoice.paid" ? "succeeded" : "failed",
      amountMinor: amountPaid,
      currency,
      hostedInvoiceUrl: invoice.hosted_invoice_url ?? null,
      invoicePdf: invoice.invoice_pdf ?? null,
      productScope: "parking_intelligence_only",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
  if (userId) {
    await admin.firestore().collection(paymentLedger).doc(`stripe_${invoiceId}`).set(
      {
        entryId: `stripe_${invoiceId}`,
        userId,
        type: "subscriptionCharge",
        status: type === "invoice.paid" ? "succeeded" : "failed",
        amountMinor: amountPaid,
        currency,
        reason: "ParkPal intelligence subscription",
        invoiceId,
        providerEventId: invoiceId,
        bookingId: null,
        reservationId: null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        metadata: {productScope: "parking_intelligence_only"},
      },
      {merge: true},
    );
    await admin.firestore().collection(subscriptions).doc(userId).set(
      {
        latestInvoiceId: invoiceId,
        latestPaymentStatus: type === "invoice.paid" ? "succeeded" : "failed",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
  }
}

function stripeSubscriptionStatus(status: string): string {
  switch (status) {
  case "trialing":
  case "active":
  case "past_due":
  case "unpaid":
  case "paused":
  case "incomplete":
  case "incomplete_expired":
    return status;
  case "canceled":
  case "cancelled":
    return "cancelled";
  default:
    return "none";
  }
}

function planKeyForPrice(priceId: string): string {
  const plan = resolveParkPalPlans().find((candidate) => candidate.stripePriceId === priceId);
  return plan?.key ?? "parkpal_monthly";
}

function appUrl(): string {
  return String(process.env.PARKPAL_APP_URL ?? process.env.PARKPAL_CUSTOMER_BASE_URL ?? "https://myparkpal.co.uk")
    .replace(/\/$/, "");
}

function timestampFromSeconds(value: unknown): admin.firestore.Timestamp | null {
  const seconds = Number(value ?? 0);
  if (!Number.isFinite(seconds) || seconds <= 0) return null;
  return admin.firestore.Timestamp.fromMillis(seconds * 1000);
}

function safeSubscription(data: admin.firestore.DocumentData): Record<string, unknown> {
  return {
    userId: data.userId ?? null,
    planKey: data.planKey ?? data.planId ?? "parkpal_monthly",
    planName: data.planName ?? null,
    status: data.status ?? "none",
    cancelAtPeriodEnd: data.cancelAtPeriodEnd === true,
    currentPeriodStart: data.currentPeriodStart ?? null,
    currentPeriodEnd: data.currentPeriodEnd ?? null,
    latestInvoiceId: data.latestInvoiceId ?? null,
    latestPaymentStatus: data.latestPaymentStatus ?? null,
    currency: data.currency ?? "GBP",
    priceMinor: Number(data.priceMinor ?? 0),
    productScope: "parking_intelligence_only",
  };
}

async function auditPayment(userId: string, action: string, metadata: Record<string, unknown>): Promise<void> {
  await admin.firestore().collection(paymentAudit).add({
    userId,
    action,
    metadata,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

export async function assertParkPalPaymentAdmin(uid: string): Promise<void> {
  const snapshot = await admin.firestore().collection(adminUsers).doc(uid).get();
  const data = snapshot.data();
  if (!snapshot.exists || data?.status !== "active" || !allowedRoles.has(String(data?.role ?? ""))) {
    throw new HttpsError("permission-denied", "This account is not authorised for ParkPal Admin.");
  }
}
