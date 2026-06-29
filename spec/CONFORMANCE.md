# CONFORMANCE — how the three ports stay in sync

All three language packages parse the **same** input fixtures and assert against
the **same** frozen golden output. This is what guarantees they behave identically.

## Files

| file | role |
|------|------|
| `spec/fixtures/ocr_raw.json` | 46 images → their OCR lines. The shared **input**. |
| `spec/golden/expected.json` | The canonical Dart parser's output for all 46 images. The shared **oracle**. |
| `spec/SPEC.md` | The algorithm every port implements. |

`expected.json` maps `"<image>.JPG" → PriceTagData` **without `rawText`** (that field
is just the input lines joined by `"\n"` — a pass-through, not parsing logic, so it is
excluded to keep the golden focused and readable). The golden is therefore a *subset*
of `PriceTagData`; the **full** output (with `rawText`) is validated against
[`schema/price_tag_data.schema.json`](schema/price_tag_data.schema.json) by the Python
suite (`tests/test_schema.py`) — structure only, not semantic validity.

## Two kinds of guarantee

1. **Ground truth (3 images)** — `IMG_3374`, `IMG_3379`, `IMG_3383` were hand-verified
   against the physical tags. These assert **real-world correctness** and each port
   should test them explicitly.
2. **Golden parity (all 46)** — the other 43 are *"whatever the canonical Dart parser
   says"*. They lock **behaviour**, not ground truth. A port matching the golden is
   proven identical to Dart, nothing more.

### When the golden is "wrong"

If a fixture's golden value is discovered to be incorrect, the fix order is:

1. Fix `packages/dart` (the canonical parser).
2. Regenerate: `cd packages/dart && dart run tool/gen_golden.dart`.
3. Re-run all three conformance suites; update ports until green.

Never hand-edit `expected.json` — it is generated.

## Running the suite

| language | command (from repo root) |
|----------|--------------------------|
| Dart | `cd packages/dart && dart test` |
| Python | `cd packages/python && pytest` |
| TypeScript | `cd packages/typescript && npm test` |

Each suite locates `spec/` by walking up from the working directory, so it works
from any cwd inside the repo. CI runs all three on every change
(`.github/workflows/conformance.yml`).

## Adding a fixture

The source photos live in the [`fixtures-source` release](https://github.com/S-Soo100/costco-price-tag-parser/releases/tag/fixtures-source), not the repo (see [ROADMAP](../ROADMAP.md) item 2).

1. Fetch them: `gh release download fixtures-source --pattern 'sample_tags.tar.gz' && tar xzf sample_tags.tar.gz`, then add your photo to `sample_tags/`.
2. Regenerate OCR: `swift tools/vision_ocr.swift sample_tags/*.{JPG,HEIC} > spec/fixtures/ocr_raw.json`
   (macOS Vision; emits the same `{text, bbox}` shape as on-device ML Kit).
3. Regenerate the golden (step above) and re-run all suites. See CONTRIBUTING.md for re-uploading the archive.
