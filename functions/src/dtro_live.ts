import {createHash} from "crypto";

const defaultDtroBaseUrl = "https://dft.dtro.gov.uk/v1";
const tokenRefreshSkewMs = 60_000;
const tokenLifetimeMs = 30 * 60_000;
const minimumRequestSpacingMs = 500;
const maxDtroDatasetBytes = 512 * 1024;
const maxDtroLiveRecords = 25;

let nextDtroRequestAt = 0;

export interface DtroCredentials {
  apiBaseUrl?: string;
  apiKey?: string;
  apiSecret?: string;
}

export interface DtroSyncResult {
  status: "success" | "failed";
  apiConnected: boolean;
  recordsFetched: number;
  recordsImported: number;
  failures: string[];
  lastSyncTime: string;
}

export interface DtroLegalPayload {
  id: string;
  troId: string;
  provisionId: string;
  authority: Record<string, unknown>;
  source: Record<string, unknown>;
  regulationType: string;
  irisLabel: string;
  irisExplanation: string;
  conditions: unknown[];
  geometry: unknown | null;
  confidence: number;
  verificationStatus: "pending" | "imported" | "verified" | "disputed" | "rejected";
  status: string;
  version?: string;
  rawProvision: Record<string, unknown>;
}

interface DtroToken {
  accessToken: string;
  expiresAtMs: number;
}

type DtroFetcher = typeof fetch;
type DtroClock = () => number;

export function loadDtroCredentialsFromEnv(env: NodeJS.ProcessEnv = process.env): DtroCredentials {
  return {
    apiBaseUrl: stringValue(env.DTRO_API_BASE_URL) ?? defaultDtroBaseUrl,
    apiKey: stringValue(env.DTRO_API_KEY),
    apiSecret: stringValue(env.DTRO_API_SECRET),
  };
}

export function validateDtroCredentials(credentials: DtroCredentials): string[] {
  const failures: string[] = [];
  if (!credentials.apiBaseUrl?.trim()) failures.push("credential_missing: DTRO_API_BASE_URL");
  if (!credentials.apiKey?.trim()) failures.push("credential_missing: DTRO_API_KEY");
  if (!credentials.apiSecret?.trim()) failures.push("credential_missing: DTRO_API_SECRET");
  return failures;
}

export class DtroAuthService {
  private cachedToken?: DtroToken;

  constructor(
    private readonly credentials: DtroCredentials = loadDtroCredentialsFromEnv(),
    private readonly fetcher: DtroFetcher = fetch,
    private readonly now: DtroClock = () => Date.now(),
  ) {}

  clearToken(): void {
    this.cachedToken = undefined;
  }

  async getAccessToken(): Promise<string> {
    const existing = this.cachedToken;
    if (existing && existing.expiresAtMs - tokenRefreshSkewMs > this.now()) {
      return existing.accessToken;
    }
    const token = await this.requestToken(existing ? "refreshed" : "requested");
    this.cachedToken = token;
    return token.accessToken;
  }

  private async requestToken(reason: "requested" | "refreshed"): Promise<DtroToken> {
    const failures = validateDtroCredentials(this.credentials);
    if (failures.length > 0) {
      throw new Error(failures.join("; "));
    }

    console.info(`D-TRO OAuth token ${reason}`);
    const tokenUrl = `${trimTrailingSlash(this.credentials.apiBaseUrl!)}/oauth-generator`;
    const basicAuth = Buffer.from(`${this.credentials.apiKey}:${this.credentials.apiSecret}`).toString("base64");
    const response = await rateLimitedFetch(this.fetcher, tokenUrl, {
      method: "POST",
      headers: {
        "Authorization": `Basic ${basicAuth}`,
        "Accept": "application/json",
        "Content-Type": "application/x-www-form-urlencoded",
        "User-Agent": "ParkPal-DTRO/1.0 (contact: ayojason600@gmail.com)",
      },
      body: new URLSearchParams({grant_type: "client_credentials"}).toString(),
    });
    const body = await response.text();
    if (!response.ok) {
      console.warn("D-TRO token request failed", {status: response.status});
      throw new Error(`dtro_token_failure: HTTP ${response.status}: ${body.slice(0, 200)}`);
    }
    const accessToken = parseAccessToken(body);
    if (!accessToken) {
      throw new Error("dtro_token_failure: access token missing from response");
    }
    return {
      accessToken,
      expiresAtMs: this.now() + tokenLifetimeMs,
    };
  }
}

export async function fetchDtroRecords(
  credentials: DtroCredentials = loadDtroCredentialsFromEnv(),
  fetcher: DtroFetcher = fetch,
  authService = new DtroAuthService(credentials, fetcher),
): Promise<{records: Record<string, unknown>[]; httpStatus?: number; contentType?: string; responseSize?: number}> {
  const failures = validateDtroCredentials(credentials);
  if (failures.length > 0) {
    throw new Error(failures.join("; "));
  }
  return fetchDtroRecordsWithRetry(credentials, fetcher, authService, false);
}

