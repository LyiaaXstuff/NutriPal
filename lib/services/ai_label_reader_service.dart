import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/nutrition_label_data.dart';
import 'label_reading_assessor.dart';

// =======================================================
// AI LABEL READER
// =======================================================
//
// Sends the cropped nutrition table to the
// extractNutritionLabel Cloud Function, which asks Claude
// to read it. The Anthropic API key stays on the server.
// =======================================================

class AiLabelReaderException implements Exception {
  final String message;

  const AiLabelReaderException(this.message);

  @override
  String toString() => message;
}

class AiLabelReaderService {
  AiLabelReaderService._();

  // Must match `region` in functions/index.js.
  static const String region = 'asia-southeast1';

  static const String functionName = 'extractNutritionLabel';

  /// True after Firebase.initializeApp() succeeded.
  static bool get isAvailable => Firebase.apps.isNotEmpty;

  static Future<NutritionLabelData> read(Uint8List jpegBytes) async {
    if (!isAvailable) {
      throw const AiLabelReaderException('Firebase is not set up.');
    }

    final HttpsCallable callable = FirebaseFunctions.instanceFor(
      region: region,
    ).httpsCallable(
      functionName,
      options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
    );

    try {
      final HttpsCallableResult<dynamic> result = await callable.call(
        <String, dynamic>{
          'imageBase64': base64Encode(jpegBytes),
          'mediaType': 'image/jpeg',
        },
      );

      final Object? data = result.data;

      if (data is! Map) {
        throw const AiLabelReaderException('Unexpected AI response.');
      }

      final Map<String, dynamic> json = Map<String, dynamic>.from(data);

      final Map<dynamic, dynamic>? label = json['label'] as Map?;

      if (label != null && label['is_nutrition_table'] == false) {
        throw const AiLabelReaderException(
          'No nutrition table was found in the photo.',
        );
      }

      return LabelReadingAssessor.fromAiJson(json);
    } on FirebaseFunctionsException catch (error) {
      throw AiLabelReaderException(
        error.message ?? 'AI reading failed (${error.code}).',
      );
    }
  }
}
