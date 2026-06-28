// Regenerates spec/golden/expected.json from the CANONICAL Dart parser.
//
// The Dart parser is the source of truth; this dumps its output over every
// fixture so the Python/TypeScript ports can assert byte-for-byte parity.
// Run from anywhere inside the repo:  dart run tool/gen_golden.dart
//
// `rawText` is intentionally omitted from the golden — it is just the input
// lines joined by '\n' (a pass-through, not parsing logic). See spec/CONFORMANCE.md.
import 'dart:convert';
import 'dart:io';

import 'package:costco_price_tag_parser/costco_price_tag_parser.dart';

void main() {
  final root = _repoRoot();
  final fixtures = File('$root/spec/fixtures/ocr_raw.json');
  final data = jsonDecode(fixtures.readAsStringSync()) as Map<String, dynamic>;

  final out = <String, dynamic>{};
  for (final fn in data.keys.toList()..sort()) {
    final lines = (data[fn] as List)
        .map((e) => OcrLine.fromJson(e as Map<String, dynamic>))
        .toList();
    out[fn] = parsePriceTag(lines).toJson()..remove('rawText');
  }

  final golden = File('$root/spec/golden/expected.json')
    ..createSync(recursive: true);
  golden.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(out)}\n');
  stdout.writeln('wrote spec/golden/expected.json (${out.length} images)');
}

/// Walks up from the current directory to the repo root (the dir holding
/// `spec/fixtures`), so the script runs from any cwd.
String _repoRoot() {
  var dir = Directory.current;
  while (true) {
    if (Directory('${dir.path}/spec/fixtures').existsSync()) return dir.path;
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('repo root (with spec/fixtures) not found from ${Directory.current.path}');
    }
    dir = parent;
  }
}
