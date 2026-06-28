"""Validates parser output against spec/schema/price_tag_data.schema.json.

This wires the otherwise-decorative JSON Schema into the test suite. Because all
three ports produce identical output (proven by the golden-parity tests),
validating the Python output validates the shared output shape for every language.

Note: the schema checks STRUCTURE (keys, types, enum, itemNumber pattern), not
semantic validity — e.g. an OCR-mangled date string still passes. See the
"Known limitations" section in the root README.
"""

from __future__ import annotations

import json
import pathlib

import pytest
from jsonschema import Draft202012Validator

from costco_price_tag_parser import OcrLine, parse_price_tag


def _repo_root() -> pathlib.Path:
    for p in pathlib.Path(__file__).resolve().parents:
        if (p / "spec" / "fixtures").is_dir():
            return p
    raise RuntimeError("repo root (with spec/fixtures) not found")


ROOT = _repo_root()
FIXTURES = json.loads((ROOT / "spec" / "fixtures" / "ocr_raw.json").read_text())
SCHEMA = json.loads((ROOT / "spec" / "schema" / "price_tag_data.schema.json").read_text())
VALIDATOR = Draft202012Validator(SCHEMA)


@pytest.mark.parametrize("fn", sorted(FIXTURES.keys()))
def test_full_output_matches_schema(fn: str):
    out = parse_price_tag([OcrLine.from_json(e) for e in FIXTURES[fn]]).to_dict()
    errors = sorted(VALIDATOR.iter_errors(out), key=lambda e: list(e.path))
    assert not errors, f"{fn}: " + "; ".join(e.message for e in errors)
