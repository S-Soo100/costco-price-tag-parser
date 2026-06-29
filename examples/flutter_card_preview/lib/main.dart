// Device-free preview: load a bundled fixture, parse it, render the result card.
// No camera, no ML Kit — runs on web/desktop. Handy for screenshots.
//
//   flutter run -d chrome      (or:  flutter run -d macos)
import 'dart:convert';

import 'package:costco_price_tag_parser/costco_price_tag_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

void main() => runApp(const PreviewApp());

class PreviewApp extends StatelessWidget {
  const PreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Costco Price Tag Parser — Preview',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF0060A9), useMaterial3: true),
      home: const PreviewScreen(),
    );
  }
}

class PreviewScreen extends StatefulWidget {
  const PreviewScreen({super.key});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  late final Future<PriceTagData> _tag = _load();

  Future<PriceTagData> _load() async {
    final raw = await rootBundle.loadString('assets/sample_ocr.json');
    final lines = (jsonDecode(raw) as List)
        .map((e) => OcrLine.fromJson(e as Map<String, dynamic>))
        .toList();
    return parsePriceTag(lines);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF2F6),
      body: Center(
        child: FutureBuilder<PriceTagData>(
          future: _tag,
          builder: (context, snap) =>
              snap.hasData ? _ResultCard(snap.data!) : const CircularProgressIndicator(),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard(this.tag);

  final PriceTagData tag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = tag.discount;
    final u = tag.unitPrice;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Card(
        elevation: 3,
        margin: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_offer_outlined, size: 20),
                  const SizedBox(width: 8),
                  Text('Costco 가격표 → PriceTagData', style: theme.textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'parsed by costco_price_tag_parser (Dart)',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
              const Divider(height: 28),
              if (tag.nameEn != null) ...[
                Text(tag.nameEn!, style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
              ],
              _row(context, '품목번호 / Item', '${tag.itemNumber ?? '—'}${tag.plusMark ? ' +' : ''}'),
              _row(context, '최종가 / Price',
                  tag.finalPrice == null ? '—' : '${_won(tag.finalPrice!)}원'),
              _row(context, '유형 / Type', tag.tagType.name),
              if (u != null) _row(context, '단가 / Unit', '${_won(u.value)}원 / ${u.unit}'),
              if (d != null)
                _row(context, '할인 / Discount',
                    '정가 ${_won(d.originalPrice ?? 0)}원 · -${_won(d.discountAmount ?? 0)}원'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 150,
              child: Text(label, style: const TextStyle(color: Colors.black54)),
            ),
            Expanded(
              child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

  // Thousands separators without an intl dependency.
  static String _won(int value) {
    final s = value.toString();
    final out = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
      out.write(s[i]);
    }
    return out.toString();
  }
}
