import {createHash} from "crypto";

export type CouncilSourceType =
  | "arcgis_featureserver"
  | "socrata"
  | "ckan"
  | "direct_csv"
  | "direct_json"
  | "pdf"
  | "manual"
  | "unverified";

export type RestrictionType =
  | "cpz"
  | "parking_bay"
  | "loading_bay"
  | "red_route"
  | "school_street"
  | "permit_zone"
  | "other";

export type GeoJsonGeometry = {
  type: string;
  coordinates: unknown;
};

export interface CouncilSource {
  councilId: string;
  name: string;
  sourceType: CouncilSourceType;
  baseUrl: string;
  datasetId?: string;
  layerIndex?: number;
  datasetLabel?: string;
  license?: string;
  restrictionTypes: RestrictionType[];
  fieldMapping?: Record<string, string>;
  active: boolean;
  priority?: number;
  refreshFrequency?: "daily" | "weekly" | "manual";
  notes?: string;
}

export interface NormalizedRecordDraft {
  councilId: string;
  councilName?: string;
  sourceFeatureId: string;
  sourceType: string;
  sourceUrl: string;
  resolvedUrl?: string;
  restrictionType: RestrictionType;
  geometry: GeoJsonGeometry | null;
  streetName?: string;
  zoneCode?: string;
  operatingHours?: string;
  permitZone?: string;
  restrictionText?: string;
  tariff?: string;
  status?: string;
  rawProperties: Record<string, unknown>;
  sourceUpdatedAt?: Date;
  needsReview: boolean;
  confidence: number;
}

export interface AdapterResult {
  records: NormalizedRecordDraft[];
  errors: string[];
  warnings: string[];
  diagnostics?: Record<string, unknown>;
}

export interface CouncilAdapter {
  sourceType: CouncilSourceType;
  fetch(source: CouncilSource): Promise<AdapterResult>;
}

export const userAgent = "ParkPal-AIE/2.0 (contact: ayojason600@gmail.com)";

export function stableHash(value: string): string {
  return createHash("sha256").update(value).digest("hex").slice(0, 32);
}

export function deterministicRestrictionId(
  councilId: string,
  sourceFeatureId: string,
  restrictionType: RestrictionType,
): string {
  return stableHash(`${councilId}|${sourceFeatureId}|${restrictionType}`);
}

export function fallbackSourceFeatureId(
  rowIndex: number,
  rawProperties: Record<string, unknown>,
): string {
  return `row_${rowIndex}_${stableHash(JSON.stringify(rawProperties))}`;
}

const aliases: Record<string, string> = {
  street: "streetName",
  street_name: "streetName",
  road_name: "streetName",
  cpz: "zoneCode",
  cpz_code: "zoneCode",
  zone: "zoneCode",
  zone_code: "zoneCode",
  hours: "operatingHours",
  operating_hours: "operatingHours",
  operating_times: "operatingHours",
  times: "operatingHours",
  restriction: "restrictionText",
  restriction_text: "restrictionText",
  description: "restrictionText",
  permit_zone: "permitZone",
  permit: "permitZone",
  zone_ref: "permitZone",
  lat: "latitude",
  latitude: "latitude",
  y: "latitude",
  lon: "longitude",
  lng: "longitude",
  longitude: "longitude",
  x: "longitude",
};

const supportedFields = new Set([
  "streetName",
  "zoneCode",
  "operatingHours",
  "permitZone",
  "restrictionText",
  "tariff",
  "status",
  "sourceUpdatedAt",
  "latitude",
  "longitude",
]);

export function applyFieldMapping(
  rawProps: Record<string, unknown>,
  fieldMapping?: Record<string, string>,
): Record<string, unknown> {
  const mapped: Record<string, unknown> = {};
  for (const [sourceField, value] of Object.entries(rawProps)) {
    const explicit = fieldMapping?.[sourceField];
    const alias = aliases[sourceField.toLowerCase()];
    const normalized = explicit ?? alias;
    if (normalized && supportedFields.has(normalized)) {
      mapped[normalized] = value;
    }
  }
  return mapped;
}

