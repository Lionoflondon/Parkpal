const test = require("node:test");
const assert = require("node:assert/strict");

const {
  fetchDtroRecords,
  firestoreWritePayload,
  normalizeDtroRecord,
  validateDtroCredentials,
} = require("../lib/dtro_live");

test("D-TRO credential missing is reported", () => {
  assert.deepEqual(validateDtroCredentials({}), [
    "credential_missing: DTRO_API_BASE_URL",
    "credential_missing: DTRO_API_KEY",
  ]);
});

test("D-TRO API success fetches live records", async () => {
  const result = await fetchDtroRecords(
    {apiBaseUrl: "https://dtro.example/api", apiKey: "secret"},
    async () =>
      new Response(
        JSON.stringify({trafficRegulationOrders: [{troId: "tro-1"}]}),
        {status: 200, headers: {"content-type": "application/json"}},
      ),
  );

  assert.equal(result.records.length, 1);
  assert.equal(result.httpStatus, 200);
});

test("D-TRO API failure throws clear error", async () => {
  await assert.rejects(
    () =>
      fetchDtroRecords(
        {apiBaseUrl: "https://dtro.example/api", apiKey: "secret"},
        async () => new Response("Forbidden", {status: 403}),
      ),
    /dtro_api_failure: HTTP 403/,
  );
});

test("D-TRO normalization creates canonical legal record", () => {
  const records = normalizeDtroRecord({
    troId: "tro-1",
    authority: {authorityId: "camden", name: "Camden Council"},
    source: {sourceId: "dtro", sourceUrl: "https://dtro.example", name: "D-TRO"},
    version: "v1",
    provisions: [
      {
        provisionId: "p1",
        regulationType: "kerbsideNoWaiting",
        geometry: {type: "LineString", coordinates: [[-0.1, 51.5]]},
        conditions: [{timeValidity: {startTime: "08:30", endTime: "18:30"}}],
      },
    ],
  });

  assert.equal(records.length, 1);
  assert.equal(records[0].id, "tro-1_p1");
  assert.equal(records[0].regulationType, "kerbsideNoWaiting");
  assert.equal(records[0].irisExplanation, "No waiting is allowed here.");
  assert.equal(records[0].verificationStatus, "imported");
});

test("D-TRO Firestore write payload includes normalized fields", () => {
  const [record] = normalizeDtroRecord({
    troId: "tro-2",
    provisions: [{provisionId: "p2", regulationType: "kerbsideResidentParkingPlace"}],
  });
  const payload = firestoreWritePayload(record);

  assert.equal(payload.id, "tro-2_p2");
  assert.equal(payload.irisLabel, "Resident permit holders only");
  assert.equal(typeof payload.lastUpdatedAt, "string");
});
