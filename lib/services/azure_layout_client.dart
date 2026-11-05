import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/nutrition_label_data.dart';
import 'azure_nutrition_layout_parser.dart';

class NutritionScanException implements Exception {
  final String message;
  const NutritionScanException(this.message);
  @override
  String toString() => message;
}

/// Calls NutriPal's backend. Azure credentials must never be placed in Flutter.
class AzureLayoutClient {
  static const configuredUrl = String.fromEnvironment('NUTRIPAL_SCAN_API_URL');
  static bool get isConfigured => configuredUrl.isNotEmpty;
  final Uri endpoint;
  final HttpClient Function() clientFactory;
  final Duration timeout;

  AzureLayoutClient({
    String baseUrl = configuredUrl,
    HttpClient Function()? clientFactory,
    this.timeout = const Duration(seconds: 110),
  }) : endpoint = Uri.parse(
         '${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/api/v1/nutrition/analyze',
       ),
       clientFactory = clientFactory ?? HttpClient.new;

  Future<NutritionLabelData> analyze(String imagePath) async {
    final client = clientFactory();
    try {
      return await _analyze(client, imagePath).timeout(timeout);
    } on NutritionScanException {
      rethrow;
    } on TimeoutException {
      throw const NutritionScanException(
        'Online scan timed out. Try again or use on-device scanning.',
      );
    } on IOException {
      throw const NutritionScanException(
        'Cannot reach online scanning. Check your connection or use on-device scanning.',
      );
    } on FormatException {
      throw const NutritionScanException(
        'Online scanning returned an unreadable result. Please try again.',
      );
    } on TypeError {
      throw const NutritionScanException(
        'Online scanning returned an unreadable result. Please try again.',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<NutritionLabelData> _analyze(
    HttpClient client,
    String imagePath,
  ) async {
    if (!['http', 'https'].contains(endpoint.scheme) || endpoint.host.isEmpty) {
      throw const NutritionScanException(
        'The online scanning address is invalid.',
      );
    }
    final image = File(imagePath);
    final length = await image.length();
    if (length > 12 * 1024 * 1024) {
      throw const NutritionScanException(
        'Photo exceeds 12 MB. Crop it to the label.',
      );
    }
    final request = await client.postUrl(endpoint);
    request.followRedirects = false;
    request.headers.contentType = ContentType.binary;
    request.contentLength = length;
    await request.addStream(image.openRead());
    final response = await request.close();
    final bytes = <int>[];
    await for (final chunk in response) {
      if (bytes.length + chunk.length > 8 * 1024 * 1024) {
        throw const NutritionScanException(
          'Online scan returned too much data. Crop to one label.',
        );
      }
      bytes.addAll(chunk);
    }
    if (response.statusCode != 200) {
      final message = switch (response.statusCode) {
        413 => 'Photo is too large. Crop it to the label.',
        415 => 'Choose a clear JPEG, PNG, or WebP photo.',
        503 => 'Online scanning is unavailable or not configured. Try again or use on-device scanning.',
        504 => 'Online scan timed out. Please try again.',
        _ =>
          'Online scanning could not complete this request. Please try again.',
      };
      throw NutritionScanException(message);
    }
    final payload = jsonDecode(utf8.decode(bytes));
    if (payload is! Map ||
        payload['provider'] != 'azure-layout' ||
        payload['analyzeResult'] is! Map) {
      throw const FormatException('Invalid scan response');
    }
    return AzureNutritionLayoutParser.parse(
      Map<String, dynamic>.from(payload['analyzeResult'] as Map),
    );
  }
}
