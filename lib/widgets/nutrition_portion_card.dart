import 'package:flutter/material.dart';

import '../models/nutrition_label_data.dart';
import '../services/nutrition_portion_calculator.dart';

class NutritionPortionCard extends StatefulWidget {
  final NutritionLabelData data;
  const NutritionPortionCard({super.key, required this.data});
  @override
  State<NutritionPortionCard> createState() => _NutritionPortionCardState();
}

class _NutritionPortionCardState extends State<NutritionPortionCard> {
  late final List<NutritionColumn> _columns = widget.data.columns
      .where(
        (c) =>
            c.basis == NutritionColumnBasis.perServing ||
            c.basis == NutritionColumnBasis.per100g ||
            c.basis == NutritionColumnBasis.per100ml,
      )
      .toList();
  late NutritionColumn? _column = _columns.firstOrNull;
  late String _unit = _column?.basis == NutritionColumnBasis.perServing
      ? 'servings'
      : _column?.basis == NutritionColumnBasis.per100ml
      ? 'ml'
      : 'g';
  late final _amount = TextEditingController(
    text: _unit == 'servings' ? '1' : '100',
  );
  bool _confirmed = false;
  NutritionPortionResult? _result;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _calculate() {
    setState(() {
      _result = null;
      _error = null;
      try {
        _result = NutritionPortionCalculator.calculate(
          data: widget.data,
          columnId: _column!.id,
          amount: double.tryParse(_amount.text) ?? double.nan,
          unit: _unit,
          confirmed: _confirmed,
        );
      } on FormatException catch (e) {
        _error = e.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Calculate your portion',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        const SizedBox(height: 8),
        if (_columns.isEmpty)
          const Text(
            'A readable per-serving, per-100-g, or per-100-ml heading is needed for calculations.',
          )
        else ...[
          const Text(
            'Choose the label column and enter how much you will eat or drink. Highlighted readings are excluded.',
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _column!.id,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Use values from'),
            items: [
              for (final c in _columns)
                DropdownMenuItem(
                  value: c.id,
                  child: Text(c.label, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (id) => setState(() {
              _column = _columns.firstWhere((c) => c.id == id);
              _result = null;
              _error = null;
            }),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Your portion'),
                  onChanged: (_) => setState(() {
                    _result = null;
                    _error = null;
                  }),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 120,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _unit,
                  decoration: const InputDecoration(labelText: 'Unit'),
                  items: const [
                    DropdownMenuItem(
                      value: 'servings',
                      child: Text('Servings'),
                    ),
                    DropdownMenuItem(value: 'g', child: Text('g')),
                    DropdownMenuItem(value: 'ml', child: Text('ml')),
                  ],
                  onChanged: (unit) => setState(() {
                    _unit = unit!;
                    _result = null;
                    _error = null;
                  }),
                ),
              ),
            ],
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _confirmed,
            title: const Text(
              'I checked the values, headings, and serving size against the photo.',
            ),
            onChanged: (v) => setState(() {
              _confirmed = v!;
              _result = null;
            }),
          ),
          FilledButton(
            onPressed: _confirmed ? _calculate : null,
            child: const Text('Calculate portion'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: const TextStyle(color: Color(0xFFB71C1C)),
              ),
            ),
          if (_result != null) ...[
            const SizedBox(height: 16),
            const Text(
              'For your portion',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const Text(
              'Calculated values are estimates based on the printed label.',
            ),
            if (_result!.nutrients.isEmpty)
              const Text('No reliable amounts are available in this column.'),
            for (final row in _result!.nutrients)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${row.name}: ${row.quantities.map((q) => q.displayText).join(' / ')}',
                ),
              ),
            if (_result!.excludedNutrients.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Excluded from this calculation: ${_result!.excludedNutrients.join(', ')}. These readings are missing, uncertain, or expressed as limits.',
                ),
              ),
          ],
        ],
      ],
    ),
  );
}
