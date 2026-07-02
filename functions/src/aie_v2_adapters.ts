import {
  AdapterResult,
  CouncilAdapter,
  CouncilSource,
  GeoJsonGeometry,
  normalizeRecord,
  parseCsvRows,
  parseJsonRecords,
  responsePreview,
  socrataResourceUrl,
  userAgent,
} from "./aie_v2_core";

type FetchLike = typeof fetch;

export class SocrataAdapter implements CouncilAdapter {
  sourceType = "socrata" as const;

  constructor(private readonly fetcher: FetchLike = fetch) {}

  async fetch(source: CouncilSource): Promise<AdapterResult> {
    const records: AdapterResult["records"] = [];
    const errors: string[] = [];
    const warnings: string[] = [];
    const diagnostics: Record<string, unknown> = {
      connectorUsed: "SocrataAdapter",
      selectedFormat: "json",
    };
    let offset = 0;
    let resolvedUrl = "";
    try {
      while (true) {
        resolvedUrl = socrataResourceUrl(source.baseUrl, source.datasetId, offset);
        const headers: Record<string, string> = {"User-Agent": userAgent};
        if (process.env.SOCRATA_APP_TOKEN) {
          headers["X-App-Token"] = process.env.SOCRATA_APP_TOKEN;
        }
        const response = await this.fetcher(resolvedUrl, {headers});
        const body = await response.text();
        diagnostics.resolvedUrl = resolvedUrl;
        diagnostics.httpStatus = response.status;
        diagnostics.contentType = response.headers.get("content-type") ?? undefined;
        diagnostics.responseSize = body.length;
        diagnostics.responsePreview = responsePreview(body);
        if (!response.ok) {
          errors.push(`HTTP ${response.status} from Socrata.`);
          break;
        }
        const parsed = parseJsonRecords(body);
        if (parsed.length === 0) break;
        diagnostics.availableColumns = Object.keys(parsed[0].properties);
        parsed.forEach((row, index) => {
          records.push(
            normalizeRecord(source, row.properties, {
              rowIndex: offset + index,
              sourceFeatureId: row.id,
              geometry: row.geometry,
              resolvedUrl,
            }),
          );
        });
        if (parsed.length < 50000) break;
        offset += 50000;
      }
    } catch (error) {
      errors.push(`Socrata parser failed: ${String(error)}`);
    }
    return {records, errors, warnings, diagnostics};
  }
}

export class ArcGisFeatureServerAdapter implements CouncilAdapter {
  sourceType = "arcgis_featureserver" as const;

  constructor(private readonly fetcher: FetchLike = fetch) {}

  async fetch(source: CouncilSource): Promise<AdapterResult> {
    const records: AdapterResult["records"] = [];
    const errors: string[] = [];
    const warnings: string[] = [];
    const diagnostics: Record<string, unknown> = {
      connectorUsed: "ArcGisFeatureServerAdapter",
      selectedFormat: "geojson",
    };
    const pageSize = 2000;
    let offset = 0;
    try {
      while (true) {
        const resolvedUrl = arcgisQueryUrl(source, offset, pageSize);
        const response = await this.fetcher(resolvedUrl, {
          headers: {"User-Agent": userAgent},
        });
        const body = await response.text();
        diagnostics.resolvedUrl = resolvedUrl;
        diagnostics.httpStatus = response.status;
        diagnostics.contentType = response.headers.get("content-type") ?? undefined;
        diagnostics.responseSize = body.length;
        diagnostics.responsePreview = responsePreview(body);
        if (!response.ok) {
          errors.push(`HTTP ${response.status} from ArcGIS.`);
          break;
        }
        const decoded = JSON.parse(body) as {features?: unknown[]; exceededTransferLimit?: boolean};
        const features = Array.isArray(decoded.features) ? decoded.features : [];
        if (features.length === 0) break;
        for (const [index, feature] of features.entries()) {
          if (!isRecord(feature)) continue;
          const props = isRecord(feature.properties) ? feature.properties : {};
          diagnostics.availableColumns = Object.keys(props);
          records.push(
            normalizeRecord(source, props, {
              rowIndex: offset + index,
              sourceFeatureId: stringValue(feature.id) ?? stringValue(props.OBJECTID),
              geometry: isGeometry(feature.geometry) ? feature.geometry : null,
              resolvedUrl,
            }),
          );
        }
        if (!decoded.exceededTransferLimit && features.length < pageSize) break;
        offset += pageSize;
      }
    } catch (error) {
      errors.push(`ArcGIS parser failed: ${String(error)}`);
    }
    return {records, errors, warnings, diagnostics};
  }
}

export class DirectCsvAdapter implements CouncilAdapter {
  sourceType = "direct_csv" as const;

  constructor(private readonly fetcher: FetchLike = fetch) {}

  async fetch(source: CouncilSource): Promise<AdapterResult> {
    const errors: string[] = [];
    const warnings: string[] = [];
    const diagnostics: Record<string, unknown> = {
      connectorUsed: "DirectCsvAdapter",
      selectedFormat: "csv",
      resolvedUrl: source.baseUrl,
    };
    try {
      const response = await this.fetcher(source.baseUrl, {
        headers: {"User-Agent": userAgent},
      });
      const body = await response.text();
      diagnostics.httpStatus = response.status;
      diagnostics.contentType = response.headers.get("content-type") ?? undefined;
      diagnostics.responseSize = body.length;
      diagnostics.responsePreview = responsePreview(body);
      if (!response.ok) return {records: [], errors: [`HTTP ${response.status}.`], warnings, diagnostics};
      const parsed = parseCsvRows(body);
      diagnostics.availableColumns = parsed.headers;
      const records = parsed.rows.map((row, index) =>
        normalizeRecord(source, row, {rowIndex: index, resolvedUrl: source.baseUrl}),
      );
      if (parsed.headers.length === 0) warnings.push("Invalid CSV headers.");
      return {records, errors, warnings, diagnostics};
    } catch (error) {
      return {records: [], errors: [`CSV parser failed: ${String(error)}`], warnings, diagnostics};
    }
  }
}

