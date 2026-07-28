#!/usr/bin/env node

/**
 * Merge-only starter registry for ParkPal AIE v2.
 * Usage:
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/key.json node tools/seed_aie_v2_sources.js
 *
 * Does not delete or overwrite existing production source records.
 */
const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp({projectId: process.env.GCLOUD_PROJECT || "parkpal-prod"});
}

const db = admin.firestore();

const sources = [
  {
    councilId: "camden_westminster_parking_spaces_socrata",
    name: "Camden Open Data — Westminster Parking Spaces",
    sourceType: "socrata",
    baseUrl:
      "https://opendata.camden.gov.uk/dataset/Westminster-Parking-Spaces/2579-98vt",
    datasetId: "2579-98vt",
    datasetLabel: "Westminster Parking Spaces",
    license: "Verify before enabling",
    restrictionTypes: ["parking_bay"],
    active: false,
    priority: 100,
    refreshFrequency: "manual",
    notes:
      "Starter Socrata source. Dataset appears hosted by Camden but labelled Westminster Parking Spaces; verify ownership before enabling.",
  },
];

async function main() {
  for (const source of sources) {
    await db.collection("parkpal_councils").doc(source.councilId).set(
      {
        ...source,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
    console.log(`Merged ${source.councilId}`);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
