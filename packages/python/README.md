# costco-price-tag-parser (Python)

Heuristic parser that turns the OCR text lines of a **Costco A-format price tag**
into structured `PriceTagData`. Pure Python, zero runtime dependencies,
OCR-engine-agnostic.

> Part of the [costco-price-tag-parser](../../README.md) monorepo (Dart · Python · TypeScript).
> Algorithm: [`spec/SPEC.md`](../../spec/SPEC.md).

## Install

```bash
pip install costco-price-tag-parser
```

## Use

Bring your own OCR. Feed the parser a list of `OcrLine`s (normalized boxes,
origin top-left, reading order):

```python
from costco_price_tag_parser import parse_price_tag, OcrLine

# Each line: {text, x, yTop, w, h, conf} normalized 0..1
lines = [OcrLine.from_json(e) for e in your_ocr_output]

tag = parse_price_tag(lines)
print(tag.item_number)   # "685246"
print(tag.final_price)   # 349900
print(tag.to_dict())     # JSON-ready (camelCase keys)
```

See [`examples/python_tesseract`](../../examples/python_tesseract) for a reference
OCR adapter (optional — any engine producing `OcrLine`s works).

## Develop

```bash
python -m venv .venv && source .venv/bin/activate
pip install -e ".[dev]"
pytest          # conformance against the shared spec/golden
mypy src
ruff check .
```
