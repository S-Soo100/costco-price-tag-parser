/**
 * Costco A-format price-tag parser — pure TypeScript, OCR-engine-agnostic.
 *
 * ```ts
 * import { parsePriceTag, type OcrLine } from "costco-price-tag-parser";
 *
 * const lines: OcrLine[] = await myOcr.recognize(imagePath); // your OCR -> OcrLine[]
 * const tag = parsePriceTag(lines);
 * console.log(tag.itemNumber); // "685246"
 * ```
 */

export { parsePriceTag } from "./parser.js";
export type {
  OcrLine,
  PriceTagData,
  DiscountInfo,
  UnitPrice,
  TagType,
} from "./types.js";
export type { OcrEngine } from "./ocrEngine.js";
