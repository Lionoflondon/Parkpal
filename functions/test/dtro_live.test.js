const test = require("node:test");
const assert = require("node:assert/strict");

const {
  DtroAuthService,
  fetchDtroRecords,
  firestoreWritePayload,
  loadDtroCredentialsFromEnv,
  normalizeDtroRecord,
  validateDtroCredentials,
} = require("../lib/dtro_live");

test("D-TRO credential missing is reported", () => {
  assert.deepEqual(validateDtroCredentials({}), [
    "credential_missing: DTRO_API_BASE_URL",
    "credential_missing: DTRO_API_KEY",
    "credential_missing: DTRO_API_SECRET",
  ]);
});

test("D-TRO API success fetches live records", async () => {
  const requests = [];
  const result = await fetchDtroRecords(
    {apiBaseUrl: "https://dtro.example/v1", apiKey: "key", apiSecret: "secret"},
    async (url, init = {}) => {
      requests.push({url, init});
      if (String(url).endsWith("/oauth-generator")) {
        return new Response(JSON.stringify({access_token: "token-1"}), {
          status: 200,
          headers: {"content-type": "application/json"},
        });
      }
      return new Response(
        JSON.stringify({trafficRegulationOrders: [{troId: "tro-1"}]}),
        {status: 200, headers: {"content-type": "application/json"}},
      );
    },
  );

  assert.equal(result.records.length, 1);
  assert.equal(result.httpStatus, 200);
  assert.equal(requests.length, 2);
  assert.equal(requests[0].url, "https://dtro.example/v1/oauth-generator");
  assert.equal(requests[0].init.method, "POST");
  assert.match(requests[0].init.headers.Authorization, /^Basic /);
  assert.equal(requests[0].init.headers["Content-Type"], "application/x-www-form-urlencoded");
  assert.equal(requests[0].init.body, "grant_type=client_credentials");
  assert.equal(requests[1].url, "https://dtro.example/v1/dtros/all");
  assert.equal(requests[1].init.headers.Authorization, "Bearer token-1");
  assert.equal(requests[1].init.headers["x-api-key"], undefined);
  assert.equal(requests[1].init.headers.apikey, undefined);
});

test("D-TRO token is cached and refreshed before expiry", async () => {
  const requests = [];
  let now = 1000;
  const auth = new DtroAuthService(
    {apiBaseUrl: "https://dtro.example/v1", apiKey: "key", apiSecret: "secret"},
    async (url) => {
      requests.push(String(url));
      return new Response(
        JSON.stringify({access_token: `token-${requests.length}`}),
        {status: 200, headers: {"content-type": "application/json"}},
      );
    },
    () => now,
  );

  assert.equal(await auth.getAccessToken(), "token-1");
  assert.equal(await auth.getAccessToken(), "token-1");
  now += 29 * 60 * 1000 + 1;
  assert.equal(await auth.getAccessToken(), "token-2");
  assert.equal(requests.length, 2);
});

test("D-TRO 401 clears token and retries original request once", async () => {
  const requests = [];
  const result = await fetchDtroRecords(
    {apiBaseUrl: "https://dtro.example/v1", apiKey: "key", apiSecret: "secret"},
    async (url, init = {}) => {
      requests.push({url: String(url), init});
      if (String(url).endsWith("/oauth-generator")) {
        return new Response(JSON.stringify({access_token: `token-${requests.length}`}), {
          status: 200,
          headers: {"content-type": "application/json"},
        });
      }
      if (requests.filter((request) => request.url === "https://dtro.example/v1/dtros/all").length === 1) {
        return new Response("expired", {status: 401});
      }
      return new Response(
        JSON.stringify({trafficRegulationOrders: [{troId: "tro-retry"}]}),
        {status: 200, headers: {"content-type": "application/json"}},
      );
    },
  );

  assert.equal(result.records[0].troId, "tro-retry");
  assert.equal(requests.filter((request) => request.url.endsWith("/oauth-generator")).length, 2);
  assert.equal(requests.filter((request) => request.url === "https://dtro.example/v1/dtros/all").length, 2);
});