async function fetchDtroRecordsWithRetry(
  credentials: DtroCredentials,
  fetcher: DtroFetcher,
  authService: DtroAuthService,
  retried: boolean,
): Promise<{records: Record<string, unknown>[]; httpStatus?: number; contentType?: string; responseSize?: number}> {
  const accessToken = await authService.getAccessToken();
  const response = await rateLimitedFetch(fetcher, `${trimTrailingSlash(credentials.apiBaseUrl!)}/dtros/all`, {
    headers: {
      "Authorization": `Bearer ${accessToken}`,
      "Accept": "application/json",
      "User-Agent": "ParkPal-DTRO/1.0 (contact: ayojason600@gmail.com)",
    },
  });
  const body = await response.text();
  if (response.status === 401 && !retried) {
    console.warn("D-TRO request failed with status code", {status: response.status});
    console.info("D-TRO retry attempted");
    authService.clearToken();
    return fetchDtroRecordsWithRetry(credentials, fetcher, authService, true);
  }
  if (!response.ok) {
    console.warn("D-TRO request failed with status code", {status: response.status});
    throw new Error(`dtro_api_failure: HTTP ${response.status}: ${body.slice(0, 200)}`);
  }
  const recordsBody = await resolveDtroRecordsBody(body, fetcher);
  const records = parseDtroRecordList(recordsBody).slice(0, maxDtroLiveRecords);
  return {
    records,
    httpStatus: response.status,
    contentType: response.headers.get("content-type") ?? undefined,
    responseSize: recordsBody.length,
  };
}

async function resolveDtroRecordsBody(body: string, fetcher: DtroFetcher): Promise<string> {
  const signedUrl = parseSignedDatasetUrl(body);
  if (!signedUrl) return body;
  const response = await rateLimitedFetch(fetcher, signedUrl, {
    headers: {
      "Accept": "application/json,text/csv,*/*",
      "Range": `bytes=0-${maxDtroDatasetBytes - 1}`,
      "User-Agent": "ParkPal-DTRO/1.0 (contact: ayojason600@gmail.com)",
    },
  });
  const datasetBody = await response.text();
  if (!response.ok) {
    console.warn("D-TRO signed dataset request failed with status code", {status: response.status});
    throw new Error(`dtro_dataset_failure: HTTP ${response.status}: ${datasetBody.slice(0, 200)}`);
  }
  return datasetBody;
}

function parseSignedDatasetUrl(body: string): string | undefined {
  const text = body.trim();
  if (text.startsWith("http://") || text.startsWith("https://")) return text;
  try {
    const decoded = JSON.parse(text) as unknown;
    if (typeof decoded === "string") return decoded;
    if (isRecord(decoded)) {
      return stringValue(decoded.url) ??
        stringValue(decoded.signedUrl) ??
        stringValue(decoded.downloadUrl);
    }
  } catch (_) {
    return undefined;
  }
  return undefined;
}

async function rateLimitedFetch(fetcher: DtroFetcher, url: string, init?: RequestInit): Promise<Response> {
  const now = Date.now();
  const scheduledAt = Math.max(now, nextDtroRequestAt);
  nextDtroRequestAt = scheduledAt + minimumRequestSpacingMs;
  const waitMs = scheduledAt - now;
  if (waitMs > 0) {
    await new Promise((resolve) => setTimeout(resolve, waitMs));
  }
  return fetcher(url, init);
}

function parseAccessToken(body: string): string | undefined {
  const decoded = JSON.parse(body) as unknown;
  if (!isRecord(decoded)) return undefined;
  return stringValue(decoded.access_token) ??
    stringValue(decoded.accessToken) ??
    stringValue(decoded.token);
}

export function parseDtroRecordList(body: string): Record<string, unknown>[] {
  let decoded: unknown;
  try {
    decoded = JSON.parse(body) as unknown;
  } catch (_) {
    return parseCsvRecords(body);
  }
  const rows = Array.isArray(decoded)
    ? decoded
    : isRecord(decoded) && Array.isArray(decoded.records)
      ? decoded.records
      : isRecord(decoded) && Array.isArray(decoded.orders)
        ? decoded.orders
        : isRecord(decoded) && Array.isArray(decoded.trafficRegulationOrders)
          ? decoded.trafficRegulationOrders
          : isRecord(decoded)
            ? [decoded]
            : [];
  return rows.filter(isRecord);
}

function parseCsvRecords(body: string): Record<string, unknown>[] {
  const lines = body
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line !== "");
  if (lines.length < 2) return [];
  const headers = splitCsvLine(lines[0]).map((header) => header.trim()).filter((header) => header !== "");
  if (headers.length === 0) return [];
  return lines.slice(1).map((line) => {
    const values = splitCsvLine(line);
    return Object.fromEntries(headers.map((header, index) => [header, values[index] ?? ""]));
  });
}

