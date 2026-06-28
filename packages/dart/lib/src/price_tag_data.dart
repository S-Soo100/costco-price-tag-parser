/// Structured result of parsing a Costco price tag (A-format rack card).
///
/// Engine-agnostic: produced from a list of [OcrLine]s, which both the desktop
/// Vision probe and on-device ML Kit emit in the same shape.
library;

enum TagType { regular, discount, unknown }

/// One recognized text line + its normalized bounding box (origin top-left).
class OcrLine {
  final String text;
  final double x, yTop, w, h, conf;
  const OcrLine({
    required this.text,
    required this.x,
    required this.yTop,
    required this.w,
    required this.h,
    required this.conf,
  });

  factory OcrLine.fromJson(Map<String, dynamic> j) => OcrLine(
        text: j['text'] as String,
        x: (j['x'] as num).toDouble(),
        yTop: (j['yTop'] as num).toDouble(),
        w: (j['w'] as num).toDouble(),
        h: (j['h'] as num).toDouble(),
        conf: (j['conf'] as num).toDouble(),
      );
}

class UnitPrice {
  final int value;
  final String unit; // 개, 100G, 10G, 100ml, ...
  const UnitPrice(this.value, this.unit);
  Map<String, dynamic> toJson() => {'value': value, 'unit': unit};
  @override
  String toString() => '$value/$unit';
}

class DiscountInfo {
  final int? originalPrice;
  final int? discountAmount;
  final String? periodStart; // ISO date (best-effort; OCR can mangle separators)
  final String? periodEnd;
  const DiscountInfo({
    this.originalPrice,
    this.discountAmount,
    this.periodStart,
    this.periodEnd,
  });
  Map<String, dynamic> toJson() => {
        'originalPrice': originalPrice,
        'discountAmount': discountAmount,
        'periodStart': periodStart,
        'periodEnd': periodEnd,
      };
}

class PriceTagData {
  final String schemaVersion;
  final String? itemNumber; // 6-digit 품목번호 (tracking key)
  final bool plusMark; // '+' next to item number (meaning TBD; kept raw)
  final String? nameKo;
  final String? model;
  final String? nameEn;
  final int? finalPrice; // 원
  final TagType tagType;
  final DiscountInfo? discount;
  final UnitPrice? unitPrice;
  final String rawText; // full OCR text, always kept for re-parse / admin review

  const PriceTagData({
    this.schemaVersion = '0.1',
    this.itemNumber,
    this.plusMark = false,
    this.nameKo,
    this.model,
    this.nameEn,
    this.finalPrice,
    this.tagType = TagType.unknown,
    this.discount,
    this.unitPrice,
    this.rawText = '',
  });

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'itemNumber': itemNumber,
        'plusMark': plusMark,
        'nameKo': nameKo,
        'model': model,
        'nameEn': nameEn,
        'finalPrice': finalPrice,
        'tagType': tagType.name,
        'discount': discount?.toJson(),
        'unitPrice': unitPrice?.toJson(),
        'rawText': rawText,
      };
}
