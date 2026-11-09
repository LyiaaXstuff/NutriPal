// =======================================================
// NUTRITION LABEL EDITOR
// =======================================================
//
// NutritionLabelData is immutable. These helpers return a
// changed copy when the user corrects a value (Quick
// verification) or edits the table (Edit nutrients).
// Pure Dart, unit tested.
// =======================================================

import '../models/nutrition_label_data.dart';
import 'nutrition_analysis_service.dart';

class NutritionLabelEditor {
  NutritionLabelEditor._();

  static const String editedNote = 'Some values were corrected by you.';

  /// Replaces one value in one cell. [valueIndex] equal to
  /// the cell length appends a value.
  static NutritionLabelData setValue(
    NutritionLabelData data, {
    required int row,
    required int column,
    required int valueIndex,
    required NutritionValue value,
  }) {
    final List<NutrientRow> rows = <NutrientRow>[...data.nutrients];
    final NutrientRow old = rows[row];

    final List<List<NutritionValue>> cells = <List<NutritionValue>>[
      for (final List<NutritionValue> c in old.valuesByColumn)
        <NutritionValue>[...c],
    ];

    while (cells.length <= column) {
      cells.add(<NutritionValue>[]);
    }

    final List<NutritionValue> cell = cells[column];

    if (valueIndex >= cell.length) {
      cell.add(value);
    } else {
      cell[valueIndex] = value;
    }

    rows[row] = NutrientRow(
      name: old.name,
      rawName: old.rawName,
      order: old.order,
      valuesByColumn: cells,
    );

    return data.copyWith(nutrients: rows, notes: _withEditedNote(data.notes));
  }

  /// Keeps per serving and per 100 in step after the user
  /// edits one of them: the other column is recalculated
  /// from the serving size (same unit only).
  static NutritionLabelData syncOtherColumn(
    NutritionLabelData data, {
    required int row,
    required int editedColumn,
  }) {
    final double? size = data.servingSizeAmount;

    if (size == null || size <= 0) return data;

    final int ps = data.columnIndexFor(NutritionColumnBasis.perServing);
    final int g = data.columnIndexFor(NutritionColumnBasis.per100g);
    final int p100 =
        g >= 0 ? g : data.columnIndexFor(NutritionColumnBasis.per100ml);

    if (ps < 0 || p100 < 0) return data;

    final int other;
    final double factor;

    if (editedColumn == ps) {
      other = p100;
      factor = 100 / size;
    } else if (editedColumn == p100) {
      other = ps;
      factor = size / 100;
    } else {
      return data;
    }

    final NutrientRow r = data.nutrients[row];

    if (editedColumn >= r.valuesByColumn.length) return data;

    NutritionLabelData result = data;

    final List<NutritionValue> source = r.valuesByColumn[editedColumn];

    for (final NutritionValue v in source) {
      if (v.unit == '?') continue;

      final List<List<NutritionValue>> now =
          result.nutrients[row].valuesByColumn;

      final List<NutritionValue> current =
          other < now.length ? now[other] : const <NutritionValue>[];

      final int at = current.indexWhere((NutritionValue t) => t.unit == v.unit);
      final double amount = _round(v.amount * factor, v.unit);

      result = setValue(
        result,
        row: row,
        column: other,
        valueIndex: at >= 0 ? at : current.length,
        value: NutritionValue(
          amount: amount,
          unit: v.unit,
          rawText: 'calculated',
        ),
      );
    }

    return result;
  }

  static NutritionLabelData setServing(
    NutritionLabelData data, {
    double? servingSize,
    double? servingsPerPackage,
  }) {
    return NutritionLabelData(
      servingSizeAmount: servingSize,
      servingSizeUnit: servingSize == null
          ? null
          : data.servingSizeUnit ??
              (data.hasPer100mlColumn ? 'ml' : 'g'),
      servingsPerPackage: servingsPerPackage,
      servingUnitAmount: data.servingUnitAmount,
      servingUnitName: data.servingUnitName,
      columns: data.columns,
      nutrients: data.nutrients,
      rawText: data.rawText,
      extractionMethod: data.extractionMethod,
      notes: _withEditedNote(data.notes),
      unreadableScriptRows: data.unreadableScriptRows,
      productName: data.productName,
      productBrand: data.productBrand,
      barcode: data.barcode,
      productImageUrl: data.productImageUrl,
    );
  }

  /// Adds a nutrient the reading missed, with one value in
  /// [column].
  static NutritionLabelData addNutrient(
    NutritionLabelData data, {
    required String name,
    required int column,
    required NutritionValue value,
  }) {
    final int columns = data.columns.isEmpty ? 1 : data.columns.length;

    final List<List<NutritionValue>> cells = <List<NutritionValue>>[
      for (int i = 0; i < columns; i++)
        i == column ? <NutritionValue>[value] : <NutritionValue>[],
    ];

    return data.copyWith(
      nutrients: <NutrientRow>[
        ...data.nutrients,
        NutrientRow(
          name: name,
          order: data.nutrients.length,
          valuesByColumn: cells,
        ),
      ],
      notes: _withEditedNote(data.notes),
    );
  }

  static double _round(double value, String unit) =>
      double.parse(NutritionAnalysisService.formatAmount(value, unit));

  static List<String> _withEditedNote(List<String> notes) =>
      notes.contains(editedNote) ? notes : <String>[...notes, editedNote];
}
