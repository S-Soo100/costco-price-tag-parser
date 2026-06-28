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
