"""Quickstart / screenshot demo — parse a bundled fixture, print the result.

No OCR needed; runs from anywhere in the repo.

    cd packages/python && python example/quickstart.py
"""

from __future__ import annotations

import json
import pathlib

from costco_price_tag_parser import OcrLine, parse_price_tag


def _repo_root() -> pathlib.Path:
    for p in pathlib.Path(__file__).resolve().parents:
        if (p / "spec" / "fixtures").is_dir():
            return p
    raise RuntimeError("repo root not found")


fixtures = json.loads((_repo_root() / "spec" / "fixtures" / "ocr_raw.json").read_text())

# A real Costco tag: NIKE synthetic gloves (item + price + unit price).
tag = parse_price_tag([OcrLine.from_json(e) for e in fixtures["IMG_3379.JPG"]])

out = tag.to_dict()
out.pop("rawText")  # drop the OCR blob for a clean view
print(json.dumps(out, ensure_ascii=False, indent=2))
