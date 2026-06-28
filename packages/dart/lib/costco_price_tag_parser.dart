/// Costco A-format price tag parser — pure Dart, OCR-engine-agnostic.
///
/// Feed it the OCR text lines (with bounding boxes) of a Costco rack card and
/// it returns structured [PriceTagData]. Bring your own OCR: any engine that
/// emits `{text, x, yTop, w, h, conf}` lines works (ML Kit, Vision, Tesseract…).
///
/// ```dart
/// final lines = await myOcrEngine.recognize(imagePath);
/// final tag = parsePriceTag(lines);
/// print(tag.itemNumber);  // e.g. "685246"
/// ```
library;

export 'src/price_tag_data.dart';
export 'src/ocr_engine.dart';
export 'src/price_tag_parser.dart';
