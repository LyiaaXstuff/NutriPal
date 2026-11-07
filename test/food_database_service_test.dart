import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutripal/models/nutrition_label_data.dart';
import 'package:nutripal/services/food_database_service.dart';

// A soy drink as Open Food Facts returns it: masses in
// grams, with the unit the contributor entered.
Map<String, dynamic> _soyDrink() => <String, dynamic>{
      'code': '9556001234567',
      'product_name': 'Soya Bean Drink',
      'brands': 'NutriBrand, Other',
      'quantity': '1 l',
      'serving_size': '250 ml',
      'serving_quantity': 250,
      'serving_quantity_unit': 'ml',
      'nutriments': <String, dynamic>{
        'energy-kcal_100g': 61,
        'energy-kcal_serving': 153,
        'energy-kj_100g': 256,
        'energy-kj_serving': 643,
        'energy_100g': 256,
        'carbohydrates_100g': 5.5,
        'carbohydrates_serving': 13.8,
        'sugars_100g': 4.4,
        'sugars_serving': 11,
        'proteins_100g': 2.6,
        'proteins_serving': 6.5,
        'fat_100g': 3.1,
        'fat_serving': 7.8,
        'saturated-fat_100g': 1.4,
        'saturated-fat_serving': 3.5,
        'sodium_100g': 0.048,
        'sodium_serving': 0.12,
        'sodium_unit': 'mg',
        'salt_100g': 0.12,
        'salt_serving': 0.3,
        'vitamin-d_100g': 0.000001,
        'vitamin-d_unit': 'µg',
        'vitamin-pp_100g': 0.0006,
        'nutrition-score-fr_100g': 2,
        'nova-group_100g': 4,
      },
    };

List<String> _cell(NutritionLabelData data, String name, int column) {
  final NutrientRow row =
      data.nutrients.firstWhere((NutrientRow r) => r.name == name);

  return row.valuesByColumn[column]
      .map((NutritionValue v) => '${v.amount} ${v.unit}')
      .toList();
}

void main() {
  group('Open Food Facts mapping', () {
    final NutritionLabelData data = FoodDatabaseService.fromOpenFoodFacts(
      _soyDrink(),
      barcode: '9556001234567',
    );

    test('product details and method', () {
      expect(data.extractionMethod, NutritionExtractionMethod.barcode);
      expect(data.productName, 'Soya Bean Drink');
      expect(data.productBrand, 'NutriBrand');
      expect(data.barcode, '9556001234567');
      expect(data.notes, isNotEmpty);
    });

    test('per 100 ml and per serving columns for a drink', () {
      expect(
        data.columns.map((NutritionColumn c) => c.basis).toList(),
        <NutritionColumnBasis>[
          NutritionColumnBasis.per100ml,
          NutritionColumnBasis.perServing,
        ],
      );
      expect(data.servingSizeAmount, 250);
      expect(data.servingSizeUnit, 'ml');
    });

    test('canonical names in label order, scores left out', () {
      final List<String> names =
          data.nutrients.map((NutrientRow r) => r.name).toList();

      expect(names.first, 'Energy');
      expect(names.indexOf('Carbohydrate'), lessThan(names.indexOf('Protein')));
      expect(names, contains('Total Sugars'));
      expect(names, contains('Saturated Fat'));
      expect(names, contains('Vitamin B3'));
      expect(names.any((String n) => n.contains('Score')), isFalse);
      expect(names.any((String n) => n.contains('Nova')), isFalse);

      // Salt is calculated from sodium: only sodium is shown.
      expect(names, contains('Sodium'));
      expect(names, isNot(contains('Salt')));
    });

    test('energy in kcal and kJ, masses in label units', () {
      expect(_cell(data, 'Energy', 0), <String>['61.0 kcal', '256.0 kJ']);
      expect(_cell(data, 'Energy', 1), <String>['153.0 kcal', '643.0 kJ']);
      expect(_cell(data, 'Sodium', 0), <String>['48.0 mg']);
      expect(_cell(data, 'Sodium', 1), <String>['120.0 mg']);
      expect(_cell(data, 'Vitamin D', 0), <String>['1.0 µg']);
      expect(_cell(data, 'Vitamin B3', 0), <String>['0.6 mg']);
      expect(_cell(data, 'Protein', 0), <String>['2.6 g']);
    });
  });

  group('lookup', () {
    test('returns the product for a known barcode', () async {
      final MockClient client = MockClient((http.Request request) async {
        expect(request.url.host, 'world.openfoodfacts.org');
        expect(request.url.path, '/api/v2/product/9556001234567.json');
        expect(request.headers['User-Agent'], startsWith('NutriPal'));

        return http.Response(
          jsonEncode(<String, dynamic>{'status': 1, 'product': _soyDrink()}),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });

      final NutritionLabelData? data =
          await FoodDatabaseService.lookup('9556001234567', client: client);

      expect(data, isNotNull);
      expect(data!.productName, 'Soya Bean Drink');
    });

    test('returns null for an unknown barcode', () async {
      final MockClient client = MockClient(
        (http.Request request) async => http.Response(
          jsonEncode(<String, dynamic>{'status': 0}),
          404,
        ),
      );

      expect(
        await FoodDatabaseService.lookup('9556001234560', client: client),
        isNull,
      );
    });

    test('rejects an invalid barcode', () {
      expect(
        () => FoodDatabaseService.lookup('123'),
        throwsA(isA<FoodDatabaseException>()),
      );
    });
  });
}
