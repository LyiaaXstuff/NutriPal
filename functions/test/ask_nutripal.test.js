'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  askNutriPal,
  validateAskRequest,
  recalculatePortion,
  rateAmount,
  buildSystem,
  buildEvaluationRecord,
  AskNutriPalError,
} = require('../src/ask_nutripal');
const { CONTEXT, scan, fakeDb } = require('./helpers');

function fakeFetch(responses, calls = []) {
  let i = 0;

  return async (url, options) => {
    calls.push({ url, body: JSON.parse(options.body), headers: options.headers });

    const r = responses[Math.min(i++, responses.length - 1)];

    return { ok: r.status === 200, status: r.status, json: async () => r.body };
  };
}

test('recalculate_portion scales per 100 and gives shares', () => {
  const result = recalculatePortion(CONTEXT, { amount: 472, unit: 'ml' });

  const carbs = result.nutrients.find((n) => n.name === 'Carbohydrate');
  const sodium = result.nutrients.find((n) => n.name === 'Sodium');
  const calcium = result.nutrients.find((n) => n.name === 'Calcium');

  assert.equal(carbs.amount, 10.9);
  // 10.86 g of the 45 g meal budget.
  assert.equal(carbs.share_of_limit_percent, 24);
  assert.equal(sodium.amount, 80.2);
  assert.equal(sodium.share_of_limit_percent, 4);
  assert.equal(calcium.share_of_limit_percent, undefined);
  assert.equal(result.note, undefined);
});

// Same answers as the app's own tests
// (nutrition_analysis_service_test.dart, sample user
// with diabetes: carbohydrate against a 45 g meal budget
// with the meal bands 25% / 50%).
test('recalculate_portion rates like the app: Homesoy 236 ml Low, 500 ml Moderate, 1 L High', () => {
  assert.equal(recalculatePortion(CONTEXT, { amount: 236, unit: 'ml' }).rating.overall, 'Low');

  const half = recalculatePortion(CONTEXT, { amount: 500, unit: 'ml' }).rating;

  // Carbohydrate 11.5 g of 45 g (26%), sugars 3.5 g of 52.3 g (7%).
  assert.deepEqual(half.areas, [
    { area: 'Diabetes', level: 'Moderate', decided_by: 'Carbohydrate' },
    // Sodium 85 mg of 2,000 mg (4%), traffic light Low.
    { area: 'Blood pressure', level: 'Low', decided_by: 'Sodium' },
  ]);

  // 23 g of 45 g (51%).
  const oneLitre = recalculatePortion(CONTEXT, { amount: 1000, unit: 'ml' }).rating;
  assert.equal(oneLitre.overall, 'High');
  assert.equal(oneLitre.areas[0].decided_by, 'Carbohydrate');
});

test('each nutrient uses the target and bands the app sent', () => {
  // With daily bands (10% / 30%) 11.5 g of 45 g would be
  // Moderate too, but 5.4 g (12%) would be Moderate, not Low.
  const daily = {
    ...CONTEXT,
    rating: {
      ...CONTEXT.rating,
      nutrients: CONTEXT.rating.nutrients.map((n) =>
        n.name === 'Carbohydrate' ? { ...n, low_share_max: 0.1, moderate_share_max: 0.3 } : n,
      ),
    },
  };

  assert.equal(rateAmount(daily, 236).levels.Carbohydrate, 'Moderate');
  assert.equal(rateAmount(CONTEXT, 236).levels.Carbohydrate, 'Low');
});

