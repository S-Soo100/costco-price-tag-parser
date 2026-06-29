import 'price_tag_data.dart';

/// Parses OCR lines from a Costco A-format rack card into [PriceTagData].
///
/// Heuristics validated against 46 real photos (see ../../../spec/SPEC.md):
///  - itemNumber: a line that is ONLY a 6-digit number (top-left), else topmost 6-digit.
///  - finalPrice: the physically LARGEST price token (biggest glyph height) —
///    original price / unit price always print smaller.
///  - discount: presence of "할인행사" label; original = a price > final,
///    amount = original - final, period = the two dates on the tag.
///  - unitPrice: the small price next to a `단가 / <unit>` label.
PriceTagData parsePriceTag(List<OcrLine> lines) {
  final raw = lines.map((l) => l.text).join('\n');
  final blob = lines.map((l) => l.text).join(' ');

  // --- itemNumber: prefer a line that is ONLY a 6-digit number. ---
  String? item;
  bool plus = false;
  OcrLine? pick;
  final pures = lines
      .where((l) => _pureItemRe.hasMatch(l.text.replaceAll(' ', '')))
      .toList()
    ..sort(_byReadingOrder);
  if (pures.isNotEmpty) {
    pick = pures.first;
  } else {
    final any = lines
        .where((l) => _itemRe.hasMatch(l.text.replaceAll(' ', '')))
        .toList()
      ..sort(_byReadingOrder);
    if (any.isNotEmpty) pick = any.first;
  }
  if (pick != null) {
    final m = _itemRe.firstMatch(pick.text.replaceAll(' ', ''))!;
    item = m.group(1);
    plus = m.group(2) == '+';
  }

  // --- price tokens with glyph height + vertical position ---
  final pts = <_PT>[];
  for (final l in lines) {
    int? v;
    final m = _priceRe.firstMatch(l.text);
    if (m != null) {
      v = int.tryParse(m.group(1)!.replaceAll(',', ''));
    } else {
      final cm = _commaNum.firstMatch(l.text); // price whose '원' got split off
      // …unless it's a nutrition/weight figure (e.g. "2,142kcal", "1,584g"),
      // which is not a price. See spec/SPEC.md.
      if (cm != null && !_weightUnitRe.hasMatch(l.text.substring(cm.end))) {
        v = int.tryParse(cm.group(0)!.replaceAll(',', ''));
      }
    }
    if (v != null) pts.add(_PT(v, l.h, l.yTop));
  }
  _PT? finalTok;
  for (final p in pts) {
    if (finalTok == null || p.h > finalTok.h) finalTok = p;
  }
  final finalPrice = finalTok?.v;

  // --- tag type + discount ---
  final isDisc = blob.contains('할인행사');
  final TagType type;
  if (item == null && finalPrice == null) {
    type = TagType.unknown;
  } else {
    type = isDisc ? TagType.discount : TagType.regular;
  }
  DiscountInfo? disc;
  if (type == TagType.discount) {
    int? orig;
    if (finalPrice != null) {
      for (final p in pts) {
        if (p.v > finalPrice) orig = (orig == null || p.v > orig) ? p.v : orig;
      }
    }
    final amt = (orig != null && finalPrice != null) ? orig - finalPrice : null;
    // Keep only calendar-plausible dates (OCR mangles them, e.g. 2026-06-70).
    final dates = _dateRe.allMatches(blob).map(_isoDate).whereType<String>().toList();
    final ps = dates.isNotEmpty ? dates[0] : null;
    final pe = dates.length > 1 ? dates[1] : null;
    disc = DiscountInfo(originalPrice: orig, discountAmount: amt, periodStart: ps, periodEnd: pe);
  }

  // --- unit price: "단가 / <unit>" label + nearest small price ---
  UnitPrice? up;
  double? labelY;
  String? unit;
  for (final l in lines) {
    final um = _unitRe.firstMatch(l.text);
    if (um != null) {
      labelY = l.yTop;
      unit = um.group(1);
      break;
    }
  }
  if (labelY != null && unit != null) {
    _PT? best;
    for (final p in pts) {
      if (finalTok != null && p.v == finalTok.v && p.h == finalTok.h) continue;
      if (best == null || (p.y - labelY).abs() < (best.y - labelY).abs()) best = p;
    }
    if (best != null) up = UnitPrice(best.v, unit);
  }

  // --- English name (best-effort): mostly-ASCII line with a space ---
  String? nameEn;
  for (final l in lines) {
    final t = l.text.trim();
    if (t.runes.length < 5 || !t.contains(' ')) continue;
    final ascii = t.runes.where((r) => r > 32 && r < 128).length;
    if (ascii / t.runes.length > 0.7 && _hasLatin.hasMatch(t)) {
      nameEn = t;
      break;
    }
  }

  return PriceTagData(
    itemNumber: item,
    plusMark: plus,
    finalPrice: finalPrice,
    tagType: type,
    discount: disc,
    unitPrice: up,
    nameEn: nameEn,
    rawText: raw,
  );
}

// Digit boundaries so a 6-digit run inside a longer number (barcodes, "ITEM: 3663092")
// is NOT mistaken for an item number.
final _itemRe = RegExp(r'(?<!\d)(\d{6})(?!\d)(\+?)');
final _pureItemRe = RegExp(r'^(\d{6})(\+?)$');
final _priceRe = RegExp(r'(\d[\d,]{2,})\s*원');
final _commaNum = RegExp(r'\d{1,3}(?:,\d{3})+');
// A comma-number followed by one of these is a nutrition/weight figure, not a price.
final _weightUnitRe = RegExp(r'^\s*(?:kcal|kg|mg|ml|g|l)', caseSensitive: false);
final _dateRe = RegExp(r'(\d{4})[.\/](\d{1,2})[.\/]?(\d{1,2})');
final _unitRe = RegExp(r'단가\s*/\s*([^\s]+)');
final _hasLatin = RegExp(r'[A-Za-z]');

/// Stable reading-order comparator: top-to-bottom, then left-to-right.
/// The explicit `x` tiebreak makes selection deterministic when two lines share
/// the same `yTop` (Dart's List.sort is not guaranteed stable). See spec/SPEC.md.
int _byReadingOrder(OcrLine a, OcrLine b) {
  final c = a.yTop.compareTo(b.yTop);
  return c != 0 ? c : a.x.compareTo(b.x);
}

class _PT {
  final int v;
  final double h, y;
  const _PT(this.v, this.h, this.y);
}

String _pad(String? s) => (s ?? '').padLeft(2, '0');

/// Formats a date match as ISO `YYYY-MM-DD`, or null when month/day are out of
/// calendar range (OCR routinely mangles dates, e.g. `2026.06.70`).
String? _isoDate(RegExpMatch m) {
  final y = int.parse(m.group(1)!);
  final mo = int.parse(m.group(2)!);
  final d = int.parse(m.group(3)!);
  if (y < 2000 || y > 2099 || mo < 1 || mo > 12 || d < 1 || d > 31) return null;
  return '${m.group(1)}-${_pad(m.group(2))}-${_pad(m.group(3))}';
}
