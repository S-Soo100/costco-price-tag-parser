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
      if (cm != null) v = int.tryParse(cm.group(0)!.replaceAll(',', ''));
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
    final dates = _dateRe.allMatches(blob).toList();
    String? ps, pe;
    if (dates.isNotEmpty) {
      ps = '${dates[0].group(1)}-${_pad(dates[0].group(2))}-${_pad(dates[0].group(3))}';
    }
    if (dates.length > 1) {
      pe = '${dates[1].group(1)}-${_pad(dates[1].group(2))}-${_pad(dates[1].group(3))}';
    }
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

final _itemRe = RegExp(r'(\d{6})(\+?)');
final _pureItemRe = RegExp(r'^(\d{6})(\+?)$');
final _priceRe = RegExp(r'(\d[\d,]{2,})\s*원');
final _commaNum = RegExp(r'\d{1,3}(?:,\d{3})+');
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
