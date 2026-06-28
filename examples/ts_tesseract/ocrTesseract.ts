/**
 * Reference OCR adapter: Tesseract.js -> OcrLine[].
 *
 * OPTIONAL — not part of the parser core. Bring any OCR you like; this just shows
 * one way to produce the `OcrLine`s the parser consumes.
 *
 *   npm install tesseract.js image-size costco-price-tag-parser
 *
 * Note: tesseract.js's result shape varies across major versions. This targets
 * v5 (`recognize(img, {}, { blocks: true })` -> data.blocks[].paragraphs[].lines[]).
 * Adjust the traversal if your installed version differs.
 */

import { readFileSync } from "node:fs";

import type { OcrLine } from "costco-price-tag-parser";
import imageSize from "image-size";
import { createWorker } from "tesseract.js";

export async function recognize(imagePath: string, lang = "kor+eng"): Promise<OcrLine[]> {
  const dim = imageSize(readFileSync(imagePath));
  const width = dim.width ?? 1;
  const height = dim.height ?? 1;

  const worker = await createWorker(lang);
  try {
    const { data } = await worker.recognize(imagePath, {}, { blocks: true });
    const out: OcrLine[] = [];
    for (const block of data.blocks ?? []) {
      for (const para of block.paragraphs ?? []) {
        for (const ln of para.lines ?? []) {
          const text = ln.text.trim();
          if (!text) continue;
          const b = ln.bbox; // pixels: { x0, y0, x1, y1 }
          out.push({
            text,
            x: b.x0 / width,
            yTop: b.y0 / height,
            w: (b.x1 - b.x0) / width,
            h: (b.y1 - b.y0) / height,
            conf: Math.max(0, ln.confidence / 100),
          });
        }
      }
    }
    // Reading order: top-to-bottom, then left-to-right (what the parser expects).
    out.sort((a, b) => (Math.abs(a.yTop - b.yTop) > 0.02 ? a.yTop - b.yTop : a.x - b.x));
    return out;
  } finally {
    await worker.terminate();
  }
}
