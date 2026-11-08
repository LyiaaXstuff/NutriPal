'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  askNutriPal,
  validateAskRequest,
  recalculatePortion,
  buildSystem,
  AskNutriPalError,
} = require('../src/ask_nutripal');

// Homesoy, sample user (rules document worked example).
const CONTEXT = {
  product: { name: 'Homesoy Soya Bean Drink', form: 'drink', serving_size: { amount: 236, unit: 'ml' } },
  per_100: [
    { name: 'Energy', amount: 39, unit: 'kcal' },
    { name: 'Carbohydrate', amount: 2.3, unit: 'g' },
    { name: 'Total Sugars', amount: 0.7, unit: 'g' },
    { name: 'Sodium', amount: 17, unit: 'mg' },
    { name: 'Calcium', amount: 120, unit: 'mg' },
  ],
  targets: {
    energy_kcal: 1720.8,
    sodium_mg: 2000,
    free_sugars_g: 43,
    carbs_per_meal_g: 71.7,
    set_by_provider: [],
  },
};

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
  assert.equal(carbs.share_of_limit_percent, 15);
  assert.equal(sodium.amount, 80.2);
  assert.equal(sodium.share_of_limit_percent, 4);
  assert.equal(calcium.share_of_limit_percent, undefined);
  assert.equal(result.note, undefined);
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
          content: [{ type: 'text', text: 'Two cups give 10.9 g carbohydrate, 15% of your meal budget.' }],
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

  assert.equal(result.answer, 'Two cups give 10.9 g carbohydrate, 15% of your meal budget.');
  assert.deepEqual(result.steps, ['Checked your profile and this label', 'Recalculated for 472 ml']);

  assert.equal(calls.length, 2);
  assert.equal(calls[0].body.tools[0].name, 'recalculate_portion');
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
