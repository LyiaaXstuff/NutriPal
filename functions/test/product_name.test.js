'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  readProductName,
  buildRequestBody,
  sanitizeName,
  cleanName,
  OUTPUT_SCHEMA,
} = require('../src/product_name');
const { LabelReaderError } = require('../src/label_reader');

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

function claudeAnswer(json, extra = {}) {
  return {
    model: 'claude-test',
    stop_reason: 'end_turn',
    content: [{ type: 'text', text: JSON.stringify(json) }],
    usage: { input_tokens: 900, output_tokens: 20 },
    ...extra,
  };
}

test('returns the name and brand Claude reads with high confidence', async () => {
  const calls = [];

  const result = await readProductName({
    data: { imageBase64: IMAGE, mediaType: 'image/jpeg' },
    apiKey: 'sk-test-123',
    model: 'claude-test',
    fetchImpl: fakeFetch(
      200,
      claudeAnswer({
        product_name: '  Roti Putih / White Bread ',
        brand: 'Gardenia',
        confidence: 'high',
      }),
      calls,
    ),
  });

  assert.equal(result.product_name, 'Roti Putih / White Bread');
  assert.equal(result.brand, 'Gardenia');

  // The API key goes only in the x-api-key header.
  const sent = JSON.parse(calls[0].options.body);
  assert.equal(calls[0].options.headers['x-api-key'], 'sk-test-123');
  assert.equal(calls[0].options.body.includes('sk-test-123'), false);
  assert.equal(sent.max_tokens, 300);
});

test('low confidence gives no name', async () => {
  const result = await readProductName({
    data: { imageBase64: IMAGE },
    apiKey: 'key',
    model: 'm',
    fetchImpl: fakeFetch(
      200,
      claudeAnswer({ product_name: 'Coklat', brand: null, confidence: 'low' }),
    ),
  });

  assert.equal(result.product_name, null);
  assert.equal(result.brand, null);
});

test('refusal or cut-off answers give no name instead of an error', async () => {
  const result = await readProductName({
    data: { imageBase64: IMAGE },
    apiKey: 'key',
    model: 'm',
    fetchImpl: fakeFetch(200, { stop_reason: 'refusal', content: [] }),
  });

  assert.equal(result.product_name, null);
});

test('rejects text that is not a product name', () => {
  assert.equal(cleanName('Maklumat Pemakanan'), null);
  assert.equal(cleanName('Ingredients: wheat flour, sugar'), null);
  assert.equal(cleanName('Dikilang oleh ABC Food Sdn. Bhd.'), null);
  assert.equal(cleanName('Berat Bersih 400g'), null);
  assert.equal(cleanName('www.gardenia.com.my'), null);
  assert.equal(cleanName('123456'), null);
  assert.equal(cleanName('x'), null);
  assert.equal(cleanName('A'.repeat(81)), null);

  assert.equal(cleanName('"Biskut Krim Coklat"'), 'Biskut Krim Coklat');
  assert.equal(cleanName('Milo   Activ-Go'), 'Milo Activ-Go');
});

test('a bad brand is dropped but a good name is kept', () => {
  assert.deepEqual(
    sanitizeName({ product_name: 'Original Classic Bread', brand: 'ABC Sdn Bhd', confidence: 'high' }),
    { product_name: 'Original Classic Bread', brand: null },
  );

  assert.deepEqual(sanitizeName(null), { product_name: null, brand: null });
});

test('request uses the server-side schema and never takes a prompt from the app', () => {
  const body = buildRequestBody({ imageBase64: IMAGE, mediaType: 'image/jpeg', model: 'm' });

  assert.deepEqual(body.output_config.format.schema, OUTPUT_SCHEMA);
  assert.equal(body.messages[0].content[0].type, 'image');
});

test('invalid images and missing key are rejected', async () => {
  await assert.rejects(
    readProductName({ data: { imageBase64: 'abc' }, apiKey: 'key', model: 'm' }),
    LabelReaderError,
  );

  await assert.rejects(
    readProductName({ data: { imageBase64: IMAGE }, apiKey: '', model: 'm' }),
    LabelReaderError,
  );
});

test('API errors map to Firebase codes', async () => {
  await assert.rejects(
    readProductName({
      data: { imageBase64: IMAGE },
      apiKey: 'key',
      model: 'm',
      fetchImpl: fakeFetch(429, { error: 'busy' }),
    }),
    (error) => error instanceof LabelReaderError && error.code === 'resource-exhausted',
  );
});
