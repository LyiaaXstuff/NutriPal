import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:nutripal/models/label_detection_status.dart';
import 'package:nutripal/screens/extracted_nutrition_review_screen.dart';
import 'package:nutripal/screens/scan_preview_screen.dart';
import 'package:nutripal/services/nutrition_label_parser_service.dart';

import 'nutrition_table_parser_test.dart' show table;

// Synthetic ML Kit response: recognizer order deliberately differs from table
// reading order. Native image recognition is mocked, not claimed as tested.
Map<String, dynamic> ocrResponse({bool elements = true, double? confidence}) {
  final tokens = table(
    ['Per serving', 'Per 100 g'],
    [
      ['Protein', '3 g', '6 g'],
      ['Inositol', '20 mg', '40 mg'],
    ],
  );
  return {
    'text': 'Nutrition Information\nPer serving Per 100 g\nProtein 3 g 6 g\nInositol 20 mg 40 mg',
    'blocks': tokens.reversed.map((t) {
      final geometry = <String, dynamic>{
        'text': t.text,
        'rect': {
          'left': t.left,
          'top': t.top,
          'right': t.right,
          'bottom': t.bottom,
        },
        'points': <Map<String, int>>[],
        'recognizedLanguages': <String>[],
      };
      return {
        ...geometry,
        'lines': [
          {
            ...geometry,
            'confidence': confidence,
            'elements': elements
                ? [
                    {...geometry, 'confidence': confidence, 'symbols': []},
                  ]
                : [],
          },
        ],
      };
    }).toList(),
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('google_mlkit_text_recognizer');
  late Directory temp;
  late File image;
  final calls = <String>[];
  Completer<void>? closed;

  setUp(() async {
    calls.clear();
    closed = Completer<void>();
    temp = await Directory.systemTemp.createTemp('nutrition-label-test-');
    image = await File('${temp.path}/label.png').writeAsBytes(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==',
      ),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          if (call.method == 'vision#startTextRecognizer') return ocrResponse();
          if (call.method == 'vision#closeTextRecognizer' &&
              !closed!.isCompleted) {
            closed!.complete();
          }
          return null;
        });
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await temp.delete(recursive: true);
  });

  test('image service maps OCR geometry and releases the recognizer', () async {
    final data = await NutritionLabelParserService.parseImage(image.path);
    expect(data.rows.map((r) => r.name), ['Protein', 'Inositol']);
    expect(data.perServing!.proteinG, 3);
    expect(data.per100!.proteinG, 6);
    expect(calls, ['vision#startTextRecognizer', 'vision#closeTextRecognizer']);
  });

  test('native OCR exceptions also release the recognizer', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          if (call.method == 'vision#startTextRecognizer') {
            throw PlatformException(code: 'unreadable');
          }
          return null;
        });
    await expectLater(
      NutritionLabelParserService.parseImage(image.path),
      throwsA(isA<PlatformException>()),
    );
    expect(calls.last, 'vision#closeTextRecognizer');
  });

  test('line fallback and low OCR confidence retain evidence for review', () {
    final data = NutritionLabelParserService.parseRecognizedText(
      RecognizedText.fromJson(ocrResponse(elements: false, confidence: 0.2)),
    );
    expect(data.rows.length, 2);
    expect(data.rows.every((r) => r.needsReview), isTrue);
    expect(data.perServing, isNull);
    expect(data.rows.first.cells.values.first.displayText, '3 g');
  });

  for (final status in [
    LabelDetectionStatus.detected,
    LabelDetectionStatus.unclear,
  ]) {
    testWidgets('$status preview opens the review with parsed values', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: ScanPreviewScreen(imagePath: image.path, initialStatus: status),
        ),
      );
      await tester.pumpAndSettle();
      final label = status == LabelDetectionStatus.detected
          ? 'Analyse label'
          : 'Review readable values';
      await tester.runAsync(() async {
        await tester.tap(find.text(label));
        await closed!.future.timeout(const Duration(seconds: 5));
      });
      await tester.pumpAndSettle();
      expect(find.byType(ExtractedNutritionReviewScreen), findsOneWidget);
      expect(find.text('Protein'), findsOneWidget);
      expect(find.text('Inositol'), findsOneWidget);
      expect(find.text('3 g'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
