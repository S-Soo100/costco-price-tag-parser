// Quickstart / screenshot demo — parse a bundled fixture, print the result.
// No OCR needed; runs from anywhere in the repo.
//
//   cd packages/dart && dart run example/quickstart.dart
import 'dart:convert';
import 'dart:io';

import 'package:costco_price_tag_parser/costco_price_tag_parser.dart';

void main() {
  final fixtures = jsonDecode(
    File('${_repoRoot()}/spec/fixtures/ocr_raw.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  // A real Costco tag: NIKE synthetic gloves (item + price + unit price).
  final lines = (fixtures['IMG_3379.JPG'] as List)
      .map((e) => OcrLine.fromJson(e as Map<String, dynamic>))
      .toList();

  final tag = parsePriceTag(lines);
  final out = tag.toJson()..remove('rawText'); // drop the OCR blob for a clean view
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(out));
}

String _repoRoot() {
  var dir = Directory.current;
  while (true) {
    if (Directory('${dir.path}/spec/fixtures').existsSync()) return dir.path;
    final parent = dir.parent;
    if (parent.path == dir.path) throw StateError('repo root not found');
    dir = parent;
  }
}
