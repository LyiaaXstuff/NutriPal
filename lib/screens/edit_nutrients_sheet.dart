import 'package:flutter/material.dart';

import '../models/nutrition_label_data.dart';
import '../services/nutrient_name_normalizer.dart';
import '../services/nutrition_analysis_service.dart';
import '../services/nutrition_label_editor.dart';
import '../widgets/nutripal_ui.dart';

// =======================================================
// 5 · EDIT NUTRIENTS (bottom sheet)
// =======================================================
//
// Lets the user correct the serving size and any value,
// column by column, or add a nutrient the reading missed.
// Returns the corrected NutritionLabelData (null = no
// change); the result screen then re-runs the analysis.
//
// When only one column of a row is edited, the other
// column (per serving <-> per 100) is recalculated from
// the serving size so the two stay consistent.
// =======================================================

Future<NutritionLabelData?> showEditNutrientsSheet(
  BuildContext context, {
  required NutritionLabelData data,
  required String productName,
}) {
  return showModalBottomSheet<NutritionLabelData>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: NpColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (BuildContext context) => _EditNutrientsSheet(
      data: data,
      productName: productName,
    ),
  );
}

class _EditNutrientsSheet extends StatefulWidget {
  final NutritionLabelData data;
  final String productName;

  const _EditNutrientsSheet({required this.data, required this.productName});

  @override
  State<_EditNutrientsSheet> createState() => _EditNutrientsSheetState();
}

class _Field {
  final TextEditingController controller;
  String unit;

  // Original value; null for a new (empty) cell.
  final NutritionValue? original;

  _Field(this.controller, this.unit, this.original);
}

