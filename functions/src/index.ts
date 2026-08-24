import * as admin from "firebase-admin";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {logger} from "firebase-functions";
import {adapterFor} from "./aie_v2_adapters";
import {defineSecret} from "firebase-functions/params";
import {
  fetchDtroRecords,
  firestoreWritePayload,
  loadDtroCredentialsFromEnv,
  normalizeDtroRecord,
  validateDtroCredentials,
} from "./dtro_live";
import {
  CouncilSource,
  deterministicRestrictionId,
  NormalizedRecordDraft,
} from "./aie_v2_core";
import {RothFinanceService} from "./roth_finance";
import {settleApprovedMissionReward} from "./roth_mission_settlement";

export {
  createParkPalBillingPortalSession,
  createParkPalSubscriptionCheckout,
  createParkPalStripeBillingPortalSession,
  createParkPalStripeCheckoutSession,
  getParkPalSubscription,
  parkPalStripeWebhook,
  refreshParkPalSubscription,
} from "./stripe_payments";

admin.initializeApp();

const DTRO_API_BASE_URL = defineSecret("DTRO_API_BASE_URL");
const DTRO_API_KEY = defineSecret("DTRO_API_KEY");
const DTRO_API_SECRET = defineSecret("DTRO_API_SECRET");
const db = admin.firestore();
const councilsCollection = "parkpal_councils";
const restrictionsCollection = "parkpal_restrictions";
const runsCollection = "parkpal_aie_import_runs";
const requestsCollection = "parkpal_aie_import_requests";
const dtroRawOrdersCollection = "parkpal_dtro_raw_orders";
const dtroLegalRecordsCollection = "parkpal_dtro_legal_records";
const dtroSyncStatusCollection = "parkpal_dtro_sync_status";
const adminUsersCollection = "parkpalAdminUsers";
const allowedAdminRoles = new Set([
  "superAdmin",
  "admin",
  "support",
  "reviewer",
  "pioneerManager",
  "atlasManager",
]);
const roth = new RothFinanceService(db);

export const runParkPalAieIngestionJob = onSchedule(
  {
    schedule: "every day 03:20",
    timeZone: "Europe/London",
    region: "europe-west2",
  },
  async () => {
    const snapshot = await db
      .collection(councilsCollection)
      .where("active", "==", true)
      .orderBy("priority", "asc")
      .get();
    let processed = 0;
    let skipped = 0;
    let fetched = 0;
    let upserted = 0;
    let failedRecords = 0;
    let failedCouncils = 0;
    for (const doc of snapshot.docs) {
      const source = councilSourceFromDoc(doc.id, doc.data());
      if (source.sourceType === "manual" || source.sourceType === "unverified") {
        skipped++;
        await writeSkippedRun(source, "manual/unverified");
        continue;
      }
      const result = await importCouncil(source);
      processed++;
      fetched += result.recordsFetched;
      upserted += result.recordsUpserted;
      failedRecords += result.recordsFailed;
      if (result.status === "failed") failedCouncils++;
      await delay(300);
    }
    logger.info("ParkPal AIE v2 scheduled run complete", {
      processed,
      skipped,
      fetched,
      upserted,
      failedRecords,
      failedCouncils,
    });
  },
);

export const runParkPalAieCouncilIngestion = onCall(
  {region: "europe-west2"},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "ParkPal Admin sign-in is required.");
    }
    await assertParkPalAdmin(request.auth.uid);
    const councilId = String(request.data?.councilId ?? "").trim();
    if (!councilId) {
      throw new HttpsError("invalid-argument", "councilId is required.");
    }
    const snapshot = await db.collection(councilsCollection).doc(councilId).get();
    if (!snapshot.exists) {
      throw new HttpsError("not-found", `Council source ${councilId} not found.`);
    }
    const source = councilSourceFromDoc(snapshot.id, snapshot.data() ?? {});
    const result = await importCouncil(source);
    await db.collection(requestsCollection).add({
      councilId,
      runId: result.id,
      requestedBy: request.auth?.uid ?? "unknown",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return result;
  },
);

