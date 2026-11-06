import 'package:flutter_test/flutter_test.dart';
import 'package:nutripal/models/nutrition_label_data.dart';
import 'package:nutripal/services/label_reading_assessor.dart';

// Cloud Function response for the canned tuna label.
Map<String, dynamic> _tunaJson({
  double natrium = 107,
  double protein = 8.2,
  double tenaga = 39,
}) {
  Map<String, dynamic> cell(double amount, String unit, String printed) =>
      <String, dynamic>{
        'values': <Map<String, dynamic>>[
          <String, dynamic>{'amount': amount, 'unit': unit, 'printed': printed},
        ],
      };

  return <String, dynamic>{
    'label': <String, dynamic>{
      'is_nutrition_table': true,
      'serving_size': <String, dynamic>{'amount': 36, 'unit': 'g'},
      'servings_per_package': 3,
      'columns': <Map<String, dynamic>>[
        <String, dynamic>{'label': 'Setiap hidangan', 'basis': 'per_serving'},
        <String, dynamic>{'label': 'Setiap 100g', 'basis': 'per_100g'},
        <String, dynamic>{'label': '%NRV', 'basis': 'percent'},
      ],
      'nutrients': <Map<String, dynamic>>[
        <String, dynamic>{
          'name': 'Tenaga',
          'cells': <Map<String, dynamic>>[
            cell(tenaga, 'kcal', '${tenaga.toInt()}kcal'),
            cell(108, 'kcal', '108kcal'),
            cell(2, '%', '2%'),
          ],
        },
        <String, dynamic>{
          'name': 'Protein',
          'cells': <Map<String, dynamic>>[
            cell(protein, 'g', '${protein}g'),
            cell(22.9, 'g', '22.9g'),
          ],
        },
        <String, dynamic>{
          'name': 'Lemak',
          'cells': <Map<String, dynamic>>[
            cell(0.5, 'g', '0.5g*'),
            cell(1.5, 'g', '1.5g*'),
          ],
        },
        <String, dynamic>{
          'name': 'Natrium',
          'cells': <Map<String, dynamic>>[
            cell(natrium, 'mg', '${natrium.toInt()}mg'),
            cell(296, 'mg', '296mg'),
          ],
        },
        <String, dynamic>{
          'name': 'Vitamin B12',
          'cells': <Map<String, dynamic>>[
            cell(0.7, 'mcg', '0.7µg'),
            <String, dynamic>{
              'values': <Map<String, dynamic>>[
                <String, dynamic>{'amount': null, 'unit': 'µg', 'printed': '?'},
              ],
            },
          ],
        },
      ],
      'notes': <String>[],
    },
  };
}

// What ML Kit read from the same table (with its usual
// mistakes, e.g. 0.5g -> 0.59).
const String _tunaOcrText = '''
KETERANGAN PEMAKANAN
Hidangan setiap pek: 3
Saiz hidangan: 36g (Berat tanpa air)
Setiap hidangan Setiap 100g
Tenaga 39kcal 108kcal
Protein 8.2g 22.9g
Lemak 0.59 1.5g*
Natrium 107mg 296mg
Vitamin B12 0.7µg 2.0µg
''';

void main() {
  group('fromAiJson', () {
    test('maps the Cloud Function response', () {
      final NutritionLabelData data =
          LabelReadingAssessor.fromAiJson(_tunaJson());

      expect(data.extractionMethod, NutritionExtractionMethod.ai);
      expect(data.servingSizeAmount, 36);
      expect(data.servingsPerPackage, 3);

      // % NRV column dropped.
      expect(
        data.columns.map((NutritionColumn c) => c.basis).toList(),
        <NutritionColumnBasis>[
          NutritionColumnBasis.perServing,
          NutritionColumnBasis.per100g,
        ],
      );

      expect(data.nutrients.length, 5);
      expect(data.nutrients.first.valuesByColumn.length, 2);

      final NutrientRow b12 = data.nutrients.last;

      expect(b12.valuesByColumn[0].single.unit, 'µg');
      expect(b12.valuesByColumn[0].single.amount, 0.7);

      // Unreadable cell stays empty instead of guessed.
      expect(b12.valuesByColumn[1], isEmpty);
    });
  });

  group('verifyAiReading', () {
    test('accepts an AI reading the OCR agrees with', () {
      final NutritionLabelData ai =
          LabelReadingAssessor.fromAiJson(_tunaJson());

      final AiVerification check =
          LabelReadingAssessor.verifyAiReading(ai, _tunaOcrText);

      expect(check.ocrAvailable, isTrue);
      expect(check.checked, 9);
      expect(check.confirmed, 9);
      expect(check.inconsistentRows, isEmpty);
      expect(check.accepted, isTrue);
    });

    test('rejects an AI reading with invented numbers', () {
      final NutritionLabelData ai = LabelReadingAssessor.fromAiJson(
        _tunaJson(natrium: 170, protein: 9.4, tenaga: 93),
      );

      final AiVerification check =
          LabelReadingAssessor.verifyAiReading(ai, _tunaOcrText);

      expect(check.confirmed, 6);
      expect(check.accepted, isFalse);
      expect(
        check.unconfirmed.any((String s) => s.startsWith('Natrium')),
        isTrue,
      );
    });
  });

  group('problems', () {
    test('a complete, consistent reading needs no AI check', () {
      final NutritionLabelData data =
          LabelReadingAssessor.fromAiJson(_tunaJson());

      // Remove the deliberately empty Vitamin B12 cell.
      final NutritionLabelData complete = data.copyWith(
        nutrients: data.nutrients.take(4).toList(),
        notes: const <String>[],
      );

      expect(LabelReadingAssessor.problems(complete), isEmpty);
    });

    test('flags too few rows, corrections and bad maths', () {
      final NutritionLabelData data = LabelReadingAssessor.fromAiJson(
        _tunaJson(natrium: 170),
      ).copyWith(notes: const <String>['"0.59" was read as 0.5 g']);

      final List<String> problems = LabelReadingAssessor.problems(data);

      expect(problems.any((String p) => p.contains('corrected')), isTrue);
      expect(problems.any((String p) => p.contains('Natrium')), isTrue);

      final NutritionLabelData tiny = data.copyWith(
        nutrients: data.nutrients.take(2).toList(),
      );

      expect(
        LabelReadingAssessor.problems(tiny)
            .any((String p) => p.startsWith('Only 2')),
        isTrue,
      );
    });
  });
}
