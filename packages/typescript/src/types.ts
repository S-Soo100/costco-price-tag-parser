/** Data model for the Costco price-tag parser (mirrors spec/schema). */

export type TagType = "regular" | "discount" | "unknown";

/** One recognized text line + its normalized bounding box (origin top-left). */
export interface OcrLine {
  text: string;
  x: number;
  yTop: number;
  w: number;
  h: number;
  conf: number;
}

export interface UnitPrice {
  value: number;
  unit: string; // 개, 100G, 10G, 100ml, ...
}

export interface DiscountInfo {
  originalPrice: number | null;
  discountAmount: number | null;
  periodStart: string | null; // ISO date, best-effort
  periodEnd: string | null;
}

export interface PriceTagData {
  schemaVersion: string;
  itemNumber: string | null; // 6-digit tracking key
  plusMark: boolean;
  nameKo: string | null; // reserved — not extracted
  model: string | null; // reserved — not extracted
  nameEn: string | null;
  finalPrice: number | null;
  tagType: TagType;
  discount: DiscountInfo | null;
  unitPrice: UnitPrice | null;
  rawText: string;
}
