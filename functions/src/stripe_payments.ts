import * as admin from "firebase-admin";
import * as crypto from "crypto";
import {HttpsError, onCall, onRequest} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import {logger} from "firebase-functions";

const STRIPE_SECRET_KEY = defineSecret("STRIPE_SECRET_KEY");
const STRIPE_WEBHOOK_SECRET = defineSecret("STRIPE_WEBHOOK_SECRET");
const PARKPAL_STRIPE_PRICE_IDS = defineSecret("PARKPAL_STRIPE_PRICE_IDS");

const paymentCustomers = "parkpalPaymentCustomers";
const subscriptions = "parkpalSubscriptions";
const invoices = "parkpalInvoices";
const paymentEvents = "parkpalPaymentEvents";
const paymentLedger = "parkpalPaymentLedger";
const paymentAudit = "parkpalPaymentAudit";
const adminUsers = "parkpalAdminUsers";
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

export function assertParkingIntelligencePlan(planId: string): void {
  if (!/^[a-z0-9_:-]+$/i.test(planId)) {
    throw new HttpsError("invalid-argument", "Invalid planId.");
  }
  const forbidden = ["booking", "reservation", "space", "carpark", "car_park"];
  if (forbidden.some((value) => planId.toLowerCase().includes(value))) {
    throw new HttpsError(
      "invalid-argument",
      "ParkPal payments are for parking intelligence only.",
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
  body: Record<string, string | number | boolean | undefined>,
  fetcher: Fetcher = fetch,
): Promise<StripePayload> {
  if (!secretKey.trim()) {
    throw new HttpsError("failed-precondition", "Stripe is not configured.");
  }
  const response = await fetcher(`https://api.stripe.com/v1/${path}`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${secretKey}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: stripeForm(body),
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

export const createParkPalStripeCheckoutSession = onCall(
  {
    region: "europe-west2",
    secrets: [STRIPE_SECRET_KEY, PARKPAL_STRIPE_PRICE_IDS],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in to manage ParkPal billing.");
    }
    const planId = String(request.data?.planId ?? "parkpal_plus").trim();
    assertParkingIntelligencePlan(planId);
    const priceIds = parseStripePriceConfig(process.env.PARKPAL_STRIPE_PRICE_IDS);
    const priceId = priceIds[planId];
    if (!priceId) {
      throw new HttpsError("failed-precondition", "Stripe plan is not configured.");
    }
    const baseUrl = String(
      request.data?.returnBaseUrl ?? process.env.PARKPAL_CUSTOMER_BASE_URL ?? "https://myparkpal.co.uk",
    );
    const successUrl = `${baseUrl.replace(/\/$/, "")}/account?billing=success`;
    const cancelUrl = `${baseUrl.replace(/\/$/, "")}/account?billing=cancelled`;
    const userId = request.auth.uid;
    const email = request.auth.token.email ? String(request.auth.token.email) : undefined;
    const customerId = await ensureStripeCustomer(userId, email);
    const session = await stripeRequest("checkout/sessions", process.env.STRIPE_SECRET_KEY ?? "", {
      mode: "subscription",
      customer: customerId,
      "line_items[0][price]": priceId,
      "line_items[0][quantity]": 1,
      success_url: successUrl,
      cancel_url: cancelUrl,
      "metadata[userId]": userId,
      "metadata[planId]": planId,
      "metadata[productScope]": "parking_intelligence_only",
      "subscription_data[metadata][userId]": userId,
      "subscription_data[metadata][planId]": planId,
      "subscription_data[metadata][productScope]": "parking_intelligence_only",
      allow_promotion_codes: true,
    });
    await auditPayment(userId, "checkout_session_created", {
      planId,
      sessionId: session.id,
    });
    return {url: session.url, sessionId: session.id};
  },
);

export const createParkPalStripeBillingPortalSession = onCall(
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
    const customerId = String(customerSnapshot.data()?.providerCustomerId ?? "");
    if (!customerId) {
      throw new HttpsError("failed-precondition", "No Stripe customer exists for this account.");
    }
    const baseUrl = String(
      request.data?.returnBaseUrl ?? process.env.PARKPAL_CUSTOMER_BASE_URL ?? "https://myparkpal.co.uk",
    );
    const session = await stripeRequest("billing_portal/sessions", process.env.STRIPE_SECRET_KEY ?? "", {
      customer: customerId,
      return_url: `${baseUrl.replace(/\/$/, "")}/account`,
    });
    await auditPayment(userId, "billing_portal_created", {sessionId: session.id});
    return {url: session.url};
  },
);

export const parkPalStripeWebhook = onRequest(
  {
    region: "europe-west2",
    secrets: [STRIPE_WEBHOOK_SECRET],
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
  const currentId = String(existing.data()?.providerCustomerId ?? "");
  if (currentId) return currentId;

  const customer = await stripeRequest("customers", process.env.STRIPE_SECRET_KEY ?? "", {
    email,
    "metadata[userId]": userId,
    "metadata[productScope]": "parking_intelligence_only",
  });
  const customerId = String(customer.id ?? "");
  if (!customerId) throw new HttpsError("internal", "Stripe customer was not created.");
  await ref.set(
    {
      userId,
      email: email ?? null,
      provider: "stripe",
      providerCustomerId: customerId,
      defaultCurrency: "GBP",
      billingCountry: "GB",
      status: "succeeded",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      metadata: {productScope: "parking_intelligence_only"},
    },
    {merge: true},
  );
  return customerId;
}

async function handleStripeEvent(event: Record<string, unknown>): Promise<void> {
  const eventId = String(event.id ?? "");
  const type = String(event.type ?? "");
  if (!eventId || !type) return;
  const object = (event.data as Record<string, unknown> | undefined)?.object as
    | Record<string, unknown>
    | undefined;
  const userId = String(object?.metadata && (object.metadata as Record<string, unknown>).userId || "");
  await admin.firestore().collection(paymentEvents).doc(eventId).set(
    {
      eventId,
      type,
      provider: "stripe",
      userId: userId || null,
      receivedAt: admin.firestore.FieldValue.serverTimestamp(),
      processed: true,
      productScope: "parking_intelligence_only",
    },
    {merge: true},
  );

  if (type.startsWith("customer.subscription.") && object) {
    await upsertSubscription(object);
  }
  if (type === "invoice.paid" || type === "invoice.payment_failed") {
    await upsertInvoiceAndLedger(type, object);
  }
}

async function upsertSubscription(subscription: Record<string, unknown>): Promise<void> {
  const metadata = (subscription.metadata ?? {}) as Record<string, unknown>;
  const userId = String(metadata.userId ?? "");
  if (!userId) return;
  const providerSubscriptionId = String(subscription.id ?? "");
  const status = stripeSubscriptionStatus(String(subscription.status ?? ""));
  const price = (((subscription.items as Record<string, unknown> | undefined)?.data as unknown[])?.[0] ??
    {}) as Record<string, unknown>;
  const priceData = (price.price ?? {}) as Record<string, unknown>;
  await admin.firestore().collection(subscriptions).doc(userId).set(
    {
      subscriptionId: userId,
      userId,
      planId: String(metadata.planId ?? "parkpal_plus"),
      status,
      provider: "stripe",
      providerSubscriptionId,
      currency: String(priceData.currency ?? "gbp").toUpperCase(),
      priceMinor: Number(priceData.unit_amount ?? 0),
      productScope: "parking_intelligence_only",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      metadata: {
        stripeStatus: subscription.status ?? null,
      },
    },
    {merge: true},
  );
}

async function upsertInvoiceAndLedger(type: string, invoice?: Record<string, unknown>): Promise<void> {
  if (!invoice) return;
  const metadata = (invoice.metadata ?? {}) as Record<string, unknown>;
  const userId = String(metadata.userId ?? "");
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
  }
}

function stripeSubscriptionStatus(status: string): string {
  switch (status) {
  case "trialing":
    return "trialing";
  case "active":
    return "active";
  case "past_due":
    return "pastDue";
  case "paused":
    return "paused";
  case "canceled":
  case "cancelled":
    return "cancelled";
  default:
    return "none";
  }
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