class _EditNutrientsSheetState extends State<_EditNutrientsSheet> {
  // Boxed text field for the Add a nutrient popup.
  static InputDecoration _boxDecoration({required String hint}) => InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFEDE4F9),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: NpColors.purple, width: 1.4),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: Color(0xFF38138C), width: 2),
        ),
      );

  static const List<String> _units = <String>['g', 'mg', 'µg', 'kcal', 'kJ', 'ml', 'IU', '%'];

  late NutritionLabelData _working;

  late final TextEditingController _servingSize;
  late final TextEditingController _servings;

  late int _column;

  // "row:column:index" -> field. index "n" = new value.
  final Map<String, _Field> _fields = <String, _Field>{};

  String? _error;

  @override
  void initState() {
    super.initState();

    _working = widget.data;

    _servingSize = TextEditingController(
      text: _working.servingSizeAmount == null
          ? ''
          : NutritionAnalysisService.formatAmount(_working.servingSizeAmount!, 'g'),
    );
    _servings = TextEditingController(
      text: _working.servingsPerPackage == null
          ? ''
          : NutritionAnalysisService.formatAmount(_working.servingsPerPackage!, 'g'),
    );

    final int ps = _working.columnIndexFor(NutritionColumnBasis.perServing);

    _column = ps >= 0 ? ps : 0;
  }

  @override
  void dispose() {
    _servingSize.dispose();
    _servings.dispose();

    for (final _Field f in _fields.values) {
      f.controller.dispose();
    }

    super.dispose();
  }

  String _servingUnit() =>
      _working.servingSizeUnit ?? (_working.hasPer100mlColumn ? 'ml' : 'g');

  String _columnTitle(int c) {
    if (c >= _working.columns.length) return 'Values';

    return switch (_working.columns[c].basis) {
      NutritionColumnBasis.perServing => 'Per serving',
      NutritionColumnBasis.per100g => 'Per 100 g',
      NutritionColumnBasis.per100ml => 'Per 100 ml',
      NutritionColumnBasis.unknown => _working.columns[c].label,
    };
  }

  static String _usualUnit(String name) => switch (name) {
        'Energy' => 'kcal',
        'Sodium' || 'Cholesterol' || 'Potassium' || 'Calcium' || 'Iron' => 'mg',
        _ => 'g',
      };

  List<_Field> _fieldsFor(int row) {
    final NutrientRow r = _working.nutrients[row];
    final List<NutritionValue> cell =
        _column < r.valuesByColumn.length ? r.valuesByColumn[_column] : const <NutritionValue>[];

    if (cell.isEmpty) {
      return <_Field>[
        _fields.putIfAbsent(
          '$row:$_column:n',
          () => _Field(TextEditingController(), _usualUnit(r.name), null),
        ),
      ];
    }

    return <_Field>[
      for (int i = 0; i < cell.length; i++)
        _fields.putIfAbsent(
          '$row:$_column:$i',
          () => _Field(
            TextEditingController(
              text: NutritionAnalysisService.formatAmount(cell[i].amount, cell[i].unit),
            ),
            cell[i].unit,
            cell[i],
          ),
        ),
    ];
  }

  Future<void> _addNutrient() async {
    final TextEditingController name = TextEditingController();
    final TextEditingController amount = TextEditingController();
    String unit = 'g';

    // Same look as the Product name popup: light purple
    // card, boxed fields; tapping outside only hides the
    // keyboard.
    final bool? ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(dialogContext).unfocus(),
        child: StatefulBuilder(
          builder: (BuildContext context, StateSetter setLocal) => AlertDialog(
            backgroundColor: const Color(0xFFF8F4FD),
            surfaceTintColor: Colors.transparent,
            titlePadding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
            contentPadding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
            actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add a nutrient',
                  style: TextStyle(
                    color: NpColors.purple,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _columnTitle(_column),
                  style: const TextStyle(color: NpColors.muted, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _FieldLabel('Name on the label'),
                TextField(
                  controller: name,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _boxDecoration(hint: 'e.g. Vitamin C'),
                ),
                const SizedBox(height: 12),
                const _FieldLabel('Value'),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: amount,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: _boxDecoration(hint: 'Amount'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Unit picker in a matching box.
                    Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDE4F9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: NpColors.purple, width: 1.4),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: unit,
                          borderRadius: BorderRadius.circular(14),
                          dropdownColor: const Color(0xFFF8F4FD),
                          icon: const Icon(Icons.expand_more_rounded, color: NpColors.purple),
                          style: const TextStyle(
                            color: NpColors.purple,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          items: <DropdownMenuItem<String>>[
                            for (final String u in _units) DropdownMenuItem<String>(value: u, child: Text(u)),
                          ],
                          onChanged: (String? u) => setLocal(() => unit = u ?? unit),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Padding(
                  padding: EdgeInsets.only(left: 2),
                  child: Text(
                    'Copy the name and value from the pack.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: NpColors.muted, fontSize: 12.5),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: NpColors.purple),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Add'),
              ),
            ],
          ),
        ),
      ),
    );

    final String label = name.text.trim();
    final double? value = double.tryParse(amount.text.trim().replaceAll(',', '.'));

    // Not disposed here: the dialog is still fading out and
    // its text fields keep using the controllers for a few
    // frames (disposing now crashes in debug). They hold no
    // listeners, so they are simply garbage collected.

    if (ok != true || label.isEmpty || value == null || !mounted) return;

    setState(() {
      _working = NutritionLabelEditor.addNutrient(
        _working,
        name: NutrientNameNormalizer.normalize(label),
        column: _column,
        value: NutritionValue(amount: value, unit: unit, rawText: 'added by you'),
      );
    });
  }

  void _save() {
    NutritionLabelData result = _working;

    // ---- serving ----------------------------------------
    final String sizeText = _servingSize.text.trim().replaceAll(',', '.');
    final String servingsText = _servings.text.trim().replaceAll(',', '.');

    final double? size = sizeText.isEmpty ? null : double.tryParse(sizeText);
    final double? servings = servingsText.isEmpty ? null : double.tryParse(servingsText);

    if ((sizeText.isNotEmpty && (size == null || size <= 0)) ||
        (servingsText.isNotEmpty && (servings == null || servings <= 0))) {
      setState(() => _error = 'Serving size and servings per pack must be numbers.');
      return;
    }

    String shown(double? v) =>
        v == null ? '' : NutritionAnalysisService.formatAmount(v, 'g');

    // Compare what was shown, so an unchanged "33.3" for a
    // printed 33.33 does not count as an edit.
    if (sizeText != shown(result.servingSizeAmount) ||
        servingsText != shown(result.servingsPerPackage)) {
      result = NutritionLabelEditor.setServing(
        result,
        servingSize: sizeText == shown(result.servingSizeAmount)
            ? result.servingSizeAmount
            : size,
        servingsPerPackage: servingsText == shown(result.servingsPerPackage)
            ? result.servingsPerPackage
            : servings,
      );
    }

    // ---- values -----------------------------------------
    final Map<int, Set<int>> editedColumns = <int, Set<int>>{};

    for (final MapEntry<String, _Field> e in _fields.entries) {
      final List<String> key = e.key.split(':');
      final int row = int.parse(key[0]);
      final int column = int.parse(key[1]);
      final _Field f = e.value;

      final String text = f.controller.text.trim().replaceAll(',', '.');

      if (text.isEmpty) continue;

      final double? amount = double.tryParse(text);

      if (amount == null) {
        setState(() => _error = 'Please enter numbers only (${_working.nutrients[row].name}).');
        return;
      }

      final NutritionValue? old = f.original;

      if (old != null &&
          text == NutritionAnalysisService.formatAmount(old.amount, old.unit) &&
          old.unit == f.unit) {
        continue;
      }

      final int index = key[2] == 'n'
          ? (column < result.nutrients[row].valuesByColumn.length
              ? result.nutrients[row].valuesByColumn[column].length
              : 0)
          : int.parse(key[2]);

      result = NutritionLabelEditor.setValue(
        result,
        row: row,
        column: column,
        valueIndex: index,
        value: NutritionValue(amount: amount, unit: f.unit, rawText: 'edited by you'),
      );

      editedColumns.putIfAbsent(row, () => <int>{}).add(column);
    }

    for (final MapEntry<int, Set<int>> e in editedColumns.entries) {
      if (e.value.length == 1) {
        result = NutritionLabelEditor.syncOtherColumn(
          result,
          row: e.key,
          editedColumn: e.value.first,
        );
      }
    }

    final bool changed = !identical(result, widget.data);

    Navigator.pop(context, changed ? result : null);
  }

  @override
  Widget build(BuildContext context) {
    final List<int> columns = <int>[
      for (int c = 0; c < _working.columns.length; c++) c,
    ];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: FractionallySizedBox(
        heightFactor: 0.92,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: NpColors.softBorder,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'EDIT NUTRIENTS',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: NpColors.muted,
                          ),
                        ),
                        Text(
                          widget.productName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: NpColors.ink),
                        ),
                      ],
                    ),
                  ),
                  NpCircleButton(
                    icon: Icons.close_rounded,
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _NumberField(
                          controller: _servingSize,
                          label: 'Serving size',
                          suffix: _servingUnit(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _NumberField(
                          controller: _servings,
                          label: 'Servings per pack',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (columns.length > 1)
                    SegmentedButton<int>(
                      showSelectedIcon: false,
                      segments: <ButtonSegment<int>>[
                        for (final int c in columns)
                          ButtonSegment<int>(value: c, label: Text(_columnTitle(c))),
                      ],
                      selected: <int>{_column},
                      onSelectionChanged: (Set<int> s) => setState(() => _column = s.first),
                      style: SegmentedButton.styleFrom(
                        selectedBackgroundColor: NpColors.selectedBg,
                        selectedForegroundColor: NpColors.selectedInk,
                      ),
                    ),
                  const SizedBox(height: 12),
                  for (int r = 0; r < _working.nutrients.length; r++)
                    _RowEditor(
                      name: _working.nutrients[r].name,
                      fields: _fieldsFor(r),
                      units: _units,
                      onUnitChanged: () => setState(() {}),
                    ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _addNutrient,
                    icon: const Icon(Icons.add_rounded, color: NpColors.purple),
                    label: const Text(
                      'Add a nutrient from the label',
                      style: TextStyle(fontWeight: FontWeight.w800, color: NpColors.purple),
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: NpColors.errorInk, fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: NpPrimaryButton(label: 'Save and update my result', onPressed: _save),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? suffix;

  const _NumberField({required this.controller, required this.label, this.suffix});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(fontWeight: FontWeight.w700, color: NpColors.ink),
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDCCFF0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: NpColors.teal, width: 2),
        ),
      ),
    );
  }
}

class _RowEditor extends StatelessWidget {
  final String name;
  final List<_Field> fields;
  final List<String> units;
  final VoidCallback onUnitChanged;

  const _RowEditor({
    required this.name,
    required this.fields,
    required this.units,
    required this.onUnitChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              name,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: NpColors.ink),
            ),
          ),
          Expanded(
            flex: 6,
            child: Column(
              children: [
                for (final _Field f in fields)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: f.controller,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontWeight: FontWeight.w700, color: NpColors.ink),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: '–',
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFDCCFF0)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: NpColors.teal, width: 2),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 64,
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: units.contains(f.unit) ? f.unit : null,
                            hint: const Text('unit'),
                            underline: const SizedBox.shrink(),
                            items: <DropdownMenuItem<String>>[
                              for (final String u in units)
                                DropdownMenuItem<String>(value: u, child: Text(u)),
                            ],
                            onChanged: (String? u) {
                              if (u == null) return;
                              f.unit = u;
                              onUnitChanged();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Small label above a boxed field.
class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 6),
      child: Text(
        text,
        style: const TextStyle(color: NpColors.bodyInk, fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }
}
