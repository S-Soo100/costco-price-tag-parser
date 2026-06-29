# Contributing

Thanks for helping out! This repo is a **parser in three languages kept identical
by a shared conformance suite**. The workflow below is what keeps them in sync.

## The one rule

**Dart is canonical.** Behaviour changes start in `packages/dart`, then flow out:

1. Change `packages/dart` and its tests.
2. Regenerate the golden:
   ```bash
   cd packages/dart && dart run tool/gen_golden.dart
   ```
3. Make the Python and TypeScript ports match the new golden.
4. All three conformance suites must be green.

Never hand-edit `spec/golden/expected.json` — it is generated. See
[`spec/CONFORMANCE.md`](spec/CONFORMANCE.md).

## Per-package dev

| | setup | test | lint / types |
|-|-------|------|--------------|
| **Dart** (`packages/dart`) | `dart pub get` | `dart test` | `dart analyze` |
| **Python** (`packages/python`) | `python -m venv .venv && . .venv/bin/activate && pip install -e ".[dev]"` | `pytest` | `mypy src && ruff check .` |
| **TypeScript** (`packages/typescript`) | `npm install` | `npm test` | `npm run typecheck` |

CI (`.github/workflows/conformance.yml`) runs all three on every push and PR.

## Adding a fixture / improving accuracy

The source photos are **not in the repo** (they're a [release asset](https://github.com/S-Soo100/costco-price-tag-parser/releases/tag/fixtures-source), to keep clones light). To work with them:

1. Fetch and extract the existing photos, then add your new one:
   ```bash
   gh release download fixtures-source --pattern 'sample_tags.tar.gz' && tar xzf sample_tags.tar.gz
   # drop your new photo into sample_tags/
   ```
2. Regenerate OCR (macOS / Apple Vision):
   ```bash
   swift tools/vision_ocr.swift sample_tags/*.JPG sample_tags/*.HEIC > spec/fixtures/ocr_raw.json
   ```
3. If you hand-verify a tag against the real photo, add explicit assertions to the
   "ground truth" group in each package's conformance test.
4. Regenerate the golden (step above) and run all three suites.
5. If you added photos, re-upload the archive: `tar czf sample_tags.tar.gz sample_tags && gh release upload fixtures-source sample_tags.tar.gz --clobber`.

## Style

- Match the existing code in each package; keep the three parsers structurally
  parallel so they stay easy to diff against `spec/SPEC.md`.
- Mind the documented porting traps in `spec/SPEC.md` (ASCII `\d`, code-point
  iteration, stable sort).
- Keep the **core dependency-free**. OCR engines belong in `examples/`, never in
  a package's runtime dependencies.
