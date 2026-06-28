import 'price_tag_data.dart';

/// Abstraction over the platform OCR engine.
///
/// Production impl wraps `google_mlkit_text_recognition` (on-device).
/// Tests/desktop use fixtures produced by tools/vision_ocr.swift.
/// Either way the output is a list of [OcrLine]s the parser consumes unchanged.
abstract class OcrEngine {
  Future<List<OcrLine>> recognize(String imagePath);
}