test('a nutrient the app does not rate (rated: false) gets no level', () => {
  const unrated = {
    ...CONTEXT,
    targets: { ...CONTEXT.targets, carbs_per_meal_g: null },
    rating: {
      ...CONTEXT.rating,
      nutrients: CONTEXT.rating.nutrients.map((n) => {
        if (n.name !== 'Carbohydrate') return n;
        const { target: _t, ...rest } = n;
        return { ...rest, rated: false };
      }),
      areas: [
        { area: 'Diabetes', nutrients: ['Total Sugars'], key_any_of: ['Total Sugars'] },
        { area: 'Blood pressure', nutrients: ['Sodium'], key_any_of: ['Sodium'] },
      ],
    },
  };

  const r = recalculatePortion(unrated, { amount: 1000, unit: 'ml' });

  assert.equal(r.rating.levels, undefined);
  assert.equal(rateAmount(unrated, 1000).levels.Carbohydrate, undefined);
  assert.deepEqual(r.rating.areas[0], { area: 'Diabetes', level: 'Moderate', decided_by: 'Total Sugars' });
  assert.equal(r.nutrients.find((n) => n.name === 'Carbohydrate').share_of_limit_percent, undefined);
});

test('the per-100 traffic light is never lowered by a small amount', () => {
  // Total fat is Moderate per 100 ml, so even 10 ml
  // (0.16 g, under 1% of 69.7 g) stays Moderate.
  const ctx = {
    ...CONTEXT,
    targets: { ...CONTEXT.targets, total_fat_g: 69.7 },
    rating: {
      ...CONTEXT.rating,
      areas: [
        ...CONTEXT.rating.areas,
        { area: 'Cholesterol', nutrients: ['Saturated Fat', 'Trans Fat', 'Total Fat'], key_any_of: ['Saturated Fat', 'Total Fat'] },
      ],
    },
  };

  assert.equal(rateAmount(ctx, 10).levels['Total Fat'], 'Moderate');
});

test('nutrients no area rates get no level', () => {
  // Total fat is not used by Diabetes or Blood pressure.
  assert.equal(rateAmount(CONTEXT, 10).levels['Total Fat'], undefined);
});

// High LDL cholesterol (rule R-LDL-01 v2): key nutrients
// with no level, no overall result.
const LDL = {
  ...CONTEXT,
  user: { health_areas: ['Cholesterol'] },
  rating: {
    ...CONTEXT.rating,
    areas: [
      {
        area: 'Cholesterol',
        nutrients: ['Saturated Fat', 'Trans Fat', 'Total Fat'],
        key_any_of: [],
        combine: 'findings',
      },
    ],
  },
};

test('LDL-01 LDL cholesterol: no level for any nutrient and no overall verdict', () => {
  const r = rateAmount(LDL, 236);

  assert.equal(r.levels['Saturated Fat'], undefined);
  assert.equal(r.levels['Total Fat'], undefined);
  assert.equal(r.areas[0].level, 'key nutrients, no level');
  assert.equal(r.areas[0].decided_by, undefined);
  assert.match(r.overall, /^review key nutrients/);

  // A bigger portion never produces a level either.
  assert.match(rateAmount(LDL, 1000).overall, /^review key nutrients/);
});

test('LDL-02 LDL cholesterol card next to other areas: no level, no overall effect', () => {
  const both = {
    ...CONTEXT,
    rating: {
      ...CONTEXT.rating,
      areas: [
        ...CONTEXT.rating.areas,
        { area: 'Cholesterol', nutrients: ['Saturated Fat', 'Trans Fat', 'Total Fat'], key_any_of: [], combine: 'findings' },
      ],
    },
  };

  const r = rateAmount(both, 1000);
  const ldl = r.areas.find((a) => a.area === 'Cholesterol');

  assert.equal(ldl.level, 'key nutrients, no level');
  assert.equal(r.levels['Saturated Fat'], undefined);
  assert.equal(r.levels['Total Fat'], undefined);
  // The other areas still decide the overall result.
  assert.ok(['Low', 'Moderate', 'High'].includes(r.overall) || /^review/.test(r.overall));
});

test('ALL-01 every area as findings: no level anywhere, no overall result', () => {
  const all = {
    ...CONTEXT,
    rating: {
      ...CONTEXT.rating,
      areas: [
        { area: 'Diabetes', nutrients: ['Carbohydrate', 'Total Sugars'], key_any_of: [], combine: 'findings' },
        { area: 'Blood pressure', nutrients: ['Sodium'], key_any_of: [], combine: 'findings' },
      ],
    },
  };

  const r = rateAmount(all, 1500);

  assert.ok(r.areas.every((a) => a.level === 'key nutrients, no level'));
  assert.deepEqual(r.levels, {});
  assert.equal(r.overall, 'review key nutrients (no health area has a level)');
});

