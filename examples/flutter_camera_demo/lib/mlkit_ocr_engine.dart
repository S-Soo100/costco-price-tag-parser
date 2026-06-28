import 'dart:io';
import 'dart:ui' as ui;

import 'package:costco_price_tag_parser/costco_price_tag_parser.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// On-device OCR via Google ML Kit (Korean script). Produces the same
/// normalized {text, bbox} shape the parser expects, so [parsePriceTag] works
/// unchanged.
///
/// Runs on real iOS/Android devices and the Android emulator. ML Kit text
/// recognition is NOT available on the iOS Simulator.
class MlKitOcrEngine implements OcrEngine {
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.korean);

  @override
  Future<List<OcrLine>> recognize(String imagePath) async {
    final (imgW, imgH) = await _imageSize(imagePath);
    final input = InputImage.fromFilePath(imagePath);
    final recognized = await _recognizer.processImage(input);

    final lines = <OcrLine>[];
    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        final r = line.boundingBox;
        lines.add(OcrLine(
          text: line.text,
          x: imgW == 0 ? 0 : r.left / imgW,
          yTop: imgH == 0 ? 0 : r.top / imgH,
          w: imgW == 0 ? 0 : r.width / imgW,
          h: imgH == 0 ? 0 : r.height / imgH,
          conf: line.confidence ?? 1.0,
        ));
      }
    }
    return lines;
  }

  Future<(double, double)> _imageSize(String path) async {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final size = (image.width.toDouble(), image.height.toDouble());
    image.dispose();
    codec.dispose();
    return size;
  }

  void dispose() => _recognizer.close();
}
