import * as admin from "firebase-admin";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import * as crypto from "node:crypto";
import {parseParkPalRewardPolicy, ParkPalRewardProgram} from "./roth_reward_policy";

const ROTH_API_ORIGIN = defineSecret("ROTH_STAGING_API_ORIGIN");
const ROTH_MERCHANT_KEY_ID = defineSecret("ROTH_PARKPAL_MERCHANT_KEY_ID");
const ROTH_MERCHANT_SECRET = defineSecret("ROTH_PARKPAL_MERCHANT_SECRET");
const ROTH_REWARD_POLICY = defineSecret("PARKPAL_ROTH_REWARD_POLICY");
// The current ROTH staging API has no reward reversal endpoint. Keep automatic
// subscription issuance disabled until that central ledger capability is verified.
const ROTH_REWARD_REVERSALS_SUPPORTED = false;
const adminRoles = new Set(["superAdmin", "admin"]);

type Input = Record<string, unknown>;

function requireStaging(): string {
  const project = process.env.GCLOUD_PROJECT ?? "";
  const expectedProject = process.env.PARKPAL_STAGING_PROJECT_ID ?? "";
  if (process.env.PARKPAL_ENV !== "staging" || !project || project !== expectedProject
      || !/^parkpal-(staging|stg)(-[a-z0-9-]+)?$/.test(expectedProject)) {
    throw new HttpsError("failed-precondition", "ROTH integration is available only in the isolated ParkPal staging project.");
  }
  const origin = ROTH_API_ORIGIN.value();
  let parsed: URL;
  try { parsed = new URL(origin); } catch { throw new HttpsError("failed-precondition", "ROTH staging API origin is not configured."); }
  if (parsed.protocol !== "https:" || parsed.pathname !== "/" || parsed.search || parsed.hash || parsed.username || parsed.password || !parsed.hostname.endsWith("run.app")) {
    throw new HttpsError("failed-precondition", "ROTH API must use the pinned HTTPS staging service origin.");
  }
  return origin.replace(/\/$/, "");
}

export function signRothRequest(method: string, pathname: string, bodyText: string, timestamp: string, nonce: string, secret: string): string {
  const bodyHash = crypto.createHash("sha256").update(bodyText).digest("hex");
  const canonical = [method.toUpperCase(), pathname, timestamp, nonce, bodyHash].join("\n");
  return crypto.createHmac("sha256", secret).update(canonical).digest("hex");
}

async function requestRoth(action: string, body: Input): Promise<Input> {
  const origin = requireStaging();
  const keyId = ROTH_MERCHANT_KEY_ID.value();
  const secret = ROTH_MERCHANT_SECRET.value();
  if (!keyId || !secret) throw new HttpsError("failed-precondition", "Company-scoped ROTH credentials are not configured.");
  const pathname = `/v1/integration/${action}`;
  const bodyText = JSON.stringify(body);
  const timestamp = new Date().toISOString();
  const nonce = crypto.randomUUID();
  const signature = signRothRequest("POST", pathname, bodyText, timestamp, nonce, secret);
  let response: Response;
  try {
    response = await fetch(new URL(pathname, origin), {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-ROTH-Key-Id": keyId,
        "X-ROTH-Timestamp": timestamp,
        "X-ROTH-Nonce": nonce,
        "X-ROTH-Signature": signature,
      },
      body: bodyText,
      redirect: "error",
      signal: AbortSignal.timeout(8_000),
    });
  } catch {
    throw new HttpsError("unavailable", "ROTH staging could not be reached.");
  }
  const payload = await response.json().catch(() => ({})) as Input;
  if (!response.ok) {
    const code = String(payload.code ?? "");
    if (code === "identity_not_linked") throw new HttpsError("failed-precondition", "Link and approve this ParkPal account in ROTH first.");
    throw new HttpsError("unavailable", "ROTH did not accept the staging request.");
  }
  return payload;
}

async function requireAuth(uid: string | undefined): Promise<string> {
  if (!uid) throw new HttpsError("unauthenticated", "ParkPal sign-in is required.");
  requireStaging();
  return uid;
}

async function requireIssuer(uid: string | undefined, token: Record<string, unknown> | undefined): Promise<string> {
  const authenticated = await requireAuth(uid);
  const firebase = token?.firebase as Record<string, unknown> | undefined;
  const authAgeSeconds = Date.now() / 1000 - Number(token?.auth_time);
  if (token?.email_verified !== true || firebase?.sign_in_second_factor !== "totp"
      || !Number.isFinite(authAgeSeconds) || authAgeSeconds < 0 || authAgeSeconds > 300) {
    throw new HttpsError("permission-denied", "ParkPal reward issuance requires a verified email and fresh authenticator sign-in.");
  }
  const snapshot = await admin.firestore().collection("parkpalAdminUsers").doc(authenticated).get();
  const role = String(snapshot.data()?.role ?? "");
  if (!snapshot.exists || snapshot.data()?.status !== "active" || !adminRoles.has(role)) {
    throw new HttpsError("permission-denied", "Only an active ParkPal administrator may issue company rewards.");
  }
  return authenticated;
}

function externalId(uid: string): string {
  // Firebase UIDs use the ROTH merchant API's allowed opaque subject alphabet.
  if (!/^[A-Za-z0-9_:@.-]{1,160}$/.test(uid)) throw new HttpsError("invalid-argument", "The ParkPal account reference is invalid.");
  return uid;
}

