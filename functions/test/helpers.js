'use strict';

// Shared test data and fakes (not a test file).

// Homesoy, sample user (rules document worked example:
// woman, 45 y, 158 cm, 65 kg, low active; NASEM 2023 EER).
const CONTEXT = {
  product: { name: 'Homesoy Soya Bean Drink', form: 'drink', serving_size: { amount: 236, unit: 'ml' } },
  per_100: [
    { name: 'Energy', amount: 39, unit: 'kcal' },
    { name: 'Carbohydrate', amount: 2.3, unit: 'g' },
    { name: 'Total Sugars', amount: 0.7, unit: 'g' },
    { name: 'Sodium', amount: 17, unit: 'mg' },
    { name: 'Calcium', amount: 120, unit: 'mg' },
  ],
  user: { health_areas: ['Diabetes', 'Blood pressure'] },
  targets: {
    energy_kcal: 2092.2,
    sodium_mg: 2000,
    free_sugars_g: 52.3,
    carbs_per_meal_g: 87.2,
    set_by_provider: [],
  },
  // As AskNutriPalService.ratingRules builds it.
  rating: {
    low_share_max: 0.1,
    moderate_share_max: 0.3,
    combine: 'worse_of_both',
    nutrients: [
      { name: 'Energy', per100: 39, unit: 'kcal', rated: true },
      { name: 'Protein', per100: 3.0, unit: 'g', rated: true },
      { name: 'Total Fat', per100: 1.6, unit: 'g', product_level_per_100: 'Moderate', rated: true },
      { name: 'Saturated Fat', per100: 0.3, unit: 'g', product_level_per_100: 'Low', rated: true },
      { name: 'Carbohydrate', per100: 2.3, unit: 'g', rated: true },
      { name: 'Total Sugars', per100: 0.7, unit: 'g', product_level_per_100: 'Low', rated: true },
      { name: 'Dietary Fibre', per100: 1.5, unit: 'g', rated: false },
      { name: 'Sodium', per100: 17, unit: 'mg', product_level_per_100: 'Low', rated: true },
    ],
    areas: [
      { area: 'Diabetes', nutrients: ['Carbohydrate', 'Total Sugars'], key_any_of: ['Carbohydrate'] },
      { area: 'Blood pressure', nutrients: ['Sodium'], key_any_of: ['Sodium'] },
    ],
  },
};

// ---- fakes for the history tool -----------------------

function scan(id, productName, form, rows, extra = {}) {
  return {
    id,
    productName,
    isFavourite: false,
    agentSummary: {
      v: 1,
      form,
      basis: form === 'drink' ? 'per 100 ml' : 'per 100 g',
      per100: rows.map(([name, amount, unit, level]) => ({ name, amount, unit, ...(level ? { level } : {}) })),
    },
    ...extra,
  };
}

function fakeDb(docs, seen = []) {
  const query = {
    select: (...fields) => {
      seen.push(`select:${fields.join(',')}`);
      return query;
    },
    limit: () => query,
    get: async () => ({ docs: docs.map((d) => ({ id: d.id, data: () => d })) }),
  };

  return {
    collection: (name) => {
      seen.push(name);
      return {
        doc: (id) => {
          seen.push(id);
          return {
            collection: (sub) => {
              seen.push(sub);
              return query;
            },
          };
        },
      };
    },
  };
}

module.exports = { CONTEXT, scan, fakeDb };
