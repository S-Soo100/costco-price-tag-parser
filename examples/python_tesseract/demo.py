"""End-to-end demo: image -> Tesseract OCR -> parse -> JSON.

    python demo.py <image_path>
"""

from __future__ import annotations

import json
import sys

from costco_price_tag_parser import parse_price_tag

from ocr_tesseract import recognize


def main() -> None:
    if len(sys.argv) < 2:
        print("usage: python demo.py <image_path>", file=sys.stderr)
        raise SystemExit(1)
    lines = recognize(sys.argv[1])
    tag = parse_price_tag(lines)
    print(json.dumps(tag.to_dict(), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
