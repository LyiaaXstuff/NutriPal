import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutripal/models/nutrition_label_data.dart';
import 'package:nutripal/services/azure_nutrition_layout_parser.dart';
import 'package:nutripal/services/nutrition_portion_calculator.dart';

// Synthetic Azure v4 response. Tests structural mapping, not Azure's actual OCR.
Map<String, dynamic> layoutFixture() =>
    jsonDecode(File('test/fixtures/azure_layout.json').readAsStringSync())
        as Map<String, dynamic>;

Map<String, dynamic> layoutFromRows(List<List<String?>> rows) {
  var content = '';
  final words = <Map<String, dynamic>>[];
  final cells = <Map<String, dynamic>>[];
  for (var r = 0; r < rows.length; r++) {
    for (var c = 0; c < rows[r].length; c++) {
      final text = rows[r][c];
      if (text == null) continue;
      final start = content.runes.length;
      for (final match in RegExp(r'\S+').allMatches(text)) {
        words.add({
          'content': match.group(0),
          'confidence': 0.99,
          'span': {
            'offset': start + match.start,
            'length': match.end - match.start,
          },
        });
      }
      cells.add({
        'rowIndex': r,
        'columnIndex': c,
        'kind': r == 0 ? 'columnHeader' : 'content',
        'content': text,
        'spans': [
          {'offset': start, 'length': text.runes.length},
        ],
      });
      content += '$text\n';
    }
  }
  return {
    'content': content,
    'pages': [
      {'words': words},
    ],
    'tables': [
      {
        'rowCount': rows.length,
        'columnCount': rows.first.length,
        'cells': cells.reversed.toList(),
      },
    ],
  };
}

