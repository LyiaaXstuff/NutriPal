import 'package:flutter_test/flutter_test.dart';
import 'package:nutripal/services/nutrient_name_normalizer.dart';

void main() {
  void expectCanonical(String raw, String canonical) {
    expect(
      NutrientNameNormalizer.normalize(raw),
      canonical,
      reason: 'normalize("$raw")',
    );
  }

  group('Bahasa Melayu and bilingual names', () {
    test('known names become the canonical English name', () {
      expectCanonical('Tenaga', 'Energy');
      expectCanonical('Natrium', 'Sodium');
      expectCanonical('Natrium / Sodium', 'Sodium');
      expectCanonical('Jumlah Gula', 'Total Sugars');
      expectCanonical('Jumlah Gula / Total Sugars', 'Total Sugars');
      expectCanonical('Karbohidrat', 'Carbohydrate');
      expectCanonical('Karbohidrat /  Carbohydrate', 'Carbohydrate');
      expectCanonical('Asid Lemak Tepu', 'Saturated Fat');
      expectCanonical('Asid Lemak Trans', 'Trans Fat');
      expectCanonical('Asid Lemak Monotidaktepu', 'Monounsaturated Fat');
      expectCanonical('Asid Lemak Politidaktepu', 'Polyunsaturated Fat');
      expectCanonical('Lemak / Fat', 'Total Fat');
      expectCanonical('Tenaga / Energy', 'Energy');
      expectCanonical('Serat Diet', 'Dietary Fibre');
      expectCanonical('Kolesterol', 'Cholesterol');
    });
  });

  group('OCR artefacts', () {
    test('brackets, bullets, colons, asterisks and spaces are cleaned', () {
      expectCanonical('(Protein)', 'Protein');
      expectCanonical('(Protein', 'Protein');
      expectCanonical('Protein)', 'Protein');
      expectCanonical('Protein:', 'Protein');
      expectCanonical('PROTEIN', 'Protein');
      expectCanonical('• Sodium', 'Sodium');
      expectCanonical('- Sodium', 'Sodium');
      expectCanonical('• Total Fat', 'Total Fat');
      expectCanonical(':Carbohydrate', 'Carbohydrate');
      expectCanonical('[Vitamin B12]', 'Vitamin B12');
      expectCanonical('Saturated Fat*', 'Saturated Fat');
      expectCanonical('Asid Lemak Tepu***', 'Saturated Fat');
      expectCanonical('  NATRIUM   ', 'Sodium');
      expectCanonical('Jumlah   Gula', 'Total Sugars');
      expectCanonical('(Natrium', 'Sodium');
    });

    test('meaningful symbols are kept', () {
      expectCanonical('Omega-3', 'Omega 3');
      expectCanonical('Omega3', 'Omega 3');
    });
  });

  group('Safe OCR spelling correction', () {
    test('obvious OCR mistakes are corrected', () {
      expectCanonical('Proteln', 'Protein');
      expectCanonical('Sodlum', 'Sodium');
      expectCanonical('Natriurn', 'Sodium');
      expectCanonical('Karbohldrat', 'Carbohydrate');
      expectCanonical('Flbre', 'Dietary Fibre');
      expectCanonical('Cholestrol', 'Cholesterol');

      final NormalizedNutrientName result =
          NutrientNameNormalizer.normalizeDetailed('Natriurn');

      expect(result.wasStandardized, isTrue);
      expect(result.wasCorrected, isTrue);
    });

    test('similar-looking names are NOT autocorrected', () {
      expectCanonical('Probiotic', 'Probiotic');
      expectCanonical('Tepung', 'Tepung');
      expectCanonical('Net Carbs', 'Net Carbs');
      expectCanonical('Vitamin D3', 'Vitamin D3');
      expectCanonical('Omega 6', 'Omega 6');
    });
  });

  group('Meaning is never changed', () {
    test('different nutrients stay different', () {
      expectCanonical('Added Sugars', 'Added Sugars');
      expectCanonical('Gula Tambahan', 'Added Sugars');
      expectCanonical('Total Sugars', 'Total Sugars');
      expectCanonical('Total Fat', 'Total Fat');
      expectCanonical('Saturated Fat', 'Saturated Fat');
      expectCanonical('Unsaturated', 'Unsaturated Fat');
      expectCanonical('Carbohydrate', 'Carbohydrate');
      expectCanonical('Cholesterol', 'Cholesterol');
      expectCanonical('Kalsium', 'Calcium');
      expectCanonical('Kalium', 'Potassium');
      expectCanonical('Vitamin A', 'Vitamin A');
      expectCanonical('Vitamin E', 'Vitamin E');
    });

    test('folic acid and folate stay separate, both vitamin B9', () {
      expectCanonical('Folic Acid', 'Folic Acid');
      expectCanonical('Asid Folik', 'Folic Acid');
      expectCanonical('Folic Acid / Asid Folik', 'Folic Acid');
      expectCanonical('Folate', 'Folate');
      expectCanonical('Folat', 'Folate');

      // Folic acid and folate on one bilingual row disagree:
      // the label wording is kept rather than picking one.
      expectCanonical('Folate / Asid Folik', 'Folate / Asid Folik');

      expect(NutrientNameNormalizer.vitaminGroupOf('Folic Acid'), 'B9');
      expect(NutrientNameNormalizer.vitaminGroupOf('Folate'), 'B9');
      expect(NutrientNameNormalizer.vitaminGroupOf('Vitamin B9'), 'B9');
      expect(NutrientNameNormalizer.vitaminGroupOf('Sodium'), isNull);
    });

    test('two languages that disagree keep the label wording', () {
      expectCanonical('Lemak / Saturated Fat', 'Lemak / Saturated Fat');
    });
  });

  group('Unknown nutrients', () {
    test('nutrients not in the dictionary are kept', () {
      expectCanonical('Inositol', 'Inositol');
      expectCanonical('Copper', 'Copper');
      expectCanonical('Manganese', 'Manganese');
      expectCanonical('INOSITOL', 'Inositol');

      final NormalizedNutrientName result =
          NutrientNameNormalizer.normalizeDetailed('Copper');

      expect(result.wasStandardized, isFalse);
      expect(result.cleanedName, 'Copper');
    });

    test('known vitamins and minerals are standardised', () {
      expectCanonical('Phosphorus', 'Phosphorus');
      expectCanonical('Vitamin B6', 'Vitamin B6');
      expectCanonical('Vitarnin C', 'Vitamin C');
      expectCanonical('Zat Besi', 'Iron');
      expectCanonical('Pantothenic Acid', 'Vitamin B5');
    });

    test('B vitamins written with their name and code', () {
      expectCanonical('Thiamin (Vitamin B1)', 'Vitamin B1');
      expectCanonical('Riboflavin (Vitamin B2)', 'Vitamin B2');
      expectCanonical('Niacin (Vitamin B3)', 'Vitamin B3');
      expectCanonical('Folic Acid (Vitamin B9)', 'Folic Acid');
      expectCanonical('Folic Acid Vitamin B9)', 'Folic Acid');
      expectCanonical('Vitamin B9', 'Vitamin B9');
      expectCanonical('Biotin', 'Biotin');

      // Name and code disagree: label wording is kept.
      expectCanonical('Niacin (Vitamin B6)', 'Niacin (Vitamin B6)');
    });
  });

  group('Unreadable second language (Arabic, Thai...)', () {
    test('stray characters after "/" are dropped', () {
      expectCanonical('Total sugars / S', 'Total Sugars');
      expectCanonical('Protein / 3', 'Protein');
      expectCanonical('Fat / Y', 'Total Fat');
      expectCanonical('Cholesterol / Ds', 'Cholesterol');
      expectCanonical('Vitamin a / A I', 'Vitamin A');
      expectCanonical('Magnesium / Ega', 'Magnesium');
      expectCanonical('Niacin (Vitamin B3) / O', 'Vitamin B3');
      expectCanonical('Folic Acid Vitamin B9) / 44', 'Folic Acid');

      final NormalizedNutrientName result =
          NutrientNameNormalizer.normalizeDetailed('Cholesterol / Ds');

      expect(result.cleanedName, 'Cholesterol');
      expect(result.droppedUnreadableText, isTrue);
      expect(
        NutrientNameNormalizer.normalizeDetailed('Lemak / Fat')
            .droppedUnreadableText,
        isFalse,
      );
    });

    test('text really in Arabic (from the AI reader) is kept', () {
      final NormalizedNutrientName result =
          NutrientNameNormalizer.normalizeDetailed('Protein / بروتين');

      expect(result.canonicalName, 'Protein');
      expect(result.cleanedName, 'Protein / بروتين');
      expect(result.droppedUnreadableText, isFalse);
    });

    test('real second-language names are kept', () {
      final NormalizedNutrientName result =
          NutrientNameNormalizer.normalizeDetailed('Lemak / Fat');

      expect(result.cleanedName, 'Lemak / Fat');
      expect(result.canonicalName, 'Total Fat');

      // An unknown nutrient keeps both halves.
      expectCanonical('Inositol / Inositol', 'Inositol / Inositol');
    });

    test('sub-heading words in front of a row are removed', () {
      expectCanonical(
        'Comprising of Monounsaturated Fatty Acid',
        'Monounsaturated Fat',
      );
      expectCanonical('of which saturated fatty acid', 'Saturated Fat');
      expectCanonical('Trans fatty acid / A', 'Trans Fat');
    });
  });

  group('Packaging text stuck to a name', () {
    test('removed only when the rest is clearly a nutrient', () {
      expectCanonical('MS1500 Asid Lemak Politidaktepu', 'Polyunsaturated Fat');
      expectCanonical('CARA Natrium', 'Sodium');
      expectCanonical('HALAL Lemak', 'Total Fat');
      expectCanonical('D01-11/2012 Omega 3', 'Omega 3');

      final NormalizedNutrientName result =
          NutrientNameNormalizer.normalizeDetailed('HALAL Lemak');

      expect(result.cleanedName, 'Lemak');
    });

    test('nutrient codes are never treated as packaging text', () {
      expectCanonical('Vitamin B12', 'Vitamin B12');
      expectCanonical('B12 Vitamin', 'B12 Vitamin');
    });
  });

  group('Raw name is preserved', () {
    test('cleaned label wording is kept next to the canonical name', () {
      final NormalizedNutrientName result =
          NutrientNameNormalizer.normalizeDetailed('Jumlah Gula / Total Sugars');

      expect(result.rawName, 'Jumlah Gula / Total Sugars');
      expect(result.cleanedName, 'Jumlah Gula / Total Sugars');
      expect(result.canonicalName, 'Total Sugars');
      expect(result.wasStandardized, isTrue);
      expect(result.wasCorrected, isFalse);
    });
  });
}
