# SPEC — Costco A-format price-tag parser

Language-neutral definition of the parsing algorithm. The Dart implementation in
`packages/dart` is the canonical reference; Python and TypeScript ports MUST
reproduce this behaviour exactly (verified by the conformance suite — see
[CONFORMANCE.md](CONFORMANCE.md)).

Validated against 46 real photos; 3 (`IMG_3374`, `IMG_3379`, `IMG_3383`) were
hand-verified against the physical tags.

## Input

An **ordered** list of `OcrLine` objects (schema: [`schema/ocr_line.schema.json`](schema/ocr_line.schema.json)):

```
OcrLine { text: string, x, yTop, w, h, conf: number(0..1) }
```

- Coordinates are normalized `0..1`, **origin top-left** (`yTop = 0` is the top).
- Lines arrive in **reading order**: top-to-bottom, then left-to-right.
- `h` (box height) is used as a **glyph-height proxy** — the biggest price prints tallest.

## Output

A `PriceTagData` object (schema: [`schema/price_tag_data.schema.json`](schema/price_tag_data.schema.json)).

## Regexes

Digits are **ASCII only** (`[0-9]`), matching Dart/JS `\d`. Whitespace (`\s`) is
**Unicode** (must match NBSP / full-width space between a price and `원`). In Python,
write `[0-9]` literally and do **not** pass `re.ASCII` — that flag would also force
`\s` to ASCII-only and break parity. Dart/JS `\d` are already ASCII and `\s` already Unicode.

| name | pattern | use |
|------|---------|-----|
| `pureItem` | `^(\d{6})(\+?)$` | a line that is ONLY a 6-digit number (+ optional `+`) |
| `item` | `(\d{6})(\+?)` | a 6-digit number anywhere |
| `price` | `(\d[\d,]{2,})\s*원` | a price followed by `원` |
| `commaNum` | `\d{1,3}(?:,\d{3})+` | a comma-grouped number whose `원` was split off by OCR |
| `date` | `(\d{4})[.\/](\d{1,2})[.\/]?(\d{1,2})` | a date like `2026.05.21` or `2026/5/7` |
| `unit` | `단가\s*/\s*([^\s]+)` | the `단가 / <unit>` label |
| `latin` | `[A-Za-z]` | presence of a Latin letter |

## Algorithm

Let `rawText` = every line's `text` joined by `"\n"`, and `blob` = joined by a single space `" "`.

### 1. itemNumber + plusMark
1. From each line, remove **ASCII space** (U+0020) characters from its `text`.
2. **Candidates A** = lines whose despaced text matches `pureItem`. Sort by `(yTop, x)` ascending. If non-empty, `pick` = first.
3. Else **Candidates B** = lines whose despaced text matches `item`. Sort by `(yTop, x)` ascending. If non-empty, `pick` = first.
4. If `pick` exists: run `item` on its despaced text; `itemNumber` = group 1, `plusMark` = (group 2 == `"+"`). Otherwise `itemNumber` = null, `plusMark` = false.

### 2. Price tokens
For each line, derive at most one integer price value `v`:
- If `price` matches, take group 1, delete commas, parse int → `v`.
- Else if `commaNum` matches, take match 0, delete commas, parse int → `v`.
- Else: no token for this line.

For every produced `v`, keep a token `{ v, h: line.h, y: line.yTop }`, **in input order**.

### 3. finalPrice
`finalPrice` = the token with the **largest `h`**. Iterate tokens in order; replace the current best only when `h` is **strictly greater** (so the first maximum wins on ties). Null if there are no tokens. Remember this token as `finalTok`.

### 4. tagType
- `isDiscount` = `blob` contains the substring `"할인행사"`.
- If `itemNumber` is null **and** `finalPrice` is null → `tagType = "unknown"`.
- Else → `"discount"` if `isDiscount`, otherwise `"regular"`.

### 5. discount (only when `isDiscount`)
- `originalPrice` = the **largest** token value strictly **greater than** `finalPrice` (null if `finalPrice` is null or no token exceeds it).
- `discountAmount` = `originalPrice − finalPrice` when both exist, else null.
- Collect all `date` matches over `blob`, in order. `periodStart` = match 0, `periodEnd` = match 1 (if present), each formatted `YYYY-MM-DD` with month/day **zero-padded to 2 digits**. Missing → null.
- When not a discount tag, `discount` = null.

### 6. unitPrice
1. Find the **first** line matching `unit`; record `labelY = line.yTop` and `unit = group 1`. If none, `unitPrice` = null.
2. Otherwise, among the price tokens, **skip `finalTok`** (the token whose `v` AND `h` both equal the final token's), and pick the token whose `y` is **closest** to `labelY` (smallest `|y − labelY|`; first wins on ties). `unitPrice = { value: token.v, unit }`. If no token remains, null.

### 7. nameEn (best-effort)
Scan lines in order; the **first** line that satisfies all of:
- trimmed length ≥ 5 **code points**, and
- contains a space, and
- ratio of printable-ASCII code points (`> 32` and `< 128`) to total **code points** is `> 0.7`, and
- contains a Latin letter (`latin`)

becomes `nameEn` (trimmed). Else null.

> **Code points, not UTF-16 units** — for *both* the length gate and the ratio.
> In JS use `[...str]` / `Array.from(str)`, **not** `str.length`. In Python use
> `len(str)` (already code points). In Dart use `str.runes.length`, **not** `str.length`.

### 8. Reserved fields
`nameKo` and `model` are in the schema but **not extracted** — always null. `schemaVersion` = `"0.1"`.

## Determinism / parity notes

- **Sort key `(yTop, x)`.** Always break `yTop` ties by ascending `x` (left-most first). Do not rely on sort stability — Dart's `List.sort` is not guaranteed stable, so an explicit `x` tiebreak is required for cross-language and cross-version determinism.
- **First-wins ties.** finalPrice (strictly-greater), unitPrice (strictly-closer), and originalPrice (strictly-greater) all use strict comparisons so the first qualifying token wins deterministically.
- **Integers only** for prices; no float formatting is involved in the output.