void main() {
  test('uses table indexes with shuffled cells and preserves missing middle values', () {
    final data = AzureNutritionLayoutParser.parse(layoutFixture());
    expect(data.extractionMethod, 'Azure Document Intelligence Layout');
    expect(data.columns.map((c) => c.basis), [
      NutritionColumnBasis.perServing,
      NutritionColumnBasis.per100g,
      NutritionColumnBasis.per100ml,
      NutritionColumnBasis.dailyValue,
    ]);
    expect(data.rows.map((r) => r.name), [
      'Energy',
      'Protein',
      'Inositol',
      'Vitamin B12',
      'Sugars',
    ]);
    expect(data.rows[2].cells['azure_column_1']!.displayText, '20 mg');
    expect(data.rows[2].cells['azure_column_2']!.displayText, 'Not read');
    expect(data.rows[2].cells['azure_column_3']!.displayText, '60 mg');
    expect(data.rows[1].cells.values.every((c) => !c.needsReview), isTrue);
    expect(data.perServing!.energyKj, 450);
    expect(data.perServing!.energyKcal, 108);
    expect(data.perServing!.proteinG, 3);
    expect(
      data.per100,
      isNull,
    ); // Mass/volume cannot share the legacy projection.
    expect(
      data.perServing!.sugarsG,
      isNull,
    ); // Printed limit isn't an exact value.
  });

  test('does not guess low-confidence values or nutrient names', () {
    for (final target in ['3', 'Protein', 'serving']) {
      final json = layoutFixture();
      final words = json['pages'][0]['words'] as List;
      (words.firstWhere((w) => w['content'] == target) as Map)['confidence'] =
          0.2;
      final data = AzureNutritionLayoutParser.parse(json);
      expect(data.rows[1].cells['azure_column_1']!.needsReview, isTrue);
      expect(data.perServing?.proteinG, isNull);
      expect(data.rows[1].cells['azure_column_1']!.displayText, '3 g');
    }
  });

  test('missing word evidence prevents use in calculations', () {
    final json = layoutFixture();
    json['pages'] = [];
    final data = AzureNutritionLayoutParser.parse(json);
    expect(data.rows, isNotEmpty);
    expect(data.perServing, isNull);
    expect(data.rows.every((r) => r.needsReview), isTrue);
  });

  test(
    'overlapping and merged numeric cells cannot duplicate calculation values',
    () {
      final json = layoutFixture();
      final cells = json['tables'][0]['cells'] as List;
      final protein = cells.firstWhere(
        (c) => c['rowIndex'] == 2 && c['columnIndex'] == 1,
      );
      protein['columnSpan'] = 2;
      final data = AzureNutritionLayoutParser.parse(json);
      expect(data.rows[1].cells['azure_column_1']!.needsReview, isTrue);
      expect(data.rows[1].cells['azure_column_2']!.needsReview, isTrue);
      expect(data.perServing!.proteinG, isNull);
    },
  );

  test('does not silently choose among two nutrition tables', () {
    final json = layoutFixture();
    (json['tables'] as List).add(json['tables'][0]);
    final data = AzureNutritionLayoutParser.parse(json);
    expect(data.rows, isEmpty);
    expect(data.extractionWarnings.single, contains('Multiple tables'));
  });

  test('unknown column bases remain visible and cannot be calculated', () {
    final json = layoutFixture();
    for (final cell in json['tables'][0]['cells']) {
      if (cell['rowIndex'] == 0) cell['content'] = 'Unrecognised heading';
    }
    final data = AzureNutritionLayoutParser.parse(json);
    expect(data.rows, isNotEmpty);
    expect(data.perServing, isNull);
    expect(
      () => NutritionPortionCalculator.calculate(
        data: data,
        columnId: data.columns.first.id,
        amount: 2,
        unit: 'servings',
        confirmed: true,
      ),
      throwsFormatException,
    );
  });

  test(
    'no table yields a retake instruction instead of a fabricated result',
    () {
      final data = AzureNutritionLayoutParser.parse({
        'content': 'Some unrelated text',
      });
      expect(data.rows, isEmpty);
      expect(data.extractionWarnings.single, contains('No table'));
    },
  );

  test('calculates arbitrary nutrients in order without replacing missing amounts by zero', () {
    final data = AzureNutritionLayoutParser.parse(layoutFixture());
    final serving = NutritionPortionCalculator.calculate(
      data: data,
      columnId: 'azure_column_1',
      amount: 2,
      unit: 'servings',
      confirmed: true,
    );
    expect(serving.nutrients.map((n) => n.name), [
      'Energy',
      'Protein',
      'Inositol',
      'Vitamin B12',
    ]);
    expect(serving.nutrients[0].quantities.map((q) => q.amount), [900, 216]);
    expect(serving.nutrients[1].quantities.single.amount, 6);
    expect(serving.nutrients[2].quantities.single.amount, 40);
    expect(serving.nutrients[3].quantities.single.amount, 4.8);
    expect(serving.excludedNutrients, ['Sugars']);
    final grams = NutritionPortionCalculator.calculate(
      data: data,
      columnId: 'azure_column_2',
      amount: 25,
      unit: 'g',
      confirmed: true,
    );
    expect(grams.nutrients[1].quantities.single.amount, 1.5);
    expect(grams.excludedNutrients, ['Inositol']);
  });

  test(
    'requires confirmation and rejects incompatible units and invalid portions',
    () {
      final data = AzureNutritionLayoutParser.parse(layoutFixture());
      for (final amount in [0.0, -1.0, double.nan, double.infinity]) {
        expect(
          () => NutritionPortionCalculator.calculate(
            data: data,
            columnId: 'azure_column_1',
            amount: amount,
            unit: 'servings',
            confirmed: true,
          ),
          throwsFormatException,
        );
      }
      expect(
        () => NutritionPortionCalculator.calculate(
          data: data,
          columnId: 'azure_column_1',
          amount: 1,
          unit: 'servings',
          confirmed: false,
        ),
        throwsFormatException,
      );
      expect(
        () => NutritionPortionCalculator.calculate(
          data: data,
          columnId: 'azure_column_2',
          amount: 100,
          unit: 'ml',
          confirmed: true,
        ),
        throwsFormatException,
      );
      expect(
        () => NutritionPortionCalculator.calculate(
          data: data,
          columnId: 'azure_column_4',
          amount: 100,
          unit: 'g',
          confirmed: true,
        ),
        throwsFormatException,
      );
    },
  );

  test('serving-size conversions respect mass and volume', () {
    final data = AzureNutritionLayoutParser.parse(layoutFixture());
    expect(data.servingSizeAmount, 50);
    final portion = NutritionPortionCalculator.calculate(
      data: data,
      columnId: 'azure_column_2',
      amount: 2,
      unit: 'servings',
      confirmed: true,
    );
    expect(portion.nutrients[1].quantities.single.amount, 6);
    final weight = NutritionPortionCalculator.calculate(
      data: data,
      columnId: 'azure_column_1',
      amount: 25,
      unit: 'g',
      confirmed: true,
    );
    expect(weight.nutrients[1].quantities.single.amount, 1.5);
    expect(
      () => NutritionPortionCalculator.calculate(
        data: data,
        columnId: 'azure_column_3',
        amount: 2,
        unit: 'servings',
        confirmed: true,
      ),
      throwsFormatException,
    );
  });
  test(
    'US inline amounts retain their names, amounts, and separate percentages',
    () {
      final data = AzureNutritionLayoutParser.parse(
        layoutFromRows([
          ['Amount Per Serving', '% Daily Value'],
          ['Calories 230', null],
          ['Total Fat 8 g', '10%'],
          ['Includes 2 g Added Sugars', '4%'],
          ['Vitamin B12 2.4 µg', '100%'],
        ]),
      );
      expect(data.rows.map((r) => r.name), [
        'Calories',
        'Total Fat',
        'Added Sugars',
        'Vitamin B12',
      ]);
      expect(data.columns.first.basis, NutritionColumnBasis.perServing);
      expect(data.perServing!.energyKcal, 230);
      expect(data.perServing!.totalFatG, 8);
      expect(data.rows[2].cells['azure_inline_amount']!.displayText, '2 g');
      final portion = NutritionPortionCalculator.calculate(
        data: data,
        columnId: 'azure_inline_amount',
        amount: 2,
        unit: 'servings',
        confirmed: true,
      );
      expect(portion.nutrients[2].quantities.single.amount, 4);
    },
  );

  test(
    'wrapped headings and a separate unit column stay attached to their row',
    () {
      final data = AzureNutritionLayoutParser.parse(
        layoutFromRows([
          ['Nutrient', 'Unit', 'Per\n100 g', 'Per\nserving'],
          ['Inositol', 'mg', '40', '20'],
          ['Protein', 'g', '6', '3'],
        ]),
      );
      expect(data.columns.map((c) => c.basis), [
        NutritionColumnBasis.per100g,
        NutritionColumnBasis.perServing,
      ]);
      expect(data.rows[0].cells['azure_column_2']!.displayText, '40 mg');
      expect(data.perServing!.proteinG, 3);
    },
  );

  test(
    'uncertain serving metadata cannot scale otherwise reliable nutrients',
    () {
      final json = layoutFixture();
      for (final word in json['pages'][0]['words']) {
        if (word['content'] == '50') word['confidence'] = 0.2;
      }
      final data = AzureNutritionLayoutParser.parse(json);
      expect(data.servingSizeAmount, isNull);
      expect(data.perServing!.proteinG, 3);
      expect(
        () => NutritionPortionCalculator.calculate(
          data: data,
          columnId: 'azure_column_1',
          amount: 50,
          unit: 'g',
          confirmed: true,
        ),
        throwsFormatException,
      );
    },
  );
}