export const parkPalAdminCreditRoth = onCall(
  {region: "europe-west2", enforceAppCheck: false},
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Sign-in required.");
    await assertParkPalAdmin(request.auth.uid);
    const data = request.data ?? {};
    const userId = String(data.userId ?? "").trim();
    const amountRoth = Number(data.amountRoth);
    const reason = String(data.reason ?? "").trim();
    if (!userId || !reason || !Number.isSafeInteger(amountRoth) || amountRoth <= 0) throw new HttpsError("invalid-argument", "userId, positive integer amountRoth and reason are required.");
    try {
      const result = await roth.mutate({userId, amountRoth, type: "admin_credit", direction: "credit", sourceType: "admin", sourceId: request.auth.uid, idempotencyKey: `admin_credit:${request.auth.uid}:${userId}:${String(data.idempotencyKey ?? reason)}`, description: reason, createdBy: request.auth.uid, approvedBy: request.auth.uid, reason});
      await db.collection("parkpalPaymentAudit").add({action: "roth_admin_credit", actorUid: request.auth.uid, targetUid: userId, amountRoth, reason, ledgerId: result.entryId, createdAt: admin.firestore.FieldValue.serverTimestamp()});
      return result;
    } catch (error) { throw new HttpsError("failed-precondition", String(error)); }
  },
);

export const parkPalReconcileRoth = onCall(
  {region: "europe-west2", enforceAppCheck: false},
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Sign-in required.");
    await assertParkPalAdmin(request.auth.uid);
    const userId = String(request.data?.userId ?? "").trim();
    if (!userId) throw new HttpsError("invalid-argument", "userId is required.");
    return roth.reconcile(userId);
  },
);

export const parkPalSettleMissionReward = onCall({region: "europe-west2", enforceAppCheck: false}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign-in required.");
  await assertParkPalAdmin(request.auth.uid);
  try { return await settleApprovedMissionReward(db, roth, String(request.data?.missionId ?? ""), request.auth.uid); }
  catch (error) { throw new HttpsError("failed-precondition", String(error)); }
});

export const parkPalReverseRoth = onCall({region: "europe-west2", enforceAppCheck: false}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign-in required.");
  await assertParkPalAdmin(request.auth.uid);
  try { return await roth.reverse(String(request.data?.entryId ?? ""), request.auth.uid, String(request.data?.reason ?? "")); }
  catch (error) { throw new HttpsError("failed-precondition", String(error)); }
});

export const syncParkPalDtroLegalData = onCall(
  {
    region: "europe-west2",
    memory: "512MiB",
    secrets: [DTRO_API_BASE_URL, DTRO_API_KEY, DTRO_API_SECRET],
    enforceAppCheck: false,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "ParkPal Admin sign-in is required.");
    }
    await assertParkPalAdmin(request.auth.uid);
    if (!request.app) {
      logger.warn("D-TRO sync continuing without Firebase App Check for authenticated ParkPal Admin user.", {
        uid: request.auth.uid,
      });
    }
    const startedAt = new Date();
    const syncRef = db.collection(dtroSyncStatusCollection).doc("live");
    const credentials = loadDtroCredentialsFromEnv();
    logger.info("D-TRO sync credential presence check", {
      hasApiBaseUrl: Boolean(credentials.apiBaseUrl?.trim()),
      hasApiKey: Boolean(credentials.apiKey?.trim()),
      hasApiSecret: Boolean(credentials.apiSecret?.trim()),
    });
    const credentialFailures = validateDtroCredentials(credentials);
    if (credentialFailures.length > 0) {
      const responsePayload = {
        apiConnected: false,
        lastSyncTime: startedAt.toISOString(),
        recordsFetched: 0,
        recordsImported: 0,
        failures: credentialFailures,
        status: "failed",
      };
      await syncRef.set(
        {...responsePayload, lastSyncTime: admin.firestore.FieldValue.serverTimestamp()},
        {merge: true},
      );
      return responsePayload;
    }

    try {
      const response = await fetchDtroRecords(credentials);
      let imported = 0;
      const failures: string[] = [];
      for (const [index, raw] of response.records.entries()) {
        try {
          const legalRecords = normalizeDtroRecord(raw, index);
          const troId = legalRecords[0]?.troId ?? `dtro_${index}`;
          await db.collection(dtroRawOrdersCollection).doc(troId).set(
            {
              troId,
              rawDtroJson: raw,
              source: "live_dtro_api",
              storedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            {merge: true},
          );
          for (const record of legalRecords) {
            await db
              .collection(dtroLegalRecordsCollection)
              .doc(record.id)
              .set(
                {
                  ...firestoreWritePayload(record),
                  lastUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
                },
                {merge: true},
              );
            imported++;
          }
        } catch (error) {
          failures.push(`normalization/write failed for row ${index}: ${String(error)}`);
        }
      }
      const status = failures.length > 0 ? "partial_success" : "success";
      const responsePayload = {
        apiConnected: true,
        lastSyncTime: startedAt.toISOString(),
        recordsFetched: response.records.length,
        recordsImported: imported,
        failures,
        status,
        httpStatus: response.httpStatus,
        contentType: response.contentType,
        responseSize: response.responseSize,
      };
      await syncRef.set(
        {...responsePayload, lastSyncTime: admin.firestore.FieldValue.serverTimestamp()},
        {merge: true},
      );
      return responsePayload;
    } catch (error) {
      const failures = [String(error)];
      const responsePayload = {
        apiConnected: false,
        lastSyncTime: startedAt.toISOString(),
        recordsFetched: 0,
        recordsImported: 0,
        failures,
        status: "failed",
      };
      await syncRef.set(
        {...responsePayload, lastSyncTime: admin.firestore.FieldValue.serverTimestamp()},
        {merge: true},
      );
      return responsePayload;
    }
  },
);

