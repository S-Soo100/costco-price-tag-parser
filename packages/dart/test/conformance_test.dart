// Conformance suite for the Dart (canonical) parser.
//
//  • "ground truth" group  — the 3 fixtures whose OCR was manually verified
//    against the real photos. These assert real-world correctness.
//  • "golden parity" group — all 46 fixtures must match spec/golden/expected.json,
//    the frozen output of this same canonical parser. The Python/TS ports run an
//    equivalent suite against the SAME golden, guaranteeing cross-language parity.
import 'dart:convert';
import 'dart:io';

import 'package:costco_price_tag_parser/costco_price_tag_parser.dart';
import 'package:test/test.dart';

void main() {
  final root = _repoRoot();
  final fixtures = jsonDecode(
    File('$root/spec/fixtures/ocr_raw.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  PriceTagData parse(String fn) {
    final lines = (fixtures[fn] as List)
        .map((e) => OcrLine.fromJson(e as Map<String, dynamic>))
        .toList();
    return parsePriceTag(lines);
  }

  group('ground truth (human-verified photos)', () {
    test('IMG_3374 — discount tag', () {
      final t = parse('IMG_3374.JPG');
      expect(t.itemNumber, '685246');
      expect(t.plusMark, isTrue);
      expect(t.finalPrice, 349900);
      expect(t.tagType, TagType.discount);
      expect(t.discount?.originalPrice, 389900);
      expect(t.discount?.discountAmount, 40000);
    });

    test('IMG_3379 — regular tag with unit price', () {
      final t = parse('IMG_3379.JPG');
      expect(t.itemNumber, '649221');
      expect(t.finalPrice, 23890);
      expect(t.tagType, TagType.regular);
      expect(t.unitPrice?.value, 11945);
      expect(t.unitPrice?.unit, '개');
    });

    test('IMG_3383 — regular tag with unit price', () {
      final t = parse('IMG_3383.JPG');
      expect(t.itemNumber, '654718');
      expect(t.finalPrice, 119900);
      expect(t.unitPrice?.value, 11990);
      expect(t.unitPrice?.unit, '100G');
    });
  });

  group('golden parity (all fixtures)', () {
    final golden = jsonDecode(
      File('$root/spec/golden/expected.json').readAsStringSync(),
    ) as Map<String, dynamic>;

    test('golden covers every fixture', () {
      expect(golden.keys.toSet(), fixtures.keys.toSet());
    });

    for (final fn in fixtures.keys.toList()..sort()) {
      test(fn, () {
        final got = parse(fn).toJson()..remove('rawText');
        expect(_canon(got), _canon(golden[fn]),
            reason: 'parser output drifted from frozen golden for $fn');
      });
    }
  });

  // Synthetic inputs that the real fixtures don't exercise — they pin the
  // cross-language hazards the review surfaced (see spec/SPEC.md "parity notes").
  group('parity traps (synthetic inputs)', () {
    test('yTop tie resolves to the left-most item (deterministic)', () {
      // Right-most listed first; without the x tiebreak a naive sort keeps it.
      final tag = parsePriceTag(const [
        OcrLine(text: '222222', x: 0.50, yTop: 0.30, w: 0.1, h: 0.05, conf: 1),
        OcrLine(text: '111111', x: 0.10, yTop: 0.30, w: 0.1, h: 0.05, conf: 1),
      ]);
      expect(tag.itemNumber, '111111');
    });

    test('non-ASCII space (NBSP) before 원 still yields the price', () {
      final tag = parsePriceTag(const [
        OcrLine(text: '685246', x: 0.3, yTop: 0.1, w: 0.1, h: 0.03, conf: 1),
        OcrLine(text: '12345 원', x: 0.3, yTop: 0.5, w: 0.2, h: 0.10, conf: 1),
      ]);
      expect(tag.finalPrice, 12345);
      expect(tag.itemNumber, '685246');
    });
  });
}

/// Order-independent canonical JSON string for deep comparison.
String _canon(Object? v) {
  if (v is Map) {
    final keys = v.keys.map((k) => k.toString()).toList()..sort();
    return '{${keys.map((k) => '${jsonEncode(k)}:${_canon(v[k])}').join(',')}}';
  }
  if (v is List) return '[${v.map(_canon).join(',')}]';
  return jsonEncode(v);
}

String _repoRoot() {
  var dir = Directory.current;
  while (true) {
    if (Directory('${dir.path}/spec/fixtures').existsSync()) return dir.path;
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('repo root not found from ${Directory.current.path}');
    }
    dir = parent;
  }
}