export function restrictionTypeFor(
  source: CouncilSource,
  rawProps: Record<string, unknown>,
): RestrictionType {
  if (source.restrictionTypes.length === 1) return source.restrictionTypes[0];
  const text = JSON.stringify(rawProps).toLowerCase();
  if (text.includes("loading")) return "loading_bay";
  if (text.includes("school")) return "school_street";
  if (text.includes("permit")) return "permit_zone";
  if (text.includes("red route")) return "red_route";
  if (text.includes("cpz") || text.includes("controlled parking")) return "cpz";
  if (text.includes("bay")) return "parking_bay";
  return source.restrictionTypes[0] ?? "other";
}

export function geometryFromMapped(
  mapped: Record<string, unknown>,
): GeoJsonGeometry | null {
  const lat = numberValue(mapped.latitude);
  const lon = numberValue(mapped.longitude);
  if (lat == null || lon == null) return null;
  if (lat < -90 || lat > 90 || lon < -180 || lon > 180) return null;
  return {type: "Point", coordinates: [lon, lat]};
}

export function validateDraft(
  draft: NormalizedRecordDraft,
  sourceType: CouncilSourceType,
): NormalizedRecordDraft {
  const hasDescriptor = Boolean(
    draft.restrictionText ||
      draft.operatingHours ||
      draft.zoneCode ||
      draft.permitZone,
  );
  const hasLocation = Boolean(draft.geometry || draft.streetName);
  const forcedReview = sourceType === "pdf";
  const needsReview =
    forcedReview || !draft.geometry || !draft.streetName || !hasDescriptor;
  const confidence = forcedReview
    ? Math.min(draft.confidence, 0.4)
    : draft.geometry && hasLocation && hasDescriptor
      ? Math.max(draft.confidence, 0.85)
      : hasLocation || hasDescriptor
        ? Math.min(Math.max(draft.confidence, 0.55), 0.75)
        : Math.min(draft.confidence, 0.5);
  return {...draft, needsReview, confidence};
}

export function normalizeRecord(
  source: CouncilSource,
  rawProps: Record<string, unknown>,
  options: {
    rowIndex: number;
    sourceFeatureId?: string;
    geometry?: GeoJsonGeometry | null;
    resolvedUrl?: string;
    pdf?: boolean;
  },
): NormalizedRecordDraft {
  const mapped = applyFieldMapping(rawProps, source.fieldMapping);
  const sourceFeatureId =
    options.sourceFeatureId ??
    stringValue(rawProps.id) ??
    stringValue(rawProps.objectid) ??
    stringValue(rawProps.OBJECTID) ??
    fallbackSourceFeatureId(options.rowIndex, rawProps);
  const geometry = options.geometry ?? geometryFromMapped(mapped);
  const draft: NormalizedRecordDraft = {
    councilId: source.councilId,
    councilName: source.name,
    sourceFeatureId,
    sourceType: source.sourceType,
    sourceUrl: source.baseUrl,
    resolvedUrl: options.resolvedUrl,
    restrictionType: restrictionTypeFor(source, rawProps),
    geometry,
    streetName: stringValue(mapped.streetName),
    zoneCode: stringValue(mapped.zoneCode),
    operatingHours: stringValue(mapped.operatingHours),
    permitZone: stringValue(mapped.permitZone),
    restrictionText: stringValue(mapped.restrictionText),
    tariff: stringValue(mapped.tariff),
    status: stringValue(mapped.status),
    rawProperties: rawProps,
    sourceUpdatedAt: dateValue(mapped.sourceUpdatedAt),
    needsReview: false,
    confidence: options.pdf ? 0.3 : 0.8,
  };
  return validateDraft(draft, options.pdf ? "pdf" : source.sourceType);
}

