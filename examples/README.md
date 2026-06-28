# Examples

These show **one** way to wire an OCR engine into the parser per language. They
are **optional** — the parser core depends on no OCR library. As long as you can
produce `OcrLine`s (`{ text, x, yTop, w, h, conf }`, normalized `0..1`, origin
top-left, reading order), any engine works.

| example | OCR | runs on |
|---------|-----|---------|
| [`flutter_camera_demo`](flutter_camera_demo) | Google ML Kit (on-device) | real iOS/Android device or Android emulator (not iOS Simulator) |
| [`python_tesseract`](python_tesseract) | Tesseract (system binary) | desktop/server with `tesseract` installed |
| [`ts_tesseract`](ts_tesseract) | tesseract.js (WASM) | Node.js (no system binary) |

> **No OCR installed?** On macOS, `tools/vision_ocr.swift` emits the same
> `OcrLine` JSON via Apple Vision — handy for trying the parser without setting
> up an OCR engine.
