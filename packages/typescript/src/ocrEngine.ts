/**
 * Optional OCR boundary. Bring your own engine — the parser only needs OcrLines.
 *
 * Any object implementing `recognize(imagePath) => Promise<OcrLine[]>` works
 * (Tesseract.js, a cloud OCR API, macOS Vision via tools/vision_ocr.swift…).
 * See examples/ts_tesseract for a reference adapter.
 */

import type { OcrLine } from "./types.js";

export interface OcrEngine {
  recognize(imagePath: string): Promise<OcrLine[]>;
}
