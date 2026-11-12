'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const { searchGuidelines, conceptsOf, KB_SIZE } = require('../src/guidelines');
const { compareWithHistory } = require('../src/history');
const KB = require('../src/knowledge/chatbot_kb.json');
const { scan, fakeDb, CONTEXT } = require('./helpers');

// =======================================================
// search_guidelines
// =======================================================

const DM_BP = { user: { health_areas: ['Diabetes', 'Blood pressure'] } };
const DM_ONLY = { user: { health_areas: ['Diabetes'] } };

test('KB: only approved entries are packaged', () => {
  assert.equal(KB_SIZE, KB.entries.length);
  assert.ok(KB_SIZE > 50);

  const allowed = new Set(['Diabetes', 'Blood pressure', 'Cholesterol', 'Weight', 'General']);

  for (const e of KB.entries) {
    assert.match(e.id, /^[A-Z]{2,3}-\d{2}$/);
    assert.ok(e.areas.length > 0 && e.areas.every((a) => allowed.has(a)), e.id);
    assert.ok(e.guidance && e.source, e.id);
  }
});

test('Malay and English words map to the same concepts', () => {
  assert.ok(conceptsOf('garam').has('salt'));
  assert.ok(conceptsOf('Sodium').has('salt'));
  assert.ok(conceptsOf('gula').has('sugar'));
  assert.ok(conceptsOf('serat').has('fibre'));
});

test('salt question finds the daily sodium limit', () => {
  const r = searchGuidelines(DM_BP, { query: 'how much salt per day' });

  assert.equal(r.found, true);
  assert.ok(r.evidence_ids.includes('HT-01'));
  assert.ok(r.entries.length <= 4);
});

test('Malay question about sweet drinks finds the drinks guidance', () => {
  const r = searchGuidelines(DM_BP, { query: 'boleh minum air manis? gula tinggi' });

  assert.equal(r.found, true);
  assert.ok(r.evidence_ids.includes('DM-05'));
});

test('off-topic question: no validated information', () => {
  const r = searchGuidelines(DM_BP, { query: 'what is the weather in Kuala Lumpur' });

  assert.equal(r.found, false);
  assert.deepEqual(r.evidence_ids, []);
});

test("the user's health areas filter results; health_area widens them", () => {
  const own = searchGuidelines(DM_ONLY, { query: 'santan coconut oil saturated fat' });

  // Diabetes fat guidance only; no cholesterol entries.
  assert.ok(own.evidence_ids.every((id) => !id.startsWith('LD-')));

  const r = searchGuidelines(DM_ONLY, {
    query: 'santan coconut oil saturated fat',
    health_area: 'Cholesterol',
  });

  assert.equal(r.found, true);
  assert.ok(r.evidence_ids.includes('LD-12'));
});

test('same question, same entries (deterministic)', () => {
  const a = searchGuidelines(DM_BP, { query: 'alcohol' });
  const b = searchGuidelines(DM_BP, { query: 'alcohol' });

  assert.deepEqual(a, b);
});

test('empty query is an error', () => {
  assert.ok(searchGuidelines(DM_BP, { query: '  ' }).error);
});

// =======================================================
// compare_with_history
// =======================================================

const NOW = Date.UTC(2026, 10, 12);

