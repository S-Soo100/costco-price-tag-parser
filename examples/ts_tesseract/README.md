# Example — TypeScript + Tesseract.js

Reference OCR adapter showing how to feed the parser from
[tesseract.js](https://github.com/naptha/tesseract.js) (pure JS/WASM — no system
binary needed). **Optional** — the parser core has zero dependencies; any OCR
that yields `OcrLine`s works.

## Setup

```bash
npm install
# Until the parser is published to npm, link the local build instead:
#   (cd ../../packages/typescript && npm install && npm run build)
#   npm install ../../packages/typescript
```

## Run

```bash
npx tsx demo.ts /path/to/price_tag.jpg
```

Prints the parsed `PriceTagData` as JSON. (First run downloads the Korean
traineddata.)

## How it works

`ocrTesseract.recognize()` runs tesseract.js, normalizes each line's pixel box to
`0..1` (origin top-left) using the image dimensions, and sorts the lines into
reading order — the `OcrLine[]` shape `parsePriceTag()` expects.

> tesseract.js result shapes drift across major versions; this targets v5. If
> your version exposes `data.lines` directly, simplify the traversal accordingly.
