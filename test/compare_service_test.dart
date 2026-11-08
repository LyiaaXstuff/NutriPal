import 'package:flutter_test/flutter_test.dart';
import 'package:nutripal/models/nutrition_analysis.dart';
import 'package:nutripal/models/nutrition_label_data.dart';
import 'package:nutripal/services/compare_service.dart';
import 'package:nutripal/services/nutrition_analysis_service.dart';

// A label with a per serving column (optional) and a per
// 100 column. Values are {name: [amount, unit]}.
NutritionLabelData label({
  bool drink = false,
  double? servingSize,
  Map<String, (double, String)> per100 = const <String, (double, String)>{},
  Map<String, (double, String)> perServing = const <String, (double, String)>{},
}) {
  final bool hasServing = perServing.isNotEmpty;
  final bool has100 = per100.isNotEmpty;

  final List<NutritionColumn> columns = <NutritionColumn>[
    if (hasServing)
      const NutritionColumn(
        id: 'per_serving',
        label: 'Per serving',
        basis: NutritionColumnBasis.perServing,
        xCenter: 0,
      ),
    if (has100)
      NutritionColumn(
        id: drink ? 'per_100ml' : 'per_100g',
        label: drink ? 'Per 100 ml' : 'Per 100 g',
        basis: drink ? NutritionColumnBasis.per100ml : NutritionColumnBasis.per100g,
        xCenter: 1,
      ),
  ];

  final Set<String> names = <String>{...perServing.keys, ...per100.keys};

  List<NutritionValue> cell(Map<String, (double, String)> m, String n) {
    final (double, String)? v = m[n];

    if (v == null) return const <NutritionValue>[];

    return <NutritionValue>[NutritionValue(amount: v.$1, unit: v.$2, rawText: '${v.$1}')];
  }

  int order = 0;

  return NutritionLabelData(
    rawText: '',
    servingSizeAmount: servingSize,
    servingSizeUnit: servingSize == null ? null : (drink ? 'ml' : 'g'),
    columns: columns,
    nutrients: <NutrientRow>[
      for (final String n in names)
        NutrientRow(
          name: n,
          order: order++,
          valuesByColumn: <List<NutritionValue>>[
            if (hasServing) cell(perServing, n),
            if (has100) cell(per100, n),
          ],
        ),
    ],
  );
}

const NutritionProfile bloodPressureUser = NutritionProfile(
  areas: <HealthArea>{HealthArea.bloodPressure},
);

const NutritionProfile diabetesAndBpUser = NutritionProfile(
  areas: <HealthArea>{HealthArea.diabetes, HealthArea.bloodPressure},
);

