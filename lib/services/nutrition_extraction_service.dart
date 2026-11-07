import 'package:flutter/foundation.dart';

import '../models/nutrition_label_data.dart';
import 'ai_label_reader_service.dart';
import 'label_reading_assessor.dart';
import 'nutrition_label_parser_service.dart';

// =======================================================
// NUTRITION EXTRACTION SERVICE
// =======================================================
//
// The agent loop for reading a label:
//
//   PERCEIVE  On-device OCR reads the nutrition table only
//             (free, offline, private).
//
//   ASSESS    Is that reading complete and consistent?
//             (rows, headings, units, energy row, per
//             serving vs per 100 g maths)
//
//   ACT       If not, send the cropped table image to
//             Claude through the Cloud Function.
//
//   VERIFY    Check every AI number against the on-device
//             OCR text and the serving-size maths.
//
//   DECIDE    Use the AI reading only if it passes; tell
//             the user which values could not be confirmed.
//
// =======================================================

class NutritionExtractionService {
  NutritionExtractionService._();

  /// Set to true to always ask the AI (useful when
  /// evaluating on-device vs AI accuracy for the report).
  static bool alwaysUseAi = false;

  static Future<NutritionLabelData> extract(String imagePath) async {
    // ---------------------------------------------------
    // PERCEIVE
    // ---------------------------------------------------

    final OnDeviceLabelReading reading =
        await NutritionLabelParserService.readLabel(imagePath);

    final NutritionLabelData onDevice = reading.data;

    // ---------------------------------------------------
    // ASSESS
    // ---------------------------------------------------

    final List<String> problems = LabelReadingAssessor.problems(onDevice);

    _log('on-device: ${onDevice.nutrients.length} rows, problems: $problems');

    if (problems.isEmpty && !alwaysUseAi) return onDevice;

    // Arabic, Thai... on the label: the phone kept only the
    // English / Malay names.
    final List<String> scriptNote = <String>[
      if (onDevice.hasUnreadableScript)
        'Part of this label is in a script the phone cannot read '
            '(for example Arabic). Only the English / Malay names were used.',
    ];

    if (!AiLabelReaderService.isAvailable) {
      _log('AI reading not available (Firebase not set up)');
      return onDevice.copyWith(notes: <String>[...onDevice.notes, ...scriptNote]);
    }

    // ---------------------------------------------------
    // ACT
    // ---------------------------------------------------

    final NutritionLabelData ai;

    try {
      ai = await AiLabelReaderService.read(reading.tableImage);
    } on AiLabelReaderException catch (error) {
      _log('AI reading failed: $error');

      return onDevice.copyWith(
        notes: <String>[
          ...onDevice.notes,
          ...scriptNote,
          'AI check was not available: ${error.message}',
        ],
      );
    } catch (error) {
      _log('AI reading failed: $error');

      return onDevice.copyWith(
        notes: <String>[
          ...onDevice.notes,
          ...scriptNote,
          'AI check was not available. Please check the values carefully.',
        ],
      );
    }

    // ---------------------------------------------------
    // VERIFY
    // ---------------------------------------------------

    final AiVerification check =
        LabelReadingAssessor.verifyAiReading(ai, reading.tableText);

    _log(
      'AI: ${ai.nutrients.length} rows, confirmed '
      '${check.confirmed}/${check.checked}, '
      'inconsistent ${check.inconsistentRows}, accepted ${check.accepted}',
    );

    // ---------------------------------------------------
    // DECIDE
    // ---------------------------------------------------

    final List<String> aiNotes = <String>[
      ...ai.notes,
      if (!check.ocrAvailable)
        'Read by AI. These values could not be cross-checked on the phone, '
            'so please compare them with the label.',
      for (final String value in check.unconfirmed)
        'Please check: $value (not confirmed by on-device reading)',
      for (final String row in check.inconsistentRows)
        'Please check $row: per serving and per 100 g values do not match '
            'the serving size',
    ];

    final NutritionLabelData aiResult = ai.copyWith(
      rawText: reading.tableText,
      servingSizeAmount: ai.servingSizeAmount ?? onDevice.servingSizeAmount,
      servingSizeUnit: ai.servingSizeUnit ?? onDevice.servingSizeUnit,
      servingsPerPackage: ai.servingsPerPackage ?? onDevice.servingsPerPackage,
      notes: aiNotes,
    );

    if (check.accepted) return aiResult;

    // The on-device reading is unusable but the AI found a
    // table: show it, clearly marked for checking.
    if (onDevice.nutrients.length < 3 && ai.nutrients.length >= 3) {
      return aiResult.copyWith(
        notes: <String>[
          'The AI reading could not be fully confirmed. '
              'Please compare every value with the label.',
          ...aiNotes,
        ],
      );
    }

    return onDevice.copyWith(
      notes: <String>[
        ...onDevice.notes,
        ...scriptNote,
        'An AI check did not confirm this reading. '
            'Please compare the values with the label.',
      ],
    );
  }

  static void _log(String message) {
    if (kDebugMode) debugPrint('[NutriPal extraction] $message');
  }
}