async function assertParkPalAdmin(uid: string): Promise<void> {
  const snapshot = await db.collection(adminUsersCollection).doc(uid).get();
  const data = snapshot.data();
  const role = String(data?.role ?? "");
  const status = String(data?.status ?? "");
  if (!snapshot.exists || status !== "active" || !allowedAdminRoles.has(role)) {
    throw new HttpsError("permission-denied", "This account is not authorised for ParkPal Admin.");
  }
}

async function importCouncil(source: CouncilSource): Promise<{
  id: string;
  status: string;
  recordsFetched: number;
  recordsUpserted: number;
  recordsFailed: number;
  recordsSkipped: number;
}> {
  const runRef = db.collection(runsCollection).doc();
  const runId = runRef.id;
  const startedAt = admin.firestore.FieldValue.serverTimestamp();
  await runRef.set({
    id: runId,
    councilId: source.councilId,
    councilName: source.name,
    sourceType: source.sourceType,
    originalUrl: source.baseUrl,
    startedAt,
    status: "skipped",
    recordsFetched: 0,
    recordsUpserted: 0,
    recordsFailed: 0,
    recordsSkipped: 0,
    errors: [],
    warnings: [],
  });

  if (!source.active || source.sourceType === "manual" || source.sourceType === "unverified") {
    await runRef.set(
      {
        finishedAt: admin.firestore.FieldValue.serverTimestamp(),
        status: "skipped",
        connectorUsed: "SkippedAdapter",
        warnings: ["Source inactive, manual, or unverified."],
      },
      {merge: true},
    );
    return {id: runId, status: "skipped", recordsFetched: 0, recordsUpserted: 0, recordsFailed: 0, recordsSkipped: 1};
  }

  try {
    const adapter = adapterFor(source);
    const result = await adapter.fetch(source);
    let upserted = 0;
    let failed = 0;
    let skipped = 0;
    for (const record of result.records) {
      try {
        await upsertRestriction(record);
        upserted++;
      } catch (error) {
        failed++;
        result.errors.push(`Persistence failed for ${record.sourceFeatureId}: ${String(error)}`);
      }
    }
    const status =
      result.errors.length > 0 && upserted === 0
        ? "failed"
        : result.errors.length > 0 || failed > 0
          ? "partial_success"
          : "success";
    const diagnostics = result.diagnostics ?? {};
    await runRef.set(
      {
        finishedAt: admin.firestore.FieldValue.serverTimestamp(),
        status,
        resolvedUrl: diagnostics.resolvedUrl,
        connectorUsed: diagnostics.connectorUsed ?? adapter.sourceType,
        httpStatus: diagnostics.httpStatus,
        contentType: diagnostics.contentType,
        responseSize: diagnostics.responseSize,
        responsePreview: diagnostics.responsePreview,
        availableColumns: diagnostics.availableColumns,
        selectedFormat: diagnostics.selectedFormat,
        recordsFetched: result.records.length,
        recordsUpserted: upserted,
        recordsFailed: failed,
        recordsSkipped: skipped,
        errors: result.errors,
        warnings: result.warnings,
        failureStage: status === "failed" ? "parser_execution" : null,
      },
      {merge: true},
    );
    await updateCouncilAfterRun(source.councilId, runId, status, result.errors[0]);
    return {id: runId, status, recordsFetched: result.records.length, recordsUpserted: upserted, recordsFailed: failed, recordsSkipped: skipped};
  } catch (error) {
    const message = String(error);
    await runRef.set(
      {
        finishedAt: admin.firestore.FieldValue.serverTimestamp(),
        status: "failed",
        failureStage: "unknown",
        recordsFailed: 1,
        errors: [message],
      },
      {merge: true},
    );
    await updateCouncilAfterRun(source.councilId, runId, "failed", message);
    return {id: runId, status: "failed", recordsFetched: 0, recordsUpserted: 0, recordsFailed: 1, recordsSkipped: 0};
  }
}

