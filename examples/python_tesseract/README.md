# Example — Python + Tesseract

Reference OCR adapter showing how to feed the parser from
[Tesseract](https://github.com/tesseract-ocr/tesseract). **Optional** — the
parser core has zero dependencies; any OCR that yields `OcrLine`s works.

## Prerequisites

```bash
# system tesseract binary + Korean traineddata
brew install tesseract tesseract-lang        # macOS
# sudo apt install tesseract-ocr tesseract-ocr-kor   # Debian/Ubuntu

# python deps + the parser
pip install -e ../../packages/python
pip install -r requirements.txt
```

## Run

```bash
python demo.py /path/to/price_tag.jpg
```

Prints the parsed `PriceTagData` as JSON.

## How it works

`ocr_tesseract.recognize()` runs `pytesseract.image_to_data`, groups word boxes
into lines, normalizes the boxes to `0..1` (origin top-left), and sorts them into
reading order — exactly the `OcrLine[]` shape `parse_price_tag()` expects.

> No tesseract? On macOS you can generate the same `OcrLine` shape with
> `tools/vision_ocr.swift` (Apple Vision) instead.
