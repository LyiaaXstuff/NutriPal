import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutripal/models/nutrition_label_data.dart';
import 'package:nutripal/services/nutrition_table_parser.dart';

NutritionOcrToken token(
  String text,
  double x,
  double y, {
  double? width,
  double height = 12,
}) => NutritionOcrToken(
  text: text,
  left: x,
  right: x + (width ?? text.length * 6),
  top: y,
  bottom: y + height,
);

List<NutritionOcrToken> table(
  List<String> headers,
  List<List<String?>> rows,
) => [
  token('Nutrition Information', 0, 0),
  for (var c = 0; c < headers.length; c++) token(headers[c], 240 + c * 150, 30),
  for (var r = 0; r < rows.length; r++) ...[
    token(rows[r][0]!, 0, 60 + r * 26),
    for (var c = 1; c < rows[r].length; c++)
      if (rows[r][c] != null)
        token(rows[r][c]!, 260 + (c - 1) * 150, 60 + r * 26),
  ],
];

NutritionCell cell(NutritionLabelData data, int row, int column) =>
    data.rows[row].cells[data.columns[column].id]!;

void main() {
  test(
    'percentage header supplies a unit without inheriting grams from the row',
    () {
      final data = NutritionTableParser.parse(
        table(
          ['Per serving', '% RNI'],
          [
            ['Protein (g)', '3', '5'],
            ['Sodium (mg)', '20', '1'],
          ],
        ),
      );
      expect(cell(data, 0, 1).displayText, '5 %');
      expect(cell(data, 1, 1).displayText, '1 %');
      expect(data.perServing!.proteinG, 3);
    },
  );

  test('unitless integers cannot merge across column gaps', () {
    final data = NutritionTableParser.parse(
      table(
        ['Per serving', 'Per 100 g'],
        [
          ['Protein (g)', '2', '400'],
          ['Sodium (mg)', '1', '200'],
        ],
      ),
    );
    expect(cell(data, 0, 0).displayText, '2 g');
    expect(cell(data, 0, 1).displayText, '400 g');
    expect(cell(data, 1, 0).displayText, '1 mg');
    expect(cell(data, 1, 1).displayText, '200 mg');
  });
  test('whole OCR lines preserve names and quantities', () {
    final data = NutritionTableParser.parse([
      token('Per serving', 120, 0),
      token('Protein 3 g', 0, 30),
      token('Sodium 20 mg', 0, 60),
      token('Vitamin B12 2.4 mcg', 0, 90),
    ]);
    expect(data.rows.map((r) => r.name), ['Protein', 'Sodium', 'Vitamin B12']);
    expect(data.perServing!.proteinG, 3);
    expect(data.perServing!.sodiumMg, 20);
  });
  test('close adjacent rows remain separate', () {
    final data = NutritionTableParser.parse([
      token('Per serving', 240, 0),
      token('Protein', 0, 30),
      token('4 g', 260, 31),
      token('Sodium', 0, 43),
      token('7 mg', 260, 44),
    ]);
    expect(data.rows.map((r) => r.name), ['Protein', 'Sodium']);
    expect(cell(data, 0, 0).displayText, '4 g');
    expect(cell(data, 1, 0).displayText, '7 mg');
  });
  test('empty OCR returns an empty result', () {
    final data = NutritionTableParser.parse([]);
    expect(data.rows, isEmpty);
    expect(data.columns, isEmpty);
    expect(data.canCalculatePortion, isFalse);
  });

  test(
    'keeps arbitrary nutrients and printed order instead of a fixed list',
    () {
      final data = NutritionTableParser.parse(
        table(
          ['Per serving'],
          [
            ['Protein', '8 g'],
            ['Inositol', '25 mg'],
            ['Taurine', '40 mg'],
            ['Lutein', '0.2 mg'],
            ['Salt', '1 g'],
            ['Vitamin B12', '2.4 µg'],
            ['Omega-3', '200 mg'],
            ['Beta glucan', '1 g'],
          ],
        ),
      );
      expect(data.rows.map((r) => r.name), [
        'Protein',
        'Inositol',
        'Taurine',
        'Lutein',
        'Salt',
        'Vitamin B12',
        'Omega-3',
        'Beta glucan',
      ]);
      expect(data.rows.length, 8);
      expect(cell(data, 5, 0).quantities.single.unit, 'µg');
      expect(cell(data, 6, 0).quantities.single.amount, 200);
      expect(data.perServing!.proteinG, 8);
    },
  );

  test('preserves three columns and a missing middle cell in either order', () {
    for (final headers in [
      ['Per serving', 'Per 100 g', 'Per 100 ml'],
      ['Per 100 ml', 'Per 100 g', 'Per serving'],
    ]) {
      final data = NutritionTableParser.parse(
        table(headers, [
          ['Protein', '2 g', '4 g', '6 g'],
          ['Sodium', '3 mg', null, '9 mg'],
          ['Fibre', '1 g', '2 g', '3 g'],
        ]),
      );
      expect(data.columns.map((c) => c.label), headers);
      expect(cell(data, 1, 0).quantities.single.amount, 3);
      expect(cell(data, 1, 1).quantities, isEmpty);
      expect(cell(data, 1, 2).quantities.single.amount, 9);
      expect(cell(data, 1, 1).needsReview, isTrue);
      expect(
        data.per100,
        isNull,
      ); // g and ml cannot collapse into a single basis.
    }
  });

  test('does not overwrite totals with sugar/fat subtypes', () {
    final data = NutritionTableParser.parse(
      table(
        ['Per serving'],
        [
          ['Total fat', '8 g'],
          ['Saturated fat', '2 g'],
          ['Unsaturated fat', '6 g'],
          ['Polyunsaturated fat', '3 g'],
          ['Total sugars', '12 g'],
          ['Added sugars', '4 g'],
          ['Sugar alcohol', '1 g'],
        ],
      ),
    );
    expect(data.perServing!.totalFatG, 8);
    expect(data.perServing!.saturatedFatG, 2);
    expect(data.perServing!.sugarsG, 12);
    expect(data.rows.length, 7);
  });

  test('joins separated number, comparator and unit, preserves decimals and precision', () {
    final data = NutritionTableParser.parse([
      token('Per serving', 250, 0),
      token('Sodium', 0, 30),
      token('<', 260, 30),
      token('0,05', 272, 30),
      token('mg', 304, 30),
      token('Calcium', 0, 60),
      token('1,200', 260, 60),
      token('mg', 296, 60),
      token('Folate', 0, 90),
      token('0.0004', 260, 90),
      token('g', 302, 90),
    ]);
    expect(cell(data, 0, 0).quantities.single.amount, 0.05);
    expect(cell(data, 0, 0).displayText, '<0,05 mg');
    expect(cell(data, 1, 0).quantities.single.amount, 1200);
    expect(cell(data, 2, 0).displayText, '0.0004 g');
    expect(data.perServing!.sodiumMg, isNull); // not an exact quantity
  });

  test(
    'handles unit annotations on names and leaves unknown units for review',
    () {
      final data = NutritionTableParser.parse(
        table(
          ['Per serving', 'Per 100 g'],
          [
            ['Protein (g)', '3.5', '7'],
            ['Sodium (mg)', '20', '40'],
            ['Taurine', '12', '24'],
          ],
        ),
      );
      expect(data.rows.map((r) => r.name), ['Protein', 'Sodium', 'Taurine']);
      expect(cell(data, 0, 0).displayText, '3.5 g');
      expect(cell(data, 1, 1).displayText, '40 mg');
      expect(cell(data, 2, 0).needsReview, isTrue);
      expect(data.perServing!.proteinG, 3.5);
    },
  );

  test('retains kJ and kcal within one energy cell', () {
    final data = NutritionTableParser.parse(
      table(
        ['Per serving', 'Per 100 g'],
        [
          ['Energy', '420 kJ / 100 kcal', '840 kJ / 200 kcal'],
          ['Protein', '2 g', '4 g'],
          ['Fat', '3 g', '6 g'],
        ],
      ),
    );
    expect(cell(data, 0, 0).quantities.map((q) => q.amount), [420, 100]);
    expect(cell(data, 0, 1).quantities.map((q) => q.amount), [840, 200]);
    expect(data.perServing!.energyKcal, 100);
    expect(data.per100!.energyKj, 840);
  });

  test('daily value percentages never replace quantities, including includes syntax', () {
    final data = NutritionTableParser.parse([
      token('Amount per serving', 220, 0),
      token('% Daily Value', 440, 0),
      token('Calories', 0, 30),
      token('230', 260, 30),
      token('Total sugars', 0, 60),
      token('12 g', 260, 60),
      token('24%', 460, 60),
      token('Includes', 0, 90),
      token('2g', 260, 90),
      token('Added Sugars', 290, 90),
      token('4%', 460, 90),
      token('Vitamin D', 0, 120),
      token('5 µg', 260, 120),
      token('25%', 460, 120),
    ]);
    expect(data.rows.map((r) => r.name), [
      'Calories',
      'Total sugars',
      'Added Sugars',
      'Vitamin D',
    ]);
    expect(cell(data, 0, 0).displayText, '230 kcal');
    expect(cell(data, 2, 0).displayText, '2 g');
    expect(cell(data, 2, 1).displayText, '4 %');
    expect(data.perServing!.sugarsG, 12);
  });

  test('reconstructs wrapped headers and wrapped names', () {
    final data = NutritionTableParser.parse([
      token('Per', 260, 0),
      token('Per', 410, 0),
      token('Serving', 250, 16),
      token('100', 405, 16),
      token('ml', 429, 16),
      token('Polyunsaturated', 0, 50),
      token('fat', 0, 66),
      token('1 g', 260, 66),
      token('2 g', 410, 66),
      token('Protein', 0, 95),
      token('3 g', 260, 95),
      token('6 g', 410, 95),
    ]);
    expect(data.columns.map((c) => c.basis), [
      NutritionColumnBasis.perServing,
      NutritionColumnBasis.per100ml,
    ]);
    expect(data.rows.map((r) => r.name), ['Polyunsaturated fat', 'Protein']);
    expect(cell(data, 0, 0).displayText, '1 g');
  });

  test('random OCR block order and modest skew do not change row pairing', () {
    final original = table(
      ['Per 100 g', 'Per serving'],
      [
        ['Protein', '10 g', '5 g'],
        ['Sodium', '40 mg', '20 mg'],
        ['Fibre', '6 g', '3 g'],
      ],
    );
    for (var seed = 0; seed < 20; seed++) {
      final shuffled =
          original
              .map(
                (t) => NutritionOcrToken(
                  text: t.text,
                  left: t.left,
                  right: t.right,
                  top: t.top + t.x * 0.08,
                  bottom: t.bottom + t.x * 0.08,
                ),
              )
              .toList()
            ..shuffle(Random(seed));
      final data = NutritionTableParser.parse(shuffled, skew: 0.08);
      expect(data.rows.map((r) => r.name), ['Protein', 'Sodium', 'Fibre']);
      expect(data.perServing!.sodiumMg, 20);
      expect(data.per100!.fibreG, 6);
    }
  });

  test('duplicate OCR boxes are removed but equal numbers and repeated rows are retained', () {
    final tokens = table(
      ['Per serving', 'Per 100 g'],
      [
        ['Protein', '2 g', '2 g'],
        ['Protein', '3 g', '3 g'],
      ],
    );
    final data = NutritionTableParser.parse([...tokens, tokens[4]]);
    expect(data.rows.length, 2);
    expect(cell(data, 0, 0).quantities.length, 1);
    expect(cell(data, 0, 1).quantities.single.amount, 2);
    expect(
      data.perServing,
      isNull,
    ); // duplicate canonical rows cannot overwrite
  });

  test('no heading means unknown basis, no invented per-serving values', () {
    final data = NutritionTableParser.parse([
      token('Protein', 0, 30),
      token('3 g', 260, 30),
      token('Sodium', 0, 60),
      token('12 mg', 260, 60),
    ]);
    expect(data.rows.length, 2);
    expect(data.columns.single.basis, NutritionColumnBasis.unknown);
    expect(data.perServing, isNull);
    expect(data.canCalculatePortion, isFalse);
  });

  test('serving and packaging numbers and footnotes are not nutrient rows', () {
    final data = NutritionTableParser.parse([
      token('Serving size: 1/2 bottle (250 ml)', 0, 0),
      token('Servings per container: 2', 0, 20),
      ...table(
        ['Per 100 ml'],
        [
          ['Protein', '4 g'],
          ['Sodium', '12 mg'],
        ],
      ).map(
        (t) => NutritionOcrToken(
          text: t.text,
          left: t.left,
          right: t.right,
          top: t.top + 40,
          bottom: t.bottom + 40,
        ),
      ),
      token('* Percent Daily Values are based on 2000 kcal', 0, 200),
      token('Ingredients: salt 2 g', 0, 230),
    ]);
    expect(data.rows.map((r) => r.name), ['Protein', 'Sodium']);
    expect(data.servingSizeAmount, 250);
    expect(data.servingSizeUnit, 'ml');
    expect(data.servingUnitAmount, 0.5);
    expect(data.servingsPerPackage, 2);
    expect(data.canCalculatePortion, isTrue);
  });

  test(
    'missing nutrient values stay visible and orphan values do not steal a row',
    () {
      final data = NutritionTableParser.parse([
        token('Per serving', 240, 0),
        token('Sodium', 0, 40),
        token('Protein', 0, 70),
        token('4 g', 260, 70),
        token('99 mg', 260, 110),
      ]);
      expect(data.rows.map((r) => r.name), ['Sodium', 'Protein']);
      expect(cell(data, 0, 0).displayText, 'Not read');
      expect(cell(data, 1, 0).displayText, '4 g');
      expect(data.extractionWarnings.any((s) => s.contains('99 mg')), isTrue);
    },
  );

  test('ambiguous cell collisions retain evidence and block calculation', () {
    final data = NutritionTableParser.parse([
      token('Per serving', 250, 0),
      token('Protein', 0, 30),
      token('2 g', 255, 30),
      token('3 g', 290, 30),
    ]);
    expect(cell(data, 0, 0).quantities.length, 2);
    expect(cell(data, 0, 0).needsReview, isTrue);
    expect(data.perServing, isNull);
  });

  test('handles Malay headers and mass-volume mismatch safely', () {
    final data = NutritionTableParser.parse([
      token('Saiz Hidangan: 25 g', 0, 0),
      token('Setiap 100ml', 250, 30),
      token('Tenaga', 0, 60),
      token('100 kcal', 260, 60),
      token('Natrium', 0, 90),
      token('0.02 g', 260, 90),
    ]);
    expect(data.per100!.energyKcal, 100);
    expect(data.per100!.sodiumMg, 20);
    expect(data.canCalculatePortion, isFalse);
  });
}
