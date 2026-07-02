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
  {
    councilId: "london_arcgis_placeholder",
    name: "London ArcGIS parking restrictions placeholder",
    sourceType: "arcgis_featureserver",
    baseUrl: "https://example.invalid/arcgis/rest/services/Parking/FeatureServer",
    layerIndex: 0,
    restrictionTypes: ["other"],
    active: false,
    priority: 500,
    refreshFrequency: "manual",
    notes: "Placeholder only — verify real ArcGIS endpoint before enabling.",
  },
  {
    councilId: "direct_csv_placeholder",
    name: "Direct CSV parking restrictions placeholder",
    sourceType: "direct_csv",
    baseUrl: "https://example.invalid/parking-restrictions.csv",
    restrictionTypes: ["other"],
    active: false,
    priority: 600,
    refreshFrequency: "manual",
    notes: "Placeholder only — verify CSV URL and field mapping before enabling.",
  },
  {
    councilId: "pdf_placeholder",
    name: "PDF TRO parking restrictions placeholder",
    sourceType: "pdf",
    baseUrl: "https://example.invalid/parking-order.pdf",
    restrictionTypes: ["other"],
    active: false,
    priority: 700,
    refreshFrequency: "manual",
    notes: "PDF imports are low confidence and always require review.",
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
