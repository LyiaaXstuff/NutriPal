import 'dart:io';

import 'package:flutter/material.dart';

import '../models/nutrition_label_data.dart';
import '../widgets/nutrition_table.dart';
import '../widgets/nutrition_portion_card.dart';

class ExtractedNutritionReviewScreen extends StatelessWidget {
  final NutritionLabelData data;
  final String? sourceImagePath;
  const ExtractedNutritionReviewScreen({
    super.key,
    required this.data,
    this.sourceImagePath,
  });

  static const _purple = Color(0xFF4B2E83);
  String _number(double n) =>
      n == n.roundToDouble() ? n.toInt().toString() : n.toString();

  @override
  Widget build(BuildContext context) {
    final serving = data.hasServingSize
        ? '${_number(data.servingSizeAmount!)} ${data.servingSizeUnit}'
        : 'Not detected';
    return Scaffold(
      backgroundColor: const Color(0xFFFCFAFF),
      appBar: AppBar(
        title: const Text('Review nutrition'),
        foregroundColor: _purple,
        backgroundColor: const Color(0xFFFCFAFF),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Check the extracted information',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                color: Color(0xFF25104F),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Nutrients follow the order on your label. Compare the values with the photo before using them.',
              style: TextStyle(color: Color(0xFF67558E), height: 1.5),
            ),
            const SizedBox(height: 20),
            Text(
              'Read with ${data.extractionMethod}',
              style: const TextStyle(color: Color(0xFF67558E)),
            ),
            const SizedBox(height: 12),
            _card(
              Column(
                children: [
                  _info('Serving size', serving),
                  _info(
                    'Servings per package',
                    data.servingsPerPackage == null
                        ? 'Not detected'
                        : _number(data.servingsPerPackage!),
                  ),
                  if (data.servingUnitAmount != null &&
                      data.servingUnitName != null)
                    _info(
                      'Serving equivalent',
                      '${_number(data.servingUnitAmount!)} ${data.servingUnitName}',
                    ),
                ],
              ),
            ),
            if (sourceImagePath != null) ...[
              const SizedBox(height: 16),
              _card(
                ExpansionTile(
                  title: const Text('View label photo'),
                  children: [
                    SizedBox(
                      height: 280,
                      child: InteractiveViewer(
                        child: Image.file(
                          File(sourceImagePath!),
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) =>
                              const Center(child: Text('Photo unavailable')),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              '${data.rows.length} nutrient rows read',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: _purple,
              ),
            ),
            if (data.columns.length > 1)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Swipe the table sideways to see every column.',
                  style: TextStyle(color: Color(0xFF67558E)),
                ),
              ),
            const SizedBox(height: 12),
            _card(NutritionTable(data: data)),
            if (data.extractionWarnings.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF5DF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Check highlighted information',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    for (final warning in data.extractionWarnings)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(warning),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            _card(NutritionPortionCard(data: data)),
            const SizedBox(height: 16),
            _card(
              ExpansionTile(
                title: const Text('Text read from the label'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SelectableText(
                      data.rawText.isEmpty
                          ? 'No readable text found.'
                          : data.rawText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Back to photo'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(Widget child) => Material(
    color: Colors.white,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: Color(0xFFE4D9F7)),
    ),
    child: child,
  );

  Widget _info(String title, String value) => Padding(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, color: _purple),
          ),
        ),
        const SizedBox(width: 16),
        Flexible(child: Text(value, textAlign: TextAlign.right)),
      ],
    ),
  );
}
