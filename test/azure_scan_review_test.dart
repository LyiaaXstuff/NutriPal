import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutripal/models/label_detection_status.dart';
import 'package:nutripal/screens/scan_preview_screen.dart';
import 'package:nutripal/screens/extracted_nutrition_review_screen.dart';
import 'package:nutripal/services/azure_layout_client.dart';
import 'package:nutripal/services/azure_nutrition_layout_parser.dart';
import 'package:nutripal/widgets/nutrition_portion_card.dart';

import 'azure_nutrition_layout_test.dart' show layoutFixture;

void main() {
  testWidgets(
    'Azure Analyze is available even when local detection rejects the photo',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var called = false;
      await tester.pumpWidget(
        MaterialApp(
          home: ScanPreviewScreen(
            imagePath: '/missing-test-photo.jpg',
            initialStatus: LabelDetectionStatus.notDetected,
            onlineScanning: true,
            onAnalyze: (_) async {
              called = true;
              return AzureNutritionLayoutParser.parse(layoutFixture());
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Analyse label'));
      await tester.pumpAndSettle();
      expect(called, isTrue);
      expect(find.byType(ExtractedNutritionReviewScreen), findsOneWidget);
      expect(
        find.text('Read with Azure Document Intelligence Layout'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'online scan error stays on the photo and offers explicit offline retry',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ScanPreviewScreen(
            imagePath: '/missing-test-photo.jpg',
            initialStatus: LabelDetectionStatus.detected,
            onlineScanning: true,
            onAnalyze: (_) async {
              throw const NutritionScanException(
                'Online scanning is unavailable.',
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Analyse label'));
      await tester.pump();
      expect(find.text('Online scanning is unavailable.'), findsOneWidget);
      expect(find.text('Use on-device'), findsOneWidget);
      expect(find.byType(ExtractedNutritionReviewScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'portion calculation is gated by confirmation and shows excluded nutrients',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: NutritionPortionCard(
                data: AzureNutritionLayoutParser.parse(layoutFixture()),
              ),
            ),
          ),
        ),
      );
      final button = find.widgetWithText(FilledButton, 'Calculate portion');
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      await tester.enterText(find.byType(TextField), '2');
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(button);
      await tester.pump();
      expect(find.text('Protein: 6.0 g'), findsOneWidget);
      expect(find.text('Inositol: 40.0 mg'), findsOneWidget);
      expect(
        find.textContaining('Excluded from this calculation: Sugars'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), '3');
      await tester.pump();
      expect(find.text('Protein: 6.0 g'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
