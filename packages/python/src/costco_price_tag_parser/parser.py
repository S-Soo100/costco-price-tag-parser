"""Costco A-format price-tag parser. Pure Python port of the canonical Dart parser.

See ../../../spec/SPEC.md for the language-neutral algorithm this implements.
"""

from __future__ import annotations

import re

from .models import DiscountInfo, OcrLine, PriceTagData, TagType, UnitPrice

# Use explicit [0-9] (ASCII digits, like Dart/JS `\d`) instead of `\d` + re.ASCII —
# re.ASCII would ALSO make `\s` ASCII-only, diverging from Dart/JS where `\s` is
# Unicode (e.g. matches NBSP / full-width space between a price and 원).
_PURE_ITEM = re.compile(r"^([0-9]{6})(\+?)$")
# Digit boundaries so a 6-digit run inside a longer number (barcodes,
# "ITEM: 3663092") is NOT mistaken for an item number.
_ITEM = re.compile(r"(?<![0-9])([0-9]{6})(?![0-9])(\+?)")
_PRICE = re.compile(r"([0-9][0-9,]{2,})\s*원")
_COMMA_NUM = re.compile(r"[0-9]{1,3}(?:,[0-9]{3})+")
# A comma-number followed by one of these is a nutrition/weight figure, not a price.
_WEIGHT_UNIT = re.compile(r"^\s*(?:kcal|kg|mg|ml|g|l)", re.IGNORECASE)
_DATE = re.compile(r"([0-9]{4})[.\/]([0-9]{1,2})[.\/]?([0-9]{1,2})")
_UNIT = re.compile(r"단가\s*/\s*([^\s]+)")
_LATIN = re.compile(r"[A-Za-z]")


def _pad(s: str | None) -> str:
    return (s or "").rjust(2, "0")


def _iso_date(m: re.Match[str]) -> str | None:
    """ISO `YYYY-MM-DD`, or None when the date is out of calendar range (OCR
    routinely mangles dates, e.g. `2026.06.70`)."""
    y, mo, d = int(m.group(1)), int(m.group(2)), int(m.group(3))
    if not (2000 <= y <= 2099 and 1 <= mo <= 12 and 1 <= d <= 31):
        return None
    return f"{m.group(1)}-{_pad(m.group(2))}-{_pad(m.group(3))}"


def parse_price_tag(lines: list[OcrLine]) -> PriceTagData:
    raw = "\n".join(ln.text for ln in lines)
    blob = " ".join(ln.text for ln in lines)

    # --- itemNumber: prefer a line that is ONLY a 6-digit number (topmost) ---
    item: str | None = None
    plus = False
    pures = sorted(
        (ln for ln in lines if _PURE_ITEM.match(ln.text.replace(" ", ""))),
        key=lambda ln: (ln.y_top, ln.x),
    )
    pick = pures[0] if pures else None
    if pick is None:
        anys = sorted(
            (ln for ln in lines if _ITEM.search(ln.text.replace(" ", ""))),
            key=lambda ln: (ln.y_top, ln.x),
        )
        pick = anys[0] if anys else None
    if pick is not None:
        m = _ITEM.search(pick.text.replace(" ", ""))
        assert m is not None
        item = m.group(1)
        plus = m.group(2) == "+"

    # --- price tokens (value, glyph-height, vertical pos), in input order ---
    pts: list[tuple[int, float, float]] = []
    for ln in lines:
        v: int | None = None
        m = _PRICE.search(ln.text)
        if m:
            v = int(m.group(1).replace(",", ""))
        else:
            cm = _COMMA_NUM.search(ln.text)  # price whose '원' got split off
            # …unless it's a nutrition/weight figure (e.g. "2,142kcal"), not a price.
            if cm and not _WEIGHT_UNIT.match(ln.text[cm.end() :]):
                v = int(cm.group(0).replace(",", ""))
        if v is not None:
            pts.append((v, ln.h, ln.y_top))

    final_tok: tuple[int, float, float] | None = None
    for p in pts:
        if final_tok is None or p[1] > final_tok[1]:
            final_tok = p
    final_price = final_tok[0] if final_tok else None

    # --- tag type + discount ---
    is_disc = "할인행사" in blob
    if item is None and final_price is None:
        tag = TagType.UNKNOWN
    else:
        tag = TagType.DISCOUNT if is_disc else TagType.REGULAR

    disc: DiscountInfo | None = None
    if tag == TagType.DISCOUNT:
        orig: int | None = None
        if final_price is not None:
            for p in pts:
                if p[0] > final_price and (orig is None or p[0] > orig):
                    orig = p[0]
        amt = orig - final_price if (orig is not None and final_price is not None) else None
        # Keep only calendar-plausible dates (OCR mangles them, e.g. 2026-06-70).
        dates = [d for d in (_iso_date(m) for m in _DATE.finditer(blob)) if d]
        ps = dates[0] if dates else None
        pe = dates[1] if len(dates) > 1 else None
        disc = DiscountInfo(orig, amt, ps, pe)

    # --- unit price: "단가 / <unit>" label + nearest small price ---
    up: UnitPrice | None = None
    label_y: float | None = None
    unit: str | None = None
    for ln in lines:
        um = _UNIT.search(ln.text)
        if um:
            label_y = ln.y_top
            unit = um.group(1)
            break
    if label_y is not None and unit is not None:
        best: tuple[int, float, float] | None = None
        for p in pts:
            if final_tok is not None and p[0] == final_tok[0] and p[1] == final_tok[1]:
                continue  # skip final
            if best is None or abs(p[2] - label_y) < abs(best[2] - label_y):
                best = p
        if best is not None:
            up = UnitPrice(best[0], unit)

    # --- English name (best-effort): mostly-ASCII line with a space ---
    name_en: str | None = None
    for ln in lines:
        t = ln.text.strip()
        if len(t) < 5 or " " not in t:
            continue
        ascii_printable = sum(1 for c in t if 32 < ord(c) < 128)
        if ascii_printable / len(t) > 0.7 and _LATIN.search(t):
            name_en = t
            break

    return PriceTagData(
        item_number=item,
        plus_mark=plus,
        final_price=final_price,
        tag_type=tag,
        discount=disc,
        unit_price=up,
        name_en=name_en,
        raw_text=raw,
    )
