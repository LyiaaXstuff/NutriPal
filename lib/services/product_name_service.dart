import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../models/nutrition_label_data.dart';
import 'barcode_reader_service.dart';
import 'food_database_service.dart';

// =======================================================
// PRODUCT NAME SERVICE (label photo scans)
// =======================================================
//
// The nutrition table does not contain the product's name,
// so NutriPal looks for it elsewhere in the same photo.
// Runs alongside the label reading and never changes a
// nutrition value:
//
//   1. BARCODE   Is a product barcode visible in the photo?
//                (on-device ML Kit, free)
//                -> look it up in Open Food Facts and take
//                   ONLY the name and brand.
//
//   2. AI        No barcode, or Open Food Facts does not
//                know it: send a small copy of the photo
//                to the readProductName Cloud Function,
//                which returns only a clearly printed name
//                (or nothing).
//
//   3. NOTHING   The product stays "Scanned product"; the
//                user can rename it on the result screen.
//
// Any failure (offline, timeout, no Firebase) just means
// "no name found": the scan itself always continues.
// =======================================================

enum ProductNameSource { barcode, photo }

class DetectedProductName {
  final String name;
  final String? brand;
  final ProductNameSource source;

  const DetectedProductName({
    required this.name,
    required this.brand,
    required this.source,
  });

  @override
  String toString() => '$brand / $name ($source)';
}

class ProductNameService {
  ProductNameService._();

  // Must match `region` in functions/index.js.
  static const String region = 'asia-southeast1';

  static const String functionName = 'readProductName';

  // A name is small text on the pack: 1280 px is enough
  // and keeps the upload and the AI cost small.
  static const int _maxImageSide = 1280;

  /// Finds the product name for a label photo, or null.
  static Future<DetectedProductName?> detect(String imagePath) async {
    try {
      return await _fromBarcode(imagePath) ?? await _fromPhoto(imagePath);
    } catch (error) {
      _log('name detection failed: $error');
      return null;
    }
  }

  // =====================================================
  // 1. BARCODE IN THE PHOTO
  // =====================================================

  static Future<DetectedProductName?> _fromBarcode(String imagePath) async {
    String? code;

    try {
      code = await BarcodeReaderService.read(imagePath);
    } catch (error) {
      _log('barcode read failed: $error');
      return null;
    }

    if (code == null) return null;

    try {
      final NutritionLabelData? product = await FoodDatabaseService.lookup(code);
      final String name = product?.productName?.trim() ?? '';

      if (name.isEmpty) {
        _log('barcode $code not in Open Food Facts');
        return null;
      }

      return DetectedProductName(
        name: name,
        brand: product?.productBrand?.trim(),
        source: ProductNameSource.barcode,
      );
    } catch (error) {
      _log('barcode lookup failed: $error');
      return null;
    }
  }

  // =====================================================
  // 2. NAME PRINTED ON THE PACK (AI)
  // =====================================================

  static Future<DetectedProductName?> _fromPhoto(String imagePath) async {
    if (Firebase.apps.isEmpty) return null;

    final Uint8List jpeg = await _smallJpeg(imagePath);

    final HttpsCallable callable = FirebaseFunctions.instanceFor(
      region: region,
    ).httpsCallable(
      functionName,
      options: HttpsCallableOptions(timeout: const Duration(seconds: 25)),
    );

    final HttpsCallableResult<dynamic> result = await callable.call(
      <String, dynamic>{
        'imageBase64': base64Encode(jpeg),
        'mediaType': 'image/jpeg',
      },
    );

    final Object? data = result.data;

    if (data is! Map) return null;

    final String name = '${data['product_name'] ?? ''}'.trim();

    if (name.isEmpty) return null;

    final String brand = '${data['brand'] ?? ''}'.trim();

    return DetectedProductName(
      name: name,
      brand: brand.isEmpty ? null : brand,
      source: ProductNameSource.photo,
    );
  }

  /// Upright, resized JPEG of the whole photo (in a
  /// background isolate so the animation stays smooth).
  static Future<Uint8List> _smallJpeg(String imagePath) {
    return Isolate.run<Uint8List>(() {
      final Uint8List bytes = File(imagePath).readAsBytesSync();

      img.Image? image = img.decodeImage(bytes);

      if (image == null) return bytes;

      image = img.bakeOrientation(image);

      final int longest = math.max(image.width, image.height);

      if (longest > _maxImageSide) {
        final double scale = _maxImageSide / longest;

        image = img.copyResize(
          image,
          width: (image.width * scale).round(),
          height: (image.height * scale).round(),
          interpolation: img.Interpolation.average,
        );
      }

      return img.encodeJpg(image, quality: 85);
    });
  }

  static void _log(String message) {
    if (kDebugMode) debugPrint('[NutriPal name] $message');
  }
}
