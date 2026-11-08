import 'package:flutter_test/flutter_test.dart';
import 'package:nutripal/models/nutrition_label_data.dart';
import 'package:nutripal/services/nutrition_label_editor.dart';
import 'package:nutripal/services/value_check_service.dart';

import 'nutrition_analysis_service_test.dart' show homesoy;

NutritionLabelData withValue(
  NutritionLabelData data,
  String nutrient,
  int column,
  NutritionValue value,
) {
  final int row = data.nutrients.indexWhere((NutrientRow r) => r.name == nutrient);

  return NutritionLabelEditor.setValue(
    data,
    row: row,
    column: column,
    valueIndex: 0,
    value: value,
  );
}

void main() {
  test('a clean label has no issues (Quick verification is skipped)', () {
    expect(ValueCheckService.find(homesoy()), isEmpty);
  });

  test('per serving that does not match per 100 ml', () {
    final NutritionLabelData data = withValue(
      homesoy(),
      'Energy',
      0,
      const NutritionValue(amount: 75, unit: 'kcal', rawText: '75 kcal'),
    );

    final List<ValueIssue> issues = ValueCheckService.find(data);

    expect(issues, hasLength(1));
    expect(issues.single.kind, ValueIssueKind.doesNotAddUp);
    expect(issues.single.suggestedAmount, 92);
    expect(
      issues.single.message,
      'From 39 kcal per 100 ml, one 236 ml serving should be about 92 kcal.',
    );
    expect(issues.single.columnLabel, 'per serving');
  });

  test('a missing decimal point: 38 g printed as 3.8 g', () {
    final NutritionLabelData data = withValue(
      homesoy(),
      'Total Fat',
      0,
      const NutritionValue(amount: 38, unit: 'g', rawText: '38g'),
    );

    final ValueIssue issue = ValueCheckService.find(data).single;

    expect(issue.kind, ValueIssueKind.decimalMissing);
    expect(issue.suggestedAmount, closeTo(3.8, 0.001));
    expect(issue.tag, 'Hard to read');
  });

  test('unit that could not be read', () {
    final NutritionLabelData data = withValue(
      homesoy(),
      'Sodium',
      1,
      const NutritionValue(amount: 17, unit: '?', rawText: '17'),
    );

    final ValueIssue issue = ValueCheckService.find(data).single;

    expect(issue.kind, ValueIssueKind.unitMissing);
    expect(issue.suggestedUnit, 'mg');
  });

  test('sugars bigger than carbohydrate', () {
    NutritionLabelData data = withValue(
      homesoy(),
      'Total Sugars',
      1,
      const NutritionValue(amount: 4.5, unit: 'g', rawText: '4.5g'),
    );
    data = withValue(
      data,
      'Total Sugars',
      0,
      const NutritionValue(amount: 10.6, unit: 'g', rawText: '10.6g'),
    );

    final List<ValueIssue> issues = ValueCheckService.find(data);

    expect(
      issues.map((ValueIssue i) => i.kind),
      everyElement(ValueIssueKind.partExceedsWhole),
    );
    expect(issues, hasLength(2));
  });

  test('kJ and kcal that disagree', () {
    final NutritionLabelData base = homesoy();
    final int energy = base.nutrients.indexWhere((NutrientRow r) => r.name == 'Energy');

    final NutritionLabelData data = NutritionLabelEditor.setValue(
      base,
      row: energy,
      column: 1,
      valueIndex: 1,
      value: const NutritionValue(amount: 230, unit: 'kJ', rawText: '230 kJ'),
    );

    final ValueIssue issue = ValueCheckService.find(data).single;

    expect(issue.kind, ValueIssueKind.energyMismatch);
    expect(issue.suggestedAmount, 55);
  });

  test('AI values that the phone could not confirm', () {
    final NutritionLabelData data = homesoy().copyWith(
      notes: <String>[
        'Please check: Sodium (Per serving): 40mg (not confirmed by on-device reading)',
      ],
    );

    final ValueIssue issue = ValueCheckService.find(data).single;

    expect(issue.kind, ValueIssueKind.notConfirmed);
    expect(issue.nutrient, 'Sodium');
    expect(issue.column, 0);
  });

  group('Editor', () {
    test('syncOtherColumn recalculates per 100 from per serving', () {
      final NutritionLabelData base = homesoy();
      final int fat = base.nutrients.indexWhere((NutrientRow r) => r.name == 'Total Fat');

      NutritionLabelData data = NutritionLabelEditor.setValue(
        base,
        row: fat,
        column: 0,
        valueIndex: 0,
        value: const NutritionValue(amount: 4.7, unit: 'g', rawText: '4.7'),
      );

      data = NutritionLabelEditor.syncOtherColumn(data, row: fat, editedColumn: 0);

      expect(data.nutrients[fat].valuesByColumn[1].single.amount, 2);
      expect(data.notes, contains(NutritionLabelEditor.editedNote));
      expect(ValueCheckService.find(data), isEmpty);
    });

    test('addNutrient appends a row', () {
      final NutritionLabelData data = NutritionLabelEditor.addNutrient(
        homesoy(),
        name: 'Potassium',
        column: 1,
        value: const NutritionValue(amount: 150, unit: 'mg', rawText: '150'),
      );

      expect(data.nutrients.last.name, 'Potassium');
      expect(data.nutrients.last.valuesByColumn[1].single.amount, 150);
      expect(data.nutrients.last.valuesByColumn[0], isEmpty);
    });
  });
}
