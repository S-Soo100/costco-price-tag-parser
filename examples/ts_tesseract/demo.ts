/**
 * End-to-end demo: image -> Tesseract.js OCR -> parse -> JSON.
 *
 *   npx tsx demo.ts <image_path>
 */

import { parsePriceTag } from "costco-price-tag-parser";

import { recognize } from "./ocrTesseract.js";

const imagePath = process.argv[2];
if (!imagePath) {
  console.error("usage: npx tsx demo.ts <image_path>");
  process.exit(1);
}

const lines = await recognize(imagePath);
const tag = parsePriceTag(lines);
console.log(JSON.stringify(tag, null, 2));
