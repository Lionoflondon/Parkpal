import {createHash} from "crypto";

export interface DtroCredentials {
  apiBaseUrl?: string;
  apiKey?: string;
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

export function validateDtroCredentials(credentials: DtroCredentials): string[] {
  const failures: string[] = [];
  if (!credentials.apiBaseUrl?.trim()) failures.push("credential_missing: DTRO_API_BASE_URL");
  if (!credentials.apiKey?.trim()) failures.push("credential_missing: DTRO_API_KEY");
  return failures;
}

export async function fetchDtroRecords(
  credentials: DtroCredentials,
  fetcher: typeof fetch = fetch,
): Promise<{records: Record<string, unknown>[]; httpStatus?: number; contentType?: string; responseSize?: number}> {
  const failures = validateDtroCredentials(credentials);
  if (failures.length > 0) {
    throw new Error(failures.join("; "));
  }
  const response = await fetcher(credentials.apiBaseUrl!, {
    headers: {
      "Authorization": `Bearer ${credentials.apiKey}`,
      "Accept": "application/json",
      "User-Agent": "ParkPal-DTRO/1.0 (contact: ayojason600@gmail.com)",
    },
  });
  const body = await response.text();
  if (!response.ok) {
    throw new Error(`dtro_api_failure: HTTP ${response.status}: ${body.slice(0, 200)}`);
  }
  return {
    records: parseDtroRecordList(body),
    httpStatus: response.status,
    contentType: response.headers.get("content-type") ?? undefined,
    responseSize: body.length,
  };
}

export function parseDtroRecordList(body: string): Record<string, unknown>[] {
  const decoded = JSON.parse(body) as unknown;
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
  return {
    ...record,
    lastUpdatedAt: new Date().toISOString(),
  };
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

function stringValue(value: unknown): string | undefined {
  if (value == null) return undefined;
  const text = String(value).trim();
  return text === "" ? undefined : text;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
