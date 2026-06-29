# costco_price_tag_parser (Dart)

Heuristic parser that turns the OCR text lines of a **Costco A-format price tag**
into a structured `PriceTagData`. Pure Dart, zero dependencies, OCR-engine-agnostic.
This is the **canonical** implementation of the
[costco-price-tag-parser](https://github.com/S-Soo100/costco-price-tag-parser)
monorepo (Dart · Python · TypeScript).

> Algorithm: [`spec/SPEC.md`](https://github.com/S-Soo100/costco-price-tag-parser/blob/main/spec/SPEC.md).

## Install

```sh
dart pub add costco_price_tag_parser
```

## Use

Bring your own OCR. Feed the parser a list of `OcrLine`s (normalized boxes,
origin top-left, reading order):

```dart
import 'package:costco_price_tag_parser/costco_price_tag_parser.dart';

final lines = await myOcr.recognize(imagePath); // List<OcrLine>
final tag = parsePriceTag(lines);

print(tag.itemNumber); // "649221"
print(tag.finalPrice); // 23890
print(tag.tagType);    // TagType.regular
print(tag.toJson());   // Map<String, dynamic>
```

See
[examples/flutter_camera_demo](https://github.com/S-Soo100/costco-price-tag-parser/tree/main/examples/flutter_camera_demo)
for a reference Google ML Kit adapter (optional — any engine producing
`OcrLine`s works).

## Develop

```sh
dart pub get
dart test       # conformance against the shared spec/golden
dart analyze
```

After any change to the parser, regenerate the shared golden oracle so the other
language ports stay in sync:

```sh
dart run tool/gen_golden.dart
```
