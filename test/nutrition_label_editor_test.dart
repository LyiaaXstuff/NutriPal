import 'package:flutter_test/flutter_test.dart';
import 'package:nutripal/models/nutrition_label_data.dart';
import 'package:nutripal/services/nutrition_label_editor.dart';

import 'nutrition_analysis_service_test.dart' show homesoy;

void main() {
  test('removing nutrients that are not on the pack', () {
    final NutritionLabelData data = homesoy();
    final String first = data.nutrients[0].name;
    final String second = data.nutrients[1].name;

    final NutritionLabelData edited = NutritionLabelEditor.removeNutrients(data, <int>{0});

    expect(edited.nutrients.length, data.nutrients.length - 1);
    expect(edited.nutrients.map((NutrientRow r) => r.name), isNot(contains(first)));
    expect(edited.nutrients.first.name, second);
    expect(edited.notes, contains(NutritionLabelEditor.editedNote));
  });

  test('removing nothing returns the same label', () {
    final NutritionLabelData data = homesoy();

    expect(identical(NutritionLabelEditor.removeNutrients(data, <int>{}), data), isTrue);
  });

  test('setting and clearing the everyday measure', () {
    final NutritionLabelData cup =
        NutritionLabelEditor.setHouseholdMeasure(homesoy(), amount: 1, name: ' cup ');

    expect(cup.servingUnitAmount, 1);
    expect(cup.servingUnitName, 'cup');
    expect(cup.servingSizeAmount, homesoy().servingSizeAmount);

    final NutritionLabelData cleared =
        NutritionLabelEditor.setHouseholdMeasure(cup, amount: null, name: '');

    expect(cleared.servingUnitAmount, isNull);
    expect(cleared.servingUnitName, isNull);
  });

  test('changing the serving keeps the everyday measure', () {
    final NutritionLabelData cup =
        NutritionLabelEditor.setHouseholdMeasure(homesoy(), amount: 1, name: 'cup');

    final NutritionLabelData edited =
        NutritionLabelEditor.setServing(cup, servingSize: 250, servingsPerPackage: 4);

    expect(edited.servingSizeAmount, 250);
    expect(edited.servingUnitName, 'cup');
  });
}