const HISTORY = [
  // 0.5 g vs 0.7 g sugars: 29% less -> counts.
  scan('1', 'Soy Drink Less Sugar', 'drink', [['Total Sugars', 0.5, 'g', 'Low'], ['Sodium', 40, 'mg', 'Low']]),
  // 0.6 g: only 14% less -> not noticeably lower.
  scan('2', 'Soy Drink Original', 'drink', [['Total Sugars', 0.6, 'g', 'Low']]),
  // Lower, but a food (per 100 g) -> skipped.
  scan('3', 'Soy Crackers', 'food', [['Total Sugars', 0.1, 'g', 'Low']]),
  // Same product as in the chat -> skipped.
  scan('4', 'homesoy soya bean drink', 'drink', [['Total Sugars', 0.1, 'g', 'Low']]),
  // Expired history -> skipped.
  scan('5', 'Old Oat Drink', 'drink', [['Total Sugars', 0, 'g', 'Low']], {
    expiresAt: { toMillis: () => NOW - 1000 },
  }),
  // Older app, no summary -> skipped.
  { id: '6', productName: 'Mystery Drink', isFavourite: false },
  // Lowest, favourite, but high in sodium.
  scan('7', 'Unsweetened Almond Drink', 'drink', [['Total Sugars', 0, 'g', 'Low'], ['Sodium', 0.4, 'g', 'High']], {
    isFavourite: true,
  }),
];

test('finds same-kind products at least 25% lower, lowest first', async () => {
  const seen = [];
  const r = await compareWithHistory(CONTEXT, { nutrient: 'Total Sugars' }, { uid: 'u1', db: fakeDb(HISTORY, seen), now: NOW });

  assert.equal(r.found, true);
  assert.equal(r.basis, 'per 100 ml');
  assert.deepEqual(r.products.map((p) => p.product_name), ['Unsweetened Almond Drink', 'Soy Drink Less Sugar']);
  assert.equal(r.products[0].favourite, true);
  assert.equal(r.products[0].traffic_lights.Sodium, 'High');
  assert.equal(r.scans_of_same_kind, 3);
  assert.ok(seen.includes('select:productName,agentSummary,isFavourite,expiresAt'));
});

test('units are converted before comparing (sodium g -> mg)', async () => {
  const r = await compareWithHistory(CONTEXT, { nutrient: 'Sodium' }, { uid: 'u1', db: fakeDb(HISTORY), now: NOW });

  // Homesoy 17 mg; almond 400 mg and soy 40 mg are higher.
  assert.equal(r.found, false);
  assert.equal(r.this_product.amount, 17);
});

test('nothing lower: found false with a message', async () => {
  const r = await compareWithHistory(CONTEXT, { nutrient: 'Carbohydrate' }, { uid: 'u1', db: fakeDb(HISTORY), now: NOW });

  assert.equal(r.found, false);
  assert.match(r.message, /None of the user's past drink scans/);
});

test('not signed in or unknown nutrient: error', async () => {
  assert.ok((await compareWithHistory(CONTEXT, { nutrient: 'Total Sugars' }, {})).error);
  assert.ok((await compareWithHistory(CONTEXT, { nutrient: 'Vitamin Z' }, { uid: 'u1', db: fakeDb([]) })).error);
});

test('label without the nutrient: found false', async () => {
  const r = await compareWithHistory(CONTEXT, { nutrient: 'Saturated Fat' }, { uid: 'u1', db: fakeDb(HISTORY), now: NOW });

  assert.equal(r.found, false);
  assert.match(r.message, /no Saturated Fat value/);
});

test('fibre: higher is better', async () => {
  const ctx = { ...CONTEXT, per_100: [{ name: 'Dietary Fibre', amount: 2, unit: 'g' }] };
  const db = fakeDb([
    scan('a', 'Oat Drink', 'drink', [['Dietary Fibre', 3, 'g']]),
    scan('b', 'Rice Drink', 'drink', [['Dietary Fibre', 1, 'g']]),
  ]);

  const r = await compareWithHistory(ctx, { nutrient: 'Dietary Fibre' }, { uid: 'u1', db, now: NOW });

  assert.deepEqual(r.products.map((p) => p.product_name), ['Oat Drink']);
});

test('a failing Firestore read becomes a safe error', async () => {
  const db = { collection: () => { throw new Error('boom'); } };

  assert.match((await compareWithHistory(CONTEXT, { nutrient: 'Total Sugars' }, { uid: 'u1', db })).error, /Could not read/);
});
