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
// History is temporary (30 days from scannedAt, see
// HistoryRetentionPolicy); a favourite never expires until
// the user removes it from Favourites.
//
// The fields map 1:1 to a future Firestore document
// (users/{uid}/scans/{id}).
// =======================================================

import 'nutrition_label_data.dart';
import 'nutrition_label_json.dart';

enum ScanExtractionPath {
  mlkit('mlkit'),
  claude('claude'),
  claudeRejected('claude_rejected'),
  barcode('barcode');

  const ScanExtractionPath(this.value);

  final String value;

  static ScanExtractionPath? fromValue(Object? value) {
    for (final ScanExtractionPath path in values) {
      if (path.value == value) return path;
    }

    return null;
  }
}

class ScanEvaluationMetadata {
  final ScanExtractionPath extractionPath;
  final List<String> fallbackReasons;
  final bool quickVerificationShown;
  final List<Map<String, dynamic>> quickVerificationIssues;
  final List<Map<String, dynamic>> valuesBeforeVerification;
  final List<Map<String, dynamic>> valuesAfterVerification;

  const ScanEvaluationMetadata({
    required this.extractionPath,
    this.fallbackReasons = const <String>[],
    this.quickVerificationShown = false,
    this.quickVerificationIssues = const <Map<String, dynamic>>[],
    this.valuesBeforeVerification = const <Map<String, dynamic>>[],
    this.valuesAfterVerification = const <Map<String, dynamic>>[],
  });

  factory ScanEvaluationMetadata.forLabel(NutritionLabelData label) {
    final List<Map<String, dynamic>> values = captureValues(label);

    return ScanEvaluationMetadata(
      extractionPath: label.extractionMethod == NutritionExtractionMethod.barcode
          ? ScanExtractionPath.barcode
          : ScanExtractionPath.mlkit,
      valuesBeforeVerification: values,
      valuesAfterVerification: values,
    );
  }

  static List<Map<String, dynamic>> captureValues(NutritionLabelData label) {
    return <Map<String, dynamic>>[
      for (final NutrientRow row in label.nutrients)
        <String, dynamic>{
          'name': row.name,
          'values': <List<Map<String, dynamic>>>[
            for (final List<NutritionValue> cell in row.valuesByColumn)
              <Map<String, dynamic>>[
                for (final NutritionValue value in cell)
                  <String, dynamic>{'amount': value.amount, 'unit': value.unit},
              ],
          ],
        },
    ];
  }

  ScanEvaluationMetadata copyWith({
    ScanExtractionPath? extractionPath,
    List<String>? fallbackReasons,
    bool? quickVerificationShown,
    List<Map<String, dynamic>>? quickVerificationIssues,
    List<Map<String, dynamic>>? valuesBeforeVerification,
    List<Map<String, dynamic>>? valuesAfterVerification,
  }) {
    return ScanEvaluationMetadata(
      extractionPath: extractionPath ?? this.extractionPath,
      fallbackReasons: fallbackReasons ?? this.fallbackReasons,
      quickVerificationShown: quickVerificationShown ?? this.quickVerificationShown,
      quickVerificationIssues: quickVerificationIssues ?? this.quickVerificationIssues,
      valuesBeforeVerification: valuesBeforeVerification ?? this.valuesBeforeVerification,
      valuesAfterVerification: valuesAfterVerification ?? this.valuesAfterVerification,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'extractionPath': extractionPath.value,
        'fallbackReasons': fallbackReasons,
        'quickVerificationShown': quickVerificationShown,
        'quickVerificationIssues': quickVerificationIssues,
        'valuesBeforeVerification': valuesBeforeVerification,
        'valuesAfterVerification': valuesAfterVerification,
      };

  static ScanEvaluationMetadata? fromJson(Map<String, dynamic> json) {
    final ScanExtractionPath? path = ScanExtractionPath.fromValue(json['extractionPath']);
    if (path == null) return null;

    List<Map<String, dynamic>> maps(Object? raw) => raw is List
        ? raw.whereType<Map>().map((Map value) => Map<String, dynamic>.from(value)).toList()
        : <Map<String, dynamic>>[];

    final Object? rawReasons = json['fallbackReasons'];

    return ScanEvaluationMetadata(
      extractionPath: path,
      fallbackReasons: <String>[
        for (final dynamic reason in (rawReasons is List ? rawReasons : const <dynamic>[]))
          if (reason is String) reason,
      ],
      quickVerificationShown: json['quickVerificationShown'] == true,
      quickVerificationIssues: maps(json['quickVerificationIssues']),
      valuesBeforeVerification: maps(json['valuesBeforeVerification']),
      valuesAfterVerification: maps(json['valuesAfterVerification']),
    );
  }
}

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

  // Evaluation metadata for the extraction and verification flow.
  final ScanEvaluationMetadata? evaluation;

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
    this.evaluation,
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
    ScanEvaluationMetadata? evaluation,
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
      evaluation: evaluation ?? this.evaluation,
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
        ...?evaluation?.toJson(),
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
        evaluation: ScanEvaluationMetadata.fromJson(raw),
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
