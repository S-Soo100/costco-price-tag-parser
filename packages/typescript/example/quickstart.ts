// Quickstart / screenshot demo — parse a bundled fixture, print the result.
// No OCR needed; runs from anywhere in the repo.
//
//   cd packages/typescript && npx tsx example/quickstart.ts
import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import { parsePriceTag, type OcrLine } from "../src/index.js";

function repoRoot(): string {
  let dir = dirname(fileURLToPath(import.meta.url));
  while (!existsSync(join(dir, "spec", "fixtures"))) {
    const parent = dirname(dir);
    if (parent === dir) throw new Error("repo root not found");
    dir = parent;
  }
  return dir;
}

const fixtures: Record<string, OcrLine[]> = JSON.parse(
  readFileSync(join(repoRoot(), "spec/fixtures/ocr_raw.json"), "utf8"),
);

// A real Costco tag: NIKE synthetic gloves (item + price + unit price).
const { rawText: _rawText, ...out } = parsePriceTag(fixtures["IMG_3379.JPG"]);
console.log(JSON.stringify(out, null, 2));