export function extractSocrataDatasetId(value: string): string | null {
  try {
    const url = new URL(value);
    const segments = url.pathname.split("/").filter(Boolean);
    const datasetIndex = segments.indexOf("dataset");
    if (datasetIndex >= 0) {
      const id = [...segments].reverse().find(looksLikeSocrataDatasetId);
      if (id) return id;
    }
    const resourceIndex = segments.indexOf("resource");
    if (resourceIndex >= 0 && segments[resourceIndex + 1]) {
      return segments[resourceIndex + 1].split(".")[0];
    }
    const viewsIndex = segments.indexOf("views");
    if (viewsIndex >= 0 && segments[viewsIndex + 1]) {
      return segments[viewsIndex + 1];
    }
  } catch {
    if (looksLikeSocrataDatasetId(value)) return value;
  }
  return looksLikeSocrataDatasetId(value) ? value : null;
}

export function socrataResourceUrl(
  baseUrl: string,
  datasetId?: string,
  offset = 0,
): string {
  const url = new URL(baseUrl);
  const id = datasetId ?? extractSocrataDatasetId(baseUrl);
  if (!id) throw new Error("Missing Socrata datasetId");
  return `${url.protocol}//${url.host}/resource/${id}.json?$limit=50000&$offset=${offset}`;
}

export function parseJsonRecords(body: string): Array<{
  properties: Record<string, unknown>;
  geometry: GeoJsonGeometry | null;
  id?: string;
}> {
  const decoded = JSON.parse(body) as unknown;
  const records = Array.isArray(decoded)
    ? decoded
    : isRecord(decoded) && Array.isArray(decoded.features)
      ? decoded.features
      : isRecord(decoded) && Array.isArray(decoded.records)
        ? decoded.records
        : isRecord(decoded) && Array.isArray(decoded.data)
          ? decoded.data
          : [];
  return records.filter(isRecord).map((record, index) => {
    const properties = isRecord(record.properties)
      ? record.properties
      : isRecord(record.attributes)
        ? record.attributes
        : record;
    const geometry = isGeometry(record.geometry) ? record.geometry : null;
    return {properties, geometry, id: stringValue(record.id) ?? `${index}`};
  });
}

export function parseCsvRows(body: string): {
  headers: string[];
  rows: Record<string, unknown>[];
} {
  const lines = body
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);
  if (lines.length === 0) return {headers: [], rows: []};
  const headers = splitCsvLine(lines[0]).map((header) => header.trim());
  const rows = lines.slice(1).map((line) => {
    const values = splitCsvLine(line);
    const row: Record<string, unknown> = {};
    headers.forEach((header, index) => {
      row[header] = values[index] ?? "";
    });
    return row;
  });
  return {headers, rows};
}

function splitCsvLine(line: string): string[] {
  const values: string[] = [];
  let current = "";
  let quoted = false;
  for (let index = 0; index < line.length; index++) {
    const char = line[index];
    if (char === '"' && line[index + 1] === '"') {
      current += '"';
      index++;
    } else if (char === '"') {
      quoted = !quoted;
    } else if (char === "," && !quoted) {
      values.push(current);
      current = "";
    } else {
      current += char;
    }
  }
  values.push(current);
  return values;
}

export function responsePreview(body: string): string {
  const cleaned = body.replace(/\s+/g, " ").trim();
  return cleaned.length > 300 ? cleaned.slice(0, 300) : cleaned;
}

function looksLikeSocrataDatasetId(value: string): boolean {
  return /^[a-z0-9]{4}-[a-z0-9]{4}$/i.test(value);
}

function numberValue(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string" && value.trim() !== "") {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function stringValue(value: unknown): string | undefined {
  if (value == null) return undefined;
  const text = String(value).trim();
  return text === "" ? undefined : text;
}

function dateValue(value: unknown): Date | undefined {
  if (!value) return undefined;
  const date = new Date(String(value));
  return Number.isNaN(date.getTime()) ? undefined : date;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isGeometry(value: unknown): value is GeoJsonGeometry {
  return isRecord(value) && typeof value.type === "string";
}
