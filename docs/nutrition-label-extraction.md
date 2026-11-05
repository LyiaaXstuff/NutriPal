# Nutrition-label extraction

For Azure Document Intelligence Layout scanning and portion calculations, see
[Azure setup](azure-layout-setup.md). The on-device adapter described below is
used when online scanning is not configured or explicitly retried offline.

`NutritionLabelParserService` adapts ML Kit bounding boxes and confidence to
`NutritionTableParser`. The latter is pure Dart and can be tested without a camera.
The ordered `NutritionLabelData.rows` and `columns` are the extraction result;
the older `perServing` / `per100` fields are conservative calculation projections.

## Behaviour

- Nutrient names come from table rows, with no nutrient allowlist. Original order
  and spelling are preserved. Added sugars, salt and unsaturated fats remain
  separate from total sugars, sodium and saturated fat.
- Columns keep their printed left-to-right order. Per serving, per 100 g, per
  100 ml and percentage columns can coexist. Missing cells stay `Not read`.
- Element boxes reconstruct rows independently of OCR block ordering. Modest
  image tilt is corrected using line corners. Repeated overlapping OCR elements
  are removed; equal values in different cells and repeated printed rows remain.
- Units can be attached to values, split across nearby elements, or printed next
  to nutrient names. Percent headings supply the percent unit. kJ and kcal can
  coexist in one cell. Inequalities and original numeric precision are displayed.
- Unknown bases, unreadable units, collisions, unpaired values and low-confidence
  OCR are exposed for review. Exact calculation projections exclude uncertain
  cells and inequalities. Repeated canonical nutrients do not overwrite one another.
- A partially detected label can open the review. Its photo and raw OCR text are
  available there. Scan preview actions stay visible while the panel text scrolls.

## Reproduce the checks

Use the Flutter SDK compatible with `pubspec.yaml` and the committed lockfile.
The changes were checked with Flutter 3.47.9 / Dart 3.13.7.

Validation results: all 48 Flutter tests passed, including the opt-in local HTTP
integration test with synthetic Azure responses; all 8 Python backend tests
passed. `flutter analyze --no-pub` reported no issues. See the Azure setup guide
for reproducing the HTTP integration check. Native OCR and Azure recognition
accuracy still require validation with real label photos and resource credentials.

```sh
flutter pub get --enforce-lockfile
flutter analyze --no-pub
flutter test --no-pub
```

In a CI/cloud environment set `CI=true` and `FLUTTER_SUPPRESS_ANALYTICS=true`
before invoking Flutter. This avoids environment-detection metadata probing.

The tests cover arbitrary nutrients, three columns in both directions, absent
middle cells, split units, unitless cells, percentages, dual energy units,
wrapped headers/names, skew, shuffled blocks, duplicate OCR, missing headers,
serving metadata, missing values and ambiguous assignments. Widget tests run
app startup, the review at phone size, horizontal scrolling, empty results and
Analyze-to-review navigation for detected and partial labels. Method-channel
tests verify image-service adaptation and recognizer cleanup on success/failure.

## Device validation

These regression fixtures are synthetic OCR output. The native Android/iOS OCR
engine is mocked in the automated flow tests. No physical device or real user
label photographs were available in the test environment, so the tests do not
establish real-camera OCR accuracy or an Android/iOS release build.

On an Android/iOS device, run `flutter run`, then scan clear and slightly tilted
labels with per-serving/per-100 columns. Compare every displayed cell and its
heading to the photo, including nutrient subtypes, missing cells and units.
Retake blurry, cropped, curved or strongly skewed labels; reconstruction cannot
recover text the OCR engine did not recognise. The current recognizer uses the
Latin script (including English/Malay), as before. It does not claim support for
every international layout, multiple independent tables in one photo, or extreme
perspective distortion.
