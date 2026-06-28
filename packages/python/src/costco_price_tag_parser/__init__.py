"""Costco A-format price-tag parser — pure Python, OCR-engine-agnostic.

>>> from costco_price_tag_parser import parse_price_tag, OcrLine
>>> lines = [OcrLine.from_json(e) for e in ocr_output]  # your OCR -> OcrLine[]
>>> tag = parse_price_tag(lines)
>>> tag.item_number
'685246'
"""

from .models import DiscountInfo, OcrLine, PriceTagData, TagType, UnitPrice
from .ocr_engine import OcrEngine
from .parser import parse_price_tag

__all__ = [
    "parse_price_tag",
    "OcrLine",
    "PriceTagData",
    "DiscountInfo",
    "UnitPrice",
    "TagType",
    "OcrEngine",
]

__version__ = "0.1.0"
