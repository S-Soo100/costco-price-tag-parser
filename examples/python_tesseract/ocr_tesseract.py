"""Reference OCR adapter: Tesseract -> list[OcrLine].

OPTIONAL — not part of the parser core. Bring any OCR you like; this just shows
one way to produce the `OcrLine`s the parser consumes.

Requires the tesseract binary (with Korean traineddata) and:
    pip install pytesseract Pillow
"""

from __future__ import annotations

import pytesseract
from PIL import Image

from costco_price_tag_parser import OcrLine


def recognize(image_path: str, lang: str = "kor+eng") -> list[OcrLine]:
    img = Image.open(image_path)
    width, height = img.size
    data = pytesseract.image_to_data(img, lang=lang, output_type=pytesseract.Output.DICT)

    # Group word boxes into text lines by (block, paragraph, line).
    groups: dict[tuple[int, int, int], dict] = {}
    for i in range(len(data["text"])):
        text = data["text"][i].strip()
        if not text:
            continue
        key = (data["block_num"][i], data["par_num"][i], data["line_num"][i])
        left, top = data["left"][i], data["top"][i]
        right, bottom = left + data["width"][i], top + data["height"][i]
        g = groups.setdefault(
            key, {"words": [], "left": left, "top": top, "right": right, "bottom": bottom, "conf": []}
        )
        g["words"].append(text)
        g["left"] = min(g["left"], left)
        g["top"] = min(g["top"], top)
        g["right"] = max(g["right"], right)
        g["bottom"] = max(g["bottom"], bottom)
        g["conf"].append(float(data["conf"][i]))

    lines: list[OcrLine] = []
    for g in groups.values():
        lines.append(
            OcrLine(
                text=" ".join(g["words"]),
                x=g["left"] / width,
                y_top=g["top"] / height,
                w=(g["right"] - g["left"]) / width,
                h=(g["bottom"] - g["top"]) / height,
                conf=max(0.0, sum(g["conf"]) / len(g["conf"]) / 100.0),
            )
        )

    # Reading order: top-to-bottom, then left-to-right (what the parser expects).
    lines.sort(key=lambda o: (round(o.y_top, 2), o.x))
    return lines
