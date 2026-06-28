import 'dart:io';

import 'package:costco_price_tag_parser/costco_price_tag_parser.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'mlkit_ocr_engine.dart';

/// Minimal end-to-end demo: pick a price-tag photo → ML Kit OCR → parse → show.
class DemoScreen extends StatefulWidget {
  const DemoScreen({super.key});

  @override
  State<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen> {
  final ImagePicker _picker = ImagePicker();
  final MlKitOcrEngine _ocr = MlKitOcrEngine();

  File? _image;
  PriceTagData? _result;
  bool _busy = false;
  String? _error;

  Future<void> _scan(ImageSource source) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final picked = await _picker.pickImage(source: source);
      if (picked == null) {
        setState(() => _busy = false);
        return;
      }
      final lines = await _ocr.recognize(picked.path);
      final tag = parsePriceTag(lines);
      if (!mounted) return;
      setState(() {
        _image = File(picked.path);
        _result = tag;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _busy = false;
      });
    }
  }

  @override
  void dispose() {
    _ocr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Costco Price Tag Parser')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : () => _scan(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('촬영'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _busy ? null : () => _scan(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('갤러리'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_busy) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
          if (_error != null)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(padding: const EdgeInsets.all(12), child: Text('오류: $_error')),
            ),
          if (_image != null) ...[
            const SizedBox(height: 8),
            ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(_image!, height: 220, fit: BoxFit.cover)),
          ],
          if (_result != null) ...[
            const SizedBox(height: 16),
            _ResultCard(_result!),
            const SizedBox(height: 16),
            ExpansionTile(
              title: const Text('OCR 원문 (rawText)'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(_result!.rawText, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard(this.tag);

  final PriceTagData tag;

  @override
  Widget build(BuildContext context) {
    final d = tag.discount;
    final u = tag.unitPrice;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row('품목번호', '${tag.itemNumber ?? '—'}${tag.plusMark ? ' +' : ''}'),
            _row('최종가', tag.finalPrice == null ? '—' : '${tag.finalPrice}원'),
            _row('유형', tag.tagType.name),
            if (d != null) _row('할인', '정가 ${d.originalPrice}원 · -${d.discountAmount}원 · ${d.periodStart ?? '?'}~${d.periodEnd ?? '?'}'),
            if (u != null) _row('단가', '${u.value}원 / ${u.unit}'),
            if (tag.nameEn != null) _row('영문명', tag.nameEn!),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 80, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
            Expanded(child: Text(value)),
          ],
        ),
      );
}
