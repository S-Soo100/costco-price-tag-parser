# costco-price-tag-parser

Turn the OCR text of a **Costco price tag** into structured data — in **Dart, Python, or TypeScript**.

```
[photo] ──(OCR: your choice)──▶ OcrLine[] ──(this library)──▶ PriceTagData
         ML Kit / Tesseract / Vision …      pure logic, identical in all 3 languages
```

The hard part of a price tag isn't the OCR — it's turning a pile of recognized
text boxes into *"item 685246, ₩349,900, on sale from ₩389,900."* That parsing
logic lives here, ported to three languages and kept **behaviourally identical**
(same structured output for the same input) by a shared conformance suite.

> **Bring your own OCR.** The core has **zero dependencies**. Feed it `OcrLine`s
> from any engine (Google ML Kit, Tesseract, Apple Vision, a cloud API…). Each
> language ships an optional reference adapter in [`examples/`](examples).

## Packages

| Language | Package | Install | Source |
|----------|---------|---------|--------|
| Dart / Flutter | `costco_price_tag_parser` | `dart pub add costco_price_tag_parser` | [`packages/dart`](packages/dart) |
| Python | `costco-price-tag-parser` | `pip install costco-price-tag-parser` | [`packages/python`](packages/python) |
| TypeScript | `costco-price-tag-parser` | `npm install costco-price-tag-parser` | [`packages/typescript`](packages/typescript) |

## Quickstart

**Dart**
```dart
import 'package:costco_price_tag_parser/costco_price_tag_parser.dart';

final lines = await myOcr.recognize(imagePath); // -> List<OcrLine>
final tag = parsePriceTag(lines);
print('${tag.itemNumber} · ${tag.finalPrice}원'); // 685246 · 349900원
```

**Python**
```python
from costco_price_tag_parser import parse_price_tag, OcrLine

lines = [OcrLine.from_json(e) for e in my_ocr_output]
tag = parse_price_tag(lines)
print(tag.item_number, tag.final_price)  # 685246 349900
```

**TypeScript**
```ts
import { parsePriceTag, type OcrLine } from "costco-price-tag-parser";

const lines: OcrLine[] = myOcrOutput;
const tag = parsePriceTag(lines);
console.log(tag.itemNumber, tag.finalPrice); // 685246 349900
```

## What it extracts

From a Costco **A-format rack card** it pulls `itemNumber` (the 6-digit tracking
key), `finalPrice`, `tagType` (`regular` / `discount` / `unknown`), `discount`
(original price, amount, period), `unitPrice`, and a best-effort `nameEn`. Full
output schema: [`spec/schema/price_tag_data.schema.json`](spec/schema/price_tag_data.schema.json).

```jsonc
{
  "itemNumber": "685246",
  "finalPrice": 349900,
  "tagType": "discount",
  "discount": { "originalPrice": 389900, "discountAmount": 40000,
                "periodStart": "2026-05-12", "periodEnd": "2026-06-07" },
  "unitPrice": null,
  "nameEn": "ROBOROCK AQUA VACUUM",
  "rawText": "…full OCR text, always kept…"
  // schemaVersion, plusMark, nameKo, model omitted for brevity
}
```

`tagType` is `unknown` only when **neither** a 6-digit item number **nor** a price
is found; if either is present the tag is `regular`/`discount`. See
[Known limitations](#known-limitations) for what that means on non-A-format tags.

## How parity is guaranteed

The Dart parser is canonical. Its output over **46 real fixtures** is frozen into
[`spec/golden/expected.json`](spec/golden), and every language runs the **same**
inputs against the **same** golden. 3 fixtures are hand-verified ground truth;
the rest lock behaviour (not correctness). Synthetic "parity trap" tests cover
cross-language hazards (Unicode whitespace, `yTop` ties) the fixtures don't hit.
See [`spec/SPEC.md`](spec/SPEC.md) (the algorithm) and
[`spec/CONFORMANCE.md`](spec/CONFORMANCE.md) (the policy).

## Known limitations

The parser is a **heuristic** tuned for the standard A-format rack card, not a
validator. In particular:

- **It does not detect non-A-format tags.** Bakery labels, product/scene shots,
  and blurry tags are *not* reliably marked `unknown` — if any 6-digit run or any
  `…원` / comma-number appears, it will emit a `regular` tag. A phone number or a
  weight (`2,142kcal`, `1,584g`) can be picked up as a price.
- **Dates are best-effort.** OCR routinely mangles them (e.g. `2026.05121`), so a
  discount's `periodStart`/`periodEnd` may be wrong or impossible (`2026-06-70`).
  They are parity-locked, **not** ground truth.
- **`itemNumber` matching is unanchored** — a 6-digit substring of a longer digit
  run can be captured.

Treat low-confidence output as "needs human review" rather than authoritative.
Hardening these heuristics (context guards, date validation) is open work —
[contributions welcome](CONTRIBUTING.md).

## Repo layout

```
spec/        SPEC.md · schema/ · fixtures/ · golden/ · CONFORMANCE.md   ← single source of truth
packages/    dart/ · python/ · typescript/                              ← the three ports
examples/    flutter_camera_demo · python_tesseract · ts_tesseract      ← optional OCR adapters
tools/       vision_ocr.swift                                           ← fixture generator (Apple Vision)
sample_tags/ 46 real photos                                            ← fixture sources
```

## Provenance

Extracted from a Flutter field-data app and generalized into a standalone library.
The heuristics were validated against 46 real Costco photos (35 A-format, 6 on
sale). Background: [`docs/legacy/`](docs/legacy).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). The golden rule: **fix the Dart parser,
regenerate the golden, get all three suites green.** Never hand-edit the golden.

## License

[MIT](LICENSE).
