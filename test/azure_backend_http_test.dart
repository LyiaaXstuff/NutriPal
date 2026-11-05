import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutripal/services/azure_layout_client.dart';
import 'package:nutripal/services/nutrition_portion_calculator.dart';

// Run against backend.tests.mock_server. This exercises the real HTTP upload,
// image validation and backend polling boundary; only the Azure service is mocked.
void main() {
  final apiUrl = Platform.environment['NUTRIPAL_TEST_API_URL'];
  test(
    'photo upload through backend produces an ordered, calculable label',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'azure-http-flow',
      );
      try {
        final image = await File('${directory.path}/label.png').writeAsBytes(
          base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAACgAAAAUCAIAAABwJOjsAAAAJUlEQVR4nO3NMQEAAAgDILV/5xljDxRgk0zDVVaxWCwWi8XiigcB4QMlssy/eAAAAABJRU5ErkJggg==',
          ),
        );
        final data = await AzureLayoutClient(baseUrl: apiUrl!)
            .analyze(image.path);
        expect(data.rows.map((r) => r.name), [
          'Energy',
          'Protein',
          'Inositol',
          'Vitamin B12',
          'Sugars',
        ]);
        expect(data.rows[2].cells['azure_column_2']!.displayText, 'Not read');
        final portion = NutritionPortionCalculator.calculate(
          data: data,
          columnId: 'azure_column_1',
          amount: 2,
          unit: 'servings',
          confirmed: true,
        );
        expect(portion.nutrients[1].quantities.single.amount, 6);
        expect(portion.nutrients[2].quantities.single.amount, 40);
        expect(portion.excludedNutrients, ['Sugars']);
      } finally {
        await directory.delete(recursive: true);
      }
    },
    skip: apiUrl == null
        ? 'Start backend.tests.mock_server and set NUTRIPAL_TEST_API_URL.'
        : false,
  );
}
