import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutripal/models/nutrition_label_data.dart';
import 'package:nutripal/screens/extracted_nutrition_review_screen.dart';
import 'package:nutripal/services/nutrition_table_parser.dart';
import 'package:nutripal/widgets/nutrition_table.dart';

import 'nutrition_table_parser_test.dart' show table;

void main() {
  testWidgets(
    'review preserves row order and scrolls through all columns on a phone',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final data = NutritionTableParser.parse(
        table(
          ['Per serving', 'Per 100 g', 'Per 100 ml'],
          [
            ['Protein', '3 g', '6 g', '9 g'],
            ['Inositol', '20 mg', null, '60 mg'],
            ['Vitamin B12', '2.4 µg', '4.8 µg', '7.2 µg'],
          ],
        ),
      );
      final boundary = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: boundary,
            child: ExtractedNutritionReviewScreen(data: data),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NutritionTable), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Protein')).dy,
        lessThan(tester.getTopLeft(find.text('Inositol')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Inositol')).dy,
        lessThan(tester.getTopLeft(find.text('Vitamin B12')).dy),
      );
      expect(find.text('Not read'), findsOneWidget);
      expect(find.text('Check photo'), findsOneWidget);
      final horizontal = find.byWidgetPredicate(
        (w) =>
            w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
      );
      await tester.drag(horizontal, const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(find.text('Per 100 ml').hitTestable(), findsOneWidget);
      expect(find.text('60 mg').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty OCR gives a useful retake message', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ExtractedNutritionReviewScreen(
          data: NutritionLabelData(rawText: ''),
        ),
      ),
    );
    expect(
      find.textContaining('No nutrient rows could be read.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
