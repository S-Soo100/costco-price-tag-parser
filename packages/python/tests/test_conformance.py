"""Conformance suite — same fixtures + golden as the Dart/TS ports.

See ../../../spec/CONFORMANCE.md.
"""

from __future__ import annotations

import json
import pathlib

import pytest

from costco_price_tag_parser import OcrLine, parse_price_tag


def _repo_root() -> pathlib.Path:
    for p in pathlib.Path(__file__).resolve().parents:
        if (p / "spec" / "fixtures").is_dir():
            return p
    raise RuntimeError("repo root (with spec/fixtures) not found")


ROOT = _repo_root()
FIXTURES = json.loads((ROOT / "spec" / "fixtures" / "ocr_raw.json").read_text())
GOLDEN = json.loads((ROOT / "spec" / "golden" / "expected.json").read_text())


def _parse(fn: str):
    return parse_price_tag([OcrLine.from_json(e) for e in FIXTURES[fn]])


# ── ground truth (human-verified photos) ───────────────────────────────
def test_img_3374_discount():
    t = _parse("IMG_3374.JPG")
    assert t.item_number == "685246"
    assert t.plus_mark is True
    assert t.final_price == 349900
    assert t.tag_type.value == "discount"
    assert t.discount is not None
    assert t.discount.original_price == 389900
    assert t.discount.discount_amount == 40000


def test_img_3379_regular_unit():
    t = _parse("IMG_3379.JPG")
    assert t.item_number == "649221"
    assert t.final_price == 23890
    assert t.tag_type.value == "regular"
    assert t.unit_price is not None and t.unit_price.value == 11945
    assert t.unit_price.unit == "개"


def test_img_3383_regular_unit():
    t = _parse("IMG_3383.JPG")
    assert t.item_number == "654718"
    assert t.final_price == 119900
    assert t.unit_price is not None and t.unit_price.value == 11990
    assert t.unit_price.unit == "100G"


# ── golden parity (all 46) ─────────────────────────────────────────────
def test_golden_covers_every_fixture():
    assert set(GOLDEN.keys()) == set(FIXTURES.keys())


@pytest.mark.parametrize("fn", sorted(FIXTURES.keys()))
def test_golden_parity(fn: str):
    got = _parse(fn).to_dict()
    got.pop("rawText")  # excluded from golden (pass-through)
    assert got == GOLDEN[fn], f"drift from frozen golden for {fn}"


# ── parity traps (synthetic inputs) ────────────────────────────────────
# Cross-language hazards the real fixtures don't exercise (see spec/SPEC.md).
def test_trap_ytop_tie_resolves_leftmost():
    # Right-most listed first; without the x tiebreak a stable sort keeps it.
    tag = parse_price_tag(
        [
            OcrLine("222222", 0.50, 0.30, 0.1, 0.05, 1.0),
            OcrLine("111111", 0.10, 0.30, 0.1, 0.05, 1.0),
        ]
    )
    assert tag.item_number == "111111"


def test_trap_unicode_space_before_won():
    # NBSP (U+00A0) before 원 — would be missed if `\s` were ASCII-only (re.ASCII).
    tag = parse_price_tag(
        [
            OcrLine("685246", 0.3, 0.1, 0.1, 0.03, 1.0),
            OcrLine("12345 원", 0.3, 0.5, 0.2, 0.10, 1.0),
        ]
    )
    assert tag.final_price == 12345
    assert tag.item_number == "685246"


def test_trap_weight_figure_not_price():
    # "1,584g" is taller (bigger h) — without the weight guard it would win.
    tag = parse_price_tag(
        [
            OcrLine("685246", 0.3, 0.1, 0.1, 0.03, 1.0),
            OcrLine("1,584g", 0.3, 0.4, 0.2, 0.20, 1.0),
            OcrLine("9,900원", 0.3, 0.6, 0.2, 0.10, 1.0),
        ]
    )
    assert tag.final_price == 9900
    assert tag.item_number == "685246"


def test_trap_six_digits_inside_longer_run_not_item():
    assert parse_price_tag([OcrLine("ITEM: 3663092", 0.1, 0.3, 0.3, 0.05, 1.0)]).item_number is None
    # …but a properly bounded 6-digit run still is.
    assert parse_price_tag([OcrLine("#512905", 0.1, 0.3, 0.2, 0.05, 1.0)]).item_number == "512905"


def test_trap_implausible_date_dropped():
    tag = parse_price_tag(
        [
            OcrLine("685246", 0.3, 0.1, 0.1, 0.03, 1.0),
            OcrLine("할인행사", 0.3, 0.2, 0.2, 0.03, 1.0),
            OcrLine("10,000원", 0.3, 0.5, 0.2, 0.20, 1.0),
            OcrLine("20,000원", 0.3, 0.3, 0.2, 0.05, 1.0),
            OcrLine("2026.13.45", 0.3, 0.7, 0.2, 0.03, 1.0),
        ]
    )
    assert tag.tag_type.value == "discount"
    assert tag.discount is not None
    assert tag.discount.original_price == 20000
    assert tag.discount.period_start is None
    assert tag.discount.period_end is None
