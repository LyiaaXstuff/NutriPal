import 'package:flutter_test/flutter_test.dart';
import 'package:nutripal/models/nutrition_analysis.dart';
import 'package:nutripal/models/nutrition_label_data.dart';
import 'package:nutripal/services/agent_summary.dart';
import 'package:nutripal/services/firestore_scan_history_repository.dart';

import 'nutrition_analysis_service_test.dart' show crisps, homesoy;

// The agentSummary written to each scan document and read
// by the Ask NutriPal compare_with_history tool (A-T01..).

Map<String, dynamic> row(Map<String, dynamic> summary, String name) =>
    (summary['per100'] as List<Map<String, dynamic>>).firstWhere((Map<String, dynamic> r) => r['name'] == name);

void main() {
  test('A-T01 drink: per 100 ml values with FSA drink levels', () {
    final Map<String, dynamic> s = AgentSummary.forLabel(homesoy())!;

    expect(s['v'], AgentSummary.version);
    expect(s['form'], 'drink');
    expect(s['basis'], 'per 100 ml');

    expect(row(s, 'Energy')['amount'], 39);
    expect(row(s, 'Energy')['unit'], 'kcal');
    expect(row(s, 'Energy').containsKey('level'), isFalse);

    // Drinks: fat 1.6 g is above 1.5 g -> Moderate.
    expect(row(s, 'Total Fat')['level'], 'Moderate');
    expect(row(s, 'Saturated Fat')['level'], 'Low');
    expect(row(s, 'Total Sugars')['level'], 'Low');
    // 17 mg sodium = 0.04 g salt -> Low.
    expect(row(s, 'Sodium')['level'], 'Low');
    expect(row(s, 'Calcium')['amount'], 120);
  });

  test('A-T02 food: sodium in mg is rated as salt per 100 g', () {
    final Map<String, dynamic> s = AgentSummary.forLabel(crisps())!;

    expect(s['form'], 'food');
    expect(s['basis'], 'per 100 g');
    // 800 mg sodium = 2.0 g salt, above 1.5 g -> High.
    expect(row(s, 'Sodium')['level'], 'High');
  });

  test('A-T03 per-serving label is scaled to per 100', () {
    final NutritionLabelData label = NutritionLabelData(
      rawText: '',
      servingSizeAmount: 250,
      servingSizeUnit: 'ml',
      columns: const <NutritionColumn>[
        NutritionColumn(id: 'ps', label: 'Per serving', basis: NutritionColumnBasis.perServing, xCenter: 0),
      ],
      nutrients: const <NutrientRow>[
        NutrientRow(name: 'Total Sugars', order: 0, valuesByColumn: <List<NutritionValue>>[
          <NutritionValue>[NutritionValue(amount: 10, unit: 'g', rawText: '10 g')],
        ]),
      ],
    );

    final Map<String, dynamic> s = AgentSummary.forLabel(label)!;

    expect(s['form'], 'drink');
    expect(row(s, 'Total Sugars')['amount'], 4.0);
    // 4 g per 100 ml: between 2.5 and 11.25 -> Moderate.
    expect(row(s, 'Total Sugars')['level'], 'Moderate');
  });

  test('A-T04 nothing per 100 -> no summary', () {
    final NutritionLabelData label = NutritionLabelData(
      rawText: '',
      columns: const <NutritionColumn>[
        NutritionColumn(id: 'ps', label: 'Per serving', basis: NutritionColumnBasis.perServing, xCenter: 0),
      ],
      nutrients: const <NutrientRow>[
        NutrientRow(name: 'Sodium', order: 0, valuesByColumn: <List<NutritionValue>>[
          <NutritionValue>[NutritionValue(amount: 200, unit: 'mg', rawText: '200 mg')],
        ]),
      ],
    );

    // No serving size, so per 100 cannot be worked out.
    expect(AgentSummary.forLabel(label), isNull);
  });

  test('A-T05 levelFor ignores non-FSA nutrients and non-mass units', () {
    expect(AgentSummary.levelFor('Calcium', 120, 'mg', ProductForm.drink), isNull);
    expect(AgentSummary.levelFor('Total Sugars', 5, 'kcal', ProductForm.food), isNull);
    expect(AgentSummary.levelFor('Sodium', 0.8, 'g', ProductForm.food), NutrientLevel.high);
  });

  test('A-T06 older scan docs without a current summary are rewritten once', () {
    // docFor() itself needs Firebase (server timestamp), so
    // the stored shape is built here the same way.
    final Map<String, dynamic> current = <String, dynamic>{
      'record': 'x',
      'agentSummary': AgentSummary.forLabel(homesoy()),
    };

    expect(FirestoreScanHistoryRepository.needsSummary(<String, dynamic>{'record': 'x'}), isTrue);
    expect(
      FirestoreScanHistoryRepository.needsSummary(<String, dynamic>{
        'agentSummary': <String, dynamic>{'v': 0},
      }),
      isTrue,
    );
    expect(FirestoreScanHistoryRepository.needsSummary(current), isFalse);
    // A label with nothing per 100 stores null: not
    // rewritten on every load.
    expect(FirestoreScanHistoryRepository.needsSummary(<String, dynamic>{'agentSummary': null}), isFalse);
  });

  test('A-T07 the summary holds no personal data', () {
    final Map<String, dynamic> s = AgentSummary.forLabel(homesoy())!;

    expect(s.keys.toSet(), <String>{'v', 'form', 'basis', 'per100'});
  });
}
