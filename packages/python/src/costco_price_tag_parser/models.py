"""Data model for the Costco price-tag parser (mirrors spec/schema)."""

from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from typing import Any


class TagType(str, Enum):
    REGULAR = "regular"
    DISCOUNT = "discount"
    UNKNOWN = "unknown"


@dataclass(frozen=True)
class OcrLine:
    """One recognized text line + its normalized bounding box (origin top-left)."""

    text: str
    x: float
    y_top: float
    w: float
    h: float
    conf: float

    @staticmethod
    def from_json(j: dict[str, Any]) -> "OcrLine":
        return OcrLine(
            text=j["text"],
            x=float(j["x"]),
            y_top=float(j["yTop"]),
            w=float(j["w"]),
            h=float(j["h"]),
            conf=float(j["conf"]),
        )


@dataclass(frozen=True)
class UnitPrice:
    value: int
    unit: str  # 개, 100G, 10G, 100ml, ...

    def to_dict(self) -> dict[str, object]:
        return {"value": self.value, "unit": self.unit}


@dataclass(frozen=True)
class DiscountInfo:
    original_price: int | None = None
    discount_amount: int | None = None
    period_start: str | None = None  # ISO date, best-effort
    period_end: str | None = None

    def to_dict(self) -> dict[str, object]:
        return {
            "originalPrice": self.original_price,
            "discountAmount": self.discount_amount,
            "periodStart": self.period_start,
            "periodEnd": self.period_end,
        }


@dataclass(frozen=True)
class PriceTagData:
    schema_version: str = "0.1"
    item_number: str | None = None  # 6-digit tracking key
    plus_mark: bool = False
    name_ko: str | None = None  # reserved — not extracted
    model: str | None = None  # reserved — not extracted
    name_en: str | None = None
    final_price: int | None = None
    tag_type: TagType = TagType.UNKNOWN
    discount: DiscountInfo | None = None
    unit_price: UnitPrice | None = None
    raw_text: str = ""

    def to_dict(self) -> dict[str, object]:
        """JSON-ready dict with the canonical (camelCase) keys from spec/schema."""
        return {
            "schemaVersion": self.schema_version,
            "itemNumber": self.item_number,
            "plusMark": self.plus_mark,
            "nameKo": self.name_ko,
            "model": self.model,
            "nameEn": self.name_en,
            "finalPrice": self.final_price,
            "tagType": self.tag_type.value,
            "discount": self.discount.to_dict() if self.discount else None,
            "unitPrice": self.unit_price.to_dict() if self.unit_price else None,
            "rawText": self.raw_text,
        }
