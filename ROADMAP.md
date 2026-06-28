# Roadmap / TODO

Post-launch backlog, captured 2026-06-28 after the baseline push and the
[cross-model review](reports/costco-price-tag-parser-review-final.md). Ordered
roughly by effort-to-value; item 4 is the only large one.

Legend: 🟢 quick · 🟡 medium · 🔴 larger / design work

---

## 1. 🟢 Fill in repository metadata

The package manifests still have placeholder / missing repo links. Now that the
repo lives at `https://github.com/S-Soo100/costco-price-tag-parser`, set:

- `packages/dart/pubspec.yaml` → uncomment & set `repository:`
- `packages/python/pyproject.toml` → add `[project.urls]` (Homepage, Repository, Issues)
- `packages/typescript/package.json` → add `repository`, `bugs`, `homepage`, `author`
- `LICENSE` → replace `costco-price-tag-parser contributors` with the real copyright holder if desired

**Acceptance:** each manifest points at the GitHub repo; `npm pkg fix` / `dart pub publish --dry-run` show no metadata warnings.

## 2. 🟡 Slim the repository (`sample_tags/` is ~95 MB)

The 46 source photos make clones heavy for a library. Options:

- Move them to **Git LFS**, or
- Split them into a separate `*-fixtures` repo and keep only `spec/fixtures/ocr_raw.json` here, or
- Keep as-is and document the size.

`spec/fixtures/ocr_raw.json` (the derived OCR, ~220 KB) is what the suites actually
need; the raw photos are only for *regenerating* fixtures (`tools/vision_ocr.swift`).

**Acceptance:** a fresh `git clone` is small; `CONTRIBUTING.md` documents where the source photos live and how to regenerate fixtures.

## 3. 🟡 Publish to package registries

Ship the three packages so the README install commands work:

- **Dart** → `pub.dev` (`dart pub publish`)
- **Python** → `PyPI` (build sdist+wheel, `twine upload`; verify `py.typed` ships in the wheel)
- **TypeScript** → `npm` (`npm publish --access public`; verify `dist/` ESM+CJS+`.d.ts`)

Each needs the owner's registry account + 2FA. Consider automating with a
`release` GitHub Actions workflow (tag → build → publish).

**Acceptance:** `dart pub add` / `pip install` / `npm install costco-price-tag-parser` all resolve the published package; README "Install" no longer needs the from-source note.

## 4. 🔴 Harden the parsing heuristics (the real feature work)

The review showed the parser is naive on **non-A-format** input and unvalidated
dates (see [Known limitations](README.md#known-limitations) and review items
C3 / single-model findings). This is deferred because each change ripples the
golden and must be re-verified across all three ports. Candidate work:

- **Context guards for prices** — don't treat phone numbers (`139원` in body text),
  weights/energy (`2,142kcal`, `1,584g`) as the final price.
- **Anchor `itemNumber`** — avoid capturing a 6-digit substring of a longer digit run.
- **Validate dates** — reject impossible months/days (`2026-06-70`, `2026-00-05`);
  treat an OCR-mangled date as absent rather than guessing.
- **Detect non-A-format tags** — return `unknown` (or a confidence signal) for
  bakery labels / scene shots instead of emitting a `regular` tag.
- For each: add a **trap fixture/unit test** so the conformance suite actually
  exercises it, then regenerate the golden (`dart run tool/gen_golden.dart`).

**Process:** change `packages/dart` first (canonical) → regen golden → match Python & TS → all suites green. See [CONTRIBUTING.md](CONTRIBUTING.md).

**Acceptance:** the listed mis-parses no longer occur on representative inputs; new trap tests guard them; the three suites stay green.

## 5. 🟢 Decide on `reports/`

`reports/costco-price-tag-parser-review-final.md` (the candid cross-review +
resolution log) is currently public. Either keep it for transparency, move it to
`docs/`, or remove it from the published tree.

**Acceptance:** a deliberate decision is made and reflected in the repo.

---

> Want any of these as GitHub issues? They map 1:1 to issues/milestones. Item 4
> is the natural place for outside contributions.