async function upsertRestriction(record: NormalizedRecordDraft): Promise<void> {
  const id = deterministicRestrictionId(
    record.councilId,
    record.sourceFeatureId,
    record.restrictionType,
  );
  await db.collection(restrictionsCollection).doc(id).set(
    {
      id,
      ...record,
      ingestedAt: admin.firestore.FieldValue.serverTimestamp(),
      sourceUpdatedAt: record.sourceUpdatedAt
        ? admin.firestore.Timestamp.fromDate(record.sourceUpdatedAt)
        : null,
    },
    {merge: true},
  );
}

async function updateCouncilAfterRun(
  councilId: string,
  runId: string,
  status: string,
  error?: string,
): Promise<void> {
  await db.collection(councilsCollection).doc(councilId).set(
    {
      lastCheckedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastSuccessAt:
        status === "success" || status === "partial_success"
          ? admin.firestore.FieldValue.serverTimestamp()
          : null,
      lastError: error ?? null,
      lastImportRunId: runId,
    },
    {merge: true},
  );
}

async function writeSkippedRun(source: CouncilSource, reason: string): Promise<void> {
  await db.collection(runsCollection).add({
    councilId: source.councilId,
    councilName: source.name,
    sourceType: source.sourceType,
    originalUrl: source.baseUrl,
    startedAt: admin.firestore.FieldValue.serverTimestamp(),
    finishedAt: admin.firestore.FieldValue.serverTimestamp(),
    status: "skipped",
    recordsFetched: 0,
    recordsUpserted: 0,
    recordsFailed: 0,
    recordsSkipped: 1,
    errors: [],
    warnings: [reason],
  });
}

function councilSourceFromDoc(id: string, data: admin.firestore.DocumentData): CouncilSource {
  return {
    councilId: String(data.councilId ?? id),
    name: String(data.name ?? data.councilName ?? id),
    sourceType: String(data.sourceType ?? "unverified") as CouncilSource["sourceType"],
    baseUrl: String(data.baseUrl ?? data.sourceUrl ?? ""),
    datasetId: data.datasetId ? String(data.datasetId) : undefined,
    layerIndex: typeof data.layerIndex === "number" ? data.layerIndex : undefined,
    datasetLabel: data.datasetLabel ? String(data.datasetLabel) : undefined,
    license: data.license ? String(data.license) : undefined,
    restrictionTypes: Array.isArray(data.restrictionTypes) && data.restrictionTypes.length > 0
      ? data.restrictionTypes
      : ["other"],
    fieldMapping: data.fieldMapping && typeof data.fieldMapping === "object"
      ? data.fieldMapping
      : undefined,
    active: data.active === true,
    priority: typeof data.priority === "number" ? data.priority : 999,
    refreshFrequency: data.refreshFrequency,
    notes: data.notes,
  };
}

function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
