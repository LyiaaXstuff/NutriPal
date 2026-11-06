'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  readNutritionLabel,
  validateRequest,
  buildRequestBody,
  sanitizeLabel,
  LabelReaderError,
} = require('../src/label_reader');

const IMAGE = 'A'.repeat(200);

function fakeFetch(status, body, calls = []) {
  return async (url, options) => {
    calls.push({ url, options });

    return {
      ok: status >= 200 && status < 300,
      status,
      json: async () => body,
    };
  };
}

const TUNA = {
  is_nutrition_table: true,
  serving_size: { amount: 36, unit: 'g' },
  servings_per_package: 3,
  physical_serving: null,
  columns: [
    { label: 'Setiap hidangan', basis: 'per_serving' },
    { label: 'Setiap 100g', basis: 'per_100g' },
  ],
  nutrients: [
    {
      name: 'Tenaga',
      cells: [
        { values: [{ amount: 39, unit: 'kcal', printed: '39kcal' }] },
        { values: [{ amount: 108, unit: 'kcal', printed: '108kcal' }] },
      ],
    },
    {
      name: 'Lemak',
      cells: [
        { values: [{ amount: 0.5, unit: 'g', printed: '0.5g*' }] },
        { values: [{ amount: 1.5, unit: 'g', printed: '1.5g*' }] },
      ],
    },
  ],
};

test('rejects missing or oversized images', () => {
  assert.throws(() => validateRequest(null), LabelReaderError);
  assert.throws(() => validateRequest({ imageBase64: 'abc' }), LabelReaderError);
  assert.throws(
    () => validateRequest({ imageBase64: 'A'.repeat(9 * 1024 * 1024) }),
    LabelReaderError,
  );
  assert.throws(
    () => validateRequest({ imageBase64: IMAGE, mediaType: 'image/gif' }),
    LabelReaderError,
  );
  assert.throws(
    () => validateRequest({ imageBase64: `${IMAGE}<script>` }),
    LabelReaderError,
  );
});

test('builds a forced tool call with image first', () => {
  const body = buildRequestBody({
    imageBase64: IMAGE,
    mediaType: 'image/jpeg',
    model: 'claude-haiku-5-5',
  });

  assert.equal(body.model, 'claude-haiku-5-5');
  assert.deepEqual(body.tool_choice, { type: 'tool', name: 'record_nutrition_table' });
  assert.equal(body.messages[0].content[0].type, 'image');
  assert.equal(body.messages[0].content[0].source.data, IMAGE);
});

test('returns the sanitized table from a tool_use block', async () => {
  const calls = [];

  const result = await readNutritionLabel({
    data: { imageBase64: IMAGE, mediaType: 'image/jpeg' },
    apiKey: 'test-key',
    model: 'claude-haiku-5-5',
    fetchImpl: fakeFetch(
      200,
      {
        model: 'claude-haiku-5-5',
        content: [{ type: 'tool_use', name: 'record_nutrition_table', input: TUNA }],
        usage: { input_tokens: 3000, output_tokens: 600 },
      },
      calls,
    ),
  });

  assert.equal(calls.length, 1);
  assert.equal(calls[0].options.headers['x-api-key'], 'test-key');
  assert.equal(result.label.nutrients.length, 2);
  assert.equal(result.label.nutrients[1].cells[0].values[0].amount, 0.5);
  assert.equal(result.label.serving_size.amount, 36);
});

test('pads missing cells and drops malformed values', () => {
  const label = sanitizeLabel({
    columns: [
      { label: 'Per serving', basis: 'per_serving' },
      { label: 'Per 100 g', basis: 'weird' },
    ],
    nutrients: [
      { name: '  Protein ', cells: [{ values: [{ amount: 'x', unit: 'g', printed: '?' }] }] },
      { name: '', cells: [] },
      null,
    ],
    serving_size: { amount: 30, unit: 'oz' },
  });

  assert.equal(label.columns[1].basis, 'other');
  assert.equal(label.nutrients.length, 1);
  assert.equal(label.nutrients[0].name, 'Protein');
  assert.equal(label.nutrients[0].cells.length, 2);
  assert.equal(label.nutrients[0].cells[0].values[0].amount, null);
  assert.deepEqual(label.nutrients[0].cells[1].values, []);
  assert.equal(label.serving_size, null);
});

test('maps API failures to safe error codes', async () => {
  await assert.rejects(
    readNutritionLabel({
      data: { imageBase64: IMAGE },
      apiKey: 'k',
      model: 'm',
      fetchImpl: fakeFetch(429, { error: { type: 'rate_limit_error' } }),
    }),
    (error) => error instanceof LabelReaderError && error.code === 'resource-exhausted',
  );

  await assert.rejects(
    readNutritionLabel({ data: { imageBase64: IMAGE }, apiKey: '', model: 'm' }),
    (error) => error.code === 'failed-precondition',
  );

  await assert.rejects(
    readNutritionLabel({
      data: { imageBase64: IMAGE },
      apiKey: 'k',
      model: 'm',
      fetchImpl: fakeFetch(200, { content: [{ type: 'text', text: 'hi' }] }),
    }),
    (error) => error.code === 'internal',
  );
});