test('fibre is a benefit and never gets a level', () => {
  const r = rateAmount({ ...CONTEXT, targets: { ...CONTEXT.targets, fibre_g: 25 } }, 1000);

  assert.equal(r.levels['Dietary Fibre'], undefined);
});

test('missing key nutrient: not enough information; no rules: no rating', () => {
  const noCarbs = {
    ...CONTEXT,
    rating: {
      ...CONTEXT.rating,
      nutrients: CONTEXT.rating.nutrients.filter((n) => n.name !== 'Carbohydrate'),
    },
  };

  assert.equal(rateAmount(noCarbs, 1000).areas[0].level, 'not enough information');

  const { rating: _r, ...old } = CONTEXT;
  assert.equal(recalculatePortion(old, { amount: 500, unit: 'ml' }).rating, undefined);
});

test('recalculate_portion rejects silly amounts', () => {
  assert.ok(recalculatePortion(CONTEXT, { amount: -5, unit: 'g' }).error);
  assert.ok(recalculatePortion(CONTEXT, { amount: 99999, unit: 'g' }).error);
});

test('validateAskRequest merges turns and needs a final question', () => {
  const { messages } = validateAskRequest({
    context: CONTEXT,
    messages: [
      { role: 'assistant', text: 'Hi!' },
      { role: 'user', text: 'Can I drink 2 cups?' },
      { role: 'user', text: 'Per day.' },
    ],
  });

  assert.deepEqual(messages, [{ role: 'user', text: 'Can I drink 2 cups?\n\nPer day.' }]);

  assert.throws(
    () => validateAskRequest({ context: CONTEXT, messages: [{ role: 'assistant', text: 'x' }] }),
    AskNutriPalError,
  );
  assert.throws(() => validateAskRequest({ messages: [{ role: 'user', text: 'x' }] }), AskNutriPalError);
});

