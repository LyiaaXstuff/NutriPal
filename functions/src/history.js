// =======================================================
// COMPARE WITH HISTORY (Ask NutriPal tool)
// =======================================================
//
// Looks through the signed-in user's own scan history
// (users/{uid}/scans) for products of the same kind
// (food or drink) that are noticeably lower in one
// nutrient than the product in the chat (higher, for
// fibre and protein).
//
// Each scan document carries an `agentSummary` written by
// the app (lib/services/agent_summary.dart): nutrients per
// 100 g or 100 ml and their FSA traffic-light levels. Only
// those values are compared, never a portion, so products
// with different serving sizes are compared fairly.
//
// "Noticeably" = at least 25% different, following the
// comparative-claim rule in the knowledge base (GEN-17).
// That reuse is a researcher-defined choice.
//
// Only this user's scans are read, with the Admin SDK and
// the uid from Firebase Auth (never from the request).
// =======================================================

'use strict';

const MIN_DIFFERENCE = 0.25;
const MAX_RESULTS = 5;
const MAX_SCANS = 300;

const HIGHER_IS_BETTER = new Set(['Dietary Fibre', 'Protein']);

const NUTRIENTS = [
  'Energy',
  'Carbohydrate',
  'Total Sugars',
  'Total Fat',
  'Saturated Fat',
  'Trans Fat',
  'Sodium',
  'Dietary Fibre',
  'Protein',
];

const TO_GRAMS = { g: 1, mg: 0.001, 'µg': 0.000001, mcg: 0.000001 };

function round(value) {
  if (Math.abs(value) >= 100) return Math.round(value);
  if (Math.abs(value) >= 1) return Math.round(value * 10) / 10;
  return Math.round(value * 100) / 100;
}

/** Converts amount between mass units; null if it can't. */
function convert(amount, from, to) {
  if (from === to) return amount;
  if (!TO_GRAMS[from] || !TO_GRAMS[to]) return null;

  return (amount * TO_GRAMS[from]) / TO_GRAMS[to];
}

function find(rows, name) {
  if (!Array.isArray(rows)) return null;

  return rows.find((r) => r && r.name === name && typeof r.amount === 'number') || null;
}

function sameName(a, b) {
  return String(a || '').trim().toLowerCase() === String(b || '').trim().toLowerCase();
}

/**
 * compare_with_history tool.
 * @param {object} context Chat context (per_100, product).
 * @param {{nutrient: string}} input
 * @param {{uid?: string, db?: object, now?: number}} env
 */
async function compareWithHistory(context, input, { uid, db, now = Date.now() } = {}) {
  const nutrient = input && input.nutrient;

  if (!NUTRIENTS.includes(nutrient)) {
    return { error: `Unknown nutrient. Use one of: ${NUTRIENTS.join(', ')}.` };
  }

  if (!uid || !db) {
    return { error: 'Scan history is only available when the user is signed in.' };
  }

  const form = context.product && context.product.form === 'drink' ? 'drink' : 'food';
  const basis = form === 'drink' ? 'per 100 ml' : 'per 100 g';
  const current = find(context.per_100, nutrient);

  if (!current) {
    return { found: false, message: `This product's label has no ${nutrient} value to compare.` };
  }

  const higher = HIGHER_IS_BETTER.has(nutrient);

  let snapshot;

  try {
    snapshot = await db
      .collection('users')
      .doc(uid)
      .collection('scans')
      .select('productName', 'agentSummary', 'isFavourite', 'expiresAt')
      .limit(MAX_SCANS)
      .get();
  } catch (_) {
    return { error: 'Could not read the scan history right now.' };
  }

  let sameKind = 0;
  const better = new Map();

  for (const doc of snapshot.docs) {
    const d = doc.data() || {};
    const summary = d.agentSummary;

    // Expired history (TTL clean-up can lag).
    if (d.expiresAt && typeof d.expiresAt.toMillis === 'function' && d.expiresAt.toMillis() < now) continue;

    if (!summary || summary.form !== form) continue;
    if (sameName(d.productName, context.product && context.product.name)) continue;

    sameKind++;

    const row = find(summary.per100, nutrient);

    if (!row) continue;

    const value = convert(row.amount, row.unit, current.unit);

    if (value === null) continue;

    const ok = higher
      ? value >= current.amount * (1 + MIN_DIFFERENCE) && value > current.amount
      : value <= current.amount * (1 - MIN_DIFFERENCE) && value < current.amount;

    if (!ok) continue;

    const levels = {};

    for (const r of summary.per100) {
      if (r && typeof r.level === 'string') levels[r.name] = r.level;
    }

    const name = String(d.productName || 'Unnamed product').slice(0, 120);
    const key = name.toLowerCase();
    const item = {
      product_name: name,
      amount: round(value),
      unit: current.unit,
      ...(Object.keys(levels).length ? { traffic_lights: levels } : {}),
      ...(d.isFavourite === true ? { favourite: true } : {}),
    };

    const seen = better.get(key);

    if (!seen || (higher ? item.amount > seen.amount : item.amount < seen.amount)) better.set(key, item);
  }

  const products = [...better.values()]
    .sort((a, b) => (higher ? b.amount - a.amount : a.amount - b.amount))
    .slice(0, MAX_RESULTS);

  const result = {
    nutrient,
    basis,
    this_product: { amount: round(current.amount), unit: current.unit },
    rule: `At least ${Math.round(MIN_DIFFERENCE * 100)}% ${higher ? 'more' : 'less'} ${nutrient} ${basis}.`,
    scans_of_same_kind: sameKind,
  };

  if (!products.length) {
    return {
      ...result,
      found: false,
      message: `None of the user's past ${form === 'drink' ? 'drink' : 'food'} scans is noticeably ${higher ? 'higher' : 'lower'} in ${nutrient}.`,
    };
  }

  return { ...result, found: true, products };
}

module.exports = { compareWithHistory, NUTRIENTS, MIN_DIFFERENCE, HIGHER_IS_BETTER };