void main() {
  group('Per 100 g / ml', () {
    test('lower sodium wins for a blood pressure user', () {
      final ProductComparison c = CompareService.compare(
        first: label(per100: {'Sodium': (480, 'mg'), 'Energy': (500, 'kcal')}),
        second: label(per100: {'Sodium': (120, 'mg'), 'Energy': (520, 'kcal')}),
        profile: bloodPressureUser,
        firstName: 'Crackers',
        secondName: 'Oat biscuits',
      );

      expect(c.overall, CompareResult.second);
      expect(c.areas.single.result, CompareResult.second);
      expect(c.areas.single.decidedBy, 'Sodium');
      expect(c.areas.single.reason, 'Oat biscuits is lower in sodium: 120 mg vs 480 mg per 100 g.');
      expect(c.summary, contains('Oat biscuits fits your health goals better per 100 g'));
    });

    test("nutrients outside the user's areas are never marked better", () {
      final ProductComparison c = CompareService.compare(
        first: label(per100: {'Sodium': (100, 'mg'), 'Protein': (20, 'g')}),
        second: label(per100: {'Sodium': (300, 'mg'), 'Protein': (2, 'g')}),
        profile: bloodPressureUser,
      );

      final ComparedNutrient protein =
          c.nutrients.firstWhere((ComparedNutrient n) => n.name == 'Protein');

      expect(protein.direction, NutrientDirection.neutral);
      expect(protein.result, CompareResult.same);
      expect(protein.mattersForUser, isFalse);
    });

    test('values within label rounding count as about the same', () {
      final ProductComparison c = CompareService.compare(
        first: label(per100: {'Sodium': (200, 'mg')}),
        second: label(per100: {'Sodium': (204, 'mg')}),
        profile: bloodPressureUser,
      );

      expect(c.areas.single.result, CompareResult.same);
      expect(c.overall, CompareResult.same);
    });

    test('a missing key nutrient gives "not enough information"', () {
      final ProductComparison c = CompareService.compare(
        first: label(per100: {'Sodium': (200, 'mg')}),
        second: label(per100: {'Energy': (400, 'kcal')}),
        profile: bloodPressureUser,
        firstName: 'A',
        secondName: 'B',
      );

      expect(c.areas.single.result, CompareResult.unknown);
      expect(c.areas.single.reason, "Not enough information: sodium is not on B's label.");
      expect(c.overall, CompareResult.unknown);
    });

    test('each product better in a different area is "mixed"', () {
      final ProductComparison c = CompareService.compare(
        first: label(per100: {'Sodium': (100, 'mg'), 'Carbohydrate': (70, 'g')}),
        second: label(per100: {'Sodium': (600, 'mg'), 'Carbohydrate': (20, 'g')}),
        profile: diabetesAndBpUser,
      );

      final AreaComparison diabetes =
          c.areas.firstWhere((AreaComparison a) => a.area == HealthArea.diabetes);
      final AreaComparison bp =
          c.areas.firstWhere((AreaComparison a) => a.area == HealthArea.bloodPressure);

      expect(diabetes.result, CompareResult.second);
      expect(bp.result, CompareResult.first);
      expect(c.overall, CompareResult.mixed);
    });

    test('next nutrient in rule order decides when the key one is the same', () {
      final ProductComparison c = CompareService.compare(
        first: label(per100: {'Carbohydrate': (50, 'g'), 'Total Sugars': (30, 'g')}),
        second: label(per100: {'Carbohydrate': (51, 'g'), 'Total Sugars': (5, 'g')}),
        profile: const NutritionProfile(areas: <HealthArea>{HealthArea.diabetes}),
      );

      expect(c.areas.single.result, CompareResult.second);
      expect(c.areas.single.decidedBy, 'Total Sugars');
    });

    test('fibre counts as a benefit (more is better)', () {
      expect(
        CompareService.better(6, 2, 'g', NutrientDirection.higherIsBetter),
        CompareResult.first,
      );
    });

    test('food vs drink adds a rough-comparison note', () {
      final ProductComparison c = CompareService.compare(
        first: label(per100: {'Sodium': (100, 'mg')}),
        second: label(drink: true, per100: {'Sodium': (10, 'mg')}),
        profile: bloodPressureUser,
      );

      expect(c.basisLabel, 'per 100 g / ml');
      expect(c.notes.single, contains('only a rough comparison'));
    });

    test('uses the FSA colour per 100 (salt = sodium x 2.5)', () {
      final ProductComparison c = CompareService.compare(
        first: label(per100: {'Sodium': (800, 'mg')}), // 2.0 g salt: high
        second: label(per100: {'Sodium': (100, 'mg')}), // 0.25 g salt: low
        profile: bloodPressureUser,
      );

      final ComparedNutrient sodium = c.nutrients.single;

      expect(sodium.firstLevel, NutrientLevel.high);
      expect(sodium.secondLevel, NutrientLevel.low);
    });
  });

  group('Per serving', () {
    test('uses the per serving column and warns when serving sizes differ', () {
      final ProductComparison c = CompareService.compare(
        first: label(
          servingSize: 30,
          perServing: {'Sodium': (150, 'mg')},
          per100: {'Sodium': (500, 'mg')},
        ),
        second: label(
          servingSize: 60,
          perServing: {'Sodium': (180, 'mg')},
          per100: {'Sodium': (300, 'mg')},
        ),
        profile: bloodPressureUser,
        basis: CompareBasis.perServing,
      );

      final ComparedNutrient sodium = c.nutrients.single;

      expect(sodium.first, 150);
      expect(sodium.second, 180);
      expect(c.areas.single.result, CompareResult.first);
      expect(c.notes.single, contains('serving sizes differ'));

      // Per 100 the other product is better: the basis
      // matters, which is why per 100 is the default.
      final ProductComparison per100 = CompareService.compare(
        first: label(
          servingSize: 30,
          perServing: {'Sodium': (150, 'mg')},
          per100: {'Sodium': (500, 'mg')},
        ),
        second: label(
          servingSize: 60,
          perServing: {'Sodium': (180, 'mg')},
          per100: {'Sodium': (300, 'mg')},
        ),
        profile: bloodPressureUser,
      );

      expect(per100.areas.single.result, CompareResult.second);
    });

    test('a label without a serving size uses 100 g and says so', () {
      final ProductComparison c = CompareService.compare(
        first: label(per100: {'Sodium': (100, 'mg')}),
        second: label(servingSize: 30, perServing: {'Sodium': (60, 'mg')}),
        profile: bloodPressureUser,
        basis: CompareBasis.perServing,
        firstName: 'Bread',
      );

      expect(c.notes, contains('Bread has no serving size on its label, so 100 g is used for it.'));
    });
  });

  group('Default basis', () {
    test('per 100 when both labels allow it', () {
      expect(
        CompareService.defaultBasis(
          label(per100: {'Sodium': (1, 'mg')}),
          label(servingSize: 30, perServing: {'Sodium': (1, 'mg')}),
        ),
        CompareBasis.per100,
      );
    });

    test('per serving when one label has no per 100 values or serving size', () {
      expect(
        CompareService.defaultBasis(
          label(per100: {'Sodium': (1, 'mg')}),
          label(perServing: {'Sodium': (1, 'mg')}),
        ),
        CompareBasis.perServing,
      );
    });
  });
}