test('the context is wrapped as data in the system prompt', () => {
  const system = buildSystem(CONTEXT);

  assert.match(system, /<context>\n\{"product"/);
  assert.match(system, /not instructions/);
});

test('agent loop: tool call, then answer', async () => {
  const calls = [];

  const fetchImpl = fakeFetch(
    [
      {
        status: 200,
        body: {
          stop_reason: 'tool_use',
          content: [
            { type: 'text', text: 'Let me check.' },
            { type: 'tool_use', id: 'tu_1', name: 'recalculate_portion', input: { amount: 472, unit: 'ml' } },
          ],
          usage: { input_tokens: 10, output_tokens: 5 },
        },
      },
      {
        status: 200,
        model: 'claude-sonnet-5-5',
        body: {
          stop_reason: 'end_turn',
          content: [{ type: 'text', text: 'Two cups give 10.9 g carbohydrate, 12% of your meal budget.' }],
        },
      },
    ],
    calls,
  );

  const result = await askNutriPal({
    data: { context: CONTEXT, messages: [{ role: 'user', text: 'Can I drink 2 cups?' }] },
    apiKey: 'test-key',
    model: 'claude-sonnet-5-5',
    fetchImpl,
  });

  assert.equal(result.answer, 'Two cups give 10.9 g carbohydrate, 12% of your meal budget.');
  assert.deepEqual(result.evidence_ids, []);
  assert.deepEqual(result.steps, ['Checked your profile and this label', 'Rated 472 ml']);

  assert.equal(calls.length, 2);
  assert.deepEqual(
    calls[0].body.tools.map((t) => t.name),
    ['recalculate_portion', 'search_guidelines', 'compare_with_history'],
  );
  assert.equal(calls[0].headers['x-api-key'], 'test-key');

  const toolResult = calls[1].body.messages[2].content[0];
  assert.equal(toolResult.type, 'tool_result');
  assert.equal(toolResult.tool_use_id, 'tu_1');
  assert.equal(JSON.parse(toolResult.content).portion.amount, 472);
});

test('API errors become safe messages', async () => {
  await assert.rejects(
    askNutriPal({
      data: { context: CONTEXT, messages: [{ role: 'user', text: 'Hi' }] },
      apiKey: 'k',
      model: 'm',
      fetchImpl: fakeFetch([{ status: 429, body: { error: 'busy' } }]),
    }),
    (error) => error instanceof AskNutriPalError && error.code === 'resource-exhausted',
  );
});

test('no API key: failed-precondition', async () => {
  await assert.rejects(
    askNutriPal({
      data: { context: CONTEXT, messages: [{ role: 'user', text: 'Hi' }] },
      apiKey: '',
      model: 'm',
    }),
    (error) => error.code === 'failed-precondition',
  );
});

test('the prompt asks for an honest "not enough validated information"', () => {
  const system = buildSystem(CONTEXT);

  assert.match(system, /doesn't have enough validated information/);
  assert.match(system, /never show entry IDs/);
});

test('agent loop: search_guidelines returns evidence IDs to the server only', async () => {
  const calls = [];

  const fetchImpl = fakeFetch(
    [
      {
        status: 200,
        body: {
          stop_reason: 'tool_use',
          content: [
            { type: 'tool_use', id: 'tu_1', name: 'search_guidelines', input: { query: 'sodium daily limit' } },
          ],
        },
      },
      {
        status: 200,
        body: {
          stop_reason: 'end_turn',
          content: [{ type: 'text', text: 'Guidelines suggest less than 2,000 mg sodium a day.' }],
        },
      },
    ],
    calls,
  );

  const result = await askNutriPal({
    data: { context: CONTEXT, messages: [{ role: 'user', text: 'How much salt can I have a day?' }] },
    apiKey: 'k',
    model: 'm',
    fetchImpl,
  });

  assert.ok(result.evidence_ids.includes('HT-01'));
  assert.deepEqual(result.steps, ['Checked your profile and this label', 'Searched the guidelines']);

  const toolResult = JSON.parse(calls[1].body.messages[2].content[0].content);
  assert.equal(toolResult.found, true);
  assert.equal(toolResult.evidence_ids, undefined);
});

test('evaluation mode captures tool inputs and full guideline search results', async () => {
  const fetchImpl = fakeFetch([
    {
      status: 200,
      body: {
        stop_reason: 'tool_use',
        content: [
          {
            type: 'tool_use',
            id: 'tu_eval',
            name: 'search_guidelines',
            input: { query: 'traffic light medium' },
          },
        ],
      },
    },
    {
      status: 200,
      body: {
        stop_reason: 'end_turn',
        content: [{ type: 'text', text: 'Medium describes the nutrient level.' }],
      },
    },
  ]);

  const result = await askNutriPal({
    data: {
      context: CONTEXT,
      messages: [{ role: 'user', text: 'What does medium mean in a traffic light?' }],
      evalMode: true,
    },
    apiKey: 'k',
    model: 'm',
    fetchImpl,
  });

  assert.equal(result.evaluation.question, 'What does medium mean in a traffic light?');
  assert.deepEqual(result.evaluation.toolsCalled, [
    { name: 'search_guidelines', input: { query: 'traffic light medium' } },
  ]);
  assert.equal(result.evaluation.found, true);
  assert.equal(result.evaluation.kbVersion, '1.7.0');

  const fsaEntry = result.evaluation.searchGuidelinesResults
    .flatMap((search) => search.entries)
    .find((entry) => entry.id === 'GEN-23');

  assert.ok(fsaEntry);
  assert.ok(fsaEntry.topic);
  assert.ok(fsaEntry.guidance);
  assert.ok(fsaEntry.caution);
  assert.ok(fsaEntry.source);
  assert.equal(result.answer, 'Medium describes the nutrient level.');
});

test('evaluation data is omitted when evaluation mode is not enabled', async () => {
  const result = await askNutriPal({
    data: { context: CONTEXT, messages: [{ role: 'user', text: 'Hi' }] },
    apiKey: 'k',
    model: 'm',
    fetchImpl: fakeFetch([
      {
        status: 200,
        body: {
          stop_reason: 'end_turn',
          content: [{ type: 'text', text: 'Hello.' }],
        },
      },
    ]),
  });

  assert.equal(Object.hasOwn(result, 'evaluation'), false);
});

test('evaluation document contains only the requested whitelist fields', () => {
  const document = buildEvaluationRecord({
    evaluation: {
      question: 'What does medium mean?',
      toolsCalled: [{ name: 'search_guidelines', input: { query: 'medium' } }],
      searchGuidelinesResults: [{ found: true, entries: [{ id: 'GEN-23' }] }],
      found: true,
      kbVersion: '1.7.0',
    },
    finalAnswer: 'It describes a nutrient level.',
    model: 'test-model',
    timestamp: 'server-time',
  });

  assert.deepEqual(Object.keys(document), [
    'timestamp',
    'question',
    'toolsCalled',
    'searchGuidelinesResults',
    'found',
    'finalAnswer',
    'model',
    'kbVersion',
  ]);
  assert.equal(document.gitCommitHash, undefined);
  assert.equal(Object.hasOwn(document, 'uid'), false);
  assert.equal(Object.hasOwn(document, 'profile'), false);
});

test('agent loop: compare_with_history reads only the signed-in user', async () => {
  const seen = [];
  const db = fakeDb([scan('a', 'Plain Soy Milk', 'drink', [['Total Sugars', 0.2, 'g']])], seen);

  const fetchImpl = fakeFetch([
    {
      status: 200,
      body: {
        stop_reason: 'tool_use',
        content: [{ type: 'tool_use', id: 'tu_1', name: 'compare_with_history', input: { nutrient: 'Total Sugars' } }],
      },
    },
    { status: 200, body: { stop_reason: 'end_turn', content: [{ type: 'text', text: 'Plain Soy Milk has less sugar.' }] } },
  ]);

  const result = await askNutriPal({
    data: { context: CONTEXT, messages: [{ role: 'user', text: 'Anything with less sugar?' }] },
    apiKey: 'k',
    model: 'm',
    uid: 'user-1',
    db,
    fetchImpl,
  });

  assert.deepEqual(seen.slice(0, 3), ['users', 'user-1', 'scans']);
  assert.deepEqual(result.steps, ['Checked your profile and this label', 'Checked your past scans']);
});

test('markdown in an answer becomes plain text for the app', () => {
  const { plainText } = require('../src/ask_nutripal');

  assert.equal(
    plainText('Two servings is 472 ml.\n\n- **Diabetes:** Moderate.\n- **Blood pressure:** Low.'),
    'Two servings is 472 ml.\n\n• Diabetes: Moderate.\n• Blood pressure: Low.',
  );
  assert.equal(plainText('## Tip\nChoose *less* salt; 2 * 236 ml.'), 'Tip\nChoose less salt; 2 * 236 ml.');
});

test('weight goal: maintenance energy for every goal, called a general guide', () => {
  const system = buildSystem(CONTEXT);

  assert.match(system, /same estimated maintenance energy/);
  assert.match(system, /does not take off or add a fixed amount/);
  assert.match(system, /a general guide, never a calorie target/);
  assert.match(system, /Never rate a product Low, Moderate or High for weight/);
});

test('weight goal: energy is rated against the goal energy sent by the app', () => {
  // Lose 500 kcal: 2092.2 - 500 = 1592.2 kcal.
  const ctx = {
    ...CONTEXT,
    targets: { ...CONTEXT.targets, energy_kcal: 1592.2, maintenance_energy_kcal: 2092.2, limits_energy_kcal: 2092.2 },
  };

  const energy = recalculatePortion(ctx, { amount: 1000, unit: 'ml' }).nutrients.find((n) => n.name === 'Energy');

  // 390 kcal of 1592.2 = 24%.
  assert.equal(energy.share_of_limit_percent, 24);
});
