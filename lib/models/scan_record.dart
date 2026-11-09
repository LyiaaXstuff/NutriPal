// =======================================================
// SCAN RECORD (History + Favourites)
// =======================================================
//
// One product the user scanned. The same record serves:
//
//   Recent scans  latest few records, on Home
//   History       every record that has not expired
//   Favourites    records with isFavourite = true
//
// History is temporary (90 days from scannedAt, see
// HistoryRetentionPolicy); a favourite never expires until
// the user removes it from Favourites.
//
// The fields map 1:1 to a future Firestore document
// (users/{uid}/scans/{id}).
// =======================================================

import 'nutrition_label_data.dart';
import 'nutrition_label_json.dart';

class ScanRecord {
  final String id;

  // Same product = same key (barcode, or a fingerprint of
  // the label), so a rescan updates the record instead of
  // adding a duplicate.
  final String productKey;

  final String productName;

  // Last time the product was scanned. Retention counts
  // from here.
  final DateTime scannedAt;

  final bool isFavourite;

  final DateTime? favouritedAt;

  // Copy of the label photo in the app's own folder.
  final String? thumbnailPath;

  // Key nutrients for the list cards (1 serving if the
  // label has one, otherwise 100 g / 100 ml).
  final String summaryBasis;
  final double? energyKcal;
  final double? sugarsG;
  final double? sodiumMg;

  // The confirmed label, to reopen the full result.
  final NutritionLabelData label;

  const ScanRecord({
    required this.id,
    required this.productKey,
    required this.productName,
    required this.scannedAt,
    required this.label,
    this.isFavourite = false,
    this.favouritedAt,
    this.thumbnailPath,
    this.summaryBasis = 'per serving',
    this.energyKcal,
    this.sugarsG,
    this.sodiumMg,
  });

  String? get servingText {
    final double? size = label.servingSizeAmount;
    final String? unit = label.servingSizeUnit;

    if (size == null || unit == null) return null;

    final String n = size == size.roundToDouble() ? size.round().toString() : size.toStringAsFixed(1);

    return '$n $unit per serving';
  }

  bool get isBarcodeScan => label.extractionMethod == NutritionExtractionMethod.barcode;

  ScanRecord copyWith({
    String? productName,
    DateTime? scannedAt,
    bool? isFavourite,
    DateTime? favouritedAt,
    bool clearFavouritedAt = false,
    String? thumbnailPath,
    bool clearThumbnail = false,
    String? summaryBasis,
    double? energyKcal,
    double? sugarsG,
    double? sodiumMg,
    NutritionLabelData? label,
  }) {
    return ScanRecord(
      id: id,
      productKey: productKey,
      productName: productName ?? this.productName,
      scannedAt: scannedAt ?? this.scannedAt,
      isFavourite: isFavourite ?? this.isFavourite,
      favouritedAt: clearFavouritedAt ? null : favouritedAt ?? this.favouritedAt,
      thumbnailPath: clearThumbnail ? null : thumbnailPath ?? this.thumbnailPath,
      summaryBasis: summaryBasis ?? this.summaryBasis,
      energyKcal: energyKcal ?? this.energyKcal,
      sugarsG: sugarsG ?? this.sugarsG,
      sodiumMg: sodiumMg ?? this.sodiumMg,
      label: label ?? this.label,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'productKey': productKey,
        'productName': productName,
        'scannedAt': scannedAt.toUtc().toIso8601String(),
        'isFavourite': isFavourite,
        if (favouritedAt != null) 'favouritedAt': favouritedAt!.toUtc().toIso8601String(),
        if (thumbnailPath != null) 'thumbnailPath': thumbnailPath,
        'summaryBasis': summaryBasis,
        'energyKcal': energyKcal,
        'sugarsG': sugarsG,
        'sodiumMg': sodiumMg,
        'label': NutritionLabelJson.toJson(label),
      };

  /// Null when the stored entry is unreadable (it is then
  /// skipped instead of breaking the whole history).
  static ScanRecord? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;

    try {
      final DateTime? scanned = DateTime.tryParse(raw['scannedAt'] as String? ?? '');

      if (scanned == null) return null;

      double? number(Object? v) => v is num ? v.toDouble() : null;

      return ScanRecord(
        id: raw['id'] as String,
        productKey: raw['productKey'] as String? ?? raw['id'] as String,
        productName: raw['productName'] as String? ?? 'Scanned product',
        scannedAt: scanned.toLocal(),
        isFavourite: raw['isFavourite'] == true,
        favouritedAt: DateTime.tryParse(raw['favouritedAt'] as String? ?? '')?.toLocal(),
        thumbnailPath: raw['thumbnailPath'] as String?,
        summaryBasis: raw['summaryBasis'] as String? ?? 'per serving',
        energyKcal: number(raw['energyKcal']),
        sugarsG: number(raw['sugarsG']),
        sodiumMg: number(raw['sodiumMg']),
        label: NutritionLabelJson.fromJson(
          raw['label'] as Map<String, dynamic>? ?? const <String, dynamic>{},
        ),
      );
    } catch (_) {
      return null;
    }
  }

  // =====================================================
  // PRODUCT KEY
  // =====================================================

  /// Barcode when known; otherwise a stable fingerprint of
  /// the serving size and the printed values, so scanning
  /// the same label twice finds the same record.
  static String productKeyFor(NutritionLabelData label) {
    final String? barcode = label.barcode?.trim();

    if (barcode != null && barcode.isNotEmpty) return 'barcode:$barcode';

    final StringBuffer b = StringBuffer()
      ..write(label.servingSizeAmount ?? '')
      ..write(label.servingSizeUnit ?? '')
      ..write('|');

    for (final NutrientRow r in label.nutrients) {
      b.write(r.name.toLowerCase());

      for (final List<NutritionValue> cell in r.valuesByColumn) {
        b.write(':');

        for (final NutritionValue v in cell) {
          b
            ..write(v.amount)
            ..write(v.unit);
        }
      }

      b.write(';');
    }

    return 'label:${_fnv1a(b.toString())}';
  }

  // 32-bit FNV-1a: stable across app runs (String.hashCode
  // is not guaranteed to be).
  static String _fnv1a(String text) {
    int hash = 0x811c9dc5;

    for (final int unit in text.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }

    return hash.toRadixString(16).padLeft(8, '0');
  }
}
