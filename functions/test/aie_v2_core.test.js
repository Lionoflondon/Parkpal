const test = require("node:test");
const assert = require("node:assert/strict");

const core = require("../lib/aie_v2_core");

const source = {
  councilId: "camden",
  name: "Camden Council",
  sourceType: "socrata",
  baseUrl: "https://opendata.camden.gov.uk/dataset/Westminster-Parking-Spaces/2579-98vt",
  restrictionTypes: ["parking_bay"],
  active: true,
};

test("applyFieldMapping maps explicit fields", () => {
  const mapped = core.applyFieldMapping(
    {CPZ_CODE: "CA-A", STREET_NAME: "Camden High Street"},
    {CPZ_CODE: "zoneCode", STREET_NAME: "streetName"},
  );
  assert.equal(mapped.zoneCode, "CA-A");
  assert.equal(mapped.streetName, "Camden High Street");
});

test("automatic alias mapping maps common source fields", () => {
  const mapped = core.applyFieldMapping({
    street_name: "Baker Street",
    operating_times: "08:30-18:30",
    lon: "-0.15",
    lat: "51.51",
  });
  assert.equal(mapped.streetName, "Baker Street");
  assert.equal(mapped.operatingHours, "08:30-18:30");
  assert.equal(mapped.longitude, "-0.15");
  assert.equal(mapped.latitude, "51.51");
});

test("deterministic restriction IDs are stable", () => {
  const first = core.deterministicRestrictionId("camden", "123", "parking_bay");
  const second = core.deterministicRestrictionId("camden", "123", "parking_bay");
  assert.equal(first, second);
});

test("sourceFeatureId fallback uses row index and raw hash", () => {
  const id = core.fallbackSourceFeatureId(7, {street: "Foo"});
  assert.match(id, /^row_7_[a-f0-9]{32}$/);
});

test("extracts Socrata dataset ID from landing URL", () => {
  assert.equal(
    core.extractSocrataDatasetId(
      "https://opendata.camden.gov.uk/dataset/Westminster-Parking-Spaces/2579-98vt",
    ),
    "2579-98vt",
  );
});

test("Direct JSON shape detection supports array", () => {
  const records = core.parseJsonRecords('[{"street":"A Road"}]');
  assert.equal(records.length, 1);
  assert.equal(records[0].properties.street, "A Road");
});

test("Direct JSON shape detection supports features array", () => {
  const records = core.parseJsonRecords('{"features":[{"properties":{"street":"B Road"}}]}');
  assert.equal(records.length, 1);
  assert.equal(records[0].properties.street, "B Road");
});

test("Direct JSON shape detection supports FeatureCollection geometry", () => {
  const records = core.parseJsonRecords(
    '{"type":"FeatureCollection","features":[{"properties":{"street":"C Road"},"geometry":{"type":"Point","coordinates":[-0.1,51.5]}}]}',
  );
  assert.equal(records.length, 1);
  assert.equal(records[0].geometry.type, "Point");
});

test("validation trusts structured data with geometry and fields", () => {
  const draft = core.normalizeRecord(
    source,
    {
      street: "High Street",
      restriction: "Permit parking",
      lon: "-0.12",
      lat: "51.5",
    },
    {rowIndex: 0},
  );
  assert.equal(draft.needsReview, false);
  assert.ok(draft.confidence >= 0.85);
});

test("validation marks missing geometry as needsReview", () => {
  const draft = core.normalizeRecord(
    source,
    {street: "High Street", restriction: "Permit parking"},
    {rowIndex: 0},
  );
  assert.equal(draft.needsReview, true);
});

test("PDF records always need review and low confidence", () => {
  const draft = core.normalizeRecord(
    {...source, sourceType: "pdf"},
    {restriction_text: "Parking suspension notice"},
    {rowIndex: 0, pdf: true},
  );
  assert.equal(draft.needsReview, true);
  assert.ok(draft.confidence <= 0.4);
});