test("D-TRO signed dataset URL is resolved after bearer request", async () => {
  const requests = [];
  const result = await fetchDtroRecords(
    {apiBaseUrl: "https://dtro.example/v1", apiKey: "key", apiSecret: "secret"},
    async (url, init = {}) => {
      requests.push({url: String(url), init});
      if (String(url).endsWith("/oauth-generator")) {
        return new Response(JSON.stringify({access_token: "token-1"}), {
          status: 200,
          headers: {"content-type": "application/json"},
        });
      }
      if (String(url).endsWith("/dtros/all")) {
        return new Response(JSON.stringify({url: "https://signed.example/dataset.csv"}), {
          status: 200,
          headers: {"content-type": "application/json"},
        });
      }
      return new Response("troId,provisionId,regulationType\ncsv-1,p1,kerbsideNoWaiting", {
        status: 200,
        headers: {"content-type": "text/csv"},
      });
    },
  );

  assert.equal(result.records.length, 1);
  assert.equal(result.records[0].troId, "csv-1");
  assert.equal(requests[1].url, "https://dtro.example/v1/dtros/all");
  assert.equal(requests[1].init.headers.Authorization, "Bearer token-1");
  assert.equal(requests[2].url, "https://signed.example/dataset.csv");
  assert.equal(requests[2].init.headers.Authorization, undefined);
  assert.equal(requests[2].init.headers.Range, "bytes=0-524287");
});

test("D-TRO CSV payload parses records", async () => {
  const result = await fetchDtroRecords(
    {apiBaseUrl: "https://dtro.example/v1", apiKey: "key", apiSecret: "secret"},
    async (url) => String(url).endsWith("/oauth-generator") ?
      new Response(JSON.stringify({access_token: "token-1"}), {
        status: 200,
        headers: {"content-type": "application/json"},
      }) :
      new Response("troId,provisionId,regulationType\ncsv-2,p2,kerbsideResidentParkingPlace", {
        status: 200,
        headers: {"content-type": "text/csv"},
      }),
  );

  assert.equal(result.records.length, 1);
  assert.equal(result.records[0].troId, "csv-2");
});

test("D-TRO live sync caps parsed records from large datasets", async () => {
  const rows = Array.from({length: 30}, (_, index) => `tro-${index},p${index},kerbsideNoWaiting`);
  const result = await fetchDtroRecords(
    {apiBaseUrl: "https://dtro.example/v1", apiKey: "key", apiSecret: "secret"},
    async (url) => String(url).endsWith("/oauth-generator") ?
      new Response(JSON.stringify({access_token: "token-1"}), {
        status: 200,
        headers: {"content-type": "application/json"},
      }) :
      new Response(`troId,provisionId,regulationType\n${rows.join("\n")}\n`, {
        status: 200,
        headers: {"content-type": "text/csv"},
      }),
  );

  assert.equal(result.records.length, 25);
  assert.equal(result.records[24].troId, "tro-24");
});

test("D-TRO API failure throws clear error", async () => {
  await assert.rejects(
    () =>
      fetchDtroRecords(
        {apiBaseUrl: "https://dtro.example/v1", apiKey: "key", apiSecret: "secret"},
        async (url) => String(url).endsWith("/oauth-generator") ?
          new Response(JSON.stringify({access_token: "token-1"}), {
            status: 200,
            headers: {"content-type": "application/json"},
          }) :
          new Response("Forbidden", {status: 403}),
      ),
    /dtro_api_failure: HTTP 403/,
  );
});

test("D-TRO credentials load from environment variables", () => {
  const credentials = loadDtroCredentialsFromEnv({
    DTRO_API_BASE_URL: "https://dft.dtro.gov.uk/v1",
    DTRO_API_KEY: "key",
    DTRO_API_SECRET: "secret",
  });

  assert.deepEqual(credentials, {
    apiBaseUrl: "https://dft.dtro.gov.uk/v1",
    apiKey: "key",
    apiSecret: "secret",
  });
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
  assert.equal(JSON.stringify(payload).includes("undefined"), false);
  assert.equal(payload.source.version, undefined);
});
