import '../models/nutrition_label_data.dart';

class CalculatedNutrient {
  final String rowId;
  final String name;
  final List<NutritionQuantity> quantities;
  const CalculatedNutrient(this.rowId, this.name, this.quantities);
}

class NutritionPortionResult {
  final String columnId;
  final double multiplier;
  final List<CalculatedNutrient> nutrients;
  final List<String> excludedNutrients;
  const NutritionPortionResult({
    required this.columnId,
    required this.multiplier,
    required this.nutrients,
    required this.excludedNutrients,
  });
}

/// Ordered, arbitrary nutrients for logging and downstream calculations. Missing
/// values remain excluded; percentages and inequalities are never exact amounts.
class NutritionPortionCalculator {
  static NutritionPortionResult calculate({
    required NutritionLabelData data,
    required String columnId,
    required double amount,
    required String unit,
    required bool confirmed,
  }) {
    if (!confirmed) {
      throw const FormatException('Check the values against the photo first.');
    }
    if (!amount.isFinite || amount <= 0) {
      throw const FormatException('Enter a portion greater than zero.');
    }
    final matches = data.columns.where((c) => c.id == columnId).toList();
    if (matches.length != 1) {
      throw const FormatException('Select a nutrition column.');
    }
    final column = matches.single;
    final expectedUnit = switch (column.basis) {
      NutritionColumnBasis.perServing => 'servings',
      NutritionColumnBasis.per100g => 'g',
      NutritionColumnBasis.per100ml => 'ml',
      _ => throw const FormatException(
        'This column has no usable serving basis.',
      ),
    };
    var input = amount;
    if (unit != expectedUnit) {
      final size = data.servingSizeAmount;
      final sizeUnit = data.servingSizeUnit;
      if (size == null ||
          !size.isFinite ||
          size <= 0 ||
          (column.basis == NutritionColumnBasis.perServing &&
              data.columns
                      .where((c) => c.basis == NutritionColumnBasis.perServing)
                      .length !=
                  1)) {
        throw const FormatException(
          'The serving size needed for this conversion was not read.',
        );
      }
      if (expectedUnit == 'servings' && unit == sizeUnit) {
        input /= size;
      } else if (unit == 'servings' && expectedUnit == sizeUnit) {
        input *= size;
      } else {
        throw const FormatException(
          'Grams and millilitres cannot be converted without product density.',
        );
      }
    }
    final factor = input / (expectedUnit == 'servings' ? 1 : 100);
    final included = <CalculatedNutrient>[];
    final excluded = <String>[];
    for (final row in data.rows) {
      final cell = row.cells[columnId];
      final quantities = cell?.quantities ?? [];
      if (cell == null ||
          cell.needsReview ||
          quantities.isEmpty ||
          quantities.any(
            (q) =>
                q.comparator.isNotEmpty ||
                !q.amount.isFinite ||
                q.amount < 0 ||
                q.unit.isEmpty ||
                q.unit == '%' ||
                !(q.amount * factor).isFinite,
          )) {
        excluded.add(row.name);
        continue;
      }
      included.add(
        CalculatedNutrient(
          row.id,
          row.name,
          List.unmodifiable([
            for (final q in quantities)
              NutritionQuantity(
                amount: q.amount * factor,
                numberText: (q.amount * factor).toString(),
                unit: q.unit,
                rawText: q.rawText,
              ),
          ]),
        ),
      );
    }
    return NutritionPortionResult(
      columnId: columnId,
      multiplier: factor,
      nutrients: List.unmodifiable(included),
      excludedNutrients: List.unmodifiable(excluded),
    );
  }
}
