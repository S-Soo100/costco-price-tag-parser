# costco-price-tag-parser (TypeScript)

Heuristic parser that turns the OCR text lines of a **Costco A-format price tag**
into a structured `PriceTagData`. Pure TypeScript, zero runtime dependencies,
OCR-engine-agnostic. Ships ESM + CJS + types.

> Part of the [costco-price-tag-parser](../../README.md) monorepo (Dart · Python · TypeScript).
> Algorithm: [`spec/SPEC.md`](../../spec/SPEC.md).

## Install

```bash
npm install costco-price-tag-parser
```

## Use

Bring your own OCR. Feed the parser an array of `OcrLine`s (normalized boxes,
origin top-left, reading order):

```ts
import { parsePriceTag, type OcrLine } from "costco-price-tag-parser";

const lines: OcrLine[] = ocrOutput; // each: { text, x, yTop, w, h, conf } normalized 0..1
const tag = parsePriceTag(lines);

tag.itemNumber; // "649221"
tag.finalPrice; // 23890
JSON.stringify(tag); // already the canonical schema shape
```

See [`examples/ts_tesseract`](../../examples/ts_tesseract) for a reference OCR
adapter (optional — any engine producing `OcrLine`s works).

## Develop

```bash
npm install
npm test          # vitest — conformance against the shared spec/golden
npm run typecheck # tsc --strict
npm run build     # tsup -> dist (esm + cjs + d.ts)
```
