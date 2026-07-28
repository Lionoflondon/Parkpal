#!/usr/bin/env node

/**
 * Merge-only importer for ParkPal London starter intelligence.
 *
 * Usage:
 *   node tools/import_london_seed.js --project parkpal-prod
 *
 * The importer does not delete existing records. It merges deterministic seed
 * documents into the target project so customer search/GPS flows have a small,
 * transparent starter dataset that can be upgraded by authoritative evidence.
 */

const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

let admin;
try {
  admin = require("firebase-admin");
} catch (_) {
  try {
    admin = require("../functions/node_modules/firebase-admin");
  } catch (_) {
    admin = null;
  }
}

const args = process.argv.slice(2);
const projectArgIndex = args.indexOf("--project");
const projectId =
  projectArgIndex >= 0 && args[projectArgIndex + 1]
    ? args[projectArgIndex + 1]
    : process.env.GCLOUD_PROJECT || "parkpal-prod";

const seedPath = path.join(__dirname, "..", "firebase", "seeds", "london_seed.json");
const seed = JSON.parse(fs.readFileSync(seedPath, "utf8"));

const idFields = {
  parkpal_councils: "councilId",
  parkpal_roads: "roadId",
  parkpal_zones: "zoneId",
  parkpal_signs: "signId",
  parkpal_atlas_intelligence_records: "recordId",
};

function convertValue(value) {
  if (Array.isArray(value)) return value.map(convertValue);
  if (value && typeof value === "object") {
    return Object.fromEntries(
      Object.entries(value).map(([key, item]) => [key, convertValue(item)]),
    );
  }
  if (
    typeof value === "string" &&
    /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/.test(value)
  ) {
    return admin.firestore.Timestamp.fromDate(new Date(value));
  }
  return value;
}

function firestoreRestValue(value) {
  if (value === null) return { nullValue: null };
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map(firestoreRestValue) } };
  }
  if (value && typeof value === "object") {
    return {
      mapValue: {
        fields: Object.fromEntries(
          Object.entries(value).map(([key, item]) => [
            key,
            firestoreRestValue(item),
          ]),
        ),
      },
    };
  }
  if (
    typeof value === "string" &&
    /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/.test(value)
  ) {
    return { timestampValue: value };
  }
  if (typeof value === "boolean") return { booleanValue: value };
  if (typeof value === "number") {
    return Number.isInteger(value)
      ? { integerValue: String(value) }
      : { doubleValue: value };
  }
  return { stringValue: String(value) };
}

function firebaseCliAccessToken() {
  const output = execFileSync("firebase", ["login:list", "--json"], {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "ignore"],
  });
  const parsed = JSON.parse(output);
  const token = parsed.result?.[0]?.tokens?.access_token;
  if (!token) throw new Error("No Firebase CLI access token available");
  return token;
}

async function importWithRest(recordsByCollection) {
  const accessToken = firebaseCliAccessToken();
  const writes = [];

  for (const [collection, records] of Object.entries(recordsByCollection)) {
    const idField = idFields[collection];
    if (!idField) throw new Error(`No id field configured for ${collection}`);
    if (!Array.isArray(records)) {
      throw new Error(`${collection} must contain an array of records`);
    }

    for (const record of records) {
      const id = record[idField];
      if (!id || typeof id !== "string") {
        throw new Error(`${collection} record missing ${idField}`);
      }
      writes.push({
        update: {
          name:
            `projects/${projectId}/databases/(default)/documents/` +
            `${collection}/${id}`,
          fields: Object.fromEntries(
            Object.entries(record).map(([key, value]) => [
              key,
              firestoreRestValue(value),
            ]),
          ),
        },
      });
    }
  }

  const response = await fetch(
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:commit`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ writes }),
    },
  );

  if (!response.ok) {
    const message = await response.text();
    throw new Error(`Firestore REST import failed: ${response.status} ${message}`);
  }

  for (const [collection, records] of Object.entries(recordsByCollection)) {
    const idField = idFields[collection];
    for (const record of records) {
      console.log(`Merged ${collection}/${record[idField]}`);
    }
  }

  return writes.length;
}

async function importWithAdmin(recordsByCollection) {
  if (!admin) throw new Error("firebase-admin is not installed");
  if (!admin.apps.length) {
    admin.initializeApp({ projectId });
  }
  const db = admin.firestore();
  let imported = 0;

  for (const [collection, records] of Object.entries(recordsByCollection)) {
    const idField = idFields[collection];
    if (!idField) throw new Error(`No id field configured for ${collection}`);
    if (!Array.isArray(records)) {
      throw new Error(`${collection} must contain an array of records`);
    }

    for (const record of records) {
      const id = record[idField];
      if (!id || typeof id !== "string") {
        throw new Error(`${collection} record missing ${idField}`);
      }

      await db
        .collection(collection)
        .doc(id)
        .set(convertValue(record), { merge: true });
      imported += 1;
      console.log(`Merged ${collection}/${id}`);
    }
  }

  return imported;
}

async function main() {
  console.log(`Importing ParkPal London starter data into ${projectId}`);
  let imported;
  try {
    imported = await importWithAdmin(seed);
  } catch (error) {
    console.warn(
      `Admin SDK import unavailable (${error.message}). Falling back to Firebase CLI REST import.`,
    );
    imported = await importWithRest(seed);
  }

  console.log(`Done. Imported/merged ${imported} records.`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
