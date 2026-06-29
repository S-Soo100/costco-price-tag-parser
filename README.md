# costco-price-tag-parser

[![conformance](https://github.com/S-Soo100/costco-price-tag-parser/actions/workflows/conformance.yml/badge.svg)](https://github.com/S-Soo100/costco-price-tag-parser/actions/workflows/conformance.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Dart](https://img.shields.io/badge/Dart-pure%20%C2%B7%200%20deps-0175C2.svg)](packages/dart)
[![Python](https://img.shields.io/badge/Python-3.10%2B%20%C2%B7%200%20deps-3776AB.svg)](packages/python)
[![TypeScript](https://img.shields.io/badge/TypeScript-ESM%2BCJS%20%C2%B7%200%20deps-3178C6.svg)](packages/typescript)

Turn the OCR text of a **Costco price tag** into structured data — in **Dart, Python, or TypeScript**.

```
[photo] ──(OCR: your choice)──▶ OcrLine[] ──(this library)──▶ PriceTagData
         ML Kit / Tesseract / Vision …      pure logic, identical in all 3 languages
```

The hard part of a price tag isn't the OCR — it's turning a pile of recognized
text boxes into *"item 685246, ₩349,900, on sale from ₩389,900."* That parsing
logic lives here, ported to three languages and kept **behaviourally identical**
(same structured output for the same input) by a shared golden conformance suite
that runs in CI on every change.

> **Bring your own OCR.** The core has **zero runtime dependencies**. Feed it
> `OcrLine`s from any engine — Google ML Kit, Tesseract, Apple Vision, a cloud
> API. Each language ships an *optional* reference adapter in [`examples/`](examples).

---

## Table of contents

- [Why](#why)
- [Install](#install)
- [Quickstart](#quickstart)
- [Input — `OcrLine`](#input--ocrline)
- [Output — `PriceTagData`](#output--pricetagdata)
- [Bring your own OCR](#bring-your-own-ocr)
- [How parity is guaranteed](#how-parity-is-guaranteed)
- [Known limitations](#known-limitations)
- [Repository layout](#repository-layout)
- [Development](#development)
- [Contributing](#contributing)
- [Roadmap](#roadmap)
- [Provenance](#provenance)
- [License](#license)

## Why

OCR engines give you text and bounding boxes. They don't tell you *which* number
is the price, *which* is the unit price, whether a tag is on sale, or where the
6-digit item number is. Costco's standard "A-format" rack card has a consistent
visual grammar — the final price is the physically largest number, the item
number sits alone on its own line, a `할인행사` label marks a discount — and this
library encodes that grammar as a small, dependency-free heuristic parser.

Writing that logic once per language drifts. Here the **Dart implementation is
canonical**, its output is frozen as a golden oracle, and the Python and
TypeScript ports are tested against the *same* oracle — so all three stay in
lockstep. See [How parity is guaranteed](#how-parity-is-guaranteed).

## Install

> ⚠️ **Not yet published** to pub.dev / PyPI / npm (tracked in [ROADMAP](ROADMAP.md#3--publish-to-package-registries)).
> Until then, use the [from-source](#from-source) install. The commands below are the intended UX once published.

| Language | Once published |
|----------|----------------|
| Dart / Flutter | `dart pub add costco_price_tag_parser` |
| Python | `pip install costco-price-tag-parser` |
| TypeScript | `npm install costco-price-tag-parser` |

### From source

**Python** (works today):
```bash
pip install "git+https://github.com/S-Soo100/costco-price-tag-parser.git#subdirectory=packages/python"
```

**Dart** — add a git dependency in your `pubspec.yaml`:
```yaml
dependencies:
  costco_price_tag_parser:
    git:
      url: https://github.com/S-Soo100/costco-price-tag-parser.git
      path: packages/dart
```

**TypeScript** — clone, then reference the package locally:
```bash
git clone https://github.com/S-Soo100/costco-price-tag-parser.git
cd costco-price-tag-parser/packages/typescript && npm install && npm run build
# then, in your project:
npm install /absolute/path/to/costco-price-tag-parser/packages/typescript
```

## Quickstart

The only thing you provide is a list of `OcrLine`s (see [the contract](#input--ocrline)).

**Dart**
```dart
import 'package:costco_price_tag_parser/costco_price_tag_parser.dart';

final lines = await myOcr.recognize(imagePath); // List<OcrLine>
final tag = parsePriceTag(lines);

print(tag.itemNumber);            // "685246"
print(tag.finalPrice);            // 349900
print(tag.tagType);               // TagType.discount
print(tag.toJson());              // Map ready for JSON
```

**Python**
```python
from costco_price_tag_parser import parse_price_tag, OcrLine

lines = [OcrLine.from_json(e) for e in my_ocr_output]
tag = parse_price_tag(lines)

print(tag.item_number)            # "685246"
print(tag.final_price)            # 349900
print(tag.tag_type.value)         # "discount"
print(tag.to_dict())              # dict with camelCase keys
```

**TypeScript**
```ts
import { parsePriceTag, type OcrLine } from "costco-price-tag-parser";

const lines: OcrLine[] = myOcrOutput;
const tag = parsePriceTag(lines);

tag.itemNumber;                   // "685246"
tag.finalPrice;                   // 349900
tag.tagType;                      // "discount"
JSON.stringify(tag);              // already the canonical shape
```

## Input — `OcrLine`

An **ordered** list of recognized text lines with normalized bounding boxes.
Schema: [`spec/schema/ocr_line.schema.json`](spec/schema/ocr_line.schema.json).

| field | type | meaning |
|-------|------|---------|
| `text` | string | the recognized line text |
| `x` | number | left edge, normalized `0..1` |
| `yTop` | number | top edge, normalized `0..1` (**origin top-left**; `0` = top of image) |
| `w` | number | width, normalized `0..1` |
| `h` | number | height, normalized `0..1` — used as a **glyph-height proxy** (the final price prints tallest) |
| `conf` | number | OCR confidence `0..1` (carried through; the parser doesn't use it) |

Requirements:

- **Normalized** to `0..1`, origin **top-left**.
- **Reading order**: top-to-bottom, then left-to-right.
- One entry per *line* (not per word). Most engines group lines for you;
  `examples/python_tesseract` shows how to group word boxes if yours doesn't.

(Python uses `OcrLine.from_json({...})` with the same camelCase keys, or the
constructor `OcrLine(text, x, y_top, w, h, conf)`.)

## Output — `PriceTagData`

Schema: [`spec/schema/price_tag_data.schema.json`](spec/schema/price_tag_data.schema.json).
JSON keys are camelCase in all three languages.

| field | type | notes |
|-------|------|-------|
| `schemaVersion` | string | always `"0.1"` |
| `itemNumber` | string \| null | 6-digit item number — the cross-store tracking key |
| `plusMark` | boolean | a `+` immediately after the item number (meaning TBD; kept raw) |
| `finalPrice` | int \| null | final price in KRW — the physically largest price token |
| `tagType` | `"regular"` \| `"discount"` \| `"unknown"` | `unknown` only when **neither** item number **nor** price is found |
| `discount` | object \| null | present only when `tagType == "discount"` |
| `discount.originalPrice` | int \| null | pre-sale price |
| `discount.discountAmount` | int \| null | `originalPrice − finalPrice` |
| `discount.periodStart` / `periodEnd` | string \| null | ISO date, **best-effort** (see [limitations](#known-limitations)) |
| `unitPrice` | object \| null | `{ value: int, unit: string }` from a `단가 / <unit>` label |
| `nameEn` | string \| null | best-effort English product name |
| `nameKo` / `model` | string \| null | **reserved** — not yet extracted (always null) |
| `rawText` | string | full OCR text (lines joined by `\n`), always kept for re-parse / review |

Example (`IMG_3374`, a discounted robot vacuum):

```jsonc
{
  "schemaVersion": "0.1",
  "itemNumber": "685246",
  "plusMark": true,
  "nameKo": null,
  "model": null,
  "nameEn": "ROBOROCK AQUA VACUUM",
  "finalPrice": 349900,
  "tagType": "discount",
  "discount": {
    "originalPrice": 389900,
    "discountAmount": 40000,
    "periodStart": "2026-05-12",
    "periodEnd": "2026-06-07"
  },
  "unitPrice": null,
  "rawText": "…full OCR text…"
}
```

The exact algorithm — every regex and tie-break — is specified language-neutrally
in [`spec/SPEC.md`](spec/SPEC.md).

## Bring your own OCR

The parser never touches an image; it only consumes `OcrLine`s. Each package
defines an optional `OcrEngine` interface to make adapters uniform:

```dart
abstract class OcrEngine {            // Dart
  Future<List<OcrLine>> recognize(String imagePath);
}
```
```python
class OcrEngine(Protocol):            # Python
    def recognize(self, image_path: str) -> list[OcrLine]: ...
```
```ts
interface OcrEngine {                 // TypeScript
  recognize(imagePath: string): Promise<OcrLine[]>;
}
```

Reference adapters (each **optional**, marked clearly) live in [`examples/`](examples):

| example | OCR engine | runs on |
|---------|-----------|---------|
| [`flutter_camera_demo`](examples/flutter_camera_demo) | Google ML Kit (on-device) | real iOS/Android device or Android emulator |
| [`python_tesseract`](examples/python_tesseract) | Tesseract (system binary) | desktop/server |
| [`ts_tesseract`](examples/ts_tesseract) | tesseract.js (WASM) | Node.js, no system binary |

No OCR set up? On macOS, [`tools/vision_ocr.swift`](tools/vision_ocr.swift) emits
the same `OcrLine` JSON via Apple Vision.

## How parity is guaranteed

The thing that keeps three implementations honest is a single shared oracle:

1. The **canonical Dart parser** is run over **46 real fixtures**
   ([`spec/fixtures/ocr_raw.json`](spec/fixtures)) and its output is frozen into
   [`spec/golden/expected.json`](spec/golden).
2. Every language's conformance suite parses the **same** fixtures and asserts
   against the **same** golden.
3. **CI** ([`conformance.yml`](.github/workflows/conformance.yml)) runs all three
   suites on every push and PR.

Two kinds of guarantee (full policy in [`spec/CONFORMANCE.md`](spec/CONFORMANCE.md)):

- **Ground truth** — 3 fixtures (`IMG_3374`, `IMG_3379`, `IMG_3383`) were
  hand-verified against the physical tags. They assert *real-world correctness*.
- **Golden parity** — the other 43 lock *behaviour*, not correctness: a port that
  matches the golden is proven identical to Dart, nothing more.

Because the fixtures can't exercise every divergence, the suites also include
**synthetic "parity trap" tests** for the cross-language hazards the
[code review](reports/costco-price-tag-parser-review-final.md) surfaced — e.g. a
non-ASCII space (NBSP) inside a price, and two item-number candidates sharing the
same `yTop` (resolved deterministically by an `x` tie-break). Porting notes for
these traps (ASCII digits, code-point iteration, sort determinism) are in
[`spec/SPEC.md`](spec/SPEC.md#determinism--parity-notes).

Tests today: **Dart 52 · Python 98 (52 + 46 schema-validation) · TypeScript 52**.

## Known limitations

The parser is a **heuristic** tuned for the standard A-format rack card, not a
validator. Several guards are in place (see [`spec/SPEC.md`](spec/SPEC.md)), but the
core limitation remains:

- **It does not detect non-A-format tags.** Bakery labels, receipts, and scene
  shots are *not* marked `unknown` if any plausible item number or `…원` price is
  found — the parser still emits a `regular` tag, and a stray price-like token
  (e.g. a `139원` hotline number) can be picked up. Proper non-A-format detection
  is the main open item — see [ROADMAP item 4](ROADMAP.md).
- **An item number OCR'd as 7+ digits yields `null`.** The digit-boundary guard
  correctly rejects 6-digit barcode substrings, but also declines a genuine item
  number that OCR merged with an extra digit (`1819440`) — `null` rather than a guess.
- **Dates are best-effort.** Calendar-impossible dates are now dropped (year
  2000–2099, month 1–12, day 1–31), but OCR can still yield a *plausible-but-wrong*
  date — treat `periodStart` / `periodEnd` as advisory, not ground truth.

Already guarded: nutrition/weight figures (`2,142kcal`, `1,584g`) are no longer
mistaken for prices; impossible dates are dropped; 6-digit barcode substrings are
rejected.

Treat low-confidence output as *"needs human review"* rather than authoritative.

## Repository layout

```
spec/         SPEC.md · schema/ · fixtures/ · golden/ · CONFORMANCE.md   ← single source of truth
packages/
  dart/       pub.dev package · canonical · pure Dart (no Flutter dep)
  python/     PyPI package · src layout · typed (py.typed)
  typescript/ npm package · ESM + CJS + d.ts
examples/     flutter_camera_demo · python_tesseract · ts_tesseract       ← optional OCR adapters
tools/        vision_ocr.swift                                            ← fixture generator (Apple Vision)
sample_tags/  46 real photos                                             ← fixture sources
docs/legacy/  original Flutter-app specs (provenance)
```

## Development

Each package is self-contained and reads `spec/` via a repo-root walk, so the
suites work from any cwd.

| | setup | test | lint / types |
|-|-------|------|--------------|
| **Dart** | `cd packages/dart && dart pub get` | `dart test` | `dart analyze` |
| **Python** | `cd packages/python && python -m venv .venv && . .venv/bin/activate && pip install -e ".[dev]"` | `pytest` | `mypy src && ruff check .` |
| **TypeScript** | `cd packages/typescript && npm install` | `npm test` | `npm run typecheck` · `npm run build` |

Regenerate the golden after any canonical (Dart) change:

```bash
cd packages/dart && dart run tool/gen_golden.dart
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). The one rule: **change `packages/dart`
first, regenerate the golden, then make Python & TypeScript match — all three
suites green.** Never hand-edit `spec/golden/expected.json`; it's generated.

## Roadmap

Planned work (metadata, slimming the repo, registry publishing, heuristic
hardening) is tracked in [ROADMAP.md](ROADMAP.md).

## Provenance

Extracted from a Flutter field-data app and generalized into a standalone library.
The heuristics were validated against 46 real Costco photos (35 A-format, 6 on
sale). Background lives in [`docs/legacy/`](docs/legacy).

## License

[MIT](LICENSE).
