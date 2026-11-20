const test = require("node:test");
const assert = require("node:assert/strict");
const {createHash, createHmac} = require("node:crypto");
const {signRothRequest} = require("../lib/roth_integration");

test("ParkPal ROTH merchant signature matches the versioned canonical request", () => {
  const body = JSON.stringify({externalId: "parkpal-user-1"});
  const timestamp = "2026-11-20T12:00:00.000Z";
  const nonce = "test-nonce-1";
  const secret = "synthetic-test-secret";
  const hash = createHash("sha256").update(body).digest("hex");
  const expected = createHmac("sha256", secret)
    .update(["POST", "/v1/integration/balance", timestamp, nonce, hash].join("\n"))
    .digest("hex");
  assert.equal(signRothRequest("POST", "/v1/integration/balance", body, timestamp, nonce, secret), expected);
  assert.notEqual(signRothRequest("POST", "/v1/integration/balance", body + " ", timestamp, nonce, secret), expected);
});
