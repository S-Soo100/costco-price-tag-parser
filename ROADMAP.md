# Roadmap / TODO

Post-launch backlog, captured 2026-06-28 after the baseline push and the
[cross-model review](docs/cross-review-2026-06.md). Ordered
roughly by effort-to-value; item 4 is the only large one.

Legend: 🟢 quick · 🟡 medium · 🔴 larger / design work

---

## 1. ✅ Fill in repository metadata — **done**

Every manifest now points at `https://github.com/S-Soo100/costco-price-tag-parser`:

- `packages/dart/pubspec.yaml` → `repository` + `issue_tracker`; added `README.md`,
  `CHANGELOG.md`, `LICENSE` (pub.dev requirements) — `dart pub publish --dry-run` is clean.
- `packages/python/pyproject.toml` → `authors` + `[project.urls]`.
- `packages/typescript/package.json` → `author`, `homepage`, `repository` (with monorepo
  `directory`), `bugs`.
- `LICENSE` → copyright holder set to `Seungsoo Baek`; copied into each package dir.

## 2. ✅ Slim the repository — **done**

The 46 source photos (~95 MB) were removed from git history with `git-filter-repo`
and preserved as the
[`fixtures-source` release](https://github.com/S-Soo100/costco-price-tag-parser/releases/tag/fixtures-source)
asset (`sample_tags.tar.gz`). `.git` dropped from ~94 MB to ~324 KB. The derived
`spec/fixtures/ocr_raw.json` (~220 KB) — all the suites actually need — stays in the
repo. Regeneration now fetches the photos from the release
(see [CONTRIBUTING.md](CONTRIBUTING.md) and [`spec/CONFORMANCE.md`](spec/CONFORMANCE.md)).

> Note: this required a one-time history rewrite + force-push. Done while the repo
> was new (no forks/dependents), so the disruption was minimal.

## 3. 🟡 Publish to package registries

Ship the three packages so the README install commands work:

- **Dart** → `pub.dev` (`dart pub publish`)
- **Python** → `PyPI` (build sdist+wheel, `twine upload`; verify `py.typed` ships in the wheel)
- **TypeScript** → `npm` (`npm publish --access public`; verify `dist/` ESM+CJS+`.d.ts`)

Each needs the owner's registry account + 2FA. Consider automating with a
`release` GitHub Actions workflow (tag → build → publish).

**Acceptance:** `dart pub add` / `pip install` / `npm install costco-price-tag-parser` all resolve the published package; README "Install" no longer needs the from-source note.

## 4. 🔴 Harden the parsing heuristics (the real feature work)

**Partially done (2026-06-29).** Three guards landed across all three ports with
trap tests; golden regenerated and diff-reviewed (8 fixtures improved, 1 honest
regression, ground-truth unchanged):

- ✅ **Weight/energy guard** — a comma-number followed by `kcal`/`g`/`kg`/`mg`/`ml`/`l`
  is no longer treated as a price (`2,142kcal`, `1,584g`).
- ✅ **Anchor `itemNumber`** — digit boundaries reject a 6-digit substring of a longer
  run (barcodes, `ITEM: 3663092`, `2000005…`). Trade-off: an item OCR'd as 7 digits
  (`1819440`) now yields `null` rather than a lucky guess.
- ✅ **Validate dates** — drop calendar-impossible dates (year 2000–2099, month 1–12,
  day 1–31): `2026-06-70`, `2026-00-05`, year `6106`.

**Still open:**

- **Detect non-A-format tags** — bakery labels / receipts / scene shots should return
  `unknown` (or a confidence score) instead of a `regular` tag assembled from stray
  tokens (e.g. a `139원` hotline number). This is the hard part: it needs a structural
  confidence signal and ideally the source photos to verify, so it warrants a
  dedicated pass.
- (Optional) recover a genuine 7-digit-OCR'd item number instead of `null`, once
  non-A-format detection can tell it apart from barcode noise.

**Process:** change `packages/dart` first (canonical) → regen golden → match Python & TS → all suites green. See [CONTRIBUTING.md](CONTRIBUTING.md).

## 5. ✅ Decide on the cross-review log — **done**

Kept for transparency and moved out of the root to
[`docs/cross-review-2026-06.md`](docs/cross-review-2026-06.md) (the candid
cross-review + resolution log). The root `reports/` directory was removed.

---

> Want any of these as GitHub issues? They map 1:1 to issues/milestones. Item 4
> is the natural place for outside contributions.