export class DirectJsonAdapter implements CouncilAdapter {
  sourceType = "direct_json" as const;

  constructor(private readonly fetcher: FetchLike = fetch) {}

  async fetch(source: CouncilSource): Promise<AdapterResult> {
    const diagnostics: Record<string, unknown> = {
      connectorUsed: "DirectJsonAdapter",
      selectedFormat: "json",
      resolvedUrl: source.baseUrl,
    };
    try {
      const response = await this.fetcher(source.baseUrl, {
        headers: {"User-Agent": userAgent},
      });
      const body = await response.text();
      diagnostics.httpStatus = response.status;
      diagnostics.contentType = response.headers.get("content-type") ?? undefined;
      diagnostics.responseSize = body.length;
      diagnostics.responsePreview = responsePreview(body);
      if (!response.ok) return {records: [], errors: [`HTTP ${response.status}.`], warnings: [], diagnostics};
      const rows = parseJsonRecords(body);
      diagnostics.availableColumns = rows[0] ? Object.keys(rows[0].properties) : [];
      const records = rows.map((row, index) =>
        normalizeRecord(source, row.properties, {
          rowIndex: index,
          sourceFeatureId: row.id,
          geometry: row.geometry,
          resolvedUrl: source.baseUrl,
        }),
      );
      return {records, errors: [], warnings: [], diagnostics};
    } catch (error) {
      return {records: [], errors: [`JSON parser failed: ${String(error)}`], warnings: [], diagnostics};
    }
  }
}

export class PdfAdapter implements CouncilAdapter {
  sourceType = "pdf" as const;

  constructor(private readonly fetcher: FetchLike = fetch) {}

  async fetch(source: CouncilSource): Promise<AdapterResult> {
    const diagnostics: Record<string, unknown> = {
      connectorUsed: "PdfAdapter",
      selectedFormat: "pdf",
      resolvedUrl: source.baseUrl,
    };
    try {
      const response = await this.fetcher(source.baseUrl, {
        headers: {"User-Agent": userAgent},
      });
      const body = await response.text();
      diagnostics.httpStatus = response.status;
      diagnostics.contentType = response.headers.get("content-type") ?? undefined;
      diagnostics.responseSize = body.length;
      diagnostics.responsePreview = responsePreview(body);
      if (!response.ok) return {records: [], errors: [`HTTP ${response.status}.`], warnings: [], diagnostics};
      const draft = normalizeRecord(
        source,
        {extractionNotes: responsePreview(body), restriction_text: responsePreview(body)},
        {rowIndex: 0, resolvedUrl: source.baseUrl, pdf: true},
      );
      return {
        records: [draft],
        errors: [],
        warnings: ["PDF extraction is best-effort and requires review."],
        diagnostics,
      };
    } catch (error) {
      return {records: [], errors: [`PDF extraction failed: ${String(error)}`], warnings: [], diagnostics};
    }
  }
}

export class SkippedAdapter implements CouncilAdapter {
  sourceType = "manual" as const;

  async fetch(): Promise<AdapterResult> {
    return {
      records: [],
      errors: [],
      warnings: ["Manual/unverified source skipped pending classification."],
      diagnostics: {connectorUsed: "SkippedAdapter"},
    };
  }
}

export function adapterFor(source: CouncilSource): CouncilAdapter {
  switch (source.sourceType) {
    case "socrata":
      return new SocrataAdapter();
    case "arcgis_featureserver":
      return new ArcGisFeatureServerAdapter();
    case "direct_csv":
      return new DirectCsvAdapter();
    case "direct_json":
    case "ckan":
      return new DirectJsonAdapter();
    case "pdf":
      return new PdfAdapter();
    case "manual":
    case "unverified":
      return new SkippedAdapter();
    default:
      return new SkippedAdapter();
  }
}

function arcgisQueryUrl(source: CouncilSource, offset: number, pageSize: number): string {
  const base = source.baseUrl.replace(/\/$/, "");
  const layerPattern = /\/(FeatureServer|MapServer)\/\d+$/i;
  const withLayer = layerPattern.test(base)
    ? base
    : `${base}/${source.layerIndex ?? 0}`;
  const url = new URL(`${withLayer}/query`);
  url.searchParams.set("where", "1=1");
  url.searchParams.set("outFields", "*");
  url.searchParams.set("f", "geojson");
  url.searchParams.set("outSR", "4326");
  url.searchParams.set("resultOffset", String(offset));
  url.searchParams.set("resultRecordCount", String(pageSize));
  return url.toString();
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isGeometry(value: unknown): value is GeoJsonGeometry {
  return isRecord(value) && typeof value.type === "string";
}

function stringValue(value: unknown): string | undefined {
  if (value == null) return undefined;
  const text = String(value).trim();
  return text === "" ? undefined : text;
}