function splitCsvLine(line: string): string[] {
  const values: string[] = [];
  let current = "";
  let inQuotes = false;
  for (let index = 0; index < line.length; index += 1) {
    const char = line[index];
    const next = line[index + 1];
    if (char === "\"" && inQuotes && next === "\"") {
      current += "\"";
      index += 1;
      continue;
    }
    if (char === "\"") {
      inQuotes = !inQuotes;
      continue;
    }
    if (char === "," && !inQuotes) {
      values.push(current.trim());
      current = "";
      continue;
    }
    current += char;
  }
  values.push(current.trim());
  return values;
}

export function normalizeDtroRecord(raw: Record<string, unknown>, rowIndex = 0): DtroLegalPayload[] {
  const troId = stringValue(raw.troId) ??
    stringValue(raw.id) ??
    stringValue(raw.orderId) ??
    `dtro_${rowIndex}_${stableHash(JSON.stringify(raw))}`;
  const authority = normalizeAuthority(raw.authority);
  const source = normalizeSource(raw.source, raw);
  const version = stringValue(raw.version) ?? stringValue(raw.versionId);
  const provisions = extractProvisions(raw);
  return provisions.map((provision, provisionIndex) => {
    const provisionId =
      stringValue(provision.provisionId) ??
      stringValue(provision.id) ??
      `provision_${provisionIndex}_${stableHash(JSON.stringify(provision))}`;
    const regulationType = stringValue(provision.regulationType) ??
      stringValue(provision.type) ??
      "other";
    return {
      id: `${troId}_${provisionId}`,
      troId,
      provisionId,
      authority,
      source,
      regulationType,
      irisLabel: irisLabelFor(regulationType),
      irisExplanation: irisExplanationFor(regulationType),
      conditions: Array.isArray(provision.conditions) ? provision.conditions : [],
      geometry: isRecord(provision.geometry) ? provision.geometry : null,
      confidence: 0.82,
      verificationStatus: "imported",
      status: stringValue(raw.status) ?? "active",
      version,
      rawProvision: provision,
    };
  });
}

export function firestoreWritePayload(record: DtroLegalPayload): Record<string, unknown> {
  return stripUndefined({
    ...record,
    lastUpdatedAt: new Date().toISOString(),
  }) as Record<string, unknown>;
}

function extractProvisions(raw: Record<string, unknown>): Record<string, unknown>[] {
  const candidate = raw.provisions ?? raw.Provisions ?? raw.provision;
  if (Array.isArray(candidate)) return candidate.filter(isRecord);
  if (isRecord(candidate)) return [candidate];
  return [raw];
}

function normalizeAuthority(value: unknown): Record<string, unknown> {
  if (isRecord(value)) {
    return {
      authorityId: stringValue(value.authorityId) ?? stringValue(value.id) ?? "",
      name: stringValue(value.name) ?? "Unknown authority",
      organisation: stringValue(value.organisation),
      reference: stringValue(value.reference),
    };
  }
  return {authorityId: "", name: "Unknown authority"};
}

function normalizeSource(value: unknown, raw: Record<string, unknown>): Record<string, unknown> {
  if (isRecord(value)) {
    return {
      sourceId: stringValue(value.sourceId) ?? stringValue(value.id) ?? "dtro-api",
      sourceUrl: stringValue(value.sourceUrl) ?? stringValue(value.url) ?? "",
      name: stringValue(value.name) ?? "D-TRO API",
      status: stringValue(value.status) ?? "active",
      version: stringValue(value.version),
    };
  }
  return {
    sourceId: "dtro-api",
    sourceUrl: stringValue(raw.sourceUrl) ?? "",
    name: "D-TRO API",
    status: stringValue(raw.status) ?? "active",
    version: stringValue(raw.version),
  };
}

function irisLabelFor(regulationType: string): string {
  switch (regulationType) {
    case "kerbsideNoWaiting":
      return "No waiting";
    case "kerbsideResidentParkingPlace":
      return "Resident permit holders only";
    default:
      return "D-TRO legal restriction";
  }
}

function irisExplanationFor(regulationType: string): string {
  switch (regulationType) {
    case "kerbsideNoWaiting":
      return "No waiting is allowed here.";
    case "kerbsideResidentParkingPlace":
      return "Resident permit holders only.";
    default:
      return "A D-TRO legal restriction applies. Check the source order.";
  }
}

function stableHash(value: string): string {
  return createHash("sha256").update(value).digest("hex").slice(0, 16);
}

function trimTrailingSlash(value: string): string {
  return value.replace(/\/+$/, "");
}

function stringValue(value: unknown): string | undefined {
  if (value == null) return undefined;
  const text = String(value).trim();
  return text === "" ? undefined : text;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function stripUndefined(value: unknown): unknown {
  if (Array.isArray(value)) {
    return value.map(stripUndefined);
  }
  if (!isRecord(value)) {
    return value;
  }
  return Object.fromEntries(
    Object.entries(value)
      .filter(([, entryValue]) => entryValue !== undefined)
      .map(([key, entryValue]) => [key, stripUndefined(entryValue)]),
  );
}
