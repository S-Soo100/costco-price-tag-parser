"""Optional OCR boundary. Bring your own engine — the parser only needs OcrLines.

Any object with a ``recognize(image_path) -> list[OcrLine]`` method satisfies this
Protocol (Tesseract, PaddleOCR, a cloud API, macOS Vision via tools/vision_ocr.swift…).
See examples/python_tesseract for a reference adapter.
"""

from __future__ import annotations

from typing import Protocol, runtime_checkable

from .models import OcrLine


@runtime_checkable
class OcrEngine(Protocol):
    def recognize(self, image_path: str) -> list[OcrLine]: ...