async function audit(uid: string, action: string, result: Input): Promise<void> {
  await admin.firestore().collection("parkpalRothAudit").add({
    actorUid: uid,
    action,
    rothReference: String(result.journalId ?? result.reservationId ?? result.businessId ?? ""),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

const protectedOptions = {
  region: "europe-west2",
  enforceAppCheck: true,
  secrets: [ROTH_API_ORIGIN, ROTH_MERCHANT_KEY_ID, ROTH_MERCHANT_SECRET, ROTH_REWARD_POLICY],
};

export const createParkPalRothLink = onCall(protectedOptions, async (request) => {
  const uid = await requireAuth(request.auth?.uid);
  const result = await requestRoth("startLink", {externalId: externalId(uid)});
  await audit(uid, "roth.identity_link_requested", {businessId: "parkpal"});
  return result;
});

export const getParkPalRothBalance = onCall(protectedOptions, async (request) => {
  const uid = await requireAuth(request.auth?.uid);
  const result = await requestRoth("balance", {externalId: externalId(uid)});
  await audit(uid, "roth.wallet_viewed", {businessId: "parkpal"});
  return result;
});

export const issueParkPalRothReward = onCall(protectedOptions, async (request) => {
  const uid = await requireIssuer(request.auth?.uid, request.auth?.token as Record<string, unknown> | undefined);
  const customerUid = String(request.data?.customerUid ?? "");
  const rewardId = String(request.data?.rewardId ?? "");
  const campaignId = String(request.data?.campaignId ?? "");
  const program = String(request.data?.program ?? "") as ParkPalRewardProgram;
  const reason = String(request.data?.reason ?? "");
  if (!customerUid || !/^[A-Za-z0-9_:@.-]{1,160}$/.test(rewardId) || !campaignId || campaignId.length > 160
      || !reason || reason.length > 500 || !["subscription", "referral", "promotion"].includes(program)) {
    throw new HttpsError("invalid-argument", "Supply a linked customer, stable reward reference, configured reward programme, campaign and reason.");
  }
  const policy = parseParkPalRewardPolicy(ROTH_REWARD_POLICY.value());
  const programPolicy = policy.programs[program];
  if (!programPolicy.enabled || !programPolicy.approved || !programPolicy.amountPence || programPolicy.maxPerCustomer < 1) {
    throw new HttpsError("failed-precondition", "This ParkPal reward programme is disabled or has no approved value and issuance limit.");
  }
  if (program === "subscription" && (!policy.reversalsReady || !ROTH_REWARD_REVERSALS_SUPPORTED)) {
    throw new HttpsError("failed-precondition", "Subscription rewards remain disabled until ROTH supports and approves reward reversals for refunds and cancellations.");
  }
  const db = admin.firestore();
  const requestId = crypto.createHash("sha256").update(JSON.stringify(["parkpal-roth-reward-v1", rewardId])).digest("hex");
  const requestRef = db.collection("parkpalRothIssuanceRequests").doc(requestId);
  const eligibilityRef = db.collection("parkpalRewardEligibility").doc(`${program}_${rewardId}`);
  const usageRef = db.collection("parkpalRothRewardUsage").doc(`${customerUid}_${program}`);
  const amountPence = programPolicy.amountPence;
  const payloadHash = crypto.createHash("sha256").update(JSON.stringify([customerUid,campaignId,reason,program,amountPence])).digest("hex");
  const prior = await db.runTransaction(async (tx) => {
    const [snapshot, eligibilitySnapshot, usageSnapshot] = await tx.getAll(requestRef, eligibilityRef, usageRef);
    if (snapshot.exists) {
      const record = snapshot.data() ?? {};
      if (record.actorUid !== uid || record.payloadHash !== payloadHash) {
        throw new HttpsError("already-exists", "This reward reference was already used for a different issuance request.");
      }
      return record.status === "posted" ? record : null;
    }
    const eligibility = eligibilitySnapshot.data() ?? {};
    if (!eligibilitySnapshot.exists || eligibility.status !== "eligible" || eligibility.program !== program ||
        eligibility.customerUid !== customerUid || (program === "subscription" &&
        (eligibility.paymentVerified !== true || eligibility.paymentStatus !== "paid" || eligibility.refunded === true || eligibility.disputed === true || eligibility.cancelled === true))) {
      throw new HttpsError("failed-precondition", "A current, server-verified PARKPAL reward eligibility record is required.");
    }
    const usage = Number(usageSnapshot.data()?.lifetimeCount ?? 0);
    if (!Number.isSafeInteger(usage) || usage >= programPolicy.maxPerCustomer) {
      throw new HttpsError("resource-exhausted", "The configured customer issuance limit has been reached.");
    }
    tx.create(requestRef, {
      actorUid: uid,
      payloadHash,
      amountPence,
      program,
      campaignId,
      reason,
      status: "pending",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.set(usageRef, {lifetimeCount: usage + 1, program, customerUid, updatedAt: admin.firestore.FieldValue.serverTimestamp()}, {merge: true});
    tx.update(eligibilityRef, {status: "issuance_pending", issuanceRequestId: requestId, updatedAt: admin.firestore.FieldValue.serverTimestamp()});
    return null;
  });
  if (prior) return {journalId: prior.journalId, duplicate: true};
  const result = await requestRoth("reward", {
    externalId: externalId(customerUid),
    rewardId,
    campaignId,
    reason,
    amountPence: Number(amountPence),
  });
  await requestRef.update({status:"posted",journalId:String(result.journalId ?? ""),postedAt:admin.firestore.FieldValue.serverTimestamp()});
  await eligibilityRef.update({status:"issued",journalId:String(result.journalId ?? ""),issuedAt:admin.firestore.FieldValue.serverTimestamp()});
  await audit(uid, "roth.company_reward_issued", {journalId: result.journalId});
  return result;
});
