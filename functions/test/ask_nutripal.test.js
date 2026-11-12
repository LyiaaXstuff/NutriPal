'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  askNutriPal,
  validateAskRequest,
  recalculatePortion,
  rateAmount,
  buildSystem,
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
  assert.equal(carbs.share_of_limit_percent, 12);
  assert.equal(sodium.amount, 80.2);
  assert.equal(sodium.share_of_limit_percent, 4);
  assert.equal(calcium.share_of_limit_percent, undefined);
  assert.equal(result.note, undefined);
});

// Same answers as the app's own tests
// (nutrition_analysis_service_test.dart, sample user).
test('recalculate_portion rates like the app: Homesoy 1 L Moderate, 1.5 L High', () => {
  const oneLitre = recalculatePortion(CONTEXT, { amount: 1000, unit: 'ml' }).rating;

  assert.equal(oneLitre.overall, 'Moderate');
  assert.deepEqual(oneLitre.areas, [
    // Carbohydrate 23 g of 87.2 g (26%), sugars 7 g of 52.3 g (13%).
    { area: 'Diabetes', level: 'Moderate', decided_by: 'Carbohydrate' },
    // Sodium 170 mg of 2,000 mg (8.5%), traffic light Low.
    { area: 'Blood pressure', level: 'Low', decided_by: 'Sodium' },
  ]);

  const bigger = recalculatePortion(CONTEXT, { amount: 1500, unit: 'ml' }).rating;
  assert.equal(bigger.overall, 'High');
  assert.equal(bigger.areas[0].decided_by, 'Carbohydrate');

  assert.equal(recalculatePortion(CONTEXT, { amount: 236, unit: 'ml' }).rating.overall, 'Low');
});

test('the per-100 traffic light is never lowered by a small amount', () => {
  // Total fat is Moderate per 100 ml, so even 10 ml
  // (0.16 g, under 1% of 69.7 g) stays Moderate.
  const ctx = { ...CONTEXT, targets: { ...CONTEXT.targets, total_fat_g: 69.7 } };

  assert.equal(rateAmount(ctx, 10).levels['Total Fat'], 'Moderate');
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

test('weight goal: the prompt calls the goal energy a general guide', () => {
  const system = buildSystem(CONTEXT);

  assert.match(system, /general guide, never a prescription/);
  assert.match(system, /maintenance_energy_kcal/);
  assert.doesNotMatch(system, /Never give the user a personal calorie target/);
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
